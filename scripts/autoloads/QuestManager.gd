# QuestManager.gd -- Tracks active and completed quests, fires quest events.
# Autoloaded as "QuestManager" in project.godot.
#
# Game systems report actions via notify_event(event_id, data).
# The manager checks if any active quest completes on that event,
# awards XP, and auto-starts the next quest in chain.
#
# bob_intro is the gatekeeper quest -- daily quests and other systems
# are suppressed until the player has talked to Uncle Bob.
#
# Side chains (Darlene, Frank, Silas, Ellen, Carl, Rose, June, CVBA)
# activate when their start_conditions are met, checked each day and
# after quest completions.
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
var _suppress_notifications: bool = false  # true during init to prevent toast spam

# Tracks the last alcohol wash result for "battening_down" quest check.
var last_wash_mites_per_100: float = -1.0

# -- Counters ------------------------------------------------------------------
# Persistent counters for tracking attendance, sightings, etc.
# Used by start_conditions (min_queen_sightings) and compound objectives.
var counters: Dictionary = {}  # counter_name -> int

# -- Saturday Regulars tracking ------------------------------------------------
# Compound objective: 4 consecutive Saturdays, 2+ products, $50+ earnings.
var sr_last_market_week: int = -1      # last week number player attended market
var sr_consecutive_weeks: int = 0      # consecutive Saturday visits
var sr_total_earnings: int = 0         # cumulative market earnings during quest
var sr_products_sold: Dictionary = {}  # product_key -> true (track diversity)

# -- Ellen milestone tracking --------------------------------------------------
# Colony Dynamics: tracks inspections done on the current day.
var ellen_inspections_today: Dictionary = {}  # hive_id -> true
var ellen_inspection_day: int = -1            # day the inspections were logged

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_init_quest_definitions()
	_init_all_chain_quests()
	TimeManager.day_advanced.connect(_on_day_advanced)
	# Auto-start the chain on first load if nothing is active yet.
	call_deferred("_try_auto_start_first_quest")

func _try_auto_start_first_quest() -> void:
	# Start bob_intro (the gatekeeper) if no quests have been completed
	if completed_quests.is_empty() and not is_active("bob_intro"):
		_suppress_notifications = true
		start_quest("bob_intro")
		_suppress_notifications = false

# -- Public API: Event Bus -----------------------------------------------------

## Game systems call this to report an action.  The manager checks if any
## active quest completes on this event.
##
## Common event_ids:
##   "bob_intro_complete"          -- player talked to Uncle Bob (first visit)
##   "first_inspection_3_frames"   -- inspected 3+ unique frames in one session
##   "full_inspection_complete"    -- inspected 8+ frame sides in one session
##   "super_added"                 -- player added a honey super
##   "harvest_complete"            -- player completed a harvest
##   "winter_ready"                -- compound: mites ok + stores ok + fed
##   "feeder_placed"               -- player placed feeder bucket
##   "treatment_applied"           -- player applied mite treatment
##   "wash_complete"               -- player completed an alcohol wash
##   "queen_spotted"               -- player spotted the queen during inspection
##   "darlene_fence_visit"         -- player visited Darlene and completed observation
##   "queen_marked"                -- player marked the queen
##   "first_market_sale"           -- player sold first jar at Saturday Market
##   "saturday_regulars_done"      -- 4 consecutive markets, 2 products, $50
##   "silas_honey_house_assessed"  -- examined Honey House + visited Silas
##   "silas_materials_delivered"   -- gathered all construction materials
##   "honey_house_restored"        -- helped Silas finish construction
##   "ellen_first_visit"           -- first visit to extension office
##   "ellen_colony_comparison"     -- inspected 2 hives same day for Ellen
##   "ellen_health_report"         -- wash data on all hives for Ellen
##   "carl_first_visit"            -- first visit to Tanner's Feed & Supply
##   "bulletin_board_posted"       -- posted swarm notice on bulletin board
##   "rose_honey_tasted"           -- brought honey to Rose at diner
##   "bee_package_collected"       -- collected bee package from June
##   "cvba_three_meetings"         -- attended 3 CVBA meetings
func notify_event(event_id: String, data: Dictionary = {}) -> void:
	if event_id == "wash_complete" or event_id == "mite_wash_complete" or event_id == "mite_wash_result":
		last_wash_mites_per_100 = data.get("mites_per_100", -1.0)
	# Auto-increment counters for tracked events
	if event_id == "queen_spotted":
		increment_counter("queen_sightings")
	if event_id == "market_attended":
		increment_counter("market_visits")
	if event_id == "cvba_meeting_attended":
		increment_counter("cvba_meetings")
	if event_id == "diner_visited":
		increment_counter("diner_visits")

	# -- Saturday Regulars compound tracking --
	if event_id == "market_sale_tracked" and is_active("frank_saturday_regulars"):
		_track_saturday_regulars_sale(data)
	if event_id == "market_attended" and is_active("frank_saturday_regulars"):
		_track_saturday_regulars_visit()

	# -- Ellen Colony Dynamics: track same-day inspections --
	if event_id == "hive_inspected" and is_active("ellen_colony_dynamics"):
		_track_ellen_inspection(data)

	# -- Ellen Health Monitoring: track wash data --
	if (event_id == "wash_complete" or event_id == "mite_wash_complete" or event_id == "mite_wash_result") and is_active("ellen_health_monitoring"):
		_track_ellen_health_wash(data)

	_process_chain_event(event_id, data)

	# After any quest completion, check if new side quests can start
	call_deferred("_check_side_quest_activation")

