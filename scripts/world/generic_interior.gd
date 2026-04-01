# generic_interior.gd -- Reusable interior scene script.
# Draws a simple room with walls, floor, and a door exit.
# Set exported properties in each .tscn to customize.
extends Node2D

@export var room_width: int = 10
@export var room_height: int = 8
@export var door_col: int = 4
@export var zone_name: String = "Interior"
@export var scene_id: String = "interior"
@export var exit_scene: String = ""
@export var floor_color: Color = Color(0.76, 0.60, 0.42, 1.0)
@export var wall_color: Color = Color(0.45, 0.30, 0.18, 1.0)

const TILE := 32

var _transitioning := false

func _ready() -> void:
	TimeManager.current_scene_id = scene_id
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = zone_name
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(0, 0, room_width * TILE, room_height * TILE))
		SceneManager.register_scene_poi(
			Vector2(door_col * TILE + TILE * 0.5, (room_height - 1) * TILE),
			"Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Exit")
	_build_walls()
	_place_player()
	queue_redraw()
	print("%s interior loaded." % zone_name)

func _place_player() -> void:
	var player: Node2D = get_node_or_null("player") as Node2D
	if player:
		player.position = Vector2((room_width * 0.5) * TILE, TILE * 1.5)

func _draw() -> void:
	var door_color := Color(0.30, 0.15, 0.04, 1.0)
	var edge_color := Color(0.25, 0.15, 0.05, 1.0)
	for row in range(room_height):
		for col in range(room_width):
			var r := Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE))
			var fill: Color
			if row == 0 or col == 0 or col == room_width - 1:
				fill = wall_color
			elif row == room_height - 1 and col == door_col:
				fill = door_color
			else:
				fill = floor_color
			draw_rect(r, fill, true)
			draw_rect(r, edge_color, false, 0.5)

func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	_add_shape(body, 0, 0, room_width, 1)
	_add_shape(body, 0, 1, 1, room_height - 1)
	_add_shape(body, room_width - 1, 1, 1, room_height - 1)
	_add_shape(body, 0, room_height - 1, door_col, 1)
	_add_shape(body, door_col + 1, room_height - 1, room_width - door_col - 1, 1)

func _add_shape(body: StaticBody2D, tx: int, ty: int, tw: int, th: int) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(tw * TILE, th * TILE)
	cs.shape = rs
	cs.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	body.add_child(cs)

func _door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(door_col * TILE, (room_height - 1) * TILE),
				 Vector2(TILE, TILE))

func _feet_rect(player_gpos: Vector2) -> Rect2:
	return Rect2(player_gpos + Vector2(-7.0, 6.0), Vector2(14.0, 10.0))

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_trigger()

func _process(_delta: float) -> void:
	if _transitioning:
		return
	var player := _find_player()
	if player == null:
		return
	var feet: Rect2 = _feet_rect((player as Node2D).global_position)
	var door := _door_world_rect()
	var isect := door.intersection(feet)
	if isect.get_area() > feet.get_area() * 0.5:
		_trigger()

func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _trigger() -> void:
	_transitioning = true
	var target: String = exit_scene
	if target == "":
		target = TimeManager.previous_scene
	if target == "":
		target = "res://scenes/home_property.tscn"
	TimeManager.came_from_interior = true
	TimeManager.next_scene = target
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
