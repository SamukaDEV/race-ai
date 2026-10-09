class_name Genome
extends RefCounted

## Representação Genética (Genoma) para Redes Neurais Dinâmicas
## Suporta dinamicamente qualquer quantidade de genes de acordo com os inputs/sensores.

const DEFAULT_GENE_COUNT: int = 434 ## Padrão para 7 inputs (5 sensores + 2 variáveis)

var genes: PackedFloat32Array
var fitness: float = 0.0

func _init(p_gene_count: int = DEFAULT_GENE_COUNT):
	genes = PackedFloat32Array()
	genes.resize(max(1, p_gene_count))


func get_gene_count() -> int:
	return genes.size()


func randomize() -> void:
	for i in range(genes.size()):
		genes[i] = randf_range(-1.0, 1.0)


func copy() -> Genome:
	var clone: Genome = Genome.new(genes.size())
	clone.genes = genes.duplicate()
	clone.fitness = fitness
	return clone


func mutate(rate: float = 0.05, strength: float = 0.2) -> void:
	for i in range(genes.size()):
		if randf() < rate:
			genes[i] += randfn(0.0, strength)


func crossover(other: Genome) -> Genome:
	var count: int = mini(genes.size(), other.genes.size())
	var child: Genome = Genome.new(count)
	for i in range(count):
		if randf() < 0.5:
			child.genes[i] = genes[i]
		else:
			child.genes[i] = other.genes[i]
	return child


## Serializa o genoma para um dicionário compatível com JSON
func to_dict() -> Dictionary:
	return {
		"fitness": fitness,
		"gene_count": genes.size(),
		"genes": Array(genes)
	}


## Reconstrói o genoma a partir de um dicionário
static func from_dict(data: Dictionary, expected_count: int = 0) -> Genome:
	var raw_genes: Array = data.get("genes", [])
	var target_count := expected_count
	if target_count <= 0:
		target_count = int(data.get("gene_count", raw_genes.size()))
	if target_count <= 0:
		target_count = DEFAULT_GENE_COUNT

	var genome := Genome.new(target_count)
	genome.fitness = float(data.get("fitness", 0.0))

	if raw_genes.size() == target_count:
		genome.genes = PackedFloat32Array(raw_genes)
	else:
		genome.randomize()

	return genome
