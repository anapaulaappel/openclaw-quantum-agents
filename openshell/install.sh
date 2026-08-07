#!/usr/bin/env bash
# install.sh — Deploy OpenShell + agentes quânticos
#
# Uso:
#   ./install.sh local          # Docker Compose (dev)
#   ./install.sh openshift      # Helm no cluster OpenShift (prod)
#
# Pré-requisitos:
#   local:     docker, docker compose, openshell CLI
#   openshift: oc, helm 3+, openshell CLI

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="$SCRIPT_DIR/policies"
MODE="${1:-local}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERRO]${NC}  $*"; exit 1; }

# ── Verificar CLI OpenShell ────────────────────────────────────────────────
check_openshell_cli() {
  if ! command -v openshell >/dev/null 2>&1; then
    warn "OpenShell CLI não encontrado."
    echo "  Instale com: curl -fsSL https://install.openshell.ai | sh"
    echo "  Ou: uv tool install -U openshell"
    exit 1
  fi
  success "OpenShell CLI: $(openshell --version 2>/dev/null || echo 'instalado')"
}

# ── Aplicar policies ──────────────────────────────────────────────────────
apply_policies() {
  local gateway_url="${1:-http://localhost:8080}"
  info "Aplicando policies dos agentes em $gateway_url..."

  OPENSHELL_GATEWAY="$gateway_url" openshell policy set qiskit-expert \
    --policy "$POLICIES_DIR/qiskit-expert.yaml" --wait
  success "Policy aplicada: qiskit-expert (Circuit)"

  OPENSHELL_GATEWAY="$gateway_url" openshell policy set qiskit-mentor \
    --policy "$POLICIES_DIR/qiskit-mentor.yaml" --wait
  success "Policy aplicada: qiskit-mentor (Quanta)"

  OPENSHELL_GATEWAY="$gateway_url" openshell policy set quantum-encoding \
    --policy "$POLICIES_DIR/quantum-encoding.yaml" --wait
  success "Policy aplicada: quantum-encoding (QiskitAgent)"
}

# ── Criar sandboxes ───────────────────────────────────────────────────────
create_sandboxes() {
  local gateway_url="${1:-http://localhost:8080}"
  info "Criando sandboxes dos agentes..."

  # NemoClaw: imagem oficial NVIDIA com OpenClaw pré-instalado
  OPENSHELL_GATEWAY="$gateway_url" openshell sandbox create \
    --name qiskit-expert \
    --policy qiskit-expert \
    --from openclaw \
    -- openclaw gateway run --bind lan --port 18789 --allow-unconfigured
  success "Sandbox criado: qiskit-expert"

  OPENSHELL_GATEWAY="$gateway_url" openshell sandbox create \
    --name qiskit-mentor \
    --policy qiskit-mentor \
    --from openclaw \
    -- openclaw gateway run --bind lan --port 18790 --allow-unconfigured
  success "Sandbox criado: qiskit-mentor"

  OPENSHELL_GATEWAY="$gateway_url" openshell sandbox create \
    --name quantum-encoding \
    --policy quantum-encoding \
    --from openclaw \
    -- openclaw gateway run --bind lan --port 18791 --allow-unconfigured
  success "Sandbox criado: quantum-encoding"
}

# ═══════════════════════════════════════════════════════════════════════════
# Modo LOCAL (Docker Compose)
# ═══════════════════════════════════════════════════════════════════════════
install_local() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   OpenShell + Quantum Agents — Setup Local              ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  command -v docker >/dev/null 2>&1 || error "Docker não encontrado."
  check_openshell_cli

  # .env
  if [ ! -f "$SCRIPT_DIR/local/.env" ]; then
    cp "$SCRIPT_DIR/local/.env.example" "$SCRIPT_DIR/local/.env" 2>/dev/null || \
    cat > "$SCRIPT_DIR/local/.env" <<'EOF'
OPENCLAW_MODEL=qwen2.5-coder:14b
EOF
    success ".env criado"
  fi

  # Subir a stack
  info "Subindo Docker Compose..."
  docker compose -f "$SCRIPT_DIR/local/docker-compose.yml" up -d --build

  # Aguardar gateway
  info "Aguardando OpenShell Gateway..."
  for i in $(seq 1 30); do
    if curl -sf http://localhost:8081/healthz >/dev/null 2>&1; then
      success "Gateway pronto em http://localhost:8080"
      break
    fi
    [ "$i" -eq 30 ] && error "Gateway não inicializou. Veja: docker compose logs openshell-gateway"
    sleep 3
  done

  # Aguardar qiskit-api
  info "Aguardando API Qiskit..."
  for i in $(seq 1 20); do
    if curl -sf http://localhost:8090/healthz >/dev/null 2>&1; then
      success "API Qiskit pronta em http://localhost:8090"
      break
    fi
    [ "$i" -eq 20 ] && warn "API Qiskit ainda não respondeu — continue manualmente"
    sleep 3
  done

  # Aplicar policies
  apply_policies "http://localhost:8080"

  # Criar sandboxes
  create_sandboxes "http://localhost:8080"

  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   Setup local concluído!                                ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  OpenShell Gateway:  http://localhost:8080"
  echo "  API Qiskit:         http://localhost:8090"
  echo "  Ollama:             http://localhost:11434"
  echo ""
  echo "  Sandboxes ativos:"
  echo "    openshell sandbox list"
  echo ""
  echo "  Conectar a um sandbox:"
  echo "    openshell sandbox connect qiskit-expert"
  echo "    openshell sandbox connect qiskit-mentor"
  echo ""
  echo "  Ver policies:"
  echo "    openshell policy get qiskit-expert"
  echo ""
  echo "  Dashboard (k9s-style TUI):"
  echo "    openshell term"
}

