# GameData.gd -- Global player state, currency, and inventory constants
# Autoloaded as "GameData" in project.godot
extends Node

# -- Signals -------------------------------------------------------------------
signal money_changed(new_amount: float)
signal energy_changed(new_amount: float)
signal level_up(new_level: int)
signal xp_gained(amount: int, total: int)
signal dev_labels_toggled(visible: bool)

# -- Developer Mode (G key) --------------------------------------------------
# When true, debug/dev labels (hive stats, flower stages, bed names) are shown.
var dev_labels_visible: bool = false

func toggle_dev_labels() -> void:
	dev_labels_visible = not dev_labels_visible
	dev_labels_toggled.emit(dev_labels_visible)
	# Also toggle all nodes in the "dev_label" group
	for node in get_tree().get_nodes_in_group("dev_label"):
		if node is CanvasItem:
			(node as CanvasItem).visible = dev_labels_visible

# -- Economy -------------------------------------------------------------------
var money: float = 500.0          # Real dollars -- replaces honey-as-currency

# -- Player Progression --------------------------------------------------------
var player_level: int = 1
var xp: int = 0
var reputation: float = 0.0       # 0-100, used for NPC relationship unlocks

# XP thresholds per level (cumulative total XP required to reach each level).
# Index 0 = L1->L2, 1 = L2->L3, 2 = L3->L4, 3 = L4->L5.
# Calibrated for ~6-7 in-game years to reach Level 5 (GDD S7.1).
#   L1->L2:  2,000 XP  -- very end of Year 1 active season (2-hive hobbyist)
#   L2->L3:  6,000 XP  -- ~mid Year 3  (~1.5 years after Level 2)
#   L3->L4: 13,000 XP  -- ~mid Year 5  (~2 years after Level 3)
#   L4->L5: 24,000 XP  -- ~mid Year 7  (~2 years after Level 4)
const XP_THRESHOLDS: Array = [2000, 6000, 13000, 24000]

# -- XP Reward Constants (GDD S7.1) --------------------------------------------
# Single source of truth for all XP award amounts. Use these constants whenever
# calling GameData.add_xp() so values stay in sync with the GDD.
#
# -- Core beekeeping actions --
const XP_INSPECTION_PER_HIVE       := 5    # First inspection of week, per hive
const XP_QUEEN_SIGHTING            := 15   # Spotting the queen during inspection (bonus)
const XP_HEALTH_ISSUE_IDENTIFIED   := 10   # Identifying a health issue during inspection (bonus)
const XP_HARVEST                   := 20   # Successful harvest (?5 lbs)
const XP_HIVE_SPLIT                := 35   # Successful split (new colony viable)
const XP_SWARM_CAUGHT              := 40   # Catching a swarm
const XP_VARROA_TREATMENT          := 15   # Confirmed varroa treatment (post-treatment count below threshold)
const XP_QUEEN_RAISED              := 50   # Raising a queen to laying status
const XP_KNOWLEDGE_LOG_ENTRY       := 20   # Knowledge Log entry unlocked (first time)
const XP_WINTER_SURVIVAL_PER_HIVE  := 25   # Hive survives winter (spring bonus, per hive)
# Honey sale revenue: 2 XP per $10 earned (calculated dynamically, not a constant)
#
# -- Quests & tasks --
const XP_TUTORIAL_QUEST            := 25   # Per tutorial quest completed
const XP_DAILY_TASK_MIN            := 10   # Daily task (low complexity)
const XP_DAILY_TASK_MAX            := 30   # Daily task (high complexity)
const XP_SEASONAL_GOAL_MIN         := 100  # Seasonal goal (low stakes)
const XP_SEASONAL_GOAL_MAX         := 200  # Seasonal goal (high stakes)
const XP_NPC_QUEST_MIN             := 75   # NPC quest (lower reward)
const XP_NPC_QUEST_MAX             := 150  # NPC quest (higher reward)
const XP_MASTERY_QUEST             := 200  # Mastery quest completed
#
# -- Year 1 early-game activities (GDD S7.1.1) --
const XP_GARDEN_BED_PLANTED        := 10   # Forage garden bed planted (first time, per bed)
const XP_GARDEN_BLOOM_MILESTONE    := 15   # First bloom of season per plant species
const XP_GARDEN_FULLY_ESTABLISHED  := 20   # All forage garden beds planted
const XP_HIVE_OBSERVATION_MIN      := 5    # Hive entrance observation session (min)
const XP_HIVE_OBSERVATION_MAX      := 8    # Hive entrance observation session (max)
const XP_EQUIPMENT_CRAFTED_MIN     := 15   # Item crafted at workbench (simple)
const XP_EQUIPMENT_CRAFTED_MAX     := 25   # Item crafted at workbench (complex)
const XP_WAX_BATCH_CRAFTED         := 20   # Wax product batch completed (candles, lip balm, etc.)
const XP_CVBA_MEETING              := 30   # CVBA club meeting attended (monthly)
const XP_UNCLE_BOB_MENTORSHIP_MIN  := 20   # Uncle Bob mentorship visit (min)
const XP_UNCLE_BOB_MENTORSHIP_MAX  := 25   # Uncle Bob mentorship visit (max)
const XP_MITE_MONITORING           := 5    # Routine mite count completed (per hive)
const XP_STUDY_SESSION             := 10   # Study session at home (max 1/week)
const XP_MARKET_PARTICIPATION_MIN  := 15   # Saturday Market sales completed (min)
const XP_MARKET_PARTICIPATION_MAX  := 25   # Saturday Market sales completed (max)

# -- Energy --------------------------------------------------------------------
var energy: float = 100.0
var max_energy: float = 100.0

# -- Expense Log ---------------------------------------------------------------
var expense_log: Array = []        # Array of {category, amount, description, day}

