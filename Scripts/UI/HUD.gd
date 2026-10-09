class_name RaceHUD
extends CanvasLayer

@export var simulation_path: NodePath = ^"../Simulation"
@export var save_manager_path: NodePath = ^"../SaveManager"

const SaveManagerClass = preload("res://Scripts/Simulation/SaveManager.gd")

var _simulation: Simulation
var _save_manager: SaveManagerClass

# Nós de interface de telemetria
var _header_label: Label
var _opt_car_profile: OptionButton
var _lbl_generation: Label
var _lbl_leader_laps: Label
var _lbl_record_laps: Label
var _lbl_cars_alive: Label
var _lbl_best_fitness: Label
var _cars_container: VBoxContainer
var _champions_modal: Control

# Nós do sistema de Toast (Notificação flutuante)
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer

# Nós de controle de Pausa
var _btn_pause: Button
var _lbl_pause_banner: Label


func _ready() -> void:
	if has_node(simulation_path):
		_simulation = get_node(simulation_path) as Simulation
		_simulation.simulation_paused_changed.connect(_update_pause_ui)
	if has_node(save_manager_path):
		_save_manager = get_node(save_manager_path) as SaveManagerClass
		_save_manager.operation_finished.connect(_on_save_manager_operation_finished)

	_build_ui()
	_setup_toast()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F6:
			_on_load_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P or event.keycode == KEY_SPACE:
			var f := get_viewport().gui_get_focus_owner()
			if not (f and (f is LineEdit or f is TextEdit or f is SpinBox)):
				_on_pause_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			var f := get_viewport().gui_get_focus_owner()
			if not (f and (f is LineEdit or f is TextEdit or f is SpinBox)):
				_on_restart_training_pressed()
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Painel Principal Ancorado no Canto Superior Esquerdo
	var margin := MarginContainer.new()
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_right = 330
	margin.offset_bottom = 520
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	style.set_corner_radius_all(10)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.24, 0.35, 0.8)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(root_vbox)

	# --- CABEÇALHO ---
	var app_state: Node = get_node_or_null("/root/AppState")
	var track_display_name: String = app_state.current_track_name if app_state else "Circuito Padrão"
	var car_prof_name: String = app_state.current_car_profile_name if app_state else "Padrão"
	
	_header_label = Label.new()
	_header_label.text = "🏁 %s\n🏎️ PERFIL: %s" % [track_display_name.to_upper(), car_prof_name.to_upper()]
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	root_vbox.add_child(_header_label)

	_lbl_pause_banner = Label.new()
	_lbl_pause_banner.text = "⏸️ SIMULAÇÃO PAUSADA"
	_lbl_pause_banner.add_theme_font_size_override("font_size", 12)
	_lbl_pause_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_lbl_pause_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_pause_banner.visible = false
	root_vbox.add_child(_lbl_pause_banner)

	var separator1 := HSeparator.new()
	root_vbox.add_child(separator1)

	# --- SELETOR DE PERFIL DE CARRO EM TEMPO REAL ---
	var car_select_box := HBoxContainer.new()
	car_select_box.add_theme_constant_override("separation", 6)
	root_vbox.add_child(car_select_box)

	var lbl_car_prof := Label.new()
	lbl_car_prof.text = "🏎️ Carro:"
	lbl_car_prof.add_theme_font_size_override("font_size", 11)
	lbl_car_prof.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	car_select_box.add_child(lbl_car_prof)

	_opt_car_profile = OptionButton.new()
	_opt_car_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opt_car_profile.add_theme_font_size_override("font_size", 11)
	_populate_car_profiles_dropdown()
	_opt_car_profile.item_selected.connect(_on_car_profile_selected)
	car_select_box.add_child(_opt_car_profile)

	var btn_edit_car := Button.new()
	btn_edit_car.text = "✏️ Editar"
	btn_edit_car.tooltip_text = "Editar configurações ou criar novos perfis de carros"
	btn_edit_car.add_theme_font_size_override("font_size", 11)
	btn_edit_car.pressed.connect(_open_car_profiles_modal)
	car_select_box.add_child(btn_edit_car)

	# --- DESTAQUE DE VOLTAS (LAPS) ---
	var laps_box := HBoxContainer.new()
	laps_box.add_theme_constant_override("separation", 8)
	root_vbox.add_child(laps_box)

	var leader_box := VBoxContainer.new()
	leader_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_lead_title := Label.new()
	lbl_lead_title.text = "VOLTAS DO LÍDER"
	lbl_lead_title.add_theme_font_size_override("font_size", 10)
	lbl_lead_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	leader_box.add_child(lbl_lead_title)

	_lbl_leader_laps = Label.new()
	_lbl_leader_laps.text = "0"
	_lbl_leader_laps.add_theme_font_size_override("font_size", 28)
	_lbl_leader_laps.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	leader_box.add_child(_lbl_leader_laps)
	laps_box.add_child(leader_box)

	var record_box := VBoxContainer.new()
	record_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_rec_title := Label.new()
	lbl_rec_title.text = "RECORDE SESSÃO"
	lbl_rec_title.add_theme_font_size_override("font_size", 10)
	lbl_rec_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	record_box.add_child(lbl_rec_title)

	_lbl_record_laps = Label.new()
	_lbl_record_laps.text = "0"
	_lbl_record_laps.add_theme_font_size_override("font_size", 28)
	_lbl_record_laps.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	record_box.add_child(_lbl_record_laps)
	laps_box.add_child(record_box)

	var separator2 := HSeparator.new()
	root_vbox.add_child(separator2)

	# --- STATUS DA SIMULAÇÃO ---
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 3)
	root_vbox.add_child(stats_grid)

	_add_stat_row(stats_grid, "Geração:", _lbl_generation_ref())
	_add_stat_row(stats_grid, "Carros Vivos:", _lbl_cars_alive_ref())
	_add_stat_row(stats_grid, "Melhor Fitness:", _lbl_best_fitness_ref())

	var separator3 := HSeparator.new()
	root_vbox.add_child(separator3)

	# --- BOTÕES DE AÇÕES E CONTROLE ---
	var actions_box := HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 6)
	root_vbox.add_child(actions_box)

	_btn_pause = Button.new()
	_btn_pause.text = "⏸️ Pausar [P]"
	_btn_pause.tooltip_text = "Pausa ou retoma a simulação (Atalho: P ou Espaço)"
	_btn_pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_pause.pressed.connect(_on_pause_pressed)
	actions_box.add_child(_btn_pause)

	var btn_save := Button.new()
	btn_save.text = "💾 Salvar [F5]"
	btn_save.tooltip_text = "Salva a geração atual, todos os genomas e a posição da câmera"
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.pressed.connect(_on_save_pressed)
	actions_box.add_child(btn_save)

	var btn_load := Button.new()
	btn_load.text = "📂 Carregar [F6]"
	btn_load.tooltip_text = "Carrega a geração e posição da câmera salvas anteriormente"
	btn_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_load.pressed.connect(_on_load_pressed)
	actions_box.add_child(btn_load)

	var actions_row2 := HBoxContainer.new()
	actions_row2.add_theme_constant_override("separation", 6)
	root_vbox.add_child(actions_row2)

	var btn_restart := Button.new()
	btn_restart.text = "🔄 Reiniciar [R]"
	btn_restart.tooltip_text = "Reinicia todo o treinamento do zero com genomas aleatórios (Atalho: R)"
	btn_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_restart.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
	btn_restart.pressed.connect(_on_restart_training_pressed)
	actions_row2.add_child(btn_restart)

	var btn_export_best := Button.new()
	btn_export_best.text = "⭐ Salvar Campeão"
	btn_export_best.tooltip_text = "Salva o genoma do piloto com maior pontuação em arquivo versionado único"
	btn_export_best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_export_best.pressed.connect(_on_export_best_pressed)
	actions_row2.add_child(btn_export_best)

	var btn_view_champs := Button.new()
	btn_view_champs.text = "📜 Campeões"
	btn_view_champs.tooltip_text = "Visualiza o histórico de pilotos campeões salvos nesta pista"
	btn_view_champs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_view_champs.pressed.connect(_open_champions_modal)
	actions_row2.add_child(btn_view_champs)

	var actions_row3 := HBoxContainer.new()
	actions_row3.add_theme_constant_override("separation", 6)
	root_vbox.add_child(actions_row3)

	var btn_menu := Button.new()
	btn_menu.text = "🏠 Menu"
	btn_menu.tooltip_text = "Retorna ao Menu Principal"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://Levels/MainMenu.tscn"))
	actions_row3.add_child(btn_menu)

	var btn_editor := Button.new()
	btn_editor.text = "🛠️ Editor"
	btn_editor.tooltip_text = "Volta a editar a pista no Editor de Pistas 3D"
	btn_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_editor.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	btn_editor.pressed.connect(func(): get_tree().change_scene_to_file("res://Levels/TrackEditor.tscn"))
	actions_row3.add_child(btn_editor)

	var separator4 := HSeparator.new()
	root_vbox.add_child(separator4)

	# --- LISTA DE CARROS (TABELA EM TEMPO REAL) ---
	var lbl_cars_header := Label.new()
	lbl_cars_header.text = "PILOTOS EM PISTA:"
	lbl_cars_header.add_theme_font_size_override("font_size", 11)
	lbl_cars_header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	root_vbox.add_child(lbl_cars_header)

	_cars_container = VBoxContainer.new()
	_cars_container.add_theme_constant_override("separation", 2)
	root_vbox.add_child(_cars_container)

	# --- DICAS DE ATALHOS NO RODAPÉ ---
	var footer := Label.new()
	footer.text = "[F3] Sensores | [WASD+Mouse] Câmera"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	root_vbox.add_child(footer)


