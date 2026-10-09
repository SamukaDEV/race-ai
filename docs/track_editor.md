# 🛠️ Editor de Pistas 3D (`TrackEditor.gd`)

A cena [Levels/TrackEditor.tscn](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Levels/TrackEditor.tscn) implementa um ambiente de criação e edição interativa de circuitos em três dimensões.

---

## 🎮 Controles e Atalhos do Editor
 
| Ação | Entrada / Tecla | Função |
| :--- | :--- | :--- |
| **Colocar Peça** | `Clique Esquerdo` | Instancia a peça selecionada na grade sob o cursor do mouse |
| **Remover Peça** | `Clique Direito` | Apaga a peça que estiver sob o cursor do mouse |
| **Girar Peça** | Tecla `R` | Rotaciona a peça ativa em $90^\circ$ no sentido horário |
| **Grade 3D (Chão)** | Tecla `G` | Liga/desliga a visualização da grade 3D modular no chão ($Y = 0.015$) |
| **Pausar Simulação** | Tecla `P` ou `Espaço` | Pausa/retoma a física dos carros na simulação mantendo a câmera livre |
| **Navegar Câmera** | `WASD + Botão Direito` | Voa livremente pelo cenário usando o componente `FreeCamera` |
| **Subir / Descer Câmera** | `Espaço` / `Shift` | Ajusta a altitude de observação da câmera no editor |
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
 
O [TrackManager](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Track/Track.gd) coleta todos os marcadores de todas as peças `RoadStartPositions` da pista e os ordena automaticamente ao longo do sentido de corrida. O [Simulation.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Simulation/Simulation.gd) instancia cada veículo exatamente na posição e rotação de seu respectivo marcador. Caso a população configurada supere a quantidade de vagas físicas, o sistema estende fileiras adicionais para trás ao longo do eixo da pista, impedindo que veículos surjam fora do asfalto ou colidam no início da simulação.
 
---
 
## ⚙️ Configurações da Pista & Simulação (Tipagem Float & Valores Livres)
 
O botão **"⚙️ Configs"** na barra superior do editor abre um modal interativo para personalizar a física e o treinamento da inteligência artificial. Todos os campos possuem tipagem `float` nativa, com `allow_greater = true` para permitir valores personalizados sem travas artificiais:
 
* **Vagas Detectadas**: Exibe em tempo real quantas vagas físicas de largada existem no circuito (ex: $2 \times \text{RoadStartPositions} = 8\text{ vagas}$).
* **Quantidade de Carros (`population_size`)**: Quantidade de carros criados (inteiro, sem teto fixo, com botão *"Auto Vagas"*).
* **Timeout de Inatividade (`max_idle_time` e `enable_idle_timeout`)**: Tempo limite decimal (`step = 0.1s`) para eliminar carros parados.
* **Taxa de Mutação (`mutation_rate`)**: Percentual decimal com 3 casas (`step = 0.001`, ex: `0.050` = 5%).
* **Força da Mutação (`mutation_power`)**: Intensidade decimal (`step = 0.01`, ex: `0.20`).
* **Elitismo (`elite_count`)**: Quantidade de melhores pilotos clonados integralmente para a próxima geração.
* **Velocidade Máxima dos Veículos (`max_speed`)**: Limite decimal de velocidade física dos carros (`step = 0.1`, sem teto fixo).
* **Aceleração do Motor (`acceleration`)**: Taxa de aumento de velocidade por segundo (`step = 0.1`, ex: `200.0`).
* **Força dos Freios (`brake_force`)**: Intensidade de desaceleração dos veículos (`step = 0.1`, ex: `100.0`).
* **Velocidade de Esterçamento (`steering_speed`)**: Agilidade de rotação e curva do volante (`step = 0.01`, destravada além de $10.0$ permitindo qualquer valor como $15.0$, $25.5$, etc.).
 
---
 
## 💾 Salvamento, Exclusão e Confirmações de Segurança
 
As pistas são serializadas em arquivos **JSON estruturados** gravados simultaneamente em `user://tracks/<nome>.json` e `res://tracks/<nome>.json`.
 
* **Exclusão de Pistas (`🗑️`)**: Na lista de pistas salvas (**"📂 Pistas"**), cada item possui um botão de exclusão protegido por modal de confirmação universal, apagando os arquivos físicos com segurança.
* **Limpeza de Pista (`🧹 Limpar`)**: O botão de limpeza solicita confirmação explícita antes de desalocar as peças 3D do traçado, prevenindo perda acidental de progresso não salvo.
* **Pausa em Tempo Real (`⏸️`)**: Durante a simulação, o usuário pode pausar (`P` ou `Espaço`) a movimentação física dos carros para inspecionar traçados e sensores com a câmera livre, retomando a execução a qualquer momento sem perder o estado da geração.
 
---
 
## 🎨 Interface e Usabilidade do Editor
 
A interface do editor foi projetada em escala nativa ($1.0$), garantindo proporções simétricas e hitboxes precisas:
 
* **Barra Superior Compacta (40px)**: Agrupa título com ícone, input de nome, `💾 Salvar`, `📂 Pistas`, `⚙️ Configs`, `🧹 Limpar`, `🏎️ Testar Simulação` e `🏠 Menu`.
* **Sidebar Vertical Esquerda (204px)**:
  - Miniaturas procedurais 2D desenhadas em tempo de execução para cada tipo de peça de pista.
  - Destaque visual da peça selecionada com borda ciano/esmeralda.
* **Rodapé Informativo Centralizado**: Apresenta todos os atalhos de comando, incluindo `[G]: Grade 3D` e comandos de câmera.
* **Isolamento de Entrada**: Bloqueia movimentações de câmera enquanto o usuário digita nos campos de texto ou caixas numéricas.

---

## 🏎️ Teste Imediato na Simulação & Retorno ao Editor

O fluxo de teste e iteração da pista funciona de forma contínua:
1. No editor, clicar em **"🏎️ Testar Simulação"** salva a pista atual com suas configurações no singleton `AppState` e transiciona diretamente para a cena de simulação (`MainScene.tscn`).
2. Durante a simulação, o HUD exibe o botão **"🛠️ Editor"** ao lado de "🏠 Menu".
3. Ao clicar em **"🛠️ Editor"**, o simulador redireciona de volta para `TrackEditor.tscn`, restaurando imediatamente em memória todas as peças colocadas, configurações, nome da pista e a posição exata da câmera, permitindo refinar o traçado sem precisar recarregar arquivos ou voltar pelo menu principal.

