extends Node

## Estado Global da Aplicação (Autoload)
## Gerencia a pista atualmente selecionada, comunicação entre o Menu Principal,
## o Editor de Pistas e a cena de Simulação.

signal track_changed(track_id: String)

var current_track_id: String = "default_circuit"
var current_track_name: String = "Circuito Padrão"

## Flag e dados temporários caso o usuário teste uma pista diretamente pelo editor
var is_testing_editor_track: bool = false
var temporary_editor_track_data: Dictionary = {}

## Persistência da pose da câmera do editor entre testes
var editor_camera_transform: Transform3D = Transform3D()
var has_saved_editor_camera: bool = false


func set_current_track(id: String, track_name: String = "") -> void:
	current_track_id = id
	current_track_name = track_name if track_name != "" else id.capitalize()
	is_testing_editor_track = false
	emit_signal("track_changed", current_track_id)


## Retorna o caminho de gravação do usuário para a pista especificada
func get_track_save_dir(track_id: String = "") -> String:
	var target_id := track_id if track_id != "" else current_track_id
	return "user://saves/%s/" % target_id


## Retorna o caminho dentro da pasta do projeto para a pista especificada
func get_track_project_save_dir(track_id: String = "") -> String:
	var target_id := track_id if track_id != "" else current_track_id
	return "res://saves/%s/" % target_id
