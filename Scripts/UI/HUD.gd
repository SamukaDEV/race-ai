class_name RaceHUD
extends CanvasLayer

@export var simulation_path: NodePath = "../Simulation"

var _simulation: Simulation

# Nós de interface
var _lbl_generation: Label
var _lbl_leader_laps: Label
var _lbl_record_laps: Label
var _lbl_cars_alive: Label
var _lbl_best_fitness: Label
var _cars_container: VBoxContainer

func _ready() -> void:
	if has_node(simulation_path):
		_simulation = get_node(simulation_path) as Simulation
	
	_build_ui()

func _build_ui() -> void:
	# Painel Principal Ancorado no Canto Superior Esquerdo
	var margin := MarginContainer.new()
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_right = 320
	margin.offset_bottom = 440
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
	root_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(root_vbox)

	# --- CABEÇALHO ---
	var header := Label.new()
	header.text = "🏁 RACE-AI TELEMETRY"
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	root_vbox.add_child(header)

	var separator1 := HSeparator.new()
	root_vbox.add_child(separator1)

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
	stats_grid.add_theme_constant_override("v_separation", 4)
	root_vbox.add_child(stats_grid)

	_add_stat_row(stats_grid, "Geração:", _lbl_generation_ref())
	_add_stat_row(stats_grid, "Carros Vivos:", _lbl_cars_alive_ref())
	_add_stat_row(stats_grid, "Melhor Fitness:", _lbl_best_fitness_ref())

	var separator3 := HSeparator.new()
	root_vbox.add_child(separator3)

	# --- LISTA DE CARROS (TABELA EM TEMPO REAL) ---
	var lbl_cars_header := Label.new()
	lbl_cars_header.text = "PILOTOS EM PISTA:"
	lbl_cars_header.add_theme_font_size_override("font_size", 11)
	lbl_cars_header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	root_vbox.add_child(lbl_cars_header)

	_cars_container = VBoxContainer.new()
	_cars_container.add_theme_constant_override("separation", 3)
	root_vbox.add_child(_cars_container)

	# --- DICAS DE ATALHOS NO RODAPÉ ---
	var footer := Label.new()
	footer.text = "[F3] Sensores | [WASD+Mouse] Câmera"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	root_vbox.add_child(footer)

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
	# Ordena por voltas e distância percorrida decrescente
	cars_list.sort_custom(func(a: RaceCar, b: RaceCar):
		if not is_instance_valid(a) or not is_instance_valid(b):
			return false
		if a.laps != b.laps:
			return a.laps > b.laps
		return a.distance_traveled > b.distance_traveled
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
			label.text = "• %s | L: %d | %.0fm" % [car.name, car.laps, car.distance_traveled]
			label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		else:
			var tag := car.death_reason if car.death_reason != "" else "Dead"
			label.text = "✕ %s | L: %d | %s" % [car.name, car.laps, tag]
			label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
