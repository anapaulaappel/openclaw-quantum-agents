# OpenShell — Quantum Encoding Agents

Integração dos agentes quânticos com o **NVIDIA OpenShell** —
runtime de segurança para agentes autônomos, com suporte oficial a Red Hat OpenShift.

---

## O que é o OpenShell

OpenShell é o runtime de segurança da NVIDIA para agentes autônomos:
cada agente roda em um **sandbox isolado**, com políticas de acesso aplicadas
no nível de OS (Landlock LSM + seccomp) — o agente não pode ver nem sobrescrever
sua própria política, mesmo se comprometido.

Componentes principais:

| Componente | Função |
|---|---|
| **Gateway** | Control plane: gerencia sandboxes, políticas e credenciais |
| **Sandbox** | Container isolado onde o agente roda sem modificação |
| **Policy Engine** | Valida políticas com Z3 SMT solver antes de aplicar |
| **Privacy Router** | Intercepta chamadas LLM, injeta credenciais sem expor ao agente |

Referência: [blogs.nvidia.com/blog/secure-autonomous-ai-agents-openshell](https://blogs.nvidia.com/blog/secure-autonomous-ai-agents-openshell/)

---

## Estrutura de arquivos

```
openshell/
├── policies/
│   ├── qiskit-expert.yaml     # Circuit — só API Qiskit + LLM, sem internet
│   ├── qiskit-mentor.yaml     # Quanta — adiciona arXiv + docs Qiskit (GET apenas)
│   └── quantum-encoding.yaml  # QiskitAgent — policy geral, permite upload CSV
├── helm/
│   └── values-openshift.yaml  # Overrides para instalação no OpenShift
├── local/
│   └── docker-compose.yml     # Stack de desenvolvimento local
├── install.sh                 # Script de install (local e OpenShift)
└── OPENSHELL-SETUP.md         # Este arquivo
```

---

## Pré-requisitos

```bash
# Instalar OpenShell CLI
curl -fsSL https://install.openshell.ai | sh
# ou
uv tool install -U openshell

# Verificar
openshell --version
```

---

## Setup Local (desenvolvimento)

```bash
cd openshell

# 1. Subir stack (Gateway + Ollama + API Qiskit)
./install.sh local

# Ou manualmente:
docker compose -f local/docker-compose.yml up -d

# 2. Verificar gateway
curl http://localhost:8081/healthz

# 3. Aplicar policies
openshell policy set qiskit-expert --policy policies/qiskit-expert.yaml --wait
openshell policy set qiskit-mentor --policy policies/qiskit-mentor.yaml --wait
openshell policy set quantum-encoding --policy policies/quantum-encoding.yaml --wait

# 4. Criar sandboxes (OpenClaw dentro do OpenShell)
openshell sandbox create --name qiskit-expert   --policy qiskit-expert   --from openclaw
openshell sandbox create --name qiskit-mentor   --policy qiskit-mentor   --from openclaw
openshell sandbox create --name quantum-encoding --policy quantum-encoding --from openclaw

# 5. Ver sandboxes ativos
openshell sandbox list

# 6. Conectar a um sandbox
openshell sandbox connect qiskit-expert
```

---

## Deploy OpenShift (produção)

```bash
cd openshell

# 1. Login no cluster
oc login --server=https://<SEU_CLUSTER>:6443

# 2. Deploy completo via script
./install.sh openshift

# Ou manualmente:

# Criar namespace
oc create ns openshell

# Conceder SCC (necessário para Landlock + seccomp)
oc adm policy add-scc-to-user privileged -z openshell-sandbox -n openshell

# Instalar via Helm
helm upgrade --install openshell \
  oci://ghcr.io/nvidia/openshell/helm-chart \
  --version latest \
  -n openshell \
  -f helm/values-openshift.yaml \
  --wait

# Criar Route
oc expose service openshell-gateway -n openshell --name openshell-gateway

# Configurar CLI
export OPENSHELL_GATEWAY="https://$(oc get route openshell-gateway -n openshell -o jsonpath='{.spec.host}')"

# Aplicar policies
openshell policy set qiskit-expert   --policy policies/qiskit-expert.yaml   --wait
openshell policy set qiskit-mentor   --policy policies/qiskit-mentor.yaml   --wait
openshell policy set quantum-encoding --policy policies/quantum-encoding.yaml --wait

# Criar sandboxes
openshell sandbox create --name qiskit-expert   --policy qiskit-expert   --from openclaw
openshell sandbox create --name qiskit-mentor   --policy qiskit-mentor   --from openclaw
openshell sandbox create --name quantum-encoding --policy quantum-encoding --from openclaw
```

---

## O que cada policy controla

### `qiskit-expert.yaml` — Circuit (expert)

**Princípio: acesso mínimo.** Circuit só precisa de simulação — sem internet.

| Recurso | Acesso |
|---|---|
| API Qiskit (`llama-qiskit-agents`) | GET + POST em `/v1/*` |
| LLM (vLLM / Ollama) | POST em `/v1/chat/completions` apenas |
| arXiv, GitHub, PyPI | **Bloqueado** |
| Internet geral | **Bloqueado** |
| Filesystem do host | **Bloqueado** (só `/sandbox` e `/tmp`) |
| Privilege escalation | **Bloqueado** |

### `qiskit-mentor.yaml` — Quanta (mentor)

**Adiciona acesso de leitura a recursos acadêmicos** — Quanta busca papers para citar.

| Recurso | Acesso |
|---|---|
| API Qiskit | GET + POST em `/v1/*` |
| LLM | POST em `/v1/chat/completions` apenas |
| arXiv (`arxiv.org`) | GET apenas (`/abs/*`, `/pdf/*`, `/search/*`) |
| Docs Qiskit (`docs.quantum.ibm.com`) | GET apenas |
| GitHub, PyPI, internet geral | **Bloqueado** |

### `quantum-encoding.yaml` — QiskitAgent (geral)

**Policy intermediária** — igual a Circuit em rede, mas permite upload CSV via `/tmp`.

---

## Diferença entre OpenShell e deploy tradicional OpenShift

| Aspecto | Deploy tradicional (K8s/OpenShift) | Com OpenShell |
|---|---|---|
| Isolamento | Namespace + NetworkPolicy | Sandbox por agente + Landlock LSM |
| Políticas de rede | IP/port level | HTTP method + path level por binário |
| Credenciais | Env vars no pod (visíveis ao agente) | Privacy Router injeta sem expor ao agente |
| Validação de policy | Nenhuma (YAML sem verificação) | Z3 SMT solver — verificação formal |
| Atualização de policy | Redeploy do pod | Hot-reload sem reiniciar o agente |
| Auditoria | Logs do pod | Event stream por ação do agente |

---

## Comandos úteis

```bash
# Ver policies aplicadas
openshell policy get qiskit-expert
openshell policy get qiskit-mentor

# Ver logs de um sandbox (ações do agente)
openshell logs qiskit-expert --tail

# Dashboard TUI (k9s-style)
openshell term

# Verificar se uma ação seria permitida (sem executar)
openshell policy check qiskit-expert \
  --binary /usr/bin/curl \
  --destination arxiv.org:443 \
  --method GET

# Atualizar policy sem reiniciar o sandbox
openshell policy set qiskit-mentor \
  --policy policies/qiskit-mentor.yaml \
  --wait

# Conectar ao sandbox via SSH
openshell sandbox connect qiskit-expert

# Apagar todos os sandboxes
openshell sandbox list | awk 'NR>1{print $1}' | xargs -I{} openshell sandbox delete {}
```

---

## Troubleshooting

### `SCC validation failed` no OpenShift

```bash
oc adm policy add-scc-to-user privileged -z openshell-sandbox -n openshell
# Se falhar por falta de permissão, peça ao admin do cluster
```

### `Landlock compatibility: strict` falha no RHCOS

Use `compatibility: best_effort` nas policies (já configurado nos YAMLs deste repo).
RHCOS pode ter Landlock parcial dependendo da versão do kernel.

### Sandbox não consegue chamar a API Qiskit

```bash
# Verificar se a policy está correta
openshell policy get quantum-encoding

# Testar a regra específica
openshell policy check quantum-encoding \
  --binary /usr/bin/curl \
  --destination llama-qiskit-agents.openclaw.svc.cluster.local:8080 \
  --method POST \
  --path /v1/recommend/explain
```

### Gateway não responde

```bash
# Local
docker compose -f local/docker-compose.yml logs openshell-gateway

# OpenShift
oc logs -n openshell deployment/openshell-gateway
```
