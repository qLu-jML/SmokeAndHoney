# exit_helper.gd -- Static helper for creating walk-to zone exits.
# Call ExitHelper.create_exit() from any scene's _ready() to add exits.
class_name ExitHelper
extends RefCounted

## Create a zone exit area at a given position and size.
## edge: "left", "right", "top", "bottom" -- which screen edge the exit is on
## target_scene: the scene file to transition to
## label_text: display text like "-> Cedar Bend"
## parent: the node to add the exit to
static func create_exit(parent: Node, edge: String, target_scene: String,
		label_text: String = "", offset: float = 0.0,
		bounds: Rect2 = Rect2(-700, -200, 1400, 500)) -> Area2D:
	var exit: Area2D = Area2D.new()
	exit.name = "Exit_" + edge + "_" + label_text.replace(" ", "").replace("->", "").replace("<-", "")
	exit.collision_layer = 0
	exit.collision_mask = 1  # detect player (layer 1)

	# Store target on the node so position_player can find it later
	exit.set_meta("target_scene", target_scene)

	# Size and position based on edge and scene bounds
	var bx: float = bounds.position.x
	var by: float = bounds.position.y
	var bw: float = bounds.size.x
	var bh: float = bounds.size.y
	var cx: float = bx + bw * 0.5
	var cy: float = by + bh * 0.5
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	match edge:
		"right":
			rect.size = Vector2(30, bh)
			exit.position = Vector2(bx + bw + offset, cy)
		"left":
			rect.size = Vector2(30, bh)
			exit.position = Vector2(bx + offset, cy)
		"top":
			rect.size = Vector2(bw, 30)
			exit.position = Vector2(cx, by + offset)
		"bottom":
			rect.size = Vector2(bw, 30)
			exit.position = Vector2(cx, by + bh + offset)
	shape.shape = rect
	exit.add_child(shape)

	# Label
	if label_text != "":
		var lbl: Label = Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 0.85))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(100, 12)
		lbl.position = Vector2(-50, -20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exit.add_child(lbl)

	# Arrow indicator
	var arrow: Label = Label.new()
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 0.6))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.size = Vector2(20, 16)
	arrow.position = Vector2(-10, -6)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match edge:
		"right":  arrow.text = ">>"
		"left":   arrow.text = "<<"
		"top":    arrow.text = "^^"
		"bottom": arrow.text = "vv"
	exit.add_child(arrow)

	parent.add_child(exit)

	# Disable monitoring briefly so it doesn't fire on scene load
	exit.monitoring = false
	exit.get_tree().create_timer(0.5).timeout.connect(func() -> void: exit.monitoring = true)

	# Connect signal for body_entered - store signal connection lambda
	var spawn_side: String = ""
	match edge:
		"right":  spawn_side = "left"     # player enters target from the left
		"left":   spawn_side = "right"    # player enters target from the right
		"top":    spawn_side = "bottom"   # player enters target from the bottom
		"bottom": spawn_side = "top"      # player enters target from the top

	exit.body_entered.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player"):
				# Store where we came from so the target scene can find the right exit
				TimeManager.set_meta("spawn_side", spawn_side)
				TimeManager.set_meta("source_scene", parent.scene_file_path)
				TimeManager.next_scene = target_scene
				# Defer scene change to avoid removing nodes during physics callback
				body.get_tree().call_deferred(
					"change_scene_to_file",
					"res://scenes/loading/loading_screen.tscn")
	)

	return exit


## Position the player near the exit they just arrived from.
## Searches for any exit node (ZoneExit or dynamic) whose target matches the
## scene the player came from, then places the player nearby with an offset
## so they don't immediately re-trigger the exit.
## Also sets up camera limits for the scene.
static func position_player_from_spawn_side(scene: Node,
		bounds: Rect2 = Rect2(0, 0, 0, 0)) -> void:
	var player: Node2D = scene.get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	# -- Resolve bounds: explicit arg > scene const > unlimited --
	var use_bounds: Rect2 = bounds
	if use_bounds.size == Vector2.ZERO:
		if scene.get_script() and "SCENE_BOUNDS" in scene:
			use_bounds = scene.get("SCENE_BOUNDS") as Rect2

	# -- Update camera limits --
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		if use_bounds.size != Vector2.ZERO:
			cam.limit_left   = int(use_bounds.position.x)
			cam.limit_top    = int(use_bounds.position.y)
			cam.limit_right  = int(use_bounds.position.x + use_bounds.size.x)
			cam.limit_bottom = int(use_bounds.position.y + use_bounds.size.y)
		else:
			cam.limit_left   = -10000000
			cam.limit_top    = -10000000
			cam.limit_right  =  10000000
			cam.limit_bottom =  10000000

	# -- Read transition metadata --
	var side: String = ""
	var source_scene: String = ""
	if TimeManager.has_meta("spawn_side"):
		side = TimeManager.get_meta("spawn_side")
		TimeManager.remove_meta("spawn_side")
	if TimeManager.has_meta("source_scene"):
		source_scene = TimeManager.get_meta("source_scene")
		TimeManager.remove_meta("source_scene")

	# -- Try to find the exit that leads back to the source scene --
	# This works for both physical ZoneExit nodes and dynamic ExitHelper exits.
	var arrival_exit: Node2D = _find_exit_to_scene(scene, source_scene)

	if arrival_exit:
		# Spawn near this exit, offset 150px inward (away from the exit)
		var exit_pos: Vector2 = arrival_exit.position
		var offset_dir: Vector2 = _get_inward_offset(side)
		player.position = exit_pos + offset_dir * 200.0
	elif use_bounds.size != Vector2.ZERO and side != "":
		# Fallback: position based on scene bounds edge (old behavior)
		var margin: float = 200.0
		match side:
			"left":
				player.position = Vector2(use_bounds.position.x + margin, player.position.y)
			"right":
				player.position = Vector2(use_bounds.position.x + use_bounds.size.x - margin, player.position.y)
			"top":
				player.position = Vector2(player.position.x, use_bounds.position.y + margin)
			"bottom":
				player.position = Vector2(player.position.x, use_bounds.position.y + use_bounds.size.y - margin)


## Find an exit node in the scene that leads to the given target scene path.
## Checks both ZoneExit nodes (target_scene property) and dynamic exits (meta).
static func _find_exit_to_scene(scene: Node, target_path: String) -> Node2D:
	if target_path == "":
		return null
	# Search all children recursively for Area2D nodes with target_scene
	var exits: Array = []
	_collect_exits(scene, exits)
	for exit_node in exits:
		var exit_target: String = ""
		# ZoneExit nodes have an exported target_scene property
		if "target_scene" in exit_node:
			exit_target = exit_node.target_scene
		# Dynamic ExitHelper exits store it as meta
		if exit_target == "" and exit_node.has_meta("target_scene"):
			exit_target = exit_node.get_meta("target_scene") as String
		if exit_target != "" and exit_target == target_path:
			return exit_node
	return null


## Recursively collect all Area2D children (potential exits)
static func _collect_exits(node: Node, results: Array) -> void:
	for child in node.get_children():
		if child is Area2D:
			results.append(child)
		_collect_exits(child, results)


## Given a spawn_side, return the direction vector pointing inward (away from edge)
static func _get_inward_offset(side: String) -> Vector2:
	match side:
		"left":
			return Vector2(1, 0)    # entered from left, push right
		"right":
			return Vector2(-1, 0)   # entered from right, push left
		"top":
			return Vector2(0, 1)    # entered from top, push down
		"bottom":
			return Vector2(0, -1)   # entered from bottom, push up
	return Vector2.ZERO
