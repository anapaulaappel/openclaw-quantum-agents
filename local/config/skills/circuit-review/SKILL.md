---
name: circuit-review
description: >
  Reviews an existing Qiskit circuit or encoding choice before recommending
  alternatives. Checks depth, gate count, qubit connectivity, and NISQ
  compatibility. Invoke when the user shares existing code or asks "is this good?".
user-invocable: true
---

# Skill: circuit-review

Revisão técnica de circuitos ou escolhas de encoding já existentes.
Invoque quando o usuário compartilhar código Qiskit ou perguntar se o encoding
atual é adequado.

## Quando usar esta skill

- Usuário cola código Qiskit e pergunta "isso está correto?" ou "posso melhorar?"
- Usuário menciona que já usa um encoding e quer saber se é o certo
- Usuário pede comparação entre o encoding atual e alternativas

## Protocolo de revisão

### Passo 1 — Extrair métricas do circuito atual

Se o usuário colou código, identifique:

- **Número de qubits** (`qc.num_qubits`)
- **Profundidade declarada** (se houver) ou estime pela contagem de camadas
- **Gates usados** — classifique como: single-qubit (Rx, Ry, Rz, H, X, Y, Z),
  two-qubit (CNOT, CZ, CX, ECR), multi-qubit (Toffoli, etc.)
- **Tipo de encoding inferido** — identifique qual dos 5 encodings o código implementa,
  ou se é um circuito híbrido/customizado

### Passo 2 — Chamar a API para benchmark

Extraia os dados de exemplo do código (se visíveis) e chame:

```
POST http://qiskit-api:8080/v1/compare
{"data": [<dados extraídos ou estimados>], "shots": 256}
```

Compare as métricas do circuito apresentado com os do ranking retornado.

### Passo 3 — Estruturar a revisão

Produza a revisão em 4 pontos objetivos:

**1. O que o circuito faz**
Identifique o encoding e descreva o que acontece fisicamente (sem repetir o código).

**2. Métricas atuais vs. alternativas**

| Métrica | Circuito atual | Melhor alternativa | Diferença |
|---|---|---|---|
| Qubits | N | M | ±X |
| Profundidade | D | E | ±Y |

**3. Compatibilidade NISQ**

Avalie com base na profundidade:
- ≤ 5: excelente para hardware atual
- 6–15: viável com fidelidade de porta ≥ 99%
- 16–30: arriscado sem mitigação de erros
- > 30: simulação clássica recomendada para NISQ

Se houver gates two-qubit acima de 10, alerte sobre fidelidade.

**4. Recomendação**

Uma das três:
- **Manter** — o encoding atual é adequado para o objetivo descrito
- **Otimizar** — o encoding está correto mas o circuito pode ser mais raso
- **Trocar** — há um encoding mais adequado; explique por quê com as métricas

## Regras

- Não critique código por estilo — apenas por impacto em profundidade, qubits ou fidelidade.
- Se não houver dados suficientes para chamar a API, pergunte antes de especular.
- Sempre termine com uma ação clara: manter, otimizar ou trocar.
