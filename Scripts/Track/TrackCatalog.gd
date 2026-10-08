class_name TrackCatalog
extends RefCounted

## Catálogo de Peças Modulares de Pista
## Contém o mapeamento de IDs de peças para seus PackedScenes e metadados.

const PIECES: Dictionary = {
	"RoadStart": {
		"name": "Portal de Largada",
		"path": "res://Models/Roads/RoadStart.tscn",
		"category": "Largada"
	},
	"RoadStartPositions": {
		"name": "Grid de Posições",
		"path": "res://Models/Roads/RoadStartPositions.tscn",
		"category": "Largada"
	},
	"RoadStraight": {
		"name": "Reta Curta",
		"path": "res://Models/Roads/RoadStraight.tscn",
		"category": "Retas"
	},
	"RoadStraightLong": {
		"name": "Reta Longa",
		"path": "res://Models/Roads/RoadStraightLong.tscn",
		"category": "Retas"
	},
	"RoadCornerLarge": {
		"name": "Curva Larga",
		"path": "res://Models/Roads/RoadCornerLarge.tscn",
		"category": "Curvas"
	},
	"RoadCornerSmall": {
		"name": "Curva Fechada",
		"path": "res://Models/Roads/RoadCornerSmall.tscn",
		"category": "Curvas"
	},
	"RoadCornerLarger": {
		"name": "Curva Muito Larga",
		"path": "res://Models/Roads/RoadCornerLarger.tscn",
		"category": "Curvas"
	},
	"RoadBump": {
		"name": "Lombada",
		"path": "res://Models/Roads/RoadBump.tscn",
		"category": "Especiais"
	},
	"RoadCrossing": {
		"name": "Cruzamento",
		"path": "res://Models/Roads/RoadCrossing.tscn",
		"category": "Especiais"
	}
}

static var _cached_scenes: Dictionary = {}


static func get_scene(piece_id: String) -> PackedScene:
	if not PIECES.has(piece_id):
		push_error("Peça não encontrada no catálogo: " + piece_id)
		return null

	if _cached_scenes.has(piece_id):
		return _cached_scenes[piece_id]

	var scene_path: String = PIECES[piece_id]["path"]
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		_cached_scenes[piece_id] = scene
		return scene

	push_error("Não foi possível carregar o arquivo da peça: " + scene_path)
	return null


static func get_piece_name(piece_id: String) -> String:
	if PIECES.has(piece_id):
		return PIECES[piece_id]["name"]
	return piece_id


static func get_all_piece_ids() -> Array:
	return PIECES.keys()
