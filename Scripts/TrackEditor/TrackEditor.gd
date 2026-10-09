class_name TrackEditor
extends Node3D

## Editor Interativo de Pistas 3D
## Permite criar, editar, rotacionar e posicionar peças modulares em grade 3D,
## gerando arquivos JSON de pistas compatíveis com o simulador e associadas a saves isolados.

const TrackCatalogClass = preload("res://Scripts/Track/TrackCatalog.gd")

const ORDERED_PIECES: Array[String] = [
	"RoadStart",
	"RoadStartPositions",
	"RoadStraight",
	"RoadStraightLong",
	"RoadCornerSmall",
	"RoadCornerLarge",
	"RoadCornerLarger",
	"RoadBump",
	"RoadCrossing"
]

@export var grid_size: float = 1.0
@export var default_track_name: String = "Minha Pista"

@onready var camera: Camera3D = $Camera3D
@onready var roads_parent: Node3D = $TrackPieces
@onready var ghost_parent: Node3D = $GhostPiece

# Estrutura de armazenamento das peças colocadas: chave "x,z" -> { piece_id, pos, rot, node }
var placed_pieces: Dictionary = {}
var current_piece_id: String = "RoadStraight"
var current_rotation_y: float = 0.0

var _ghost_node: Node3D = null
var _hovered_grid_pos: Vector3 = Vector3.ZERO
var _is_hovering_ground: bool = false
var _is_mouse_over_ui: bool = false

# Configurações da simulação e IA associadas à pista
var current_track_config: Dictionary = {
	"population_size": 4,
	"max_idle_time": 3.0,
	"enable_idle_timeout": true,
	"mutation_rate": 0.05,
	"mutation_power": 0.2,
	"elite_count": 1,
	"max_speed": 300.0,
	"acceleration": 200.0,
	"brake_force": 100.0,
	"steering_speed": 2.5
}

# Nós de interface criados dinamicamente
var _line_edit_name: LineEdit
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _load_modal: PanelContainer
var _track_list_container: VBoxContainer

# Nós de interface do modal de configurações
var _settings_modal: PanelContainer
var _cfg_lbl_spots: Label
var _cfg_spin_pop: SpinBox
var _cfg_spin_idle: SpinBox
var _cfg_check_idle: CheckBox
var _cfg_spin_mut_rate: SpinBox
var _cfg_spin_mut_power: SpinBox
var _cfg_spin_elite: SpinBox
var _cfg_spin_speed: SpinBox
var _cfg_spin_accel: SpinBox
var _cfg_spin_brake: SpinBox
var _cfg_spin_steer: SpinBox

# Sidebar Vertical e Miniaturas
var _sidebar_panel: PanelContainer
var _piece_buttons: Dictionary = {}
var _thumbnail_cache: Dictionary = {}


func _ready() -> void:
	_setup_editor_ui()
	_update_ghost_piece()

	# Restaura a pose da câmera do editor se estiver retornando de um teste
	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state and app_state.has_saved_editor_camera and camera:
		if camera is FreeCamera:
			camera.set_camera_transform(app_state.editor_camera_transform)
		else:
			camera.transform = app_state.editor_camera_transform

	# Restaura a pista anterior se estiver retornando de um teste ou se houver pista ativa
	if app_state and not app_state.temporary_editor_track_data.is_empty():
		load_track_from_dict(app_state.temporary_editor_track_data)
		_show_toast("🛠️ Retomando edição da pista!")
	elif app_state and app_state.current_track_id != "" and app_state.current_track_id != "default_circuit":
		var p_user: String = "user://tracks/" + str(app_state.current_track_id) + ".json"
		var p_res: String = "res://tracks/" + str(app_state.current_track_id) + ".json"
		if FileAccess.file_exists(p_user):
			load_track_from_file(p_user)
		elif FileAccess.file_exists(p_res):
			load_track_from_file(p_res)


func _process(_delta: float) -> void:
	_update_mouse_raycast()


func _unhandled_input(event: InputEvent) -> void:
	# Solta o foco de campos de texto ao pressionar ESC ou ENTER
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER):
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
			get_viewport().set_input_as_handled()
			return

	# Clique do mouse solta foco de LineEdits
	if event is InputEventMouseButton and event.pressed:
		var f := get_viewport().gui_get_focus_owner()
		if f and f is LineEdit:
			f.release_focus()

	if _is_mouse_over_ui:
		return

	# Atalho 'R' para girar a peça atual em 90 graus
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			current_rotation_y = fposmod(current_rotation_y + 90.0, 360.0)
			_update_ghost_transform()
			get_viewport().set_input_as_handled()

	# Clique do mouse para colocar ou remover peças
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _is_hovering_ground:
			place_piece_at(_hovered_grid_pos, current_piece_id, current_rotation_y)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and _is_hovering_ground:
			remove_piece_at(_hovered_grid_pos)
			get_viewport().set_input_as_handled()


func _update_mouse_raycast() -> void:
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var ground_plane := Plane(Vector3.UP, 0.0)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_dir)

	if intersection != null:
		_is_hovering_ground = true
		var hit: Vector3 = intersection
		var gx: float = round(hit.x / grid_size) * grid_size
		var gz: float = round(hit.z / grid_size) * grid_size
		_hovered_grid_pos = Vector3(gx, 0.0, gz)

		if _ghost_node and is_instance_valid(_ghost_node):
			_ghost_node.visible = true
			_update_ghost_transform()
	else:
		_is_hovering_ground = false
		if _ghost_node and is_instance_valid(_ghost_node):
			_ghost_node.visible = false


