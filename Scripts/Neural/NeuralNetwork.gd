class_name NeuralNetwork
extends RefCounted

## Rede Neural Artificial Feed-Forward Multicamadas (Perceptron Multicamadas)
## Permite número dinâmico de entradas para acomodar perfis de carro com diferentes sensores.

var inputs_count: int = 7
const HIDDEN_1: int = 16
const HIDDEN_2: int = 16
const OUTPUTS: int = 2

var layer1: NeuralLayer
var layer2: NeuralLayer
var layer3: NeuralLayer


func _init(p_inputs: int = 7) -> void:
	inputs_count = max(1, p_inputs)
	layer1 = NeuralLayer.new(inputs_count, HIDDEN_1)
	layer2 = NeuralLayer.new(HIDDEN_1, HIDDEN_2)
	layer3 = NeuralLayer.new(HIDDEN_2, OUTPUTS)


static func get_gene_count_for_inputs(p_inputs: int) -> int:
	var l1 := (p_inputs * HIDDEN_1) + HIDDEN_1
	var l2 := (HIDDEN_1 * HIDDEN_2) + HIDDEN_2
	var l3 := (HIDDEN_2 * OUTPUTS) + OUTPUTS
	return l1 + l2 + l3


func randomize() -> void:
	layer1.randomize_weights()
	layer2.randomize_weights()
	layer3.randomize_weights()


func forward(inputs: PackedFloat32Array) -> PackedFloat32Array:
	assert(inputs.size() == inputs_count)
	
	var hidden1: PackedFloat32Array = layer1.forward(inputs)
	var hidden2: PackedFloat32Array = layer2.forward(hidden1)
	var output: PackedFloat32Array = layer3.forward(hidden2)
	
	return output


func from_genome(genome: Genome) -> void:
	var expected_genes := get_gene_count_for_inputs(inputs_count)
	if genome.genes.size() != expected_genes:
		genome.genes.resize(expected_genes)
		genome.randomize()

	var index: int = 0
	
	# Layer 1
	for neuron in range(HIDDEN_1):
		for input in range(inputs_count):
			layer1.weights[neuron][input] = genome.genes[index]
			index += 1
	
	for neuron in range(HIDDEN_1):
		layer1.biases[neuron] = genome.genes[index]
		index += 1
	
	# Layer 2
	for neuron in range(HIDDEN_2):
		for input in range(HIDDEN_1):
			layer2.weights[neuron][input] = genome.genes[index]
			index += 1
	
	for neuron in range(HIDDEN_2):
		layer2.biases[neuron] = genome.genes[index]
		index += 1
	
	# Layer 3
	for neuron in range(OUTPUTS):
		for input in range(HIDDEN_2):
			layer3.weights[neuron][input] = genome.genes[index]
			index += 1
	
	for neuron in range(OUTPUTS):
		layer3.biases[neuron] = genome.genes[index]
		index += 1
		
	assert(index == expected_genes)


func to_genome() -> Genome:
	var expected_genes := get_gene_count_for_inputs(inputs_count)
	var genome := Genome.new(expected_genes)
	var index := 0

	# Layer 1
	for neuron in range(HIDDEN_1):
		for input in range(inputs_count):
			genome.genes[index] = layer1.weights[neuron][input]
			index += 1

	for neuron in range(HIDDEN_1):
		genome.genes[index] = layer1.biases[neuron]
		index += 1

	# Layer 2
	for neuron in range(HIDDEN_2):
		for input in range(HIDDEN_1):
			genome.genes[index] = layer2.weights[neuron][input]
			index += 1

	for neuron in range(HIDDEN_2):
		genome.genes[index] = layer2.biases[neuron]
		index += 1

	# Layer 3
	for neuron in range(OUTPUTS):
		for input in range(HIDDEN_2):
			genome.genes[index] = layer3.weights[neuron][input]
			index += 1

	for neuron in range(OUTPUTS):
		genome.genes[index] = layer3.biases[neuron]
		index += 1

	assert(index == expected_genes)

	return genome
