# frank_fischbach.gd -- Frank Fischbach NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Frank Fischbach -- the market man.
#   German-American, mid-50s, always wearing decades-old Cedar Bend Corn
#   Festival cap. Runs Saturday Market. Cheerful ruthlessness -- direct
#   feedback, doesn't coddle. Economic realist in a cast of romantics.
#   His approval matters because he doesn't give it cheaply.
#
# Year 1 Quests:
#   Q1: First Jar -- bring honey to market, sell at least 1 jar
#   Q2: The Saturday Regulars -- 4 consecutive markets, 2 products, $50
#
# Dialogue priority:
#   1. First visit (introduces himself)
#   2. Post-quest debrief
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"Hey there. You're Bob's kid, right? I'm Frank.",
	"I run the Saturday Market. Been doing it for -- oh, fifteen years now.",
	"If you've got something to sell, I've got a spot for you.",
	"Honey, wax, whatever you make. People come here for local, for real.",
	"But I'll tell you straight: this isn't a hobby market.",
	"People are spending money. They expect quality. Presentation matters.",
	"When you've got jars ready, bring them by on Saturday. We'll talk.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"frank_first_jar": [
		"You sold one. Good start.",
		"But let me be honest with you. Those labels look like a school project.",
		"That's not an insult. It's actionable feedback.",
		"Clean labels. Consistent jars. A name people can remember.",
		"The honey is good. The packaging needs to catch up.",
		"Come back next Saturday. And the Saturday after that. And the one after that.",
		"Consistency is what turns a booth into a business.",
	],
	"frank_saturday_regulars": [
		"Four Saturdays in a row. Two products. Fifty dollars.",
		"You know what that proves? It proves you'll show up.",
		"Showing up is ninety percent of this. The other ten is quality.",
		"People are asking for you now. 'Where's the honey kid?' That's what they say.",
		"That's worth more than the honey.",
		"I'm bumping your pricing. You've earned it.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"frank_first_jar": [
		"You've got honey? Good. Bring at least 3 jars to Saturday Market.",
		"I've got a spot for you. Show up, set up, and sell at least one jar.",
		"After that, we'll talk about what you're doing right and what needs work.",
	],
	"frank_saturday_regulars": [
		"Here's what I need from you: four Saturdays. In a row. No skipping.",
		"Sell at least two different products -- honey and something else. Wax, herbs, whatever.",
		"And hit fifty dollars total. That's not a lot. It's a test.",
		"I need to know you're serious before I give you better shelf placement.",
	],
}

# -- Bubble lines (quick one-liners) -------------------------------------------
const BUBBLE_LINES: Array = [
	"Hey there! Got any honey for me today?",
	"Wildflower honey's been selling like crazy.",
	"Quality matters -- the restaurants pay double for the good stuff.",
	"Spring honey is lighter. Folks love it on toast.",
	"Business has been good this season!",
	"Let me know when you're ready to sell.",
]

# -- Holiday dialogue ----------------------------------------------------------
const HOLIDAY_LINES: Dictionary = {
	"quickening_morn": [
		"No market today -- everybody is at the square eating Rose's biscuits.",
		"Spring is coming. That means Saturday Market starts back up soon.",
		"Get your jars ready. First spring honey always sells fast.",
	],
	"founders_beam": [
		"Founder's Beam! Best sales day of the year.",
		"I doubled the prices. Nobody blinks. They are in a good mood.",
		"If you brought honey, sell it now. You will not see foot traffic like this again.",
		"I added 25% to your per-jar price today. Festival premium. Enjoy it.",
	],
	"reaping_fire": [
		"Market's closed for the fire tonight. But come see me next Saturday.",
		"Fall honey sells well to the candle makers. Dark and strong is what they want.",
		"Save some jars for winter. Prices go up when supply goes down.",
	],
	"long_table": [
		"Market's done for the season. See you in spring.",
		"Merry Long Table. I left a gift under my table for you -- leftover market signage.",
		"You did good this year. Better than most first-timers.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
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
		["People buy honey year-round if you make it easy for them.", "Think about labels, packaging, a brand. Make it look like you mean it."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["Here's a tip: restaurants in the city pay top dollar for single-source honey.", "If you can keep your bees near one kind of flower, that jar is worth three times a mix."],
	["Wax is an overlooked product. Candles, cosmetics, furniture polish.", "Save your cappings when you extract. Melt, strain, sell. Another revenue stream."],
	["The farmers' market is great exposure. Folks love meeting the beekeeper.", "Just make sure your jars are labeled right. Health department checks."],
	["I've been doing this fifteen years. The ones who succeed are the ones who show up.", "Rain or shine. Summer or fall. They show up."],
]

# -- State ---------------------------------------------------------------------
var _seasonal_index: int = 0
var _fallback_index: int = 0
var _talking: bool = false
var _prompt_label: Label = null
var _dialogue_ui: Node = null
var _pending_debrief: String = ""
var _first_visit_done: bool = false

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	add_to_group("frank_fischbach")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Frank"
	_prompt_label.add_theme_font_size_override("font_size", 7)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(120, 12)
	_prompt_label.position = Vector2(-60, -70)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

	if QuestManager:
		QuestManager.quest_completed.connect(_on_quest_completed)

func _on_quest_completed(quest_id: String, _xp: int) -> void:
	if quest_id in ["frank_first_jar", "frank_saturday_regulars"]:
		_pending_debrief = quest_id

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

func interact() -> void:
	if _talking:
		return
	if _dialogue_ui == null:
		_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")
	if _dialogue_ui == null:
		return
	_talking = true

	var lines: Array = _pick_lines()
	_dialogue_ui.show_dialogue("Frank", lines, "frank")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit
	if not _first_visit_done and not PlayerData.has_flag("frank_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("frank_first_visit")
		return FIRST_VISIT_LINES

	# Priority 2: Post-quest debrief
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		return DEBRIEF_LINES[debrief_id]

	# Priority 3: Quest-aware advice
	if QuestManager:
		for quest_id in QUEST_LINES.keys():
			if QuestManager.is_active(quest_id):
				return QUEST_LINES[quest_id]

	# Priority 3.5: Holiday dialogue
	if HolidayManager and HolidayManager.current_holiday_key() != "":
		var hk: String = HolidayManager.current_holiday_key()
		if HOLIDAY_LINES.has(hk):
			return HOLIDAY_LINES[hk]

	# Priority 4: Seasonal rotation
	var season: String = ""
	if TimeManager and TimeManager.has_method("current_season_name"):
		season = TimeManager.current_season_name()
	if SEASONAL_LINES.has(season):
		var pool: Array = SEASONAL_LINES[season]
		if pool.size() > 0:
			_seasonal_index = _seasonal_index % pool.size()
			var lines: Array = pool[_seasonal_index]
			_seasonal_index += 1
			return lines

	# Priority 5: Fallback
	_fallback_index = _fallback_index % FALLBACK_LINES.size()
	var lines: Array = FALLBACK_LINES[_fallback_index]
	_fallback_index += 1
	return lines

func _wait_for_dialogue_close() -> void:
	while _dialogue_ui and _dialogue_ui.has_method("is_open") and _dialogue_ui.is_open():
		await get_tree().create_timer(0.2).timeout
	_talking = false