# -- Diner / Meal State --------------------------------------------------------
# Tracks which meal periods have been eaten today (keyed by game day number)
# meal_key -> day_number: "breakfast" | "lunch" | "dinner" | "seasonal"
var meals_eaten: Dictionary = {}   # { "breakfast": 42, "lunch": 40, ... }
# Coffee: until what game-hour is the 15-energy burst / drain-suppress active?
var coffee_until_hour: float = -1.0
# XP buff from seasonal special: until what game-day does the 5% XP bonus apply?
var xp_buff_until_day: int = -1

# -- Pending Deliveries --------------------------------------------------------
# Array of { "item": String, "count": int } -- checked by mailbox in county_road.gd
var pending_deliveries: Array = []

# -- Item Type Constants --------------------------------------------------------
# Use these string constants when calling add_item / consume_item on the player
const ITEM_RAW_HONEY         := "raw_honey"
const ITEM_HONEY_JAR         := "honey_jar"
const ITEM_BEESWAX           := "beeswax"
const ITEM_POLLEN            := "pollen"
const ITEM_SEEDS             := "seeds"
const ITEM_TREATMENT_OXALIC  := "treatment_oxalic"
const ITEM_TREATMENT_FORMIC  := "treatment_formic"
const ITEM_SYRUP_FEEDER      := "syrup_feeder"
const ITEM_FRAMES            := "frames"
const ITEM_SUPER_BOX         := "super_box"
const ITEM_BEEHIVE           := "beehive"
const ITEM_QUEEN_CAGE        := "queen_cage"
const ITEM_SWARM_TRAP        := "swarm_trap"
const ITEM_JAR               := "jar"
const ITEM_HIVE_STAND        := "hive_stand"
const ITEM_DEEP_BODY         := "deep_body"
const ITEM_LID               := "hive_lid"
const ITEM_HIVE_TOOL         := "hive_tool"
const ITEM_PACKAGE_BEES      := "package_bees"
const ITEM_DEEP_BOX          := "deep_box"       # Complete deep body with 10 frames for brood expansion
const ITEM_QUEEN_EXCLUDER    := "queen_excluder"
const ITEM_FULL_SUPER        := "full_super"
const ITEM_HONEY_BULK        := "honey_bulk"
const ITEM_FERMENTED_HONEY   := "fermented_honey"
const ITEM_SUGAR_SYRUP       := "sugar_syrup"
const ITEM_CHEST             := "chest"
const ITEM_GLOVES            := "gloves"

# -- Beeswax fractional tracking (sub-1lb remainder between harvests) --------
var beeswax_fractional: float = 0.0
var beeswax_lifetime: float = 0.0

# -- Economy Helpers -----------------------------------------------------------

## Deduct money. Returns true if successful, false if insufficient funds.
func spend_money(amount: float, category: String = "Purchase", description: String = "") -> bool:
	if money < amount:
		return false
	money -= amount
	_log_expense(category, amount, description)
	money_changed.emit(money)
	return true

## Add money (from sales, etc.)
func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)

func _log_expense(category: String, amount: float, description: String) -> void:
	expense_log.append({
		"category": category,
		"amount": amount,
		"description": description,
		"day": TimeManager.current_day
	})
	# Keep log bounded to last 365 entries
	if expense_log.size() > 365:
		expense_log.pop_front()

# -- Energy Helpers ------------------------------------------------------------

## Deduct energy for an action. Returns false if not enough energy.
func deduct_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy = maxf(0.0, energy - amount)
	energy_changed.emit(energy)
	return true

## Restore energy (from sleep, meals, etc.)
func restore_energy(amount: float) -> void:
	energy = minf(max_energy, energy + amount)
	energy_changed.emit(energy)

## Full restore -- used on sleep / new day
func full_restore_energy() -> void:
	energy = max_energy
	energy_changed.emit(energy)

# -- XP / Leveling -------------------------------------------------------------

func add_xp(amount: int) -> void:
	xp += amount
	xp_gained.emit(amount, xp)
	_check_level_up()

func _check_level_up() -> void:
	if player_level >= 5:
		return
	var threshold: int = XP_THRESHOLDS[player_level - 1]
	if xp >= threshold:
		player_level += 1
		level_up.emit(player_level)
		print("? Level Up! Now Level %d" % player_level)

func get_level_title() -> String:
	match player_level:
		1: return "Hobbyist"
		2: return "Apprentice"
		3: return "Beekeeper"
		4: return "Journeyman"
		5: return "Master Beekeeper"
	return "Beekeeper"

## Dev-mode helper: force player to a specific level (1-5) for testing.
func set_level_debug(new_level: int) -> void:
	player_level = clampi(new_level, 1, 5)
	level_up.emit(player_level)

# -- Meal / Diner Helpers ------------------------------------------------------

## Returns true if the player has already eaten this meal period today.
func has_eaten_meal(meal_key: String) -> bool:
	if not meals_eaten.has(meal_key):
		return false
	return meals_eaten[meal_key] == TimeManager.current_day

## Record that the player ate a meal this period.
func record_meal(meal_key: String) -> void:
	meals_eaten[meal_key] = TimeManager.current_day

## Returns true if coffee energy buff is currently active.
func is_coffee_active() -> bool:
	return TimeManager.current_hour < coffee_until_hour

## Activate the coffee effect for 2 in-game hours.
func apply_coffee_buff() -> void:
	coffee_until_hour = TimeManager.current_hour + 2.0

## Returns true if the XP buff from seasonal special is active.
func is_xp_buff_active() -> bool:
	return TimeManager.current_day == xp_buff_until_day

## Apply the seasonal special XP buff for the rest of today.
func apply_xp_buff() -> void:
	xp_buff_until_day = TimeManager.current_day
