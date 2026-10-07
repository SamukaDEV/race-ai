class_name Population
extends Node

@export var population_size: int = 6 # on the example the default value was 100

var genomes: Array[Genome] = []
var generation: int = 0

func create_initial_population() -> void:
	genomes.clear()
	
	for i in range(population_size):
		var genome: Genome = Genome.new()
		genome.randomize()
		
		genomes.append(genome)

func sort_by_fitness() -> void:
	genomes.sort_custom(
		func(a: Genome, b: Genome):
			return a.fitness > b.fitness
	)

func create_next_generation() -> void:
	sort_by_fitness()
	
	var survivors_count: int = max(1, population_size / 2)
	var survivors: Array[Genome] = []
	
	for i in range(survivors_count):
		survivors.append(genomes[i])
	
	var next_generation: Array[Genome] = []
	
	# Mantém o melhor indivíduo intacto
	next_generation.append(survivors[0].copy())
	
	while next_generation.size() < population_size:
		var parent: Genome = survivors.pick_random()
		var child: Genome = parent.copy()
		child.mutate(0.05, 0.2)
		next_generation.append(child)
	
	genomes = next_generation
	generation += 1

func get_best_genome() -> Genome:
	sort_by_fitness()
	return genomes[0]
