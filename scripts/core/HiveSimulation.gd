# HiveSimulation.gd -- Hive colony simulation (non-visual).
# -----------------------------------------------------------------------------
# Orchestrates the 10-step simulation pipeline.  Each step is a separate
# script in scripts/simulation/.  Steps run in order on tick():
#
#   1. CellStateTransition      -- age/transition every cell
#   2. PopulationCohortManager  -- nurse/forager cohort lifecycle
#   3. NurseSystem              -- brood care coverage check
#   4. ForagerSystem            -- nectar/pollen collection
#   5. NectarProcessor          -- honey frame sync (via _sync_honey_to_frames)
#   6. QueenBehavior            -- laying pattern (inline _queen_lay)
#   7. CongestionDetector       -- honey-bound / brood-bound checks
#   8. HiveHealthCalculator     -- composite health score
#   9. SnapshotWriter           -- write last_snapshot
#  10. FrameRenderer            -- on-demand only, NOT called in tick()
#
# READS:  TimeManager, ForageManager
# WRITES: last_snapshot  (read-only dict consumed by hive.gd and FrameRenderer)
# -----------------------------------------------------------------------------
extends Node
class_name HiveSimulation

# -- Cell State Constants (delegate to CellStateTransition) --------------------
# Expose as aliases so other scripts can write HiveSimulation.S_CAPPED_HONEY etc.
const S_EMPTY_FOUNDATION := CellStateTransition.S_EMPTY_FOUNDATION
const S_DRAWN_EMPTY      := CellStateTransition.S_DRAWN_EMPTY
const S_EGG              := CellStateTransition.S_EGG
const S_OPEN_LARVA       := CellStateTransition.S_OPEN_LARVA
const S_CAPPED_BROOD     := CellStateTransition.S_CAPPED_BROOD
const S_CAPPED_DRONE     := CellStateTransition.S_CAPPED_DRONE
const S_NECTAR           := CellStateTransition.S_NECTAR
const S_CURING_HONEY     := CellStateTransition.S_CURING_HONEY
const S_CAPPED_HONEY     := CellStateTransition.S_CAPPED_HONEY
const S_PREMIUM_HONEY    := CellStateTransition.S_PREMIUM_HONEY
const S_VARROA           := CellStateTransition.S_VARROA
const S_AFB              := CellStateTransition.S_AFB
const S_QUEEN_CELL       := CellStateTransition.S_QUEEN_CELL
const S_VACATED          := CellStateTransition.S_VACATED

# -- Legacy aliases (kept for any code that references the old names) -----------
const CELL_EMPTY        := S_DRAWN_EMPTY
const CELL_EGG          := S_EGG
const CELL_OPEN_LARVA   := S_OPEN_LARVA
const CELL_CAPPED_LARVA := S_CAPPED_BROOD
const CELL_PUPA         := S_CAPPED_BROOD   # merged: pupa IS capped brood
const CELL_HATCHED      := S_DRAWN_EMPTY    # hatched -> immediately drawn_empty
const CELL_BEEBREAD     := S_DRAWN_EMPTY    # TODO: beebread gets its own state later
const CELL_NECTAR       := S_NECTAR
const CELL_CAPPED_HONEY := S_CAPPED_HONEY
const CELL_DAMAGED      := S_VACATED        # damaged -> vacated

# -- Congestion States ---------------------------------------------------------
enum CongestionState { NORMAL, BROOD_BOUND, HONEY_BOUND, FULLY_CONGESTED }

# -- Frame Geometry ------------------------------------------------------------
const FRAME_WIDTH    := CellStateTransition.FRAME_COLS
const FRAME_HEIGHT   := CellStateTransition.FRAME_ROWS
const FRAME_SIZE     := CellStateTransition.FRAME_SIZE
const FRAMES_PER_BOX := 10

# Queen lays center-out through brood box frames (0-indexed).
const QUEEN_FRAME_ORDER := [4, 5, 3, 6, 2, 7, 1, 8, 0, 9]

# -- 3D Ellipsoid Brood Nest Geometry ----------------------------------------
# Real brood nests form a 3D oblate ellipsoid (dome shape) centered on the
# middle frames, upper-center of each frame face. The nest extends:
#   - Across frames (Z): widest at frames 4-5, tapers toward 0 and 9
#   - Horizontally (X): widest on center frames, narrower on outer frames
#   - Vertically (Y): dome shape -- starts near top, extends downward
#
# 3D center point: frame 4.5 (between frames 4 and 5), column 35, row 15
# (upper third -- real queens start laying near the top of the frame and
# the brood nest dome extends downward as it grows).
#
# Each cell's 3D normalized distance from center determines draw/lay priority.
# Distance = sqrt((dz/rz)^2 + (dx/rx)^2 + (dy/ry)^2)
# where rz, rx, ry are the ellipsoid radii.

const ELLIPSOID_CENTER_Z := 4.5    # between frames 4 and 5
const ELLIPSOID_CENTER_X := 35.0   # horizontal center of frame
const ELLIPSOID_CENTER_Y := 15.0   # upper third -- dome starts high

# Radii control the shape of the 3D ellipsoid:
# RZ = how many frames out from center (5.0 = fills all 10 frames)
# RX = how wide across the frame (38.0 = ~54% of 70 cols per side)
# RY = how far down the frame (42.0 = extends well below center)
const ELLIPSOID_RZ := 5.0    # frame-depth radius
const ELLIPSOID_RX := 38.0   # horizontal radius in cells
const ELLIPSOID_RY := 42.0   # vertical radius in cells (asymmetric -- extends more downward)

# -- Bee Development Age Thresholds --------------------------------------------
const AGE_EGG_TO_LARVA    := CellStateTransition.AGE_EGG_TO_LARVA
const AGE_LARVA_TO_CAPPED := CellStateTransition.AGE_LARVA_TO_CAPPED
const AGE_CAPPED_TO_PUPA  := CellStateTransition.AGE_LARVA_TO_CAPPED   # same threshold
const AGE_PUPA_TO_HATCHED := CellStateTransition.AGE_WORKER_EMERGE

