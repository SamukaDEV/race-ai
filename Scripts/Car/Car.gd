class_name RaceCar
extends CharacterBody3D

@export var max_speed: float = 300.0
@export var acceleration: float = 200.0
@export var brake_force: float = 100.0
@export var steering_speed: float = 2.5

@export_group("Inatividade / Timeout")
@export var enable_idle_timeout: bool = true
@export var max_idle_time: float = 3.0 ## Tempo máximo (segundos) que o carro pode ficar parado antes de ser eliminado
@export var min_moving_speed: float = 1.0 ## Velocidade mínima para reiniciar o contador de inatividade

@onready var sensors: CarSensors = $Sensors
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

signal lap_completed(car: RaceCar, lap_count: int)

var neural_network: NeuralNetwork
var genome: Genome

var speed_value: float = 0.0
var alive: bool = true
var distance_traveled: float = 0.0
var idle_timer: float = 0.0
var laps: int = 0
var current_checkpoint_index: int = 0
var death_reason: String = ""
var final_fitness: float = 0.0
var car_profile_id: String = "standard"

# Variáveis de Lap Time, Amortecimento e Recompensa
var current_lap_time: float = 0.0
var best_lap_time: float = 9999.0
var steer_smooth: float = 0.0
var oscillation_penalty: float = 0.0
var lap_time_bonus: float = 0.0
var last_lap_distance: float = 0.0
var _lap_cooldown: float = 0.0


## Aplica as configurações do perfil de carro à física e aos sensores
func apply_profile(profile_data: Dictionary) -> void:
	if profile_data.is_empty():
		return

	car_profile_id = profile_data.get("id", "standard")

	if profile_data.has("max_speed"):
		max_speed = float(profile_data["max_speed"])
	if profile_data.has("acceleration"):
		acceleration = float(profile_data["acceleration"])
	if profile_data.has("brake_force"):
		brake_force = float(profile_data["brake_force"])
	if profile_data.has("steering_speed"):
		steering_speed = float(profile_data["steering_speed"])

	# Configura sensores
	if sensors:
		var s_cnt: int = int(profile_data.get("sensor_count", 5))
		var s_rng: float = float(profile_data.get("sensor_range", 1.5))
		var s_spd: float = float(profile_data.get("sensor_spread_angle", 90.0))
		var s_off := Vector3(
			0.0,
			float(profile_data.get("sensor_offset_y", 0.05)),
			float(profile_data.get("sensor_offset_z", 0.15))
		)
		sensors.configure_sensors(s_cnt, s_rng, s_spd, s_off)


func setup(p_genome: Genome) -> void:
	genome = p_genome
	
	var sensor_cnt: int = sensors.sensor_count if sensors else 5
	var total_inputs: int = sensor_cnt + 2
	neural_network = NeuralNetwork.new(total_inputs)
	neural_network.from_genome(genome)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	
	var sensor_values: PackedFloat32Array = sensors.update_sensors()
	
	current_lap_time += delta
	if _lap_cooldown > 0.0:
		_lap_cooldown -= delta
	
	var inputs: PackedFloat32Array = PackedFloat32Array()
	inputs.resize(sensor_values.size() + 2)
	for i in range(sensor_values.size()):
		inputs[i] = sensor_values[i]
	inputs[sensor_values.size()] = speed_value / max_speed
	inputs[sensor_values.size() + 1] = get_direction_input(sensor_values)
	
	var outputs := neural_network.forward(inputs)
	
	# outputs[0] em [-1.0, 1.0]: positivo acelera, negativo freia ativamente
	var gas: float = outputs[0]
	var steer: float = outputs[1]
	
	apply_controls(gas, steer, delta)
	
	move_and_slide()
	
	distance_traveled += abs(speed_value) * delta
	
	# COLLISION DETECTOR
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider.is_in_group("track_obstacle"):
			print("CAR: ", name, " Collided with ", collider)
			die("Crash")
			break

	# TIMEOUT DE INATIVIDADE (Elimina carros parados ou presos)
	if enable_idle_timeout and alive:
		if speed_value < min_moving_speed:
			idle_timer += delta
			if idle_timer >= max_idle_time:
				die("Idle")
				return
		else:
			idle_timer = 0.0
	