func _update_ghost_piece() -> void:
	if _ghost_node and is_instance_valid(_ghost_node):
		_ghost_node.queue_free()
		_ghost_node = null

	var scene: PackedScene = TrackCatalogClass.get_scene(current_piece_id)
	if not scene:
		return

	_ghost_node = scene.instantiate() as Node3D
	_apply_ghost_transparency(_ghost_node)
	ghost_parent.add_child(_ghost_node)
	_update_ghost_transform()


func _update_ghost_transform() -> void:
	if not _ghost_node or not is_instance_valid(_ghost_node):
		return
	_ghost_node.position = _hovered_grid_pos
	_ghost_node.rotation_degrees = Vector3(0.0, current_rotation_y, 0.0)


func _apply_ghost_transparency(node: Node) -> void:
	# Desativa colisões na peça fantasma para não interferir no editor
	if node is CollisionShape3D or node is StaticBody3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED

	if node is MeshInstance3D:
		var ghost_mat := StandardMaterial3D.new()
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.55)
		ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = ghost_mat

	for child in node.get_children():
		_apply_ghost_transparency(child)


func _grid_key(pos: Vector3) -> String:
	return "%.1f,%.1f" % [pos.x, pos.z]


func place_piece_at(pos: Vector3, piece_id: String, rot_y: float) -> void:
	var key := _grid_key(pos)

	# Se já houver peça nessa coordenada, remove a anterior
	if placed_pieces.has(key):
		remove_piece_at(pos)

	var scene: PackedScene = TrackCatalogClass.get_scene(piece_id)
	if not scene:
		return

	var node := scene.instantiate() as Node3D
	node.position = pos
	node.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	roads_parent.add_child(node)

	placed_pieces[key] = {
		"piece_id": piece_id,
		"position": [pos.x, pos.y, pos.z],
		"rotation_y_deg": rot_y,
		"node": node
	}


func remove_piece_at(pos: Vector3) -> void:
	var key := _grid_key(pos)
	if placed_pieces.has(key):
		var piece_info: Dictionary = placed_pieces[key]
		var node: Node3D = piece_info.get("node")
		if node and is_instance_valid(node):
			node.queue_free()
		placed_pieces.erase(key)


func clear_all_pieces() -> void:
	for key in placed_pieces.keys():
		var node: Node3D = placed_pieces[key].get("node")
		if node and is_instance_valid(node):
			node.queue_free()
	placed_pieces.clear()
	_show_toast("🧹 Pista limpa!")


## Exporta a pista atual para dicionário
func get_track_data() -> Dictionary:
	var track_name := _line_edit_name.text.strip_edges() if _line_edit_name else default_track_name
	if track_name == "":
		track_name = default_track_name

	var track_id := track_name.to_lower().replace(" ", "_")

	var pieces_arr: Array = []
	var spawn_pos := Vector3(0.35, 0.3, 0.25)
	var spawn_rot := 0.0

	for key in placed_pieces.keys():
		var p: Dictionary = placed_pieces[key]
		var piece_id: String = p["piece_id"]
		var pos_arr: Array = p["position"]
		var rot: float = p["rotation_y_deg"]

		pieces_arr.append({
			"piece_id": piece_id,
			"position": pos_arr,
			"rotation_y_deg": rot
		})

		# Se for uma peça de largada, usa como ponto de spawn principal
		if piece_id == "RoadStart" or piece_id == "RoadStartPositions":
			spawn_pos = Vector3(pos_arr[0], pos_arr[1] + 0.3, pos_arr[2])
			spawn_rot = rot

	# Gera checkpoints automáticos baseados nos cantos e extremos da pista
	var checkpoints_arr := _generate_checkpoints(pieces_arr, spawn_pos)

	return {
		"track_id": track_id,
		"track_name": track_name,
		"created_at": Time.get_datetime_string_from_system(),
		"grid_size": grid_size,
		"config": current_track_config.duplicate(),
		"spawn_point": {
			"position": [spawn_pos.x, spawn_pos.y, spawn_pos.z],
			"rotation_y_deg": spawn_rot
		},
		"pieces": pieces_arr,
		"checkpoints": checkpoints_arr
	}


## Retorna o total de vagas de largada físicas disponíveis nas peças RoadStartPositions colocadas
func get_detected_spawn_spots_count() -> int:
	var count: int = 0
	for piece_info in placed_pieces.values():
		var pid: String = piece_info.get("piece_id", "")
		if pid == "RoadStartPositions":
			count += 4
	return count


func _generate_checkpoints(pieces: Array, spawn_pos: Vector3) -> Array:
	if pieces.is_empty():
		return []

	# Encontra extremos do circuito (norte, sul, leste, oeste)
	var min_x := 999999.0
	var max_x := -999999.0
	var min_z := 999999.0
	var max_z := -999999.0

	for p in pieces:
		var pos: Array = p["position"]
		min_x = min(min_x, pos[0])
		max_x = max(max_x, pos[0])
		min_z = min(min_z, pos[2])
		max_z = max(max_z, pos[2])

	var mid_x := (min_x + max_x) * 0.5
	var mid_z := (min_z + max_z) * 0.5

	# Cria 4 checkpoints cardeais ao longo dos quadrantes
	return [
		{ "position": [max_x, 0.5, mid_z], "size": [3.0, 2.0, 3.0], "name": "Sector_1" },
		{ "position": [mid_x, 0.5, max_z], "size": [3.0, 2.0, 3.0], "name": "Sector_2" },
		{ "position": [min_x, 0.5, mid_z], "size": [3.0, 2.0, 3.0], "name": "Sector_3" },
		{ "position": [spawn_pos.x, 0.5, spawn_pos.z], "size": [3.5, 2.0, 2.0], "name": "FinishLine" }
	]


