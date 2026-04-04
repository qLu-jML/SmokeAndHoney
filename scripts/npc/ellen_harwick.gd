# ellen_harwick.gd -- Dr. Ellen Harwick NPC
# -----------------------------------------------------------------------------
# GDD S9: Dr. Ellen Harwick -- the local veterinarian / bee inspector.
#   She provides scientific insight, hive health assessments, and
#   guidance on disease management and treatments.
#
# Phase 1:
#   - Static sprite at a fixed position (not yet placed in world)
#   - Interaction prompt when player is nearby
#   - Uses DialogueUI autoload for speech bubbles and dialogue boxes
#   - Hint lines rotate through arrays each visit
#   - Awards XP for each conversation (GDD S7.1)
#
# Phase 2 (future):
#   - Inspection event triggers
#   - Disease diagnosis dialogue tree
#   - Treatment recommendation system
# -----------------------------------------------------------------------------
extends Node2D

# Interaction radius (pixels)
const INTERACT_RADIUS := 40.0

# -- Dialogue content ---------------------------------------------------------
const BUBBLE_LINES: Array = [
	"Good to see you taking care of your bees!",
	"Have you done a mite check this month?",
	"Healthy bees start with a healthy queen.",
	"Watch for deformed wings -- that's a varroa sign.",
	"I can inspect your hives anytime, just ask.",
	"Prevention is always cheaper than treatment.",
	"A sugar roll test only takes five minutes.",
]

const DIALOGUE_LINES: Array = [
	[
		"I'm Dr. Harwick -- I handle livestock health around here, bees included.",
		"If you ever see something in your hive that doesn't look right -- discolored larvae,\nfoul smell, spotty brood -- come find me.",
		"Early detection is everything with bee diseases.",
	],
	[
		"Varroa destructor is the number one threat to honey bees worldwide.",
		"They feed on fat bodies, not hemolymph like we used to think. That's why infected\nbees have shortened lifespans.",
		"Monitor monthly during the active season. I can show you how.",
	],
	[
		"American Foulbrood is the one you never want to see. Ropy, brown larval remains\nthat smell like old gym socks.",
		"If you suspect AFB, don't move any equipment. Come get me immediately.",
		"The good news? It's rare if you keep your equipment clean.",
	],
	[
		"Nosema is a gut parasite -- you'll see dysentery streaks on the landing board.",
		"It's worst in late winter when bees are confined. Good ventilation helps.",
		"Fumagillin used to be the standard treatment, but these days we focus on\nstrong genetics and hygienic behavior.",
	],
	[
		"Small hive beetles love warm, humid conditions. Keep your colonies strong\nand they'll police the beetles themselves.",
		"If you see larvae tunneling through comb, that's beetle damage. The honey\nwill ferment and the bees may abscond.",
		"Traps help, but a strong population is your best defense.",
	],
]

# -- State ---------------------------------------------------------------------
var _hint_index:     int  = 0
var _talking:        bool = false
var _prompt_label:   Label = null
var _dialogue_ui:    Node  = null

# -- Lifecycle -----------------------------------------------------------------

## Initialize Dr. Harwick: set up dialogue UI and add prompt label.
func _ready() -> void:
	add_to_group("ellen_harwick")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Dr. Harwick"
	_prompt_label.add_theme_font_size_override("font_size", 5)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(96, 8)
	_prompt_label.position = Vector2(-48, -52)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

## Check player distance each frame and show/hide interact prompt.
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

## Trigger dialogue with Dr. Harwick. Shows dialogue UI or fallback speech bubble.
## Seasonal dialogue for Dr. Harwick (disease/health focus).
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["Spring is when colonies are most vulnerable to starvation.", "Check stores weekly. If they're light, feed 1:1 sugar syrup until the nectar flow starts."],
		["Nosema can flare up in spring -- watch for dysentery streaks on the landing board.", "Strong colonies usually clear it on their own once it warms up."],
	],
	"Summer": [
		["Varroa reproduces inside capped brood cells. Summer is when populations explode.", "An alcohol wash kit is your best diagnostic tool. Test monthly, minimum."],
		["If you see deformed wings on bees at the entrance, that's DWV -- deformed wing virus.", "The virus rides on varroa mites. Treat the mites, you treat the virus."],
	],
	"Fall": [
		["Fall treatment is critical. You want mites low before the winter bees emerge.", "Winter bees live 4-6 months instead of 4-6 weeks. They cannot afford parasites."],
		["Oxalic acid is most effective when the colony is broodless -- late fall is ideal.", "One treatment, 90% efficacy. But timing matters."],
	],
	"Winter": [
		["Nothing to treat in winter. The cluster needs to stay undisturbed.", "If a colony is quiet, that's normal. If it's silent... come see me in spring."],
		["This is a good time to clean equipment and read up.", "Knowledge is the best medicine. Most losses come from what we didn't know to look for."],
	],
}

func interact() -> void:
	if _talking:
		return
	_talking = true
	_prompt_label.visible = false

	var lines: Array = _pick_dialogue()
	_hint_index += 1

	GameData.add_xp(2)

	# Teach alcohol wash on first summer/late spring conversation
	if KnowledgeLog and KnowledgeLog.has_method("unlock_entry"):
		if not KnowledgeLog.is_unlocked("the_mite_problem"):
			KnowledgeLog.unlock_entry("the_mite_problem")
			KnowledgeLog.unlock_entry("alcohol_wash")

	if _dialogue_ui and _dialogue_ui.has_method("show_dialogue"):
		_dialogue_ui.show_dialogue("Dr. Harwick", lines, "ellen_harwick")
		await _dialogue_ui.dialogue_finished
		_talking = false
	else:
		_show_speech_bubble_fallback(lines[0])

## Pick dialogue based on season.
func _pick_dialogue() -> Array:
	var season: String = _get_current_season()
	if SEASONAL_LINES.has(season):
		var pool: Array = SEASONAL_LINES[season]
		var idx: int = _hint_index % pool.size()
		return pool[idx]
	var idx: int = _hint_index % DIALOGUE_LINES.size()
	return DIALOGUE_LINES[idx]

func _get_current_season() -> String:
	if not TimeManager or not TimeManager.has_method("current_month_index"):
		return "Spring"
	var month: int = TimeManager.current_month_index()
	if month <= 1:
		return "Spring"
	elif month <= 3:
		return "Summer"
	elif month <= 5:
		return "Fall"
	else:
		return "Winter"

## Show a floating label as fallback when DialogueUI is unavailable.
func _show_speech_bubble_fallback(text: String) -> void:
	var bubble := Label.new()
	bubble.text = "Dr. Harwick: " + text
	bubble.add_theme_font_size_override("font_size", 5)
	bubble.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70, 1.0))
	bubble.position = Vector2(-48, -80)
	bubble.custom_minimum_size = Vector2(96, 0)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.z_index = 20
	add_child(bubble)

	var timer := get_tree().create_timer(4.0)
	var cleanup_fn := func():
		bubble.queue_free()
		_talking = false
	timer.timeout.connect(cleanup_fn)
	# Note: SceneTreeTimer auto-disconnects after firing; no explicit disconnect needed
