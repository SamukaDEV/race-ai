# 🛠️ Editor de Pistas 3D (`TrackEditor.gd`)

A cena [Levels/TrackEditor.tscn](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Levels/TrackEditor.tscn) implementa um ambiente de criação e edição interativa de circuitos em três dimensões.

---

## 🎮 Controles e Atalhos do Editor

| Ação | Entrada / Tecla | Função |
| :--- | :--- | :--- |
| **Colocar Peça** | `Clique Esquerdo` | Instancia a peça selecionada na grade sob o cursor do mouse |
| **Remover Peça** | `Clique Direito` | Apaga a peça que estiver sob o cursor do mouse |
| **Girar Peça** | Tecla `R` | Rotaciona a peça ativa em $90^\circ$ no sentido horário |
| **Navegar Câmera** | `WASD + Botão Direito` | Voa livremente pelo cenário usando o componente `FreeCamera` |
| **Subir / Descer Câmera** | `Espaço` / `Shift` | Ajusta a altitude de observação da câmera |
| **Velocidade da Câmera** | `Scroll da Roda` | Ajusta a velocidade de deslocamento da câmera no ar |

---

## 🧱 Peças Modulares Disponíveis

O catálogo em [TrackCatalog.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Track/TrackCatalog.gd) disponibiliza peças prontas da Kenney Racing Kit:

* 🏁 **Portal de Largada (`RoadStart`)**: Define o ponto onde os carros alinham no grid de largada.
* 🚦 **Grid de Posições (`RoadStartPositions`)**: Pistas com marcas no asfalto para os competidores.
* 📏 **Reta Curta (`RoadStraight`)**: Bloco linear de $1\text{m}$.
* 🛣️ **Reta Longa (`RoadStraightLong`)**: Bloco linear duplo de $2\text{m}$.
* ↩️ **Curva Larga (`RoadCornerLarge`)**: Curva aberta de $90^\circ$.
* ↪️ **Curva Fechada (`RoadCornerSmall`)**: Curva acentuada de $90^\circ$.
* 🔄 **Curva Muito Larga (`RoadCornerLarger`)**: Curva ultra suave para altas velocidades.
* ⚠️ **Lombada (`RoadBump`) & Cruzamento (`RoadCrossing`)**: Desafios especiais de pista.

---

## 💾 Salvamento e Carregamento de Pistas

As pistas são serializadas em arquivos **JSON estruturados** gravados simultaneamente em:
1. `user://tracks/<nome_da_pista>.json` (pasta persistente do usuário).
2. `res://tracks/<nome_da_pista>.json` (pasta do projeto para versionamento Git).

### Estrutura do Arquivo de Pista
* **`track_id` & `track_name`**: Identificador e nome amigável da pista.
* **`spawn_point`**: Coordenadas e orientação exata onde os carros alinham no grid de largada.
* **`pieces`**: Lista com coordenadas `[x, y, z]` e rotação `rotation_y_deg` de cada peça colocada.
* **`checkpoints`**: Setores cardeais e linha de chegada gerados automaticamente para validação de voltas completadas (LAPs).

---

## 🏎️ Teste Imediato na Simulação

Clicar no botão **"🏎️ Testar Simulação"** na barra superior do editor:
1. Salva automaticamente a pista desenhada.
2. Configura a pista no singleton global `AppState`.
3. Abre a cena do simulador (`MainScene.tscn`) com os carros já alinhados e treinando no novo circuito.