func _setup_toast() -> void:
	# Toast Notification Container centralizado no topo da tela
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_top = 24
	_toast_panel.offset_bottom = 60

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
	add_child(_toast_panel)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 2.5
	_toast_timer.timeout.connect(func(): _toast_panel.visible = false)
	add_child(_toast_timer)


func show_toast(text: String, is_error: bool = false) -> void:
	if not _toast_label or not _toast_panel:
		return
	_toast_label.text = text
	var color := Color(1.0, 0.35, 0.35) if is_error else Color(0.4, 1.0, 0.6)
	_toast_label.add_theme_color_override("font_color", color)
	_toast_panel.visible = true
	_toast_timer.start()


func _on_pause_pressed() -> void:
	if _simulation and is_instance_valid(_simulation):
		var is_p := _simulation.toggle_pause()
		_update_pause_ui(is_p)


func _update_pause_ui(is_p: bool) -> void:
	if _btn_pause and is_instance_valid(_btn_pause):
		_btn_pause.text = "▶️ Retomar [P]" if is_p else "⏸️ Pausar [P]"
		_btn_pause.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_p else Color(1.0, 1.0, 1.0))
	if _lbl_pause_banner and is_instance_valid(_lbl_pause_banner):
		_lbl_pause_banner.visible = is_p


