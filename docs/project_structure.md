# 📁 Estrutura do Projeto

Mapeamento completo da organização de diretórios e arquivos do repositório **Race-AI**.

```
race-ai/
├── Assets/                 # Modelos 3D brutos, materiais e malhas
│   ├── Environment/        # Elementos de cenário (natureza, infraestrutura)
│   ├── Props/              # Objetos complementares (marketing, público)
│   ├── Track/              # Elementos de pista (estradas, barreiras, cones)
│   └── Vehicles/           # Modelos de veículos de corrida
├── Levels/                 # Cenas de níveis / pistas
│   └── MainScene.tscn      # Cena principal da simulação
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
│   ├── Neural/             # Rede Neural Artificial
│   │   ├── Genome.gd       # Vetor de genes de 434 floats e operadores
│   │   ├── Layer.gd        # Camada neural densa com ativação tanh
│   │   ├── NeuralNetwork.gd# Rede completa de 3 camadas feedforward
│   │   └── Neuron.gd       # Definições auxiliares de neurônios
│   ├── Simulation/         # Controle da simulação
│   │   └── Simulation.gd   # Spawn de carros, monitoramento e avanço
│   ├── Track/              # Scripts utilitários de pistas e checkpoints
│   ├── FreeCamera.gd       # Câmera livre cinematográfica e de depuração
│   └── main.gd             # Script raiz da cena principal
├── docs/                   # Documentação detalhada em Markdown
│   ├── project_overview.md # Visão geral e arquitetura
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
| **`Scripts/Car/Car.gd`** | Implementa o nó `CharacterBody3D`, integra o genoma com a rede neural, calcula física, aceleração, atrito, rotação e tratamento de colisão. |
| **`Scripts/Car/Sensors.gd`** | Emite 5 raios na dianteira do veículo, calcula as distâncias até obstáculos e projeta as linhas de depuração 3D com a tecla `F3`. |
| **`Scripts/Neural/Genome.gd`** | Vetor linear de 434 genes (`PackedFloat32Array`). Responsável pelos métodos de clonagem, mutação gaussiana e crossover. |
| **`Scripts/Neural/Layer.gd`** | Camada neural com matriz de pesos e vetor de viés, realizando inferência e aplicando a função $\tanh(x)$. |
| **`Scripts/Neural/NeuralNetwork.gd`** | Orquestra as 3 camadas neurais ($7 \rightarrow 16 \rightarrow 16 \rightarrow 2$) e realiza a conversão bidirecional com os genomas. |
| **`Scripts/Evolution/Population.gd`** | Mantém a lista de indivíduos da geração, ordena por fitness, aplica elitismo e gera novos filhos mutados. |
| **`Scripts/Simulation/Simulation.gd`** | Instancia a população de veículos na pista, monitora quem continua vivo a cada frame e dispara o avanço para a próxima geração quando todos colidem. |
| **`Scripts/FreeCamera.gd`** | Câmera 3D de controle livre com modos de voo ou navegação planar, aceleração via scroll e sensibilidade via mouse. |
