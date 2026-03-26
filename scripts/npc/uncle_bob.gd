# uncle_bob.gd -- Uncle Bob NPC
# -----------------------------------------------------------------------------
# GDD S9: Uncle Bob -- the player's experienced beekeeper uncle.
#   He lives next door, gives tutorials, and gently nudges the player toward
#   good beekeeping practice.
#
# Phase 1:
#   - Static sprite at a fixed position on the home property
#   - Interaction prompt when player is nearby
#   - Uses DialogueUI autoload for speech bubbles and dialogue boxes
#   - Hint lines rotate through HINTS array each visit
#   - Awards XP for each conversation (GDD S7.1)
#
# Phase 2 (future):
#   - Full quest-linked dialogue tree
#   - Seasonal contextual advice
# -----------------------------------------------------------------------------
extends Node2D

# Interaction radius (pixels)
const INTERACT_RADIUS := 40.0

# -- Dialogue content ---------------------------------------------------------
# Short opening line used for speech bubbles (MODE_BUBBLE).
const BUBBLE_LINES: Array = [
	"Morning! Your bees are looking lively today.",
	"Check those frames -- spring buildup is fast.",
	"A tight oval brood pattern means a healthy queen.",
	"Queen lays center-out. Frame 5 is usually her favorite.",
	"Don't harvest too soon -- wait for the frames to cap.",
	"A colony needs at least 60 lbs going into winter.",
	"Those dandelions are gold -- don't mow 'em yet!",
]

# Longer tutorial hints used in the full dialogue box.
const DIALOGUE_LINES: Array = [
	[
		"Glad you're out here. The best beekeepers I know spend more time watching than working.",
		"Press H to enter Hive mode, then E to place one of your hive bodies wherever looks good.",
		"Once it's down, walk up close and press E to open the inspection. Take a look inside.",
	],
	[
		"A healthy brood nest looks like a tight oval -- brown capped cells in the center,\nhoney arching around the outside like a rainbow.",
		"If you see spotty or scattered capping, something's off. Could be disease, cold snap, or a failing queen.",
		"Write it in your Knowledge Log. The bees will teach you if you pay attention.",
	],
	[
		"The queen lays from the center frame outward. Frame 5 is usually her first choice.",
		"You'll know you're on the right frame when you see tiny white eggs standing upright in the cells.",
		"Spotting her yourself is the real skill. You'll get better at it -- I promise.",
	],
	[
		"Spring is when everything happens at once. Colony builds fast in March and April.",
		"Watch for overcrowding -- if the brood box is packed, add a super or you'll lose half\nyour bees to a swarm.",
		"A swarm isn't the end of the world, but it's half your workforce walking out the door.",
	],
	[
		"Varroa is the thing that'll keep you up at night. One mite per hundred bees is your ceiling.",
		"Check with a sugar roll or alcohol wash once a month in summer. Don't guess.",
		"If the count is high, treat. Oxalic acid in late fall, formic in summer. I'll show you.",
	],
	[
		"Come fall, your whole job is making sure they have enough honey to survive winter.",
		"60 pounds minimum. Lift the back of the hive -- heavy is good.",
		"Don't harvest what they need. You can always buy more jars next year.",
	],
]

# -- State ---------------------------------------------------------------------
var _hint_index:     int  = 0
var _talking:        bool = false
var _prompt_label:   Label = null
var _dialogue_ui:    Node  = null   # DialogueUI autoload ref
@onready var _bob_sprite: Sprite2D = get_node_or_null("BobSprite")

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	add_to_group("uncle_bob")
	add_to_group("npc")

	# Load Uncle Bob's spritesheet at runtime (bypasses import pipeline)
	if _bob_sprite:
		var path := "res://assets/sprites/npc/Uncle_Bob/uncle_bob_spritesheet.png"
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			_bob_sprite.texture = tex
			_bob_sprite.hframes = 8
			_bob_sprite.vframes = 24
			_bob_sprite.frame = 0  # south-facing idle
			print("Uncle Bob: loaded spritesheet %dx%d" % [img.get_width(), img.get_height()])
		else:
			push_error("Uncle Bob: failed to load spritesheet from %s" % abs_path)

	# Find or create DialogueUI
	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	# "[E] Talk" prompt label -- shown when player is nearby
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Uncle Bob"
	_prompt_label.add_theme_font_size_override("font_size", 7)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(120, 12)
	_prompt_label.position = Vector2(-60, -70)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

func _process(_delta: float) -> void:
	if _prompt_label == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var dist: float = (player as Node2D).global_position.distance_to(global_position)
		_prompt_label.visible = dist <= INTERACT_RADIUS and not _talking
	else:
		_prompt_label.visible = false

# -- Public API ----------------------------------------------------------------

## Called by player.gd when E is pressed near Uncle Bob.
func interact() -> void:
	if _talking:
		return
	_talking = true
	_prompt_label.visible = false

	var idx := _hint_index % DIALOGUE_LINES.size()
	var lines: Array = DIALOGUE_LINES[idx]
	_hint_index += 1

	# Award XP for the conversation (GDD S7.1)
	GameData.add_xp(2)

	# Use DialogueUI if available; fall back to speech bubble
	if _dialogue_ui and _dialogue_ui.has_method("show_dialogue"):
		_dialogue_ui.show_dialogue("Uncle Bob", lines, "uncle_bob")
		await _dialogue_ui.dialogue_finished
		_talking = false
	else:
		_show_speech_bubble_fallback(lines[0])

func _show_speech_bubble_fallback(text: String) -> void:
	# Legacy fallback: floating label if DialogueUI is not present
	var bubble := Label.new()
	bubble.text = "Bob: " + text
	bubble.add_theme_font_size_override("font_size", 5)
	bubble.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70, 1.0))
	bubble.position = Vector2(-48, -80)
	bubble.custom_minimum_size = Vector2(96, 0)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.z_index = 20
	add_child(bubble)

	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func():
		bubble.queue_free()
		_talking = false
	)
