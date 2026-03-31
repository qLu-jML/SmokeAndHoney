# exit_helper.gd -- Static helper for creating walk-to zone exits.
# Call ExitHelper.create_exit() from any scene's _ready() to add exits.
class_name ExitHelper
extends RefCounted

# Create a zone exit area at a given position and size.
# edge: "left", "right", "top", "bottom" -- which screen edge the exit is on
# target_scene: the scene file to transition to
# label_text: display text like "-> Cedar Bend"
# parent: the node to add the exit to
static func create_exit(parent: Node, edge: String, target_scene: String,
		label_text: String = "", offset: float = 0.0) -> Area2D:
	var exit := Area2D.new()
	exit.name = "Exit_" + edge + "_" + label_text.replace(" ", "").replace("->", "").replace("<-", "")
	exit.collision_layer = 0
	exit.collision_mask = 1  # detect player (layer 1)

	# Size and position based on edge
	# Scene bounds: roughly -700..700 x, -200..300 y (1400x500 total)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	match edge:
		"right":
			rect.size = Vector2(30, 500)
			exit.position = Vector2(700 + offset, 50)
		"left":
			rect.size = Vector2(30, 500)
			exit.position = Vector2(-700 + offset, 50)
		"top":
			rect.size = Vector2(1400, 30)
			exit.position = Vector2(0, -200 + offset)
		"bottom":
			rect.size = Vector2(1400, 30)
			exit.position = Vector2(0, 200 + offset)
	shape.shape = rect
	exit.add_child(shape)

	# Label
	if label_text != "":
		var lbl := Label.new()
		lbl.text = label_text
		lbl.add_theme_font_size_override("font_size", 6)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 0.85))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(100, 12)
		lbl.position = Vector2(-50, -20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		exit.add_child(lbl)

	# Arrow indicator
	var arrow := Label.new()
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

	# Connect signal
	var spawn_side: String = ""
	match edge:
		"right":  spawn_side = "left"     # player enters target from the left
		"left":   spawn_side = "right"    # player enters target from the right
		"top":    spawn_side = "bottom"   # player enters target from the bottom
		"bottom": spawn_side = "top"      # player enters target from the top

	exit.body_entered.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player"):
				TimeManager.set_meta("spawn_side", spawn_side)
				TimeManager.next_scene = target_scene
				# Defer scene change to avoid removing nodes during physics callback
				body.get_tree().call_deferred(
					"change_scene_to_file",
					"res://scenes/loading/loading_screen.tscn")
	)

	return exit

# Place the player on the correct side based on TimeManager spawn_side meta
static func position_player_from_spawn_side(scene: Node) -> void:
	var player: Node2D = scene.get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var side: String = ""
	if TimeManager.has_meta("spawn_side"):
		side = TimeManager.get_meta("spawn_side")
		TimeManager.remove_meta("spawn_side")

	match side:
		"left":
			player.position = Vector2(-620, player.position.y)
		"right":
			player.position = Vector2(620, player.position.y)
		"top":
			player.position = Vector2(player.position.x, -150)
		"bottom":
			player.position = Vector2(player.position.x, 150)
		# else: keep default position
