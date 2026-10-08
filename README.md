# 🏎️ Race-AI

> **Simulação de corrida 3D autônoma impulsionada por Redes Neurais e Algoritmos Genéticos (Neuroevolução) no Godot Engine 4.**

---

## 📌 Sobre o Projeto

O **Race-AI** é um ambiente de simulação 3D onde carros de corrida aprendem a pilotar de forma autônoma sem supervisão humana ou dados de telemetria pré-gravados. 

Através de **Neuroevolução**, cada veículo possui sua própria rede neural artificial alimentada por sensores de proximidade (raycasts). A cada geração, os pilotos que percorrem a maior distância acumulam maior pontuação de aptidão (*fitness*), transmitindo seus genes com pequenas mutações para a próxima geração, enquanto o melhor piloto de cada geração é preservado integralmente através de **Elitismo**.

---

## ✨ Principais Funcionalidades

* 🧠 **Redes Neurais Multicamadas (MLP)**: Topologia $7 \rightarrow 16 \rightarrow 16 \rightarrow 2$ com função de ativação $\tanh$.
* 🧬 **Algoritmo Genético Robusto**: Genomas com 434 parâmetros de precisão `float32`, seleção natural, elitismo e mutação gaussiana.
* 📡 **Sensores Raycast com Debug Visual**: 5 feixes de proximidade por veículo com alternância global de depuração visual via tecla `F3`.
* 📷 **Câmera Livre Configurável (`FreeCamera`)**: Navegação fluida em 3D ou planar horizontal com controles familiares (`WASD`, `Shift`, `Espaço`), rotação por mouse e ajuste de velocidade dinâmico por scroll.
* ⚡ **Motor Físico Jolt 3D**: Simulação física de alta estabilidade e desempenho integrada ao Godot 4.

---

## 🎮 Controles Rápidos

### Câmera Livre (`FreeCamera`)
| Comando | Tecla / Ação | Função |
| :--- | :--- | :--- |
| **Mover** | `W`, `A`, `S`, `D` | Navega pelo circuito (no modo `FLY_3D`, `W` avança na direção do olhar) |
| **Altitude** | `Espaço` / `Shift` | `Espaço` sobe (+Y) \| `Shift` desce (-Y) |
| **Olhar** | `Botão Direito (Segurar)` | Rotaciona o ângulo de visão com o mouse |
| **Ajustar Velocidade** | `Scroll da Roda` | Rolar para cima aumenta a velocidade; para baixo diminui |
| **Turbo** | `Ctrl` | Multiplica a velocidade de deslocamento (2.5x) |

### Simulação e Sensores
| Comando | Tecla | Função |
| :--- | :--- | :--- |
| **Depuração de Sensores** | `F3` | Liga ou desliga as linhas visuais dos sensores de todos os carros em tempo real |

---

## 📚 Documentação Técnica (`docs/`)

Para detalhes arquiteturais aprofundados, consulte os documentos dedicados na pasta `docs/`:

* 📖 [**Visão Geral do Projeto**](docs/project_overview.md): Fluxo completo de simulação e conceitos de neuroevolução.
* 📷 [**Guia da Câmera Livre (`FreeCamera`)**](docs/free_camera.md): Modos de operação, propriedades do Inspector e boas práticas.
* 🧬 [**Genomas e Algoritmo Genético**](docs/genomes_evolution.md): Representação de 434 genes, elitismo, mutação e reprodução.
* 🧠 [**Rede Neural Artificial**](docs/neural_network.md): Topologia de camadas, ativação $\tanh$, normalização de entradas e saídas de controle.
* 🚗 [**Veículos e Sensores**](docs/car_sensors.md): Física do carro, ângulos dos feixes de raycast e renderização de depuração.
* 📁 [**Estrutura de Pastas**](docs/project_structure.md): Descrição detalhada da organização de pastas e arquivos.

---

## 📁 Estrutura do Projeto

```Text
📁 Project Structure
• 📂 Assets/
	• 📂 Vehicles/ (Modelos 3D de veículos)
		• Carros/
	• 📂 Environment/ (Cenário ao redor da pista)
		• 📂 Infrastructure/ (Postes, Semáforos, Caixas d'água)
		• 📂 Nature/ (Árvores, Arbustos, Vegetação)
	• 📂 Track/ (Estrutura da pista e corrida)
		• 📂 Roads/ (Ruas, asfalto, zebras, largadas)
		• 📂 Safety/ (Barreiras de colisão, cercas, cones, placas)
	• 📂 Props/ (Objetos estáticos e dinâmicos)
		• 📂 Crowd/ (Arquibancadas, pessoas, tendas)
		• 📂 Marketing/ (Banners, estandes, outdoors, torres)
• 📂 Levels/
	• MainScene.tscn (Cena principal de execução da simulação)
• 📂 Models/ (Cenas modulares empacotadas .tscn e materiais .tres)
• 📂 Scripts/
	• 📂 Car/ (Car.gd e Sensors.gd)
	• 📂 Evolution/ (Population.gd, Evolution.gd e Fitness.gd)
	• 📂 Neural/ (NeuralNetwork.gd, Layer.gd e Genome.gd)
	• 📂 Simulation/ (Simulation.gd)
	• FreeCamera.gd (Câmera livre 3D configurável)
	• main.gd (Ponto de entrada da aplicação)
• 📂 docs/ (Documentação técnica em Markdown)
```

---

## 🚀 Como Executar

1. Abra o **Godot Engine 4** (versão 4.2+ recomendada).
2. Importe o diretório do projeto `race-ai/`.
3. Pressione **F5** (ou clique no botão **Play**) para iniciar a simulação principal (`Levels/MainScene.tscn`).
4. Utilize o mouse e as teclas `WASD`, `Shift` e `Espaço` para navegar com a câmera livre e pressione `F3` para inspecionar os sensores da inteligência artificial em ação.
