# QuestManager.gd -- Tracks active and completed quests, fires quest events.
# Autoloaded as "QuestManager" in project.godot.
# Phase 6 will add actual quest definitions and checking logic.
extends Node

# -- Signals -------------------------------------------------------------------
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, xp_reward: int)
signal quest_failed(quest_id: String)
@warning_ignore("UNUSED_SIGNAL")
signal challenge_event_fired(event_id: String)  # Phase 6: challenge quest triggers

# -- Quest States --------------------------------------------------------------
enum QuestState { INACTIVE, ACTIVE, COMPLETE, FAILED }

# -- State ---------------------------------------------------------------------
var active_quests: Dictionary = {}     # quest_id -> QuestState
# Dictionary used as a hash-set for O(1) .has() -- Array.has() is O(n).
var completed_quests: Dictionary = {}  # quest_id -> true
var quest_notes: Dictionary = {}       # quest_id -> player note string
var quest_data: Dictionary = {}        # quest_id -> quest definition dict
var daily_tasks: Array = []            # daily quests that reset each day
var last_daily_reset_day: int = -1     # track when daily quests were last reset

# -- Public API ----------------------------------------------------------------

func _ready() -> void:
	# Initialize quest definitions
	_init_quest_definitions()
	# Initialize daily tasks
	_reset_daily_quests_if_needed()

func start_quest(quest_id: String) -> void:
	if active_quests.has(quest_id) and active_quests[quest_id] == QuestState.ACTIVE:
		return  # already running
	if completed_quests.has(quest_id):
		return  # already done
	active_quests[quest_id] = QuestState.ACTIVE
	quest_started.emit(quest_id)
	print("? Quest started: %s" % quest_id)

func complete_quest(quest_id: String, xp_reward: int = 0) -> void:
	active_quests[quest_id] = QuestState.COMPLETE
	completed_quests[quest_id] = true   # O(1) insert; duplicate writes are harmless
	if xp_reward > 0:
		GameData.add_xp(xp_reward)
	quest_completed.emit(quest_id, xp_reward)
	print("? Quest complete: %s (+%d XP)" % [quest_id, xp_reward])

func fail_quest(quest_id: String) -> void:
	active_quests[quest_id] = QuestState.FAILED
	quest_failed.emit(quest_id)
	print("? Quest failed: %s" % quest_id)

func is_active(quest_id: String) -> bool:
	return active_quests.get(quest_id, QuestState.INACTIVE) == QuestState.ACTIVE

func is_complete(quest_id: String) -> bool:
	return completed_quests.has(quest_id)   # O(1) hash lookup

func get_active_hint() -> String:
	# Returns a one-line hint string for the HUD.
	# Phase 6 will use proper quest definitions with hint text.
	if active_quests.is_empty():
		return ""
	for quest_id in active_quests:
		if active_quests[quest_id] == QuestState.ACTIVE:
			return "Quest: " + quest_id.replace("_", " ").capitalize()
	return ""

func complete_objective(quest_id: String, obj_key: String, amount: int = 1) -> void:
	if not active_quests.has(quest_id):
		return
	if not quest_data.has(quest_id):
		return
	var qd: Dictionary = quest_data[quest_id]
	if not "objectives" in qd:
		return
	for obj in qd.objectives:
		if obj.key == obj_key:
			obj.current = mini(obj.current + amount, obj.target)
			if obj.current >= obj.target and not completed_quests.has(quest_id):
				# Quest auto-complete when all objectives done
				var rewards = qd.get("rewards", {})
				var xp: int = int(rewards.get("xp", 0))
				complete_quest(quest_id, xp)
			break

func is_quest_active(quest_id: String) -> bool:
	return is_active(quest_id)

func is_quest_complete(quest_id: String) -> bool:
	return is_complete(quest_id)

# -- Quest Definitions -------------------------------------------------------

func _init_quest_definitions() -> void:
	# Intro quest: Meet Uncle Bob
	quest_data["bob_intro"] = {
		"id": "bob_intro",
		"title": "Meet Uncle Bob",
		"description": "Walk up to Uncle Bob and press E to meet him.",
		"objectives": [
			{"key": "bob_talked", "label": "Talk to Uncle Bob", "current": 0, "target": 1}
		],
		"rewards": {"xp": 25, "money": 0, "items": []}
	}

	# Daily quest 1: Inspect your hives
	quest_data["daily_inspection"] = {
		"id": "daily_inspection",
		"title": "Inspect Your Hives",
		"description": "Inspect at least 1 hive today.",
		"objectives": [
			{"key": "inspections_done", "label": "Hives inspected", "current": 0, "target": 1}
		],
		"rewards": {"xp": 10, "money": 5, "items": []}
	}

	# Daily quest 2: Harvest a full super
	quest_data["daily_harvest"] = {
		"id": "daily_harvest",
		"title": "Harvest a Full Super",
		"description": "Remove 1 full super from a hive today.",
		"objectives": [
			{"key": "supers_harvested", "label": "Supers removed", "current": 0, "target": 1}
		],
		"rewards": {"xp": 15, "money": 10, "items": []}
	}

	# Daily quest 3: Sell at Saturday market
	quest_data["daily_market"] = {
		"id": "daily_market",
		"title": "Sell at Saturday Market",
		"description": "Make a honey sale at the Saturday Market.",
		"objectives": [
			{"key": "market_sales", "label": "Sales completed", "current": 0, "target": 1}
		],
		"rewards": {"xp": 20, "money": 0, "items": []}
	}

func _reset_daily_quests_if_needed() -> void:
	var current_day: int = TimeManager.current_day if TimeManager else 0
	if current_day != last_daily_reset_day:
		_reset_daily_quests()
		last_daily_reset_day = current_day

func _reset_daily_quests() -> void:
	# Reset daily quest progress
	daily_tasks = ["daily_inspection", "daily_harvest", "daily_market"]

	# Mark any active dailies as inactive and reset objectives
	for qid in daily_tasks:
		if active_quests.has(qid):
			active_quests.erase(qid)
		if quest_data.has(qid):
			# Reset all objectives to 0
			var qd: Dictionary = quest_data[qid]
			if "objectives" in qd:
				for obj in qd.objectives:
					obj.current = 0

	# Auto-start all daily quests
	for qid in daily_tasks:
		start_quest(qid)
