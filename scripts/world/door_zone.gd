# door_zone.gd -- Building door entry trigger.
# Place as a child of a building Sprite2D. When the player overlaps,
# transitions to the interior scene.
# @tool makes the door zone visible as a colored rect in the editor.
@tool
extends Area2D

@export var target_scene: String = ""
@export var building_name: String = ""
## Color of the debug rectangle drawn in the editor
@export var debug_color: Color = Color(1.0, 0.5, 0.2, 0.3)

var _transitioning: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)

func _draw() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			var cshape: CollisionShape2D = child as CollisionShape2D
			if cshape.shape is RectangleShape2D:
				var rect_shape: RectangleShape2D = cshape.shape as RectangleShape2D
				var half: Vector2 = rect_shape.size * 0.5
				var rect := Rect2(cshape.position - half, rect_shape.size)
				draw_rect(rect, debug_color, true)
				var outline_color := Color(debug_color.r, debug_color.g, debug_color.b, 0.8)
				draw_rect(rect, outline_color, false, 1.0)
	# Label in editor
	if building_name != "":
		draw_string(ThemeDB.fallback_font, Vector2(-20, -6), building_name, HORIZONTAL_ALIGNMENT_CENTER, 40, 5, Color(1, 0.8, 0.5, 0.9))

func _on_body_entered(body: Node2D) -> void:
	if _transitioning:
		return
	if body.name != "player" and not body.is_in_group("player"):
		return
	if target_scene == "":
		print("[DoorZone] No target scene set for %s" % building_name)
		return
	_transitioning = true
	# Save exterior state
	var home: Node = get_tree().current_scene
	if home and home.has_method("_save_exterior_state"):
		home._save_exterior_state()
	TimeManager.came_from_interior = false
	TimeManager.player_return_pos = body.global_position
	print("[DoorZone] Entering %s -> %s" % [building_name, target_scene])
	SceneManager.go_to_scene(target_scene)
