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


var _opt_main_car_profile: OptionButton


func _on_btn_settings_pressed() -> void:
	CarProfileModal.open_modal(self, func(_saved_id): _populate_car_profiles_in_selector())


func _on_btn_quit_pressed() -> void:
	get_tree().quit()


func _ensure_car_profile_selector() -> void:
	if _opt_main_car_profile and is_instance_valid(_opt_main_car_profile):
		_populate_car_profiles_in_selector()
		return

	var modal_vbox: VBoxContainer = $TrackSelectModal/CenterContainer/Panel/VBoxContainer
	var scroll_container := modal_vbox.get_node_or_null("ScrollContainer")
	if not scroll_container:
		return

	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 8)
	modal_vbox.add_child(selector_row)
	modal_vbox.move_child(selector_row, scroll_container.get_index())

	var lbl := Label.new()
	lbl.text = "🏎️ Carro / Perfil:"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.7))
	selector_row.add_child(lbl)

	_opt_main_car_profile = OptionButton.new()
	_opt_main_car_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_main_car_profile.add_theme_font_size_override("font_size", 12)
	selector_row.add_child(_opt_main_car_profile)

	var btn_edit_prof := Button.new()
	btn_edit_prof.text = "✏️ Editar"
	btn_edit_prof.add_theme_font_size_override("font_size", 11)
	btn_edit_prof.pressed.connect(func():
		CarProfileModal.open_modal(self, func(_id): _populate_car_profiles_in_selector())
	)
	selector_row.add_child(btn_edit_prof)

	_populate_car_profiles_in_selector()


func _populate_car_profiles_in_selector() -> void:
	if not _opt_main_car_profile:
		return
	_opt_main_car_profile.clear()
	var profiles := CarProfileManager.list_profiles()
	var active_id: String = AppState.current_car_profile_id if AppState else "standard"
	var sel_idx := 0

	for i in range(profiles.size()):
		var p: Dictionary = profiles[i]
		_opt_main_car_profile.add_item(p["name"], i)
		_opt_main_car_profile.set_item_metadata(i, p["id"])
		if p["id"] == active_id:
			sel_idx = i

	_opt_main_car_profile.select(sel_idx)


func _populate_track_list() -> void:
	_ensure_car_profile_selector()

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
		btn.text = "🏁 " + trk["name"]
		var track_id: String = trk["id"]
		var track_name: String = trk["name"]

		# Informações de save associadas à pista
		var save_path := "user://saves/%s/quicksave.json" % track_id
		var has_save := FileAccess.file_exists(save_path)
		if has_save:
			btn.text += "  [Save Disponível]"

		btn.pressed.connect(func():
			if _opt_main_car_profile:
				var chosen_idx := _opt_main_car_profile.selected
				var chosen_prof_id: String = _opt_main_car_profile.get_item_metadata(chosen_idx)
				if AppState:
					AppState.set_current_car_profile(chosen_prof_id)

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