# -- Honey Capacity ------------------------------------------------------------
const LBS_PER_FULL_FRAME := 5.0

# ------------------------------------------------------------------------------
# HiveFrame -- one removable wax frame inside a box.
# Each physical frame has TWO sides (A and B) -- just like a real Langstroth
# frame.  The beekeeper can flip the frame during inspection to view either side.
#
# Side A = cells / cell_age  (front)
# Side B = cells_b / cell_age_b  (back)
#
# Age is cumulative days from when the egg was laid (0-255 max).
# ------------------------------------------------------------------------------
class HiveFrame:
	const SIDE_A := 0
	const SIDE_B := 1

	# Deep frame: 70x50 = 3500.  Medium super frame: 70x35 = 2450.
	const DEEP_COLS   := 70
	const DEEP_ROWS   := 50
	const DEEP_SIZE   := 3500   # DEEP_COLS * DEEP_ROWS
	const SUPER_COLS  := 70
	const SUPER_ROWS  := 35
	const SUPER_SIZE  := 2450   # SUPER_COLS * SUPER_ROWS
	const LBS_PER_FULL_DEEP  := 5.0
	const LBS_PER_FULL_SUPER := 3.5

	var is_super_frame: bool = false
	var grid_cols: int = DEEP_COLS
	var grid_rows: int = DEEP_ROWS
	var grid_size: int = DEEP_SIZE

	# Side A (front)
	var cells:    PackedByteArray
	var cell_age: PackedByteArray
	# Side B (back)
	var cells_b:    PackedByteArray
	var cell_age_b: PackedByteArray

	# Harvest marking
	var marked_for_harvest: bool = false

	func _init(p_is_super: bool = false) -> void:
		is_super_frame = p_is_super
		if p_is_super:
			grid_cols = SUPER_COLS
			grid_rows = SUPER_ROWS
			grid_size = SUPER_SIZE
		else:
			grid_cols = DEEP_COLS
			grid_rows = DEEP_ROWS
			grid_size = DEEP_SIZE
		cells = PackedByteArray()
		cells.resize(grid_size)
		cells.fill(CellStateTransition.S_EMPTY_FOUNDATION)
		cell_age = PackedByteArray()
		cell_age.resize(grid_size)
		cell_age.fill(0)
		cells_b = PackedByteArray()
		cells_b.resize(grid_size)
		cells_b.fill(CellStateTransition.S_EMPTY_FOUNDATION)
		cell_age_b = PackedByteArray()
		cell_age_b.resize(grid_size)
		cell_age_b.fill(0)

	func get_cell(x: int, y: int, side: int = SIDE_A) -> int:
		var i := y * grid_cols + x
		return cells[i] if side == SIDE_A else cells_b[i]

	func set_cell(x: int, y: int, state: int, age: int = 0, side: int = SIDE_A) -> void:
		var i := y * grid_cols + x
		if side == SIDE_A:
			cells[i]    = state
			cell_age[i] = age
		else:
			cells_b[i]    = state
			cell_age_b[i] = age

	func lbs_per_full_frame() -> float:
		return LBS_PER_FULL_SUPER if is_super_frame else LBS_PER_FULL_DEEP

	func count_state(s: int) -> int:
		return CellStateTransition.count_state(self, s)

	func count_brood() -> int:
		return CellStateTransition.count_brood(self)

	func count_honey() -> int:
		return CellStateTransition.count_honey(self)

	func count_all_honey() -> int:
		return CellStateTransition.count_all_honey(self)

	## Fill empty drawn cells with S_CAPPED_HONEY up to limit (both sides).
	## Returns total cells placed across both sides.
	func fill_honey(limit: int) -> int:
		var placed := 0
		# Side A
		for i in grid_size:
			if placed >= limit:
				break
			if cells[i] == CellStateTransition.S_DRAWN_EMPTY:
				cells[i] = CellStateTransition.S_CAPPED_HONEY
				placed   += 1
		# Side B
		for i in grid_size:
			if placed >= limit:
				break
			if cells_b[i] == CellStateTransition.S_DRAWN_EMPTY:
				cells_b[i] = CellStateTransition.S_CAPPED_HONEY
				placed     += 1
		return placed

	## Clear honey/nectar cells on both sides, leaving brood and structure intact.
	func clear_honey() -> void:
		for i in grid_size:
			var s: int = int(cells[i])
			if s == CellStateTransition.S_CAPPED_HONEY   or \
			   s == CellStateTransition.S_PREMIUM_HONEY  or \
			   s == CellStateTransition.S_CURING_HONEY   or \
			   s == CellStateTransition.S_NECTAR:
				cells[i]    = CellStateTransition.S_DRAWN_EMPTY
				cell_age[i] = 0
		for i in grid_size:
			var s: int = int(cells_b[i])
			if s == CellStateTransition.S_CAPPED_HONEY   or \
			   s == CellStateTransition.S_PREMIUM_HONEY  or \
			   s == CellStateTransition.S_CURING_HONEY   or \
			   s == CellStateTransition.S_NECTAR:
				cells_b[i]    = CellStateTransition.S_DRAWN_EMPTY
				cell_age_b[i] = 0

# ------------------------------------------------------------------------------
# HiveBox -- a single hive body (deep brood box or shallow super).
# ------------------------------------------------------------------------------
class HiveBox:
	var frames:   Array
	var is_super: bool

	func _init(p_is_super: bool = false) -> void:
		is_super = p_is_super
		frames   = []
		for _i in 10:
			frames.append(HiveFrame.new(p_is_super))

	func count_state(s: int) -> int:
		var n := 0
		for f in frames:
			n += f.count_state(s)
		return n

	func count_brood() -> int:
		var n := 0
		for f in frames:
			n += f.count_brood()
		return n

	func count_honey() -> int:
		var n := 0
		for f in frames:
			n += f.count_honey()
		return n

