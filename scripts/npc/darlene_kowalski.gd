# darlene_kowalski.gd -- Darlene Kowalski NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Darlene Kowalski -- the neighbor beekeeper.
#   Third-generation Cedar Bend beekeeper. Keeps six hives (not because she
#   can't manage more, but because six is enough for high standards).
#   Her grandmother's queen line traces back to Poland 1928.
#   Warm, practical, absolutely no-nonsense.
#
# Year 1 Quests:
#   Q1: Over the Fence -- observation visit, foreshadowing "Telling the Bees"
#   Q2: The Marked Queen -- find and mark the queen
#
# Dialogue priority:
#   1. First visit (starts Over the Fence quest if not active)
#   2. Post-quest debrief (after Over the Fence or Marked Queen)
#   3. Quest-aware briefing (active quest advice)
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue (triggers Over the Fence quest) ---------------------
const FIRST_VISIT_LINES: Array = [
	"So you're the one Bob's been talking about. I'm Darlene.",
	"I keep six hives on the other side of this fence. Have for thirty years.",
	"My grandmother kept bees before that. Her queen stock came from Poland in 1928.",
	"I've been watching you work. You're not terrible.",
	"Come over sometime. I'll show you what a healthy hive looks like.",
	"Not today -- I've got frames to check. But soon.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"darlene_over_the_fence": [
		"You paid attention. That's more than most people manage.",
		"A strong hive hums different than a weak one. You'll learn to hear it.",
		"My grandmother talked to her bees every morning.",
		"She said they knew her voice.",
		"She said when a beekeeper dies, someone has to tell the bees, or they'll leave.",
		"Old Polish superstition. But I still talk to mine.",
		"Now. Your queen -- have you found her yet? Really found her?",
		"When you've spotted her three times on your own, come back. I'll teach you to mark her.",
	],
	"darlene_marked_queen": [
		"Clean mark. Good hands.",
		"A marked queen means you know who she is. You can track her laying, her health.",
		"If she disappears, you'll know it fast instead of losing a month wondering.",
		"My grandmother marked every queen with a prayer. I just use the pen.",
		"You're doing real work now. Not just learning -- doing.",
		"Keep at it. I'll be watching.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"darlene_over_the_fence": [
		"Come on over to my side of the fence when you're ready.",
		"I want to show you one of my hives. Watch how I work.",
		"Pay attention -- I'm going to ask you what you see.",
	],
	"darlene_marked_queen": [
		"You need to spot your queen three times before I'll let you mark her.",
		"Finding a queen isn't luck -- it's pattern recognition. She moves different.",
		"Look for the long abdomen, the way the workers clear a path for her.",
		"When you've found her enough times to know it's skill, not chance, come find me.",
	],
}

# -- Observation visit dialogue (completes Over the Fence) ---------------------
const OBSERVATION_LINES: Array = [
	"Good. You came back. Let me show you something.",
	"See this hive? Listen. Hear that hum? Steady, even, like a motor idling.",
	"That is a healthy hive. No high-pitched whine, no silence. Just work.",
	"Now look at the entrance. Foragers coming in heavy, pollen on their legs.",
	"Workers fanning at the entrance -- that means they have nectar to cure.",
	"You see guard bees checking everyone who lands? That is a colony that knows itself.",
	"A weak hive sounds different. Thinner. Uncertain. You will learn to hear it.",
	"Your hive is not there yet. But it could be. Keep watching. Keep listening.",
]

# -- Queen marking dialogue (completes The Marked Queen) -----------------------
const MARKING_LINES: Array = [
	"Three sightings. Good. That means you know what you are looking for.",
	"Here is the marking pen. International color system -- this year is blue.",
	"Find her. One small dot on the thorax. Steady hands. Do not crush her.",
	"...",
	"Clean mark. She will be easy to find now.",
	"A marked queen means you will know if she is replaced. If she vanishes.",
	"My grandmother marked every queen she ever kept. Said it was a promise.",
	"A promise to pay attention. That is all beekeeping really is.",
]

