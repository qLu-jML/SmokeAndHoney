# june_wellman.gd -- June Wellman NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: June Wellman -- the keeper.
#   Late 20s, took over post office two years ago from grandmother Mae.
#   Knows every address in the county by heart (from childhood in back room).
#   Quiet, observant, unexpectedly dry-humored. Youngest adult NPC.
#   Quietly the archivist of Cedar Bend's important moments.
#   Holds Bob's letter (delivered Year 3).
#
# Year 1 Quests:
#   Q1: The Buzzing Box -- collect bee package from post office
#
# Dialogue priority:
#   1. First visit (introduces herself)
#   2. Post-quest debrief (after bee package pickup)
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"Hi. I'm June. I run the post office.",
	"Well -- my grandmother ran it for forty years. I took over when she retired.",
	"I know every address in Millhaven County. Grew up in the back room sorting mail.",
	"You're at Bob's place, right? Rural Route 3, Box 12.",
	"I'll hold packages for you if you're not home. Just come by before 5.",
	"And if you ever need to order bees by mail -- yes, that's a real thing -- I'm your person.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"june_buzzing_box": [
		"Here's your package. It's been humming all morning.",
		"I kept it behind the counter where it's cool. They don't like heat.",
		"The mail carrier was... not thrilled. But he's delivered worse.",
		"My grandmother used to get bee packages too. She'd hold them up to her ear and listen.",
		"Said you could tell if the queen was alive by the sound the workers made.",
		"Calm hum means she's in there. Angry buzz means trouble.",
		"Yours sound calm. Good luck with them.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"june_buzzing_box": [
		"Your bee package came in this morning. Three pounds of bees and a queen.",
		"I've got it behind the counter. Come pick it up when you're ready.",
		"Don't leave them too long -- they need to get into a hive.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["Spring is busy. Seed catalogs, equipment orders, bee packages.", "Half the county orders through me. The other half drives to Albion."],
		["Bob's mail has been lighter lately. He used to subscribe to three bee journals.", "Now it's just the Albion paper and the occasional letter."],
	],
	"Summer": [
		["Summer is slow for mail. Everyone's outside working.", "I use the quiet time to organize the back. Grandmother left forty years of records."],
		["Got a package for you. Just kidding. But you should see your face.", "Sorry. Post office humor. It's a niche market."],
	],
	"Fall": [
		["Fall orders are picking up. Everyone stocking supplies before winter.", "If you need to order anything for the bees, do it now. Shipping slows down in November."],
		["I found an old letter in the back room. Postmarked 1971, never delivered.", "Return address is a farm that hasn't existed in thirty years. I'm keeping it."],
	],
	"Winter": [
		["Quiet days. I've been reading through grandmother's old logbooks.", "She wrote down every package, every letter, every postcard for forty years."],
		["Holiday cards are coming in. I can tell who's doing well by the return addresses.", "Some people move away and keep writing. Some stop. I notice both."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["My grandmother knew everyone's business because she handled their mail.", "I know everyone's business because I grew up listening. Different skill, same result."],
	["I'm the youngest person who works on Main Street. By about twenty years.", "That's fine. I like it here. The quiet suits me."],
	["If you ever need to send something, I've got boxes and tape behind the counter.", "And stamps. People forget stamps exist. They do. I sell them."],
	["Bob comes in every Tuesday. Picks up his paper, says three words, leaves.", "Those three words change every week. That's how I know he's okay."],
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
	add_to_group("june_wellman")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to June"
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
	if quest_id == "june_buzzing_box":
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
	_dialogue_ui.show_dialogue("June", lines, "june")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit
	if not _first_visit_done and not PlayerData.has_flag("june_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("june_first_visit")
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
