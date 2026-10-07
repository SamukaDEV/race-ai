class_name CarSensors
extends Node3D

@export var sensor_offset := Vector3(0.0, 0.3, -1.5)

const SENSOR_COUNT: int = 5
const MAX_DISTANCE: float = 30.0

var sensor_angles: Array = [
	deg_to_rad(-45.0),
	deg_to_rad(-22.5),
	0.0,
	deg_to_rad(22.5),
	deg_to_rad(45.0)
]

var distances: PackedFloat32Array

func _ready() -> void:
	distances.resize(SENSOR_COUNT)

func update_sensors() -> PackedFloat32Array:
	for i in range(SENSOR_COUNT):
		distances[i] = cast_sensor(sensor_angles[i])
	
	return distances

func cast_sensor(angle: float) -> float:
	# Considerando Z como frente.
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, angle)
	
	# Without start offset:
	#var start: Vector3 = global_position
	# With start offset:
	var start: Vector3 = global_transform * sensor_offset
	var end: Vector3 = start + direction * MAX_DISTANCE
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end)
	
	query.exclude = [get_parent()]
	
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	
	if result.is_empty():
		return 1.0
	
	var distance: float = start.distance_to(result.position)
	
	return clamp(distance / MAX_DISTANCE, 0.0, 1.0)