# -- Public API: Quest Management ----------------------------------------------

func start_quest(quest_id: String) -> void:
	if active_quests.has(quest_id) and active_quests[quest_id] == QuestState.ACTIVE:
		return
	if completed_quests.has(quest_id):
		return
	# Check start conditions (month gating, prerequisites, etc.)
	if QuestDefs.QUESTS.has(quest_id):
		if not QuestDefs.check_start_conditions(quest_id):
			active_quests[quest_id] = QuestState.INACTIVE
			return
	active_quests[quest_id] = QuestState.ACTIVE
	quest_started.emit(quest_id)
	if not _suppress_notifications:
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

	# Show return-to-Bob prompt if quest def says to
	_show_return_prompt(quest_id)

	# Auto-start next quest in chain
	_start_next_in_chain(quest_id)
	quest_hint_changed.emit(get_active_hint())

	# Start daily quests once bob_intro is done (first time only)
	if quest_id == "bob_intro":
		_reset_daily_quests_if_needed()

func fail_quest(quest_id: String) -> void:
	active_quests[quest_id] = QuestState.FAILED
	quest_failed.emit(quest_id)
	print("Quest failed: %s" % quest_id)

func is_active(quest_id: String) -> bool:
	return active_quests.get(quest_id, QuestState.INACTIVE) == QuestState.ACTIVE

func is_complete(quest_id: String) -> bool:
	return completed_quests.has(quest_id)

## Returns true if onboarding (bob_intro) is done. Used by other systems
## to gate features until the player has met Bob.
func is_onboarding_complete() -> bool:
	return completed_quests.has("bob_intro")

## Returns a one-line hint string for the HUD.
func get_active_hint() -> String:
	# Prefer Year 1 Bob chain quests for the hint
	for qid in QuestDefs.year_1_chain():
		if active_quests.get(qid, QuestState.INACTIVE) == QuestState.ACTIVE:
			return QuestDefs.QUESTS[qid].get("hint", "")
	# Then check all other active quests
	for qid in active_quests:
		if active_quests[qid] == QuestState.ACTIVE:
			if QuestDefs.QUESTS.has(qid):
				return QuestDefs.QUESTS[qid].get("hint", "")
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

# -- Counter API ---------------------------------------------------------------

## Increment a named counter by amount.
func increment_counter(counter_name: String, amount: int = 1) -> void:
	counters[counter_name] = counters.get(counter_name, 0) + amount

## Get the current value of a named counter.
func get_counter(counter_name: String) -> int:
	return counters.get(counter_name, 0)

## Set a counter to a specific value.
func set_counter(counter_name: String, value: int) -> void:
	counters[counter_name] = value

## Reset a counter to zero.
func reset_counter(counter_name: String) -> void:
	counters[counter_name] = 0

# -- Side Quest Activation -----------------------------------------------------

## Check all side chain first-quests and activate any whose conditions are met.
## Called after quest completions and on day advance.
func _check_side_quest_activation() -> void:
	if not is_onboarding_complete():
		return
	for qid in QuestDefs.all_y1_quests():
		# Skip Bob chain -- handled by next_quest auto-start
		if QuestDefs.get_chain(qid) == "bob":
			continue
		# Skip already active, complete, or failed quests
		var state: int = active_quests.get(qid, -1)
		if state == QuestState.ACTIVE or state == QuestState.COMPLETE:
			continue
		if completed_quests.has(qid):
			continue
		# Check if this is the next quest in its chain
		var chain_name: String = QuestDefs.get_chain(qid)
		if chain_name == "":
			continue
		var chain: Array = QuestDefs.CHAINS.get(chain_name, [])
		var idx: int = chain.find(qid)
		if idx > 0:
			# Not the first quest in chain -- previous must be complete
			var prev_qid: String = chain[idx - 1]
			if not completed_quests.has(prev_qid):
				continue
		# Check start conditions
		if QuestDefs.check_start_conditions(qid):
			start_quest(qid)

