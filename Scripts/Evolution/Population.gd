class_name Population
extends Node

@export var population_size: int = 6 # on the example the default value was 100
@export var mutation_rate: float = 0.05
@export var mutation_power: float = 0.2
@export var elite_count: int = 1
var gene_count: int = Genome.DEFAULT_GENE_COUNT

var genomes: Array[Genome] = []
var generation: int = 0

func create_initial_population() -> void:
	genomes.clear()
	
	for i in range(population_size):
		var genome: Genome = Genome.new(gene_count)
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
	
	# Mantém os melhores indivíduos intactos (Elitismo)
	var actual_elites: int = clamp(elite_count, 1, survivors_count)
	for e in range(actual_elites):
		next_generation.append(survivors[e].copy())
	
	while next_generation.size() < population_size:
		var parent: Genome = survivors.pick_random()
		var child: Genome = parent.copy()
		child.mutate(mutation_rate, mutation_power)
		next_generation.append(child)
	
	genomes = next_generation
	generation += 1

func get_best_genome() -> Genome:
	sort_by_fitness()
	return genomes[0]

## Serializa a população para salvar em arquivo
func to_dict() -> Dictionary:
	var genomes_data: Array = []
	for g in genomes:
		genomes_data.append(g.to_dict())
	
	return {
		"generation": generation,
		"population_size": population_size,
		"gene_count": gene_count,
		"mutation_rate": mutation_rate,
		"mutation_power": mutation_power,
		"elite_count": elite_count,
		"genomes": genomes_data
	}

## Restaura a população a partir de dados importados
func load_from_dict(data: Dictionary) -> void:
	generation = int(data.get("generation", 0))
	population_size = int(data.get("population_size", population_size))
	if data.has("gene_count"):
		gene_count = int(data["gene_count"])
	mutation_rate = float(data.get("mutation_rate", mutation_rate))
	mutation_power = float(data.get("mutation_power", mutation_power))
	elite_count = int(data.get("elite_count", elite_count))
	genomes.clear()
	
	var raw_genomes: Array = data.get("genomes", [])
	for g_data in raw_genomes:
		if g_data is Dictionary:
			genomes.append(Genome.from_dict(g_data, gene_count))
	
	# Se a lista estiver menor que a população esperada, preenche o restante
	while genomes.size() < population_size:
		var new_g := Genome.new(gene_count)
		new_g.randomize()
		genomes.append(new_g)
