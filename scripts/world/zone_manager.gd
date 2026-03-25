extends Node

const SAVE_PATH = "user://zones.json"

var flower_tiles: Dictionary = {}  # Vector2i -> true
var apiary_tiles: Dictionary = {}  # Vector2i -> true

func _ready() -> void:
	_load()

func set_flower(tile: Vector2i) -> void:
	apiary_tiles.erase(tile)
	if flower_tiles.has(tile):
		flower_tiles.erase(tile)
	else:
		flower_tiles[tile] = true
	_save()

func set_apiary(tile: Vector2i) -> void:
	flower_tiles.erase(tile)
	if apiary_tiles.has(tile):
		apiary_tiles.erase(tile)
	else:
		apiary_tiles[tile] = true
	_save()

func clear_tile(tile: Vector2i) -> void:
	flower_tiles.erase(tile)
	apiary_tiles.erase(tile)
	_save()

func is_flower_zone(tile: Vector2i) -> bool:
	return flower_tiles.has(tile)

func is_apiary_zone(tile: Vector2i) -> bool:
	return apiary_tiles.has(tile)

# --- Persistence ---

func _save() -> void:
	var data = {
		"flower": _vec_dict_to_list(flower_tiles),
		"apiary": _vec_dict_to_list(apiary_tiles)
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	flower_tiles = _list_to_vec_dict(parsed.get("flower", []))
	apiary_tiles = _list_to_vec_dict(parsed.get("apiary", []))

func _vec_dict_to_list(d: Dictionary) -> Array:
	var out: Array = []
	for key in d:
		out.append([key.x, key.y])
	return out

func _list_to_vec_dict(arr: Array) -> Dictionary:
	var out: Dictionary = {}
	for pair in arr:
		out[Vector2i(pair[0], pair[1])] = true
	return out