# -- Queen Data ----------------------------------------------------------------
var queen: Dictionary = {
	"present":          true,
	"species":          "Italian",
	"grade":            "B",
	"age_days":         0,
	"temperament":      1.0,
	"laying_rate":      1500,    # eggs/day target at peak
	"skip_probability": 0.12,    # chance queen skips an empty cell
	"laying_delay":     0,       # days queen waits before starting to lay (package bees)
}

# -- Boxes ---------------------------------------------------------------------
var boxes: Array   # boxes[0] = brood box, [1+] = supers

# -- Adult Bee Population ------------------------------------------------------
# Nuc starting colony: ~10,000 bees (5-frame nuc transferred to 10-frame hive).
# Middle 5 frames are active (drawn comb + brood), outer 5 are empty foundation
# that the colony must draw out and incorporate over time.
# Peak summer will grow to 40,000-55,000 through natural brood emergence.
var nurse_count:   int = 3500
var house_count:   int = 4000
var forager_count: int = 2500
var drone_count:   int = 200

# -- Colony Resources ----------------------------------------------------------
# Nuc starts with modest stores -- enough for a few days but needs forage quickly.
var honey_stores:  float = 8.0    # ~1.5 lbs per nuc frame
var pollen_stores: float = 2.0
var mite_count:    float = 50.0   # lower mite load in a fresh nuc

# -- Disease Flags -------------------------------------------------------------
var disease_flags: Array = []   # String list: "AFB", "EFB", "SHB", etc.

# -- State ---------------------------------------------------------------------
var days_elapsed:           int = 0
var congestion_state:       CongestionState = CongestionState.NORMAL
var consecutive_congestion: int = 0

# -- Snapshot (read-only outside tick) -----------------------------------------
var last_snapshot: Dictionary = {}

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	# Create empty foundation boxes but do NOT seed brood or register for ticks.
	# Registration happens only when a colony is initialized (init_as_nuc or
	# init_as_package), ensuring empty hives don't tick or waste resources.
	boxes = []
	boxes.append(HiveBox.new(false))

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		HiveManager.unregister(self)

## Initialize as a 5-frame nuc transferred into a 10-frame hive.
## Call this explicitly when placing a pre-built colony (not from _ready).
func init_as_nuc() -> void:
	boxes = []
	boxes.append(HiveBox.new(false))
	_seed_initial_brood()
	HiveManager.register(self)
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())

func _seed_initial_brood() -> void:
	# -- Nuc starting state ----------------------------------------------------
	# A 5-frame nuc has been transferred into a 10-frame hive body.
	# Middle 5 frames (indices 2,3,4,5,6) = active drawn comb from the nuc.
	# Outer 5 frames (indices 0,1,7,8,9) = empty foundation the colony must draw.
	#
	# Brood is seeded using the 3D ellipsoid -- cells closest to the hive center
	# get brood, creating the realistic dome pattern across multiple frames.
	# Center frames (3,4,5) get the most brood; flank frames (2,6) get less.
	# --------------------------------------------------------------------------
	var brood_box = boxes[0]

	# Nuc frame indices (the 5 active frames from the nuc)
	const NUC_FRAMES := [2, 3, 4, 5, 6]

	# Outer frames stay as S_EMPTY_FOUNDATION (default from HiveFrame._init)
	# Only the nuc frames get drawn comb -- both sides
	for fi in NUC_FRAMES:
		brood_box.frames[fi].cells.fill(S_DRAWN_EMPTY)
		brood_box.frames[fi].cells_b.fill(S_DRAWN_EMPTY)

	# Seed brood using 3D ellipsoid distance -- cells within 0.55 radius get brood.
	# This creates the dome: center frames (3,4,5) are dense with brood,
	# flanking frames (2,6) have smaller patches near their centers.
	const BROOD_RADIUS := 0.55
	for fi in NUC_FRAMES:
		var frame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var dist: float = _cell_3d_dist(fi, x, y)
					if dist <= BROOD_RADIUS:
						var age: int = randi() % 21
						var state: int
						if   age < AGE_EGG_TO_LARVA:
							state = S_EGG
						elif age < AGE_LARVA_TO_CAPPED:
							state = S_OPEN_LARVA
						else:
							state = S_CAPPED_BROOD
						frame.set_cell(x, y, state, age, side)

	_sync_honey_to_frames()

# -- Package Bee Initialization ------------------------------------------------
# Called by hive.gd when player installs Package Bees into a complete empty hive.
# Replaces nuc-style initialization with realistic package-bee starting conditions:
#   - All 10 frames are empty foundation (no drawn comb -- bees must draw it)
#   - ~8,000 loose bees (3-lb package), no existing brood
#   - Queen in cage, released after 2-3 days, then needs 2-3 more to start laying
#   - Total queen laying delay: 4-6 days (randomized)
#   - Minimal stores (sugar syrup from the package can)
#   - Very low mite count (packages are relatively clean)
#   - Random queen grade and species for variety
# ------------------------------------------------------------------------------

func init_as_package() -> void:
	# Reset boxes -- all 10 frames are empty foundation
	boxes = []
	boxes.append(HiveBox.new(false))
	# HiveFrame._init() already fills with S_EMPTY_FOUNDATION, so no seeding needed

	# Smaller starting population -- loose package bees, no established cohorts
	nurse_count   = 2800
	house_count   = 3200
	forager_count = 1800
	drone_count   = 50

	# Minimal stores -- sugar syrup from the package can
	honey_stores  = 2.0     # ~2 lbs equivalent (much less than a nuc)
	pollen_stores = 0.3     # almost none -- need to forage immediately

	# Very low mite load -- packages are typically treated before shipping
	mite_count = 15.0

	# Reset elapsed state
	days_elapsed           = 0
	congestion_state       = CongestionState.NORMAL
	consecutive_congestion = 0
	disease_flags          = []

	# Randomize queen -- she's a fresh caged queen from the package supplier
	var species_pool := ["Italian", "Carniolan", "Russian", "Buckfast", "Caucasian"]
	var grade_pool   := ["S", "A", "A", "B", "B", "B", "C", "C", "D"]
	queen = {
		"present":          true,
		"species":          species_pool[randi() % species_pool.size()],
		"grade":            grade_pool[randi() % grade_pool.size()],
		"age_days":         0,
		"temperament":      randf_range(0.7, 1.0),
		"laying_rate":      randi_range(1200, 1800),
		"skip_probability": randf_range(0.08, 0.18),
		"laying_delay":     randi_range(4, 6),   # 4-6 days before queen starts laying
	}

	# Register with HiveManager so tick() is called each day
	HiveManager.register(self)

	# Write initial snapshot
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())

