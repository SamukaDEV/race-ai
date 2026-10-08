# 🧠 Rede Neural Artificial (`NeuralNetwork.gd`)

A tomada de decisão dos veículos é executada por uma **Rede Neural Feedforward Multicamadas (Multi-Layer Perceptron - MLP)** implementada em [NeuralNetwork.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Neural/NeuralNetwork.gd) e [Layer.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Neural/Layer.gd).

---

## 📐 Topologia da Rede

```
   [Entradas: 7]          [Oculta 1: 16]          [Oculta 2: 16]          [Saídas: 2]
    
  (1) Sensor -45°  ──┐   ┌──────────────┐        ┌──────────────┐        ┌─────────────┐
  (2) Sensor -22.5° ─┼──>│  16 Neurônios│───────>│  16 Neurônios│───────>│  Gas/Freio  │
  (3) Sensor 0°    ──┼──>│              │        │              │        └─────────────┘
  (4) Sensor +22.5° ─┼──>│ Função tanh  │        │ Função tanh  │        ┌─────────────┐
  (5) Sensor +45°  ──┼──>│              │        │              │───────>│  Direção    │
  (6) Velocidade   ──┼──>└──────────────┘        └──────────────┘        └─────────────┘
  (7) Ângulo Y     ──┘
```

| Camada | Tipo | Entradas | Saídas / Neurônios | Pesos | Biases | Total Parâmetros |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Camada 1** | Oculta | 7 | 16 | $7 \times 16 = 112$ | 16 | 128 |
| **Camada 2** | Oculta | 16 | 16 | $16 \times 16 = 256$ | 16 | 272 |
| **Camada 3** | Saída | 16 | 2 | $16 \times 2 = 32$ | 2 | 34 |
| **Total** | | | | **400** | **34** | **434** |

---

## 📥 Entradas da Rede (Inputs)

A cada frame de física (`_physics_process`), o carro coleta um vetor com 7 números normalizados:

```gdscript
var inputs: PackedFloat32Array = PackedFloat32Array([
    sensor_values[0],          # Sensor -45° (distância até obstáculo)
    sensor_values[1],          # Sensor -22.5°
    sensor_values[2],          # Sensor 0° (frontal central)
    sensor_values[3],          # Sensor +22.5°
    sensor_values[4],          # Sensor +45°
    speed_value / max_speed,   # Velocidade escalar atual normalizada [0.0, 1.0]
    get_direction_input()      # Orientação angular atual (seno da rotação Y)
])
```

1. **Sensores 0 a 4**: Distância medida por raycasts frontais, normalizada pela distância máxima do sensor.
2. **Velocidade**: Fração da velocidade máxima atual do carro.
3. **Direção (`sin(rotation.y)`)**: Permite que a rede tenha noção do alinhamento rotacional do carro na pista.

---

## 📤 Saídas da Rede (Outputs)

A inferência produz 2 saídas que controlam o carro:

```gdscript
var outputs := neural_network.forward(inputs)

var gas: float = outputs[0]    # Aceleração / Frenagem
var steer: float = outputs[1]  # Ângulo de Esterçamento
```

1. **`gas` (Aceleração / Freio)**:
   * Se $\text{gas} > 0.0$: o carro aplica aceleração no motor proporcionalmente.
   * Se $\text{gas} \le 0.0$: o carro aplica frenagem (`brake_force`).
2. **`steer` (Esterçamento do Volante)**:
   * Varia entre $-1.0$ (curva total para a esquerda) e $+1.0$ (curva total para a direita).
   * Multiplicado pela velocidade do veículo para garantir esterçamento realista (mais suave em alta velocidade).

---

## ⚡ Função de Ativação

A rede utiliza a função de ativação **Tangente Hiperbólica (`tanh`)**:

$$f(x) = \tanh(x) = \frac{e^x - e^{-x}}{e^x + e^{-x}}$$

* O resultado é naturalmente delimitado no intervalo $[-1.0, 1.0]$.
* É perfeitamente compatível com os controles analógicos do carro, permitindo que $-1.0$ signifique virar totalmente à esquerda e $+1.0$ virar totalmente à direita.

```gdscript
# Implementação em Layer.gd:
for neuron in range(output_size):
    var sum: float = biases[neuron]
    for input in range(input_size):
        sum += weights[neuron][input] * inputs[input]
    outputs[neuron] = tanh(sum)
```

---

## 🔄 Conversão Bidirecional: Rede $\leftrightarrow$ Genoma

Para permitir a evolução genética dos pesos e vieses sem perder estrutura:

* **`from_genome(genome: Genome)`**: Lê a sequência linear de 434 floats do genoma e preenche as matrizes de pesos e vetores de viés de cada uma das 3 camadas.
* **`to_genome() -> Genome`**: Extrai os pesos e vieses atuais da rede e compacta novamente em um vetor linear de 434 floats.
