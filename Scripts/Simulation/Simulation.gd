class_name Simulation
extends Node3D

@export var car_scene: PackedScene
@export var population_size: int = 6

var population: Population
var cars: Array[RaceCar] = []

func _ready() -> void:
	randomize()
	
	if not car_scene:
		print("Car Scene not selected on Simulation Object")
		return
	
	population = Population.new()
	population.population_size = population_size
	
	add_child(population)
	
	population.create_initial_population()
	
	start_generation()

func start_generation() -> void:
	for car in cars:
		if is_instance_valid(car):
			car.queue_free()
	
	cars.clear()
	
	var car_index: int = 0
	for genome in population.genomes:
		var car: RaceCar = car_scene.instantiate()
		
		car.name = "car_" + str(car_index)
		add_child(car)
		
		car.global_position = Vector3(0.35, 0.3, 0.25)
		car.rotation = Vector3.ZERO
		
		# Posicionar o carro no lugar correto
		
		var d: float = (car_index * (car.get_car_length() + 0.3))
		car.global_position.z = d
		car.random_car_color()
		car.set_car_text("i: " + str(car_index))
		if car_index % 2 == 0:
			car.global_position.x += 0.3
		
		car.setup(genome)
		cars.append(car)
		
		car_index += 1

func _physics_process(_delta: float) -> void:
	if cars.is_empty():
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
