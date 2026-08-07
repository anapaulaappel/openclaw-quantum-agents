# Demo Guide — Quantum Encoding Agents com OpenClaw

**Ambiente:** Local (Docker Compose + Ollama)  
**Formato:** Live coding no chat do OpenClaw  
**Audiência:** Comunidade / conferência (mix técnico + curioso)  
**Duração estimada:** 20–30 min (completo) | 10 min (versão curta)

---

## Antes de começar — Checklist

Execute isso **no dia anterior** e **30 minutos antes** da apresentação:

```bash
cd openclaw-openshift/local

# 1. Subir a stack
./setup.sh                            # ou ./setup.sh qwen2.5-coder:7b se RAM < 16 GB

# 2. Verificar que tudo está UP
docker compose ps
# Esperado: ollama Running, qiskit-api Running, openclaw Running

# 3. Verificar a API quantum
curl -s http://localhost:8080/healthz
# Esperado: {"status":"ok","service":"llama-qiskit-agents"}

# 4. Fazer uma chamada de aquecimento (carrega o modelo na memória)
curl -s -X POST http://localhost:8080/v1/recommend/explain \
  -H "Content-Type: application/json" \
  -d '{"data": [0.1, 0.2, 0.3], "description": "dados continuos"}' > /dev/null

# 5. Abrir o OpenClaw no navegador
open "http://localhost:18789/?token=$(grep OPENCLAW_GATEWAY_TOKEN .env | cut -d= -f2)"
```

**Mantenha aberto:**
- Navegador com OpenClaw (tab 1)
- Terminal com `docker compose logs -f qiskit-api` (para mostrar as chamadas em tempo real, opcional)
- Este arquivo como referência (tab separado, fora da tela principal)

---

## Estrutura da demo

```
Ato 1 — Contexto (2 min)
  Por que quantum encoding? O problema que estamos resolvendo.

Ato 2 — O agente para iniciantes: Quanta (8 min)
  Mostra como o agente constrói intuição física antes do código.

Ato 3 — O agente para experts: Circuit (8 min)
  Mesma pergunta, resposta completamente diferente.

Ato 4 — O contraste (3 min)
  Lado a lado: o que muda na alma do agente, não só na resposta.

Ato 5 — Encerramento / Q&A (5 min)
  Arquitetura rápida + próximos passos.
```

---

## Ato 1 — Contexto (fale isso, não precisa digitar nada)

> "Quantum Machine Learning tem um problema de entrada que raramente é discutido:
> como você coloca dados clássicos dentro de um circuito quântico?
> Isso se chama quantum encoding, e a escolha errada pode desperdiçar todos os
> seus qubits ou tornar o circuito profundo demais para rodar em hardware real.
>
> Hoje vou mostrar dois agentes de IA que ajudam a tomar essa decisão —
> mas com personalidades completamente diferentes, dependendo de quem está perguntando.
> Os dois usam o mesmo backend: um simulador Qiskit rodando localmente.
> O que muda é a alma de cada agente."

---

## Ato 2 — Quanta, a professora (agente `qiskit_mentor`)

### Setup
No OpenClaw, selecione o agente **Quanta** na lista de agentes.

### Cena 2.1 — Primeira pergunta: dados em português

**Digite no chat:**
```
tenho um dataset com 5 features contínuas e quero treinar um modelo de classificação quântica. que encoding devo usar?
```

**O que Quanta deve fazer:**
- Detectar PT-BR automaticamente
- Descrever o que "5 features contínuas" implica para o mundo quântico
- Explicar o encoding recomendado com contexto físico (esfera de Bloch, ângulos)
- Mostrar as métricas do circuito: N qubits, profundidade D
- Apresentar o código Qiskit com explicação das seções

**O que falar enquanto a resposta aparece:**
> "Reparem que o agente não começa com o código — ele começa explicando
> o que está acontecendo fisicamente com os dados. Essa é a alma da Quanta:
> intuição antes de implementação."

**Ponto de atenção:** Se a resposta vier em inglês, a detecção de idioma ajustou
com base nas palavras. Tudo bem — mencione que o agente detecta o idioma automaticamente.

---

### Cena 2.2 — Pergunta conceitual (sem dados)

**Digite no chat:**
```
o que é amplitude encoding e quando não devo usar?
```

**O que Quanta deve fazer:**
- Dar a intuição geométrica primeiro (estado como vetor de amplitudes)
- A definição matemática: |ψ⟩ = Σ xᵢ|i⟩, com ‖x‖=1
- Quando usar (vetor denso, poucos qubits necessários)
- Quando NÃO usar: circuito de preparação de estado é profundo; em hardware real com poucos qubits e muita profundidade, o erro acumulado destrói a fidelidade

**O que falar:**
> "Ela não chamou a API aqui — respondeu com conhecimento próprio.
> O agente sabe quando o contexto é conceitual e quando precisa simular."

---

### Cena 2.3 — Pergunta com dados numéricos em inglês

