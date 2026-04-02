# zone_exit.gd -- Walk-to scene exit trigger.
# Place as a child of any scene. When the player overlaps this Area2D,
# transition to the target scene via the loading screen.
# Use the exported properties to configure each exit.
# @tool makes collision shapes visible as colored rects in the editor.
@tool
extends Area2D

@export var target_scene: String = ""
@export var exit_label_text: String = ""   # e.g., "-> Cedar Bend"
@export var spawn_side: String = "left"    # which side player spawns on in target scene
@export var energy_cost: float = 0.0       # optional energy deduction
## Color of the debug rectangle drawn in the editor
@export var debug_color: Color = Color(0.2, 0.6, 1.0, 0.25)

var _transitioning: bool = false
var _cooldown: bool = true  # ignore collisions briefly after scene load
var _label: Label = null

func _ready() -> void:
	# In-editor: just draw the debug overlay, skip runtime logic
	if Engine.is_editor_hint():
		queue_redraw()
		return

	# Disable collision for a short time so the player doesn't
	# immediately re-trigger this exit when spawning near it
	monitoring = false
	get_tree().create_timer(0.5).timeout.connect(_enable_monitoring)

	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _enable_monitoring() -> void:
	monitoring = true
	_cooldown = false

	# Create a visual label hint above the exit
	if exit_label_text != "":
		_label = Label.new()
		_label.text = exit_label_text
		_label.add_theme_font_size_override("font_size", 5)
		_label.add_theme_color_override("font_color", Color(0.90, 0.82, 0.58, 0.9))
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.size = Vector2(80, 12)
		_label.position = Vector2(-40, -20)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	# Create arrow indicator on the exit edge
	var arrow := Label.new()
	arrow.add_theme_font_size_override("font_size", 8)
	arrow.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 0.7))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.size = Vector2(20, 14)
	arrow.position = Vector2(-10, -8)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match spawn_side:
		"left":
			arrow.text = ">>"
		"right":
			arrow.text = "<<"
		"up":
			arrow.text = "vv"
		"down":
			arrow.text = "^^"
		_:
			arrow.text = ">>"
	add_child(arrow)

func _draw() -> void:
	# Only draw the debug rectangle in the editor, never at runtime
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		if child is CollisionShape2D:
			var cshape: CollisionShape2D = child as CollisionShape2D
			if cshape.shape is RectangleShape2D:
				var rect_shape: RectangleShape2D = cshape.shape as RectangleShape2D
				var half: Vector2 = rect_shape.size * 0.5
				var rect := Rect2(cshape.position - half, rect_shape.size)
				# Filled rectangle
				draw_rect(rect, debug_color, true)
				# Outline
				var outline_color := Color(debug_color.r, debug_color.g, debug_color.b, 0.8)
				draw_rect(rect, outline_color, false, 1.0)
	# Draw the label text in the editor too
	if exit_label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-30, -8), exit_label_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 5, Color(1, 1, 0.7, 0.9))

func _on_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if not body.is_in_group("player"):
		return
	if target_scene == "":
		print("[ZoneExit] No target scene configured!")
		return

	# Energy check
	if energy_cost > 0.0:
		if not GameData.deduct_energy(energy_cost):
			print("[ZoneExit] Too tired to travel!")
			return

	_transitioning = true
	# Store spawn info so the target scene can position the player
	TimeManager.set_meta("spawn_side", spawn_side)
	TimeManager.set_meta("source_scene", owner.scene_file_path if owner else "")
	TimeManager.next_scene = target_scene
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