# -- Daily Tick (called by HiveManager) ----------------------------------------

func tick() -> void:
	days_elapsed      += 1
	queen["age_days"] += 1

	var s_factor: float = TimeManager.season_factor()
	var forage:   float = ForageManager.calculate_forage_pool(Vector2.ZERO)

	# -- Pre-CST full-count pass ------------------------------------------------
	# One sum_frame_counts() pass over all 10 brood-box frames (35,000 cell reads)
	# replaces 2 former separate scans (count_state(S_OPEN_LARVA) + count_brood)
	# that each scanned the same 35,000 cells independently.
	var pre_counts: Dictionary = CellStateTransition.sum_frame_counts(boxes[0].frames)
	var open_larva_count: int = pre_counts[S_OPEN_LARVA]

	# -- Step 3: NurseSystem -- computed first to inform CellStateTransition ctx -
	var nurse_result: Dictionary = NurseSystem.process(nurse_count, open_larva_count)

	# -- Step 1: CellStateTransition -- age/transition every cell ---------------
	var total_adults := nurse_count + house_count + forager_count
	var mite_rate    := clampf(mite_count / maxf(1.0, float(total_adults)), 0.0, 1.0)
	# total_brood mirrors HiveBox.count_brood() which covers S_EGG..S_CAPPED_DRONE.
	var total_brood: int = (pre_counts[S_EGG] + pre_counts[S_OPEN_LARVA]
		+ pre_counts[S_CAPPED_BROOD] + pre_counts[S_CAPPED_DRONE])
	var chill_risk  := 0.0
	if total_adults < total_brood * 2:
		chill_risk = clampf(
			(float(total_brood) - float(total_adults) * 2.0) / float(total_brood + 1),
			0.0, 0.06
		)

	var ctx := {
		"mite_rate":      mite_rate,
		"chill_risk":     chill_risk,
		"afb_active":     disease_flags.has("AFB"),
		"has_nurse_bees": nurse_result["has_nurse_bees"],
		# NurseSystem now provides a capping_delay (0-2 days) when understaffed.
		# CellStateTransition uses this to delay larva->capped transition.
		"capping_delay":  nurse_result.get("capping_delay", 0),
	}

	var emerged_workers := 0
	var emerged_drones  := 0

	for frame in boxes[0].frames:
		# Side A
		var result_a: Dictionary = CellStateTransition.process_frame(frame, ctx)
		emerged_workers += result_a["emerged_workers"]
		emerged_drones  += result_a["emerged_drones"]
		# Side B -- swap arrays so process_frame operates on side B data
		var save_cells = frame.cells
		var save_ages  = frame.cell_age
		frame.cells    = frame.cells_b
		frame.cell_age = frame.cell_age_b
		var result_b: Dictionary = CellStateTransition.process_frame(frame, ctx)
		emerged_workers += result_b["emerged_workers"]
		emerged_drones  += result_b["emerged_drones"]
		# Restore: save modified B back, restore A
		frame.cells_b    = frame.cells
		frame.cell_age_b = frame.cell_age
		frame.cells      = save_cells
		frame.cell_age   = save_ages

	# -- Step 2: PopulationCohortManager -- age adult cohorts -------------------
	var transition_result := {
		"emerged_workers": emerged_workers,
		"emerged_drones":  emerged_drones,
	}
	PopulationCohortManager.process(self, transition_result, s_factor)

	# -- Step 4: ForagerSystem -- nectar/pollen collection ----------------------
	var forage_result := ForagerSystem.process(
		forager_count, forage, s_factor, int(congestion_state))
	var nectar_in: float = forage_result["nectar_collected"]
	var pollen_in: float = forage_result["pollen_collected"]

	# -- Step 5: Stores update + honey frame sync -------------------------------
	# Science fix (HS-1): nectar->honey conversion factor corrected to 0.20.
	# Standard ratio is 5 lbs nectar -> 1 lb honey (dehydration from ~80% to <18%
	# water content).  Previous factor 0.15 underproduced honey by 25%.
	honey_stores  = maxf(0.0, honey_stores + nectar_in * 0.20 - _daily_consumption())
	pollen_stores = maxf(0.0, pollen_stores + pollen_in - float(nurse_count) * 0.00003)
	if pollen_stores < 2.0 and forage > 0.5:
		pollen_stores += forage * 0.3

	_sync_honey_to_frames()

	# -- Step 5.5: Comb drawing (package bees -- workers draw foundation) ------
	# Package colonies start with all empty foundation. Workers progressively
	# draw comb outward from center. Rate scales with house bee count AND forage
	# availability -- bees need incoming nectar to produce wax (6-7 lbs honey per
	# 1 lb wax). Good forage months = fast comb drawing; dearth = near stall.
	var foundation_total: int = boxes[0].count_state(S_EMPTY_FOUNDATION)
	if foundation_total > 0:
		_draw_comb(foundation_total, forage)

	# -- Step 6: QueenBehavior -- lay eggs --------------------------------------
	# Respect laying_delay for package bee queens still in their cage / acclimating
	var laying_delay: int = queen.get("laying_delay", 0)
	if laying_delay > 0:
		queen["laying_delay"] = laying_delay - 1
	elif queen["present"]:
		_queen_lay(s_factor)

	# -- Post-lay full-count pass -----------------------------------------------
	# Second (and final) full scan this tick. Covers mite reproduction, congestion
	# detection, and snapshot writing. Replaces 5 formerly-separate count calls
	# (count_statex3 + count_brood + count_honey) that totalled ~175,000 cell reads.
	# Queen laying only writes S_EGG so capped-brood counts are stable vs. pre-lay.
	var post_counts: Dictionary = CellStateTransition.sum_frame_counts(boxes[0].frames)

	# Mite reproduction inside capped brood.
	# Science fix (HS-3): Varroa population growth is exponential w.r.t. mite count,
	# not linear w.r.t. brood count.  Each mite in a brood cell produces ~1.5
	# daughters over 12 days = ~0.125 daughters/mite/day.  Population doubles in
	# ~40-60 days in summer (untreated) -- this is the well-documented epidemiological
	# curve (Calis et al. 1999).
	# Formula: mites added = mite_count x 0.017 x brood_availability_factor
	# where brood_availability_factor = capped_cells / healthy_brood_baseline.
	# At low mite/brood loads this is comparable to the old formula; at high loads
	# it correctly produces exponential growth rather than flat-rate additions.
	var capped_brood: int = post_counts[S_CAPPED_BROOD] + post_counts[S_VARROA]
	# Baseline doubled from 8000->16000 because each frame now has two sides.
	var brood_avail := clampf(float(capped_brood) / 16000.0, 0.0, 1.0)
	mite_count += mite_count * 0.017 * brood_avail
	mite_count  = minf(mite_count, 5000.0)

	# -- Step 7: CongestionDetector -- space stress analysis --------------------
	var brood_cells: int = (post_counts[S_EGG] + post_counts[S_OPEN_LARVA]
		+ post_counts[S_CAPPED_BROOD] + post_counts[S_CAPPED_DRONE]
		+ post_counts[S_VARROA])
	var honey_cells: int  = post_counts[S_CAPPED_HONEY] + post_counts[S_PREMIUM_HONEY]
	var foundation_c: int = post_counts[S_EMPTY_FOUNDATION]
	var total_drawn  := FRAME_SIZE * FRAMES_PER_BOX - foundation_c
	# CongestionDetector now returns a dict: {state, swarm_prep}.
	# Pass consecutive_congestion so swarm prep can be gated on sustained pressure.
	var cong_result := CongestionDetector.evaluate(
		brood_cells, honey_cells, total_drawn, consecutive_congestion)
	var new_cong: int = cong_result["state"]
	if new_cong != CongestionState.NORMAL:
		consecutive_congestion += 1
	else:
		consecutive_congestion = 0
	congestion_state = new_cong as CongestionState
	# swarm_prep flag: wire this into QueenBehavior / HiveManager when ready.
	# For now, store it in the snapshot via last_snapshot so UI can display it.
	var _swarm_prep_ready: bool = cong_result.get("swarm_prep", false)

	# -- Step 8: HiveHealthCalculator -- composite health score -----------------
	var health_score := _calculate_health_score()

	# -- Step 9: SnapshotWriter -- write read-only snapshot dict ----------------
	# Pass post_counts so SnapshotWriter reuses already-computed totals.
	last_snapshot = SnapshotWriter.write(self, health_score, post_counts)

