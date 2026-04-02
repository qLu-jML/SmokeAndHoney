extends Node

const SAVE_PATH: String = "user://zones.json"

var flower_tiles: Dictionary = {}
var apiary_tiles: Dictionary = {}

## Initialize zone manager and load saved zone data.
func _ready() -> void:
	_load()

## Set a tile as a flower zone (or toggle if already set).
func set_flower(tile: Vector2i) -> void:
	apiary_tiles.erase(tile)
	if flower_tiles.has(tile):
		flower_tiles.erase(tile)
	else:
		flower_tiles[tile] = true
	_save()

## Set a tile as an apiary zone (or toggle if already set).
func set_apiary(tile: Vector2i) -> void:
	flower_tiles.erase(tile)
	if apiary_tiles.has(tile):
		apiary_tiles.erase(tile)
	else:
		apiary_tiles[tile] = true
	_save()

## Clear a tile (remove it from both flower and apiary zones).
func clear_tile(tile: Vector2i) -> void:
	flower_tiles.erase(tile)
	apiary_tiles.erase(tile)
	_save()

## Check if a tile is marked as a flower zone.
func is_flower_zone(tile: Vector2i) -> bool:
	return flower_tiles.has(tile)

## Check if a tile is marked as an apiary zone.
func is_apiary_zone(tile: Vector2i) -> bool:
	return apiary_tiles.has(tile)

## Save zone data to persistent storage.
func _save() -> void:
	var data: Dictionary = {
		"flower": _vec_dict_to_list(flower_tiles),
		"apiary": _vec_dict_to_list(apiary_tiles)
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

## Load zone data from persistent storage.
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	flower_tiles = _list_to_vec_dict(parsed.get("flower", []))
	apiary_tiles = _list_to_vec_dict(parsed.get("apiary", []))

## Convert a Vector2i dictionary to an array of coordinate pairs.
func _vec_dict_to_list(d: Dictionary) -> Array:
	var out: Array = []
	for key: Vector2i in d:
		out.append([key.x, key.y])
	return out

## Convert an array of coordinate pairs back to a Vector2i dictionary.
func _list_to_vec_dict(arr: Array) -> Dictionary:
	var out: Dictionary = {}
	for pair: Array in arr:
		out[Vector2i(pair[0], pair[1])] = true
	return out