## Salva a pista atual em arquivo JSON em user://tracks/ e res://tracks/
func save_track() -> bool:
	if placed_pieces.is_empty():
		_show_toast("⚠️ Coloque ao menos uma peça antes de salvar!", true)
		return false

	var data := get_track_data()
	var track_id: String = data["track_id"]

	var dir_user := "user://tracks/"
	if not DirAccess.dir_exists_absolute(dir_user):
		DirAccess.make_dir_recursive_absolute(dir_user)

	var dir_res := "res://tracks/"
	if not DirAccess.dir_exists_absolute(dir_res):
		DirAccess.make_dir_recursive_absolute(dir_res)

	var json_str := JSON.stringify(data, "\t")

	var user_file := FileAccess.open(dir_user + track_id + ".json", FileAccess.WRITE)
	if user_file:
		user_file.store_string(json_str)
		user_file.close()

	var res_file := FileAccess.open(dir_res + track_id + ".json", FileAccess.WRITE)
	if res_file:
		res_file.store_string(json_str)
		res_file.close()

	_show_toast("✅ Pista [%s] salva com sucesso!" % data["track_name"])
	return true


## Reconstrói a pista no editor a partir de um dicionário de dados
func load_track_from_dict(data: Dictionary) -> bool:
	clear_all_pieces()

	if data.has("config") and data["config"] is Dictionary:
		current_track_config = data["config"].duplicate()
		if not current_track_config.has("acceleration"):
			current_track_config["acceleration"] = 200.0
		if not current_track_config.has("brake_force"):
			current_track_config["brake_force"] = 100.0
		if not current_track_config.has("steering_speed"):
			current_track_config["steering_speed"] = 2.5
	else:
		current_track_config = {
			"population_size": 4,
			"max_idle_time": 3.0,
			"enable_idle_timeout": true,
			"mutation_rate": 0.05,
			"mutation_power": 0.2,
			"elite_count": 1,
			"max_speed": 300.0,
			"acceleration": 200.0,
			"brake_force": 100.0,
			"steering_speed": 2.5
		}

	if _line_edit_name:
		_line_edit_name.text = data.get("track_name", "Pista Carregada")

	var pieces: Array = data.get("pieces", [])
	for p_info in pieces:
		var p_id: String = p_info.get("piece_id", "RoadStraight")
		var pos_arr: Array = p_info.get("position", [0.0, 0.0, 0.0])
		var rot: float = float(p_info.get("rotation_y_deg", 0.0))
		place_piece_at(Vector3(pos_arr[0], pos_arr[1], pos_arr[2]), p_id, rot)

	return true


## Carrega uma pista a partir de um arquivo JSON
func load_track_from_file(filepath: String) -> bool:
	if not FileAccess.file_exists(filepath):
		_show_toast("❌ Arquivo não encontrado: " + filepath, true)
		return false

	var file := FileAccess.open(filepath, FileAccess.READ)
	if not file:
		return false

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		_show_toast("❌ Erro de JSON ao carregar pista!", true)
		return false

	var data: Dictionary = json.data as Dictionary
	var ok := load_track_from_dict(data)
	if ok:
		_show_toast("✅ Pista [%s] carregada!" % data.get("track_name", ""))
	return ok


## Inicia a simulação imediatamente com a pista desenhada
func test_in_simulation() -> void:
	if placed_pieces.is_empty():
		_show_toast("⚠️ Desenhe uma pista antes de testar!", true)
		return

	var track_data := get_track_data()
	# Salva a pista para que os dados persistam
	save_track()

	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state:
		app_state.current_track_id = track_data["track_id"]
		app_state.current_track_name = track_data["track_name"]
		app_state.is_testing_editor_track = true
		app_state.temporary_editor_track_data = track_data
		if camera:
			app_state.editor_camera_transform = camera.transform
			app_state.has_saved_editor_camera = true

	get_tree().change_scene_to_file("res://Levels/MainScene.tscn")


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")


