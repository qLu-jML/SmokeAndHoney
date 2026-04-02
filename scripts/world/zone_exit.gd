# zone_exit.gd -- Walk-to scene exit trigger.
# Place as a child of any scene. When the player overlaps this Area2D,
# transition to the target scene via the loading screen.
# Use the exported properties to configure each exit.
# @tool makes collision shapes visible as colored rects in the editor.
@tool
extends Area2D

@export var target_scene: String = ""
@export var exit_label_text: String = ""
@export var spawn_side: String = "left"
@export var energy_cost: float = 0.0
## Color of the debug rectangle drawn in the editor
@export var debug_color: Color = Color(0.2, 0.6, 1.0, 0.25)

var _transitioning: bool = false
var _cooldown: bool = true
var _label: Label = null
var _debug_overlay: Node2D = null

## Initialize the zone exit with collision shapes and signal connections.
func _ready() -> void:
	# In-editor: just draw the debug overlay, skip runtime logic
	if Engine.is_editor_hint():
		queue_redraw()
		return

	# Create high-z debug overlay for dev mode collision visibility
	_create_debug_overlay()
	GameData.dev_labels_toggled.connect(_on_dev_labels_toggled)

	# Disable collision for a short time so the player doesn't
	# immediately re-trigger this exit when spawning near it
	monitoring = false
	get_tree().create_timer(0.5).timeout.connect(_enable_monitoring)

	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

## Enable monitoring after cooldown and create visual hint label.
func _enable_monitoring() -> void:
	monitoring = true
	_cooldown = false

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

	var arrow: Label = Label.new()
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

## Draw debug rectangle in the editor to visualize exit zones.
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
				draw_rect(rect, debug_color, true)
				var outline_color: Color = Color(debug_color.r, debug_color.g, debug_color.b, 0.8)
				draw_rect(rect, outline_color, false, 1.0)
	if exit_label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-30, -8), exit_label_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 5, Color(1, 1, 0.7, 0.9))

## Create high-z debug overlay so collision is visible on top of everything.
func _create_debug_overlay() -> void:
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "CollisionDebugOverlay"
	_debug_overlay.z_index = 100
	_debug_overlay.z_as_relative = false
	_debug_overlay.set_script(load("res://scripts/debug/collision_debug_draw.gd"))
	_update_debug_rects()
	add_child(_debug_overlay)
	_debug_overlay.visible = GameData.dev_labels_visible

## Update debug overlay collision rectangles from child CollisionShape2D nodes.
func _update_debug_rects() -> void:
	if _debug_overlay == null:
		return
	var rects: Array = []
	for child in get_children():
		if child is CollisionShape2D:
			var cshape: CollisionShape2D = child as CollisionShape2D
			if cshape.shape is RectangleShape2D:
				var rs: RectangleShape2D = cshape.shape as RectangleShape2D
				var half: Vector2 = rs.size * 0.5
				rects.append(Rect2(cshape.position - half, rs.size))
	_debug_overlay.set_meta("rects", rects)
	_debug_overlay.queue_redraw()

## Toggle debug overlay when dev mode changes.
func _on_dev_labels_toggled(vis: bool) -> void:
	if _debug_overlay:
		_debug_overlay.visible = vis
		_debug_overlay.queue_redraw()

## Disconnect signals when exiting the scene.
func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		if body_entered.is_connected(_on_body_entered):
			body_entered.disconnect(_on_body_entered)
		if GameData and GameData.dev_labels_toggled.is_connected(_on_dev_labels_toggled):
			GameData.dev_labels_toggled.disconnect(_on_dev_labels_toggled)

## Handle player entering the zone exit and transition to target scene.
func _on_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if not body.is_in_group("player"):
		return
	if target_scene == "":
		print("[ZoneExit] No target scene configured!")
		return

	if energy_cost > 0.0:
		if not GameData.deduct_energy(energy_cost):
			print("[ZoneExit] Too tired to travel!")
			return

	_transitioning = true
	TimeManager.set_meta("spawn_side", spawn_side)
	TimeManager.set_meta("source_scene", owner.scene_file_path if owner else "")
	TimeManager.next_scene = target_scene
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
