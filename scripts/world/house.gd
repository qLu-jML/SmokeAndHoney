@tool
extends Node2D

const TILE     := 32
const W        := 11
const H        := 11
const DOOR_COL := 5   # 0-indexed centre column

# Colors
const COL_WALL := Color(0.62, 0.62, 0.70, 1.0)
const COL_DOOR := Color(0.55, 0.27, 0.07, 1.0)
const COL_EDGE := Color(0.28, 0.28, 0.32, 1.0)

var _transitioning := false

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()   # force _draw() to run so the house is visible in the editor
		return
	_build_walls()

func _draw() -> void:
	for row in range(H):
		for col in range(W):
			var rect := Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE))
			var fill: Color = COL_DOOR if (row == H - 1 and col == DOOR_COL) else COL_WALL
			draw_rect(rect, fill, true)
			draw_rect(rect, COL_EDGE, false, 0.5)

# -- Collision ----------------------------------------------------------------

func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	_add_shape(body, 0,          0,          W,                1)           # top
	_add_shape(body, 0,          1,          1,                H - 1)       # left
	_add_shape(body, W - 1,      1,          1,                H - 1)       # right
	_add_shape(body, 0,          H - 1,      DOOR_COL,         1)           # bottom-left
	_add_shape(body, DOOR_COL+1, H - 1,      W - DOOR_COL - 1, 1)          # bottom-right
	# Door column (row H-1, col DOOR_COL) intentionally has NO collision

func _add_shape(body: StaticBody2D, tx: int, ty: int, tw: int, th: int) -> void:
	var cs  := CollisionShape2D.new()
	var rs  := RectangleShape2D.new()
	rs.size     = Vector2(tw * TILE, th * TILE)
	cs.shape    = rs
	cs.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	body.add_child(cs)

# -- Door overlap check (runs every frame) ------------------------------------

# Door tile world-space rect
func _door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(DOOR_COL * TILE, (H - 1) * TILE),
				 Vector2(TILE, TILE))

# Player feet rect -- matches CollisionShape2D: size 14x10, centre at (0, 11)
func _feet_rect(player_gpos: Vector2) -> Rect2:
	return Rect2(player_gpos + Vector2(-7.0, 6.0), Vector2(14.0, 10.0))

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _transitioning:
		return
	var player := _find_player()
	if player == null:
		return
	var feet: Rect2  = _feet_rect((player as Node2D).global_position)
	var door  := _door_world_rect()
	var isect := door.intersection(feet)
	# Trigger when >50% of the foot rectangle is inside the door tile
	if isect.get_area() > feet.get_area() * 0.5:
		_trigger(player)

func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _trigger(body: Node) -> void:
	_transitioning = true
	_save_state()
	# Return pos: 3 tiles below the door so the player re-appears clear of it
	TimeManager.player_return_pos = global_position + Vector2(
		(DOOR_COL + 0.5) * TILE, (H + 3.0) * TILE)
	TimeManager.next_scene = "res://scenes/house/house_interior.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

# -- State save ----------------------------------------------------------------

func _save_state() -> void:
	TimeManager.exterior_hives.clear()
	for h in get_tree().get_nodes_in_group("hive"):
		var entry := {"pos": Vector2(h.global_position)}
		if h.has_meta("tile_coords"):
			entry["tile"] = Vector2i(h.get_meta("tile_coords"))
		TimeManager.exterior_hives.append(entry)

	TimeManager.exterior_flowers.clear()
	for f in get_tree().get_nodes_in_group("flowers"):
		TimeManager.exterior_flowers.append({"pos": Vector2(f.global_position)})

	TimeManager.came_from_interior = false
