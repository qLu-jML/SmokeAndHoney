# CellStateTransition.gd
# -----------------------------------------------------------------------------
# Pipeline Step 1 of 10 -- Cell Biology Engine
#
# Advances every cell in a HiveFrame by one simulated day.
# Handles all deterministic biological and pathological state transitions:
#   egg -> larva -> capped brood -> emerge (worker or drone)
#   nectar -> curing honey -> capped honey -> premium honey
#   varroa damage, AFB spread, vacated cell cleanup
#
# USAGE:
#   var result = CellStateTransition.process_frame(frame, context)
#
# INPUT:  frame   -- HiveSimulation.HiveFrame  (mutated in place)
#         context -- Dictionary with simulation parameters (see CONTEXT KEYS)
#
# OUTPUT: Dictionary (TransitionResult) consumed by PopulationCohortManager
#   {
#     "emerged_workers" : int,   # new adult bees from worker brood
#     "emerged_drones"  : int,   # new adult bees from drone brood
#     "damaged"         : int,   # cells killed by mites / chilling
#     "cleaned"         : int,   # vacated cells returned to drawn_empty
#     "afb_spread"      : int,   # new cells infected by AFB spread
#   }
#
# -----------------------------------------------------------------------------
# CONTEXT KEYS (all optional -- sensible defaults applied if missing):
#   "mite_rate"       float 0-1   fraction of brood cells with a mite riding
#   "chill_risk"      float 0-1   chilling probability per capped cell
#   "afb_active"      bool        true if AFB disease flag is set for this hive
#   "has_nurse_bees"  bool        true if colony has enough nurses to clean
#   "capping_delay"   int  0-2    extra days before larva is capped (nurse stress)
# -----------------------------------------------------------------------------
extends RefCounted
class_name CellStateTransition

# -- Cell State Constants -------------------------------------------------------
# These must stay in sync with HiveSimulation.  The canonical definitions live
# here; HiveSimulation imports them via CellStateTransition.S_*.
const S_EMPTY_FOUNDATION := 0   # No wax drawn -- queen won't lay, bees must draw
const S_DRAWN_EMPTY      := 1   # Empty drawn comb -- ready for queen or storage
const S_EGG              := 2   # Worker/queen egg, days 1-3
const S_OPEN_LARVA       := 3   # Uncapped larva, days 4-9 (nurse-fed)
const S_CAPPED_BROOD     := 4   # Worker pupa, days 10-21, emerges as adult bee
const S_CAPPED_DRONE     := 5   # Drone pupa, days 10-24, emerges as drone
const S_NECTAR           := 6   # Fresh nectar deposited by foragers
const S_CURING_HONEY     := 7   # Nectar being dehydrated, ~3 days
const S_CAPPED_HONEY     := 8   # Fully cured capped honey, harvestable
const S_PREMIUM_HONEY    := 9   # Aged honey (7+ days capped), higher value
const S_VARROA           := 10  # Mite-infested capped brood -- bee may emerge
                                 #   deformed or die; mite reproduces
const S_AFB              := 11  # American Foulbrood infection -- spreads to
                                 #   adjacent larvae; stays until treated/burned
const S_QUEEN_CELL       := 12  # Queen rearing cell -- managed by QueenBehavior
const S_VACATED          := 13  # Dead brood remnant -- bees clean over time
const S_BEE_BREAD        := 14  # Pollen stored as bee bread (up to 3 PU per cell)

const STATE_COUNT := 15         # Total number of distinct cell states

# -- Biological Timing (cumulative days from egg-lay) --------------------------
const AGE_EGG_TO_LARVA       := 3   # Day 3:  egg hatches to open larva
const AGE_LARVA_TO_CAPPED    := 9   # Day 9:  larva capped by nurse bees
const AGE_WORKER_EMERGE      := 21  # Day 21: worker bee chews out of cap
const AGE_DRONE_EMERGE       := 24  # Day 24: drone bee emerges

# -- Honey Curing Chain (days in each state) -----------------------------------
const DAYS_NECTAR_TO_CURING  := 3   # nectar ripens into uncapped curing honey
const DAYS_CURING_TO_CAPPED  := 5   # curing honey sealed under wax cap (Karpathy Phase 1)
const DAYS_CAPPED_TO_PREMIUM := 7   # fully cured honey ages to premium grade

# -- Disease & Damage Thresholds -----------------------------------------------
# mite_rate: fraction of occupied brood cells that have a mite.
# At or above MITE_INFESTATION_THRESHOLD the colony starts showing damage.
const MITE_INFESTATION_THRESHOLD := 0.03  # 3 mites per 100 brood cells

