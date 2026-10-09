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
var app_state_override: Node = null


func _ready() -> void:
	if has_node(simulation_path):
		_simulation = get_node(simulation_path) as Simulation
	if has_node(camera_path):
		_camera = get_node(camera_path) as FreeCamera

	_ensure_track_save_dirs()


func _get_app_state() -> Node:
	if app_state_override:
		return app_state_override
	if is_inside_tree() and get_tree() and get_tree().root:
		if get_tree().root.has_node("AppState"):
			return get_tree().root.get_node("AppState")
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root and main_loop.root.has_node("AppState"):
		return main_loop.root.get_node("AppState")
	if is_inside_tree() and has_node("/root/AppState"):
		return get_node_or_null("/root/AppState")
	return null


func _get_track_id() -> String:
	var app_state: Node = _get_app_state()
	if app_state and app_state.current_track_id != "":
		return app_state.current_track_id
	return "default_circuit"


const GLOBAL_CHAMPIONS_DIR: String = "user://champions/"
const GLOBAL_CHAMPIONS_PROJECT_DIR: String = "res://champions/"


func get_current_save_dir() -> String:
	return "user://saves/%s/" % _get_track_id()


func get_current_project_save_dir() -> String:
	return "res://saves/%s/" % _get_track_id()


func _ensure_track_save_dirs() -> void:
	var track_id := _get_track_id()
	var user_data_path := OS.get_user_data_dir()
	if DirAccess.dir_exists_absolute(user_data_path):
		DirAccess.make_dir_recursive_absolute(user_data_path + "/champions")
		DirAccess.make_dir_recursive_absolute(user_data_path + "/saves/" + track_id + "/champions")
		DirAccess.make_dir_recursive_absolute(user_data_path + "/saves/" + track_id + "/history")

	var res_dir := DirAccess.open("res://")
	if res_dir:
		res_dir.make_dir_recursive("champions")
		res_dir.make_dir_recursive("saves/" + track_id + "/champions")
		res_dir.make_dir_recursive("saves/" + track_id + "/history")


