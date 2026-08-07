# Setup Local — OpenClaw + Ollama + llama-qiskit-agents

Stack completa rodando em Docker Compose, sem OpenShift, sem cloud, sem custo.

---

## O que sobe

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| `ollama` | 11434 | Serve o modelo LLM localmente |
| `qiskit-api` | 8080 | API REST de encoding quântico (llama-qiskit-agents) |
| `openclaw` | 18789 | Interface de chat com 3 agentes |

---

## Pré-requisitos

- **Docker Desktop** (Mac/Windows) ou **Docker Engine** (Linux)
- **Python 3** (para gerar o token; já instalado na maioria dos sistemas)
- RAM suficiente para o modelo escolhido:

| Modelo | RAM mínima | Observação |
|--------|-----------|------------|
| `qwen2.5-coder:7b` | 8 GB | Leve, bom para testar |
| `qwen2.5-coder:14b` | 16 GB | **Recomendado** — código Qiskit |
| `mistral-small3.2:24b` | 24 GB | Melhor raciocínio geral, 128K context |

---

## Início rápido (1 comando)

```bash
cd openclaw-openshift/local

# Com o modelo padrão (qwen2.5-coder:14b)
./setup.sh

# Ou escolha o modelo:
./setup.sh mistral-small3.2:24b
./setup.sh qwen2.5-coder:7b
```

O script:
1. Verifica RAM disponível
2. Gera token do gateway automaticamente
3. Cria o `.env`
4. Faz `docker compose up --build`
5. Baixa o modelo via Ollama (na primeira vez, pode levar vários minutos)
6. Exibe a URL de acesso com o token

---

## Início manual (passo a passo)

### 1. Configurar o `.env`

```bash
cp .env.example .env
```

Edite o `.env`:
```bash
# Modelo desejado
OPENCLAW_MODEL=qwen2.5-coder:14b

# Gere um token seguro:
# python3 -c "import secrets; print(secrets.token_urlsafe(32))"
OPENCLAW_GATEWAY_TOKEN=<seu-token-aqui>
```

Atualize também o token no `config/openclaw.json`:
```bash
sed -i '' 's/local-dev-token-change-me/<seu-token-aqui>/g' config/openclaw.json
```

### 2. Subir a stack

```bash
docker compose up -d --build
```

### 3. Baixar o modelo

```bash
# Verificar quando o Ollama estiver pronto:
docker compose logs ollama | grep "Ollama is running"

# Baixar o modelo (o model-puller faz isso automaticamente, mas pode forçar):
docker compose exec ollama ollama pull qwen2.5-coder:14b
```

O download é feito uma única vez — o volume `quantum-ollama-data` persiste entre restarts.

### 4. Acessar

```bash
# Ver URL e token:
docker compose logs openclaw | grep -i token

# Acesse no navegador:
http://localhost:18789/?token=<seu-token>
```

---

## Estrutura de arquivos

```
local/
├── docker-compose.yml              # Orquestra Ollama + qiskit-api + openclaw
├── .env.example                    # Template de variáveis de ambiente
├── .env                            # Criado pelo setup.sh (não commitado)
├── setup.sh                        # Script de setup automático
├── LOCAL-SETUP.md                  # Este arquivo
└── config/
    ├── openclaw.json               # Config do OpenClaw (modelos, agentes, cron)
    ├── cron/
    │   └── jobs.json               # Cron jobs (benchmark diário — desabilitado por padrão)
    └── agents/
        ├── meu_agente/             # Agente genérico (padrão)
        │   ├── AGENTS.md
        │   ├── SOUL.md
        │   ├── IDENTITY.md
        │   └── agent.json
        ├── quantum_news/           # Monitor de notícias quânticas
        │   ├── AGENTS.md
        │   ├── SOUL.md
        │   ├── IDENTITY.md
        │   └── agent.json
        └── quantum_encoding/       # QiskitAgent — encoding de dados QML
            ├── AGENTS.md           # Instruções de uso da API qiskit-api
            ├── SOUL.md
            ├── IDENTITY.md
            └── agent.json
```

---

## Os 3 agentes disponíveis

