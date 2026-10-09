class_name CarProfileManager
extends RefCounted

## Gerenciador Central de Perfis de Carros (Car Profiles)
## Permite criar, carregar, salvar, listar e duplicar características
## físicas e configurações de sensores dos veículos.

const CARS_DIR_USER: String = "user://cars/"
const CARS_DIR_RES: String = "res://cars/"

## Retorna a estrutura do perfil padrão de fábrica
static func get_default_profile() -> Dictionary:
	return {
		"id": "standard",
		"name": "Padrão",
		"physics": {
			"max_speed": 300.0,
			"acceleration": 200.0,
			"brake_force": 100.0,
			"steering_speed": 2.5
		},
		"sensors": {
			"sensor_count": 5,
			"sensor_range": 1.5,
			"sensor_spread_angle": 90.0,
			"sensor_offset_y": 0.05,
			"sensor_offset_z": 0.15
		}
	}


## Garante que os diretórios de gravação existam
static func _ensure_dirs() -> void:
	var user_dir := DirAccess.open("user://")
	if user_dir:
		if not user_dir.dir_exists("cars"):
			user_dir.make_dir("cars")
	else:
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/cars")

	var res_dir := DirAccess.open("res://")
	if res_dir:
		if not res_dir.dir_exists("cars"):
			res_dir.make_dir("cars")


## Lista todos os perfis disponíveis no jogo (user:// e res://)
static func list_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}

	# 1. Busca em user://cars/
	_scan_dir_for_profiles(CARS_DIR_USER, result, seen)

	# 2. Busca em res://cars/
	_scan_dir_for_profiles(CARS_DIR_RES, result, seen)

	# Se nenhum foi encontrado, inclui o padrão em memória
	if result.is_empty():
		var default_prof := get_default_profile()
		result.append({
			"id": default_prof["id"],
			"name": default_prof["name"],
			"data": default_prof
		})

	return result


static func _scan_dir_for_profiles(dir_path: String, out_list: Array[Dictionary], seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var prof_id := filename.get_basename()
			if not seen.has(prof_id):
				seen[prof_id] = true
				var prof_data := get_profile(prof_id)
				out_list.append({
					"id": prof_id,
					"name": prof_data.get("name", prof_id.capitalize()),
					"data": prof_data
				})
		filename = dir.get_next()
	dir.list_dir_end()


## Carrega um perfil específico pelo seu ID
static func get_profile(profile_id: String) -> Dictionary:
	var user_path := CARS_DIR_USER + profile_id + ".json"
	var res_path := CARS_DIR_RES + profile_id + ".json"

	var target_path := ""
	if FileAccess.file_exists(user_path):
		target_path = user_path
	elif FileAccess.file_exists(res_path):
		target_path = res_path

	if target_path == "":
		if profile_id == "standard" or profile_id == "":
			return get_default_profile()
		push_warning("Perfil de carro não encontrado: %s, usando padrão." % profile_id)
		return get_default_profile()

	var file := FileAccess.open(target_path, FileAccess.READ)
	if not file:
		return get_default_profile()

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("Erro ao analisar JSON do perfil de carro %s: %s" % [profile_id, json.get_error_message()])
		return get_default_profile()

	var data: Dictionary = json.data as Dictionary
	return _normalize_profile(data, profile_id)


## Salva um perfil de carro em disco
static func save_profile(profile_data: Dictionary) -> bool:
	_ensure_dirs()
	var prof_id: String = profile_data.get("id", "custom_car")
	if prof_id == "":
		prof_id = "custom_car"
	profile_data["id"] = prof_id

	var json_str := JSON.stringify(profile_data, "\t")

	var success_user := false
	var user_file := FileAccess.open(CARS_DIR_USER + prof_id + ".json", FileAccess.WRITE)
	if user_file:
		user_file.store_string(json_str)
		user_file.close()
		success_user = true

	var res_success := false
	var res_file := FileAccess.open(CARS_DIR_RES + prof_id + ".json", FileAccess.WRITE)
	if res_file:
		res_file.store_string(json_str)
		res_file.close()
		res_success = true

	return success_user or res_success


## Exclui um perfil customizado (não permite excluir o 'standard')
static func delete_profile(profile_id: String) -> bool:
	if profile_id == "standard":
		return false

	var user_path := CARS_DIR_USER + profile_id + ".json"
	if FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(user_path)

	var res_path := CARS_DIR_RES + profile_id + ".json"
	if FileAccess.file_exists(res_path):
		DirAccess.remove_absolute(res_path)

	return true


## Normaliza dados do perfil garantindo retrocompatibilidade e acesso direto facilitado
static func _normalize_profile(raw: Dictionary, fallback_id: String) -> Dictionary:
	var prof := raw.duplicate(true)

	if not prof.has("id") or prof["id"] == "":
		prof["id"] = fallback_id
	if not prof.has("name") or prof["name"] == "":
		prof["name"] = prof["id"].capitalize()

	# Normaliza bloco de física
	if not prof.has("physics") or not (prof["physics"] is Dictionary):
		prof["physics"] = {
			"max_speed": float(prof.get("max_speed", 300.0)),
			"acceleration": float(prof.get("acceleration", 200.0)),
			"brake_force": float(prof.get("brake_force", 100.0)),
			"steering_speed": float(prof.get("steering_speed", 2.5))
		}
	else:
		var phy: Dictionary = prof["physics"]
		phy["max_speed"] = float(phy.get("max_speed", 300.0))
		phy["acceleration"] = float(phy.get("acceleration", 200.0))
		phy["brake_force"] = float(phy.get("brake_force", 100.0))
		phy["steering_speed"] = float(phy.get("steering_speed", 2.5))

	# Normaliza bloco de sensores
	if not prof.has("sensors") or not (prof["sensors"] is Dictionary):
		prof["sensors"] = {
			"sensor_count": int(prof.get("sensor_count", 5)),
			"sensor_range": float(prof.get("sensor_range", 1.5)),
			"sensor_spread_angle": float(prof.get("sensor_spread_angle", 90.0)),
			"sensor_offset_y": float(prof.get("sensor_offset_y", 0.05)),
			"sensor_offset_z": float(prof.get("sensor_offset_z", 0.15))
		}
	else:
		var sen: Dictionary = prof["sensors"]
		sen["sensor_count"] = int(sen.get("sensor_count", 5))
		sen["sensor_range"] = float(sen.get("sensor_range", 1.5))
		sen["sensor_spread_angle"] = float(sen.get("sensor_spread_angle", 90.0))
		sen["sensor_offset_y"] = float(sen.get("sensor_offset_y", 0.05))
		sen["sensor_offset_z"] = float(sen.get("sensor_offset_z", 0.15))

	# Adiciona atalhos planos para conveniência
	prof["max_speed"] = prof["physics"]["max_speed"]
	prof["acceleration"] = prof["physics"]["acceleration"]
	prof["brake_force"] = prof["physics"]["brake_force"]
	prof["steering_speed"] = prof["physics"]["steering_speed"]
	prof["sensor_count"] = prof["sensors"]["sensor_count"]
	prof["sensor_range"] = prof["sensors"]["sensor_range"]
	prof["sensor_spread_angle"] = prof["sensors"]["sensor_spread_angle"]

	return prof
