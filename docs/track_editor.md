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

* 🏁 **Portal de Largada (`RoadStart`)**: Estrutura de pórtico com barreiras laterais de proteção.
* 🚦 **Grid de Posições (`RoadStartPositions`)**: Pista com marcas pintadas no asfalto e nó interno `SpawnPoints` contendo **4 nós `Marker3D`** (`Spawn1` a `Spawn4`) para alinhamento realista dos veículos.
* 📏 **Reta Curta (`RoadStraight`)**: Bloco linear de $1\text{m}$.
* 🛣️ **Reta Longa (`RoadStraightLong`)**: Bloco linear duplo de $2\text{m}$.
* ↩️ **Curva Larga (`RoadCornerLarge`)**: Curva aberta de $90^\circ$.
* ↪️ **Curva Fechada (`RoadCornerSmall`)**: Curva acentuada de $90^\circ$.
* 🔄 **Curva Muito Larga (`RoadCornerLarger`)**: Curva ultra suave para altas velocidades.
* ⚠️ **Lombada (`RoadBump`) & Cruzamento (`RoadCrossing`)**: Desafios especiais de pista.

---

## 🚦 Marcadores de Largada (`SpawnPoints` / `Marker3D`)

Cada peça [RoadStartPositions.tscn](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Models/Roads/RoadStartPositions.tscn) possui um container `SpawnPoints` com 4 marcadores tridimensionais estrategicamente posicionados no asfalto:
* `Spawn1`: Linha da frente, faixa esquerda (Pole position).
* `Spawn2`: Linha 2, faixa direita.
* `Spawn3`: Linha 3, faixa esquerda.
* `Spawn4`: Linha 4, faixa direita.

O [TrackManager](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Track/Track.gd) coleta todos os marcadores de todas as peças `RoadStartPositions` da pista e os ordena automaticamente ao longo do sentido de corrida. O [Simulation.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Simulation/Simulation.gd) instancia cada veículo exatamente na posição e rotação de seu respectivo marcador. Caso a população configurada supere a quantidade de vagas físicas, o sistema estende suavemente fileiras adicionais para trás ao longo do eixo da pista, impedindo que veículos surjam fora do asfalto ou colidam no início da simulação.

---

## ⚙️ Configurações da Pista & Simulação

O botão **"⚙️ Configurações"** na barra superior do editor abre um modal interativo para personalizar a física e o treinamento da inteligência artificial:

* **Vagas Detectadas**: Exibe em tempo real quantas vagas físicas de largada existem no circuito (ex: $2 \times \text{RoadStartPositions} = 8\text{ vagas}$).
* **Quantidade de Carros (`population_size`)**: Controle numérico com botão rápido *"Auto Vagas"* para sincronizar com as vagas do traçado.
* **Timeout de Inatividade (`max_idle_time` e `enable_idle_timeout`)**: Tempo limite para eliminar carros parados ou presos.
* **Taxa de Mutação (`mutation_rate`)**: Percentual de probabilidade de mutação em cada gene (padrão 5%).
* **Força da Mutação (`mutation_power`)**: Magnitude da perturbação gaussiana dos pesos neurais (padrão 0.20).
* **Elitismo (`elite_count`)**: Quantidade de melhores pilotos clonados integralmente para a próxima geração.
* **Velocidade Máxima dos Veículos (`max_speed`)**: Limite de velocidade física dos carros (padrão 300).

---

## 💾 Salvamento e Carregamento de Pistas

As pistas são serializadas em arquivos **JSON estruturados** gravados simultaneamente em:
1. `user://tracks/<nome_da_pista>.json` (pasta persistente do usuário).
2. `res://tracks/<nome_da_pista>.json` (pasta do projeto para versionamento Git).

### Estrutura do Arquivo de Pista
* **`track_id` & `track_name`**: Identificador e nome amigável da pista.
* **`config`**: Dicionário com todas as configurações de simulação e neuroevolução (`population_size`, `mutation_rate`, `max_idle_time`, etc.).
* **`spawn_point`**: Coordenadas e orientação legada do grid de largada.
* **`pieces`**: Lista com coordenadas `[x, y, z]` e rotação `rotation_y_deg` de cada peça colocada.
* **`checkpoints`**: Setores cardeais e linha de chegada gerados automaticamente para validação de voltas completadas (LAPs).

---

## 🏎️ Teste Imediato na Simulação

Clicar no botão **"🏎️ Testar Simulação"** na barra superior do editor:
1. Salva automaticamente a pista desenhada com suas configurações.
2. Configura a pista e os dados de teste no singleton global `AppState`.
3. Abre a cena do simulador (`MainScene.tscn`) com os carros já alinhados nas vagas reais e treinando no novo circuito.
