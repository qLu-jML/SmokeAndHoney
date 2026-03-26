extends Node2D

const TILE     := 32
const W        := 10
const H        := 10
const DOOR_COL := 4   # 0-indexed centre column (10 tiles wide)

# Colors
const COL_FLOOR := Color(0.76, 0.60, 0.42, 1.0)   # warm wood planks
const COL_WALL  := Color(0.45, 0.30, 0.18, 1.0)   # darker wood walls
const COL_DOOR  := Color(0.30, 0.15, 0.04, 1.0)   # dark-brown door tile
const COL_EDGE  := Color(0.25, 0.15, 0.05, 1.0)   # grid edge lines

var _transitioning := false

func _ready() -> void:
	TimeManager.current_scene_id = "house_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "House Interior"
		SceneManager.show_zone_name()
	_build_walls()
	_place_player()

func _place_player() -> void:
	var player = get_node_or_null("player")
	if player and player is Node2D:
		(player as Node2D).position = Vector2((W * 0.5) * TILE, TILE * 1.5)

func _draw() -> void:
	for row in range(H):
		for col in range(W):
			var rect := Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE))
			var fill: Color
			if row == 0 or col == 0 or col == W - 1:
				fill = COL_WALL
			elif row == H - 1 and col == DOOR_COL:
				fill = COL_DOOR
			else:
				fill = COL_FLOOR
			draw_rect(rect, fill, true)
			draw_rect(rect, COL_EDGE, false, 0.5)

# -- Collision -----------------------------------------------------------------

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

# -- Door overlap check (runs every frame) -------------------------------------

# Exit door tile world-space rect
func _door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(DOOR_COL * TILE, (H - 1) * TILE),
				 Vector2(TILE, TILE))

# Player feet rect -- matches CollisionShape2D: size 14x10, centre at (0, 11)
func _feet_rect(player_gpos: Vector2) -> Rect2:
	return Rect2(player_gpos + Vector2(-7.0, 6.0), Vector2(14.0, 10.0))

func _process(_delta: float) -> void:
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
		_trigger()

func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _trigger() -> void:
	_transitioning = true
	TimeManager.came_from_interior = true
	TimeManager.next_scene = "res://scenes/home_property.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
