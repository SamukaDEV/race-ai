class_name Simulation
extends Node3D

@export var car_scene: PackedScene
@export var population_size: int = 100
@export var start_position: bool = false
@export var track_path: NodePath = ^"../Track"

signal lap_recorded(car: RaceCar, lap_count: int)

var population: Population
var cars: Array[RaceCar] = []
var current_max_laps: int = 0
var all_time_max_laps: int = 0
var _is_transitioning: bool = false

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

	population = Population.new()
	population.population_size = population_size
	if track_cfg.has("mutation_rate"):
		population.mutation_rate = float(track_cfg["mutation_rate"])
	if track_cfg.has("mutation_power"):
		population.mutation_power = float(track_cfg["mutation_power"])
	if track_cfg.has("elite_count"):
		population.elite_count = int(track_cfg["elite_count"])

	add_child(population)
	population.create_initial_population()
	start_generation()

func start_generation() -> void:
	current_max_laps = 0
	for car in cars:
		if is_instance_valid(car):
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

		# Aplica configurações específicas do carro
		if track_cfg.has("max_speed"):
			car.max_speed = float(track_cfg["max_speed"])
		if track_cfg.has("acceleration"):
			car.acceleration = float(track_cfg["acceleration"])
		if track_cfg.has("brake_force"):
			car.brake_force = float(track_cfg["brake_force"])
		if track_cfg.has("steering_speed"):
			car.steering_speed = float(track_cfg["steering_speed"])
		if track_cfg.has("max_idle_time"):
			car.max_idle_time = float(track_cfg["max_idle_time"])
		if track_cfg.has("enable_idle_timeout"):
			car.enable_idle_timeout = bool(track_cfg["enable_idle_timeout"])

		car.random_car_color()
		car.set_car_text("i: " + str(car_index))
		car.setup(genome)
		car.lap_completed.connect(_on_car_lap_completed)
		cars.append(car)
		
		car_index += 1

func _on_car_lap_completed(car: RaceCar, lap_count: int) -> void:
	current_max_laps = max(current_max_laps, lap_count)
	all_time_max_laps = max(all_time_max_laps, lap_count)
	emit_signal("lap_recorded", car, lap_count)
	print("🏁 LAP! %s completou a volta %d (Recorde da Sessão: %d)" % [car.name, lap_count, all_time_max_laps])

func _physics_process(_delta: float) -> void:
	if _is_transitioning or cars.is_empty():
		return
	
	var all_dead := true
	
	for i in range(cars.size()):
		var car: RaceCar = cars[i]
		if not is_instance_valid(car):
			continue
		if car.alive:
			all_dead = false
		
		population.genomes[i].fitness = car.get_fitness()
		
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
