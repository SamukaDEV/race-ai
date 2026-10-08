# 💾 Sistema de Exportação e Importação (Save & Load)

O projeto conta com um sistema de persistência gerenciado por [SaveManager.gd](file:///Users/samukadev/Documents/Godot%20Projects/race-ai/Scripts/Simulation/SaveManager.gd), permitindo salvar o estado da neuroevolução, as configurações e enquadramento da câmera e modelos de pilotos campeões.

---

## 🎮 Controles e Atalhos

| Ação | Tecla / Botão | Descrição |
| :--- | :--- | :--- |
| **Salvar Estado Rápido** | `F5` ou Botão `💾 Salvar [F5]` | Salva a geração atual, todos os genomas da população, histórico de voltas e a posição da câmera |
| **Carregar Estado Rápido** | `F6` ou Botão `📂 Carregar [F6]` | Restaura a simulação e reposiciona a câmera imediatamente |
| **Exportar Campeão** | Botão `⭐ Exportar Campeão` | Salva um arquivo JSON dedicado contendo apenas o genoma do piloto com maior pontuação |

---

## 📂 Locais de Armazenamento

Os arquivos são gravados simultaneamente em dois locais:
1. **Pasta de Dados do Usuário (`user://saves/`)**:
   * Padrão oficial do Godot para arquivos graváveis pelo usuário final.
   * macOS: `~/Library/Application Support/Godot/app_userdata/race-ai/saves/`
2. **Pasta do Projeto (`res://saves/`)**:
   * Gravado diretamente dentro do repositório para facilitar versionamento e compartilhamento via Git.

### Arquivos Gerados
* `quicksave.json`: Contém o snapshot completo da simulação (geração, genomas, recordes) e o estado da câmera livre (posição 3D, ângulos yaw/pitch, velocidade).
* `best_pilot.json`: Contém o genoma individual do melhor piloto treinado até o momento, acompanhado de seu fitness e da geração em que atingiu a marca.

---

## 📄 Estrutura do Arquivo JSON (`quicksave.json`)

```json
{
  "version": 1,
  "timestamp": "2026-10-08T10:30:00",
  "simulation": {
    "all_time_max_laps": 2,
    "current_max_laps": 1,
    "population": {
      "generation": 8,
      "population_size": 10,
      "genomes": [
        {
          "fitness": 1420.5,
          "genes": [0.15, -0.42, 0.88, "... (434 valores) ..."]
        }
      ]
    }
  },
  "camera": {
    "position": [-1.29, 0.50, 2.29],
    "yaw": 0.075,
    "pitch": 0.139,
    "base_speed": 3.0,
    "movement_mode": 0,
    "mouse_control_mode": 0
  }
}
```

---

## 🔔 Feedback Visual (Toast Notifications)

Ao salvar ou carregar, uma notificação flutuante temporária aparece centralizada no topo da tela indicando o sucesso ou a causa de eventuais problemas:
* `✅ Progresso salvo com sucesso! (Geração #8)`
* `✅ Save carregado com sucesso! (Geração #8)`
* `⭐ Piloto Campeão exportado! (Fitness: 1420.5)`
* `⚠️ Nenhum arquivo de save encontrado para carregar!`
