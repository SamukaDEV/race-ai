class_name TrackManager
extends Node3D

## Gerenciador Dinâmico de Pistas e Checkpoints (LAPs)
## Instancia peças modulares e posiciona áreas de colisão para validação de voltas.

const TrackCatalogClass = preload("res://Scripts/Track/TrackCatalog.gd")

signal track_loaded(track_id: String, piece_count: int)

const TRACKS_DIR: String = "user://tracks/"
const PROJECT_TRACKS_DIR: String = "res://tracks/"

var total_checkpoints: int = 4
var current_track_data: Dictionary = {}
var current_track_config: Dictionary = {}

var _roads_container: Node3D
var _checkpoints_container: Node3D


func _ready() -> void:
	_ensure_containers()
	_load_initial_track()


func _ensure_containers() -> void:
	if not _roads_container:
		_roads_container = get_node_or_null("Roads")
		if not _roads_container:
			_roads_container = Node3D.new()
			_roads_container.name = "Roads"
			add_child(_roads_container)

	if not _checkpoints_container:
		_checkpoints_container = get_node_or_null("Checkpoints")
		if not _checkpoints_container:
			_checkpoints_container = Node3D.new()
			_checkpoints_container.name = "Checkpoints"
			add_child(_checkpoints_container)


func _load_initial_track() -> void:
	var app_state: Node = get_node_or_null("/root/AppState")
	# Se vier do editor para teste rápido com dados em memória
	if app_state and app_state.is_testing_editor_track and not app_state.temporary_editor_track_data.is_empty():
		load_track_from_dict(app_state.temporary_editor_track_data)
		return

	# Caso contrário, carrega a pista atual configurada no AppState
	var track_id: String = app_state.current_track_id if app_state else "default_circuit"
	load_track(track_id)


## Carrega uma pista pelo ID (busca em user://tracks/ ou res://tracks/)
func load_track(track_id: String) -> bool:
	var path_user := TRACKS_DIR + track_id + ".json"
	var path_res := PROJECT_TRACKS_DIR + track_id + ".json"

	var target_path := ""
	if FileAccess.file_exists(path_user):
		target_path = path_user
	elif FileAccess.file_exists(path_res):
		target_path = path_res
	else:
		push_warning("Pista não encontrada nos caminhos padrão: " + track_id)
		# Se não encontrar arquivo mas já tiver peças na cena (pista estática legado), cria checkpoints padrão
		if _roads_container and _roads_container.get_child_count() > 0:
			_create_default_checkpoints()
			return true
		return false

	var file := FileAccess.open(target_path, FileAccess.READ)
	if not file:
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("Erro ao interpretar JSON da pista: " + json.get_error_message())
		return false

	var data: Dictionary = json.data as Dictionary
	return load_track_from_dict(data)


## Reconstrói a pista inteira e seus checkpoints a partir de um dicionário
func load_track_from_dict(data: Dictionary) -> bool:
	_ensure_containers()
	current_track_data = data
	current_track_config = data.get("config", {})
	_clear_current_track()

	var pieces: Array = data.get("pieces", [])
	for piece_info in pieces:
		if not piece_info is Dictionary:
			continue
		var piece_id: String = piece_info.get("piece_id", "")
		var scene: PackedScene = TrackCatalogClass.get_scene(piece_id)
		if not scene:
			continue

		var piece_node: Node3D = scene.instantiate() as Node3D
		var pos_arr: Array = piece_info.get("position", [0.0, 0.0, 0.0])
		piece_node.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		var rot_y: float = float(piece_info.get("rotation_y_deg", 0.0))
		piece_node.rotation_degrees.y = rot_y

		_roads_container.add_child(piece_node)

	# Cria os checkpoints da pista
	var checkpoints: Array = data.get("checkpoints", [])
	if not checkpoints.is_empty():
		_build_checkpoints_from_data(checkpoints)
	else:
		_create_default_checkpoints()

	var track_id_name: String = data.get("track_id", "custom")
	emit_signal("track_loaded", track_id_name, pieces.size())
	return true


## Retorna os dados de posição e orientação da câmera salvos nesta pista
func get_camera_config() -> Dictionary:
	if current_track_data.has("camera") and current_track_data["camera"] is Dictionary:
		return current_track_data["camera"]
	return {}


func _clear_current_track() -> void:
	if _roads_container:
		for child in _roads_container.get_children():
			_roads_container.remove_child(child)
			child.queue_free()

	if _checkpoints_container:
		for child in _checkpoints_container.get_children():
			_checkpoints_container.remove_child(child)
			child.queue_free()


