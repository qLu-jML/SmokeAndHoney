# honey_house_ruin.gd -- Honey House examination interaction
# -----------------------------------------------------------------------------
# When the silas_old_honey_house quest is active, the player can examine the
# Honey House ruin by pressing E near it. This fires the first half of the
# quest event (examined = true). The quest completes when the player then
# visits Silas, who fires silas_honey_house_assessed.
#
# Once the Honey House is restored (silas_raising_the_roof complete), this
# script hides the ruin prompt and lets the normal door_zone handle entry.
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 50.0

var _prompt_label: Label = null
var _examined: bool = false

func _ready() -> void:
	add_to_group("honey_house_ruin")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Examine the Honey House"
	_prompt_label.add_theme_font_size_override("font_size", 6)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(140, 12)
	_prompt_label.position = Vector2(-70, -90)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

func _process(_delta: float) -> void:
	if _prompt_label == null:
		return
	# Only show during the silas_old_honey_house quest or before it starts
	if _examined:
		_prompt_label.visible = false
		return
	if QuestManager.is_complete("silas_raising_the_roof"):
		_prompt_label.visible = false
		return
	# Show prompt if player is nearby and quest conditions allow
	var show_prompt: bool = false
	if QuestManager.is_active("silas_old_honey_house"):
		show_prompt = true
	elif not QuestManager.is_complete("silas_old_honey_house") and not PlayerData.has_flag("honey_house_examined"):
		show_prompt = true

	if not show_prompt:
		_prompt_label.visible = false
		return

	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var dist: float = (player as Node2D).global_position.distance_to(global_position)
		_prompt_label.visible = dist <= INTERACT_RADIUS
	else:
		_prompt_label.visible = false

func interact() -> void:
	if _examined:
		return

	_examined = true
	PlayerData.set_flag("honey_house_examined")

	# Show examination dialogue
	var dialogue_ui: Node = get_tree().root.get_node_or_null("DialogueUI")
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		var lines: Array = [
			"The old Honey House. Hasn't been used in years.",
			"The roof is caved in on one side. Door hangs on a single hinge.",
			"Floor is cracked concrete, but the foundation looks solid.",
			"Screened windows are rusted through. Weeds growing inside.",
			"This used to be where Bob extracted his honey. Someone built it well.",
			"Maybe someone could fix it. Silas Crenshaw might know -- he is usually at his workshop.",
		]
		dialogue_ui.show_dialogue("", lines)

	# If the quest isn't active yet, this examination might help trigger it
	# The quest completion event fires when visiting Silas, not here
	_prompt_label.visible = false
