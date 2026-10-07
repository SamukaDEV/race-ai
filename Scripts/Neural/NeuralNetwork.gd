class_name NeuralNetwork
extends RefCounted

const INPUTS: int = 7
const HIDDEN_1: int = 16
const HIDDEN_2: int = 16
const OUTPUTS: int = 2

var layer1: NeuralLayer
var layer2: NeuralLayer
var layer3: NeuralLayer

func _init() -> void:
	layer1 = NeuralLayer.new(INPUTS, HIDDEN_1)
	layer2 = NeuralLayer.new(HIDDEN_1, HIDDEN_2)
	layer3 = NeuralLayer.new(HIDDEN_2, OUTPUTS)

func randomize() -> void:
	layer1.randomize_weights()
	layer2.randomize_weights()
	layer3.randomize_weights()

func forward(inputs: PackedFloat32Array) -> PackedFloat32Array:
	assert(inputs.size() == INPUTS)
	
	var hidden1: PackedFloat32Array = layer1.forward(inputs)
	var hidden2: PackedFloat32Array = layer2.forward(hidden1)
	var output: PackedFloat32Array = layer3.forward(hidden2)
	
	return output

func from_genome(genome: Genome) -> void:
	var index: int = 0
	
	# Layer 1
	for neuron in range(HIDDEN_1):
		for input in range(INPUTS):
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
		
	assert(index == Genome.GENE_COUNT)

func to_genome() -> Genome:
	var genome := Genome.new()
	var index := 0

	# Layer 1
	for neuron in range(HIDDEN_1):
		for input in range(INPUTS):
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

	assert(index == Genome.GENE_COUNT)

	return genome