**Digite no chat:**
```
I have binary data: [1, 0, 1, 1, 0, 0, 1, 0]. I want to classify items.
```

**O que Quanta deve fazer:**
- Mudar para inglês automaticamente
- Identificar dados binários → basis encoding
- Explicar que cada bit mapeia para |0⟩ ou |1⟩ na base computacional
- Mostrar que o circuito usa apenas portas X (profundidade mínima)
- Dar o código

**O que falar:**
> "Mudei para inglês — e o agente mudou junto, sem configuração.
> Agora reparem na escolha: basis encoding. Circuito mínimo.
> Portas X simples. Quanta explicou por que dados binários não precisam
> de superposição no encoding — eles já são estados da base."

---

## Ato 3 — Circuit, o engenheiro (agente `qiskit_expert`)

### Setup
Selecione o agente **Circuit** na lista de agentes.

### Cena 3.1 — A mesma primeira pergunta

**Digite no chat:**
```
tenho um dataset com 5 features contínuas e quero treinar um modelo de classificação quântica. que encoding devo usar?
```

**O que Circuit deve fazer:**
- Resposta direta em 3 blocos:
  ```
  Encoding: <nome>
  Métricas: 5 qubits, profundidade <D>
  Razão: <1-2 frases com trade-off concreto>
  ```
- Código sem explicação das seções
- Se depth > 20: aviso de degradação de fidelidade em NISQ

**O que falar:**
> "Mesmo pergunta. Olhem a diferença. Circuit não explica o que é a esfera de Bloch.
> Ele vai direto: encoding, métricas, razão em duas frases.
> Se você já sabe o que é profundidade de circuito, você não precisa que
> o agente explique. A alma dele pressupõe isso."

---

### Cena 3.2 — Pergunta técnica direta

**Digite no chat:**
```
qual o trade-off entre data_reuploading e custom_feature_map para QSVM com 8 features?
```

**O que Circuit deve fazer:**
- Comparar diretamente as duas opções com métricas
- custom_feature_map: melhor para kernel implícito, mais profundo, CZ pareado
- data_reuploading: mais orientado a QNN/VQC, estrutura diferente de entrelaçamento
- Possivelmente citar Havlíček et al. (2019) para feature map e Pérez-Salinas et al. (2020) para re-uploading
- Apresentar como dois lados objetivos, não como recomendação

**O que falar:**
> "Reparem: ele não escolhe por mim. Apresenta os dois lados e devolve
> a decisão. Essa é uma escolha de design intencional na alma do agente —
> trade-offs são neutros quando a pessoa tem contexto para decidir."

---

### Cena 3.3 — Pergunta vaga (para mostrar o comportamento de Circuit)

**Digite no chat:**
```
qual encoding usar?
```

**O que Circuit deve fazer:**
- Pedir o que falta: `n_features`? conectividade do hardware alvo? função de custo? budget de profundidade?
- Não tentar adivinhar
- Não dar resposta genérica

**O que falar:**
> "Circuit recusou responder. Ele pediu o que precisa para dar uma resposta útil.
> Comparem com o que Quanta faria: ela teria pedido com contexto, explicando
> por que cada informação importa. Mesma ação, alma completamente diferente."

---

## Ato 4 — O contraste: a alma do agente

> "O que torna esses agentes diferentes não é o LLM — os dois usam o mesmo modelo.
> Não é a API — os dois chamam o mesmo endpoint `/v1/recommend/explain`.
> O que é diferente é o `SOUL.md` e o `AGENTS.md`: arquivos de texto que
> definem como o agente pensa, o que ele pressupõe sobre você,
> e o que ele nunca vai fazer."

Mostre no terminal (opcional, para audiência técnica):

```bash
# A alma da Quanta
cat openclaw-openshift/local/config/agents/qiskit_mentor/SOUL.md

# A alma do Circuit
cat openclaw-openshift/local/config/agents/qiskit_expert/SOUL.md
```

**Destaque estas linhas ao ler:**

De Quanta:
> *"A linha que você não cruza: analogias que mentem."*
> *"Você nunca usa o gato de Schrödinger para explicar superposição em QML."*

De Circuit:
> *"Você não explica o que é superposição. Você pressupõe que a pessoa
> sabe distinguir amplitude encoding de angle encoding sem precisar de definição."*
> *"Quando há trade-off real, você apresenta os dois lados sem escolher por ninguém."*

> "Isso é o que chamamos de soul engineering: não é prompt engineering clássico —
> é definir o caráter do agente, o que ele valoriza, o que ele recusa fazer,
> e como ele trata o conhecimento do interlocutor."

---

## Ato 5 — Arquitetura em 60 segundos

**Diagrama para mostrar (pode desenhar no quadro ou mostrar do CONTEXT.md):**

