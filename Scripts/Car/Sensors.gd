class_name CarSensors
extends Node3D

## Flag individual configurável no Inspector
@export var debug: bool = true

## Flag global: ao pressionar a tecla F3, liga/desliga para todos os carros em tempo real
static var global_debug: bool = true

#@export var sensor_offset := Vector3(0.0, 0.3, -1.5)
#@export var sensor_offset := Vector3(0.0, 0.05, -0.13)
@export var sensor_offset := Vector3(0.0, 0.05, 0.15)

const SENSOR_COUNT: int = 5
#const MAX_DISTANCE: float = 0.2
const MAX_DISTANCE: float = .25

var sensor_angles: Array = [
	deg_to_rad(-45.0),
	deg_to_rad(-22.5),
	0.0,
	deg_to_rad(22.5),
	deg_to_rad(45.0)
]

var distances: PackedFloat32Array

# Estrutura para armazenar os raios do frame atual
var _debug_rays: Array = []

# Nós para renderização das linhas 3D
var _debug_mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _debug_material: StandardMaterial3D

func _ready() -> void:
	distances.resize(SENSOR_COUNT)
	_setup_debug_mesh()

func _setup_debug_mesh() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_debug_mesh_instance = MeshInstance3D.new()
	_debug_mesh_instance.mesh = _immediate_mesh
	_debug_mesh_instance.top_level = true # Usa coordenadas do mundo (globais)
	
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.vertex_color_use_as_albedo = true
	_debug_material.no_depth_test = true # Faz as linhas ficarem visíveis mesmo atrás de obstáculos/pistas
	
	add_child(_debug_mesh_instance)

static var _last_toggle_frame: int = -1

func _unhandled_input(event: InputEvent) -> void:
	# Pressione F3 para alternar a visualização dos sensores em tempo de execução
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			var current_frame := Engine.get_process_frames()
			if current_frame != _last_toggle_frame:
				_last_toggle_frame = current_frame
				global_debug = not global_debug

func is_debug_active() -> bool:
	return debug and global_debug

func update_sensors() -> PackedFloat32Array:
	if is_debug_active():
		_debug_rays.clear()
	
	for i in range(SENSOR_COUNT):
		distances[i] = cast_sensor(sensor_angles[i])
	
	if is_debug_active():
		_draw_debug_rays()
	else:
		clear_debug()
	
	return distances

func cast_sensor(angle: float) -> float:
	# Direção local rotacionada no ângulo do sensor
	var local_direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, angle)
	
	# IMPORTANTE: Multiplicar pela orientação (basis) do carro para que os raios
	# acompanhem a rotação do veículo nas curvas
	var direction: Vector3 = -(global_transform.basis * local_direction).normalized()
	
	var start: Vector3 = global_transform * sensor_offset
	var end: Vector3 = start + direction * MAX_DISTANCE
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [get_parent()]
	
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	
	var hit: bool = not result.is_empty()
	var hit_pos: Vector3 = result.position if hit else end
	var distance: float = start.distance_to(hit_pos)
	
	if is_debug_active():
		_debug_rays.append({
			"start": start,
			"hit_pos": hit_pos,
			"end": end,
			"hit": hit
		})
	
	if not hit:
		return 1.0
	
	return clamp(distance / MAX_DISTANCE, 0.0, 1.0)

func _draw_debug_rays() -> void:
	_immediate_mesh.clear_surfaces()
	if _debug_rays.is_empty():
		return
	
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _debug_material)
	for ray in _debug_rays:
		var color: Color = Color.RED if ray["hit"] else Color.GREEN
		
		# Linha do carro até o impacto (ou distância máxima)
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(ray["start"])
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(ray["hit_pos"])
		
		# Se atingiu um obstáculo antes do fim, desenha o resto do alcance em vermelho transparente
		if ray["hit"]:
			var ghost_color := Color(1.0, 0.2, 0.2, 0.25)
			_immediate_mesh.surface_set_color(ghost_color)
			_immediate_mesh.surface_add_vertex(ray["hit_pos"])
			_immediate_mesh.surface_set_color(ghost_color)
			_immediate_mesh.surface_add_vertex(ray["end"])
			
	_immediate_mesh.surface_end()

func clear_debug() -> void:
	if _immediate_mesh and _immediate_mesh.get_surface_count() > 0:
		_immediate_mesh.clear_surfaces()
