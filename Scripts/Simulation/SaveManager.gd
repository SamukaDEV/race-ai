class_name SaveManager
extends Node

## Gerenciador Central de Exportação e Importação (Save & Load)
## Os saves são particionados por pista (user://saves/<track_id>/ e res://saves/<track_id>/)
## para garantir que o treinamento de uma pista não interfira nos dados de outra.

signal operation_finished(success: bool, message: String)

@export var simulation_path: NodePath = ^"../Simulation"
@export var camera_path: NodePath = ^"../Camera3D"

var _simulation: Simulation
var _camera: FreeCamera


func _ready() -> void:
	if has_node(simulation_path):
		_simulation = get_node(simulation_path) as Simulation
	if has_node(camera_path):
		_camera = get_node(camera_path) as FreeCamera

	_ensure_track_save_dirs()


func _get_track_id() -> String:
	if AppState and AppState.current_track_id != "":
		return AppState.current_track_id
	return "default_circuit"


func get_current_save_dir() -> String:
	return "user://saves/%s/" % _get_track_id()


func get_current_project_save_dir() -> String:
	return "res://saves/%s/" % _get_track_id()


func _ensure_track_save_dirs() -> void:
	var track_id := _get_track_id()
	var user_dir := DirAccess.open("user://")
	if user_dir:
		if not user_dir.dir_exists("saves"):
			user_dir.make_dir("saves")
		if not user_dir.dir_exists("saves/" + track_id):
			user_dir.make_dir("saves/" + track_id)
	else:
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/saves/" + track_id)

	var res_dir := DirAccess.open("res://")
	if res_dir:
		if not res_dir.dir_exists("saves"):
			res_dir.make_dir("saves")
		if not res_dir.dir_exists("saves/" + track_id):
			res_dir.make_dir("saves/" + track_id)