# -- Saturday Regulars Tracking ------------------------------------------------

func _track_saturday_regulars_sale(data: Dictionary) -> void:
	var earnings: int = data.get("earnings", 0)
	var product: String = data.get("product", "honey")
	sr_total_earnings += earnings
	sr_products_sold[product] = true
	_check_saturday_regulars_complete()

func _track_saturday_regulars_visit() -> void:
	# Calculate current week number from in-game day
	var current_week: int = TimeManager.current_day / 7
	if sr_last_market_week < 0:
		# First visit while quest is active
		sr_consecutive_weeks = 1
	elif current_week == sr_last_market_week + 1:
		# Consecutive week
		sr_consecutive_weeks += 1
	elif current_week != sr_last_market_week:
		# Missed a week -- reset streak
		sr_consecutive_weeks = 1
		sr_total_earnings = 0
		sr_products_sold.clear()
	# Same week = no change (already counted)
	sr_last_market_week = current_week
	_check_saturday_regulars_complete()

func _check_saturday_regulars_complete() -> void:
	if sr_consecutive_weeks >= 4 and sr_products_sold.size() >= 2 and sr_total_earnings >= 50:
		notify_event("saturday_regulars_done", {})

# -- Ellen Milestone Tracking --------------------------------------------------

func _track_ellen_inspection(data: Dictionary) -> void:
	var hive_id: String = data.get("hive_id", "")
	if hive_id == "":
		return
	var today: int = TimeManager.current_day
	# Reset if it is a new day
	if today != ellen_inspection_day:
		ellen_inspections_today.clear()
		ellen_inspection_day = today
	ellen_inspections_today[hive_id] = true
	# Check if player inspected 2+ different hives today
	if ellen_inspections_today.size() >= 2:
		# Set a flag so Ellen can detect it when the player visits her
		PlayerData.set_flag("ellen_colony_comparison_ready")

func _track_ellen_health_wash(data: Dictionary) -> void:
	var hive_id: String = data.get("hive_id", "")
	if hive_id == "":
		return
	# Track which hives have been washed
	var washed_key: String = "ellen_wash_" + hive_id
	PlayerData.set_flag(washed_key)
	# Check if all registered hives have been washed
	var all_hives: Array = HiveManager.get_all_hives()
	if all_hives.size() < 3:
		return
	var washed_count: int = 0
	for hive_node in all_hives:
		var h_name: String = hive_node.name if hive_node else ""
		# Check the parent node name (hive_inspected uses parent hive node name)
		var parent_node: Node = hive_node.get_parent() if hive_node else null
		var parent_name: String = parent_node.name if parent_node else ""
		if PlayerData.has_flag("ellen_wash_" + h_name) or PlayerData.has_flag("ellen_wash_" + parent_name):
			washed_count += 1
	if washed_count >= all_hives.size():
		PlayerData.set_flag("ellen_health_report_ready")

# -- Chain Event Processing ----------------------------------------------------

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
	# Defer start so completion signals finish first
	call_deferred("start_quest", next_id)

## Show a "Go talk to Uncle Bob" prompt after quests that have return_to_bob.
func _show_return_prompt(quest_id: String) -> void:
	if not QuestDefs.QUESTS.has(quest_id):
		return
	var qdef: Dictionary = QuestDefs.QUESTS[quest_id]
	if qdef.get("return_to_bob", false):
		# Delay slightly so the quest-complete toast shows first
		call_deferred("_deferred_return_prompt")

func _deferred_return_prompt() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	NotificationManager.notify("Go talk to Uncle Bob.", NotificationManager.T_INFO, 5.0)

# -- Quest Definitions (daily + dynamic) ---------------------------------------

func _init_quest_definitions() -> void:
	# Daily repeatable quests (reset each in-game day)
	# These only activate after bob_intro is complete.
	quest_data["daily_inspection"] = {
		"title": "Inspect Your Hives",
		"objectives": [{"key": "inspect", "current": 0, "target": 1}],
		"rewards": {"xp": 10, "money": 5},
	}
	quest_data["daily_harvest"] = {
		"title": "Harvest a Full Super",
		"objectives": [{"key": "harvest_super", "current": 0, "target": 1}],
		"rewards": {"xp": 15, "money": 10},
	}
	quest_data["daily_market"] = {
		"title": "Sell at Saturday Market",
		"objectives": [{"key": "market_sale", "current": 0, "target": 1}],
		"rewards": {"xp": 20},
	}

