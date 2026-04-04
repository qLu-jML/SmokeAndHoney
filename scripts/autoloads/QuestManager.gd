# QuestManager.gd -- Tracks active and completed quests, fires quest events.
# Autoloaded as "QuestManager" in project.godot.
#
# Game systems report actions via notify_event(event_id, data).
# The manager checks if any active quest completes on that event,
# awards XP, and auto-starts the next quest in chain.
extends Node

# -- Signals -------------------------------------------------------------------
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, xp_reward: int)
signal quest_failed(quest_id: String)
signal quest_hint_changed(hint_text: String)
@warning_ignore("UNUSED_SIGNAL")
signal challenge_event_fired(event_id: String)

# -- Quest States --------------------------------------------------------------
enum QuestState { INACTIVE, ACTIVE, COMPLETE, FAILED }

# -- State ---------------------------------------------------------------------
var active_quests: Dictionary = {}     # quest_id -> QuestState
var completed_quests: Dictionary = {}  # quest_id -> true  (O(1) hash-set)
var quest_notes: Dictionary = {}       # quest_id -> player note string
var quest_data: Dictionary = {}        # quest_id -> quest definition dict
var daily_tasks: Array[String] = []    # daily quests that reset each day
var last_daily_reset_day: int = -1     # track when daily quests were last reset

# Tracks the last alcohol wash result for "battening_down" quest check.
var last_wash_mites_per_100: float = -1.0

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_init_quest_definitions()
	_init_year1_chain_quests()
	_reset_daily_quests_if_needed()
	TimeManager.day_advanced.connect(_on_day_advanced)
	# Auto-start Year 1 chain on day 1 if nothing is active yet.
	call_deferred("_try_auto_start_first_quest")

func _try_auto_start_first_quest() -> void:
	if completed_quests.is_empty() and not is_active("first_light"):
		start_quest("first_light")

# -- Public API: Event Bus -----------------------------------------------------

## Game systems call this to report an action.  The manager checks if any
## active quest completes on this event.
##
## Common event_ids:
##   "inspection_opened"  -- player opened InspectionOverlay
##   "feeder_placed"      -- player placed feeder bucket with syrup
##   "super_added"        -- player added a honey super
##   "harvest_complete"   -- player completed a harvest
##   "winter_ready"       -- checked by day_advanced (compound condition)
##   "treatment_applied"  -- player applied mite treatment
##   "wash_complete"      -- player completed an alcohol wash
func notify_event(event_id: String, data: Dictionary = {}) -> void:
	if event_id == "wash_complete":
		last_wash_mites_per_100 = data.get("mites_per_100", -1.0)
	_process_chain_event(event_id, data)

# -- Public API: Quest Management ----------------------------------------------

func start_quest(quest_id: String) -> void:
	if active_quests.has(quest_id) and active_quests[quest_id] == QuestState.ACTIVE:
		return
	if completed_quests.has(quest_id):
		return
	# Check chain quest start conditions (month gating)
	if QuestDefs.QUESTS.has(quest_id):
		if not QuestDefs.check_start_conditions(quest_id):
			active_quests[quest_id] = QuestState.INACTIVE
			return
	active_quests[quest_id] = QuestState.ACTIVE
	quest_started.emit(quest_id)
	var title: String = _get_quest_title(quest_id)
	NotificationManager.notify("Quest: " + title, NotificationManager.T_INFO)
	quest_hint_changed.emit(get_active_hint())
	print("Quest started: %s" % quest_id)

func complete_quest(quest_id: String, xp_reward: int = 0) -> void:
	active_quests[quest_id] = QuestState.COMPLETE
	completed_quests[quest_id] = true
	if xp_reward > 0:
		GameData.add_xp(xp_reward)
	quest_completed.emit(quest_id, xp_reward)
	var title: String = _get_quest_title(quest_id)
	NotificationManager.notify("Quest complete: " + title + " (+" + str(xp_reward) + " XP)", NotificationManager.T_XP)
	print("Quest complete: %s (+%d XP)" % [quest_id, xp_reward])
	# Auto-start next quest in Year 1 chain
	_start_next_in_chain(quest_id)
	quest_hint_changed.emit(get_active_hint())

func fail_quest(quest_id: String) -> void:
	active_quests[quest_id] = QuestState.FAILED
	quest_failed.emit(quest_id)
	print("Quest failed: %s" % quest_id)

func is_active(quest_id: String) -> bool:
	return active_quests.get(quest_id, QuestState.INACTIVE) == QuestState.ACTIVE

