# grange_interior.gd -- Cedar Valley Grange Hall interior with CVBA meetings.
# Extends the generic_interior base to add:
#   - CVBA meeting attendance tracking (counter: cvba_meetings)
#   - Meeting-night dialogue with rotating speakers
#   - Quest completion for cvba_the_new_kid (attend 3 meetings)
#   - Darlene appears as a fellow beekeeper (NPC interaction)
#
# The Grange Hall is only accessible on meeting night (day 14-15, 6-10 PM).
# cedar_bend.gd gates entry. This script handles what happens inside.
extends Node2D

@export var room_width: int = 12
@export var room_height: int = 10
@export var door_col: int = 5
@export var zone_name: String = "Cedar Valley Grange Hall"
@export var scene_id: String = "grange_interior"
@export var exit_scene: String = "res://scenes/world/cedar_bend.tscn"
@export var floor_color: Color = Color(0.68, 0.55, 0.38, 1.0)
@export var wall_color: Color = Color(0.42, 0.28, 0.15, 1.0)

const TILE: int = 32

var _transitioning: bool = false
var _meeting_attended: bool = false
var _dialogue_ui: Node = null

# -- Meeting dialogue lines (rotate by attendance count) ----------------------

# First meeting: the player is a stranger
const MEETING_1_LINES: Array = [
	"The room is half-full. Folding chairs in uneven rows. Coffee in styrofoam cups.",
	"A woman at the lectern is talking about oxalic acid dribble methods.",
	"People glance at you. A few nod. Nobody introduces themselves.",
	"Darlene catches your eye from across the room and gives a small wave.",
	"After the talk, a man with a John Deere cap says, 'You Bob's kid?'",
	"You say something about inheriting the hive. He nods. That is enough.",
	"The meeting breaks up around 8. You learned something. You were seen.",
]

# Second meeting: recognized but still outside
const MEETING_2_LINES: Array = [
	"Same chairs, same coffee. You know where to sit this time.",
	"Tonight's speaker is talking about spring splits and queen rearing.",
	"The John Deere cap man -- Lloyd, you learn -- saves you a seat.",
	"'Saw your hive from the road. Looking good,' he says. That is high praise here.",
	"Darlene stands up during questions and asks something technical about mite resistance.",
	"The room defers to her. She has been doing this longer than most of them.",
	"You stay for the whole meeting. People are starting to remember your name.",
]

# Third meeting: you belong now
const MEETING_3_LINES: Array = [
	"Third meeting. You do not hesitate at the door anymore.",
	"Lloyd has coffee waiting. Darlene sits next to you.",
	"The speaker asks if anyone has observations to share from their apiaries.",
	"Darlene nudges you. 'Tell them about your brood pattern.'",
	"You stand up. You describe what you saw in your last inspection.",
	"The room listens. A few people nod. Someone writes something down.",
	"After the meeting, the chapter president shakes your hand.",
	"'Good to have you,' she says. 'We need young beekeepers.'",
	"You are not the new kid anymore.",
]

# Fourth+ meeting: regular attendee
const MEETING_REGULAR_LINES: Array = [
	"Another meeting at the Grange. The coffee is still bad. The company is still good.",
	"Tonight's topic is winter preparation. You already know most of this.",
	"But you listen anyway. There is always something new.",
	"Darlene argues with Lloyd about entrance reducers. It is the same argument every year.",
	"You realize you are comfortable here. That took less time than you expected.",
]

# -- Lifecycle -----------------------------------------------------------------

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

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	# Auto-trigger meeting dialogue shortly after entering
	call_deferred("_start_meeting")
	print("Grange Hall interior loaded -- CVBA meeting night.")

func _place_player() -> void:
	var player: Node2D = get_node_or_null("player") as Node2D
	if player:
		player.position = Vector2((room_width * 0.5) * TILE, TILE * 1.5)

# -- Meeting System ------------------------------------------------------------

func _start_meeting() -> void:
	# Small delay so the scene transition settles
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")
	if _dialogue_ui == null or not _dialogue_ui.has_method("show_dialogue"):
		return

	# Determine which meeting this is (before incrementing)
	var meetings_before: int = QuestManager.get_counter("cvba_meetings")
	var lines: Array = _get_meeting_lines(meetings_before)

	_dialogue_ui.show_dialogue("", lines, "")

	# Record attendance
	QuestManager.notify_event("cvba_meeting_attended", {})
	_meeting_attended = true

	# Check if this was the 3rd meeting (counter was 2 before, now 3)
	if meetings_before == 2:
		# Fire the quest completion event
		QuestManager.notify_event("cvba_three_meetings", {})

func _get_meeting_lines(count: int) -> Array:
	match count:
		0:
			return MEETING_1_LINES
		1:
			return MEETING_2_LINES
		2:
			return MEETING_3_LINES
		_:
			return MEETING_REGULAR_LINES

# -- Room Drawing (same as generic_interior) -----------------------------------

func _draw() -> void:
	var door_color: Color = Color(0.30, 0.15, 0.04, 1.0)
	var edge_color: Color = Color(0.25, 0.15, 0.05, 1.0)
	for row in range(room_height):
		for col in range(room_width):
			var r: Rect2 = Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE))
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
	var body: StaticBody2D = StaticBody2D.new()
	add_child(body)
	_add_shape(body, 0, 0, room_width, 1)
	_add_shape(body, 0, 1, 1, room_height - 1)
	_add_shape(body, room_width - 1, 1, 1, room_height - 1)
	_add_shape(body, 0, room_height - 1, door_col, 1)
	_add_shape(body, door_col + 1, room_height - 1, room_width - door_col - 1, 1)

func _add_shape(body: StaticBody2D, tx: int, ty: int, tw: int, th: int) -> void:
	var cs: CollisionShape2D = CollisionShape2D.new()
	var rs: RectangleShape2D = RectangleShape2D.new()
	rs.size = Vector2(tw * TILE, th * TILE)
	cs.shape = rs
	cs.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	body.add_child(cs)

# -- Door Exit -----------------------------------------------------------------

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
			_exit()

func _process(_delta: float) -> void:
	if _transitioning:
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var player: Node2D = players[0] as Node2D
	if player == null:
		return
	var feet: Rect2 = _feet_rect(player.global_position)
	var door: Rect2 = _door_world_rect()
	var isect: Rect2 = door.intersection(feet)
	if isect.get_area() > feet.get_area() * 0.5:
		_exit()

func _exit() -> void:
	_transitioning = true
	TimeManager.came_from_interior = true
	TimeManager.next_scene = exit_scene
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