# Probability per tick that a mite riding a capping event invades the cell.
# Scaled by mite_rate in practice; this is the base coefficient.
const MITE_INVASION_BASE := 2.0

# Probability per tick that a varroa-infested cell dies before emergence.
# Science: Rosenkranz et al. (2010) -- 8-11% in-cell bee mortality from varroa.
# Previous value 0.25 was 2.5x too high.
const VARROA_KILL_CHANCE := 0.10

# Probability per tick that an AFB cell spreads to an adjacent larva.
# Science: AFB spread through nurse bee feeding; visible progression over 2-4
# weeks. Radius 1 (8 neighbours) x 1.2% = ~0.096 new infections/source/day.
# Previous: radius 2 x 4% = ~0.96/day (10x too aggressive).
const AFB_SPREAD_CHANCE  := 0.012

# Neighbourhood radius (Chebyshev) for AFB spread.
const AFB_SPREAD_RADIUS  := 1

# Clean-up chance per tick: a vacated cell is returned to drawn_empty.
# Depends on nurse availability.
const VACATED_CLEAN_CHANCE_GOOD  := 0.10  # normal nurse population
const VACATED_CLEAN_CHANCE_POOR  := 0.03  # depleted colony

# Frame geometry defaults (deep). Super frames use 70x35=2450.
# All iteration methods now use frame.grid_size for dynamic sizing.
const FRAME_COLS := 70
const FRAME_ROWS := 50
const FRAME_SIZE := 3500   # default deep -- kept for backward compat