func _on_restart_training_pressed() -> void:
	if _simulation and is_instance_valid(_simulation):
		_simulation.restart_training()
		show_toast("🔄 Treinamento reiniciado do zero! (Geração #1)")


func _on_save_pressed() -> void:
	if _save_manager:
		_save_manager.save_simulation()


func _on_load_pressed() -> void:
	if _save_manager:
		_save_manager.load_simulation()


func _on_export_best_pressed() -> void:
	if _save_manager:
		_save_manager.export_best_pilot()


func _on_save_manager_operation_finished(success: bool, message: String) -> void:
	show_toast(message, not success)


func _add_stat_row(parent: GridContainer, label_text: String, label_node: Label) -> void:
	var title := Label.new()
	title.text = label_text
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	parent.add_child(title)
	parent.add_child(label_node)


func _lbl_generation_ref() -> Label:
	_lbl_generation = Label.new()
	_lbl_generation.text = "1"
	_lbl_generation.add_theme_font_size_override("font_size", 12)
	_lbl_generation.add_theme_color_override("font_color", Color(1, 1, 1))
	return _lbl_generation


func _lbl_cars_alive_ref() -> Label:
	_lbl_cars_alive = Label.new()
	_lbl_cars_alive.text = "0 / 0"
	_lbl_cars_alive.add_theme_font_size_override("font_size", 12)
	_lbl_cars_alive.add_theme_color_override("font_color", Color(1, 1, 1))
	return _lbl_cars_alive


