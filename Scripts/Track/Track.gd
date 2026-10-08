class_name TrackManager
extends Node3D

## Gerenciador de Checkpoints e Detecção de Voltas (LAPs)
## Cria áreas de colisão ao longo da pista para validar se o carro percorreu
## todos os setores do circuito na ordem correta antes de registrar uma nova volta.

const TOTAL_CHECKPOINTS: int = 4

# Definição dos checkpoints: [Posição, Tamanho da Caixa]
# 0: Saída da Curva 1 / Entrada da Reta Oposta
# 1: Setor Lateral Oposto
# 2: Curva de Retorno à Reta Principal
# 3: Linha de Chegada (Finish Line) na Reta Principal
var checkpoint_data: Array = [
	{ "pos": Vector3(4.0, 0.5, 9.0), "size": Vector3(3.0, 2.0, 1.5), "name": "Checkpoint_0" },
	{ "pos": Vector3(7.0, 0.5, 2.5), "size": Vector3(1.5, 2.0, 3.0), "name": "Checkpoint_1" },
	{ "pos": Vector3(0.0, 0.5, -1.0), "size": Vector3(3.0, 2.0, 1.5), "name": "Checkpoint_2" },
	{ "pos": Vector3(0.5, 0.5, 4.0), "size": Vector3(3.0, 2.0, 1.5), "name": "FinishLine" }
]

func _ready() -> void:
	_create_checkpoints()

func _create_checkpoints() -> void:
	for i in range(checkpoint_data.size()):
		var data: Dictionary = checkpoint_data[i]
		
		var area := Area3D.new()
		area.name = data["name"]
		area.position = data["pos"]
		
		# Configura para detectar carros sem bloquear física ou sensores
		area.monitoring = true
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 1 # Layer dos RaceCar
		
		var col_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = data["size"]
		col_shape.shape = box
		area.add_child(col_shape)
		
		var checkpoint_idx := i
		area.body_entered.connect(func(body: Node3D):
			_on_checkpoint_entered(body, checkpoint_idx)
		)
		
		add_child(area)

func _on_checkpoint_entered(body: Node3D, checkpoint_idx: int) -> void:
	if body is RaceCar:
		body.register_checkpoint(checkpoint_idx, TOTAL_CHECKPOINTS)