# ------------------------------------------------------------------------------
# process_frame(frame, context) -> TransitionResult
#
# Main entry point.  Iterates all 3,500 cells once.
# Returns aggregate counts for the downstream pipeline step.
# ------------------------------------------------------------------------------
static func process_frame(frame,
                           context: Dictionary) -> Dictionary:

	var mite_rate:      float = context.get("mite_rate",      0.0)
	var chill_risk:     float = context.get("chill_risk",     0.0)
	var afb_active:     bool  = context.get("afb_active",     false)
	var has_nurses:     bool  = context.get("has_nurse_bees", true)
	# capping_delay: extra days before a fully-grown larva is capped.
	# Set by NurseSystem when nurse:larva ratio is below healthy threshold.
	var capping_delay:  int   = context.get("capping_delay",  0)

	var cap_threshold := AGE_LARVA_TO_CAPPED + capping_delay

	var clean_chance: float = VACATED_CLEAN_CHANCE_GOOD if has_nurses else VACATED_CLEAN_CHANCE_POOR

	# Working result counters
	var emerged_workers := 0
	var emerged_drones  := 0
	var damaged         := 0
	var cleaned         := 0

	# Main per-cell loop -- no allocations inside the hot path.
	for i in frame.grid_size:
		var state: int = int(frame.cells[i])
		var age:   int = int(frame.cell_age[i])

		match state:

			S_EGG:
				# -- Egg: age daily; hatch at day 3 --------------------------
				age = _inc_age(age)
				frame.cell_age[i] = age
				if age >= AGE_EGG_TO_LARVA:
					frame.cells[i]   = S_OPEN_LARVA
					# Keep age accumulating from egg-lay for disease checks

			S_OPEN_LARVA:
				# -- Open larva: feed daily; cap at day 9 (+ nurse delay) ----
				# AFB can only infect open larvae and eggs.
				age = _inc_age(age)
				frame.cell_age[i] = age
				if age >= cap_threshold:
					# Capping -- mite may invade during this one-time event.
					# Science: varroa female enters the cell just before capping;
					# invasion probability scales with mite infestation rate.
					if mite_rate >= MITE_INFESTATION_THRESHOLD and \
					   randf() < mite_rate * MITE_INVASION_BASE:
						frame.cells[i] = S_VARROA
					else:
						frame.cells[i] = S_CAPPED_BROOD

			S_CAPPED_BROOD:
				# -- Worker pupa: emerge at day 21; chill damage only ---------
				# Science fix (CST-4): varroa invasion is a one-time event at
				# capping.  The previous ongoing mite-rate check inside capped
				# brood was biologically incorrect -- a mite either entered at
				# capping or it didn't.  Removed to prevent double-counting.
				age = _inc_age(age)
				frame.cell_age[i] = age
				# Chilling check (colony too small to cover brood)
				if chill_risk > 0.0 and randf() < chill_risk:
					frame.cells[i]   = S_VACATED
					frame.cell_age[i] = 0
					damaged += 1
				elif age >= AGE_WORKER_EMERGE:
					frame.cells[i]   = S_DRAWN_EMPTY
					frame.cell_age[i] = 0
					emerged_workers  += 1

			S_CAPPED_DRONE:
				# -- Drone pupa: emerge at day 24 -----------------------------
				age = _inc_age(age)
				frame.cell_age[i] = age
				if age >= AGE_DRONE_EMERGE:
					frame.cells[i]   = S_DRAWN_EMPTY
					frame.cell_age[i] = 0
					emerged_drones   += 1

			S_VARROA:
				# -- Varroa-infested cell: bee may die or emerge damaged ------
				# Science: VARROA_KILL_CHANCE reduced to 0.10 (was 0.25) based
				# on Rosenkranz et al. (2010) -- 8-11% in-cell mortality.
				# Surviving bees may carry DWV and have reduced lifespan, but
				# are counted as emerged workers (health penalty is distributed
				# through reduced forager effectiveness and higher mite load).
				age = _inc_age(age)
				frame.cell_age[i] = age
				if age >= AGE_WORKER_EMERGE:
					if randf() < VARROA_KILL_CHANCE:
						frame.cells[i]   = S_VACATED
						frame.cell_age[i] = 0
						damaged          += 1
					else:
						# Emerges -- likely DWV-compromised but still functional
						frame.cells[i]   = S_DRAWN_EMPTY
						frame.cell_age[i] = 0
						emerged_workers  += 1

			S_AFB:
				# -- AFB: ages with the dead larva, spreads handled below -----
				age = _inc_age(age)
				frame.cell_age[i] = age
				# AFB stays indefinitely until treated; no automatic transition

			S_NECTAR:
				# -- Nectar: cures into honey over ~3 days -------------------
				age += 1
				if age >= DAYS_NECTAR_TO_CURING:
					frame.cells[i]   = S_CURING_HONEY
					frame.cell_age[i] = 0
				else:
					frame.cell_age[i] = age

			S_CURING_HONEY:
				# -- Curing honey: capped after ~4 more days -----------------
				age += 1
				if age >= DAYS_CURING_TO_CAPPED:
					frame.cells[i]   = S_CAPPED_HONEY
					frame.cell_age[i] = 0
				else:
					frame.cell_age[i] = age

			S_CAPPED_HONEY:
				# -- Capped honey: ages to premium after 7 days --------------
				age += 1
				if age >= DAYS_CAPPED_TO_PREMIUM:
					frame.cells[i]   = S_PREMIUM_HONEY
					frame.cell_age[i] = 0
				else:
					frame.cell_age[i] = age

			S_PREMIUM_HONEY:
				# Premium honey stays premium until harvested.  No transition.
				pass

			S_VACATED:
				# -- Vacated: nurse bees may clean it back to drawn empty -----
				if has_nurses and randf() < clean_chance:
					frame.cells[i]   = S_DRAWN_EMPTY
					frame.cell_age[i] = 0
					cleaned          += 1

			# S_EMPTY_FOUNDATION, S_DRAWN_EMPTY, S_QUEEN_CELL: no daily change.
			# Foundation drawing and queen cell management are in separate scripts.
			_:
				pass

	# -- AFB Spread Pass (second pass; avoids same-tick cascade) ---------------
	var afb_spread := 0
	if afb_active:
		afb_spread = _spread_afb(frame)

	return {
		"emerged_workers" : emerged_workers,
		"emerged_drones"  : emerged_drones,
		"damaged"         : damaged,
		"cleaned"         : cleaned,
		"afb_spread"      : afb_spread,
	}

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

## Increment age, clamped to 255 (PackedByteArray ceiling).
static func _inc_age(age: int) -> int:
	return mini(age + 1, 255)