func _build_checkpoints_from_data(checkpoints: Array) -> void:
	total_checkpoints = checkpoints.size()
	for i in range(checkpoints.size()):
		var cp_info: Dictionary = checkpoints[i]
		var pos_arr: Array = cp_info.get("position", [0.0, 0.0, 0.0])
		var size_arr: Array = cp_info.get("size", [3.0, 2.0, 1.5])

		var area := Area3D.new()
		area.name = cp_info.get("name", "Checkpoint_%d" % i)
		area.position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		area.monitoring = true
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 1 # Apenas RaceCars

		var col_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(size_arr[0]), float(size_arr[1]), float(size_arr[2]))
		col_shape.shape = box
		area.add_child(col_shape)

		var idx := i
		area.body_entered.connect(func(body: Node3D):
			if body is RaceCar:
				body.register_checkpoint(idx, total_checkpoints)
		)

		_checkpoints_container.add_child(area)

	# Se houver portais de largada com FinishGate físico na pista, conecta ao último checkpoint (FinishLine)
	_connect_physical_finish_gates()


func _connect_physical_finish_gates() -> void:
	if not _roads_container or total_checkpoints <= 0:
		return
	var finish_idx := total_checkpoints - 1
	for road_piece in _roads_container.get_children():
		var gate := road_piece.get_node_or_null("FinishGate") as Area3D
		if gate:
			gate.body_entered.connect(func(body: Node3D):
				if body is RaceCar:
					body.register_checkpoint(finish_idx, total_checkpoints)
			)


func _create_default_checkpoints() -> void:
	var default_cps: Array = [
		{ "position": [4.0, 0.5, 9.0], "size": [3.0, 2.0, 1.5], "name": "Checkpoint_0" },
		{ "position": [7.0, 0.5, 2.5], "size": [1.5, 2.0, 3.0], "name": "Checkpoint_1" },
		{ "position": [0.0, 0.5, -1.0], "size": [3.0, 2.0, 1.5], "name": "Checkpoint_2" },
		{ "position": [0.5, 0.5, 4.0], "size": [3.0, 2.0, 1.5], "name": "FinishLine" }
	]
	_build_checkpoints_from_data(default_cps)


## Retorna a posição e rotação inicial para spawn dos carros na pista
func get_spawn_transform() -> Transform3D:
	if current_track_data.has("spawn_point"):
		var sp: Dictionary = current_track_data["spawn_point"]
		var pos_arr: Array = sp.get("position", [0.35, 0.3, 0.25])
		var rot_deg: float = float(sp.get("rotation_y_deg", 0.0))
		var t := Transform3D()
		t.origin = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		t = t.rotated(Vector3.UP, deg_to_rad(rot_deg))
		return t
	return Transform3D(Basis(), Vector3(0.35, 0.3, 0.25))


## Retorna o dicionário com as configurações de simulação e IA da pista ativa
func get_track_config() -> Dictionary:
	return current_track_config


## Procura todos os nós Marker3D dentro de SpawnPoints das peças RoadStartPositions,
## retornando suas transformações globais ordenadas da frente (pole) para trás.
func get_spawn_points() -> Array[Transform3D]:
	var collected_transforms: Array[Transform3D] = []
	if not _roads_container:
		return collected_transforms

	var pieces_with_spawns: Array[Node3D] = []
	for child in _roads_container.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Node3D and child.has_node("SpawnPoints"):
			pieces_with_spawns.append(child)

	if pieces_with_spawns.is_empty():
		return collected_transforms

	for piece in pieces_with_spawns:
		if piece.is_queued_for_deletion():
			continue
		piece.force_update_transform()
		var sp_node: Node = piece.get_node("SpawnPoints")
		for sp_child in sp_node.get_children():
			if sp_child is Marker3D:
				sp_child.force_update_transform()
				collected_transforms.append(sp_child.global_transform)

	if collected_transforms.is_empty():
		return collected_transforms

	# Ordena os marcadores: da vaga mais adiantada no sentido da pista para a mais recuada
	collected_transforms.sort_custom(
		func(a: Transform3D, b: Transform3D) -> bool:
			var fwd_a: Vector3 = a.basis.z
			var fwd_b: Vector3 = b.basis.z
			var proj_a: float = a.origin.dot(fwd_a)
			var proj_b: float = b.origin.dot(fwd_b)
			# Se estiverem praticamente na mesma linha longitudinal, ordena da esquerda para direita
			if abs(proj_a - proj_b) < 0.15:
				var side_a: float = a.origin.dot(a.basis.x)
				var side_b: float = b.origin.dot(b.basis.x)
				return side_a < side_b
			return proj_a > proj_b
	)

	return collected_transforms
