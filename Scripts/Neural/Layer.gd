class_name NeuralLayer
extends RefCounted

var input_size: int
var output_size: int

var weights: Array[PackedFloat32Array] = []
var biases: PackedFloat32Array = PackedFloat32Array()

func _init(p_input_size: int, p_output_size: int):
	input_size = p_input_size
	output_size = p_output_size
	
	biases.resize(output_size)
	
	for i in range(output_size):
		var neuron_weights: PackedFloat32Array = PackedFloat32Array()
		neuron_weights.resize(input_size)
		weights.append(neuron_weights)

func randomize_weights(min_value: float = -1.0, max_value: float = 1.0) -> void:
	for neuron in range(output_size):
		biases[neuron] = randf_range(min_value, max_value)
		
		for input in range(input_size):
			weights[neuron][input] = randf_range(min_value, max_value)

func forward(inputs: PackedFloat32Array) -> PackedFloat32Array:
	assert(inputs.size() == input_size)
	
	var outputs: PackedFloat32Array = PackedFloat32Array()
	outputs.resize(output_size)
	
	for neuron in range(output_size):
		var sum: float = biases[neuron]
		
		for input in range(input_size):
			sum += weights[neuron][input] * inputs[input]
		
		outputs[neuron] = tanh(sum)
	
	return outputs