# ==============================================================================
# CONSTRUÇÃO DA INTERFACE DO EDITOR (UI)
# ==============================================================================
func _setup_editor_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	canvas.scale = Vector2(0.8, 0.8)

	# --- BARRA SUPERIOR COMPACTA (AÇÕES & NOME DA PISTA) ---
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 10
	top_panel.offset_top = 8
	top_panel.offset_right = -10
	top_panel.offset_bottom = 50

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	top_style.set_corner_radius_all(6)
	top_style.border_width_left = 1
	top_style.border_width_top = 1
	top_style.border_width_right = 1
	top_style.border_width_bottom = 1
	top_style.border_color = Color(0.18, 0.25, 0.38, 0.8)
	top_style.content_margin_left = 10
	top_style.content_margin_right = 10
	top_style.content_margin_top = 4
	top_style.content_margin_bottom = 4
	top_panel.add_theme_stylebox_override("panel", top_style)
	canvas.add_child(top_panel)

	_connect_mouse_filter(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_panel.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🛠️ EDITOR"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	top_hbox.add_child(title_lbl)

	top_hbox.add_child(VSeparator.new())

	var lbl_name := Label.new()
	lbl_name.text = "Nome:"
	lbl_name.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(lbl_name)

	_line_edit_name = LineEdit.new()
	_line_edit_name.text = default_track_name
	_line_edit_name.custom_minimum_size = Vector2(140, 26)
	_line_edit_name.add_theme_font_size_override("font_size", 12)
	_line_edit_name.text_submitted.connect(func(_t): _line_edit_name.release_focus())
	top_hbox.add_child(_line_edit_name)

	var btn_save := Button.new()
	btn_save.text = "💾 Salvar"
	btn_save.add_theme_font_size_override("font_size", 12)
	btn_save.pressed.connect(save_track)
	top_hbox.add_child(btn_save)

	var btn_load := Button.new()
	btn_load.text = "📂 Carregar"
	btn_load.add_theme_font_size_override("font_size", 12)
	btn_load.pressed.connect(_open_load_modal)
	top_hbox.add_child(btn_load)

	var btn_settings := Button.new()
	btn_settings.text = "⚙️ Configs"
	btn_settings.add_theme_font_size_override("font_size", 12)
	btn_settings.pressed.connect(_open_settings_modal)
	top_hbox.add_child(btn_settings)

	var btn_clear := Button.new()
	btn_clear.text = "🧹 Limpar"
	btn_clear.add_theme_font_size_override("font_size", 12)
	btn_clear.pressed.connect(clear_all_pieces)
	top_hbox.add_child(btn_clear)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var btn_test := Button.new()
	btn_test.text = "🏎️ Testar"
	btn_test.add_theme_font_size_override("font_size", 12)
	btn_test.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	btn_test.pressed.connect(test_in_simulation)
	top_hbox.add_child(btn_test)

	var btn_menu := Button.new()
	btn_menu.text = "🏠 Menu"
	btn_menu.add_theme_font_size_override("font_size", 12)
	btn_menu.pressed.connect(go_to_main_menu)
	top_hbox.add_child(btn_menu)

	# --- SIDEBAR VERTICAL NA LATERAL ESQUERDA (SELETOR COM MINIATURAS) ---
	_setup_sidebar_ui(canvas)

	# --- DICA DE CONTROLES NO RODAPÉ ---
	_setup_bottom_hint_ui(canvas)

	# --- MODAL DE CARREGAMENTO ---
	_setup_load_modal(canvas)

	# --- MODAL DE CONFIGURAÇÕES DA PISTA ---
	_setup_settings_modal(canvas)

	# --- TOAST NOTIFICATION ---
	_setup_toast_ui(canvas)


func _setup_load_modal(canvas: CanvasLayer) -> void:
	_load_modal = PanelContainer.new()
	_load_modal.visible = false
	_load_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_load_modal.custom_minimum_size = Vector2(340, 260)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.98)
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.8, 1.0, 0.8)
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	_load_modal.add_theme_stylebox_override("panel", style)
	canvas.add_child(_load_modal)

	_connect_mouse_filter(_load_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_load_modal.add_child(vbox)

	var title := Label.new()
	title.text = "📂 SELECIONE UMA PISTA"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 150)
	vbox.add_child(scroll)

	_track_list_container = VBoxContainer.new()
	_track_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_track_list_container)

	var btn_close := Button.new()
	btn_close.text = "Fechar"
	btn_close.pressed.connect(func(): _load_modal.visible = false)
	vbox.add_child(btn_close)


func _open_load_modal() -> void:
	for child in _track_list_container.get_children():
		child.queue_free()

	var tracks := _list_available_tracks()
	if tracks.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhuma pista encontrada."
		_track_list_container.add_child(empty_lbl)
	else:
		for trk in tracks:
			var btn := Button.new()
			btn.text = trk["name"] + " (" + trk["id"] + ")"
			var path: String = trk["path"]
			btn.pressed.connect(func():
				load_track_from_file(path)
				_load_modal.visible = false
			)
			_track_list_container.add_child(btn)

	_load_modal.visible = true