# -- 3D Ellipsoid Distance ----------------------------------------------------
# Returns the normalized 3D distance of a cell from the ellipsoid center.
# Values < 1.0 are inside the ellipsoid; lower = closer to center.
# frame_idx: 0-9, x: 0-69, y: 0-49.
# Side doesn't matter for distance -- both sides of a frame are the same depth.

static func _cell_3d_dist(frame_idx: int, x: int, y: int) -> float:
	var dz: float = (float(frame_idx) - ELLIPSOID_CENTER_Z) / ELLIPSOID_RZ
	var dx: float = (float(x) - ELLIPSOID_CENTER_X) / ELLIPSOID_RX
	var dy: float = (float(y) - ELLIPSOID_CENTER_Y) / ELLIPSOID_RY
	return sqrt(dz * dz + dx * dx + dy * dy)

# -- Comb Drawing (3D ellipsoid -- center-out) --------------------------------
# Workers convert S_EMPTY_FOUNDATION -> S_DRAWN_EMPTY expanding outward from
# the 3D center of the hive. The draw frontier is a growing ellipsoid shell:
# cells closest to center get drawn first, creating the dome shape that real
# bees build. Rate scales with house bee count AND forage level.

func _draw_comb(foundation_remaining: int, forage: float) -> void:
	# Wax production depends on multiple colony factors.
	# Strongest driver: nectar/honey stores (bees consume 6-7 lbs honey per 1 lb wax).
	# Secondary: forager count (more foragers = more incoming nectar stimulus).
	# Tertiary: overall hive health (sick/stressed colonies draw slowly).
	#
	# Below 0.5 lb stores = starvation, no wax at all.
	if honey_stores < 0.5:
		return

	# -- Nectar/honey stores multiplier (STRONGEST factor, 0.2 - 1.5 range) --
	# Abundant stores trigger a building boom; scarce stores throttle hard.
	var store_mult: float = 1.5
	if honey_stores < 2.0:
		store_mult = 0.20 + 0.30 * (honey_stores - 0.5) / 1.5
	elif honey_stores < 5.0:
		store_mult = 0.50 + 0.30 * (honey_stores - 2.0) / 3.0
	elif honey_stores < 12.0:
		store_mult = 0.80 + 0.40 * (honey_stores - 5.0) / 7.0
	elif honey_stores < 25.0:
		store_mult = 1.20 + 0.30 * (honey_stores - 12.0) / 13.0

	# -- Forager multiplier (0.3 - 1.2 range) --
	# Active foragers signal nectar flow; bees ramp up wax glands in response.
	var forager_ratio: float = float(forager_count) / 3000.0
	var forager_mult: float = clampf(0.30 + 0.90 * forager_ratio, 0.30, 1.20)

	# -- Health multiplier (0.4 - 1.0 range) --
	# Sick or stressed colonies divert energy from building to survival.
	var health: float = _calculate_health_score()
	var health_mult: float = clampf(0.40 + 0.60 * (health / 100.0), 0.40, 1.0)

	# -- Forage availability (incoming nectar stimulus) --
	var forage_mult: float = 0.15 + 0.85 * forage

	# -- Base rate from house bee count (wax gland workers) --
	# Tuned so a B-grade colony (4000 house, 9lb stores, 2500 foragers, 75 health,
	# B month 0.65 forage, Italian B queen) draws ~30% more cells/day than the
	# queen lays (~975 eggs/day at B conditions -> target ~1268 cells/day).
	var base_rate: float = float(house_count) * 0.49
	var draw_rate: int = int(base_rate * store_mult * forager_mult * health_mult * forage_mult)
	draw_rate = clampi(draw_rate, 0, 5000)
	if draw_rate <= 0:
		return

	# Collect all foundation cells with their 3D distance from hive center.
	# Then sort by distance and draw the closest ones first -- this produces
	# the natural dome/ellipsoid expansion pattern real bees create.
	var candidates: Array = []   # [dist, frame_idx, side, cell_idx]
	var brood_box = boxes[0]

	for fi in range(FRAMES_PER_BOX):
		var frame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			var side_cells: PackedByteArray = frame.cells if side == 0 else frame.cells_b
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var idx := y * FRAME_WIDTH + x
					if int(side_cells[idx]) == S_EMPTY_FOUNDATION:
						var dist: float = _cell_3d_dist(fi, x, y)
						candidates.append([dist, fi, side, idx])

	# Sort by 3D distance -- closest to center first
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	# Draw the closest cells up to draw_rate
	var drawn := 0
	for c in candidates:
		if drawn >= draw_rate:
			break
		var fi: int   = int(c[1])
		var sd: int   = int(c[2])
		var idx: int  = int(c[3])
		var frame = brood_box.frames[fi]
		if sd == HiveFrame.SIDE_A:
			frame.cells[idx] = S_DRAWN_EMPTY
		else:
			frame.cells_b[idx] = S_DRAWN_EMPTY
		drawn += 1

	# Wax production costs honey -- ~7 lbs honey per 1 lb wax.
	# ~70,000 total cells = ~3-4 lbs wax = ~21-28 lbs honey.
	# Each cell costs roughly 0.0004 lbs of honey.
	var honey_cost: float = float(drawn) * 0.0004
	honey_stores = maxf(0.0, honey_stores - honey_cost)

