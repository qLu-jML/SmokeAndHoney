# frank_fischbach.gd -- Frank Fischbach NPC
# -----------------------------------------------------------------------------
# GDD S9: Frank Fischbach -- the local honey buyer / general store owner.
#   He buys honey, sells equipment, and provides market-related tips.
#
# Phase 1:
#   - Static sprite at a fixed position (not yet placed in world)
#   - Interaction prompt when player is nearby
#   - Uses DialogueUI autoload for speech bubbles and dialogue boxes
#   - Hint lines rotate through arrays each visit
#   - Awards XP for each conversation (GDD S7.1)
#
# Phase 2 (future):
#   - Honey buying / equipment shop interface
#   - Price fluctuations tied to season and quality
#   - Special order quests
# -----------------------------------------------------------------------------
extends Node2D

# Interaction radius (pixels)
const INTERACT_RADIUS := 40.0

# -- Dialogue content ---------------------------------------------------------
const BUBBLE_LINES: Array = [
	"Hey there! Got any honey for me today?",
	"Wildflower honey's been selling like crazy.",
	"Quality matters -- the restaurants pay double for the good stuff.",
	"I just got a new batch of frames in stock.",
	"Spring honey is lighter. Folks love it on toast.",
	"Business has been good this season!",
	"Let me know when you're ready to sell.",
]

const DIALOGUE_LINES: Array = [
	[
		"Name's Frank. I run the general store in town -- been buying local honey for years.",
		"When you've got jars to sell, bring 'em by. I pay fair prices, especially\nfor the premium stuff.",
		"Wildflower, clover, goldenrod -- each has its market. People care about flavor now.",
	],
	[
		"Here's a tip: the restaurants in the city pay top dollar for single-source honey.",
		"If you can keep your bees near one kind of flower -- clover, say -- that jar\nis worth three times a mixed batch.",
		"It's not easy, but it's worth planning your forage patches.",
	],
	[
		"I also stock equipment if you need it. Frames, supers, smokers, the works.",
		"Prices go up in spring when everyone's buying. Smart beekeepers stock up\nin winter when I'm trying to clear shelves.",
		"Come by the shop anytime.",
	],
	[
		"Wax is an overlooked product. Candles, cosmetics, furniture polish --\npeople will buy it.",
		"Save your cappings when you extract. Melt 'em down, strain 'em,\nand you've got another revenue stream.",
		"I'll buy clean wax blocks if you've got 'em.",
	],
	[
		"The farmers' market runs every weekend during the warm months.",
		"Having a booth there is great exposure. Folks love meeting the beekeeper\nbehind the label.",
		"Just make sure your jars are labeled right. Health department's been\nchecking lately.",
	],
]

# -- State ---------------------------------------------------------------------
var _hint_index:     int  = 0
var _talking:        bool = false
var _prompt_label:   Label = null
var _dialogue_ui:    Node  = null

# -- Lifecycle -----------------------------------------------------------------

## Initialize Frank: set up dialogue UI and add prompt label.
func _ready() -> void:
	add_to_group("frank_fischbach")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Frank"
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

## Trigger dialogue with Frank. Shows dialogue UI or fallback speech bubble.
## Seasonal market advice from Frank.
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["Spring honey is light and delicate. Customers pay a premium for it.", "But don't rush the harvest -- reputation is built on quality, not quantity."],
		["Folks are buying seeds and garden supplies right now. Good foot traffic.", "If you have any early-spring wildflower honey, that's liquid gold at the market."],
	],
	"Summer": [
		["Saturday Market is packed in summer. Bring your best jars.", "Presentation matters. Clean labels, full jars, a smile. That's the formula."],
		["Summer honey is darker, stronger. Different customers, same good money.", "Offer samples. Once people taste real local honey, they never go back to store-bought."],
	],
	"Fall": [
		["Fall market slows down, but the buyers who come are serious.", "Bulk honey and beeswax sell well now. Candle makers stock up before the holidays."],
		["If you've got any premium honey left, hold some back.", "Winter prices go up. Supply goes down. That's just math."],
	],
	"Winter": [
		["Market's quiet. Good time to plan next year's lineup.", "Beeswax candles, infused honey, gift sets -- diversify your offerings."],
		["People buy honey as gifts in winter. Presentation is everything.", "A nice jar with a hand-written label? That's a story they're buying, not just food."],
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

	if _dialogue_ui and _dialogue_ui.has_method("show_dialogue"):
		_dialogue_ui.show_dialogue("Frank", lines, "frank_fischbach")
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
	bubble.text = "Frank: " + text
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