## Salva o estado completo da simulação e da câmera para a pista atual
func save_simulation(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population:
		var err := "Erro: Simulação não encontrada para salvar!"
		emit_signal("operation_finished", false, err)
		return false

	_ensure_track_save_dirs()

	var target_filepath := filepath
	if target_filepath == "":
		target_filepath = get_current_save_dir() + "quicksave.json"

	var payload: Dictionary = {
		"version": 1,
		"track_id": _get_track_id(),
		"timestamp": Time.get_datetime_string_from_system(),
		"simulation": {
			"all_time_max_laps": _simulation.all_time_max_laps,
			"current_max_laps": _simulation.current_max_laps,
			"population": _simulation.population.to_dict()
		}
	}

	if _camera and is_instance_valid(_camera):
		payload["camera"] = _camera.get_camera_state()

	var json_string := JSON.stringify(payload, "\t")
	var success := _write_text_file(target_filepath, json_string)

	# Grava também uma cópia na pasta do projeto para backup no Git
	if success:
		var filename := target_filepath.get_file()
		_write_text_file(get_current_project_save_dir() + filename, json_string)

	if success:
		var gen := _simulation.population.generation
		var msg := "✅ Progresso salvo na pista [%s]! (Geração #%d)" % [_get_track_id(), gen]
		emit_signal("operation_finished", true, msg)
		print(msg)
	else:
		var err := "❌ Falha ao gravar arquivo de save em: " + target_filepath
		emit_signal("operation_finished", false, err)
		push_error(err)

	return success


## Carrega o estado completo da simulação e da câmera da pista atual
func load_simulation(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population:
		var err := "Erro: Simulação não encontrada para carregar!"
		emit_signal("operation_finished", false, err)
		return false

	var target_path := filepath
	if target_path == "":
		target_path = get_current_save_dir() + "quicksave.json"

	# Fallbacks se o arquivo não estiver em user://: tenta na pasta do projeto ou raiz
	if not FileAccess.file_exists(target_path):
		var proj_path := get_current_project_save_dir() + target_path.get_file()
		var legacy_user := "user://saves/" + target_path.get_file()
		var legacy_res := "res://saves/" + target_path.get_file()

		if FileAccess.file_exists(proj_path):
			target_path = proj_path
		elif FileAccess.file_exists(legacy_user):
			target_path = legacy_user
		elif FileAccess.file_exists(legacy_res):
			target_path = legacy_res
		else:
			var msg := "⚠️ Nenhum save encontrado para a pista [%s]!" % _get_track_id()
			emit_signal("operation_finished", false, msg)
			return false

	var json_string := _read_text_file(target_path)
	if json_string == "":
		var err := "❌ Arquivo de save vazio ou corrompido!"
		emit_signal("operation_finished", false, err)
		return false

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		var err := "❌ Erro ao analisar JSON: " + json.get_error_message()
		emit_signal("operation_finished", false, err)
		return false

	var data: Dictionary = json.data as Dictionary
	if not data.has("simulation"):
		var err := "❌ Estrutura de save inválida!"
		emit_signal("operation_finished", false, err)
		return false

	var sim_data: Dictionary = data["simulation"]
	_simulation.all_time_max_laps = int(sim_data.get("all_time_max_laps", 0))
	_simulation.current_max_laps = int(sim_data.get("current_max_laps", 0))

	if sim_data.has("population"):
		_simulation.population.load_from_dict(sim_data["population"])

	if data.has("camera") and _camera and is_instance_valid(_camera):
		_camera.set_camera_state(data["camera"])

	_simulation.start_generation()

	var gen := _simulation.population.generation
	var msg := "✅ Save da pista [%s] carregado! (Geração #%d)" % [_get_track_id(), gen]
	emit_signal("operation_finished", true, msg)
	print(msg)

	return true


## Exporta o genoma do melhor piloto treinado nesta pista
func export_best_pilot(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population or _simulation.population.genomes.is_empty():
		var err := "Erro: Nenhum piloto disponível para exportar!"
		emit_signal("operation_finished", false, err)
		return false

	_ensure_track_save_dirs()

	var target_filepath := filepath
	if target_filepath == "":
		target_filepath = get_current_save_dir() + "best_pilot.json"

	var best: Genome = _simulation.population.get_best_genome()
	var payload: Dictionary = {
		"model_type": "RaceAI_Best_Pilot",
		"track_id": _get_track_id(),
		"timestamp": Time.get_datetime_string_from_system(),
		"generation": _simulation.population.generation,
		"fitness": best.fitness,
		"all_time_max_laps": _simulation.all_time_max_laps,
		"genome": best.to_dict()
	}

	var json_string := JSON.stringify(payload, "\t")
	var success := _write_text_file(target_filepath, json_string)
	if success:
		_write_text_file(get_current_project_save_dir() + target_filepath.get_file(), json_string)
		var msg := "⭐ Piloto Campeão da pista [%s] exportado! (Fitness: %.1f)" % [_get_track_id(), best.fitness]
		emit_signal("operation_finished", true, msg)
		print(msg)
	else:
		var err := "❌ Falha ao exportar modelo do melhor piloto!"
		emit_signal("operation_finished", false, err)

	return success


## Importa um piloto campeão para ser a semente evolutiva desta pista
func import_best_pilot(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population:
		return false

	var target_path := filepath
	if target_path == "":
		target_path = get_current_save_dir() + "best_pilot.json"

	if not FileAccess.file_exists(target_path):
		var proj_path := get_current_project_save_dir() + target_path.get_file()
		var legacy_user := "user://saves/best_pilot.json"
		var legacy_res := "res://saves/best_pilot.json"

		if FileAccess.file_exists(proj_path):
			target_path = proj_path
		elif FileAccess.file_exists(legacy_user):
			target_path = legacy_user
		elif FileAccess.file_exists(legacy_res):
			target_path = legacy_res
		else:
			var msg := "⚠️ Nenhum arquivo de piloto campeão encontrado para [%s]!" % _get_track_id()
			emit_signal("operation_finished", false, msg)
			return false

	var text := _read_text_file(target_path)
	var json := JSON.new()
	if json.parse(text) != OK:
		emit_signal("operation_finished", false, "❌ Erro ao ler JSON do piloto!")
		return false

	var data: Dictionary = json.data as Dictionary
	if not data.has("genome"):
		emit_signal("operation_finished", false, "❌ Formato inválido de piloto!")
		return false

	var champion := Genome.from_dict(data["genome"])
	_simulation.population.genomes.clear()
	_simulation.population.genomes.append(champion.copy())

	while _simulation.population.genomes.size() < _simulation.population.population_size:
		var mutant: Genome = champion.copy()
		mutant.mutate(0.08, 0.25)
		_simulation.population.genomes.append(mutant)

	_simulation.population.generation = int(data.get("generation", 0))
	_simulation.start_generation()

	var msg := "⭐ Piloto Campeão importado! População pronta nesta pista."
	emit_signal("operation_finished", true, msg)
	return true


func _write_text_file(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(content)
	file.close()
	return true


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var content := file.get_as_text()
	file.close()
	return content
