# silas_crenshaw.gd -- Silas Crenshaw NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Silas Crenshaw -- the builder.
#   Semi-retired carpenter, built half the barns in Millhaven County.
#   Runs workshop behind hardware store. Built the original Honey House.
#   Quiet, precise, opinionated about lumber quality.
#   Builds without asking, never acknowledges -- Midwestern love spoken
#   in the language of shared craft.
#
# Year 1 Quests:
#   Q1: The Old Honey House -- examine ruin, visit Silas, get materials list
#   Q2: Gathering Materials -- collect lumber, nails, felt, $150
#   Q3: Raising the Roof -- assist final construction day (3 tasks)
#
# Dialogue priority:
#   1. First visit (introduces himself, starts Honey House quest)
#   2. Post-quest debrief
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"You must be Bob's kid. He said you'd come around eventually.",
	"I'm Silas. I build things. Fix things. Mostly fix things these days.",
	"I built that Honey House on your property -- oh, twenty-five years ago now.",
	"Bob wanted a proper extraction room. Concrete floor, screened windows, the works.",
	"Heard it's seen better days. That happens when nobody uses a building for a while.",
	"Go take a look at it. Then come back and tell me how bad it is.",
	"I've got lumber that needs a purpose.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"silas_old_honey_house": [
		"That bad, huh.",
		"Roof's gone. Door's hanging. Floor's cracked but the foundation is good.",
		"I can fix it. Won't be cheap, but I can fix it.",
		"Here's what I need from you: 20 boards of lumber, 5 pounds of nails, 2 rolls of roofing felt.",
		"And $150 for my time. I'd do it for free but my knees charge rent these days.",
		"Get the materials together and bring them to the site. I'll handle the rest.",
	],
	"silas_gathering_materials": [
		"Good lumber. You didn't cheap out. I respect that.",
		"Give me a week. I'll get the framing up and the roof on.",
		"Come back when I send word. I'll need an extra pair of hands for the last day.",
	],
	"silas_raising_the_roof": [
		"She's solid again. Better than she was, if I'm honest.",
		"New roof, new door, patched floor. The bones were always good.",
		"Here's the key. It's yours now.",
		"Bob would be glad to see it working again. He spent a lot of hours in there.",
		"You need anything else built, you know where to find me.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"silas_old_honey_house": [
		"Go look at that old Honey House on your property.",
		"The one behind the shed, past the garden. Can't miss it.",
		"Tell me what you see. I need to know how much work we're talking about.",
	],
	"silas_gathering_materials": [
		"You got my list? 20 boards, 5 lbs nails, 2 rolls felt, $150.",
		"Carl stocks most of it at Tanner's. Tell him it's for me -- he'll set you right.",
		"Don't buy cheap lumber. I won't put cheap lumber on a building I built.",
	],
	"silas_raising_the_roof": [
		"Today's the day. I need you at the Honey House.",
		"Three jobs: hold the ridge beam while I nail it, hand up the felt, help hang the door.",
		"Should take a couple hours. Bring work gloves.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["Good building weather. Dry air, not too hot.", "If you need any frames built, I can show you how. Cheaper than buying."],
		["I put a new bench up at Bob's apiary. Don't tell him I did it.", "He'll sit on it and pretend it was always there. That's how we do things."],
	],
	"Summer": [
		["Too hot to be inside a workshop. But the work doesn't care about the heat.", "How's that Honey House treating you? Roof holding up?"],
		["I've been meaning to fix the screen on the diner's back door. Rose won't ask.", "That's how it works here. You see something that needs fixing, you fix it."],
	],
	"Fall": [
		["Good time to check your buildings before winter. Loose boards, drafty doors.", "A cold draft in the wrong place can kill a hive. Make sure your equipment is tight."],
		["I'm building storm shutters for the Grange Hall. Volunteer work.", "This town runs on people doing things without being asked."],
	],
	"Winter": [
		["Winter is when I plan next year's projects. Sharpen tools. Oil the bench.", "A good carpenter is always getting ready for the next job."],
		["If you need anything repaired before spring, bring it by. I'm not busy.", "Well, I'm always busy. But I've got time for the right work."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["A building is only as good as its foundation. Same goes for most things."],
	["I built that barn on Peterson's road in 1987. Still standing.", "Good lumber and honest nails. That's the whole secret."],
	["Bob and I go way back. He helped me frame my workshop.", "I helped him build the original Honey House. That's how it works."],
	["You need something built, you come to me. I don't do fast, but I do right."],
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
	add_to_group("silas_crenshaw")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Silas"
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
	if quest_id in ["silas_old_honey_house", "silas_gathering_materials", "silas_raising_the_roof"]:
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
	_dialogue_ui.show_dialogue("Silas", lines, "silas")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit
	if not _first_visit_done and not PlayerData.has_flag("silas_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("silas_first_visit")
		if QuestManager and not QuestManager.is_complete("silas_old_honey_house"):
			if not QuestManager.is_active("silas_old_honey_house"):
				QuestManager.start_quest("silas_old_honey_house")
		# If player already examined the ruin, complete the assessment quest
		if PlayerData.has_flag("honey_house_examined") and QuestManager.is_active("silas_old_honey_house"):
			QuestManager.notify_event("silas_honey_house_assessed", {})
		return FIRST_VISIT_LINES

	# Priority 2: Post-quest debrief
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		var lines: Array = DEBRIEF_LINES[debrief_id]
		_unlock_debrief_entries(debrief_id)
		return lines

	# Priority 3: Quest-aware advice
	if QuestManager:
		# Special: if player visits Silas while honey_house quest is active AND ruin examined
		if QuestManager.is_active("silas_old_honey_house") and PlayerData.has_flag("honey_house_examined"):
			QuestManager.notify_event("silas_honey_house_assessed", {})
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

func _unlock_debrief_entries(quest_id: String) -> void:
	if KnowledgeLog == null:
		return
	match quest_id:
		"silas_old_honey_house":
			KnowledgeLog.unlock_entry("honey_house_history")
		"silas_raising_the_roof":
			KnowledgeLog.unlock_entry("honey_house_restored")

func _wait_for_dialogue_close() -> void:
	while _dialogue_ui and _dialogue_ui.has_method("is_open") and _dialogue_ui.is_open():
		await get_tree().create_timer(0.2).timeout
	_talking = false
