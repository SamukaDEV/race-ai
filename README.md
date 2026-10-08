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
* 🛠️ **Editor 3D de Pistas Integrado (`TrackEditor`)**: Crie circuitos personalizados em tempo real com snap de grade ($1.0\text{m}$), rotação angular, preview fantasma translúcido, checkpoints automáticos e teste imediato na simulação.
* 🏠 **Menu Principal & Seletor de Circuitos**: Seleção visual de pistas pré-fabricadas (`res://tracks/`) e pistas criadas pelo usuário (`user://tracks/`).
* 📡 **Sensores Raycast Otimizados**: 5 feixes de proximidade por veículo filtrados na camada física do circuito (não colidem entre si) com alternância visual via tecla `F3`.
* 📷 **Câmera Livre Configurável (`FreeCamera`)**: Navegação fluida em 3D ou planar horizontal com controles familiares (`WASD`, `Shift`, `Espaço`), rotação por mouse e ajuste de velocidade dinâmico por scroll.
* 🏁 **Contagem de Voltas (LAPs) & HUD em Tempo Real**: Telemetria na tela com voltas do líder, recorde histórico da sessão, status dos carros e setores/checkpoints validados.
* 💾 **Saves Isolados por Pista**: Sistema inteligente que particiona os saves genéticos (`user://saves/<track_id>/`), impedindo que o aprendizado de uma pista sobrescreva o de outra com geometria diferente.
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

### Editor 3D de Pistas (`TrackEditor`)
| Comando | Tecla / Ação | Função |
| :--- | :--- | :--- |
| **Posicionar Peça** | `Botão Esquerdo` | Instancia a peça modular selecionada na coordenada da grade |
| **Remover Peça** | `Botão Direito` | Remove a peça sob o cursor do mouse |
| **Rotacionar Peça** | `R` | Gira a orientação da peça em $90^\circ$ |
| **Alternar Catálogo** | Botões da Barra Inferior | Escolhe entre retas, curvas, largada, lombada ou cruzamento |
| **Testar Circuito** | Botão "▶ Testar Pista" | Transfere a pista montada diretamente para a simulação de IA |

### Simulação e Persistência
| Comando | Tecla / Botão | Função |
| :--- | :--- | :--- |
| **Salvar Estado Rápido** | `F5` ou Botão no HUD | Salva no diretório específico da pista (`user://saves/<track_id>/`) |
| **Carregar Estado Rápido** | `F6` ou Botão no HUD | Restaura imediatamente a simulação e a câmera da pista ativa |
| **Depuração de Sensores** | `F3` | Liga ou desliga as linhas visuais dos sensores de todos os carros em tempo real |
| **Voltar ao Menu** | Botão `🏠 Menu` | Retorna para a tela de seleção de pistas |

---

## 📚 Documentação Técnica (`docs/`)

Para detalhes arquiteturais aprofundados, consulte os documentos dedicados na pasta `docs/`:

* 🛠️ [**Editor de Pistas & Menu Principal**](docs/track_editor.md): Arquitetura do editor, catálogo modular, serialização JSON e ciclo de vida.
* 💾 [**Sistema de Save & Load Particionado**](docs/save_load_system.md): Persistência por circuito de genomas, geração, câmera e modelos campeões.
* 📖 [**Visão Geral do Projeto**](docs/project_overview.md): Fluxo completo de simulação e conceitos de neuroevolução.
* 📷 [**Guia da Câmera Livre (`FreeCamera`)**](docs/free_camera.md): Modos de operação, propriedades do Inspector e boas práticas.
* 🧬 [**Genomas e Algoritmo Genético**](docs/genomes_evolution.md): Representação de 434 genes, elitismo, mutação e reprodução.
* 🧠 [**Rede Neural Artificial**](docs/neural_network.md): Topologia de camadas, ativação $\tanh$, normalização de entradas e saídas de controle.
* 🚗 [**Veículos e Sensores**](docs/car_sensors.md): Física do carro, isolamento de camadas físicas e renderização de depuração.
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
	• MainMenu.tscn (Menu principal com seleção de circuitos)
	• MainScene.tscn (Cena principal de execução da simulação)
	• TrackEditor.tscn (Editor 3D de pistas modulares)
• 📂 Models/ (Cenas modulares empacotadas .tscn e materiais .tres)
• 📂 Scripts/
	• 📂 Car/ (Car.gd e Sensors.gd)
	• 📂 Evolution/ (Population.gd, Evolution.gd e Fitness.gd)
	• 📂 Global/ (AppState.gd - singleton de gerenciamento)
	• 📂 Neural/ (NeuralNetwork.gd, Layer.gd e Genome.gd)
	• 📂 Simulation/ (Simulation.gd e SaveManager.gd)
	• 📂 Track/ (Track.gd e TrackCatalog.gd)
	• 📂 TrackEditor/ (TrackEditor.gd)
	• 📂 UI/ (MainMenu.gd e HUD.gd)
	• FreeCamera.gd (Câmera livre 3D configurável)
	• main.gd (Ponto de entrada da aplicação)
• 📂 tracks/ (Circuitos em formato JSON)
• 📂 docs/ (Documentação técnica detalhada em Markdown)
```

---

## 🚀 Como Executar

1. Abra o **Godot Engine 4** (versão 4.2+ recomendada).
2. Importe o diretório do projeto `race-ai/`.
3. Pressione **F5** (ou clique no botão **Play**) para abrir o **Menu Principal** (`Levels/MainMenu.tscn`).
4. Selecione **Iniciar Simulação** para treinar a IA na pista oficial ou em pistas criadas, ou clique em **Editor de Pistas** para criar e testar seu próprio traçado 3D!
5. Durante a simulação, utilize o mouse e as teclas `WASD`, `Shift` e `Espaço` para navegar com a câmera livre e pressione `F3` para inspecionar os sensores da inteligência artificial em ação.