```
Você (chat OpenClaw)
        │
   [SOUL.md + AGENTS.md]   ← personalidade do agente
        │
    Modelo LLM
   (Qwen 14B / Ollama)
        │
        ├─── chama ──→  POST /v1/recommend/explain
        │                       │
        │               llama-qiskit-agents
        │               ├── infer_data_profile()
        │               ├── recommend_encoding()
        │               ├── build_natural_explanation()  ← detecta idioma
        │               ├── generate_qiskit_code()       ← código copiável
        │               └── simulate_encoding_circuit()  ← AerSimulator
        │
        └─── responde com:
             explanation + qiskit_code + métricas
```

> "Em produção, isso roda no OpenShift com vLLM. Localmente, roda com Ollama.
> O único componente que muda é o endpoint do modelo — o resto é idêntico."

---

## Versão curta (10 min)

Se o tempo for limitado, faça apenas:

1. **Cena 2.1** com Quanta (pergunta PT-BR com 5 features) — 3 min
2. **Cena 3.1** com Circuit (mesma pergunta) — 3 min
3. **Ato 4** mostrando os SOUL.md — 2 min
4. Diagrama de arquitetura — 2 min

Pule as cenas 2.2, 2.3, 3.2, 3.3.

---

## Plano B — se algo der errado

| Problema | O que fazer |
|----------|-------------|
| OpenClaw não carrega | `docker compose restart openclaw` e aguardar 20s |
| Agente não responde / trava | `docker compose logs -f openclaw` — se houver erro de conexão com Ollama, reiniciar: `docker compose restart ollama` |
| Ollama muito lento | Primeira resposta aquece o modelo. Segunda é mais rápida. Avise à audiência que é cold start. |
| API qiskit offline | `docker compose restart qiskit-api`. Enquanto aguarda: mostre o SOUL.md dos agentes no terminal. |
| Modelo baixando ainda | Se esqueceu de fazer `./setup.sh` antes: `docker compose exec ollama ollama pull qwen2.5-coder:14b` enquanto apresenta o contexto do Ato 1. |
| Demo no OpenShift caindo | Mude para local imediatamente. Diga: "vou mostrar a versão local, que é idêntica exceto pelo endpoint do LLM." |

---

## Perguntas frequentes da audiência

**"Qual é a diferença para o ChatGPT normal?"**
> "ChatGPT é stateless — não tem SOUL.md, não tem ferramenta de simulação quântica,
> não detecta que você quer profundidade vs. simplicidade. Aqui o agente tem uma
> função específica, chama uma API real que executa código Qiskit, e tem um caráter
> definido que persiste em toda a conversa."

**"Por que Qiskit e não Pennylane?"**
> "Qiskit tem o ecossistema mais maduro para simulação local com Aer.
> A arquitetura é agnóstica — trocar o backend de simulação não muda os agentes."

**"O código gerado realmente roda?"**
> Mostre ao vivo: copie o código da resposta do agente e cole num terminal Python.
> ```bash
> python3 -c "<cole o código aqui>"
> ```
> Deve imprimir o diagrama do circuito e as contagens de medição.

**"Quanto custa rodar isso?"**
> "Local: zero. O modelo roda na sua máquina com Ollama.
> No OpenShift com vLLM: custo de infraestrutura apenas, sem API key externa."

**"Como funciona a detecção de idioma?"**
> "Comparação de vocabulário — sem chamada a API externa, sem modelo separado.
> Pesado o suficiente para separar PT-BR de EN em frases naturais sobre QML."

---

## Frases de abertura e fechamento

**Abertura sugerida:**
> "Vou mostrar como dois agentes respondem exatamente a mesma pergunta de formas
> completamente diferentes — não porque um é mais inteligente, mas porque eles têm
> almas diferentes. Um pressupõe que você já sabe quantum. O outro constrói
> intuição do zero sem condescendência. Os dois são corretos. A diferença é quem
> está do outro lado."

**Fechamento sugerido:**
> "O que levo daqui: agentes especializados não são sobre ser mais espertos —
> são sobre saber com quem estão falando. A alma do agente é o que define
> isso. E `SOUL.md` é literalmente um arquivo de texto que você pode editar
> em cinco minutos. O código, a API, o cluster — tudo isso é infraestrutura.
> A alma é o produto."

---

## Comandos de referência rápida

```bash
# Subir a stack
cd openclaw-openshift/local && ./setup.sh

# Ver token de acesso
grep OPENCLAW_GATEWAY_TOKEN .env

# URL do OpenClaw
http://localhost:18789/?token=<TOKEN>

# Testar API diretamente
curl -s -X POST http://localhost:8080/v1/recommend/explain \
  -H "Content-Type: application/json" \
  -d '{
    "data": [0.31, 0.72, 0.55, 0.18, 0.9],
    "description": "features contínuas para QSVM",
    "algorithm": "QSVM"
  }' | python3 -m json.tool

# Logs em tempo real
docker compose logs -f qiskit-api
docker compose logs -f openclaw

# Resetar se necessário
docker compose restart openclaw
```
