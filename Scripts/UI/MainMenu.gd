class_name MainMenu
extends Control

## Menu Principal do Race-AI
## Ponto de entrada que permite navegar entre a Simulação com seletor de pista,
## o Editor de Pistas 3D e Configurações futuras.

@onready var main_container: VBoxContainer = $CenterContainer/MainPanel/VBoxContainer
@onready var track_select_modal: Control = $TrackSelectModal
@onready var track_list_vbox: VBoxContainer = $TrackSelectModal/CenterContainer/Panel/VBoxContainer/ScrollContainer/TrackListVBox
@onready var settings_modal: Control = $SettingsModal


func _ready() -> void:
	track_select_modal.visible = false
	settings_modal.visible = false
	_populate_track_list()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if track_select_modal.visible:
			track_select_modal.visible = false
			get_viewport().set_input_as_handled()
		elif settings_modal.visible:
			settings_modal.visible = false
			get_viewport().set_input_as_handled()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		track_select_modal.visible = false
		settings_modal.visible = false


func _on_btn_simulation_pressed() -> void:
	_populate_track_list()
	track_select_modal.visible = true


func _on_btn_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://Levels/TrackEditor.tscn")


func _on_btn_settings_pressed() -> void:
	settings_modal.visible = true


func _on_btn_quit_pressed() -> void:
	get_tree().quit()


func _populate_track_list() -> void:
	for child in track_list_vbox.get_children():
		child.queue_free()

	var tracks := _get_available_tracks()
	if tracks.is_empty():
		var lbl := Label.new()
		lbl.text = "Nenhuma pista encontrada."
		track_list_vbox.add_child(lbl)
		return

	for trk in tracks:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.text = "🏎️ " + trk["name"]
		var track_id: String = trk["id"]
		var track_name: String = trk["name"]

		# Informações de save associadas à pista
		var save_path := "user://saves/%s/quicksave.json" % track_id
		var has_save := FileAccess.file_exists(save_path)
		if has_save:
			btn.text += "  [Save Disponível]"

		btn.pressed.connect(func():
			if AppState:
				AppState.set_current_track(track_id, track_name)
			get_tree().change_scene_to_file("res://Levels/MainScene.tscn")
		)
		track_list_vbox.add_child(btn)


func _get_available_tracks() -> Array:
	var list: Array = []
	var seen: Dictionary = {}

	# Pista padrão nativa garantida
	seen["default_circuit"] = true
	list.append({
		"id": "default_circuit",
		"name": "Circuito Padrão (Oficial)",
		"path": "res://tracks/default_circuit.json"
	})

	_scan_tracks_dir("user://tracks/", list, seen)
	_scan_tracks_dir("res://tracks/", list, seen)

	return list


func _scan_tracks_dir(dir_path: String, out_list: Array, seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var track_id := filename.get_basename()
			if not seen.has(track_id):
				seen[track_id] = true
				out_list.append({
					"id": track_id,
					"name": track_id.capitalize().replace("_", " "),
					"path": dir_path + filename
				})
		filename = dir.get_next()
	dir.list_dir_end()


func _on_close_track_modal_pressed() -> void:
	track_select_modal.visible = false


func _on_close_settings_modal_pressed() -> void:
	settings_modal.visible = false
