---
name: qiskit-api
description: >
  Calls the llama-qiskit-agents REST API to analyze data profiles, recommend
  quantum encodings, generate Qiskit code, and simulate circuits.
  Use this skill whenever the user provides data or asks about quantum encoding.
user-invocable: false
---

# Skill: qiskit-api

Encapsula todas as chamadas HTTP à API do `llama-qiskit-agents`.
Use esta skill sempre que o usuário fornecer dados ou pedir recomendação de encoding.

## Base URL

```
http://qiskit-api:8080
```

(No OpenShift: `http://llama-qiskit-agents.openclaw.svc.cluster.local:8080`)

---

## Endpoint principal — use este primeiro

### `POST /v1/recommend/explain`

Recomendação completa: detecta idioma, retorna justificativa narrativa + código Qiskit.

```json
{
  "description": "texto livre sobre o dado ou problema",
  "data": [0.1, 0.2, 0.3, 0.4],
  "task": "kernel",
  "algorithm": "QSVM",
  "problem_description": "contexto adicional"
}
```

Todos os campos são opcionais — use os que o usuário forneceu.

**Campos da resposta que importam:**

| Campo | O que é |
|---|---|
| `recommended_encoding` | Nome do encoding escolhido |
| `explanation` | Justificativa em linguagem natural (já no idioma do usuário) |
| `qiskit_code` | Código Python completo e copiável |
| `circuit_depth` | Profundidade do circuito transpilado |
| `circuit_qubits` | Número de qubits usados |
| `lang` | Idioma detectado: `pt` ou `en` |

**Apresentação:** mostre `explanation` diretamente, depois `qiskit_code` em bloco de código.

---

## Endpoints auxiliares

### `POST /v1/compare` — ranking dos 5 encodings

```json
{"data": [0.1, 0.2, 0.3], "task": "variational", "shots": 1024}
```

Use quando o usuário quiser comparar todas as opções.

### `POST /v1/circuit` — diagrama ASCII do circuito

```json
{"encoding_name": "angle", "data": [0.1, 0.2, 0.3]}
```

`encoding_name` aceita: `amplitude` | `angle` | `basis` | `data_reuploading` | `custom_feature_map`

### `POST /v1/simulate` — histograma de medições

```json
{"encoding_name": "data_reuploading", "data": [0.1, 0.2], "shots": 512}
```

### `GET /v1/tradeoffs` — trade-offs de todos os encodings

Sem corpo. Use quando o usuário quiser uma visão geral antes de decidir.

---

## Regras de uso

1. **Sempre chame a API** quando houver dados numéricos ou descrição de dataset.
   Não deduza o encoding sem simular — as métricas reais (depth, qubits) importam.

2. **Passe todos os campos disponíveis.** Se o usuário mencionou algoritmo, passe
   `algorithm`. Se descreveu o problema, passe `problem_description`.

3. **Não reformule a `explanation`** — ela já está no idioma do usuário e cita
   métricas concretas. Apresente-a diretamente.

4. **Se a API retornar erro**, diga ao usuário e tente `/v1/recommend` (JSON simples)
   como fallback.
