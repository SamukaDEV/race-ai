# 📷 Componente FreeCamera (`FreeCamera.gd`)

O script [FreeCamera.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/FreeCamera.gd) estende `Camera3D` e implementa uma câmera livre cinematográfica e de depuração para o Godot 4, projetada para visualização flexível de cenários 3D.

---

## 🎮 Controles Padrão

| Ação | Entrada / Tecla | Descrição |
| :--- | :--- | :--- |
| **Mover para Frente** | `W` | No modo `FLY_3D`, move diretamente para onde a câmera está apontando |
| **Mover para Trás** | `S` | Move na direção oposta ao olhar da câmera |
| **Mover para Esquerda** | `A` | Strafe / deslocamento para a esquerda local |
| **Mover para Direita** | `D` | Strafe / deslocamento para a direita local |
| **Ganhar Altitude** | `Espaço` | Eleva a câmera no eixo vertical (+Y) |
| **Descer Altitude** | `Shift` | Abaixa a câmera no eixo vertical (-Y) |
| **Olhar com Mouse** | `Botão Direito (Segurar)` | Rotaciona a orientação da câmera com movimentação do mouse |
| **Ajustar Velocidade** | `Scroll Wheel (Roda)` | Rola para cima acelera; rola para baixo desacelera |
| **Modo Turbo / Sprint** | `Ctrl` | Multiplica a velocidade de deslocamento (por padrão em 2.5x) |
| **Alternar Captura** | `F` | No modo `TOGGLE_KEY`, alterna captura e liberação do cursor |

---

## ⚙️ Modos de Funcionamento

O script oferece enums exportados para alternar entre diferentes fluxos de navegação:

### 1. Modos de Movimento (`MovementMode`)
* **`FLY_3D` (Voo Livre 3D - Padrão)**:
  * Ao pressionar `W`, a câmera se desloca tridimensionalmente na direção do vetor de visão (`-global_transform.basis.z`).
  * Se você inclinar o mouse para cima e pressionar `W`, a câmera sobe. Se apontar para o chão e pressionar `W`, ela desce em direção ao solo.
* **`PLANAR` (Navegação Horizontal Plana)**:
  * O movimento das teclas `W`, `S`, `A` e `D` é projetado unicamente no plano horizontal (XZ).
  * A inclinação vertical da câmera é desconsiderada no deslocamento frontal, mantendo a altitude constante a menos que as teclas `Espaço` ou `Shift` sejam pressionadas.

### 2. Modos do Mouse (`MouseControlMode`)
* **`HOLD_RIGHT_CLICK` (Padrão)**:
  * Ideal para simulações e editores. Mantém o cursor livre para interagir com a interface. Ao pressionar o botão direito do mouse, o cursor é ocultado e capturado para rotacionar a visão, voltando a ficar visível ao soltar.
* **`MOUSE_CAPTURED` (Estilo FPS)**:
  * O mouse é capturado imediatamente na inicialização da cena. A tecla `ESC` alterna entre liberar e prender o cursor.
* **`HOLD_LEFT_CLICK`**:
  * Semelhante ao clique direito, mas ativado segurando o botão esquerdo do mouse.
* **`TOGGLE_KEY`**:
  * Alterna o estado de captura do mouse através de uma tecla configurada (`key_toggle_capture`, padrão `F`).

---

## 🛠️ Propriedades Configuráveis no Inspector

Todas as propriedades estão organizadas por categorias no editor do Godot:

```
FreeCamera
├── Geral
│   ├── active: bool = true
│   └── make_current_on_ready: bool = true
├── Modos de Operação
│   ├── movement_mode: FLY_3D | PLANAR
│   ├── mouse_control_mode: HOLD_RIGHT_CLICK | MOUSE_CAPTURED | HOLD_LEFT_CLICK | TOGGLE_KEY
│   └── vertical_movement_global: bool = true
├── Velocidade
│   ├── base_speed: float = 20.0
│   ├── smooth_movement: bool = true
│   ├── smooth_factor: float = 16.0
│   ├── Ajuste por Roda do Mouse
│   │   ├── enable_speed_scroll: bool = true
│   │   ├── min_speed: float = 1.0
│   │   ├── max_speed: float = 150.0
│   │   └── scroll_speed_step: float = 2.5
│   └── Turbo / Sprint
│       ├── enable_turbo: bool = true
│       ├── turbo_multiplier: float = 2.5
│       └── key_turbo: Key = KEY_CTRL
├── Mouse / Rotação
│   ├── mouse_sensitivity: float = 0.003
│   ├── invert_y: bool = false
│   ├── min_pitch: float = -89.0
│   └── max_pitch: float = 89.0
└── Teclas de Controle
    ├── key_forward: Key = KEY_W
    ├── key_backward: Key = KEY_S
    ├── key_left: Key = KEY_A
    ├── key_right: Key = KEY_D
    ├── key_up: Key = KEY_SPACE
    ├── key_down: Key = KEY_SHIFT
    └── key_toggle_capture: Key = KEY_F
```

---

## 💡 Prevenção de Falhas Técnicas
1. **Sem Dependência de InputMap**: As teclas são lidas por `Input.is_physical_key_pressed` e `Input.is_key_pressed`, permitindo funcionamento imediato em qualquer projeto sem configurar ações manuais no `project.godot`.
2. **Sem Gimbal Lock**: Os ângulos de guinada (`_yaw`) e arfagem (`_pitch`) são rastreados de forma desacoplada em variáveis escalares, limitando o pitch entre `-89°` e `+89°` e fixando o roll em `0.0`.
3. **Liberação Automática de Cursor**: Implementa `_exit_tree()` para garantir que o mouse retorne a `Input.MOUSE_MODE_VISIBLE` ao fechar a cena ou alternar nós.