func _setup_settings_modal(canvas: CanvasLayer) -> void:
	_settings_modal = PanelContainer.new()
	_settings_modal.visible = false
	_settings_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings_modal.custom_minimum_size = Vector2(460, 480)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.98)
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.8, 1.0, 0.8)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	_settings_modal.add_theme_stylebox_override("panel", style)
	canvas.add_child(_settings_modal)

	_connect_mouse_filter(_settings_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_settings_modal.add_child(vbox)

	var title := Label.new()
	title.text = "⚙️ CONFIGURAÇÕES DA PISTA & SIMULAÇÃO"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(title)

	_cfg_lbl_spots = Label.new()
	_cfg_lbl_spots.add_theme_font_size_override("font_size", 11)
	_cfg_lbl_spots.text = "🚦 Vagas de largada detectadas: 0"
	vbox.add_child(_cfg_lbl_spots)

	vbox.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	# 1. População de Carros
	var lbl_pop := Label.new()
	lbl_pop.text = "Quantidade de Carros:"
	lbl_pop.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_pop)

	var pop_hbox := HBoxContainer.new()
	pop_hbox.add_theme_constant_override("separation", 6)
	_cfg_spin_pop = SpinBox.new()
	_cfg_spin_pop.min_value = 1
	_cfg_spin_pop.max_value = 100
	_cfg_spin_pop.step = 1
	_cfg_spin_pop.value = 4
	pop_hbox.add_child(_cfg_spin_pop)

	var btn_auto_pop := Button.new()
	btn_auto_pop.text = "Auto Vagas"
	btn_auto_pop.add_theme_font_size_override("font_size", 10)
	btn_auto_pop.pressed.connect(func():
		var detected := get_detected_spawn_spots_count()
		_cfg_spin_pop.value = max(1, detected)
	)
	pop_hbox.add_child(btn_auto_pop)
	grid.add_child(pop_hbox)

	# 2. Timeout de Inatividade
	var lbl_idle := Label.new()
	lbl_idle.text = "Timeout Parado (seg):"
	lbl_idle.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_idle)

	var idle_hbox := HBoxContainer.new()
	idle_hbox.add_theme_constant_override("separation", 6)
	_cfg_check_idle = CheckBox.new()
	_cfg_check_idle.text = "Ativo"
	_cfg_check_idle.button_pressed = true
	idle_hbox.add_child(_cfg_check_idle)

	_cfg_spin_idle = SpinBox.new()
	_cfg_spin_idle.min_value = 1.0
	_cfg_spin_idle.max_value = 20.0
	_cfg_spin_idle.step = 0.5
	_cfg_spin_idle.value = 3.0
	idle_hbox.add_child(_cfg_spin_idle)
	grid.add_child(idle_hbox)

	# 3. Taxa de Mutação
	var lbl_mut_rate := Label.new()
	lbl_mut_rate.text = "Taxa de Mutação:"
	lbl_mut_rate.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_mut_rate)

	_cfg_spin_mut_rate = SpinBox.new()
	_cfg_spin_mut_rate.min_value = 0.01
	_cfg_spin_mut_rate.max_value = 0.50
	_cfg_spin_mut_rate.step = 0.01
	_cfg_spin_mut_rate.value = 0.05
	grid.add_child(_cfg_spin_mut_rate)

	# 4. Força da Mutação
	var lbl_mut_pow := Label.new()
	lbl_mut_pow.text = "Força da Mutação:"
	lbl_mut_pow.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_mut_pow)

	_cfg_spin_mut_power = SpinBox.new()
	_cfg_spin_mut_power.min_value = 0.05
	_cfg_spin_mut_power.max_value = 1.50
	_cfg_spin_mut_power.step = 0.05
	_cfg_spin_mut_power.value = 0.20
	grid.add_child(_cfg_spin_mut_power)

	# 5. Elitismo
	var lbl_elite := Label.new()
	lbl_elite.text = "Carros de Elite (Clonados):"
	lbl_elite.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_elite)

	_cfg_spin_elite = SpinBox.new()
	_cfg_spin_elite.min_value = 1
	_cfg_spin_elite.max_value = 5
	_cfg_spin_elite.step = 1
	_cfg_spin_elite.value = 1
	grid.add_child(_cfg_spin_elite)

	# 6. Velocidade Máxima
	var lbl_speed := Label.new()
	lbl_speed.text = "Velocidade Máxima:"
	lbl_speed.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_speed)

	_cfg_spin_speed = SpinBox.new()
	_cfg_spin_speed.min_value = 10.0
	_cfg_spin_speed.max_value = 1000.0
	_cfg_spin_speed.step = 5.0
	_cfg_spin_speed.value = 300.0
	grid.add_child(_cfg_spin_speed)

	# 7. Aceleração
	var lbl_accel := Label.new()
	lbl_accel.text = "Aceleração do Motor:"
	lbl_accel.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_accel)

	_cfg_spin_accel = SpinBox.new()
	_cfg_spin_accel.min_value = 10.0
	_cfg_spin_accel.max_value = 1000.0
	_cfg_spin_accel.step = 10.0
	_cfg_spin_accel.value = 200.0
	grid.add_child(_cfg_spin_accel)

	# 8. Força dos Freios
	var lbl_brake := Label.new()
	lbl_brake.text = "Força dos Freios:"
	lbl_brake.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_brake)

	_cfg_spin_brake = SpinBox.new()
	_cfg_spin_brake.min_value = 10.0
	_cfg_spin_brake.max_value = 600.0
	_cfg_spin_brake.step = 10.0
	_cfg_spin_brake.value = 100.0
	grid.add_child(_cfg_spin_brake)

	# 9. Velocidade ao Virar (Esterçamento)
	var lbl_steer := Label.new()
	lbl_steer.text = "Velocidade de Esterçamento:"
	lbl_steer.add_theme_font_size_override("font_size", 12)
	grid.add_child(lbl_steer)

	_cfg_spin_steer = SpinBox.new()
	_cfg_spin_steer.min_value = 0.5
	_cfg_spin_steer.max_value = 10.0
	_cfg_spin_steer.step = 0.1
	_cfg_spin_steer.value = 2.5
	grid.add_child(_cfg_spin_steer)

	vbox.add_child(HSeparator.new())

	# Botões de Ação
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(actions_hbox)

	var btn_apply := Button.new()
	btn_apply.text = "💾 Salvar Configurações"
	btn_apply.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	btn_apply.pressed.connect(_apply_settings_from_modal)
	actions_hbox.add_child(btn_apply)

	var btn_defaults := Button.new()
	btn_defaults.text = "🔄 Padrões"
	btn_defaults.pressed.connect(_reset_settings_to_defaults)
	actions_hbox.add_child(btn_defaults)

	var btn_close := Button.new()
	btn_close.text = "Fechar"
	btn_close.pressed.connect(func(): _settings_modal.visible = false)
	actions_hbox.add_child(btn_close)


func _open_settings_modal() -> void:
	if not _settings_modal:
		return

	var spots := get_detected_spawn_spots_count()
	if spots > 0:
		_cfg_lbl_spots.text = "🚦 %d vagas físicas detectadas (peças RoadStartPositions no traçado)" % spots
		_cfg_lbl_spots.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	else:
		_cfg_lbl_spots.text = "⚠️ Nenhuma peça 'Grid de Posições' detectada. (Recomendado adicionar para largada realista)"
		_cfg_lbl_spots.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

	_cfg_spin_pop.value = current_track_config.get("population_size", max(1, spots) if spots > 0 else 4)
	_cfg_spin_idle.value = current_track_config.get("max_idle_time", 3.0)
	_cfg_check_idle.button_pressed = current_track_config.get("enable_idle_timeout", true)
	_cfg_spin_mut_rate.value = current_track_config.get("mutation_rate", 0.05)
	_cfg_spin_mut_power.value = current_track_config.get("mutation_power", 0.20)
	_cfg_spin_elite.value = current_track_config.get("elite_count", 1)
	_cfg_spin_speed.value = current_track_config.get("max_speed", 300.0)
	_cfg_spin_accel.value = current_track_config.get("acceleration", 200.0)
	_cfg_spin_brake.value = current_track_config.get("brake_force", 100.0)
	_cfg_spin_steer.value = current_track_config.get("steering_speed", 2.5)

	_settings_modal.visible = true


