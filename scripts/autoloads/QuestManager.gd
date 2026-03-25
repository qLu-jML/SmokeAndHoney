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

# -- Public API ----------------------------------------------------------------

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
