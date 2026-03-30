# NurseSystem.gd
# -----------------------------------------------------------------------------
# Pipeline Step 3 -- Nurse Bee Night Actions
#
# NEW MODEL (Nathan's 2-action nurse system):
#   Each nurse bee has 2 actions per night. Priority order:
#
#   ACTION 1 (HIGHEST PRIORITY): Feed brood with PU
#     - Every open larva cell needs 1 PU to be fed
#     - Unfed brood is stunted (growth delayed by 1 day, prioritized next night)
#     - Nurses use incoming PU first, then pull from bee bread stores
#     - Bee bread stores hold up to 3 PU per cell
#
#   ACTION 2 (REMAINING ACTIONS): Store excess PU as bee bread
#     - Leftover PU after feeding goes into bee bread cells (up to 3 PU/cell)
#
#   Then the NU allocation happens (separate from nurse actions):
#     - 50/50 split: half to wax production, half to honey storage
#     - If honey storage is full, excess NU converts to wax
#     - Once brood box comb is complete, overflow NU -> supers as honey ONLY
#
# OUTPUTS:
#   {
#     "brood_fed"       : int    -- number of brood cells fed this night
#     "brood_stunted"   : int    -- number of brood cells NOT fed (will stunt)
#     "pu_used_feeding" : int    -- PU spent on brood feeding
#     "pu_stored"       : int    -- PU stored as bee bread
#     "bee_bread_used"  : int    -- PU pulled from bee bread stores for feeding
#     "has_nurse_bees"  : bool   -- adequate nursing coverage
#     "nurse_ratio"     : float  -- nurses per open larva
#     "capping_delay"   : int    -- 0-2 extra days before larva is capped
#     "total_actions"   : int    -- total nurse actions available
#     "actions_used"    : int    -- actions consumed
#   }
#
# Science references:
#   Winston (1987) "The Biology of the Honey Bee" -- nurse:larva ratios
#   Seeley (1995) "The Wisdom of the Hive" -- colony workforce allocation
# -----------------------------------------------------------------------------
extends RefCounted
class_name NurseSystem

# Actions per nurse per night
const ACTIONS_PER_NURSE := 2

# PU required to feed one open larva cell per night
const PU_PER_LARVA := 1

# Max PU stored per bee bread cell
const PU_PER_BEE_BREAD_CELL := 3

# Nurse staffing thresholds
const IDEAL_NURSE_RATIO := 1.2   # excellent coverage
const ADEQUATE_RATIO    := 0.4   # minimum adequate coverage
const MIN_NURSE_COUNT   := 1500  # absolute minimum for any brood care


## Process nurse night actions.
## nurse_count: total nurse bees in colony
## open_larva_count: cells needing feeding (S_OPEN_LARVA)
## pu_incoming: PU collected by foragers today
## bee_bread_stores: current PU stored as bee bread in frames
## stunted_brood: number of brood cells stunted from previous night (get priority)
static func process(nurse_count: int,
                    open_larva_count: int,
                    pu_incoming: int,
                    bee_bread_stores: int,
                    stunted_brood: int) -> Dictionary:

	var total_actions: int = nurse_count * ACTIONS_PER_NURSE
	var actions_used: int = 0

	# -- Nurse ratio and staffing check --
	var ratio: float = float(nurse_count) / maxf(1.0, float(open_larva_count))
	var adequate: bool = nurse_count >= MIN_NURSE_COUNT and ratio >= (ADEQUATE_RATIO * 0.5)

	# -- ACTION 1: Feed brood (highest priority) --
	# Stunted brood from last night gets fed first, then regular brood.
	# Each feeding action consumes 1 PU and 1 nurse action.
	var brood_needing_feed: int = open_larva_count
	# Available PU: incoming first, then bee bread reserves
	var pu_available: int = pu_incoming + bee_bread_stores
	var bee_bread_used: int = 0

	# How many brood can we actually feed? Limited by:
	# 1. Available nurse actions
	# 2. Available PU (incoming + bee bread)
	# 3. Actual brood count
	var can_feed: int = mini(brood_needing_feed, mini(total_actions, pu_available))
	var brood_fed: int = can_feed
	var brood_stunted: int = maxi(0, brood_needing_feed - brood_fed)

	# Consume PU -- use incoming first, then tap bee bread
	var pu_used_feeding: int = brood_fed
	var pu_from_incoming: int = mini(pu_used_feeding, pu_incoming)
	var pu_from_bee_bread: int = pu_used_feeding - pu_from_incoming
	bee_bread_used = pu_from_bee_bread

	# Consume nurse actions for feeding
	actions_used += brood_fed

	# -- ACTION 2: Store excess PU as bee bread --
	var remaining_pu: int = pu_incoming - pu_from_incoming
	var remaining_actions: int = total_actions - actions_used
	# Each store action puts 1 PU into bee bread
	var pu_to_store: int = mini(remaining_pu, remaining_actions)
	actions_used += pu_to_store

	# -- Capping delay (from nurse understaffing) --
	var capping_delay: int
	if ratio >= ADEQUATE_RATIO:
		capping_delay = 0   # Normal: capped on schedule
	elif ratio >= ADEQUATE_RATIO * 0.5:
		capping_delay = 1   # Mild stress: 1 day delay
	else:
		capping_delay = 2   # Severe stress: 2 day delay

	# Royal jelly surplus for queen rearing
	var rjelly: float = clampf((ratio - IDEAL_NURSE_RATIO * 0.5) / IDEAL_NURSE_RATIO, 0.0, 1.0)

	return {
		"brood_fed":        brood_fed,
		"brood_stunted":    brood_stunted,
		"pu_used_feeding":  pu_used_feeding,
		"pu_stored":        pu_to_store,
		"bee_bread_used":   bee_bread_used,
		"has_nurse_bees":   adequate,
		"nurse_ratio":      ratio,
		"rjelly_surplus":   rjelly,
		"capping_delay":    capping_delay,
		"total_actions":    total_actions,
		"actions_used":     actions_used,
	}
