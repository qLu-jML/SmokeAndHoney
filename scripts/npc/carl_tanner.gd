# carl_tanner.gd -- Carl Tanner NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Carl Tanner -- the supply line.
#   Third-generation store owner (grandfather opened Tanner's Feed & Supply
#   in 1952 -- one of the first Black-owned businesses in the county).
#   Quiet competence. Remembers everything. Keeps a legendary hand-annotated
#   winter catalog. Manages the bulletin board -- Cedar Bend's unofficial
#   nervous system.
#
# Year 1 Quests:
#   Q1: New Customer -- first visit, discover beekeeping section
#   Q2: The Bulletin Board -- post swarm-removal notice
#
# Dialogue priority:
#   1. First visit (introduces himself, starts New Customer quest)
#   2. Post-quest debrief
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"You must be the one Bob mentioned. Come on in.",
	"I'm Carl. This is Tanner's Feed and Supply. My grandfather opened it in '52.",
	"I already set aside a few things Bob said you'd need. They're in the back.",
	"Beekeeping section is along the east wall. Frames, foundation, treatments, feeders.",
	"If I don't have it, I can order it. Takes about a week from the supplier.",
	"And check the bulletin board by the door. That's how this town talks to itself.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"carl_new_customer": [
		"Good to have you as a regular.",
		"Bob's been coming in here since before I took over. He's a good man.",
		"When he was in the hospital last winter, I delivered feed to his place every week.",
		"Never collected the tab. Don't intend to.",
		"You need anything for those bees, you come to me first. I'll treat you right.",
	],
	"carl_bulletin_board": [
		"Posted. That'll get some calls when swarm season hits.",
		"The board is how things happen around here. Jobs, sales, lost dogs, swarm calls.",
		"Check it when you come in. Something new goes up every week.",
		"And if you hear about somebody needing help with bees, you'll be the one they call.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"carl_new_customer": [
		"Take a look around. Beekeeping supplies are on the east wall.",
		"I've got frames, foundation, smoker fuel, treatments -- the basics.",
		"Bob told me what you'd need for your first season. I've got it ready.",
	],
	"carl_bulletin_board": [
		"The bulletin board is right by the front door.",
		"Write up a notice: swarm removal, your name, how to reach you.",
		"When spring swarms fly, people want them gone fast. You'll get calls.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["Spring rush is on. Every farmer in the county needs something.", "I ordered extra bee packages this year. Should be in by mid-month."],
		["You see what they're charging at Casey's? Three dollars more than last week.", "Anyway. You need supplies, now's the time. Prices go up when everyone's buying."],
	],
	"Summer": [
		["Slow week at the store. Everyone's out working instead of shopping.", "Good time to stock up on frames. I've got a surplus from a canceled order."],
		["Hot enough for you? I've been keeping the back door open all day.", "Your bees are probably drinking a gallon of water a day in this heat."],
	],
	"Fall": [
		["Fall is when the smart beekeepers come in. Sugar, treatments, mouse guards.", "The ones who wait until November are the ones who lose hives."],
		["I'm putting together my winter catalog. Hand-annotated, same as my dad did it.", "If you want anything special ordered for spring, let me know before December."],
	],
	"Winter": [
		["Quiet season. Good time to fix equipment and plan ahead.", "I've got woodenware on clearance if you want to build up your stock."],
		["Bob came by yesterday. Looking thin but he won't say anything about it.", "I just put his usual order together and don't ask questions. That's how he wants it."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["My grandfather opened this store in 1952. One of the first Black-owned businesses in the county.", "Folks were skeptical at first. Then they realized he had the best prices and the best memory."],
	["I remember every order. Every farmer, every season. It's not a trick -- I just pay attention."],
	["The bulletin board is Cedar Bend's real newspaper. Everything important ends up there."],
	["Bob's a good customer. Good man. We don't talk much but we understand each other."],
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
	add_to_group("carl_tanner")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Carl"
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
	if quest_id in ["carl_new_customer", "carl_bulletin_board"]:
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
	_dialogue_ui.show_dialogue("Carl", lines, "carl")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit
	if not _first_visit_done and not PlayerData.has_flag("carl_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("carl_first_visit")
		# Fire the completion event for carl_new_customer
		if QuestManager and QuestManager.is_active("carl_new_customer"):
			QuestManager.notify_event("carl_first_visit", {})
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