# -- Hex Adjacency Check ------------------------------------------------------
# Pointy-top hex offset grid (odd rows shift right by half a cell).
# Returns true only if ALL 6 hex neighbours are drawn comb (not foundation).
# Edge cells (touching the frame boundary) always return false -- the queen
# won't lay where the comb doesn't have a complete wall of neighbours.

func _cell_walled_in(side_cells: PackedByteArray, x: int, y: int) -> bool:
	# Reject edge cells outright -- they can never be fully surrounded.
	if x <= 0 or x >= FRAME_WIDTH - 1 or y <= 0 or y >= FRAME_HEIGHT - 1:
		return false

	var even_row: bool = (y % 2 == 0)

	# Hex neighbour offsets for pointy-top offset coordinates.
	# Even rows:  NW(-1,-1) NE(0,-1)  W(-1,0) E(+1,0)  SW(-1,+1) SE(0,+1)
	# Odd  rows:  NW(0,-1)  NE(+1,-1) W(-1,0) E(+1,0)  SW(0,+1)  SE(+1,+1)
	var offsets: Array
	if even_row:
		offsets = [
			Vector2i(-1, -1), Vector2i( 0, -1),   # NW, NE
			Vector2i(-1,  0), Vector2i( 1,  0),   # W,  E
			Vector2i(-1,  1), Vector2i( 0,  1),   # SW, SE
		]
	else:
		offsets = [
			Vector2i( 0, -1), Vector2i( 1, -1),   # NW, NE
			Vector2i(-1,  0), Vector2i( 1,  0),   # W,  E
			Vector2i( 0,  1), Vector2i( 1,  1),   # SW, SE
		]

	for off in offsets:
		var nx: int = x + off.x
		var ny: int = y + off.y
		# Out-of-bounds neighbour -> not walled in
		if nx < 0 or nx >= FRAME_WIDTH or ny < 0 or ny >= FRAME_HEIGHT:
			return false
		var n_state: int = int(side_cells[ny * FRAME_WIDTH + nx])
		if n_state == CellStateTransition.S_EMPTY_FOUNDATION:
			return false

	return true

# -- Queen Laying Pattern (3D ellipsoid -- center-out) -------------------------
# The queen lays in a 3D ellipsoid pattern matching how real queens work:
# she starts at the center of the middle frames and spirals outward, filling
# cells closest to the 3D center first. This creates the characteristic dome
# of brood visible when you pull frames -- center frames are full, outer frames
# have smaller and smaller brood patches.

