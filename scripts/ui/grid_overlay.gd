extends Node2D

const TILE_SIZE := 32
var show_grid: bool = false
var _was_drawing: bool = false   # tracks previous frame's draw state

func _process(_delta: float) -> void:
	# Only force a redraw when there is something visible to update.
	# When the grid and hive-placement preview are both off, _draw() would do
	# nothing, so skipping queue_redraw() saves a draw call every frame.
	var player = get_node_or_null("../player")
	var needs_draw := show_grid
	if not needs_draw and player and player.has_method("get") \
			and player.get("current_mode") == 3:
		needs_draw = true
	if needs_draw:
		_was_drawing = true
		queue_redraw()
	elif _was_drawing:
		# One final redraw to clear the last painted frame (green box, grid lines)
		_was_drawing = false
		queue_redraw()

func _draw() -> void:
	var player = get_node_or_null("../player")
	var tilemap: TileMap = get_node_or_null("../TileMap")

	if not player or not tilemap:
		return

	var map_coords: Vector2i = (
		player.get_target_tile_coords(tilemap)
		if player.has_method("get_target_tile_coords")
		else Vector2i.ZERO
	)
	var snapped_rect := _tile_rect(map_coords, tilemap)

	if show_grid:
		# -- Grid lines, derived from TileMap so they always align -------------
		var player_local := tilemap.to_local(player.global_position)
		var center_tile  := tilemap.local_to_map(player_local)

		# How many tiles fit in half the viewport
		var htiles := int(400.0 / TILE_SIZE) + 2
		var vtiles := int(300.0 / TILE_SIZE) + 2

		var x0 := center_tile.x - htiles
		var x1 := center_tile.x + htiles
		var y0 := center_tile.y - vtiles
		var y1 := center_tile.y + vtiles

		# World-space extents of the draw area (top-left of corner tiles)
		var draw_left  := _tile_left_x(x0,     tilemap)
		var draw_right := _tile_left_x(x1 + 1, tilemap)
		var draw_top   := _tile_top_y(y0,      tilemap)
		var draw_bot   := _tile_top_y(y1 + 1,  tilemap)

		# Vertical lines -- one per tile column boundary
		for tx in range(x0, x1 + 2):
			var lx := _tile_left_x(tx, tilemap)
			draw_line(Vector2(lx, draw_top), Vector2(lx, draw_bot), Color(1, 1, 1, 0.2))

		# Horizontal lines -- one per tile row boundary
		for ty in range(y0, y1 + 2):
			var ty_pos := _tile_top_y(ty, tilemap)
			draw_line(Vector2(draw_left, ty_pos), Vector2(draw_right, ty_pos), Color(1, 1, 1, 0.2))

		# -- Targeter ----------------------------------------------------------
		draw_rect(snapped_rect, Color(0, 1, 0, 0.30), true)
		draw_rect(snapped_rect, Color(0, 0, 0, 1.00), false, 1.5)

	# -- Hive placement preview (HIVE mode) -------------------------------------
	if player.has_method("get") and player.get("current_mode") == 3:
		# Collect existing hive tile positions
		var hive_tiles: Array = []
		for h in get_tree().get_nodes_in_group("hive"):
			if h.has_meta("tile_coords"):
				hive_tiles.append(h.get_meta("tile_coords"))
			elif h is Node2D and tilemap:
				hive_tiles.append(
					tilemap.local_to_map(tilemap.to_local((h as Node2D).global_position))
				)

		# Check if target tile is too close to an existing hive
		var too_close := false
		for hive_tile in hive_tiles:
			var ht: Vector2i = hive_tile as Vector2i
			if maxi(absi(map_coords.x - ht.x), absi(map_coords.y - ht.y)) <= 2:
				too_close = true
				break

		# Show green if placeable, red if blocked
		if too_close:
			draw_rect(snapped_rect, Color(1, 0, 0, 0.40), true)
			draw_rect(snapped_rect, Color(1, 0, 0, 0.90), false, 1.5)
		else:
			draw_rect(snapped_rect, Color(0.4, 0.9, 0.2, 0.35), true)
			draw_rect(snapped_rect, Color(0.4, 0.9, 0.2, 0.90), false, 1.5)

# -- Helpers -------------------------------------------------------------------

## Rect2 for a tile in this node's local draw space.
## Uses the TileMap's own coordinate conversion so the result always aligns
## with painted sprites regardless of where the TileMap node is positioned.
func _tile_rect(tile: Vector2i, tilemap: TileMap) -> Rect2:
	var world_center := tilemap.to_global(tilemap.map_to_local(tile))
	var local_center := to_local(world_center)
	return Rect2(local_center - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5), Vector2(TILE_SIZE, TILE_SIZE))

## X coordinate of the left edge of tile column tx, in this node's local space.
func _tile_left_x(tx: int, tilemap: TileMap) -> float:
	var world_center := tilemap.to_global(tilemap.map_to_local(Vector2i(tx, 0)))
	return to_local(world_center).x - TILE_SIZE * 0.5

## Y coordinate of the top edge of tile row ty, in this node's local space.
func _tile_top_y(ty: int, tilemap: TileMap) -> float:
	var world_center := tilemap.to_global(tilemap.map_to_local(Vector2i(0, ty)))
	return to_local(world_center).y - TILE_SIZE * 0.5
