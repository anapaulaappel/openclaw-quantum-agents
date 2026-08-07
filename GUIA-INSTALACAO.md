# Guia de Instalação do OpenClaw no OpenShift

## O que é o OpenClaw?

OpenClaw é um assistente de IA pessoal open source. Ele roda na sua própria infraestrutura,
conecta a provedores de modelos (vLLM local, OpenAI, Anthropic, etc.) e integra com canais
de mensagens (WhatsApp, Telegram, Slack, Discord, e outros).

---

## O que você vai precisar antes de começar

1. **Acesso a um cluster OpenShift** (não precisa ser admin do cluster, mas precisa poder criar namespaces)
2. **Ferramenta `oc` instalada** no seu computador ([download aqui](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/))
3. **vLLM já deployado no cluster** com o modelo `llama-32-3b-instruct`
   - Endpoint interno: `http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local/v1`
   - Sem chave de API necessária (acesso aberto dentro do cluster)
4. **Imagem do `llama-qiskit-agents` publicada** (para o agente QiskitAgent)
   - Ver seção [Build e Deploy do llama-qiskit-agents](#build-e-deploy-do-llama-qiskit-agents) abaixo

---

## Passo 1 — Fazer login no OpenShift

```bash
oc login --server=https://<ENDERECO_DO_SEU_CLUSTER>:6443
```

**Verificar se funcionou:**
```bash
oc whoami
```

---

## Passo 2 — Editar os arquivos de configuração

Antes de aplicar, substitua os valores entre `<>` em **3 arquivos**:

### Gerar os tokens (rode no seu Mac)

```bash
# Token do Gateway (use o mesmo nos dois arquivos abaixo)
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Cookie do OAuth proxy (diferente do anterior)
python3 -c "import secrets; print(secrets.token_hex(16))"

# Descobrir o domínio do cluster
oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'
```

### `02-secrets.yaml`
- `<SEU_TOKEN_GATEWAY_AQUI>` → token gerado acima

### `04-configmap-openclaw.yaml`
- `<SEU_TOKEN_GATEWAY_AQUI>` → o mesmo token
- `<SEU_DOMINIO_OPENSHIFT>` → domínio do cluster (ex: `ocp.g8hb6.sandbox2571.opentlc.com`)

### `09-secret-oauth-proxy.yaml`
- `<GERE_UM_VALOR_ALEATORIO_AQUI>` → segundo valor gerado acima

---

## Passo 3 — Build e Deploy do llama-qiskit-agents

O agente `quantum_encoding` depende do microserviço `llama-qiskit-agents` rodando no cluster.
Faça o build antes de aplicar o deployment principal:

```bash
cd llama-qiskit-agents   # diretório do projeto quantum

# Criar o BuildConfig no cluster (só na primeira vez)
oc new-build --name=llama-qiskit-agents --binary -n openclaw

# Build da imagem a partir do código local
oc start-build llama-qiskit-agents --from-dir=. --follow -n openclaw

# Aplicar os manifests do microserviço
cd deploy/openshift
oc apply -f service.yaml
oc apply -f route.yaml
oc apply -f deployment.yaml

# Verificar se subiu
oc get pods -n openclaw -l app=llama-qiskit-agents -w
```

Aguarde até `1/1 Running`. Teste a API internamente:

```bash
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  curl http://llama-qiskit-agents.openclaw.svc.cluster.local:8080/healthz
```

Esperado: `{"status":"ok","service":"llama-qiskit-agents"}`

---

## Passo 4 — Aplicar os YAMLs do OpenClaw

Execute na ordem:

```bash
cd openclaw-openshift

# 1. Criar o namespace
oc apply -f 00-namespace.yaml
oc project openclaw

# 2. Storage, secrets e permissões
oc apply -f 01-pvc.yaml
oc apply -f 02-secrets.yaml
oc apply -f 09-secret-oauth-proxy.yaml
oc apply -f 03-serviceaccount.yaml
oc apply -f 13-clusterrolebinding-oauth.yaml

# 3. Configurações
oc apply -f 04-configmap-openclaw.yaml
oc apply -f 05-configmap-agent.yaml
oc apply -f 05-configmap-agent-quantum.yaml
oc apply -f 05-configmap-agent-qiskit.yaml
oc apply -f 06-configmap-agent-tree.yaml
oc apply -f 07-configmap-skills.yaml
oc apply -f 08-configmap-cron.yaml

# 4. Rede e aplicação
oc apply -f 11-service.yaml
oc apply -f 12-route.yaml
oc apply -f 10-deployment.yaml
```

---

## Passo 5 — Aguardar o pod subir

```bash
oc get pods -n openclaw -w
```

Aguarde até aparecer `2/2 Running` com `0 RESTARTS`.

Se aparecer erro, veja os logs:
```bash
oc logs -n openclaw deployment/openclaw -c gateway
oc logs -n openclaw deployment/openclaw -c oauth-proxy
oc logs -n openclaw deployment/openclaw -c init-config
```

---

## Passo 6 — Descobrir a URL de acesso

```bash
oc get route openclaw -n openclaw
```

---

## Passo 7 — Acessar o OpenClaw

Acesse no navegador com o token na URL:

```
https://openclaw-openclaw.apps.<SEU_DOMINIO>/?token=<SEU_TOKEN_GATEWAY>
```

---

## Estrutura dos arquivos

```
openclaw-openshift/
├── 00-namespace.yaml                  # Projeto/namespace isolado
├── 01-pvc.yaml                        # Volume persistente (10Gi) para dados do agente
├── 02-secrets.yaml                    # Token do gateway + OPENAI_API_KEY=dummy (para vLLM)
├── 03-serviceaccount.yaml             # Identidade do pod para OAuth
├── 04-configmap-openclaw.yaml         # Configuração principal (modelo, agentes, vLLM)
├── 05-configmap-agent.yaml            # Personalidade do agente genérico (meu_agente)
├── 05-configmap-agent-quantum.yaml    # Personalidade do agente de quantum computing (quantum_news)
├── 05-configmap-agent-qiskit.yaml     # Personalidade do QiskitAgent (quantum_encoding)
├── 06-configmap-agent-tree.yaml       # Workspaces extras (vazio por padrão)
├── 07-configmap-skills.yaml           # Skills extras (vazio por padrão)
├── 08-configmap-cron.yaml             # Jobs agendados (quantum daily/weekly + qiskit benchmark)
├── 09-secret-oauth-proxy.yaml         # Cookie secreto do proxy OAuth
├── 10-deployment.yaml                 # Pod principal (init + oauth-proxy + gateway)
├── 11-service.yaml                    # Rede interna do cluster
├── 12-route.yaml                      # Acesso externo HTTPS
└── 13-clusterrolebinding-oauth.yaml   # Permissão para o OAuth proxy

# Manifests do microserviço llama-qiskit-agents (em llama-qiskit-agents/deploy/openshift/):
├── deployment.yaml                    # Pod da API quantum (namespace openclaw)
├── service.yaml                       # ClusterIP :8080
└── route.yaml                         # Route HTTPS opcional (acesso externo direto)
```

---

## Decisões importantes aprendidas

| Problema | Solução |
|----------|---------|
| `baseURL` inválido | A chave correta é `baseUrl` dentro de `models.providers` (não dentro de `agents`) |
| `gateway.mode` ausente | O init container deve sobrescrever **tanto** `openclaw.json` **quanto** `openclaw.json.last-good` no PVC |
| JSON truncado no ConfigMap | Usar `oc create configmap --from-literal` em vez de YAML inline longo |
| Device pairing | Usar `"dangerouslyDisableDeviceAuth": true` no `controlUi` do config |
| vLLM sem auth | Usar `OPENAI_API_KEY=dummy` — o vLLM ignora o header de autenticação |
| Acesso via navegador | Passar o token na URL: `?token=<TOKEN>` |

---

## Solução de problemas

### Pod em CrashLoopBackOff

```bash
oc logs -n openclaw deployment/openclaw -c gateway
```

### Testar conectividade com o vLLM

```bash
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  curl http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local/v1/models
```

### PVC com permissão errada

Use um pod temporário com o mesmo UID do container (`1000900000`):

```bash
oc run fix -n openclaw \
  --image=registry.access.redhat.com/ubi9-minimal:latest \
  --restart=Never \
  --overrides='{
    "spec": {
      "securityContext": {"runAsUser": 1000900000},
      "volumes": [
        {"name": "home", "persistentVolumeClaim": {"claimName": "openclaw-home-pvc"}},
        {"name": "cfg", "configMap": {"name": "openclaw-config"}}
      ],
      "containers": [{
        "name": "fix",
        "image": "registry.access.redhat.com/ubi9-minimal:latest",
        "command": ["sh", "-c", "cp /cfg/openclaw.json /home/node/.openclaw/openclaw.json && cp /cfg/openclaw.json /home/node/.openclaw/openclaw.json.last-good && echo OK"],
        "volumeMounts": [
          {"name": "home", "mountPath": "/home/node/.openclaw"},
          {"name": "cfg", "mountPath": "/cfg"}
        ]
      }]
    }
  }'

oc logs fix -n openclaw
oc delete pod fix -n openclaw
oc delete pod -n openclaw -l app=openclaw
```

---

## Agentes configurados

Esta instância roda com **3 agentes** isolados no mesmo Gateway:

### meu_agente (padrão)

Assistente pessoal genérico. É o agente que responde quando nenhum outro é
especificado. Responde em português e ajuda com tarefas gerais de IA e automação.

### quantum_news — Monitor de Computação Quântica

Agente especializado que monitora notícias e avanços em computação quântica.
Funciona como um curador de conteúdo automatizado.

**Áreas de foco:**
- Hardware quântico (IBM, Google, IonQ, Quantinuum, PsiQuantum, etc.)
- Algoritmos quânticos e machine learning quântico
- Correção de erros (fault-tolerance, logical qubits)
- Criptografia pós-quântica (padrões NIST)
- Aplicações industriais (farmacêutica, finanças, materiais)

**Cron jobs automáticos:**

| Job | Frequência | Horário (BRT) | O que faz |
|-----|------------|---------------|-----------|
| `quantum-daily` | Seg–Sex | 07:00 | Resumo diário das últimas 24h em quantum computing |
| `quantum-weekly` | Segunda | 08:00 | Relatório semanal aprofundado com análise de tendências |

**Arquivos de configuração:**
- `05-configmap-agent-quantum.yaml` — Personalidade e instruções
- `08-configmap-cron.yaml` — Jobs agendados

### quantum_encoding — QiskitAgent

Agente especializado em **encoding de dados para Quantum Machine Learning**. Ele usa
a API interna do `llama-qiskit-agents` para analisar datasets, recomendar estratégias
de encoding, gerar circuitos Qiskit e simular via AerSimulator — tudo sem hardware
quântico real.

**Capacidades:**
- Analisa perfil do dado (dimensão, tipo, distribuição)
- Recomenda o melhor entre 5 encodings (amplitude, angle, basis, data_reuploading, custom_feature_map)
- Justifica a escolha citando características concretas (n_features, qubits, profundidade)
- Gera diagrama ASCII do circuito Qiskit
- Simula e interpreta histograma de medições quânticas

**Modelo LLM:** Por padrão usa `llama-32-3b-instruct`. Para melhor desempenho em geração
de código Qiskit, substitua por `qwen2.5-coder-14b` ou `mistral-small-3.2-24b` quando
disponíveis no cluster. Ver instruções em `04-configmap-openclaw.yaml`.

**Cron job automático:**

| Job | Frequência | Horário (BRT) | O que faz |
|-----|------------|---------------|-----------|
| `qiskit-benchmark-daily` | Seg–Sex | 08:00 | Benchmark de encodings com datasets de exemplo |

**Arquivos de configuração:**
- `05-configmap-agent-qiskit.yaml` — Personalidade e instruções de uso da API
- `08-configmap-cron.yaml` — Job de benchmark diário

**Dependência:** requer o microserviço `llama-qiskit-agents` rodando no cluster.

---

## Aplicando os ConfigMaps dos agentes

```bash
# Na primeira instalação (junto com os outros configmaps)
oc apply -f 05-configmap-agent-quantum.yaml
oc apply -f 05-configmap-agent-qiskit.yaml

# Para atualizar a personalidade de qualquer agente:
oc apply -f 05-configmap-agent-qiskit.yaml
oc delete pod -n openclaw -l app=openclaw  # reiniciar para recarregar
```

---

## Verificando os cron jobs

Após o pod subir, os cron jobs aparecem no log do gateway:

```bash
# Ver se o cron está ativo
oc logs -n openclaw deployment/openclaw -c gateway | grep -i cron

# Listar jobs configurados
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  openclaw cron list

# Forçar execução manual de um job
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  openclaw cron run quantum-daily

oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  openclaw cron run qiskit-benchmark-daily
```

---

## Trocar o modelo do QiskitAgent (Qwen ou Mistral)

Quando você implantar `qwen2.5-coder-14b` ou `mistral-small-3.2-24b` no OpenShift AI:

1. Descubra o endpoint do predictor:
   ```bash
   oc get inferenceservice -n <namespace-do-modelo>
   ```

2. Edite `04-configmap-openclaw.yaml`:
   - Descomente o bloco `vllm-qiskit` em `models.providers`
   - Preencha `baseUrl` com o endpoint do predictor (porta 8080)
   - Troque `"primary": "vllm-local/llama-32-3b-instruct"` para
     `"primary": "vllm-qiskit/qwen2.5-coder-14b"` no agente `quantum_encoding`

3. Aplique e reinicie:
   ```bash
   oc apply -f 04-configmap-openclaw.yaml
   # O openclaw.json no PVC já existe, então é necessário forçar atualização:
   oc exec -it deployment/openclaw -n openclaw -c gateway -- \
     cp /dev/stdin /home/node/.openclaw/openclaw.json < 04-configmap-data.json
   oc delete pod -n openclaw -l app=openclaw
   ```

---

## Testar o QiskitAgent manualmente

```bash
# Verificar se o microserviço está acessível de dentro do pod OpenClaw
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  curl -s http://llama-qiskit-agents.openclaw.svc.cluster.local:8080/healthz

# Testar recomendação de encoding
oc exec -it deployment/openclaw -n openclaw -c gateway -- \
  curl -s -X POST \
    http://llama-qiskit-agents.openclaw.svc.cluster.local:8080/v1/recommend \
    -H "Content-Type: application/json" \
    -d '{"data": [0.1, 0.2, 0.3, 0.4, 0.5], "task": "kernel", "algorithm": "QSVM"}'
```