func _lbl_best_fitness_ref() -> Label:
	_lbl_best_fitness = Label.new()
	_lbl_best_fitness.text = "0.0"
	_lbl_best_fitness.add_theme_font_size_override("font_size", 12)
	_lbl_best_fitness.add_theme_color_override("font_color", Color(1, 1, 1))
	return _lbl_best_fitness


func _process(_delta: float) -> void:
	if not _simulation or not is_instance_valid(_simulation):
		return

	# Atualiza Geração
	if _simulation.population:
		_lbl_generation.text = "#" + str(_simulation.population.generation)

	# Atualiza Voltas
	_lbl_leader_laps.text = str(_simulation.current_max_laps)
	_lbl_record_laps.text = str(_simulation.all_time_max_laps)

	# Atualiza Carros e Contagens
	var alive_count := 0
	var best_fitness := 0.0
	var sorted_cars := _simulation.cars.duplicate()

	for car in sorted_cars:
		if is_instance_valid(car):
			if car.alive:
				alive_count += 1
			best_fitness = max(best_fitness, car.get_fitness())

	_lbl_cars_alive.text = "%d / %d" % [alive_count, _simulation.cars.size()]
	_lbl_best_fitness.text = "%.1f m" % [best_fitness]

	# Atualiza Leaderboard de pilotos
	_update_cars_list(sorted_cars)


func _update_cars_list(cars_list: Array[RaceCar]) -> void:
	# Ordena por maior pontuação (fitness) obtida
	cars_list.sort_custom(func(a: RaceCar, b: RaceCar):
		if not is_instance_valid(a) or not is_instance_valid(b):
			return false
		var fit_a := a.get_fitness()
		var fit_b := b.get_fitness()
		if not is_equal_approx(fit_a, fit_b):
			return fit_a > fit_b
		return a.laps > b.laps
	)

	# Reutiliza ou ajusta filhos no _cars_container
	while _cars_container.get_child_count() < cars_list.size():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 11)
		_cars_container.add_child(row)

	while _cars_container.get_child_count() > cars_list.size():
		_cars_container.get_child(_cars_container.get_child_count() - 1).queue_free()

	for i in range(cars_list.size()):
		var car := cars_list[i]
		var label := _cars_container.get_child(i) as Label
		if not is_instance_valid(car) or not label:
			continue

		if car.alive:
			label.text = "• %s | L: %d | Fit: %.1fm" % [car.name, car.laps, car.get_fitness()]
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		else:
			var tag := car.death_reason if car.death_reason != "" else "Dead"
			label.text = "✕ %s | L: %d | Fit: %.1fm [%s]" % [car.name, car.laps, car.get_fitness(), tag]
			label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))


func _populate_car_profiles_dropdown() -> void:
	if not _opt_car_profile:
		return
	_opt_car_profile.clear()

	var app_state: Node = get_node_or_null("/root/AppState")
	var active_id: String = app_state.current_car_profile_id if app_state else "standard"
	var profiles := CarProfileManager.list_profiles()

	var selected_idx := 0
	for i in range(profiles.size()):
		var prof: Dictionary = profiles[i]
		var p_id: String = prof["id"]
		var p_name: String = prof["name"]
		_opt_car_profile.add_item(p_name, i)
		_opt_car_profile.set_item_metadata(i, p_id)
		if p_id == active_id:
			selected_idx = i

	_opt_car_profile.select(selected_idx)


func _on_car_profile_selected(index: int) -> void:
	var prof_id: String = _opt_car_profile.get_item_metadata(index)
	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state and app_state.current_car_profile_id == prof_id:
		return

	if _simulation and is_instance_valid(_simulation):
		_simulation.change_car_profile(prof_id)

	_update_header_text()
	var prof_data := CarProfileManager.get_profile(prof_id)
	show_toast("🏎️ Carro alterado para [%s]! Reiniciando geração..." % prof_data.get("name", prof_id))


func _update_header_text() -> void:
	if not _header_label:
		return
	var app_state: Node = get_node_or_null("/root/AppState")
	var track_display_name: String = app_state.current_track_name if app_state else "Circuito Padrão"
	var car_prof_name: String = app_state.current_car_profile_name if app_state else "Padrão"
	_header_label.text = "🏁 %s\n🏎️ PERFIL: %s" % [track_display_name.to_upper(), car_prof_name.to_upper()]


