# ellen_harwick.gd -- Dr. Ellen Harwick NPC
# -----------------------------------------------------------------------------
# GDD S9 / Story Bible: Dr. Ellen Harwick -- the scientist.
#   PhD entomology from University of Iowa. Early 40s. Moved to Cedar Bend
#   five years ago from Iowa City, still called "the new girl" by Lloyd.
#   Data and citations. Occasionally forgets not everyone finds varroa
#   reproductive cycles fascinating. Never sugarcoats bad news.
#
# Year 1 Quests (milestone-triggered by hive count):
#   M1: The First Hive -- visit extension office, learn smoker science
#   M2: Colony Dynamics -- inspect 2 hives same session, compare for Ellen
#   M3: Health Monitoring -- alcohol wash all hives, report data
#
# Dialogue priority:
#   1. First visit (introduces herself, starts First Hive quest)
#   2. Post-quest debrief
#   3. Quest-aware briefing
#   4. Seasonal rotation
#   5. Fallback lines (original DIALOGUE_LINES content)
# -----------------------------------------------------------------------------
extends Node2D

const INTERACT_RADIUS := 40.0

# -- First visit dialogue ------------------------------------------------------
const FIRST_VISIT_LINES: Array = [
	"Oh good -- you're the new beekeeper. Bob mentioned you. I'm Dr. Harwick.",
	"Ellen. Please. I handle livestock health for the county extension office.",
	"Bees included. Especially bees, honestly. They're what got me into this field.",
	"PhD from Iowa. Entomology. We just don't put corn on everything, despite the rumors.",
	"I wanted to talk to you about your smoker. Most new beekeepers don't understand the science.",
	"Smoke doesn't calm the bees. It triggers a gorging response -- they think there's a fire.",
	"They fill up on honey in case they need to abandon the hive. Full bees are docile bees.",
	"The effect lasts about 20 minutes. After that, they get defensive again.",
	"Come see me anytime. I can inspect your hives, run diagnostics, teach you what to look for.",
]

# -- Post-quest debrief lines -------------------------------------------------
const DEBRIEF_LINES: Dictionary = {
	"ellen_first_hive": [
		"Good. Now you know why smoke works, not just that it works.",
		"That distinction matters. Beekeeping without understanding is just luck.",
		"I'll be keeping an eye on your operation. Professionally, I mean.",
		"When you have a second hive, come see me. I want you to learn to compare colonies.",
		"Two hives teach you more than one ever could.",
	],
	"ellen_colony_dynamics": [
		"Interesting. You noticed the differences.",
		"Growth rate, temperament, foraging intensity -- every colony has a personality.",
		"That's genetics and environment interacting. It's fascinating.",
		"Sorry. I forget not everyone finds this as exciting as I do.",
		"The practical point: comparing colonies helps you spot problems early.",
		"A colony that's behind its neighbor might have a failing queen or a disease issue.",
		"Now -- when you have three hives, I want baseline mite data on all of them.",
	],
	"ellen_health_monitoring": [
		"This is exactly the kind of data I need. Thank you.",
		"Mite loads vary between colonies even in the same apiary. That's normal.",
		"What matters is the trend. Up is bad. Stable is okay. Down means your treatments work.",
		"I had a beekeeper in 2003 -- 40 hives, all dead by November. All AFB.",
		"She didn't test. Didn't monitor. Just assumed they were fine.",
		"I don't tell that story to scare you. I tell it because monitoring saved every hive since.",
		"Keep testing. Keep recording. The data protects you.",
	],
}

# -- Quest-aware briefing lines -----------------------------------------------
const QUEST_LINES: Dictionary = {
	"ellen_first_hive": [
		"Come by the extension office when you have a minute.",
		"I want to talk about smoker science and basic hive health indicators.",
		"It won't take long. But it will change how you think about your bees.",
	],
	"ellen_colony_dynamics": [
		"You have two hives now. Perfect for comparison.",
		"Inspect both in the same day. Note the differences in population, temperament, stores.",
		"Then come tell me what you found. I want to hear it in your words.",
	],
	"ellen_health_monitoring": [
		"Time for baseline data. Do an alcohol wash on every hive you own.",
		"Record whether each colony is above or below 3 mites per 100 bees.",
		"Bring me the numbers. I'll help you interpret them.",
	],
}

# -- Colony comparison report (completes Colony Dynamics) ----------------------
const COMPARISON_REPORT_LINES: Array = [
	"You inspected both colonies in one session. Good. Tell me what you saw.",
	"Different growth rates? Different temperaments? That is genetics at work.",
	"Every colony is an individual. Comparing them is how you learn to read bees.",
	"This is real data now. Not theory. Your eyes, your hives, your observations.",
	"I am going to write this up for the county extension report. You did well.",
]