func _apply_settings_from_modal() -> void:
	current_track_config["population_size"] = int(_cfg_spin_pop.value)
	current_track_config["max_idle_time"] = float(_cfg_spin_idle.value)
	current_track_config["enable_idle_timeout"] = _cfg_check_idle.button_pressed
	current_track_config["mutation_rate"] = float(_cfg_spin_mut_rate.value)
	current_track_config["mutation_power"] = float(_cfg_spin_mut_power.value)
	current_track_config["elite_count"] = int(_cfg_spin_elite.value)
	current_track_config["max_speed"] = float(_cfg_spin_speed.value)
	current_track_config["acceleration"] = float(_cfg_spin_accel.value)
	current_track_config["brake_force"] = float(_cfg_spin_brake.value)
	current_track_config["steering_speed"] = float(_cfg_spin_steer.value)

	_settings_modal.visible = false
	_show_toast("✅ Configurações da pista salvas!")


func _reset_settings_to_defaults() -> void:
	var spots := get_detected_spawn_spots_count()
	_cfg_spin_pop.value = spots if spots > 0 else 4
	_cfg_spin_idle.value = 3.0
	_cfg_check_idle.button_pressed = true
	_cfg_spin_mut_rate.value = 0.05
	_cfg_spin_mut_power.value = 0.20
	_cfg_spin_elite.value = 1
	_cfg_spin_speed.value = 300.0
	_cfg_spin_accel.value = 200.0
	_cfg_spin_brake.value = 100.0
	_cfg_spin_steer.value = 2.5


func _list_available_tracks() -> Array:
	var result: Array = []
	var seen_ids: Dictionary = {}

	# 1. Busca em user://tracks/
	_scan_dir_for_tracks("user://tracks/", result, seen_ids)
	# 2. Busca em res://tracks/
	_scan_dir_for_tracks("res://tracks/", result, seen_ids)

	return result


func _scan_dir_for_tracks(dir_path: String, out_list: Array, seen_ids: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var track_id := filename.get_basename()
			if not seen_ids.has(track_id):
				seen_ids[track_id] = true
				out_list.append({
					"id": track_id,
					"name": track_id.capitalize().replace("_", " "),
					"path": dir_path + filename
				})
		filename = dir.get_next()
	dir.list_dir_end()


func _setup_toast_ui(canvas: CanvasLayer) -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_top = 70
	_toast_panel.offset_bottom = 106

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.8, 1.0, 0.8)
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_panel.add_child(_toast_label)
	canvas.add_child(_toast_panel)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 2.5
	_toast_timer.timeout.connect(func(): _toast_panel.visible = false)
	add_child(_toast_timer)


func _show_toast(text: String, is_error: bool = false) -> void:
	if not _toast_label or not _toast_panel:
		return
	_toast_label.text = text
	var color := Color(1.0, 0.35, 0.35) if is_error else Color(0.4, 1.0, 0.6)
	_toast_label.add_theme_color_override("font_color", color)
	_toast_panel.visible = true
	_toast_timer.start()


func _connect_mouse_filter(control_node: Control) -> void:
	control_node.mouse_entered.connect(func(): _is_mouse_over_ui = true)
	control_node.mouse_exited.connect(func(): _is_mouse_over_ui = false)


