# rose_delacroix.gd -- Rose Delacroix NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Rose Delacroix -- the heart of Cedar Bend.
#   Born here, went to culinary school in North Carolina, came back voluntarily.
#   Runs Crossroads Diner 6 AM - 9 PM, six days a week. Closed Sundays.
#   The social switchboard. Knows whose marriage is struggling before they do.
#   Actions over words. Intuitive, knowing without stating.
#
#   Puts a plate in front of you without asking what you want.
#   That is how Cedar Bend says you belong.
#
# Year 1 Quests:
#   Q1: Honey in the Coffee -- bring honey, Rose tastes for kitchen use
#
# Dialogue priority:
#   1. First visit (plate-without-asking moment)
#   2. Post-quest debrief (after honey tasting)
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"Sit down. I'll bring you something.",
	"...",
	"Here. Eat.",
	"I'm Rose. This is the Crossroads. I've been here longer than the furniture.",
	"Bob told me you were coming to town. Said you'd probably forget to eat.",
	"He was right. You look like you forgot to eat.",
	"Diner's open six days. Closed Sundays. Even the Lord rested.",
	"You come in whenever you need to. There's always a plate.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"rose_honey_in_coffee": [
		"Let me taste that.",
		"...",
		"That's good honey. Light. Clean. Dandelion, mostly, with a little clover underneath.",
		"I could use this in the kitchen. Drizzle on the biscuits, sweeten the iced tea.",
		"Tell you what -- you bring me a jar every couple weeks, I'll put it on the tables.",
		"People will ask where it came from. That's better advertising than any sign.",
		"Now finish your coffee. It's getting cold.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"rose_honey_in_coffee": [
		"Bob says you've got honey now. Bring me a jar.",
		"I want to taste it before I put it in front of my customers.",
		"I don't serve anything I haven't tried myself. That's just how it is.",
	],
}

# -- Holiday dialogue ----------------------------------------------------------
const HOLIDAY_LINES: Dictionary = {
	"quickening_morn": [
		"Quickening Morn. I have been cooking since 4 AM.",
		"Sit down. Eat. You are too thin for a beekeeper.",
		"Bob brought the comb. Golden as anything. That man never misses.",
	],
	"founders_beam": [
		"My honey pie is going to win this year. Do not argue with me.",
		"Darlene's sour cream raisin is good. Mine is better. The judges know.",
		"If you brought good honey, I used it. If my pie wins, you get credit.",
	],
	"reaping_fire": [
		"I made corn chowder for fifty. Grab a bowl before Lloyd eats it all.",
		"The fire is something. Every year I think it cannot be bigger. Every year it is.",
		"Check on Bob after tonight. He gets quiet this time of year.",
	],
	"long_table": [
		"Long Table tonight. I brought pie. Enough for an army.",
		"Nobody eats alone on the longest night. That is the rule.",
		"You two count as an army. Eat.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["First dandelions are up. I made dandelion jelly last week.", "Your bees are probably all over my garden right now. I don't mind."],
		["Bob came in for breakfast this morning. Same order as always.", "Two eggs, toast, black coffee. He didn't finish the toast. I noticed."],
	],
	"Summer": [
		["Saturday Market brings half the county into town. Good for business.", "I've been making honey butter with that jar you brought. People love it."],
		["It's pie season. Strawberry-rhubarb this week.", "You look like you could use a slice. Sit down."],
	],
	"Fall": [
		["Apple pie starts in October. I get my apples from Henderson's orchard.", "If you've got any late-season honey, I'll take it. The darker stuff is perfect for baking."],
		["Harvest bonfire is coming up. I'm making corn chowder for fifty.", "This town eats together. That's how we know we're still here."],
	],
	"Winter": [
		["Slow days. Soup weather. I make the stock from scratch.", "Come in out of the cold whenever you need to. Coffee's always on."],
		["The Long Table is coming up. Longest night of the year.", "I cook for anyone who walks in alone. Nobody should eat by themselves on that night."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["I went to culinary school in North Carolina. Came back on purpose.", "People asked why. I said because this is where the food matters."],
	["You look tired. Eat something. That's not a suggestion."],
	["I see everyone who comes through that door. I know more than I say.", "That's not gossip. That's paying attention."],
	["Bob used to come in every morning at 6:15. Now it's closer to 7.", "I don't say anything about it. But I notice."],
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
	add_to_group("rose_delacroix")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Rose"
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
	if quest_id == "rose_honey_in_coffee":
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
	_dialogue_ui.show_dialogue("Rose", lines, "rose")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit -- the plate-without-asking moment
	if not _first_visit_done and not PlayerData.has_flag("rose_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("rose_first_visit")
		return FIRST_VISIT_LINES

	# Priority 2: Post-quest debrief
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		return DEBRIEF_LINES[debrief_id]

	# Priority 3: Quest-aware advice (with honey delivery check)
	if QuestManager and QuestManager.is_active("rose_honey_in_coffee"):
		# Check if player has honey to offer
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("item_count"):
			var honey_count: int = player.item_count(GameData.ITEM_HONEY_JAR)
			if honey_count > 0:
				# Player has honey -- deliver it and complete the quest
				player.consume_item(GameData.ITEM_HONEY_JAR, 1)
				QuestManager.notify_event("rose_honey_tasted", {})
				return DEBRIEF_LINES["rose_honey_in_coffee"]
		# Player has no honey yet -- give the quest hint
		return QUEST_LINES["rose_honey_in_coffee"]
	if QuestManager:
		for quest_id in QUEST_LINES.keys():
			if quest_id == "rose_honey_in_coffee":
				continue  # Handled above
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