## Abre o editor/gerenciador de perfis de carros diretamente da simulação
func _open_car_profiles_modal() -> void:
	var was_paused := false
	if _simulation and is_instance_valid(_simulation):
		was_paused = _simulation.is_simulation_paused
		if not was_paused:
			_simulation.set_simulation_paused(true)
			_update_pause_ui(true)

	var app_state: Node = get_node_or_null("/root/AppState")
	var curr_prof: String = app_state.current_car_profile_id if app_state else "standard"
	if _opt_car_profile and _opt_car_profile.selected >= 0:
		curr_prof = _opt_car_profile.get_item_metadata(_opt_car_profile.selected)

	var modal := CarProfileModal.open_modal(self, func(saved_id: String):
		_populate_car_profiles_dropdown()
		if _simulation and is_instance_valid(_simulation):
			_simulation.change_car_profile(saved_id)
		_update_header_text()
		var prof_data := CarProfileManager.get_profile(saved_id)
		show_toast("🏎️ Perfil [%s] aplicado! Reiniciando geração..." % prof_data.get("name", saved_id))
	, curr_prof)

	modal.closed.connect(func():
		_populate_car_profiles_dropdown()
		_update_header_text()
		if not was_paused and _simulation and is_instance_valid(_simulation):
			_simulation.set_simulation_paused(false)
			_update_pause_ui(false)
	)


## Abre modal interativo listando o histórico de pilotos campeões salvos
func _open_champions_modal() -> void:
	if _champions_modal and is_instance_valid(_champions_modal):
		_champions_modal.queue_free()

	_champions_modal = Control.new()
	_champions_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_champions_modal)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.02, 0.03, 0.06, 0.75)
	_champions_modal.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_champions_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 380)
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
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "📜 HISTÓRICO DE CAMPEÕES EXPORTADOS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var btn_folder := Button.new()
	btn_folder.text = "📂 Pasta Externa"
	btn_folder.tooltip_text = "Abre a pasta de arquivos JSON de campeões no gerenciador de arquivos do computador (Finder / Explorer)"
	btn_folder.add_theme_font_size_override("font_size", 11)
	btn_folder.pressed.connect(func():
		if _save_manager:
			_save_manager.open_champions_folder()
	)
	header_hbox.add_child(btn_folder)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.flat = true
	btn_close.pressed.connect(func(): _champions_modal.queue_free())
	header_hbox.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	var champions := _save_manager.list_exported_champions() if _save_manager else []
	if champions.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum campeão salvo ainda nesta pista.\nClique em '⭐ Salvar Campeão' para exportar."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_vbox.add_child(empty_lbl)
	else:
		for champ in champions:
			var item_panel := PanelContainer.new()
			var item_style := StyleBoxFlat.new()
			item_style.bg_color = Color(0.12, 0.15, 0.22, 0.8)
			item_style.set_corner_radius_all(6)
			item_style.content_margin_left = 10
			item_style.content_margin_top = 8
			item_style.content_margin_right = 10
			item_style.content_margin_bottom = 8
			item_panel.add_theme_stylebox_override("panel", item_style)
			list_vbox.add_child(item_panel)

			var item_hbox := HBoxContainer.new()
			item_panel.add_child(item_hbox)

			var info_lbl := Label.new()
			var gen_txt: int = champ.get("generation", 0)
			var fit_txt: float = champ.get("fitness", 0.0)
			var car_id: String = champ.get("car_profile_id", "standard")
			var track_orig: String = champ.get("track_id", "Geral")
			var tag_global: String = " 🌐 [Global]" if champ.get("is_global", false) else ""
			info_lbl.text = "🏆 Gen #%d • Fit: %.1fm • Carro: %s%s\n🏁 Pista: %s | 📅 %s" % [gen_txt, fit_txt, car_id, tag_global, track_orig, champ.get("timestamp", "")]
			info_lbl.add_theme_font_size_override("font_size", 11)
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_hbox.add_child(info_lbl)

			var btn_import := Button.new()
			btn_import.text = "Usar como Semente"
			btn_import.add_theme_font_size_override("font_size", 11)
			var c_path: String = champ.get("path", "")
			btn_import.pressed.connect(func():
				if _save_manager:
					_save_manager.import_best_pilot(c_path)
					_champions_modal.queue_free()
			)
			item_hbox.add_child(btn_import)
