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
* **Velocidade Máxima dos Veículos (`max_speed`)**: Limite de velocidade física dos carros (mínimo destravado a partir de $10.0$ até $1000.0$).
* **Aceleração do Motor (`acceleration`)**: Taxa de aumento de velocidade por segundo ($10.0$ a $1000.0$, padrão $200.0$).
* **Força dos Freios (`brake_force`)**: Intensidade de desaceleração dos veículos ($10.0$ a $600.0$, padrão $100.0$).
* **Velocidade de Esterçamento (`steering_speed`)**: Agilidade de rotação e curva do volante ($0.5$ a $10.0$, padrão $2.5$).

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

---

## 🎨 Interface e Usabilidade do Editor

A interface do editor foi projetada para máxima ergonomia e integração com a visualização 3D:

* **Barra Superior Compacta**: Acesso rápido a `Nome da Pista`, `💾 Salvar`, `📂 Carregar`, `⚙️ Configs`, `🧹 Limpar`, `🏎️ Testar` e `🏠 Menu`.
* **Sidebar Vertical na Lateral Esquerda**:
  - Lista vertical completa com as peças modulares disponíveis e indicador visual da peça ativa destacada em verde fluorescente.
  - **Miniaturas Procedurais 2D**: Cada botão exibe um ícone renderizado sob medida (asfalto, zebras vermelhas, linhas tracejadas, grelha amarela de largada, etc.) gerado em tempo de execução sem dependência de assets externos.
* **Isolamento de Entrada & Foco de Câmera**:
  - Quando o usuário digita no campo `Nome` ou em qualquer campo numérico (`SpinBox`), os atalhos de voo da câmera (`WASD`, `Espaço`, `Shift`) são automaticamente suspensos para evitar movimentação indesejada da cena 3D.
  - Ao pressionar `Enter`, `Esc` ou clicar com o botão esquerdo/direito na tela 3D, o foco do campo de texto é desativado imediatamente, restabelecendo o controle da câmera.
* **Barra Inferior de Dicas**: Rodapé compacto resumindo os atalhos do mouse e teclado.

---

## 🏎️ Teste Imediato na Simulação & Retorno ao Editor

O fluxo de teste e iteração da pista funciona de forma contínua:
1. No editor, clicar em **"🏎️ Testar"** salva a pista atual com suas configurações no singleton `AppState` e transiciona diretamente para a cena de simulação (`MainScene.tscn`).
2. Durante a simulação, o HUD exibe o botão **"🛠️ Editor"** ao lado de "🏠 Menu".
3. Ao clicar em **"🛠️ Editor"**, o simulador redireciona de volta para `TrackEditor.tscn`, restaurando imediatamente em memória todas as peças colocadas, configurações e nome da pista, permitindo refinar o traçado sem precisar recarregar arquivos ou voltar pelo menu principal.