func apply_controls(gas: float, steer: float, delta: float) -> void:
	# 1. Aceleração / Freio com Resistência de Rolamento Natural (Drag)
	if gas > 0.05:
		speed_value += gas * acceleration * delta
	elif gas < -0.05:
		# Frenagem ativa comandada pela rede neural
		speed_value -= abs(gas) * brake_force * delta
	else:
		# Arrasto natural / freio-motor suave na ausência de aceleração
		speed_value = move_toward(speed_value, 0.0, 15.0 * delta)
	
	speed_value = clamp(speed_value, 0.0, max_speed)
	
	# 2. Direção com Amortecimento Suave (Damping)
	# Suaviza a transição angular do volante via interpolação, eliminando o efeito ping-pong
	steer_smooth = lerp(steer_smooth, steer, clamp(delta * 12.0, 0.0, 1.0))
	
	var motion_factor: float = clamp(speed_value / 15.0, 0.0, 1.0)
	var speed_ratio: float = speed_value / max_speed if max_speed > 0.0 else 0.0
	
	# Em alta velocidade reduz a sensibilidade para manter estabilidade direcional
	var turn_agility: float = lerp(1.3, 0.6, speed_ratio)
	
	var steering_amount: float = steer_smooth * steering_speed * delta * motion_factor * turn_agility
	rotate_y(steering_amount)
	
	# Penalidade leve cumulativa por oscilar desnecessariamente o volante
	oscillation_penalty += abs(steer) * 0.08 * delta
	
	# 3. Movimento
	var forward: Vector3 = global_transform.basis.z
	
	velocity.x = forward.x * speed_value
	velocity.z = forward.z * speed_value
	
	# Gravidade
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0.0

func get_direction_input(sensor_values: PackedFloat32Array = PackedFloat32Array()) -> float:
	# Balanço lateral relativo aos limites da pista (Centro = 0.0)
	# Substitui a orientação absoluta de bússola por informação direta de centralização
	if sensor_values.size() >= 2:
		var left_dist: float = sensor_values[0]
		var right_dist: float = sensor_values[sensor_values.size() - 1]
		if sensor_values.size() >= 5:
			left_dist = (sensor_values[0] * 0.6) + (sensor_values[1] * 0.4)
			right_dist = (sensor_values[sensor_values.size() - 1] * 0.6) + (sensor_values[sensor_values.size() - 2] * 0.4)
		return clamp(right_dist - left_dist, -1.0, 1.0)
	return 0.0

func die(reason: String = "Dead") -> void:
	if not alive:
		return
	final_fitness = get_fitness()
	alive = false
	death_reason = reason
	velocity = Vector3.ZERO
	set_car_color(Color(0.691, 0.691, 0.691, 1.0))
	set_car_text(reason)
	if sensors:
		sensors.clear_debug() # Limpa as linhas ao morrer

func get_fitness() -> float:
	if not alive and final_fitness > 0.0:
		return final_fitness
	var fit: float = distance_traveled + (laps * 1000.0) + lap_time_bonus - oscillation_penalty
	return max(0.1, fit)

## Chamado diretamente quando o carro atinge o trigger Area3D do portal de início (RoadStart)
func complete_lap() -> void:
	if not alive:
		return
	
	# Cooldown de 1.0s para evitar múltiplos disparos enquanto atravessa o volume do portal
	if _lap_cooldown > 0.0:
		return
	
	_lap_cooldown = 1.0
	laps += 1
	last_lap_distance = distance_traveled
	
	# Bônus inversamente proporcional ao tempo gasto nesta volta
	var bonus: float = max(0.0, 30.0 - current_lap_time) * 40.0
	lap_time_bonus += bonus
	best_lap_time = min(best_lap_time, current_lap_time) if best_lap_time < 9000.0 else current_lap_time
	current_lap_time = 0.0
	
	emit_signal("lap_completed", self, laps)
	update_car_label()


func complete_lap_gate(_min_d: float = 0.0, _min_t: float = 0.0) -> bool:
	complete_lap()
	return true


## Registra a passagem por um checkpoint ou linha de chegada
func register_checkpoint(checkpoint_idx: int, total_checkpoints: int) -> bool:
	if not alive:
		return false
	
	# Se atingir o último checkpoint (FinishLine), contabiliza o LAP diretamente
	if total_checkpoints > 0 and checkpoint_idx == total_checkpoints - 1:
		complete_lap()
		return true

	if checkpoint_idx == current_checkpoint_index:
		current_checkpoint_index += 1
	elif checkpoint_idx > current_checkpoint_index:
		current_checkpoint_index = checkpoint_idx + 1
	return false


func update_car_label() -> void:
	if alive:
		set_car_text("%s | L: %d" % [name, laps])

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
