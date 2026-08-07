# Ideias e Oportunidades — Quantum Encoding Agents

Mapeamento de oportunidades concretas identificadas em pesquisa de literatura
e ecossistema (julho/agosto 2026). Organizado por esforço e impacto.

---

## Tier 1 — Implementável agora (dias)

### 1. Dois novos encodings: `dense_angle` e `IQP`

O survey mais completo da área (Sammartino, arXiv:2606.05387, ACM Computing Surveys 2026,
66 papers revisados) classifica **6 famílias** de encoding — o projeto implementa 5.
A que falta:

**`dense_angle`** — múltiplas features por qubit via composição de rotações:
```python
# Em vez de Ry(x[i]) por qubit, usa Ry(x[i]) · Rz(x[j]) no mesmo qubit
# → n features em n/2 qubits com profundidade semelhante ao angle
qc.ry(x[2*i],   qubit)
qc.rz(x[2*i+1], qubit)
```
Mais eficiente que `angle` quando features > qubits disponíveis.

**`IQP` (Instantaneous Quantum Polynomial)** — Hadamards + diagonal Z/ZZ gates:
```python
for i in range(n): qc.h(i)
for i in range(n): qc.rz(x[i]**2, i)   # diagonal Z
for i,j in pairs: qc.rzz(x[i]*x[j], i, j)  # diagonal ZZ
for i in range(n): qc.h(i)
```
Base teórica forte para kernels quânticos. Complementa `custom_feature_map`.

**Onde adicionar:** `encodings.py` (2 novas funções + 2 valores no `EncodingType`).

---

### 2. Parâmetro `hardware_profile` na recomendação

A literatura estabelece um **limiar crítico de erro de porta**:
> `p* ≈ 10⁻³` — acima disso, `amplitude` encoding degrada mais que encodings rasos.

Adicionar ao schema de input:
```json
{
  "data": [...],
  "hardware_profile": {
    "gate_error_rate": 1e-3,
    "connectivity": "heavy-hex",
    "max_depth_budget": 20
  }
}
```

Lógica em `refine_recommendation()`:
- Se `gate_error_rate >= 1e-3` → deprioritizar `amplitude` e `custom_feature_map`
- Se `max_depth_budget < depth_simulado` → recomendar encoding mais raso
- Se `connectivity == "linear"` → alertar sobre overhead de SWAP em `custom_feature_map`

**Onde adicionar:** `problem_context.py` (novo campo `HardwareProfile`) + `data_analysis.py`.

---

### 3. Visualização de estado: esfera de Bloch na resposta

Depois de simular, capturar o statevector e gerar a visualização:

```python
from qiskit.visualization import plot_bloch_multivector
from qiskit_aer import StatevectorSimulator

sim = StatevectorSimulator()
sv = sim.run(qc).result().get_statevector()
fig = plot_bloch_multivector(sv)
# → base64 PNG na resposta JSON
```

Alto valor de demonstração: o usuário vê o que o encoding faz ao estado.
Adicionar ao endpoint `/v1/simulate` como campo opcional `include_bloch: bool`.

---

### 4. Kubeflow Pipeline para RHOAI

Um manifesto YAML de pipeline Kubeflow que encadeia os endpoints existentes
como etapas de um pipeline de ML:

```
CSV upload → /v1/analyze → /v1/recommend → /v1/compare → MLflow log
```

Sem código novo no backend — apenas o manifesto do pipeline + um componente
Python que chama a API. Alta visibilidade para o time de ML da Red Hat.

**Arquivos:** `deploy/rhoai/pipeline.yaml` + `deploy/rhoai/components/`

---

## Tier 2 — Médio prazo (semanas)

### 5. Endpoint `POST /v1/kernel` — matriz de kernel quântico

O `FidelityQuantumKernel` do Qiskit ML calcula a matriz K entre amostras.
É a saída mais concreta de QML: mostra se o encoding consegue separar as classes.

```python
from qiskit_machine_learning.kernels import FidelityStatevectorKernel

kernel = FidelityStatevectorKernel(feature_map=encoding_circuit)
K = kernel.evaluate(x_vec=X_train)   # N×N matrix
# → JSON + heatmap base64
```

**Schema proposto:**
```
POST /v1/kernel
{
  "data": [[...], [...], ...],   # múltiplas amostras
  "encoding_name": "custom_feature_map",
  "labels": [0, 1, 0, ...]       # opcional — para colorir o heatmap
}
→ { "kernel_matrix": [[...]], "heatmap_png_b64": "..." }
```

Permite visualizar separabilidade sem treinar um classificador.

---

### 6. Opt-in para hardware IBM Quantum real