## Spread AFB from existing infected cells to adjacent larvae.
## Science: AFB spreads via nurse bee feeding, not direct cell contact.
## Spread radius reduced to 1 (8 neighbours) with 1.2% chance per neighbour,
## giving ~0.096 new cells per AFB source per day -- realistic 2-4 week spread.
## Returns the number of newly infected cells this tick.
static func _spread_afb(frame) -> int:
	# Collect source cells first so we don't spread within the same tick.
	var sources: PackedInt32Array = PackedInt32Array()
	for i in frame.grid_size:
		if frame.cells[i] == S_AFB:
			sources.append(i)
	if sources.is_empty():
		return 0

	var newly_infected := 0
	for idx in sources:
		var sx := idx % FRAME_COLS
		@warning_ignore("INTEGER_DIVISION")
		var sy := idx / FRAME_COLS
		for dy in range(-AFB_SPREAD_RADIUS, AFB_SPREAD_RADIUS + 1):
			for dx in range(-AFB_SPREAD_RADIUS, AFB_SPREAD_RADIUS + 1):
				if dx == 0 and dy == 0:
					continue
				var nx := sx + dx
				var ny := sy + dy
				if nx < 0 or nx >= FRAME_COLS or ny < 0 or ny >= FRAME_ROWS:
					continue
				var ni  := ny * FRAME_COLS + nx
				var ns: int = int(frame.cells[ni])
				# AFB can only infect open larvae and eggs
				if (ns == S_EGG or ns == S_OPEN_LARVA) and randf() < AFB_SPREAD_CHANCE:
					frame.cells[ni]   = S_AFB
					# Preserve age so we know how old the larva was when infected
					newly_infected    += 1
	return newly_infected

# ------------------------------------------------------------------------------
# Utility: count cells matching a state (used by tests / HiveHealthCalculator)
# ------------------------------------------------------------------------------
## All counting methods aggregate both sides (A and B) of each frame.
## This reflects the true cell population of the physical frame.

static func count_state(frame, state: int) -> int:
	var n := 0
	for i in frame.grid_size:
		if frame.cells[i] == state:
			n += 1
		if frame.cells_b[i] == state:
			n += 1
	return n

static func count_brood(frame) -> int:
	var n := 0
	for i in frame.grid_size:
		var s: int = int(frame.cells[i])
		if s >= S_EGG and s <= S_CAPPED_DRONE:
			n += 1
		var sb: int = int(frame.cells_b[i])
		if sb >= S_EGG and sb <= S_CAPPED_DRONE:
			n += 1
	return n

static func count_honey(frame) -> int:
	var n := 0
	for i in frame.grid_size:
		var s: int = int(frame.cells[i])
		if s == S_CAPPED_HONEY or s == S_PREMIUM_HONEY:
			n += 1
		var sb: int = int(frame.cells_b[i])
		if sb == S_CAPPED_HONEY or sb == S_PREMIUM_HONEY:
			n += 1
	return n

static func count_all_honey(frame) -> int:
	## Includes nectar + curing + capped + premium on both sides
	var n := 0
	for i in frame.grid_size:
		var s: int = int(frame.cells[i])
		if s >= S_NECTAR and s <= S_PREMIUM_HONEY:
			n += 1
		var sb: int = int(frame.cells_b[i])
		if sb >= S_NECTAR and sb <= S_PREMIUM_HONEY:
			n += 1
	return n

## Returns a Dictionary mapping state_int -> count for a SINGLE side (0=A, 1=B).
static func full_count_side(frame, side: int) -> Dictionary:
	var counts: Dictionary = {}
	for s in STATE_COUNT:
		counts[s] = 0
	var arr: PackedByteArray = frame.cells if side == 0 else frame.cells_b
	for i in frame.grid_size:
		counts[arr[i]] += 1
	return counts

## Returns a Dictionary mapping state_int -> count, for all 14 states.
## Counts BOTH sides of the frame.
static func full_count(frame) -> Dictionary:
	var counts: Dictionary = {}
	for s in STATE_COUNT:
		counts[s] = 0
	for i in frame.grid_size:
		counts[frame.cells[i]] += 1
		counts[frame.cells_b[i]] += 1
	return counts

## Count brood cells (S_EGG through S_CAPPED_DRONE) on a SINGLE side of a frame.
## Used by the Queen Finder density model to calculate per-frame brood share.
static func count_brood_side(frame, side: int) -> int:
	var n := 0
	var arr: PackedByteArray = frame.cells if side == 0 else frame.cells_b
	for i in frame.grid_size:
		var s: int = int(arr[i])
		if s >= S_EGG and s <= S_CAPPED_DRONE:
			n += 1
	return n

## Accumulate full_count across an Array[HiveFrame] in a single allocation.
## Counts both sides (A and B) of every frame.  One pass gives all 14 state
## totals across the entire box -- replacing N separate count_state() calls.
static func sum_frame_counts(frames: Array) -> Dictionary:
	var totals: Dictionary = {}
	for s in STATE_COUNT:
		totals[s] = 0
	for frame in frames:
		var cells_a: PackedByteArray = frame.cells
		var cells_b: PackedByteArray = frame.cells_b
		for i in frame.grid_size:
			totals[cells_a[i]] += 1
			totals[cells_b[i]] += 1
	return totals
