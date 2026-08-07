#!/usr/bin/env bash
# setup.sh — Inicializa o ambiente local quantum (OpenClaw + Ollama + llama-qiskit-agents)
# Uso: ./setup.sh [modelo]
#   modelo: qwen2.5-coder:14b (padrão) | mistral-small3.2:24b | qwen2.5-coder:7b

set -euo pipefail

MODEL="${1:-qwen2.5-coder:14b}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Cores ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERRO]${NC} $*"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Quantum Local Stack — Setup                           ║"
echo "║   OpenClaw + Ollama + llama-qiskit-agents               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Pré-requisitos ─────────────────────────────────────────────────────────────
info "Verificando pré-requisitos..."

command -v docker >/dev/null 2>&1 || error "Docker não encontrado. Instale em https://docs.docker.com/get-docker/"
docker compose version >/dev/null 2>&1 || error "Docker Compose v2 não encontrado."
command -v python3 >/dev/null 2>&1 || error "Python3 não encontrado."

success "Docker e Python3 encontrados"

# ── RAM disponível ─────────────────────────────────────────────────────────────
info "Verificando RAM disponível..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
else
  TOTAL_RAM_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
fi

info "RAM total: ${TOTAL_RAM_GB} GB"

case "$MODEL" in
  qwen2.5-coder:7b)   MIN_RAM=8  ;;
  qwen2.5-coder:14b)  MIN_RAM=16 ;;
  mistral-small3.2:24b|mistral-small:24b) MIN_RAM=24 ;;
  *) MIN_RAM=16 ;;
esac

if [ "$TOTAL_RAM_GB" -lt "$MIN_RAM" ]; then
  warn "RAM disponível (${TOTAL_RAM_GB} GB) pode ser insuficiente para ${MODEL} (recomendado: ${MIN_RAM} GB)"
  warn "O modelo ainda pode funcionar, mas será mais lento com swap."
  read -r -p "Continuar mesmo assim? [s/N] " resp
  [[ "$resp" =~ ^[sS]$ ]] || exit 0
else
  success "RAM suficiente para ${MODEL}"
fi

# ── .env ───────────────────────────────────────────────────────────────────────
info "Configurando .env..."
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
  cat > "$ENV_FILE" <<EOF
OPENCLAW_MODEL=${MODEL}
OPENCLAW_GATEWAY_TOKEN=${TOKEN}
EOF
  success ".env criado com token gerado automaticamente"
else
  # Atualiza o modelo se informado explicitamente via argumento
  if [ -n "${1:-}" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|^OPENCLAW_MODEL=.*|OPENCLAW_MODEL=${MODEL}|" "$ENV_FILE"
    else
      sed -i "s|^OPENCLAW_MODEL=.*|OPENCLAW_MODEL=${MODEL}|" "$ENV_FILE"
    fi
    success ".env atualizado: modelo = ${MODEL}"
  else
    warn ".env já existe — mantendo configuração atual"
  fi
fi

# Lê o token do .env para exibir no final
GATEWAY_TOKEN=$(grep '^OPENCLAW_GATEWAY_TOKEN=' "$ENV_FILE" | cut -d= -f2)

# ── Verificar llama-qiskit-agents ──────────────────────────────────────────────
QISKIT_DIR="$SCRIPT_DIR/../../llama-qiskit-agents"
if [ ! -f "$QISKIT_DIR/Dockerfile" ]; then
  error "Dockerfile do llama-qiskit-agents não encontrado em: $QISKIT_DIR
Certifique-se de que o projeto llama-qiskit-agents está em ../llama-qiskit-agents
relativo a este diretório (openclaw-openshift/local/)."
fi
success "llama-qiskit-agents encontrado em: $QISKIT_DIR"

# ── Substituir token no openclaw.json ──────────────────────────────────────────
info "Atualizando token no openclaw.json..."
CONFIG_FILE="$SCRIPT_DIR/config/openclaw.json"
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|local-dev-token-change-me|${GATEWAY_TOKEN}|g" "$CONFIG_FILE"
else
  sed -i "s|local-dev-token-change-me|${GATEWAY_TOKEN}|g" "$CONFIG_FILE"
fi
success "Token atualizado no openclaw.json"

# ── Substituir modelo no openclaw.json ────────────────────────────────────────
info "Atualizando modelo no openclaw.json para ${MODEL}..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|qwen2.5-coder:14b|${MODEL}|g" "$CONFIG_FILE"
else
  sed -i "s|qwen2.5-coder:14b|${MODEL}|g" "$CONFIG_FILE"
fi
success "Modelo atualizado no openclaw.json"

# ── Subir a stack ──────────────────────────────────────────────────────────────
info "Iniciando containers (build + up)..."
cd "$SCRIPT_DIR"
docker compose up -d --build

# ── Aguardar Ollama ────────────────────────────────────────────────────────────
info "Aguardando Ollama inicializar..."
for i in $(seq 1 30); do
  if docker compose exec -T ollama ollama list >/dev/null 2>&1; then
    success "Ollama pronto"
    break
  fi
  [ "$i" -eq 30 ] && error "Ollama não inicializou em 60s"
  sleep 2
done

# ── Pull do modelo (se ainda não tiver) ───────────────────────────────────────
info "Verificando se o modelo ${MODEL} já está disponível..."
if docker compose exec -T ollama ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  success "Modelo ${MODEL} já disponível"
else
  info "Baixando ${MODEL} (pode demorar bastante na primeira vez)..."
  docker compose exec -T ollama ollama pull "$MODEL"
  success "Modelo ${MODEL} baixado"
fi

# ── Aguardar llama-qiskit-agents ──────────────────────────────────────────────
info "Aguardando llama-qiskit-agents inicializar..."
for i in $(seq 1 30); do
  if docker compose exec -T qiskit-api curl -sf http://localhost:8080/healthz >/dev/null 2>&1; then
    success "llama-qiskit-agents pronto"
    break
  fi
  [ "$i" -eq 30 ] && warn "llama-qiskit-agents ainda não respondeu — verifique com: docker compose logs qiskit-api"
  sleep 3
done

# ── Resultado ─────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   Stack pronta!                                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo -e "  Modelo LLM:    ${GREEN}${MODEL}${NC} (via Ollama)"
echo -e "  OpenClaw:      ${GREEN}http://localhost:18789/?token=${GATEWAY_TOKEN}${NC}"
echo -e "  QiskitAgent:   Agente 'quantum_encoding' no OpenClaw"
echo -e "  API Qiskit:    ${GREEN}http://localhost:8080${NC}"
echo -e "  Ollama API:    ${GREEN}http://localhost:11434${NC}"
echo ""
echo "  Comandos úteis:"
echo "    docker compose logs -f openclaw     # logs do OpenClaw"
echo "    docker compose logs -f qiskit-api   # logs da API quantum"
echo "    docker compose down                 # parar tudo"
echo "    docker compose down -v              # parar + apagar volumes"
echo ""