Troca condicional de backend com variável de ambiente:

```python
# simulate.py
if os.getenv("USE_IBM_QUANTUM"):
    from qiskit_ibm_runtime import QiskitRuntimeService, SamplerV2
    service = QiskitRuntimeService(channel="ibm_quantum")
    backend = service.least_busy(operational=True, simulator=False)
    sampler = SamplerV2(backend)
else:
    sampler = AerSimulator()   # comportamento atual
```

Campos novos no request: `backend_name` (ex: `"ibm_torino"`) e `use_real_hardware: bool`.
Custo QPU estimado retornado junto com as métricas.

**Requer:** `IBMQ_API_KEY` env var + nova dependência `qiskit-ibm-runtime`.

---

### 7. Agente Evaluator — fecha o loop proposta → avaliação

Um quarto agente especializado (diferente dos três existentes) que não recomenda
encoding, mas **avalia a qualidade** de um encoding já escolhido:

- **KTA (Kernel Target Alignment)** — mede alinhamento do kernel com os labels
- **PST (Probability of Successful Trials)** — mede queda de fidelidade com ruído
- **Expressibility** — cobertura do espaço de Hilbert pelo circuito
- **Entanglement capability** — para cada encoding, mede o entrelaçamento gerado

Fluxo multi-agente:
```
Quanta recomenda → Circuit gera → Evaluator pontua → QiskitAgent reporta
```

Implementação: novo endpoint `/v1/evaluate` + agente `qiskit_evaluator` no OpenClaw.

---

### 8. Q-Tucker: amplitude encoding mais raso

O StatePreparation do Qiskit gera circuitos muito profundos para amplitude encoding.
O **Q-Tucker** (arXiv:2602.09909) é uma decomposição alternativa que reduz a
profundidade em ~50% para dados com estrutura de baixo rank:

```python
# Em vez de StatePreparation (profundidade O(2^n))
# Q-Tucker usa decomposição Tucker + circuito determinístico
# Profundidade O(n) para dados com bond dimension pequena
```

Pode ser exposto como opção: `amplitude_method: "state_preparation" | "q_tucker"`.

---

## Tier 3 — Pesquisa (meses)

### 9. Quantum Spectral Models (QSM)

arXiv:2607.22516 — encoding onde o Hamiltoniano é construído diretamente
a partir da matriz de entrada. O espectro de frequências do encoding
se adapta ao dado. Resultados superiores a todos os encodings estáticos.

Seria o 7º encoding, mas requer infraestrutura nova (construção dinâmica
do circuito a partir de auto-decomposição da matriz de entrada).

---

### 10. Qiskit como MCP server nativo

IBM lançou suporte a Qiskit como MCP server (`/docs/guides/qiskit-mcp-servers`).
Isso significa que agentes MCP-nativos (Claude, OpenCode, etc.) podem chamar
Qiskit diretamente como ferramenta — sem passar pela API FastAPI.

Permite integrar o projeto com qualquer cliente MCP sem manutenção de API própria.

---

## Papers de referência

| Paper | Relevância |
|---|---|
| arXiv:2606.05387 — Sammartino (2026) | Survey definitivo: 6 famílias, limiar p*, guidelines de escolha |
| arXiv:2604.07856 — Hardware-Aware QSVM (2026) | NAS com restrições de hardware real — noise-aware recommendation |
| arXiv:2607.22516 — Quantum Spectral Models (2026) | Novo paradigma de encoding adaptativo ao input |
| arXiv:2602.09909 — Q-Tucker (2026) | Amplitude encoding com profundidade O(n) em vez de O(2^n) |
| arXiv:2508.07104 — QuProFS (2025) | Busca de arquitetura sem treinamento, com robustez a ruído |
| arXiv:2506.21161 — GNN for Kernel Design (2025) | Preditor de KTA e PST via GNN — scoring de encoding |
| arXiv:2604.11022 — SPATE (2026) | Encoding temporal para dados de sensor/streaming |

---

## Mapa de dependências das ideias

```
Tier 1 (base)
  dense_angle + IQP encodings
       ↓
  hardware_profile param  ←──── dados do cluster IBM / OpenShift
       ↓
  Bloch sphere visualization

Tier 2 (extensão)
  /v1/kernel  ←── FidelityQuantumKernel (qiskit-machine-learning)
       ↓
  Evaluator Agent  ←── KTA + PST scores
       ↓
  IBM Quantum real hardware  ←── QiskitRuntimeService

Tier 3 (pesquisa)
  Q-Tucker  ←── substitui StatePreparation
  QSM       ←── novo paradigma
  Qiskit MCP ←── elimina FastAPI layer para clientes MCP
```
