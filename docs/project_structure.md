# 📁 Estrutura do Projeto

Mapeamento completo da organização de diretórios e arquivos do repositório **Race-AI**.

```
race-ai/
├── Assets/                 # Modelos 3D brutos, materiais e malhas
│   ├── Environment/        # Elementos de cenário (natureza, infraestrutura)
│   ├── Props/              # Objetos complementares (marketing, público)
│   ├── Track/              # Elementos de pista (estradas, barreiras, cones)
│   └── Vehicles/           # Modelos de veículos de corrida
├── Levels/                 # Cenas de níveis, menus e editores
│   ├── MainMenu.tscn       # Menu principal do jogo (cena inicial)
│   ├── MainScene.tscn      # Cena principal de simulação de neuroevolução
│   └── TrackEditor.tscn    # Editor 3D de pistas em tempo real
├── Models/                 # Cenas pré-fabricadas (.tscn) e recursos (.tres)
│   ├── Environment/        # Pré-fabricados de natureza e infraestrutura
│   ├── Roads/              # Peças modulares da pista (retas, curvas, largadas)
│   ├── Stands/             # Pré-fabricados de arquibancadas e estandes
│   └── Vehicles/           # Cena instanciável do carro (Car.tscn)
├── Scripts/                # Código-fonte em GDScript
│   ├── Car/                # Lógica do veículo e sensores
│   │   ├── Car.gd          # Física, movimentação e estado do carro
│   │   └── Sensors.gd      # Sensores raycast e visualizador de debug
│   ├── Evolution/          # Lógica do algoritmo genético
│   │   ├── Evolution.gd    # Classes base de evolução
│   │   ├── Fitness.gd      # Regras de avaliação de fitness
│   │   └── Population.gd   # Gerenciamento de populações, elitismo e gerações
│   ├── Global/             # Autoloads e estado global
│   │   └── AppState.gd     # Gerenciamento de pista ativa e isolamento de saves
│   ├── Neural/             # Rede Neural Artificial
│   │   ├── Genome.gd       # Vetor de genes de 434 floats e operadores
│   │   ├── Layer.gd        # Camada neural densa com ativação tanh
│   │   └── NeuralNetwork.gd# Rede completa de 3 camadas feedforward
│   │   └── Neuron.gd       # Definições auxiliares de neurônios
│   ├── Simulation/         # Controle da simulação e persistência
│   │   ├── SaveManager.gd  # Exportação e importação particionada por pista
│   │   └── Simulation.gd   # Spawn dinâmico de carros, monitoramento e avanço
│   ├── Track/              # Gerenciador de pistas e catálogo modular
│   │   ├── Track.gd        # Instanciação dinâmica de peças e checkpoints
│   │   └── TrackCatalog.gd # Mapeamento das 9 peças modulares de pista
│   ├── TrackEditor/        # Lógica do editor 3D de pistas
│   │   └── TrackEditor.gd  # Raycasting, snapping, preview fantasma, rotação e JSON
│   ├── UI/                 # Interfaces de usuário
│   │   ├── HUD.gd          # Telemetria, botões de save/load e retorno ao menu
│   │   └── MainMenu.gd     # Seleção de pistas, início de treino e criação
│   ├── FreeCamera.gd       # Câmera livre cinematográfica e de depuração
│   └── main.gd             # Script raiz da cena principal
├── tracks/                 # Circuitos salvos em formato JSON
│   └── default_circuit.json# Circuito oval oficial empacotado
├── docs/                   # Documentação detalhada em Markdown
│   ├── project_overview.md # Visão geral e arquitetura
│   ├── track_editor.md     # Guia completo do Editor de Pistas e Menu
│   ├── save_load_system.md # Sistema de Save & Load particionado por pista
│   ├── free_camera.md      # Guia do componente FreeCamera
│   ├── genomes_evolution.md# Genomas e algoritmo genético
│   ├── neural_network.md   # Topologia da rede neural
│   ├── car_sensors.md      # Física do carro e sensores raycast
│   └── project_structure.md# Este documento
├── project.godot           # Configurações do motor Godot 4
└── README.md               # Apresentação do projeto e índice geral
```

---

## 🗂️ Responsabilidade dos Módulos em `Scripts/`

| Pasta / Arquivo | Responsabilidade |
| :--- | :--- |
| **`Scripts/Global/AppState.gd`** | Autoload singleton (`AppState`) que rastreia a pista atual (`current_track_id`), nomes e gera caminhos de saves isolados (`user://saves/<track_id>/`). |
| **`Scripts/TrackEditor/TrackEditor.gd`** | Gerencia o editor 3D: raycast no plano $Y=0$, snap de grade de $1.0\text{m}$, peça fantasma translúcida, rotação com `R`, adição, remoção com botão direito, geração de checkpoints e serialização em JSON. |
| **`Scripts/Track/TrackCatalog.gd`** | Catálogo com as 9 peças modulares oficiais (retas, curvas, largada, cruzamento, lombada) mapeadas para suas cenas em `Models/Roads/`. |
| **`Scripts/Track/Track.gd`** | Carrega pistas a partir de dicionários em memória ou arquivos JSON, constrói os nós 3D dinamicamente e gera áreas de checkpoint (`Area3D`) ao redor do circuito. |
| **`Scripts/Simulation/SaveManager.gd`** | Persistência particionada por pista de genomas, geração e câmera, garantindo que o aprendizado em um circuito não sobrescreva o de outro. |
| **`Scripts/UI/MainMenu.gd`** | Interface de boas-vindas com listagem automática de circuitos (`tracks/` e `user://tracks/`), seleção para simulação ou abertura no editor. |
| **`Scripts/UI/HUD.gd`** | Exibe telemetria em tempo real, circuito em execução, voltas (LAPs), ranking, botões rápidos de persistência e retorno ao menu principal. |
| **`Scripts/Car/Car.gd`** | Implementa o nó `CharacterBody3D`, integra o genoma com a rede neural, calcula física, aceleração, atrito, rotação e tratamento de colisão. |
| **`Scripts/Car/Sensors.gd`** | Emite 5 raios na dianteira do veículo configurados para ignorar outros carros (apenas colidindo com o cenário/pista) e projeta o debug visual com `F3`. |
| **`Scripts/Neural/Genome.gd`** | Vetor linear de 434 genes (`PackedFloat32Array`). Responsável pelos métodos de clonagem, mutação gaussiana e crossover. |
| **`Scripts/Neural/Layer.gd`** | Camada neural com matriz de pesos e vetor de viés, realizando inferência e aplicando a função $\tanh(x)$. |
| **`Scripts/Neural/NeuralNetwork.gd`** | Orquestra as 3 camadas neurais ($7 \rightarrow 16 \rightarrow 16 \rightarrow 2$) e realiza a conversão bidirecional com os genomas. |
| **`Scripts/Evolution/Population.gd`** | Mantém a lista de indivíduos da geração, ordena por fitness, aplica elitismo e gera novos filhos mutados. |
| **`Scripts/Simulation/Simulation.gd`** | Instancia a população de veículos na pista dinamicamente alinhados à peça de largada da pista ativa, monitora e comanda as gerações. |
| **`Scripts/FreeCamera.gd`** | Câmera 3D de controle livre com modos de voo ou navegação planar, aceleração via scroll e sensibilidade via mouse. |
