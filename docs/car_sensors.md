# 🚗 Veículos e Sensores de Proximidade

Este documento detalha o funcionamento físico do veículo em [Car.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Car/Car.gd) e o sistema de telemetria sensorial em [Sensors.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Car/Sensors.gd).

---

## 🚘 O Carro de Corrida (`RaceCar.gd`)

O carro herda de `CharacterBody3D` e implementa física arcade customizada para máxima estabilidade e previsibilidade de aprendizado.

### Parâmetros Físicos Configuráveis
* **`max_speed`**: Velocidade máxima que o carro pode atingir (padrão: `300.0`).
* **`acceleration`**: Taxa de aumento de velocidade quando o acelerador é pressionado (padrão: `200.0`).
* **`brake_force`**: Potência de frenagem aplicada quando o gás for negativo (padrão: `300.0`).
* **`steering_speed`**: Velocidade angular do esterçamento das rodas (padrão: `2.5`).

### Dinâmica de Movimento
* **Esterçamento Proporcional**: O giro depende da velocidade atual (`speed_value / max_speed`). Um carro parado não consegue esterçar, simulando a tração das rodas no solo.
* **Gravidade**: O carro aplica aceleração gravitacional de `9.81 m/s²` caso não esteja em contato com o solo (`is_on_floor()`).
* **Detecção de Colisão**: A cada passo de física, varre todas as colisões detectadas via `get_slide_collision()`. Caso atinja qualquer objeto no grupo `"track_obstacle"`:
  1. Marca `alive = false`.
  2. Zera a velocidade.
  3. Altera a cor do veículo para cinza.
  4. Define o texto visual para `"Crash"`.
  5. Desativa e limpa as linhas de depuração dos sensores.
* **Watchdog de Inatividade (Timeout)**:
  * Parâmetros: `enable_idle_timeout = true`, `max_idle_time = 3.0` segundos, `min_moving_speed = 2.0`.
  * Se o carro permanecer com velocidade abaixo de `min_moving_speed` por mais de `max_idle_time`, ele é eliminado com o rótulo visual `"Idle"`.
  * Evita que carros fiquem travando a simulação sem progredir ou bloqueando o grid de largada.

---

## 📡 Sistema de Sensores (`CarSensors.gd`)

O veículo conta com 5 sensores de feixe (raycasts) que varrem o espaço tridimensional à sua frente:

```
           [0° Frontal]
                │
 [-22.5°] ↖     │     ↗ [+22.5°]
            \   │   /
[-45°]  <────  🚗  ────> [+45°]
```

### Configurações dos Sensores
* **Quantidade de Raios**: 5 sensores.
* **Ângulos**: `-45.0°`, `-22.5°`, `0.0°`, `+22.5°`, `+45.0°`.
* **Alcance Máximo (`MAX_DISTANCE`)**: Distância máxima de detecção.
* **Offset (`sensor_offset`)**: Ponto de origem do feixe na dianteira do veículo (`Vector3(0.0, 0.05, 0.15)`).

---

## 🟢 Depuração Visual de Sensores (Debug F3)

O sistema possui renderização de linhas 3D em tempo real construídas com `ImmediateMesh`:

* **Ativação Individual**: Variável `@export var debug: bool = true` no Inspector do nó `Sensors`.
* **Alternar Globalmente (Hotkey)**: Pressione a tecla `F3` durante a execução da simulação para ligar ou desligar instantaneamente a visualização de raios de **todos os veículos** em pista simultaneamente.
* **Profundidade Infinita (`no_depth_test = true`)**: As linhas de laser dos sensores são desenhadas mesmo através de elementos do cenário ou outros veículos, facilitando a inspeção da visão da IA.
