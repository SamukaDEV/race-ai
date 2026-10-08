class_name SaveManager
extends Node

## Gerenciador Central de Exportação e Importação (Save & Load)
## Responsável por serializar/deserializar o estado genético da população,
## o modelo do piloto campeão e a posição da câmera livre em formato JSON.

signal operation_finished(success: bool, message: String)

@export var simulation_path: NodePath = ^"../Simulation"
@export var camera_path: NodePath = ^"../Camera3D"

const SAVE_DIR: String = "user://saves/"
const PROJECT_SAVE_DIR: String = "res://saves/"

var _simulation: Simulation
var _camera: FreeCamera


func _ready() -> void:
	_ensure_save_directories()
	if has_node(simulation_path):
		_simulation = get_node(simulation_path) as Simulation
	if has_node(camera_path):
		_camera = get_node(camera_path) as FreeCamera


func _ensure_save_directories() -> void:
	var user_dir := DirAccess.open("user://")
	if user_dir:
		if not user_dir.dir_exists("saves"):
			user_dir.make_dir("saves")
	else:
		var full_user_path: String = OS.get_user_data_dir()
		DirAccess.make_dir_recursive_absolute(full_user_path + "/saves")

	var res_dir := DirAccess.open("res://")
	if res_dir:
		if not res_dir.dir_exists("saves"):
			res_dir.make_dir("saves")


## Salva o estado completo da simulação e da câmera
func save_simulation(filepath: String = "user://saves/quicksave.json") -> bool:
	if not _simulation or not _simulation.population:
		var err := "Erro: Simulação não encontrada para salvar!"
		emit_signal("operation_finished", false, err)
		return false

	var payload: Dictionary = {
		"version": 1,
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
	var success := _write_text_file(filepath, json_string)

	# Grava também uma cópia na pasta do projeto para facilitar backup no Git
	if success and filepath.begins_with("user://saves/"):
		var filename := filepath.get_file()
		_write_text_file(PROJECT_SAVE_DIR + filename, json_string)

	if success:
		var gen := _simulation.population.generation
		var msg := "✅ Progresso salvo com sucesso! (Geração #%d)" % gen
		emit_signal("operation_finished", true, msg)
		print(msg)
	else:
		var err := "❌ Falha ao gravar arquivo de save em: " + filepath
		emit_signal("operation_finished", false, err)
		push_error(err)

	return success


## Carrega o estado completo da simulação e da câmera
func load_simulation(filepath: String = "user://saves/quicksave.json") -> bool:
	if not _simulation or not _simulation.population:
		var err := "Erro: Simulação não encontrada para carregar!"
		emit_signal("operation_finished", false, err)
		return false

	# Se não encontrar em user://, tenta buscar em res://saves/
	var target_path := filepath
	if not FileAccess.file_exists(target_path):
		var fallback_path := PROJECT_SAVE_DIR + filepath.get_file()
		if FileAccess.file_exists(fallback_path):
			target_path = fallback_path
		else:
			var _msg := "⚠️ Nenhum arquivo de save encontrado para carregar!"
			emit_signal("operation_finished", false, _msg)
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

	# Restaura a câmera se presente no save
	if data.has("camera") and _camera and is_instance_valid(_camera):
		_camera.set_camera_state(data["camera"])

	# Reinicia os carros na pista com os novos genomas carregados
	_simulation.start_generation()

	var gen := _simulation.population.generation
	var msg := "✅ Save carregado com sucesso! (Geração #%d)" % gen
	emit_signal("operation_finished", true, msg)
	print(msg)

	return true


## Exporta apenas o genoma do piloto com maior pontuação (modelo campeão)
func export_best_pilot(filepath: String = "user://saves/best_pilot.json") -> bool:
	if not _simulation or not _simulation.population or _simulation.population.genomes.is_empty():
		var err := "Erro: Nenhum piloto disponível para exportar!"
		emit_signal("operation_finished", false, err)
		return false

	var best: Genome = _simulation.population.get_best_genome()
	var payload: Dictionary = {
		"model_type": "RaceAI_Best_Pilot",
		"timestamp": Time.get_datetime_string_from_system(),
		"generation": _simulation.population.generation,
		"fitness": best.fitness,
		"all_time_max_laps": _simulation.all_time_max_laps,
		"genome": best.to_dict()
	}

	var json_string := JSON.stringify(payload, "\t")
	var success := _write_text_file(filepath, json_string)
	if success:
		_write_text_file(PROJECT_SAVE_DIR + filepath.get_file(), json_string)
		var msg := "⭐ Piloto Campeão exportado! (Fitness: %.1f)" % best.fitness
		emit_signal("operation_finished", true, msg)
		print(msg)
	else:
		var err := "❌ Falha ao exportar modelo do melhor piloto!"
		emit_signal("operation_finished", false, err)

	return success


## Importa um piloto campeão e preenche a população com ele e mutações derivadas
func import_best_pilot(filepath: String = "user://saves/best_pilot.json") -> bool:
	if not _simulation or not _simulation.population:
		return false

	var target_path := filepath
	if not FileAccess.file_exists(target_path):
		var fallback := PROJECT_SAVE_DIR + filepath.get_file()
		if FileAccess.file_exists(fallback):
			target_path = fallback
		else:
			var _msg := "⚠️ Arquivo de piloto não encontrado: " + filepath.get_file()
			emit_signal("operation_finished", false, _msg)
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

	# O campeão entra puro como indivíduo 0
	_simulation.population.genomes.append(champion.copy())

	# O restante da população é gerado com pequenas mutações para acelerar a evolução
	while _simulation.population.genomes.size() < _simulation.population.population_size:
		var mutant: Genome = champion.copy()
		mutant.mutate(0.08, 0.25)
		_simulation.population.genomes.append(mutant)

	_simulation.population.generation = int(data.get("generation", 0))
	_simulation.start_generation()

	var msg := "⭐ Piloto Campeão importado! População clonada com sucesso."
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
