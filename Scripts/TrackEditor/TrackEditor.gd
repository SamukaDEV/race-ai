class_name TrackEditor
extends Node3D

## Editor Interativo de Pistas 3D
## Permite criar, editar, rotacionar e posicionar peças modulares em grade 3D,
## gerando arquivos JSON de pistas compatíveis com o simulador e associadas a saves isolados.

const TrackCatalogClass = preload("res://Scripts/Track/TrackCatalog.gd")

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

# Nós de interface criados dinamicamente
var _line_edit_name: LineEdit
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer
var _load_modal: PanelContainer
var _track_list_container: VBoxContainer


func _ready() -> void:
	_setup_editor_ui()
	_update_ghost_piece()


func _process(_delta: float) -> void:
	_update_mouse_raycast()


func _unhandled_input(event: InputEvent) -> void:
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
		"spawn_point": {
			"position": [spawn_pos.x, spawn_pos.y, spawn_pos.z],
			"rotation_y_deg": spawn_rot
		},
		"pieces": pieces_arr,
		"checkpoints": checkpoints_arr
	}


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
	clear_all_pieces()

	if _line_edit_name:
		_line_edit_name.text = data.get("track_name", "Pista Carregada")

	var pieces: Array = data.get("pieces", [])
	for p_info in pieces:
		var p_id: String = p_info.get("piece_id", "RoadStraight")
		var pos_arr: Array = p_info.get("position", [0.0, 0.0, 0.0])
		var rot: float = float(p_info.get("rotation_y_deg", 0.0))
		place_piece_at(Vector3(pos_arr[0], pos_arr[1], pos_arr[2]), p_id, rot)

	_show_toast("✅ Pista [%s] carregada!" % data.get("track_name", ""))
	return true


## Inicia a simulação imediatamente com a pista desenhada
func test_in_simulation() -> void:
	if placed_pieces.is_empty():
		_show_toast("⚠️ Desenhe uma pista antes de testar!", true)
		return

	var track_data := get_track_data()
	# Salva a pista para que os dados persistam
	save_track()

	if AppState:
		AppState.current_track_id = track_data["track_id"]
		AppState.current_track_name = track_data["track_name"]
		AppState.is_testing_editor_track = true
		AppState.temporary_editor_track_data = track_data

	get_tree().change_scene_to_file("res://Levels/MainScene.tscn")


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://Levels/MainMenu.tscn")


# ==============================================================================
# CONSTRUÇÃO DA INTERFACE DO EDITOR (UI)
# ==============================================================================
func _setup_editor_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# --- BARRA SUPERIOR (AÇÕES & NOME DA PISTA) ---
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 12
	top_panel.offset_top = 12
	top_panel.offset_right = -12
	top_panel.offset_bottom = 60

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	top_style.set_corner_radius_all(8)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_panel.add_theme_stylebox_override("panel", top_style)
	canvas.add_child(top_panel)

	_connect_mouse_filter(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🛠️ EDITOR DE PISTAS"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	top_hbox.add_child(title_lbl)

	top_hbox.add_child(VSeparator.new())

	var lbl_name := Label.new()
	lbl_name.text = "Nome:"
	lbl_name.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(lbl_name)

	_line_edit_name = LineEdit.new()
	_line_edit_name.text = default_track_name
	_line_edit_name.custom_minimum_size = Vector2(180, 28)
	top_hbox.add_child(_line_edit_name)

	var btn_save := Button.new()
	btn_save.text = "💾 Salvar Pista"
	btn_save.pressed.connect(save_track)
	top_hbox.add_child(btn_save)

	var btn_load := Button.new()
	btn_load.text = "📂 Carregar Pista"
	btn_load.pressed.connect(_open_load_modal)
	top_hbox.add_child(btn_load)

	var btn_clear := Button.new()
	btn_clear.text = "🧹 Limpar"
	btn_clear.pressed.connect(clear_all_pieces)
	top_hbox.add_child(btn_clear)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var btn_test := Button.new()
	btn_test.text = "🏎️ Testar Simulação"
	btn_test.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	btn_test.pressed.connect(test_in_simulation)
	top_hbox.add_child(btn_test)

	var btn_menu := Button.new()
	btn_menu.text = "🏠 Menu Principal"
	btn_menu.pressed.connect(go_to_main_menu)
	top_hbox.add_child(btn_menu)

	# --- PALETA INFERIOR (SELEÇÃO DE PEÇAS) ---
	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 12
	bottom_panel.offset_top = -80
	bottom_panel.offset_right = -12
	bottom_panel.offset_bottom = -12

	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	bot_style.set_corner_radius_all(8)
	bot_style.content_margin_left = 12
	bot_style.content_margin_right = 12
	bot_style.content_margin_top = 8
	bot_style.content_margin_bottom = 8
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	canvas.add_child(bottom_panel)

	_connect_mouse_filter(bottom_panel)

	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(bottom_vbox)

	var help_lbl := Label.new()
	help_lbl.text = "🖱️ [Clique Esq] Colocar Peça  |  [Clique Dir] Remover Peça  |  [R] Girar 90°  |  [WASD + Botão Dir] Navegar Câmera"
	help_lbl.add_theme_font_size_override("font_size", 11)
	help_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	bottom_vbox.add_child(help_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 36)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_vbox.add_child(scroll)

	var palette_hbox := HBoxContainer.new()
	palette_hbox.add_theme_constant_override("separation", 6)
	scroll.add_child(palette_hbox)

	for piece_id in TrackCatalogClass.get_all_piece_ids():
		var btn := Button.new()
		btn.text = TrackCatalogClass.get_piece_name(piece_id)
		var target_id: String = piece_id
		btn.pressed.connect(func():
			current_piece_id = target_id
			_update_ghost_piece()
		)
		palette_hbox.add_child(btn)

	# --- MODAL DE CARREGAMENTO ---
	_setup_load_modal(canvas)

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
