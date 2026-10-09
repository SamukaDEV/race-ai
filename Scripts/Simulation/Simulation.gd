class_name Simulation
extends Node3D

@export var car_scene: PackedScene
@export var population_size: int = 100
@export var start_position: bool = false
@export var track_path: NodePath = ^"../Track"

signal lap_recorded(car: RaceCar, lap_count: int)
signal simulation_paused_changed(is_paused: bool)

var population: Population
var cars: Array[RaceCar] = []
var current_max_laps: int = 0
var all_time_max_laps: int = 0
var _is_transitioning: bool = false
var is_simulation_paused: bool = false

func _ready() -> void:
	randomize()
	
	if not car_scene:
		print("Car Scene not selected on Simulation Object")
		return
	
	var track_mgr: TrackManager = null
	if has_node(track_path):
		track_mgr = get_node(track_path) as TrackManager

	var track_cfg: Dictionary = {}
	if track_mgr:
		track_cfg = track_mgr.get_track_config()

	if track_cfg.has("population_size") and int(track_cfg["population_size"]) > 0:
		population_size = int(track_cfg["population_size"])

	var active_prof := get_active_car_profile()
	var sensor_cnt: int = int(active_prof.get("sensor_count", 5))
	var expected_inputs: int = sensor_cnt + 2
	var expected_genes: int = NeuralNetwork.get_gene_count_for_inputs(expected_inputs)

	population = Population.new()
	population.population_size = population_size
	population.gene_count = expected_genes

	if track_cfg.has("mutation_rate"):
		population.mutation_rate = float(track_cfg["mutation_rate"])
	if track_cfg.has("mutation_power"):
		population.mutation_power = float(track_cfg["mutation_power"])
	if track_cfg.has("elite_count"):
		population.elite_count = int(track_cfg["elite_count"])

	add_child(population)
	population.create_initial_population()
	start_generation()


## Retorna o perfil de carro ativo (do AppState ou fallback)
func get_active_car_profile() -> Dictionary:
	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state and app_state.has_method("get_current_car_profile"):
		return app_state.get_current_car_profile()
	return CarProfileManager.get_default_profile()


## Alterna o perfil do carro e reinicia a geração atual
func change_car_profile(profile_id: String) -> void:
	var app_state: Node = get_node_or_null("/root/AppState")
	if app_state and app_state.has_method("set_current_car_profile"):
		app_state.set_current_car_profile(profile_id)

	var active_prof := get_active_car_profile()
	var sensor_cnt: int = int(active_prof.get("sensor_count", 5))
	var expected_inputs: int = sensor_cnt + 2
	var expected_genes: int = NeuralNetwork.get_gene_count_for_inputs(expected_inputs)

	if population:
		population.gene_count = expected_genes
		for g in population.genomes:
			if g.genes.size() != expected_genes:
				g.genes.resize(expected_genes)
				g.randomize()

	start_generation()


## Reinicia todo o treinamento do zero: população aleatória, geração 1 e recordes zerados
func restart_training() -> void:
	current_max_laps = 0
	all_time_max_laps = 0
	_is_transitioning = false
	if population:
		population.create_initial_population()
	start_generation()
	print("🔄 Treinamento reiniciado do zero! Geração #1 iniciada.")