func _queen_lay(s_factor: float) -> void:
	var grade_mod: float   = _grade_modifier(queen["grade"])
	var species_mod: float = _species_seasonal_modifier(queen["species"], s_factor)
	var target: int        = int(float(queen["laying_rate"]) * s_factor * species_mod * grade_mod)
	if target <= 0:
		return

	var skip_prob: float = queen["skip_probability"]
	var brood_box = boxes[0]

	# Collect all eligible cells (drawn, empty, walled-in) with 3D distances.
	var candidates: Array = []   # [dist, frame_idx, side, cell_idx]

	for fi in range(FRAMES_PER_BOX):
		var frame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			var side_cells: PackedByteArray = frame.cells if side == 0 else frame.cells_b
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var idx := y * FRAME_WIDTH + x
					var state: int = int(side_cells[idx])
					if state != S_DRAWN_EMPTY:
						continue
					if not _cell_walled_in(side_cells, x, y):
						continue
					var dist: float = _cell_3d_dist(fi, x, y)
					# Only lay within the ellipsoid boundary (dist <= 1.0)
					if dist > 1.0:
						continue
					candidates.append([dist, fi, side, idx])

	# Sort by 3D distance -- queen fills closest to center first
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	# Lay eggs in order of proximity to 3D center
	var laid := 0
	for c in candidates:
		if laid >= target:
			break
		# Skip probability -- queen occasionally skips cells (realistic)
		if randf() > skip_prob:
			var fi: int   = int(c[1])
			var sd: int   = int(c[2])
			var idx: int  = int(c[3])
			var frame = brood_box.frames[fi]
			if sd == HiveFrame.SIDE_A:
				frame.cells[idx]    = S_EGG
				frame.cell_age[idx] = 0
			else:
				frame.cells_b[idx]    = S_EGG
				frame.cell_age_b[idx] = 0
			laid += 1

# -- (Adult cohort and stores update are now in PopulationCohortManager and ForagerSystem) --

# -- Honey Frame Sync ----------------------------------------------------------

func _sync_honey_to_frames() -> void:
	# Incremental honey sync -- deposits new nectar cells OR removes excess honey
	# cells to keep frames roughly in line with honey_stores, WITHOUT wiping the
	# natural nectar -> curing -> capped -> premium cell-state progression that
	# CellStateTransition manages each tick.
	var brood_box = boxes[0]

	# Count existing honey-chain cells across honey frames (indices 4-9 in laying order)
	var existing_honey_cells := 0
	for order_idx in range(4, 10):
		var fi: int = QUEEN_FRAME_ORDER[order_idx]
		var frame = brood_box.frames[fi]
		for i in frame.grid_size:
			var s: int = int(frame.cells[i])
			if s >= CellStateTransition.S_NECTAR and s <= CellStateTransition.S_PREMIUM_HONEY:
				existing_honey_cells += 1
			var sb: int = int(frame.cells_b[i])
			if sb >= CellStateTransition.S_NECTAR and sb <= CellStateTransition.S_PREMIUM_HONEY:
				existing_honey_cells += 1

	var cells_target: int = int(honey_stores / LBS_PER_FULL_FRAME * float(FRAME_SIZE))
	var delta: int = cells_target - existing_honey_cells

	if delta > 0:
		# Need to deposit more nectar cells (new nectar came in)
		var remaining: int = delta
		for order_idx in [9, 8, 7, 6, 5, 4]:
			if remaining <= 0:
				break
			var fi: int = QUEEN_FRAME_ORDER[order_idx]
			var frame = brood_box.frames[fi]
			# Deposit as S_NECTAR on drawn-empty cells (not S_CAPPED_HONEY)
			# so the visual progression plays out naturally
			for i in frame.grid_size:
				if remaining <= 0:
					break
				if int(frame.cells[i]) == CellStateTransition.S_DRAWN_EMPTY:
					frame.cells[i]    = CellStateTransition.S_NECTAR
					frame.cell_age[i] = 0
					remaining -= 1
			for i in frame.grid_size:
				if remaining <= 0:
					break
				if int(frame.cells_b[i]) == CellStateTransition.S_DRAWN_EMPTY:
					frame.cells_b[i]    = CellStateTransition.S_NECTAR
					frame.cell_age_b[i] = 0
					remaining -= 1
	elif delta < -10:
		# Honey consumed -- remove some capped/premium cells (oldest first)
		var to_remove: int = absi(delta)
		for order_idx in range(4, 10):
			if to_remove <= 0:
				break
			var fi: int = QUEEN_FRAME_ORDER[order_idx]
			var frame = brood_box.frames[fi]
			for i in frame.grid_size:
				if to_remove <= 0:
					break
				var s: int = int(frame.cells[i])
				if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
					frame.cells[i]    = CellStateTransition.S_DRAWN_EMPTY
					frame.cell_age[i] = 0
					to_remove -= 1
			for i in frame.grid_size:
				if to_remove <= 0:
					break
				var sb: int = int(frame.cells_b[i])
				if sb == CellStateTransition.S_CAPPED_HONEY or sb == CellStateTransition.S_PREMIUM_HONEY:
					frame.cells_b[i]    = CellStateTransition.S_DRAWN_EMPTY
					frame.cell_age_b[i] = 0
					to_remove -= 1

# -- (Congestion detection now in CongestionDetector; snapshot in SnapshotWriter) --

# -- Harvest -------------------------------------------------------------------

# -- Box Management ----------------------------------------------------------
var has_excluder: bool = false

## Returns the number of deep (brood) boxes in this hive.
func deep_count() -> int:
	var n := 0
	for b in boxes:
		if not b.is_super:
			n += 1
	return n

## Returns the number of super (honey) boxes in this hive.
func super_count() -> int:
	var n := 0
	for b in boxes:
		if b.is_super:
			n += 1
	return n

## Add a second (or third) deep brood body on top of existing deeps.
## Returns true if added, false if max deeps reached (limit 2).
func add_deep() -> bool:
	if deep_count() >= 2:
		return false
	# Insert after the last deep box, before any supers
	var insert_idx := 0
	for i in boxes.size():
		if not boxes[i].is_super:
			insert_idx = i + 1
	boxes.insert(insert_idx, HiveBox.new(false))
	return true

## Rotate deep bodies: move the bottom deep to the top of the deep section.
## This is a real beekeeping technique -- the queen prefers to climb up,
## so putting a mostly-empty bottom box on top gives her new laying space.
## Returns true if rotation happened, false if only 1 deep.
func rotate_deep_bodies() -> bool:
	# Collect indices of deep boxes
	var deep_indices: Array = []
	for i in boxes.size():
		if not boxes[i].is_super:
			deep_indices.append(i)
	if deep_indices.size() < 2:
		return false
	# Remove the bottom-most deep and insert it after the last deep
	var bottom_idx: int = deep_indices[0]
	var bottom_box: HiveBox = boxes[bottom_idx]
	boxes.remove_at(bottom_idx)
	# Find new insert position (after all remaining deeps)
	var new_insert := 0
	for i in boxes.size():
		if not boxes[i].is_super:
			new_insert = i + 1
	boxes.insert(new_insert, bottom_box)
	return true