# -- Holiday dialogue ----------------------------------------------------------
const HOLIDAY_LINES: Dictionary = {
	"quickening_morn": [
		"Quickening Morn. The bees feel it too -- first real cleansing flights.",
		"My grandmother always said the bees celebrate spring before we do.",
		"Bob is carrying the comb today. He has done it every year since Margaret died.",
	],
	"founders_beam": [
		"If Rose thinks her honey pie is beating my grandmother's recipe, she is dreaming.",
		"I have won six times. She has won seven. This is my year.",
		"Go enjoy the market. Frank charges double and somehow people still buy.",
	],
	"reaping_fire": [
		"Reaping Fire tonight. My girls are tucked in with 80 pounds each.",
		"I will be at the bonfire. Lloyd will tell the wrong year for the storm again.",
		"Tomorrow, check your stores. If they are light, feed now. Do not wait.",
	],
	"long_table": [
		"Long Table tonight. I am bringing mead. My grandmother's recipe.",
		"She made it every winter. Said the bees did most of the work.",
		"Stop by if you want. Nobody should be alone on the longest night.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["My girls are building up fast. Dandelion pollen everywhere.", "Check your own entrance -- if the foragers are coming in heavy, your queen is laying well."],
		["I split one of my hives last week. Population was getting too high.", "You're not ready for splits yet. Just keep them fed and give them room."],
	],
	"Summer": [
		["Six hives is plenty when you do it right. Quality over quantity.", "Every jar I sell has my name on it. I don't put my name on something I'm not proud of."],
		["Watch your mite loads. Summer is when they explode.", "I do a wash every two weeks June through August. Not optional."],
	],
	"Fall": [
		["My girls have 80 pounds of stores each. They'll be fine.", "How are yours looking? Sixty is the floor, not the goal."],
		["I'm treating with oxalic this week. Broodless period is the window.", "Time it right and you get 90% kill rate. Time it wrong and you're just annoying them."],
	],
	"Winter": [
		["Nothing to do but wait. And worry. Every beekeeper worries in winter.", "Put your ear to the hive wall. If you hear them humming, they're alive."],
		["My grandmother used to bring warm stones from the fireplace and set them near the hives.", "I don't know if it helped the bees, but it helped her feel like she was doing something."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["Six hives is enough if you do it right. Quality matters more than quantity."],
	["Watch the entrance. The bees will tell you everything if you learn to look.", "Pollen loads, flight patterns, the sound of the hive -- it all means something."],
	["My grandmother said bees can sense a calm heart. I believe her.", "If you're anxious, they know. If you're steady, they settle."],
	["Bob taught me more than he thinks he did. He taught you too.", "The trick is noticing when the lesson is happening."],
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
	add_to_group("darlene_kowalski")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Darlene"
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
	if quest_id == "darlene_over_the_fence" or quest_id == "darlene_marked_queen":
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
	_dialogue_ui.show_dialogue("Darlene", lines, "darlene")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit -- introduce herself, start quest
	if not _first_visit_done and not PlayerData.has_flag("darlene_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("darlene_first_visit")
		# Start the Over the Fence quest if conditions are met
		if QuestManager and not QuestManager.is_complete("darlene_over_the_fence"):
			if not QuestManager.is_active("darlene_over_the_fence"):
				QuestManager.start_quest("darlene_over_the_fence")
		return FIRST_VISIT_LINES

	# Priority 2: Post-quest debrief
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		var lines: Array = DEBRIEF_LINES[debrief_id]
		_unlock_debrief_entries(debrief_id)
		return lines

	# Priority 3: Quest-aware advice (with observation visit completion)
	if QuestManager:
		# Over the Fence: second visit completes the observation
		if QuestManager.is_active("darlene_over_the_fence"):
			if PlayerData.has_flag("darlene_first_visit"):
				# Player already met Darlene -- this is the observation visit
				QuestManager.notify_event("darlene_fence_visit", {})
				return OBSERVATION_LINES
			return QUEST_LINES["darlene_over_the_fence"]
		# Marked Queen: check queen sightings counter
		if QuestManager.is_active("darlene_marked_queen"):
			var sightings: int = QuestManager.get_counter("queen_sightings")
			if sightings >= 3:
				# Player is ready -- complete the marking quest
				QuestManager.notify_event("queen_marked", {})
				return MARKING_LINES
			return QUEST_LINES["darlene_marked_queen"]
		for quest_id in QUEST_LINES.keys():
			if quest_id == "darlene_over_the_fence" or quest_id == "darlene_marked_queen":
				continue
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

func _unlock_debrief_entries(quest_id: String) -> void:
	if KnowledgeLog == null:
		return
	match quest_id:
		"darlene_over_the_fence":
			KnowledgeLog.unlock_entry("healthy_hive")
		"darlene_marked_queen":
			KnowledgeLog.unlock_entry("queen_marking")

func _wait_for_dialogue_close() -> void:
	while _dialogue_ui and _dialogue_ui.has_method("is_open") and _dialogue_ui.is_open():
		await get_tree().create_timer(0.2).timeout
	_talking = false