func start_generation() -> void:
	current_max_laps = 0
	for car in cars:
		if is_instance_valid(car):
			if car.get_parent() == self:
				remove_child(car)
			car.queue_free()
	
	cars.clear()
	
	var track_mgr: TrackManager = null
	if has_node(track_path):
		track_mgr = get_node(track_path) as TrackManager

	var spawn_points: Array[Transform3D] = []
	var spawn_transform := Transform3D(Basis(), Vector3(0.35, 0.05, 0.25))
	var track_cfg: Dictionary = {}

	if track_mgr:
		track_cfg = track_mgr.get_track_config()
		spawn_points = track_mgr.get_spawn_points()
		spawn_transform = track_mgr.get_spawn_transform()

	var active_prof := get_active_car_profile()

	var car_index: int = 0
	for genome in population.genomes:
		var car: RaceCar = car_scene.instantiate()
		car.name = "car_" + str(car_index)
		add_child(car)
		
		if not spawn_points.is_empty():
			# Posiciona exatamente sobre os Marker3D do nó SpawnPoints
			if car_index < spawn_points.size():
				car.global_position = spawn_points[car_index].origin
				car.global_rotation = spawn_points[car_index].basis.get_euler()
			else:
				# População excedente: recua fileiras atrás das vagas originais respeitando a coluna
				var base_sp: Transform3D = spawn_points[car_index % spawn_points.size()]
				var extra_cycle: int = int(car_index / spawn_points.size())
				var back_offset: Vector3 = -base_sp.basis.z * (extra_cycle * (car.get_car_length() + 0.35))
				car.global_position = base_sp.origin + back_offset
				car.global_rotation = base_sp.basis.get_euler()
		else:
			# Fallback para circuitos sem Marker3D
			var row: int = int(car_index / 2)
			var lateral_side: float = 0.15 if (car_index % 2 == 0) else -0.15
			var longitudinal: float = -row * (car.get_car_length() + 0.35)

			var pos: Vector3 = spawn_transform.origin \
				+ (spawn_transform.basis.x * lateral_side) \
				+ (spawn_transform.basis.z * longitudinal)
			
			car.global_position = pos
			car.global_rotation = spawn_transform.basis.get_euler()

		# Aplica perfil de carro (física e sensores)
		car.apply_profile(active_prof)

		# Aplica configurações específicas da pista (timeouts de inatividade)
		if track_cfg.has("max_idle_time"):
			car.max_idle_time = float(track_cfg["max_idle_time"])
		if track_cfg.has("enable_idle_timeout"):
			car.enable_idle_timeout = bool(track_cfg["enable_idle_timeout"])

		car.random_car_color()
		car.set_car_text("i: " + str(car_index))
		car.setup(genome)
		car.lap_completed.connect(_on_car_lap_completed)
		cars.append(car)
		if is_simulation_paused:
			car.set_physics_process(false)

		car_index += 1

func _on_car_lap_completed(car: RaceCar, lap_count: int) -> void:
	current_max_laps = max(current_max_laps, lap_count)
	all_time_max_laps = max(all_time_max_laps, lap_count)
	emit_signal("lap_recorded", car, lap_count)
	print("🏁 LAP! %s completou a volta %d (Recorde da Sessão: %d)" % [car.name, lap_count, all_time_max_laps])

## Alterna o estado de pausa da simulação
func toggle_pause() -> bool:
	set_simulation_paused(not is_simulation_paused)
	return is_simulation_paused


## Pausa ou retoma o processamento dos carros na pista
func set_simulation_paused(paused: bool) -> void:
	is_simulation_paused = paused
	for car in cars:
		if is_instance_valid(car):
			car.set_physics_process(not paused)
	emit_signal("simulation_paused_changed", is_simulation_paused)
	print("Simulação " + ("PAUSADA ⏸️" if is_simulation_paused else "RETOMADA ▶️"))


func _physics_process(_delta: float) -> void:
	if is_simulation_paused or _is_transitioning or cars.is_empty():
		return
	
	var all_dead := true
	var max_l := 0
	
	for i in range(cars.size()):
		var car: RaceCar = cars[i]
		if not is_instance_valid(car):
			continue
		if car.alive:
			all_dead = false
		
		if car.laps > max_l:
			max_l = car.laps
		
		population.genomes[i].fitness = car.get_fitness()
	
	if max_l > current_max_laps:
		current_max_laps = max_l
		all_time_max_laps = max(all_time_max_laps, max_l)
		
	if all_dead:
		finish_generation()

func finish_generation() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	for car in cars:
		if is_instance_valid(car):
			car.die()
	
	for i in range(cars.size()):
		if is_instance_valid(cars[i]):
			population.genomes[i].fitness = cars[i].get_fitness()
	
	population.sort_by_fitness()
	
	print("Generation: ", population.generation, " | Best fitness: ", population.get_best_genome().fitness)
	
	population.create_next_generation()
	
	await get_tree().create_timer(0.5).timeout
	
	start_generation()
	_is_transitioning = false