## Add a honey super on top of the stack (above excluder/deeps).
## Returns true if added, false if max supers reached (limit 10).
func add_super() -> bool:
	if super_count() >= 10:
		return false
	boxes.append(HiveBox.new(true))
	return true

## Remove a specific super by box index. Returns the removed HiveBox or null.
func remove_super(box_idx: int) -> HiveBox:
	if box_idx < 0 or box_idx >= boxes.size():
		return null
	if not boxes[box_idx].is_super:
		return null
	var removed: HiveBox = boxes[box_idx]
	boxes.remove_at(box_idx)
	return removed

## Get harvest data for marked frames. Returns array of dicts with frame info.
func get_harvestable_frames() -> Array:
	var result := []
	for b_idx in boxes.size():
		var box: HiveBox = boxes[b_idx]
		if not box.is_super:
			continue
		for f_idx in box.frames.size():
			var frame: HiveFrame = box.frames[f_idx]
			if not frame.marked_for_harvest:
				continue
			# Calculate capping percentage (honey cells only)
			var capped := 0
			var total_honey := 0
			for side_cells in [frame.cells, frame.cells_b]:
				for i in frame.grid_size:
					var s: int = int(side_cells[i])
					if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
						capped += 1
						total_honey += 1
					elif s == CellStateTransition.S_CURING_HONEY or s == CellStateTransition.S_NECTAR:
						total_honey += 1
			var cap_pct: float = 100.0 if total_honey == 0 else (float(capped) / float(total_honey)) * 100.0
			var honey_lbs := (float(capped) / float(frame.grid_size * 2)) * frame.lbs_per_full_frame()
			result.append({
				"box_idx": b_idx,
				"frame_idx": f_idx,
				"capping_pct": cap_pct,
				"honey_lbs": honey_lbs,
				"capped_cells": capped,
				"total_honey_cells": total_honey,
				"is_super": true
			})
	return result

## Check if an entire super box has all frames marked for harvest.
func is_super_fully_marked(box_idx: int) -> bool:
	if box_idx < 0 or box_idx >= boxes.size():
		return false
	if not boxes[box_idx].is_super:
		return false
	for frame in boxes[box_idx].frames:
		if not frame.marked_for_harvest:
			return false
	return true

func harvest_honey() -> float:
	var amount := honey_stores
	honey_stores = 0.0
	for b in boxes:
		for frame in b.frames:
			frame.clear_honey()
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())
	return amount

# -- Direct Disease Management -------------------------------------------------

func add_disease(flag: String) -> void:
	if not disease_flags.has(flag):
		disease_flags.append(flag)

func clear_disease(flag: String) -> void:
	disease_flags.erase(flag)

func treat_mites(reduction: float) -> void:
	mite_count = maxf(0.0, mite_count * (1.0 - reduction))

# -- Helpers -------------------------------------------------------------------

func _grade_modifier(grade: String) -> float:
	match grade:
		"S": return 1.25
		"A": return 1.10
		"B": return 1.00
		"C": return 0.85
		"D": return 0.65
		"F": return 0.0
	return 1.0

func _species_seasonal_modifier(species: String, s_factor: float) -> float:
	match species:
		"Italian":   return 1.0
		"Carniolan": return clampf(1.0 + (s_factor - 0.5) * 0.4, 0.5, 1.3)
		"Russian":   return 0.90
		"Buckfast":  return 1.05
		"Caucasian": return clampf(0.7 + s_factor * 0.6, 0.7, 1.1)
	return 1.0

func _daily_consumption() -> float:
	var total := float(nurse_count + house_count + forager_count + drone_count)
	# Science fix (HS-2 revised): winter cluster thermogenesis is a FIXED overhead
	# shared by all cluster bees -- not a simple per-bee linear cost.  A larger
	# cluster has better thermal insulation (lower surface:volume ratio) and
	# actually costs less per bee to heat.  Model: multiply by a factor that scales
	# inversely with cluster size so total consumption stays ? constant per day.
	#
	# Formula: winter_mult = 35,000 / cluster_size, clamped to [1.0, 4.0].
	# At 35,000 bees (full colony): mult = 1.0 -> 35,000 x 0.000015 = 0.525 lbs/day
	# At 10,000 bees (small winter cluster): mult = 3.5 -> same 0.525 lbs/day ?
	# At  5,000 bees (dying colony): mult = 4.0 -> 0.300 lbs/day (insulation failing)
	#
	# Total winter consumption: ~0.525 lbs/day x 56 winter days ? 29.4 lbs ?
	# Science: Farrar (1943) -- 25-30 lbs; Seeley (1995) S7 -- cluster fuel budget.
	if TimeManager.is_winter():
		var winter_mult := clampf(35_000.0 / maxf(1.0, total), 1.0, 4.0)
		return total * 0.000015 * winter_mult
	return total * 0.000015

func _calculate_health_score() -> float:
	var score := 100.0
	if not queen["present"]:
		score -= 30.0
	else:
		score -= (1.0 - _grade_modifier(queen["grade"])) * 25.0

	var total_adults  := float(nurse_count + house_count + forager_count)
	var mite_per_100  := mite_count / maxf(1.0, total_adults) * 100.0
	score -= minf(25.0, mite_per_100 * 2.5)

	if honey_stores < 5.0:    score -= 20.0
	elif honey_stores < 15.0: score -= 8.0
	if pollen_stores < 0.5:   score -= 10.0
	elif pollen_stores < 1.5: score -= 5.0

	score -= float(disease_flags.size()) * 5.0
	return clampf(score, 0.0, 100.0)