# -- Health report (completes Health Monitoring) -------------------------------
const HEALTH_REPORT_LINES: Array = [
	"Let me see those numbers. Alcohol wash results, all hives.",
	"Good. You tested every colony. That is the discipline that keeps bees alive.",
	"Some beekeepers skip the wash because they do not want to kill 300 bees.",
	"I understand the feeling. But 300 bees to save 30,000 is not a hard calculation.",
	"Your data gives us a baseline. If mite loads rise, we will know.",
	"I will enter these into the county database. Keep testing monthly.",
]

# -- Bubble lines (quick one-liners) -------------------------------------------
const BUBBLE_LINES: Array = [
	"Good to see you taking care of your bees!",
	"Have you done a mite check this month?",
	"Healthy bees start with a healthy queen.",
	"Watch for deformed wings -- that's a varroa sign.",
	"I can inspect your hives anytime, just ask.",
	"Prevention is always cheaper than treatment.",
	"A sugar roll test only takes five minutes.",
]

# -- Seasonal dialogue pools ---------------------------------------------------
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
		["Nothing to treat in winter. The cluster needs to stay undisturbed.", "Check the bottom board for debris. Lots of cappings means they're eating. That's good."],
		["I've been reviewing last year's county mite data. The average load is trending up.", "We need more beekeepers testing regularly. You're one of the good ones."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["Varroa destructor is the number one threat to honey bees worldwide.", "They feed on fat bodies, not hemolymph like we used to think. That shortens lifespans."],
	["American Foulbrood is the one you never want to see. Ropy, brown larval remains.", "If you suspect AFB, don't move any equipment. Come get me immediately."],
	["Small hive beetles love warm, humid conditions. Keep your colonies strong.", "A strong population is your best defense against beetles."],
	["I went into entomology because of a bee sting when I was six.", "Most people develop a fear. I developed a fascination. Same stimulus, different response."],
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
	add_to_group("ellen_harwick")
	add_to_group("npc")

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Dr. Harwick"
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
	if quest_id in ["ellen_first_hive", "ellen_colony_dynamics", "ellen_health_monitoring"]:
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
	_dialogue_ui.show_dialogue("Dr. Harwick", lines, "ellen")

	if GameData:
		GameData.add_xp(5)

	_wait_for_dialogue_close()

func _pick_lines() -> Array:
	# Priority 1: First visit
	if not _first_visit_done and not PlayerData.has_flag("ellen_first_visit"):
		_first_visit_done = true
		PlayerData.set_flag("ellen_first_visit")
		# Fire the completion event for ellen_first_hive if active
		if QuestManager and QuestManager.is_active("ellen_first_hive"):
			QuestManager.notify_event("ellen_first_visit", {})
		return FIRST_VISIT_LINES

	# Priority 2: Post-quest debrief
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		_unlock_debrief_entries(debrief_id)
		return DEBRIEF_LINES[debrief_id]

	# Priority 3: Quest-aware advice (with completion checks)
	if QuestManager:
		# Colony Dynamics: complete if player inspected 2+ hives today
		if QuestManager.is_active("ellen_colony_dynamics"):
			if PlayerData.has_flag("ellen_colony_comparison_ready"):
				PlayerData.clear_flag("ellen_colony_comparison_ready")
				QuestManager.notify_event("ellen_colony_comparison", {})
				return COMPARISON_REPORT_LINES
			return QUEST_LINES["ellen_colony_dynamics"]
		# Health Monitoring: complete if all hives have been washed
		if QuestManager.is_active("ellen_health_monitoring"):
			if PlayerData.has_flag("ellen_health_report_ready"):
				PlayerData.clear_flag("ellen_health_report_ready")
				QuestManager.notify_event("ellen_health_report", {})
				return HEALTH_REPORT_LINES
			return QUEST_LINES["ellen_health_monitoring"]
		for quest_id in QUEST_LINES.keys():
			if quest_id == "ellen_colony_dynamics" or quest_id == "ellen_health_monitoring":
				continue
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
		"ellen_first_hive":
			KnowledgeLog.unlock_entry("science_of_smoke")
		"ellen_colony_dynamics":
			KnowledgeLog.unlock_entry("colony_dynamics")
		"ellen_health_monitoring":
			KnowledgeLog.unlock_entry("varroa_monitoring")

func _wait_for_dialogue_close() -> void:
	while _dialogue_ui and _dialogue_ui.has_method("is_open") and _dialogue_ui.is_open():
		await get_tree().create_timer(0.2).timeout
	_talking = false
