class_name Genome
extends RefCounted

const GENE_COUNT: int = 434

var genes: PackedFloat32Array
var fitness: float = 0.0

func _init():
	genes = PackedFloat32Array()
	genes.resize(GENE_COUNT)
	
func randomize() -> void:
	for i in range(GENE_COUNT):
		genes[i] = randf_range(-1.0, 1.0)

func copy() -> Genome:
	var clone: Genome = Genome.new()
	clone.genes = genes.duplicate()
	clone.fitness = fitness
	
	return clone
	
func mutate(rate: float = 0.05, strength: float = 0.2) -> void:
	for i in range(GENE_COUNT):
		if randf() < rate:
			genes[i] += randfn(0.0, strength)

func crossover(other: Genome) -> Genome:
	var child: Genome = Genome.new()
	
	for i in range(GENE_COUNT):
		if randf() < 0.5:
			child.genes[i] = genes[i]
		else:
			child.genes[i] = other.genes[i]
	
	return child

## Serializa o genoma para um dicionário compatível com JSON
func to_dict() -> Dictionary:
	return {
		"fitness": fitness,
		"genes": Array(genes)
	}

## Reconstrói o genoma a partir de um dicionário
static func from_dict(data: Dictionary) -> Genome:
	var genome := Genome.new()
	genome.fitness = float(data.get("fitness", 0.0))
	var raw_genes: Array = data.get("genes", [])
	if raw_genes.size() == GENE_COUNT:
		genome.genes = PackedFloat32Array(raw_genes)
	else:
		genome.randomize()
	return genome