## Salva o estado completo da simulação e da câmera para a pista atual (com histórico versionado)
func save_simulation(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population:
		var err := "Erro: Simulação não encontrada para salvar!"
		emit_signal("operation_finished", false, err)
		return false

	_ensure_track_save_dirs()

	var app_state: Node = _get_app_state()
	var car_prof_id: String = app_state.current_car_profile_id if app_state else "standard"
	var car_prof_data: Dictionary = app_state.get_current_car_profile() if app_state else {}
	var timestamp_raw := Time.get_datetime_string_from_system()
	var timestamp_safe := timestamp_raw.replace(":", "-")
	var gen := _simulation.population.generation

	var payload: Dictionary = {
		"version": 2,
		"track_id": _get_track_id(),
		"car_profile_id": car_prof_id,
		"car_profile": car_prof_data,
		"timestamp": timestamp_raw,
		"simulation": {
			"all_time_max_laps": _simulation.all_time_max_laps,
			"current_max_laps": _simulation.current_max_laps,
			"population": _simulation.population.to_dict()
		}
	}

	if _camera and is_instance_valid(_camera):
		payload["camera"] = _camera.get_camera_state()

	var json_string := JSON.stringify(payload, "\t")

	# 1. Salva o quicksave mais recente
	var quicksave_path := filepath if filepath != "" else get_current_save_dir() + "quicksave.json"
	var success := _write_text_file(quicksave_path, json_string)
	var proj_success := _write_text_file(get_current_project_save_dir() + quicksave_path.get_file(), json_string)

	# 2. Salva versão histórica imutável (não sobrescreve histórico)
	var history_filename := "save_gen%d_%s.json" % [gen, timestamp_safe]
	var history_path := get_current_save_dir() + "history/" + history_filename
	_write_text_file(history_path, json_string)
	_write_text_file(get_current_project_save_dir() + "history/" + history_filename, json_string)

	if success or proj_success:
		var msg := "✅ Progresso salvo! (Geração #%d • Arquivado: %s)" % [gen, history_filename]
		emit_signal("operation_finished", true, msg)
		print(msg)
		return true
	else:
		var err := "❌ Falha ao gravar arquivo de save em: " + quicksave_path
		emit_signal("operation_finished", false, err)
		push_error(err)
		return false


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


## Exporta o genoma do melhor piloto treinado nesta pista sem sobrescrever histórico
func export_best_pilot(filepath: String = "") -> bool:
	if not _simulation or not _simulation.population or _simulation.population.genomes.is_empty():
		var err := "Erro: Nenhum piloto disponível para exportar!"
		emit_signal("operation_finished", false, err)
		return false

	_ensure_track_save_dirs()

	var app_state: Node = _get_app_state()
	var car_prof_id: String = app_state.current_car_profile_id if app_state else "standard"
	var car_prof_data: Dictionary = app_state.get_current_car_profile() if app_state else {}
	var timestamp_raw := Time.get_datetime_string_from_system()
	var timestamp_safe := timestamp_raw.replace(":", "-")
	var gen := _simulation.population.generation
	var best: Genome = _simulation.population.get_best_genome()

	var payload: Dictionary = {
		"model_type": "RaceAI_Best_Pilot",
		"track_id": _get_track_id(),
		"car_profile_id": car_prof_id,
		"car_profile": car_prof_data,
		"timestamp": timestamp_raw,
		"generation": gen,
		"fitness": best.fitness,
		"all_time_max_laps": _simulation.all_time_max_laps,
		"genome": best.to_dict()
	}

	var json_string := JSON.stringify(payload, "\t")

	# 1. Arquivo versionado único (NUNCA sobrescreve anteriores)
	var champion_filename := "champion_gen%d_fit%.0f_%s.json" % [gen, best.fitness, timestamp_safe]
	var versioned_user_path := get_current_save_dir() + "champions/" + champion_filename
	var versioned_res_path := get_current_project_save_dir() + "champions/" + champion_filename
	_write_text_file(versioned_user_path, json_string)
	_write_text_file(versioned_res_path, json_string)

	# 2. Atualiza cópia de conveniência do campeão mais recente
	var latest_user_path := get_current_save_dir() + "champion_latest.json"
	var latest_res_path := get_current_project_save_dir() + "champion_latest.json"
	_write_text_file(latest_user_path, json_string)
	_write_text_file(latest_res_path, json_string)
	_write_text_file(get_current_save_dir() + "best_pilot.json", json_string)

	# 3. Salva cópia no repositório global compartilhado para uso em outras pistas
	var global_filename := "champion_%s_gen%d_fit%.0f_%s.json" % [_get_track_id(), gen, best.fitness, timestamp_safe]
	_write_text_file(GLOBAL_CHAMPIONS_DIR + global_filename, json_string)
	_write_text_file(GLOBAL_CHAMPIONS_PROJECT_DIR + global_filename, json_string)

	var msg := "⭐ Campeão Gen #%d (Fit: %.1f) salvo! (%s)" % [gen, best.fitness, champion_filename]
	emit_signal("operation_finished", true, msg)
	print(msg)
	return true


## Lista todos os campeões (desta pista e globais de outras pistas)
func list_exported_champions(include_global: bool = true) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var seen: Dictionary = {}
	var user_champ_dir := get_current_save_dir() + "champions/"
	var res_champ_dir := get_current_project_save_dir() + "champions/"

	_scan_champions_dir(user_champ_dir, list, seen, false)
	_scan_champions_dir(res_champ_dir, list, seen, false)

	if include_global:
		_scan_champions_dir(GLOBAL_CHAMPIONS_DIR, list, seen, true)
		_scan_champions_dir(GLOBAL_CHAMPIONS_PROJECT_DIR, list, seen, true)

	list.sort_custom(func(a, b): return float(a.get("fitness", 0)) > float(b.get("fitness", 0)))
	return list


func _scan_champions_dir(dir_path: String, out_list: Array[Dictionary], seen: Dictionary, is_global: bool = false) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			if not seen.has(filename):
				seen[filename] = true
				var full_path := dir_path + filename
				var text := _read_text_file(full_path)
				var json := JSON.new()
				if json.parse(text) == OK and json.data is Dictionary:
					var data: Dictionary = json.data
					out_list.append({
						"filename": filename,
						"path": full_path,
						"generation": int(data.get("generation", 0)),
						"fitness": float(data.get("fitness", 0.0)),
						"track_id": String(data.get("track_id", "Geral")),
						"car_profile_id": String(data.get("car_profile_id", "")),
						"timestamp": String(data.get("timestamp", "")),
						"is_global": is_global
					})
		filename = dir.get_next()
	dir.list_dir_end()


## Abre a pasta de campeões no gerenciador de arquivos do sistema (Finder / Explorer)
func open_champions_folder() -> void:
	_ensure_track_save_dirs()
	var global_user_path := ProjectSettings.globalize_path(GLOBAL_CHAMPIONS_DIR)
	OS.shell_open(global_user_path)


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
	var base_dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)

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