func is_complete(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

## Returns a one-line hint string for the HUD.
func get_active_hint() -> String:
	# Prefer Year 1 chain quests for the hint
	for qid in QuestDefs.year_1_chain():
		if active_quests.get(qid, QuestState.INACTIVE) == QuestState.ACTIVE:
			return QuestDefs.QUESTS[qid].get("hint", "")
	# Fall back to any active quest
	for qid in active_quests:
		if active_quests[qid] == QuestState.ACTIVE:
			return _get_quest_title(qid)
	return ""

## Returns the id of the currently active Year 1 chain quest, or "".
func get_active_chain_quest_id() -> String:
	for qid in QuestDefs.year_1_chain():
		if active_quests.get(qid, QuestState.INACTIVE) == QuestState.ACTIVE:
			return qid
	return ""

## Advances an objective towards completion and auto-completes quest when done.
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
				var rewards: Dictionary = qd.get("rewards", {})
				var xp: int = int(rewards.get("xp", 0))
				complete_quest(quest_id, xp)
			break

## Alias for is_active() for backward compatibility.
func is_quest_active(quest_id: String) -> bool:
	return is_active(quest_id)

## Alias for is_complete() for backward compatibility.
func is_quest_complete(quest_id: String) -> bool:
	return is_complete(quest_id)

# -- Year 1 Chain Event Processing ---------------------------------------------

func _process_chain_event(event_id: String, _data: Dictionary) -> void:
	var to_complete: Array = []
	for qid in active_quests:
		if active_quests[qid] != QuestState.ACTIVE:
			continue
		if not QuestDefs.QUESTS.has(qid):
			continue
		var qdef: Dictionary = QuestDefs.QUESTS[qid]
		if qdef.get("completion_event", "") == event_id:
			to_complete.append(qid)
	for qid in to_complete:
		var xp: int = QuestDefs.QUESTS[qid].get("xp_reward", 0)
		complete_quest(qid, xp)

func _start_next_in_chain(quest_id: String) -> void:
	if not QuestDefs.QUESTS.has(quest_id):
		return
	var next_id: String = QuestDefs.QUESTS[quest_id].get("next_quest", "")
	if next_id == "":
		return
	start_quest(next_id)

# -- Day-Based Checks ----------------------------------------------------------

func _on_day_advanced(_new_day: int) -> void:
	_reset_daily_quests_if_needed()
	# Try to activate any INACTIVE chain quests whose conditions are now met
	for qid in active_quests:
		if active_quests[qid] == QuestState.INACTIVE:
			if QuestDefs.QUESTS.has(qid) and QuestDefs.check_start_conditions(qid):
				active_quests[qid] = QuestState.ACTIVE
				quest_started.emit(qid)
				var title: String = _get_quest_title(qid)
				NotificationManager.notify("Quest: " + title, NotificationManager.T_INFO)
				quest_hint_changed.emit(get_active_hint())
				print("Quest started (deferred): %s" % qid)
	# Check compound conditions for "battening_down"
	if is_active("battening_down"):
		_check_battening_down()

func _check_battening_down() -> void:
	var hives: Array = get_tree().get_nodes_in_group("hive")
	for hive in hives:
		var sim: Node = hive.get("simulation") if hive != null else null
		if sim == null:
			continue
		var stores: float = sim.get("honey_stores") if sim.get("honey_stores") != null else 0.0
		if stores >= 60.0 and last_wash_mites_per_100 >= 0.0 and last_wash_mites_per_100 < 3.0:
			notify_event("winter_ready")
			return

# -- Helpers -------------------------------------------------------------------

func _get_quest_title(quest_id: String) -> String:
	if QuestDefs.QUESTS.has(quest_id):
		return QuestDefs.QUESTS[quest_id].get("title", quest_id)
	if quest_data.has(quest_id):
		return quest_data[quest_id].get("title", quest_id)
	return quest_id.replace("_", " ").capitalize()

# -- Quest Definitions (daily / objective-based) --------------------------------

func _init_quest_definitions() -> void:
	quest_data["bob_intro"] = {
		"id": "bob_intro",
		"title": "Meet Uncle Bob",
		"description": "Walk up to Uncle Bob and press E to meet him.",
		"objectives": [
			{"key": "bob_talked", "label": "Talk to Uncle Bob", "current": 0, "target": 1}
		],
		"rewards": {"xp": 25, "money": 0, "items": []}
	}
	quest_data["daily_inspection"] = {
		"id": "daily_inspection",
		"title": "Inspect Your Hives",
		"description": "Inspect at least 1 hive today.",
		"objectives": [
			{"key": "inspections_done", "label": "Hives inspected", "current": 0, "target": 1}
		],
		"rewards": {"xp": 10, "money": 5, "items": []}
	}
	quest_data["daily_harvest"] = {
		"id": "daily_harvest",
		"title": "Harvest a Full Super",
		"description": "Remove 1 full super from a hive today.",
		"objectives": [
			{"key": "supers_harvested", "label": "Supers removed", "current": 0, "target": 1}
		],
		"rewards": {"xp": 15, "money": 10, "items": []}
	}
	quest_data["daily_market"] = {
		"id": "daily_market",
		"title": "Sell at Saturday Market",
		"description": "Make a honey sale at the Saturday Market.",
		"objectives": [
			{"key": "market_sales", "label": "Sales completed", "current": 0, "target": 1}
		],
		"rewards": {"xp": 20, "money": 0, "items": []}
	}

func _init_year1_chain_quests() -> void:
	# Register Year 1 chain quest data for UI lookup
	for qid in QuestDefs.QUESTS:
		var qdef: Dictionary = QuestDefs.QUESTS[qid]
		quest_data[qid] = {
			"id": qid,
			"title": qdef.get("title", ""),
			"description": qdef.get("description", ""),
			"objectives": [],
			"rewards": {"xp": qdef.get("xp_reward", 0), "money": 0, "items": []}
		}

func _reset_daily_quests_if_needed() -> void:
	var current_day: int = TimeManager.current_day if TimeManager else 0
	if current_day != last_daily_reset_day:
		_reset_daily_quests()
		last_daily_reset_day = current_day

func _reset_daily_quests() -> void:
	daily_tasks = ["daily_inspection", "daily_harvest", "daily_market"]
	for qid in daily_tasks:
		if active_quests.has(qid):
			active_quests.erase(qid)
		if quest_data.has(qid):
			var qd: Dictionary = quest_data[qid]
			if "objectives" in qd:
				for obj in qd.objectives:
					obj.current = 0
	for qid in daily_tasks:
		start_quest(qid)