# ==============================================================================
# SIDEBAR VERTICAL NA LATERAL ESQUERDA (CATÁLOGO DE PEÇAS COM MINIATURAS)
# ==============================================================================
func _setup_sidebar_ui(canvas: CanvasLayer) -> void:
	_sidebar_panel = PanelContainer.new()
	_sidebar_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_sidebar_panel.offset_left = 10
	_sidebar_panel.offset_top = 58
	_sidebar_panel.offset_right = 236
	_sidebar_panel.offset_bottom = -10

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.25, 0.38, 0.8)
	style.content_margin_left = 8
	style.content_margin_top = 10
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	_sidebar_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(_sidebar_panel)

	_connect_mouse_filter(_sidebar_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	_sidebar_panel.add_child(main_vbox)

	var header_lbl := Label.new()
	header_lbl.text = "📦 PEÇAS DE PISTA"
	header_lbl.add_theme_font_size_override("font_size", 12)
	header_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	main_vbox.add_child(header_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Selecione e posicione na grade:"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	main_vbox.add_child(sub_lbl)

	main_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	_connect_mouse_filter(scroll)

	var pieces_vbox := VBoxContainer.new()
	pieces_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pieces_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(pieces_vbox)

	for piece_id in ORDERED_PIECES:
		var btn := _create_piece_button(piece_id)
		pieces_vbox.add_child(btn)
		_piece_buttons[piece_id] = btn

	_update_selected_piece_ui()


func _create_piece_button(piece_id: String) -> Button:
	var btn := Button.new()
	var piece_name: String = TrackCatalogClass.get_piece_name(piece_id)
	btn.text = " " + piece_name
	btn.tooltip_text = piece_name + " (Clique para selecionar, 'R' no 3D para rotacionar)"
	btn.icon = get_piece_thumbnail(piece_id)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(204, 46)
	btn.add_theme_font_size_override("font_size", 11)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.1, 0.13, 0.19, 0.85)
	normal_sb.set_corner_radius_all(6)
	normal_sb.border_width_left = 1
	normal_sb.border_width_top = 1
	normal_sb.border_width_right = 1
	normal_sb.border_width_bottom = 1
	normal_sb.border_color = Color(0.2, 0.28, 0.4, 0.5)
	normal_sb.content_margin_left = 6
	normal_sb.content_margin_right = 6
	normal_sb.content_margin_top = 4
	normal_sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = Color(0.16, 0.22, 0.32, 0.95)
	hover_sb.border_color = Color(0.0, 0.8, 1.0, 0.7)
	btn.add_theme_stylebox_override("hover", hover_sb)

	btn.pressed.connect(func():
		current_piece_id = piece_id
		_update_ghost_piece()
		_update_selected_piece_ui()
	)

	_connect_mouse_filter(btn)
	return btn


func _update_selected_piece_ui() -> void:
	for piece_id in _piece_buttons:
		var btn: Button = _piece_buttons[piece_id]
		if not is_instance_valid(btn):
			continue

		if piece_id == current_piece_id:
			var active_sb := StyleBoxFlat.new()
			active_sb.bg_color = Color(0.08, 0.28, 0.24, 0.95)
			active_sb.set_corner_radius_all(6)
			active_sb.border_width_left = 3
			active_sb.border_width_top = 1
			active_sb.border_width_right = 1
			active_sb.border_width_bottom = 1
			active_sb.border_color = Color(0.2, 1.0, 0.6, 1.0)
			active_sb.content_margin_left = 6
			active_sb.content_margin_right = 6
			active_sb.content_margin_top = 4
			active_sb.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
		else:
			var normal_sb := StyleBoxFlat.new()
			normal_sb.bg_color = Color(0.1, 0.13, 0.19, 0.85)
			normal_sb.set_corner_radius_all(6)
			normal_sb.border_width_left = 1
			normal_sb.border_width_top = 1
			normal_sb.border_width_right = 1
			normal_sb.border_width_bottom = 1
			normal_sb.border_color = Color(0.2, 0.28, 0.4, 0.5)
			normal_sb.content_margin_left = 6
			normal_sb.content_margin_right = 6
			normal_sb.content_margin_top = 4
			normal_sb.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", normal_sb)
			btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))