func _init_all_chain_quests() -> void:
	# All chain quests are defined statically in QuestDefs.
	# Make sure quest_data has entries so objective tracking works.
	for qid in QuestDefs.all_y1_quests():
		if not quest_data.has(qid):
			var qdef: Dictionary = QuestDefs.QUESTS.get(qid, {})
			quest_data[qid] = {
				"title": qdef.get("title", qid),
				"objectives": [{"key": qdef.get("completion_event", ""), "current": 0, "target": 1}],
				"rewards": {"xp": qdef.get("xp_reward", 0)},
			}

func _reset_daily_quests_if_needed() -> void:
	# Don't start daily quests until the player has met Bob
	if not is_onboarding_complete():
		return
	var today: int = TimeManager.current_day
	if today == last_daily_reset_day:
		return
	last_daily_reset_day = today
	daily_tasks = ["daily_inspection", "daily_harvest", "daily_market"]
	_suppress_notifications = true
	for qid in daily_tasks:
		active_quests.erase(qid)
		completed_quests.erase(qid)
		if quest_data.has(qid):
			for obj in quest_data[qid].get("objectives", []):
				obj["current"] = 0
		active_quests[qid] = QuestState.ACTIVE
	_suppress_notifications = false

func _on_day_advanced() -> void:
	_reset_daily_quests_if_needed()
	# Retry any INACTIVE chain quests whose conditions may now be met
	_retry_inactive_chain_quests()
	# Check side quest activation (conditions may change with new day)
	_check_side_quest_activation()
	# Check compound winter_ready condition for battening_down quest
	if is_active("battening_down"):
		_check_winter_ready()

## Re-check INACTIVE quests on each new day. A quest that failed its
## conditions when first attempted may now be startable.
func _retry_inactive_chain_quests() -> void:
	for qid in QuestDefs.all_y1_quests():
		if active_quests.get(qid, -1) == QuestState.INACTIVE:
			if QuestDefs.check_start_conditions(qid):
				start_quest(qid)

func _check_winter_ready() -> void:
	# Compound condition: 60+ lbs honey AND mites under control
	# This is checked each day during fall
	if last_wash_mites_per_100 >= 0.0 and last_wash_mites_per_100 < 3.0:
		# Check honey stores via HiveManager
		if Engine.has_singleton("HiveManager"):
			pass  # Full implementation when honey weight tracking is complete
	# For now, winter_ready is triggered manually via notify_event

# -- Helpers -------------------------------------------------------------------

func _get_quest_title(quest_id: String) -> String:
	# Check static chain quests first
	if QuestDefs.QUESTS.has(quest_id):
		return QuestDefs.QUESTS[quest_id].get("title", quest_id)
	# Check dynamic quest_data
	if quest_data.has(quest_id):
		return quest_data[quest_id].get("title", quest_id)
	return quest_id

# -- Save / Load ---------------------------------------------------------------

func collect_save_data() -> Dictionary:
	return {
		"active_quests": active_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"quest_notes": quest_notes.duplicate(),
		"last_daily_reset_day": last_daily_reset_day,
		"last_wash_mites_per_100": last_wash_mites_per_100,
		"counters": counters.duplicate(),
		"sr_last_market_week": sr_last_market_week,
		"sr_consecutive_weeks": sr_consecutive_weeks,
		"sr_total_earnings": sr_total_earnings,
		"sr_products_sold": sr_products_sold.duplicate(),
		"ellen_inspection_day": ellen_inspection_day,
	}

func apply_save_data(data: Dictionary) -> void:
	active_quests = data.get("active_quests", {})
	completed_quests = data.get("completed_quests", {})
	quest_notes = data.get("quest_notes", {})
	last_daily_reset_day = data.get("last_daily_reset_day", -1)
	last_wash_mites_per_100 = data.get("last_wash_mites_per_100", -1.0)
	counters = data.get("counters", {})
	sr_last_market_week = data.get("sr_last_market_week", -1)
	sr_consecutive_weeks = data.get("sr_consecutive_weeks", 0)
	sr_total_earnings = data.get("sr_total_earnings", 0)
	sr_products_sold = data.get("sr_products_sold", {})
	ellen_inspection_day = data.get("ellen_inspection_day", -1)
