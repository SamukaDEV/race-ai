class_name RaceCar
extends CharacterBody3D

@export var max_speed: float = 300.0
@export var acceleration: float = 200.0
@export var brake_force: float = 300.0
@export var steering_speed: float = 2.5

@onready var sensors: CarSensors = $Sensors
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var neural_network: NeuralNetwork
var genome: Genome

var speed_value: float = 0.0
var alive: bool = true
var distance_traveled: float = 0.0

func setup(p_genome: Genome) -> void:
	genome = p_genome
	
	neural_network = NeuralNetwork.new()
	neural_network.from_genome(genome)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	var sensor_values: PackedFloat32Array = sensors.update_sensors()
	
	var inputs: PackedFloat32Array = PackedFloat32Array([
		sensor_values[0],
		sensor_values[1],
		sensor_values[2],
		sensor_values[3],
		sensor_values[4],
		speed_value / max_speed,
		get_direction_input()
	])
	
	var outputs := neural_network.forward(inputs)
	
	var gas := outputs[0]
	var steer := outputs[1]
	
	apply_controls(gas, steer, delta)
	
	move_and_slide()
	
	distance_traveled += abs(speed_value) * delta
	
	# COLLISION DETECTOR
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider.is_in_group("track_obstacle"):
			print("CAR: ", name, " Collided with ", collider)
			die()
			break
	
func apply_controls(gas: float, steer: float, delta: float) -> void:
	# Aceleração / freio
	
	if gas > 0.0:
		speed_value += gas * acceleration * delta
	else:
		speed_value += gas * brake_force * delta
	
	speed_value = clamp(speed_value, 0.0, max_speed)
	
	# Direção
	
	var steering_amount: float = steer * steering_speed * delta * (speed_value / max_speed)
	rotate_y(steering_amount)
	
	# Movimento
	
	var forward: Vector3 = global_transform.basis.z
	
	velocity.x = forward.x * speed_value
	velocity.z = forward.z * speed_value
	
	# Gravidade
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0.0

func get_direction_input() -> float:
	# Temporariamente usamos a rotação do carro.
	# Posteriormente vamos substituir pelo erro relativo à direção da pista.
	
	return sin(rotation.y)

func die() -> void:
	alive = false
	velocity = Vector3.ZERO
	set_car_color(Color(0.691, 0.691, 0.691, 1.0))
	set_car_text("Dead")
	if sensors:
		sensors.clear_debug() # Limpa as linhas ao morrer

func get_fitness() -> float:
	return distance_traveled

func _on_body_entered(_body: Node3D) -> void:
	die()

func get_shape() -> BoxShape3D:
	var shape: BoxShape3D = collision_shape.shape
	return shape

## Comprimento do carro.
func get_car_length() -> float:
	var shape: BoxShape3D = get_shape()
	if shape == null:
		return 0.0
	return shape.size.z
	
## Largura do carro.
func get_car_width() -> float:
	var shape: BoxShape3D = get_shape()
	if shape == null:
		return 0.0
	return shape.size.x

## Altura do carro.
func get_car_height() -> float:
	var shape: BoxShape3D = get_shape()
	if shape == null:
		return 0.0
	return shape.size.y

func set_car_color(nova_cor: Color) -> void:
	var node: MeshInstance3D = get_node_or_null("VFX/body")
	if node == null:
		return
	var material: StandardMaterial3D = node.get_active_material(1).duplicate()
	if material:
		material.albedo_color = nova_cor
		node.set_surface_override_material(1, material)

func random_car_color() -> void:
	set_car_color(get_absolute_random_color())

## Gera uma cor completamente aleatória no espectro RGB.
##
## Sorteia valores independentes para os canais Vermelho, Verde e Azul.
## Oferece o máximo de possibilidades, incluindo tons escuros, claros, pastéis e cinzentos.
## @return Retorna um novo objeto [code]Color[/code] gerado aleatoriamente.
func get_absolute_random_color() -> Color:
	var r: float = randf() # Sorteia Vermelho entre 0.0 e 1.0
	var g: float = randf() # Sorteia Verde entre 0.0 e 1.0
	var b: float = randf() # Sorteia Azul entre 0.0 e 1.0
	
	return Color(r, g, b)

## Gera uma cor aleatória vibrante utilizando o espaço de cores HSV.
##
## Garante que a cor seja sempre brilhante e saturada, ideal para elementos visuais de jogos.
## @return Retorna um novo objeto [code]Color[/code] com uma cor aleatória.
func get_random_color() -> Color:
	# Sorteia um ângulo entre 0.0 e 1.0 para a matiz (cobre todo o arco-íris)
	var matiz: float = randf()
	
	# Fixamos a saturação e o brilho altos (entre 0.8 e 1.0) para a cor não ficar cinza ou preta
	var saturacao: float = randf_range(0.8, 1.0)
	var brilho: float = randf_range(0.8, 1.0)
	
	return Color.from_hsv(matiz, saturacao, brilho)

func set_car_text(text: String) -> void:
	var text_node: Label3D = get_node("VFX/Label3D")
	text_node.text = text