### `meu_agente` (padrão)
Assistente genérico em português. É o agente que responde por padrão.

### `quantum_news`
Especialista em computação quântica. Responde perguntas sobre hardware, algoritmos,
correção de erros e criptografia pós-quântica.

### `quantum_encoding` — QiskitAgent
O mais especializado. Conecta ao `qiskit-api` para:
- Analisar perfil estrutural do seu dataset
- Recomendar o encoding quântico ideal com justificativa técnica
- Gerar o circuito Qiskit correspondente (diagrama ASCII)
- Simular via AerSimulator e interpretar o histograma

**Exemplos de perguntas:**
```
"Tenho 5 features contínuas e quero usar QSVM. Qual encoding usar?"
"Compare todos os encodings para esses dados: [0.1, 0.2, 0.3, 0.4]"
"Gera o circuito de angle encoding para [0.5, 0.7, 0.3]"
"Quais são os trade-offs entre amplitude e data_reuploading?"
```

---

## Trocar de modelo sem perder dados

Os volumes (`quantum-ollama-data` e `quantum-openclaw-data`) persistem entre trocas de modelo.

```bash
# Trocar para Mistral:
./setup.sh mistral-small3.2:24b

# Ou edite o .env manualmente e reinicie:
# OPENCLAW_MODEL=mistral-small3.2:24b
docker compose up -d
```

Para usar modelos diferentes por agente, edite `config/openclaw.json` e altere
`model.primary` por agente (ex: `"ollama/mistral-small3.2:24b"` só para `quantum_encoding`).

---

## Comandos úteis

```bash
# Ver logs em tempo real
docker compose logs -f

# Logs de um serviço específico
docker compose logs -f openclaw
docker compose logs -f qiskit-api
docker compose logs -f ollama

# Listar modelos baixados no Ollama
docker compose exec ollama ollama list

# Testar a API qiskit diretamente
curl -s http://localhost:8080/healthz
curl -s -X POST http://localhost:8080/v1/recommend \
  -H "Content-Type: application/json" \
  -d '{"data": [0.1, 0.2, 0.3, 0.4, 0.5], "task": "kernel", "algorithm": "QSVM"}'

# Parar tudo (preserva volumes)
docker compose down

# Parar e apagar volumes (reset total)
docker compose down -v

# Rebuild da imagem qiskit-api após mudanças no código
docker compose up -d --build qiskit-api
```

---

## Ativar o cron job de benchmark

O job `qiskit-benchmark-daily` está desabilitado por padrão (`"enabled": false`).
Para ativar, edite `config/cron/jobs.json`:

```json
"enabled": true
```

E reinicie o OpenClaw para recarregar:
```bash
docker compose restart openclaw
```

---

## Diferenças em relação ao setup OpenShift

| Aspecto | Local (Docker Compose) | OpenShift |
|---------|----------------------|-----------|
| LLM | Ollama local | vLLM (RHOAI) |
| URL do qiskit-api | `http://qiskit-api:8080` | `http://llama-qiskit-agents.openclaw.svc:8080` |
| Autenticação | Token na URL | OAuth proxy + token |
| TLS | Sem TLS (HTTP) | HTTPS (edge + reencrypt) |
| Persistência | Volumes Docker | PVC ReadWriteOnce |
| Cron jobs | Habilitado mas desativado por padrão | Habilitado e ativo |

---

## Solução de problemas

### OpenClaw não abre no navegador

```bash
docker compose logs openclaw | tail -30
```
Verifique se o token no navegador é o mesmo do `.env`.

### Modelo muito lento ou travado

O Ollama usa CPU se não houver GPU. Para Mac com Apple Silicon:
- O Ollama usa Metal automaticamente — não precisa de configuração extra.
- Para Linux com NVIDIA: descomente o bloco `deploy.resources` no `docker-compose.yml`.

### qiskit-api em CrashLoopBackOff / restart

```bash
docker compose logs qiskit-api
```
Provável causa: `build-essential` ausente ou timeout no build. Rebuild:
```bash
docker compose build qiskit-api --no-cache
docker compose up -d qiskit-api
```

### Resetar completamente

```bash
docker compose down -v
rm .env
./setup.sh
```