# ═══════════════════════════════════════════════════════════════════════════
# Modo OPENSHIFT (Helm)
# ═══════════════════════════════════════════════════════════════════════════
install_openshift() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   OpenShell + Quantum Agents — Deploy OpenShift         ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""

  command -v oc   >/dev/null 2>&1 || error "'oc' CLI não encontrado."
  command -v helm >/dev/null 2>&1 || error "'helm' CLI não encontrado."
  check_openshell_cli

  # Verificar login
  oc whoami >/dev/null 2>&1 || error "Não logado no OpenShift. Execute: oc login --server=<URL>"
  info "Logado como: $(oc whoami) no cluster $(oc whoami --show-server)"

  # Versão do OpenShell
  OPENSHELL_VERSION="${OPENSHELL_VERSION:-latest}"
  info "Versão OpenShell: $OPENSHELL_VERSION"

  # Namespace
  info "Criando namespace openshell..."
  oc create ns openshell 2>/dev/null || info "Namespace já existe"

  # SCC — o sandbox precisa de privileged para Landlock + seccomp
  info "Concedendo SCC privileged ao sandbox service account..."
  oc adm policy add-scc-to-user privileged \
    -z openshell-sandbox \
    -n openshell
  success "SCC concedido"

  # Instalar via Helm
  info "Instalando OpenShell via Helm..."
  helm upgrade --install openshell \
    "oci://ghcr.io/nvidia/openshell/helm-chart" \
    --version "$OPENSHELL_VERSION" \
    -n openshell \
    -f "$SCRIPT_DIR/helm/values-openshift.yaml" \
    --wait \
    --timeout 5m
  success "OpenShell instalado"

  # Criar Route para o gateway (acesso externo)
  info "Criando Route OpenShift para o gateway..."
  oc apply -n openshell -f - <<'ROUTE'
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: openshell-gateway
  namespace: openshell
  labels:
    app: openshell
spec:
  to:
    kind: Service
    name: openshell-gateway
  port:
    targetPort: 8080
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
ROUTE
  GATEWAY_HOST=$(oc get route openshell-gateway -n openshell -o jsonpath='{.spec.host}')
  GATEWAY_URL="https://$GATEWAY_HOST"
  success "Gateway disponível em: $GATEWAY_URL"

  # Configurar CLI para apontar para o cluster
  export OPENSHELL_GATEWAY="$GATEWAY_URL"

  # Aguardar gateway
  info "Aguardando gateway ficar saudável..."
  for i in $(seq 1 20); do
    if curl -sf "$GATEWAY_URL/healthz" >/dev/null 2>&1; then
      success "Gateway saudável"
      break
    fi
    [ "$i" -eq 20 ] && warn "Gateway ainda não respondeu — tente manualmente"
    sleep 6
  done

  # Aplicar policies
  apply_policies "$GATEWAY_URL"

  # Criar sandboxes
  create_sandboxes "$GATEWAY_URL"

  echo ""
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║   Deploy OpenShift concluído!                           ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo ""
  echo "  OpenShell Gateway:  $GATEWAY_URL"
  echo "  Namespace:          openshell"
  echo ""
  echo "  Configurar CLI:"
  echo "    export OPENSHELL_GATEWAY=$GATEWAY_URL"
  echo ""
  echo "  Sandboxes:"
  echo "    openshell sandbox list"
  echo "    openshell sandbox connect qiskit-expert"
  echo ""
  echo "  Dashboard:"
  echo "    openshell term"
}

# ═══════════════════════════════════════════════════════════════════════════
# Entry point
# ═══════════════════════════════════════════════════════════════════════════
case "$MODE" in
  local)      install_local ;;
  openshift)  install_openshift ;;
  *)
    echo "Uso: $0 [local|openshift]"
    echo "  local:     Docker Compose (desenvolvimento)"
    echo "  openshift: Helm no cluster OpenShift (produção)"
    exit 1
    ;;
esac
