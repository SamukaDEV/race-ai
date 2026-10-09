extends Node

@onready var simulation: Simulation = $Simulation
@onready var camera: FreeCamera = $Camera3D
@onready var track: TrackManager = $Track

func _ready() -> void:
	print("Neural F1 started")
	_setup_camera()
	if track and track.has_signal("track_loaded"):
		track.track_loaded.connect(_on_track_loaded)


func _setup_camera() -> void:
	if not camera or not is_instance_valid(camera):
		return

	var app_state: Node = get_node_or_null("/root/AppState")

	# 1. Se veio recentemente do Editor de Pistas (teste direto ou salvo)
	if app_state and app_state.get("has_saved_editor_camera"):
		if app_state.get("editor_camera_state") is Dictionary and not app_state.editor_camera_state.is_empty():
			camera.set_camera_state(app_state.editor_camera_state)
			print("📷 Câmera da Simulação sincronizada com o Editor de Pistas (Estado)")
			return
		elif app_state.get("editor_camera_transform"):
			camera.set_camera_transform(app_state.editor_camera_transform)
			print("📷 Câmera da Simulação sincronizada com o Editor de Pistas (Transform)")
			return

	# 2. Se a pista ativa possuir dados de câmera salvos no arquivo
	if track:
		var cam_cfg: Dictionary = track.get_camera_config()
		if not cam_cfg.is_empty():
			camera.set_camera_state(cam_cfg)
			print("📷 Câmera da Simulação restaurada a partir do arquivo da pista")
			return


func _on_track_loaded(_track_id: String, _piece_count: int) -> void:
	var app_state: Node = get_node_or_null("/root/AppState")
	# Se não estiver testando com câmera específica recente do editor, aplica a da pista carregada
	if not (app_state and app_state.get("is_testing_editor_track") and app_state.get("has_saved_editor_camera")):
		if track and camera and is_instance_valid(camera):
			var cam_cfg: Dictionary = track.get_camera_config()
			if not cam_cfg.is_empty():
				camera.set_camera_state(cam_cfg)