func _setup_bottom_hint_ui(canvas: CanvasLayer) -> void:
	var hint_panel := PanelContainer.new()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_panel.offset_left = 246
	hint_panel.offset_top = -42
	hint_panel.offset_right = -10
	hint_panel.offset_bottom = -10

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.set_corner_radius_all(6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.25, 0.38, 0.6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	hint_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(hint_panel)

	_connect_mouse_filter(hint_panel)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	hint_panel.add_child(hbox)

	var hints := [
		"🖱️ [Esq]: Inserir Peça",
		"🖱️ [Dir]: Remover",
		"⌨️ [R]: Girar Peça (90°)",
		"🎥 WASD + Botão Dir: Mover Câmera"
	]
	for h in hints:
		var lbl := Label.new()
		lbl.text = h
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
		hbox.add_child(lbl)


# ==============================================================================
# GERAÇÃO PROCEDURAL DE MINIATURAS (THUMBNAILS) 2D DAS PEÇAS
# ==============================================================================
func get_piece_thumbnail(piece_id: String) -> ImageTexture:
	if _thumbnail_cache.has(piece_id):
		return _thumbnail_cache[piece_id]

	var img := Image.create(38, 38, false, Image.FORMAT_RGBA8)
	var bg_color := Color(0.12, 0.15, 0.13, 1.0)
	img.fill(bg_color)

	var asphalt := Color(0.24, 0.25, 0.27, 1.0)
	var curb := Color(0.8, 0.25, 0.25, 1.0)
	var white_line := Color(0.95, 0.95, 0.95, 1.0)
	var yellow_mark := Color(1.0, 0.82, 0.1, 1.0)
	var cyan_mark := Color(0.0, 0.85, 1.0, 1.0)

	match piece_id:
		"RoadStraight":
			# Pista reta vertical
			_draw_rect(img, 10, 0, 18, 38, asphalt)
			_draw_rect(img, 8, 0, 2, 38, curb)
			_draw_rect(img, 28, 0, 2, 38, curb)
			# Linha tracejada central
			for y in range(2, 38, 7):
				_draw_rect(img, 18, y, 2, 4, white_line)

		"RoadStraightLong":
			# Pista reta longa com linhas duplas
			_draw_rect(img, 8, 0, 22, 38, asphalt)
			_draw_rect(img, 6, 0, 2, 38, curb)
			_draw_rect(img, 30, 0, 2, 38, curb)
			for y in range(1, 38, 6):
				_draw_rect(img, 17, y, 1, 3, white_line)
				_draw_rect(img, 20, y, 1, 3, white_line)

		"RoadCornerSmall":
			# Curva de 90 graus pequena (baixo para a direita)
			for y in range(0, 38):
				for x in range(0, 38):
					var dist := Vector2(38, 38).distance_to(Vector2(x, y))
					if dist >= 16.0 and dist <= 34.0:
						img.set_pixel(x, y, asphalt)
					elif (dist >= 14.0 and dist < 16.0) or (dist > 34.0 and dist <= 36.0):
						img.set_pixel(x, y, curb)
			# Marcação central
			for a_deg in range(100, 180, 15):
				var rad: float = deg_to_rad(float(a_deg))
				var cx := int(round(38.0 + 25.0 * cos(rad)))
				var cy := int(round(38.0 + 25.0 * sin(rad)))
				if cx >= 0 and cx < 38 and cy >= 0 and cy < 38:
					_draw_rect(img, cx - 1, cy - 1, 2, 2, white_line)

		"RoadCornerLarge":
			# Curva de 90 graus média
			for y in range(0, 38):
				for x in range(0, 38):
					var dist := Vector2(38, 38).distance_to(Vector2(x, y))
					if dist >= 12.0 and dist <= 36.0:
						img.set_pixel(x, y, asphalt)
					elif (dist >= 10.0 and dist < 12.0) or (dist > 36.0 and dist <= 38.0):
						img.set_pixel(x, y, curb)
			for a_deg in range(95, 180, 12):
				var rad: float = deg_to_rad(float(a_deg))
				var cx := int(round(38.0 + 24.0 * cos(rad)))
				var cy := int(round(38.0 + 24.0 * sin(rad)))
				if cx >= 0 and cx < 38 and cy >= 0 and cy < 38:
					_draw_rect(img, cx - 1, cy - 1, 2, 2, white_line)

		"RoadCornerLarger":
			# Curva aberta ampla
			for y in range(0, 38):
				for x in range(0, 38):
					var dist := Vector2(42, 42).distance_to(Vector2(x, y))
					if dist >= 14.0 and dist <= 40.0:
						img.set_pixel(x, y, asphalt)
					elif (dist >= 12.0 and dist < 14.0) or (dist > 40.0 and dist <= 42.0):
						img.set_pixel(x, y, curb)
			for a_deg in range(95, 180, 10):
				var rad: float = deg_to_rad(float(a_deg))
				var cx := int(round(42.0 + 27.0 * cos(rad)))
				var cy := int(round(42.0 + 27.0 * sin(rad)))
				if cx >= 0 and cx < 38 and cy >= 0 and cy < 38:
					_draw_rect(img, cx - 1, cy - 1, 2, 2, white_line)

		"RoadStart":
			# Reta com linha de chegada xadrez
			_draw_rect(img, 10, 0, 18, 38, asphalt)
			_draw_rect(img, 8, 0, 2, 38, curb)
			_draw_rect(img, 28, 0, 2, 38, curb)
			# Grid xadrez central de largada
			for r in range(2):
				for c in range(6):
					var col: Color = white_line if (r + c) % 2 == 0 else Color(0.1, 0.1, 0.1)
					_draw_rect(img, 10 + c * 3, 17 + r * 3, 3, 3, col)
			# Seta apontando a direção da largada
			_draw_rect(img, 18, 8, 2, 6, cyan_mark)
			_draw_rect(img, 17, 9, 4, 1, cyan_mark)
			_draw_rect(img, 16, 10, 6, 1, cyan_mark)

		"RoadStartPositions":
			# Reta com 4 vagas físicas marcadas em amarelo
			_draw_rect(img, 9, 0, 20, 38, asphalt)
			_draw_rect(img, 7, 0, 2, 38, curb)
			_draw_rect(img, 29, 0, 2, 38, curb)
			# Vaga 1 (Frente Dir)
			_draw_rect(img, 21, 6, 6, 6, yellow_mark)
			_draw_rect(img, 22, 7, 4, 4, asphalt)
			# Vaga 2 (Frente Esq)
			_draw_rect(img, 11, 13, 6, 6, yellow_mark)
			_draw_rect(img, 12, 14, 4, 4, asphalt)
			# Vaga 3 (Atrás Dir)
			_draw_rect(img, 21, 20, 6, 6, yellow_mark)
			_draw_rect(img, 22, 21, 4, 4, asphalt)
			# Vaga 4 (Atrás Esq)
			_draw_rect(img, 11, 27, 6, 6, yellow_mark)
			_draw_rect(img, 12, 28, 4, 4, asphalt)

		"RoadBump":
			# Reta com faixas diagonais de lombada
			_draw_rect(img, 10, 0, 18, 38, asphalt)
			_draw_rect(img, 8, 0, 2, 38, curb)
			_draw_rect(img, 28, 0, 2, 38, curb)
			_draw_rect(img, 10, 14, 18, 10, Color(0.18, 0.18, 0.2))
			for i in range(4):
				_draw_rect(img, 11 + i * 4, 16, 2, 6, yellow_mark)

		"RoadCrossing":
			# Cruzamento de 4 vias
			_draw_rect(img, 10, 0, 18, 38, asphalt)
			_draw_rect(img, 0, 10, 38, 18, asphalt)
			_draw_rect(img, 8, 0, 2, 10, curb)
			_draw_rect(img, 28, 0, 2, 10, curb)
			_draw_rect(img, 8, 28, 2, 10, curb)
			_draw_rect(img, 28, 28, 2, 10, curb)
			_draw_rect(img, 0, 8, 10, 2, curb)
			_draw_rect(img, 28, 8, 10, 2, curb)
			_draw_rect(img, 0, 28, 10, 2, curb)
			_draw_rect(img, 28, 28, 10, 2, curb)
			# Centro
			_draw_rect(img, 17, 17, 4, 4, yellow_mark)

		_:
			_draw_rect(img, 8, 8, 22, 22, asphalt)

	var tex := ImageTexture.create_from_image(img)
	_thumbnail_cache[piece_id] = tex
	return tex


func _draw_rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(x0, x0 + w):
			if x < 0 or x >= img.get_width():
				continue
			img.set_pixel(x, y, color)
