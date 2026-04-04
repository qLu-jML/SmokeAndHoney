# HiveSimulation.gd -- Hive colony simulation (non-visual).
# =============================================================================
# The core simulation engine for a single beehive colony. This script models
# real Langstroth hive biology: frames with two sides (A/B), cell-level state
# tracking, 3D ellipsoid brood nest geometry, queen laying patterns, resource
# economics (NU/PU discrete units), and adult bee population cohorts.
#
# Orchestrates the 10-step simulation pipeline. Each step is a separate
# script in scripts/simulation/. Steps run in order on tick():
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
# READS:  TimeManager, ForageManager, WeatherManager, HiveManager
# WRITES: last_snapshot (read-only dict consumed by hive.gd and FrameRenderer)
#
# Inner classes:
#   HiveFrame -- one removable wax frame (two-sided, cell-level data)
#   HiveBox   -- a hive body containing 10 HiveFrames (deep or super)
# =============================================================================
extends Node
class_name HiveSimulation

# -- Cell State Constants (delegate to CellStateTransition) --------------------
# Expose as aliases so other scripts can reference states via HiveSimulation
# (e.g. HiveSimulation.S_CAPPED_HONEY) without importing CellStateTransition.
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
const S_BEE_BREAD        := CellStateTransition.S_BEE_BREAD

# -- Legacy aliases (kept for any code that references the old names) -----------
const CELL_EMPTY        := S_DRAWN_EMPTY
const CELL_EGG          := S_EGG
const CELL_OPEN_LARVA   := S_OPEN_LARVA
const CELL_CAPPED_LARVA := S_CAPPED_BROOD
const CELL_PUPA         := S_CAPPED_BROOD   # merged: pupa IS capped brood
const CELL_HATCHED      := S_DRAWN_EMPTY    # hatched -> immediately drawn_empty
const CELL_BEEBREAD     := S_BEE_BREAD      # now a real state
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

# -- Honey Capacity & Production -----------------------------------------------
const LBS_PER_FULL_FRAME := 5.0
# How many lbs of honey one Nectar Unit produces after processing.
# Tuned so an S-rank colony yields 80-120 lbs harvestable honey per year
# (enough to fill 2 supers by fall). At peak summer NU ~800/day:
#   nu_for_honey=400 -> 2.0 lbs/day, minus ~0.5 consumption = ~1.5 net/day.
#   Over 80 productive days = ~120 lbs gross, ~80 lbs net harvestable.
const LBS_PER_NU := 0.005

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
	const LBS_PER_FULL_SUPER := 4.0

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

	## Return the cell state at grid position (x, y) on the given side.
	func get_cell(x: int, y: int, side: int = SIDE_A) -> int:
		var i := y * grid_cols + x
		return cells[i] if side == SIDE_A else cells_b[i]

	## Set the cell state and age at grid position (x, y) on the given side.
	func set_cell(x: int, y: int, state: int, age: int = 0, side: int = SIDE_A) -> void:
		var i := y * grid_cols + x
		if side == SIDE_A:
			cells[i]    = state
			cell_age[i] = age
		else:
			cells_b[i]    = state
			cell_age_b[i] = age

	## Return the max honey weight (lbs) this frame can hold when fully capped.
	func lbs_per_full_frame() -> float:
		return LBS_PER_FULL_SUPER if is_super_frame else LBS_PER_FULL_DEEP

	## Count cells in a specific state across both sides of this frame.
	func count_state(s: int) -> int:
		return CellStateTransition.count_state(self, s)

	## Count all brood cells (egg + larva + capped brood + capped drone) both sides.
	func count_brood() -> int:
		return CellStateTransition.count_brood(self)

	## Count capped honey cells only (S_CAPPED_HONEY) on both sides.
	func count_honey() -> int:
		return CellStateTransition.count_honey(self)

	## Count all honey-chain cells (nectar through premium) on both sides.
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
# Contains 10 HiveFrames. Deep boxes hold brood + honey; supers hold honey only
# (when a queen excluder is installed).
# ------------------------------------------------------------------------------
class HiveBox:
	var frames: Array   ## Array[HiveFrame] -- the 10 frames in this box
	var is_super: bool  ## true = shallow honey super, false = deep brood box

	func _init(p_is_super: bool = false) -> void:
		is_super = p_is_super
		frames   = []
		for _i in 10:
			frames.append(HiveFrame.new(p_is_super))

	## Count cells in a specific state across all 10 frames in this box.
	func count_state(s: int) -> int:
		var n := 0
		for f in frames:
			n += f.count_state(s)
		return n

	## Count all brood cells across all frames in this box.
	func count_brood() -> int:
		var n := 0
		for f in frames:
			n += f.count_brood()
		return n

	## Count capped honey cells across all frames in this box.
	func count_honey() -> int:
		var n := 0
		for f in frames:
			n += f.count_honey()
		return n

	## Returns what fraction (0.0-1.0) of total brood in this box is on the
	## given frame (both sides combined). Used by Queen Finder density model.
	func get_frame_brood_share(frame_idx: int) -> float:
		var total_brood := 0
		var frame_brood := 0
		for fi in frames.size():
			var fb: int = CellStateTransition.count_brood(frames[fi])
			total_brood += fb
			if fi == frame_idx:
				frame_brood = fb
		if total_brood == 0:
			return 0.0
		return float(frame_brood) / float(total_brood)

# -- Queen Data ----------------------------------------------------------------
var queen: Dictionary = {
	"present":          true,
	"species":          "Carniolan",
	"grade":            "S",
	"age_days":         0,
	"temperament":      1.0,
	# S-rank queen: 2000 eggs/day peak. Nail the best outcome first.
	"laying_rate":      2000,
	"skip_probability": 0.08,
	"laying_delay":     0,
}

# -- Boxes ---------------------------------------------------------------------
var boxes: Array   ## Array[HiveBox] -- boxes[0] = brood box, [1+] = supers

# -- Adult Bee Population ------------------------------------------------------
# Nuc starting colony: ~10,000 bees (5-frame nuc transferred to 10-frame hive).
# Middle 5 frames are active (drawn comb + brood), outer 5 are empty foundation
# that the colony must draw out and incorporate over time.
# Peak summer will grow to 40,000-55,000 through natural brood emergence.
var nurse_count:   int = 3500
var house_count:   int = 4000
var forager_count: int = 2500
var drone_count:   int = 200

# -- Colony Resources (NU/PU discrete unit economy) ----------------------------
# honey_stores: total NU currently stored as honey (in frame cells)
# pollen_stores: total PU currently stored as bee bread (in frame cells, 3 PU/cell)
var honey_stores:  float = 8.0    # ~1.5 lbs per nuc frame
var pollen_stores: float = 2.0
var mite_count:    float = 50.0   # lower mite load in a fresh nuc
var feed_stores:   float = 0.0    # sugar syrup stores (lbs) -- NOT sellable as honey

# Stunted brood tracking -- brood not fed PU last night get priority next night
var stunted_brood_count: int = 0

# -- Disease Flags -------------------------------------------------------------
var disease_flags: Array = []   # String list: "AFB", "EFB", "SHB", etc.

# -- State ---------------------------------------------------------------------
var days_elapsed:           int = 0
var congestion_state:       CongestionState = CongestionState.NORMAL
var consecutive_congestion: int = 0

# -- Snapshot (read-only outside tick) -----------------------------------------
var last_snapshot: Dictionary = {}

# -- Lifecycle -----------------------------------------------------------------

## Called by Godot when this node enters the scene tree.
## Creates an empty brood box with bare foundation but does NOT seed brood or
## register with HiveManager. Registration only happens when a colony is
## explicitly initialized (init_as_nuc, init_as_package, etc.), ensuring
## empty hives sitting in the yard don't tick or waste resources.
func _ready() -> void:
	boxes = []
	boxes.append(HiveBox.new(false))

## Godot lifecycle callback -- unregister from HiveManager on tree exit
## to prevent stale references and orphaned tick calls.
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
	var brood_box: HiveBox = boxes[0]

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
		var frame: HiveFrame = brood_box.frames[fi]
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

# -- Overwintered Colony Initialization ----------------------------------------
# Called by hive.gd to place a colony that has survived winter and is entering
# spring (day 1 of Quickening).  Represents a realistic overwintered hive:
#   - 4 center frames of drawn comb (indices 3,4,5,6), 6 outer = foundation
#   - Small brood nest -- queen just ramping up from winter cluster
#   - Reduced winter-bee population (~8,000 adults, no drones yet)
#   - Remaining honey stores (~12 lbs) and modest pollen (~1.5 lbs)
#   - Moderate mite load from overwintering (~35 mites)
#   - Queen is ~1 year old, already laying (no delay)
# Accepts species/grade overrides so the caller can specify breed and quality.
# ------------------------------------------------------------------------------

func init_as_overwintered(
	p_species: String = "Carniolan",
	p_grade: String = "S"
) -> void:
	# Fresh brood box -- all 10 frames start as foundation
	boxes = []
	boxes.append(HiveBox.new(false))

	var brood_box: HiveBox = boxes[0]

	# -- 4 drawn frames (center: 3, 4, 5, 6) ----------------------------------
	# These survived winter with wax intact.  Outer 6 frames are bare foundation
	# the colony will draw out as spring progresses.
	const DRAWN_FRAMES := [3, 4, 5, 6]
	for fi in DRAWN_FRAMES:
		brood_box.frames[fi].cells.fill(S_DRAWN_EMPTY)
		brood_box.frames[fi].cells_b.fill(S_DRAWN_EMPTY)

	# -- Small brood nest (queen just starting spring laying) ------------------
	# Carniolans shut down hard in winter and restart aggressively in spring.
	# On day 1 of Quickening the queen has been laying for ~7-10 days at a low
	# rate, so there is a small dome of brood in all stages concentrated on the
	# two center-most drawn frames (4 and 5) with a trace on flanks (3 and 6).
	# BROOD_RADIUS 0.30 keeps the nest tight -- roughly 800-1200 total brood
	# cells, which is realistic for early spring restart.
	const OW_BROOD_RADIUS := 0.30
	for fi in DRAWN_FRAMES:
		var frame: HiveFrame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var dist: float = _cell_3d_dist(fi, x, y)
					if dist <= OW_BROOD_RADIUS:
						# Distribute brood across all stages (eggs through
						# late capped) to reflect ~10 days of laying.
						# Weighted toward younger brood since the queen is
						# accelerating her rate as spring begins.
						var age: int = randi() % 15
						var state: int
						if   age < AGE_EGG_TO_LARVA:
							state = S_EGG
						elif age < AGE_LARVA_TO_CAPPED:
							state = S_OPEN_LARVA
						else:
							state = S_CAPPED_BROOD
						frame.set_cell(x, y, state, age, side)

	# -- Seed honey stores into outer drawn frames -----------------------------
	# Overwintered colony has remaining honey on frames 3 and 6 (the flanking
	# drawn frames) -- the bees consumed the center honey to heat the cluster
	# and feed brood.  We place capped honey on the periphery of frames 3 and 6,
	# outside the brood radius (cells with dist > 0.30 that are still drawn).
	# This is more realistic than relying on _sync_honey_to_frames() alone.
	const HONEY_FRAMES := [3, 6]
	for fi in HONEY_FRAMES:
		var frame: HiveFrame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var dist: float = _cell_3d_dist(fi, x, y)
					# Honey arc: outside brood zone but inside the frame's
					# drawn area.  Top corners and edges get capped honey.
					if dist > OW_BROOD_RADIUS and dist < 0.80:
						var cell_state: int = frame.get_cell(x, y, side)
						if cell_state == S_DRAWN_EMPTY:
							frame.set_cell(x, y, S_CAPPED_HONEY, 10, side)

	# -- Seed bee bread cells on flanking drawn frames (3 and 6) ----------------
	# Overwintered colonies have modest pollen stores.  Place S_BEE_BREAD cells
	# near the brood nest perimeter (just outside the brood radius) on the same
	# drawn frames that have honey.  Each bee bread cell holds 3 PU.  With
	# pollen_stores = 1.5 lbs we need a small ring of bee bread cells to give
	# the NurseSystem something to pull from on the first few ticks.
	# We seed ~20-30 cells (60-90 PU equivalent) to match realistic stores.
	const BB_FRAMES := [3, 4, 5, 6]
	var bb_placed: int = 0
	var bb_target: int = 25  # ~75 PU worth of bee bread
	for fi in BB_FRAMES:
		if bb_placed >= bb_target:
			break
		var frame: HiveFrame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			if bb_placed >= bb_target:
				break
			for y in FRAME_HEIGHT:
				if bb_placed >= bb_target:
					break
				for x in FRAME_WIDTH:
					if bb_placed >= bb_target:
						break
					var dist: float = _cell_3d_dist(fi, x, y)
					# Bee bread ring: just outside brood zone, inside honey zone
					if dist > OW_BROOD_RADIUS and dist < 0.50:
						var cell_state: int = frame.get_cell(x, y, side)
						if cell_state == S_DRAWN_EMPTY:
							# age field stores PU count for bee bread (3 = full)
							frame.set_cell(x, y, S_BEE_BREAD, 3, side)
							bb_placed += 1

	# -- Winter-bee population -------------------------------------------------
	# Overwintered cluster is ~8,000 adults.  Carniolans winter conservatively.
	# Mostly long-lived winter bees (diutinus) that have not yet transitioned
	# to summer roles.  No drones -- they were expelled in fall.
	nurse_count   = 2500
	house_count   = 3500
	forager_count = 2000
	drone_count   = 0

	# -- Stores ----------------------------------------------------------------
	# Surviving winter consumed ~20-25 lbs.  ~12 lbs remain heading into spring.
	# Pollen stores derived from actual seeded bee bread cells above.
	honey_stores  = 12.0
	pollen_stores = float(bb_placed * NurseSystem.PU_PER_BEE_BREAD_CELL)

	# -- Mites -----------------------------------------------------------------
	# Overwintered mite population -- manageable but present.
	mite_count = 35.0

	# -- State reset -----------------------------------------------------------
	days_elapsed           = 0
	congestion_state       = CongestionState.NORMAL
	consecutive_congestion = 0
	disease_flags          = []

	# -- Queen -----------------------------------------------------------------
	# Uses caller-specified species and grade. Second year, already laying.
	queen = {
		"present":          true,
		"species":          p_species,
		"grade":            p_grade,
		"age_days":         224,
		"temperament":      randf_range(0.90, 1.0),
		"laying_rate":      2000,
		"skip_probability": 0.08,
		"laying_delay":     0,
	}

	# Let _sync_honey_to_frames reconcile any remaining delta between the
	# manually seeded honey cells and the honey_stores weight.
	_sync_honey_to_frames()

	# Register with HiveManager for daily ticking
	HiveManager.register(self)

	# Write initial snapshot
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())

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

func init_as_package(p_species: String = "Carniolan") -> void:
	# Reset boxes -- all 10 frames are empty foundation
	boxes = []
	boxes.append(HiveBox.new(false))
	# HiveFrame._init() already fills with S_EMPTY_FOUNDATION, so no seeding needed

	# Smaller starting population -- loose package bees, no established cohorts
	nurse_count   = 2800
	house_count   = 3200
	forager_count = 1800
	drone_count   = 50

	# Starting stores -- sugar syrup from the package can plus beekeeper feeding.
	# Real package beekeepers feed 1:1 sugar syrup for the first 2-4 weeks to
	# stimulate comb drawing. 4 lbs simulates this standard practice.
	honey_stores  = 4.0     # ~4 lbs equivalent (syrup can + initial feeding)
	pollen_stores = 0.0     # no drawn comb yet, so no bee bread cells possible

	# Very low mite load -- packages are typically treated before shipping
	mite_count = 15.0

	# Reset elapsed state
	days_elapsed           = 0
	congestion_state       = CongestionState.NORMAL
	consecutive_congestion = 0
	disease_flags          = []

	# Queen -- always S-rank for now (nail the best outcome first, tune down later).
	# Species comes from the starting bee species parameter.
	queen = {
		"present":          true,
		"species":          p_species,
		"grade":            "S",
		"age_days":         0,
		"temperament":      randf_range(0.85, 1.0),
		"laying_rate":      2000,    # S-tier: 2000 eggs/day peak
		"skip_probability": 0.08,    # S-tier: minimal skipping
		"laying_delay":     randi_range(4, 6),   # 4-6 days before queen starts laying
	}

	# Register with HiveManager so tick() is called each day
	HiveManager.register(self)

	# Write initial snapshot
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())

# -- Fall-Harvest Initialization -----------------------------------------------
# Called when the player chooses "Start in Fall with 2 Full Supers".
# Represents a strong midsummer colony that has filled two honey supers and
# is ready for fall harvest on day 113 (Full-Earth, Fall M1).
#
# Setup goals:
#   - Peak-summer population (few drones remain in early fall)
#   - Full 10-frame brood box with drawn comb and active brood nest
#   - 2 honey supers attached, both filled with capped honey
#   - honey_stores ~24 lbs  (2 full supers ~8 lbs + brood-box winter stores ~16 lbs)
#   - Manageable mite load (colony was treated in midsummer)
# ------------------------------------------------------------------------------
func init_as_fall_harvest(p_species: String = "Carniolan",
		p_grade: String = "A") -> void:

	# -- Two brood/deep boxes (drawn comb, mixed brood nest + honey arc) ------
	boxes = []
	for deep_idx in range(2):
		var bb: HiveBox = HiveBox.new(false)
		for f_idx in bb.frames.size():
			var frm: HiveFrame = bb.frames[f_idx]
			var is_center: bool = (f_idx >= 2 and f_idx <= 7)
			for side in [frm.cells, frm.cells_b]:
				for i in frm.grid_size:
					var x: int = i % frm.grid_cols
					var y: int = int(float(i) / float(frm.grid_cols))
					var cx: float = abs(float(x) - float(frm.grid_cols) / 2.0) / (float(frm.grid_cols) / 2.0)
					var cy: float = abs(float(y) - float(frm.grid_rows) / 2.0) / (float(frm.grid_rows) / 2.0)
					var dist: float = cx * cx + cy * cy
					if deep_idx == 0:
						# Bottom deep: primary brood nest
						if is_center:
							if dist < 0.25:
								side[i] = S_CAPPED_BROOD
							elif dist < 0.50:
								side[i] = S_DRAWN_EMPTY
							elif dist < 0.80:
								side[i] = S_CAPPED_HONEY
							else:
								side[i] = S_DRAWN_EMPTY
						else:
							if randf() < 0.68:
								side[i] = S_CAPPED_HONEY
							elif randf() < 0.50:
								side[i] = S_BEE_BREAD
							else:
								side[i] = S_DRAWN_EMPTY
					else:
						# Top deep: mostly honey stores + some bee bread
						if is_center:
							if dist < 0.15:
								side[i] = S_DRAWN_EMPTY
							elif dist < 0.65:
								side[i] = S_CAPPED_HONEY
							else:
								side[i] = S_DRAWN_EMPTY
						else:
							if randf() < 0.75:
								side[i] = S_CAPPED_HONEY
							elif randf() < 0.40:
								side[i] = S_BEE_BREAD
							else:
								side[i] = S_DRAWN_EMPTY
		boxes.append(bb)

	# -- Two honey supers (both filled with capped honey) ----------------------
	for _s in range(2):
		var sup: HiveBox = HiveBox.new(true)
		for frm in sup.frames:
			for side in [frm.cells, frm.cells_b]:
				for i in frm.grid_size:
					side[i] = S_CAPPED_HONEY
		boxes.append(sup)

	# -- Population (strong early-fall colony) ---------------------------------
	nurse_count   = 10000
	house_count   = 14000
	forager_count = 8000
	drone_count   = 200   # few drones remain in early fall

	# -- Stores ----------------------------------------------------------------
	# 2 full supers (~8 lbs) + winter stores in 2 deeps (~24 lbs)
	honey_stores  = 32.0
	pollen_stores = 220.0

	# -- Mite load (post midsummer treatment, manageable) ----------------------
	mite_count = 45.0

	# -- State -----------------------------------------------------------------
	days_elapsed           = 112
	congestion_state       = CongestionState.NORMAL
	consecutive_congestion = 0
	disease_flags          = []

	# -- Queen -----------------------------------------------------------------
	queen = {
		"present":          true,
		"species":          p_species,
		"grade":            p_grade,
		"age_days":         224,
		"temperament":      randf_range(0.85, 1.0),
		"laying_rate":      1800,
		"skip_probability": 0.10,
		"laying_delay":     0,
	}

	# Reconcile honey_stores float with seeded comb cells
	_sync_honey_to_frames()

	HiveManager.register(self)
	last_snapshot = SnapshotWriter.write(self, _calculate_health_score())

# -- Daily Tick (called by HiveManager) ----------------------------------------

## Main simulation entry point -- called once per in-game day by HiveManager.
## Runs the full 10-step pipeline: cell aging, population management, forager
## collection, nurse feeding, NU allocation (stores/wax/honey), queen laying,
## mite reproduction, congestion detection, health scoring, and snapshot.
func tick() -> void:
	days_elapsed      += 1
	queen["age_days"] += 1

	var s_factor: float = TimeManager.season_factor()

	# -- Pre-CST full-count pass ------------------------------------------------
	var pre_counts: Dictionary = CellStateTransition.sum_frame_counts(boxes[0].frames)
	var open_larva_count: int = pre_counts[S_OPEN_LARVA]

	# -- Step 1: CellStateTransition -- age/transition every cell ---------------
	var total_adults := nurse_count + house_count + forager_count
	var mite_rate    := clampf(mite_count / maxf(1.0, float(total_adults)), 0.0, 1.0)
	var total_brood: int = (pre_counts[S_EGG] + pre_counts[S_OPEN_LARVA]
		+ pre_counts[S_CAPPED_BROOD] + pre_counts[S_CAPPED_DRONE])
	var chill_risk  := 0.0
	if total_adults < total_brood * 2:
		chill_risk = clampf(
			(float(total_brood) - float(total_adults) * 2.0) / float(total_brood + 1),
			0.0, 0.06
		)

	# Nurse staffing check (lightweight -- just for CST context flags)
	var nurse_ratio: float = float(nurse_count) / maxf(1.0, float(open_larva_count))
	var has_nurses: bool = nurse_count >= 1500 and nurse_ratio >= 0.2
	var capping_delay: int = 0
	if nurse_ratio < 0.4:
		capping_delay = 1
	if nurse_ratio < 0.2:
		capping_delay = 2

	var ctx := {
		"mite_rate":      mite_rate,
		"chill_risk":     chill_risk,
		"afb_active":     disease_flags.has("AFB"),
		"has_nurse_bees": has_nurses,
		"capping_delay":  capping_delay,
	}

	var emerged_workers := 0
	var emerged_drones  := 0

	# Process ALL boxes (brood + supers) so honey in supers ages properly.
	for box_idx in boxes.size():
		var box: HiveBox = boxes[box_idx]
		for frame in box.frames:
			# Side A
			var result_a: Dictionary = CellStateTransition.process_frame(frame, ctx)
			if box_idx == 0:
				emerged_workers += result_a["emerged_workers"]
				emerged_drones  += result_a["emerged_drones"]
			# Side B
			var save_cells = frame.cells
			var save_ages  = frame.cell_age
			frame.cells    = frame.cells_b
			frame.cell_age = frame.cell_age_b
			var result_b: Dictionary = CellStateTransition.process_frame(frame, ctx)
			if box_idx == 0:
				emerged_workers += result_b["emerged_workers"]
				emerged_drones  += result_b["emerged_drones"]
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

	# =========================================================================
	# FORAGER COLLECTION (NU/PU discrete unit economy)
	# =========================================================================
	# 1. Get zone NU/PU totals
	# 2. Divide by number of colonies in zone
	# 3. Each forager collects 2-6 NU and 1-2 PU, capped by zone share
	# =========================================================================
	var zone_nu: int = _get_zone_nu()
	var zone_pu: int = _get_zone_pu()
	var colony_count: int = maxi(1, HiveManager.hive_count())
	@warning_ignore("INTEGER_DIVISION")
	var my_nu: int = zone_nu / colony_count
	@warning_ignore("INTEGER_DIVISION")
	var my_pu: int = zone_pu / colony_count

	var weather_mult: float = 1.0
	if WeatherManager:
		weather_mult = WeatherManager.get_forage_multiplier()

	var forage_result := ForagerSystem.process(
		forager_count, my_nu, my_pu, s_factor * weather_mult, int(congestion_state))
	var nu_in: int = forage_result["nu_collected"]
	var pu_in: int = forage_result["pu_collected"]

	# =========================================================================
	# NURSE NIGHT ACTIONS (2 actions per nurse)
	# =========================================================================
	# Priority 1: Feed all brood with PU (incoming PU, then bee bread reserves)
	# Priority 2: Store excess PU as bee bread
	# Unfed brood is stunted (delayed 1 day, prioritized next night)
	# =========================================================================
	var bee_bread_cell_count: int = pre_counts.get(S_BEE_BREAD, 0)
	var bee_bread_pu: int = bee_bread_cell_count * NurseSystem.PU_PER_BEE_BREAD_CELL

	var nurse_result: Dictionary = NurseSystem.process(
		nurse_count, open_larva_count, pu_in, bee_bread_pu, stunted_brood_count)

	stunted_brood_count = nurse_result["brood_stunted"]

	# Update bee bread stores in frames based on nurse result
	var pu_stored: int = nurse_result["pu_stored"]
	var bb_used: int = nurse_result["bee_bread_used"]
	# Net change to bee bread: stored - used
	var bb_delta: int = pu_stored - bb_used
	if bb_delta > 0:
		_store_bee_bread(bb_delta)
	elif bb_delta < 0:
		_consume_bee_bread(absi(bb_delta))

	# Update pollen_stores tracking variable
	pollen_stores = float(_count_bee_bread_cells() * NurseSystem.PU_PER_BEE_BREAD_CELL)

	# =========================================================================
	# NU ALLOCATION (stores-first, then wax, then extra storage)
	# =========================================================================
	# Real bee behavior:
	#   1. Colony eats daily (subtract consumption from stores).
	#   2. If stores < 2-week consumption forecast: ALL NU -> honey stores.
	#      This is survival mode -- no wax, just bank everything.
	#   3. Once 2-week stores are secure: NU goes to WAX FIRST (comb drawing),
	#      then any leftover NU goes to honey storage.
	#
	# In fall the queen slows laying, fewer mouths to feed, BUT the colony
	# still needs to fill the brood box with winter stores.  Goldenrod/aster
	# flow goes to stores until the 2-week buffer is full, then excess builds
	# comb (if any foundation remains) or overflows into more honey.
	# =========================================================================
	var daily_cost: float = _daily_consumption()
	# Consume feed_stores (sugar syrup) first, then honey_stores
	if feed_stores > 0.0:
		var from_feed: float = minf(feed_stores, daily_cost)
		feed_stores -= from_feed
		daily_cost -= from_feed
	honey_stores = maxf(0.0, honey_stores - daily_cost)

	var two_week_need: float = _daily_consumption() * 14.0
	var stores_secure: bool = (honey_stores + feed_stores) >= two_week_need and two_week_need > 0.0

	var nu_for_wax: int = 0
	var nu_for_honey: int = 0

	if not stores_secure:
		# Survival mode: ALL NU -> honey stores, no wax investment
		nu_for_wax = 0
		nu_for_honey = nu_in
	else:
		# Stores are healthy -- WAX FIRST, remainder to honey.
		# Cap wax at 50% of NU so bees always bank some honey even when flush.
		@warning_ignore("INTEGER_DIVISION")
		nu_for_wax = nu_in / 2
		nu_for_honey = nu_in - nu_for_wax

	# Convert NU to honey (LBS_PER_NU tuned for 80-120 lbs/year harvestable)
	honey_stores += float(nu_for_honey) * LBS_PER_NU

	if days_elapsed % 7 == 0:
		print("[NU ALLOC d%d] stores=%.2f lbs | 2wk_need=%.2f | secure=%s | NU_in=%d wax=%d honey=%d | daily_cost=%.3f" % [
			days_elapsed, honey_stores, two_week_need, str(stores_secure),
			nu_in, nu_for_wax, nu_for_honey, daily_cost])

	# Sync honey stores to frame cells
	_sync_honey_to_frames()

	# -- Comb drawing with wax NU --
	# Only fires when stores are secure (nu_for_wax > 0).
	var foundation_total: int = boxes[0].count_state(S_EMPTY_FOUNDATION)
	if foundation_total > 0 and nu_for_wax > 0:
		_draw_comb_with_nu(foundation_total, nu_for_wax)

	# Super comb drawing -- once brood box is mostly drawn, use wax NU for
	# super comb too. Real bees work supers as soon as brood box is ~60% drawn
	# and a flow is on. Supers store honey ONLY (no brood with queen excluder).
	var brood_drawn_pct: float = 1.0 - float(foundation_total) / 70000.0
	if brood_drawn_pct > 0.60 and boxes.size() > 1 and nu_for_wax > 0:
		for bi in range(1, boxes.size()):
			if boxes[bi].is_super:
				var super_foundation: int = boxes[bi].count_state(S_EMPTY_FOUNDATION)
				if super_foundation > 0:
					_draw_super_comb(bi, super_foundation, 0.5)

	# NOTE: _sync_honey_to_frames() already overflows into supers when brood box
	# has insufficient drawn-empty cells.  _overflow_honey_to_supers() is now
	# redundant and was causing double-deposit conflicts (supers got extra nectar
	# cells beyond what honey_stores warranted, then next tick delta went negative
	# and removed cells from brood box).  Disabled to let sync be the single
	# source of truth for cell<->stores alignment.
	# _overflow_honey_to_supers()

	# -- Step 6: QueenBehavior -- lay eggs --------------------------------------
	var laying_delay: int = queen.get("laying_delay", 0)
	if laying_delay > 0:
		queen["laying_delay"] = laying_delay - 1
	elif queen["present"]:
		_queen_lay(s_factor)

	# -- Post-lay full-count pass -----------------------------------------------
	var post_counts: Dictionary = CellStateTransition.sum_frame_counts(boxes[0].frames)

	# Mite reproduction
	var capped_brood: int = post_counts[S_CAPPED_BROOD] + post_counts.get(S_VARROA, 0)
	var brood_avail := clampf(float(capped_brood) / 16000.0, 0.0, 1.0)
	mite_count += mite_count * 0.017 * brood_avail
	mite_count  = minf(mite_count, 5000.0)

	# -- Step 7: CongestionDetector --
	var brood_cells: int = (post_counts[S_EGG] + post_counts[S_OPEN_LARVA]
		+ post_counts[S_CAPPED_BROOD] + post_counts[S_CAPPED_DRONE]
		+ post_counts.get(S_VARROA, 0))
	var honey_cells: int  = post_counts[S_CAPPED_HONEY] + post_counts[S_PREMIUM_HONEY]
	var foundation_c: int = post_counts[S_EMPTY_FOUNDATION]
	var total_drawn  := FRAME_SIZE * FRAMES_PER_BOX - foundation_c
	var cong_result := CongestionDetector.evaluate(
		brood_cells, honey_cells, total_drawn, consecutive_congestion)
	var new_cong: int = cong_result["state"]
	if new_cong != CongestionState.NORMAL:
		consecutive_congestion += 1
	else:
		consecutive_congestion = 0
	congestion_state = new_cong as CongestionState

	# -- Step 8: Health score --
	var health_score := _calculate_health_score()

	# -- Step 9: Snapshot --
	last_snapshot = SnapshotWriter.write(self, health_score, post_counts)

	# -- Dev diagnostic (every 7 days) --
	if days_elapsed % 7 == 0:
		var total_pop := nurse_count + house_count + forager_count
		var super_honey_cells := 0
		for bi in range(1, boxes.size()):
			if boxes[bi].is_super:
				for frame in boxes[bi].frames:
					super_honey_cells += _count_honey_cells_in_frame(frame)
		var brood_foundation: int = boxes[0].count_state(S_EMPTY_FOUNDATION)
		# Count all honey-chain cells in brood box for diagnostic
		var brood_honey_cells := 0
		for frame in boxes[0].frames:
			brood_honey_cells += _count_honey_cells_in_frame(frame)
		# Count nectar-specific cells (not yet cured)
		var nectar_cells: int = 0
		for frame in boxes[0].frames:
			for i in frame.grid_size:
				if int(frame.cells[i]) == S_NECTAR:
					nectar_cells += 1
				if int(frame.cells_b[i]) == S_NECTAR:
					nectar_cells += 1
		print("[SIM d%d] pop=%d (n=%d h=%d f=%d) honey=%.1f lbs | zoneNU=%d zonePU=%d | NU_in=%d (wax=%d honey=%d)" % [
			days_elapsed, total_pop, nurse_count, house_count, forager_count,
			honey_stores, zone_nu, zone_pu, nu_in, nu_for_wax, nu_for_honey])
		print("  comb=%.0f%% | brood_honey=%d nectar=%d | supers=%d s_honey=%d | bb=%d PU" % [
			(1.0 - float(brood_foundation) / 70000.0) * 100.0,
			brood_honey_cells, nectar_cells,
			super_count(), super_honey_cells, int(pollen_stores)])

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
## Draw comb in a super box. Simpler than brood box -- no 3D ellipsoid,
## bees just draw center-out on each frame. Rate is ~60% of brood box rate
## since bees prefer to work in the brood nest area.
func _draw_super_comb(box_idx: int, _foundation_remaining: int, forage: float) -> void:
	if honey_stores < 1.0:
		return

	# Store multiplier -- scales up as stores increase, encouraging faster
	# drawing during strong flows when the colony has surplus honey.
	var store_mult: float = 1.5
	if honey_stores < 3.0:
		store_mult = 0.50 + 0.50 * (honey_stores - 1.0) / 2.0
	elif honey_stores < 8.0:
		store_mult = 1.0 + 0.20 * (honey_stores - 3.0) / 5.0
	else:
		store_mult = 1.2 + 0.50 * minf(1.0, (honey_stores - 8.0) / 20.0)

	var forager_ratio: float = float(forager_count) / 3000.0
	var forager_mult: float = clampf(0.30 + 0.90 * forager_ratio, 0.30, 1.20)
	var forage_mult: float = 0.15 + 0.85 * forage
	# During a strong flow bees draw super comb eagerly (real beekeepers see
	# a super fully drawn in 1-2 weeks during peak). 0.80 per house bee
	# with multipliers gives ~2000-4000 cells/day at mature colony size.
	var base_rate: float = float(house_count) * 0.80
	var draw_rate: int = int(base_rate * store_mult * forager_mult * forage_mult)
	draw_rate = clampi(draw_rate, 0, 8000)
	if draw_rate <= 0:
		return

	var super_box = boxes[box_idx]
	# Draw center frames first (index 4,5 outward), both sides
	var candidates: Array = []
	for fi in range(super_box.frames.size()):
		var frame: HiveFrame = super_box.frames[fi]
		var frame_dist: float = absf(float(fi) - 4.5) / 5.0
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			var side_cells: PackedByteArray = frame.cells if side == 0 else frame.cells_b
			for y in frame.grid_rows:
				for x in frame.grid_cols:
					var idx: int = y * frame.grid_cols + x
					if int(side_cells[idx]) == S_EMPTY_FOUNDATION:
						# Simple distance from center of frame
						var dx: float = absf(float(x) - float(frame.grid_cols) / 2.0)
						var dy: float = absf(float(y) - float(frame.grid_rows) / 2.0)
						var dist: float = frame_dist + (dx / float(frame.grid_cols) + dy / float(frame.grid_rows))
						candidates.append([dist, fi, side, idx])

	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var drawn := 0
	for c in candidates:
		if drawn >= draw_rate:
			break
		var fi: int   = int(c[1])
		var sd: int   = int(c[2])
		var idx: int  = int(c[3])
		var frame: HiveFrame = super_box.frames[fi]
		if sd == HiveFrame.SIDE_A:
			frame.cells[idx] = S_DRAWN_EMPTY
		else:
			frame.cells_b[idx] = S_DRAWN_EMPTY
		drawn += 1

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

## Simulate the queen's daily egg-laying using a 3D ellipsoid pattern.
## The queen starts at the center of the middle frames and fills outward,
## prioritizing cells closest to the 3D center. This creates the characteristic
## dome of brood visible when you pull frames -- center frames are full, outer
## frames have smaller and smaller brood patches.
## [br][br]
## s_factor: seasonal modifier from TimeManager (0.0 in winter, 1.0 at peak).
## Laying rate is further modified by queen grade, species, age, varroa load,
## and congestion state.
func _queen_lay(s_factor: float) -> void:
	var grade_mod: float   = _grade_modifier(queen["grade"])
	var species_mod: float = _species_seasonal_modifier(queen["species"], s_factor)
	# Karpathy Phase 4+8: queen age curve and varroa/congestion modifiers.
	var age_mod: float     = QueenBehavior.queen_age_multiplier(queen["age_days"])
	var total_adults: int  = nurse_count + house_count + forager_count
	var mites_per_100: float = mite_count / maxf(1.0, float(total_adults)) * 100.0
	var varroa_mod: float  = QueenBehavior.varroa_laying_modifier(mites_per_100)
	var cong_mod: float    = QueenBehavior.congestion_laying_modifier(int(congestion_state))
	# Phase 8 validated: cap congestion penalty at 20% to prevent colony crashes.
	cong_mod = maxf(0.80, cong_mod)
	var target: int = int(float(queen["laying_rate"]) * s_factor * species_mod \
						  * grade_mod * age_mod * varroa_mod * cong_mod)
	if target <= 0:
		return

	var skip_prob: float = queen["skip_probability"]

	# Queen lays in brood box first. Without a queen excluder, she can also
	# move up into supers and lay there (wastes super space with brood).
	# With an excluder installed, queen is restricted to brood box only.
	var layable_boxes: Array = [0]   # always includes brood box
	if not has_excluder and boxes.size() > 1:
		for bi in range(1, boxes.size()):
			if boxes[bi].is_super:
				layable_boxes.append(bi)

	# Collect all eligible cells (drawn, empty, walled-in) with 3D distances.
	var candidates: Array = []   # [dist, box_idx, frame_idx, side, cell_idx]

	for bi in layable_boxes:
		var box: HiveBox = boxes[bi]
		var frames_in_box: int = box.frames.size()
		for fi in range(frames_in_box):
			var frame: HiveFrame = box.frames[fi]
			var f_width: int = frame.grid_cols
			var f_height: int = frame.grid_rows
			for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
				var side_cells: PackedByteArray = frame.cells if side == 0 else frame.cells_b
				for y in f_height:
					for x in f_width:
						var idx: int = y * f_width + x
						var state: int = int(side_cells[idx])
						if state != S_DRAWN_EMPTY:
							continue
						# Walled-in check only for brood box (full hex adjacency)
						if bi == 0 and not _cell_walled_in(side_cells, x, y):
							continue
						var dist: float = _cell_3d_dist(fi, x, y)
						# Brood box: ellipsoid boundary. Supers: queen wanders freely.
						if bi == 0 and dist > 1.0:
							continue
						# Add penalty for super boxes so queen prefers brood box
						var box_penalty: float = float(bi) * 2.0
						candidates.append([dist + box_penalty, bi, fi, side, idx])

	# Sort by distance -- queen fills closest to center first
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	# Lay eggs in order of proximity
	var laid := 0
	for c in candidates:
		if laid >= target:
			break
		if randf() > skip_prob:
			var c_bi: int  = int(c[1])
			var fi: int    = int(c[2])
			var sd: int    = int(c[3])
			var idx: int   = int(c[4])
			var frame = boxes[c_bi].frames[fi]
			if sd == HiveFrame.SIDE_A:
				frame.cells[idx]    = S_EGG
				frame.cell_age[idx] = 0
			else:
				frame.cells_b[idx]    = S_EGG
				frame.cell_age_b[idx] = 0
			laid += 1

# -- (Adult cohort and stores update are now in PopulationCohortManager and ForagerSystem) --

# -- Honey Frame Sync ----------------------------------------------------------

## Reconcile honey_stores (float lbs) with actual cell states on frames.
## Deposits new S_NECTAR cells or removes excess capped honey to keep
## frame cells aligned with the stores value, WITHOUT wiping the natural
## nectar -> curing -> capped -> premium progression that CellStateTransition
## manages each tick. Fills brood box outer frames first, then overflows
## into supers (mimicking real bee behavior).
func _sync_honey_to_frames() -> void:
	# Incremental honey sync -- deposits new nectar cells OR removes excess honey
	# cells to keep frames roughly in line with honey_stores, WITHOUT wiping the
	# natural nectar -> curing -> capped -> premium cell-state progression that
	# CellStateTransition manages each tick.
	#
	# Priority: ALL drawn-empty cells in the hive are eligible for honey deposit.
	# Brood box outer honey frames fill first, then inner frame margins, then
	# super boxes (just like real bees -- fill down, then move up).
	var brood_box: HiveBox = boxes[0]

	# Count existing honey-chain cells across ALL boxes (brood + supers)
	var existing_honey_cells := 0
	for frame in brood_box.frames:
		existing_honey_cells += _count_honey_cells_in_frame(frame)
	for bi in range(1, boxes.size()):
		if boxes[bi].is_super:
			for frame in boxes[bi].frames:
				existing_honey_cells += _count_honey_cells_in_frame(frame)

	var cells_target: int = int(honey_stores / LBS_PER_FULL_FRAME * float(FRAME_SIZE))
	var delta: int = cells_target - existing_honey_cells

	if delta > 0:
		# Need to deposit more nectar cells (new nectar came in).
		# Fill brood box honey frames first, then overflow into supers.
		var remaining: int = delta
		# Brood box outer frames (outermost first)
		for order_idx in [9, 8, 7, 6, 5, 4]:
			if remaining <= 0:
				break
			var fi: int = QUEEN_FRAME_ORDER[order_idx]
			remaining = _deposit_nectar_in_frame(brood_box.frames[fi], remaining)
		# Fallback: inner brood frames (queen center) -- bees store honey in
		# the corners/edges of brood frames too, above and beside the brood nest.
		if remaining > 0:
			for order_idx in [3, 2, 1, 0]:
				if remaining <= 0:
					break
				var fi: int = QUEEN_FRAME_ORDER[order_idx]
				remaining = _deposit_nectar_in_frame(brood_box.frames[fi], remaining)
		# Overflow into supers (bottom super first, then upward)
		for bi in range(1, boxes.size()):
			if remaining <= 0:
				break
			if not boxes[bi].is_super:
				continue
			for frame in boxes[bi].frames:
				if remaining <= 0:
					break
				remaining = _deposit_nectar_in_frame(frame, remaining)
		if days_elapsed % 7 == 0 or remaining > 0:
			print("[HONEY SYNC d%d] stores=%.2f lbs target=%d existing=%d delta=%d deposited=%d still_remaining=%d boxes=%d" % [
				days_elapsed, honey_stores, cells_target, existing_honey_cells,
				delta, delta - remaining, remaining, boxes.size()])
	elif delta < -10:
		# Honey consumed -- remove from brood box first (supers are savings)
		var to_remove: int = absi(delta)
		for order_idx in range(4, 10):
			if to_remove <= 0:
				break
			var fi: int = QUEEN_FRAME_ORDER[order_idx]
			to_remove = _remove_honey_from_frame(brood_box.frames[fi], to_remove)


## Count honey-chain cells (nectar through premium) on both sides of a frame.
func _count_honey_cells_in_frame(frame: HiveFrame) -> int:
	var count := 0
	for i in frame.grid_size:
		var s: int = int(frame.cells[i])
		if s >= CellStateTransition.S_NECTAR and s <= CellStateTransition.S_PREMIUM_HONEY:
			count += 1
		var sb: int = int(frame.cells_b[i])
		if sb >= CellStateTransition.S_NECTAR and sb <= CellStateTransition.S_PREMIUM_HONEY:
			count += 1
	return count


## Deposit S_NECTAR into drawn-empty cells on both sides. Returns remaining to deposit.
func _deposit_nectar_in_frame(frame: HiveFrame, remaining: int) -> int:
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
	return remaining


## Remove capped/premium honey cells from both sides. Returns remaining to remove.
func _remove_honey_from_frame(frame: HiveFrame, to_remove: int) -> int:
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
	return to_remove

# -- Zone NU/PU Queries --------------------------------------------------------
# These functions aggregate nectar/pollen availability from all sources in the
# current zone: flower lifecycle managers, seasonal trees, and barrel feeders.
# The result is divided by colony count in tick() to share resources fairly.

## Get total Nectar Units (NU) available in the zone this tick.
## Sources: FlowerLifecycleManager blooms, SeasonalTree forage, barrel feeders.
func _get_zone_nu() -> int:
	var managers = get_tree().get_nodes_in_group("flower_lifecycle_manager")
	var total: int = 0
	for mgr in managers:
		if mgr.has_method("get_total_zone_nectar"):
			total += int(mgr.get_total_zone_nectar())
	# Also add tree forage contributions
	var month: int = TimeManager.current_month_index()
	if month < 6:
		var trees = get_tree().get_nodes_in_group("trees")
		for tree_node in trees:
			if tree_node.has_method("get_forage_contribution"):
				var contrib: Dictionary = tree_node.get_forage_contribution(month)
				total += int(contrib.get("nectar", 0.0))
	# Barrel feeders inject directly into feed_stores via their own daily tick.
	# They are NOT added to the zone NU pool to avoid double-counting and
	# to keep feed separate from sellable honey.
	# Ambient forage hack removed -- real SeasonalTree nodes on home_property
	# now provide proper NU through the "trees" group forage system above.
	return maxi(0, total)

## Get total Pollen Units (PU) available in the zone this tick.
## Sources: FlowerLifecycleManager blooms, SeasonalTree forage.
func _get_zone_pu() -> int:
	var managers = get_tree().get_nodes_in_group("flower_lifecycle_manager")
	var total: int = 0
	for mgr in managers:
		if mgr.has_method("get_total_zone_pollen"):
			total += int(mgr.get_total_zone_pollen())
	var month: int = TimeManager.current_month_index()
	if month < 6:
		var trees = get_tree().get_nodes_in_group("trees")
		for tree_node in trees:
			if tree_node.has_method("get_forage_contribution"):
				var contrib: Dictionary = tree_node.get_forage_contribution(month)
				total += int(contrib.get("pollen", 0.0))
	# Ambient pollen hack removed -- real SeasonalTree nodes now provide PU.
	return maxi(0, total)

# -- Bee Bread Management -----------------------------------------------------

## Store PU as bee bread in drawn-empty cells of the brood box (outer frames).
## Each bee bread cell holds up to 3 PU (tracked via cell_age as PU count).
func _store_bee_bread(pu_to_store: int) -> void:
	var remaining: int = pu_to_store
	var brood_box: HiveBox = boxes[0]
	# First, top up existing bee bread cells that have < 3 PU
	for fi in range(FRAMES_PER_BOX):
		var frame: HiveFrame = brood_box.frames[fi]
		for i in frame.grid_size:
			if remaining <= 0:
				return
			if int(frame.cells[i]) == S_BEE_BREAD and int(frame.cell_age[i]) < 3:
				var space: int = 3 - int(frame.cell_age[i])
				var add: int = mini(space, remaining)
				frame.cell_age[i] = frame.cell_age[i] + add
				remaining -= add
			if int(frame.cells_b[i]) == S_BEE_BREAD and int(frame.cell_age_b[i]) < 3:
				var space: int = 3 - int(frame.cell_age_b[i])
				var add: int = mini(space, remaining)
				frame.cell_age_b[i] = frame.cell_age_b[i] + add
				remaining -= add
	# Then create new bee bread cells from drawn-empty cells (outer frames first)
	for order_idx in [9, 8, 7, 6, 5, 4]:
		if remaining <= 0:
			return
		var fi: int = QUEEN_FRAME_ORDER[order_idx]
		var frame: HiveFrame = brood_box.frames[fi]
		for i in frame.grid_size:
			if remaining <= 0:
				return
			if int(frame.cells[i]) == S_DRAWN_EMPTY:
				frame.cells[i] = S_BEE_BREAD
				var pu: int = mini(3, remaining)
				frame.cell_age[i] = pu
				remaining -= pu
		for i in frame.grid_size:
			if remaining <= 0:
				return
			if int(frame.cells_b[i]) == S_DRAWN_EMPTY:
				frame.cells_b[i] = S_BEE_BREAD
				var pu: int = mini(3, remaining)
				frame.cell_age_b[i] = pu
				remaining -= pu


## Consume PU from bee bread cells. Empties cells once depleted.
func _consume_bee_bread(pu_to_consume: int) -> void:
	var remaining: int = pu_to_consume
	var brood_box: HiveBox = boxes[0]
	for fi in range(FRAMES_PER_BOX):
		var frame: HiveFrame = brood_box.frames[fi]
		for i in frame.grid_size:
			if remaining <= 0:
				return
			if int(frame.cells[i]) == S_BEE_BREAD:
				var avail: int = int(frame.cell_age[i])
				var take: int = mini(avail, remaining)
				frame.cell_age[i] = avail - take
				remaining -= take
				if frame.cell_age[i] <= 0:
					frame.cells[i] = S_DRAWN_EMPTY
					frame.cell_age[i] = 0
			if int(frame.cells_b[i]) == S_BEE_BREAD:
				var avail: int = int(frame.cell_age_b[i])
				var take: int = mini(avail, remaining)
				frame.cell_age_b[i] = avail - take
				remaining -= take
				if frame.cell_age_b[i] <= 0:
					frame.cells_b[i] = S_DRAWN_EMPTY
					frame.cell_age_b[i] = 0


## Count total bee bread cells in the brood box.
func _count_bee_bread_cells() -> int:
	var count: int = 0
	for frame in boxes[0].frames:
		for i in frame.grid_size:
			if int(frame.cells[i]) == S_BEE_BREAD:
				count += 1
			if int(frame.cells_b[i]) == S_BEE_BREAD:
				count += 1
	return count


# -- NU-based Comb Drawing -----------------------------------------------------

## Draw comb using NU wax budget. Each NU of wax draws ~2-3 cells.
## Replaces the old store_mult-based system with direct NU input.
func _draw_comb_with_nu(_foundation_remaining: int, nu_wax: int) -> void:
	# Stores check now handled upstream by wax_fraction allocation.
	# nu_wax will be 0 if stores are too low.
	# Each NU of wax draws ~3 cells (game balance tuning)
	var draw_rate: int = nu_wax * 3
	# Also factor in house bee count -- need workers to actually build
	var house_factor: float = clampf(float(house_count) / 2000.0, 0.1, 1.5)
	draw_rate = int(float(draw_rate) * house_factor)
	draw_rate = clampi(draw_rate, 0, 5000)
	if draw_rate <= 0:
		return

	# Collect all foundation cells with 3D distance, sort center-out
	var candidates: Array = []
	var brood_box: HiveBox = boxes[0]
	for fi in range(FRAMES_PER_BOX):
		var frame: HiveFrame = brood_box.frames[fi]
		for side in [HiveFrame.SIDE_A, HiveFrame.SIDE_B]:
			var side_cells: PackedByteArray = frame.cells if side == 0 else frame.cells_b
			for y in FRAME_HEIGHT:
				for x in FRAME_WIDTH:
					var idx: int = y * FRAME_WIDTH + x
					if int(side_cells[idx]) == S_EMPTY_FOUNDATION:
						var dist: float = _cell_3d_dist(fi, x, y)
						candidates.append([dist, fi, side, idx])

	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

	var drawn := 0
	for c in candidates:
		if drawn >= draw_rate:
			break
		var fi: int   = int(c[1])
		var sd: int   = int(c[2])
		var idx: int  = int(c[3])
		var frame: HiveFrame = brood_box.frames[fi]
		if sd == HiveFrame.SIDE_A:
			frame.cells[idx] = S_DRAWN_EMPTY
		else:
			frame.cells_b[idx] = S_DRAWN_EMPTY
		drawn += 1

	# Wax costs honey
	var honey_cost: float = float(drawn) * 0.0004
	honey_stores = maxf(0.0, honey_stores - honey_cost)


# -- Overflow honey into supers ------------------------------------------------
# NOTE: This function is currently DISABLED (not called from tick()).
# _sync_honey_to_frames() now handles overflow into supers as the single
# source of truth for cell<->stores alignment. Kept for potential future use
# or if the sync approach needs to be revisited.

## [DISABLED] Once brood box honey frames are full, push excess into super boxes.
## Supers store honey ONLY -- no brood, no bee bread.
## Was causing double-deposit conflicts with _sync_honey_to_frames().
func _overflow_honey_to_supers() -> void:
	if boxes.size() <= 1:
		return
	# Check if brood box honey frames have space
	var brood_box: HiveBox = boxes[0]
	var brood_honey_capacity: int = 0
	var brood_honey_current: int = 0
	for order_idx in range(4, 10):
		var fi: int = QUEEN_FRAME_ORDER[order_idx]
		var frame: HiveFrame = brood_box.frames[fi]
		for i in frame.grid_size:
			var s: int = int(frame.cells[i])
			if s == S_DRAWN_EMPTY:
				brood_honey_capacity += 1
			elif s >= S_NECTAR and s <= S_PREMIUM_HONEY:
				brood_honey_current += 1
		for i in frame.grid_size:
			var sb: int = int(frame.cells_b[i])
			if sb == S_DRAWN_EMPTY:
				brood_honey_capacity += 1
			elif sb >= S_NECTAR and sb <= S_PREMIUM_HONEY:
				brood_honey_current += 1

	# If brood box still has room, no overflow needed
	if brood_honey_capacity > 100:
		return

	# Calculate how much honey should go to supers
	var excess_honey: float = honey_stores - float(brood_honey_current) * 0.00143
	if excess_honey <= 0.0:
		return

	# Deposit excess into super frames
	var cells_to_deposit: int = int(excess_honey / 0.00143)
	var remaining: int = cells_to_deposit
	for bi in range(1, boxes.size()):
		if remaining <= 0:
			break
		if not boxes[bi].is_super:
			continue
		for frame in boxes[bi].frames:
			if remaining <= 0:
				break
			remaining = _deposit_nectar_in_frame(frame, remaining)


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
## Returns true if added, false if max deeps reached (limit 3).
func add_deep() -> bool:
	if deep_count() >= 3:
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
## Returns true if added, false if max supers reached (limit 5).
func add_super() -> bool:
	if super_count() >= 5:
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
			var honey_lbs: float = (float(capped) / float(frame.grid_size * 2)) * frame.lbs_per_full_frame()
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

## Returns per-super visual data for the overworld hive sprite system.
## Each entry is a dict: { fill_pct, capping_pct, drawn_pct, honey_cells,
## capped_cells, total_honey_cells, capacity }
## fill_pct: 0.0-1.0, fraction of super capacity holding any honey-chain cell.
## capping_pct: 0.0-1.0, fraction of honey-chain cells that are capped/premium.
## drawn_pct: 0.0-1.0, fraction of foundation that has been drawn into comb.
func get_super_visual_data() -> Array:
	var result: Array = []
	for bi in boxes.size():
		var box: HiveBox = boxes[bi]
		if not box.is_super:
			continue
		var capacity: int = 0   # total cells on both sides
		var drawn: int = 0      # non-foundation cells
		var honey_total: int = 0
		var capped: int = 0
		for frame in box.frames:
			var fs: int = frame.grid_size
			capacity += fs * 2
			for side_cells in [frame.cells, frame.cells_b]:
				for i in fs:
					var s: int = int(side_cells[i])
					if s != CellStateTransition.S_EMPTY_FOUNDATION:
						drawn += 1
					if s == CellStateTransition.S_NECTAR or s == CellStateTransition.S_CURING_HONEY:
						honey_total += 1
					elif s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
						honey_total += 1
						capped += 1
		var fill_pct: float = float(honey_total) / maxf(1.0, float(capacity))
		var cap_pct: float = float(capped) / maxf(1.0, float(honey_total)) if honey_total > 0 else 0.0
		var drawn_pct: float = float(drawn) / maxf(1.0, float(capacity))
		result.append({
			"box_idx": bi,
			"fill_pct": fill_pct,
			"capping_pct": cap_pct,
			"drawn_pct": drawn_pct,
			"honey_cells": honey_total,
			"capped_cells": capped,
			"capacity": capacity,
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

## Add a disease flag (e.g. "AFB", "EFB", "SHB") if not already present.
func add_disease(flag: String) -> void:
	if not disease_flags.has(flag):
		disease_flags.append(flag)

## Remove a disease flag from this colony.
func clear_disease(flag: String) -> void:
	disease_flags.erase(flag)

## Apply a mite treatment that reduces mite_count by the given fraction (0.0-1.0).
func treat_mites(reduction: float) -> void:
	mite_count = maxf(0.0, mite_count * (1.0 - reduction))

# -- Helpers -------------------------------------------------------------------

## Return the laying rate multiplier for the given queen grade (S/A/B/C/D).
## Delegates to QueenBehavior. S = 1.0 (best real queens), lower grades scale down.
func _grade_modifier(grade: String) -> float:
	# Validated by Karpathy Phase 4: S-tier = 1.00 baseline (best real queens).
	# S is the ceiling, lower grades scale down from there.
	return QueenBehavior.grade_modifier(grade)

## Return the species-specific seasonal laying modifier.
## e.g. Carniolans shut down hard in winter but ramp aggressively in spring.
func _species_seasonal_modifier(species: String, s_factor: float) -> float:
	return QueenBehavior.species_seasonal_modifier(species, s_factor)

## Calculate daily honey consumption (lbs) based on total adult population.
## In winter, uses a cluster thermogenesis model where larger clusters are
## more efficient (lower surface:volume ratio), keeping total consumption
## roughly constant (~0.525 lbs/day) regardless of cluster size.
## Science: Farrar (1943), Seeley (1995) S7.
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

## Calculate composite health score (0-100) for this colony.
## Factors: queen presence/grade, mite load per 100 bees, honey stores,
## pollen stores, and active disease flags. Used by SnapshotWriter and UI.
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


# -- Tomorrow Forecast (dev mode) --------------------------------------------
# Estimates how many wax cells, bee bread cells, and honey cells will be
# created tomorrow.  Uses the SAME formulas as tick() but without mutating
# any state.  Returns a Dictionary with keys:
#   "wax_cells"       : int  -- new comb cells drawn from foundation
#   "bee_bread_cells"  : int  -- net new bee bread cells stored
#   "honey_cells"      : int  -- net new honey cells deposited
#   "eggs_laid"        : int  -- queen eggs laid tomorrow (estimate)
# All values are estimates (weather variance and random forager rolls are
# replaced with their expected-value averages).

func forecast_tomorrow() -> Dictionary:
	# -- Season / weather -------------------------------------------------
	var s_factor: float = TimeManager.season_factor()
	var weather_mult: float = 1.0
	if WeatherManager:
		weather_mult = WeatherManager.get_forage_multiplier()

	# -- Zone resources ---------------------------------------------------
	var zone_nu: int = _get_zone_nu()
	var zone_pu: int = _get_zone_pu()
	var colony_count: int = maxi(1, HiveManager.hive_count())
	@warning_ignore("INTEGER_DIVISION")
	var my_nu: int = zone_nu / colony_count
	@warning_ignore("INTEGER_DIVISION")
	var my_pu: int = zone_pu / colony_count

	# -- Forager collection (expected value, no random roll) ---------------
	var avg_nu_per: float = float(ForagerSystem.NU_PER_FORAGER_MIN + ForagerSystem.NU_PER_FORAGER_MAX) / 2.0
	var avg_pu_per: float = float(ForagerSystem.PU_PER_FORAGER_MIN + ForagerSystem.PU_PER_FORAGER_MAX) / 2.0
	var raw_nu: int = int(float(forager_count) * avg_nu_per * s_factor * weather_mult)
	var raw_pu: int = int(float(forager_count) * avg_pu_per * s_factor * weather_mult)
	if int(congestion_state) == 3:
		raw_nu = int(float(raw_nu) * (1.0 - ForagerSystem.CONGESTION_PENALTY))
		raw_pu = int(float(raw_pu) * (1.0 - ForagerSystem.CONGESTION_PENALTY))
	var nu_in: int = mini(raw_nu, my_nu)
	var pu_in: int = mini(raw_pu, my_pu)

	# -- NU allocation (stores-first, then wax, then storage) ---------------
	var f_daily_cost: float = _daily_consumption()
	var f_two_week: float = f_daily_cost * 14.0
	var f_stores_ok: bool = honey_stores >= f_two_week and f_two_week > 0.0
	var nu_for_wax: int = 0
	var nu_for_honey: int = nu_in
	if f_stores_ok:
		@warning_ignore("INTEGER_DIVISION")
		nu_for_wax = nu_in / 2
		nu_for_honey = nu_in - nu_for_wax

	# -- Wax cells forecast ------------------------------------------------
	var est_wax: int = 0
	if nu_for_wax > 0:
		var draw_rate: int = nu_for_wax * 3
		var house_factor: float = clampf(float(house_count) / 2000.0, 0.1, 1.5)
		draw_rate = int(float(draw_rate) * house_factor)
		var foundation_total: int = boxes[0].count_state(S_EMPTY_FOUNDATION)
		est_wax = clampi(draw_rate, 0, foundation_total)

	# -- Bee bread forecast ------------------------------------------------
	# Nurses feed brood first (1 PU per open larva), then store excess as
	# bee bread.  Each bee bread cell holds 3 PU.
	var open_larva: int = 0
	var pre_counts: Dictionary = CellStateTransition.sum_frame_counts(boxes[0].frames)
	open_larva = pre_counts.get(S_OPEN_LARVA, 0)
	var pu_for_brood: int = mini(pu_in, open_larva)
	var pu_leftover: int = maxi(0, pu_in - pu_for_brood)
	# Net bee bread = stored - consumed from reserves
	# If incoming PU was enough to feed all brood, no reserves consumed.
	# If not, reserves are consumed (negative bb delta).
	var pu_from_reserves: int = 0
	if pu_for_brood < open_larva:
		pu_from_reserves = mini(open_larva - pu_for_brood,
			_count_bee_bread_cells() * NurseSystem.PU_PER_BEE_BREAD_CELL)
	@warning_ignore("INTEGER_DIVISION")
	var est_bb_new: int = pu_leftover / NurseSystem.PU_PER_BEE_BREAD_CELL
	@warning_ignore("INTEGER_DIVISION")
	var est_bb_consumed: int = pu_from_reserves / NurseSystem.PU_PER_BEE_BREAD_CELL
	var est_bb_net: int = est_bb_new - est_bb_consumed

	# -- Honey cells forecast ----------------------------------------------
	# New honey = NU for honey converted to lbs, then to cells.
	# LBS_PER_NU lbs per NU.  Each honey cell ~ 0.00143 lbs.
	var new_honey_lbs: float = float(nu_for_honey) * LBS_PER_NU
	var consumption: float = _daily_consumption()
	var net_honey_lbs: float = new_honey_lbs - consumption
	# Approximate cells: 1 cell ~ 0.00143 lbs (from LBS_PER_FULL_SUPER / cells)
	var est_honey: int = int(net_honey_lbs / 0.00143) if net_honey_lbs > 0.0 else 0

	# -- Eggs forecast -----------------------------------------------------
	var est_eggs: int = 0
	var laying_delay: int = queen.get("laying_delay", 0)
	if laying_delay <= 1 and queen["present"]:
		var grade_mod: float = _grade_modifier(queen["grade"])
		var species_mod: float = _species_seasonal_modifier(queen["species"], s_factor)
		var age_mod: float = QueenBehavior.queen_age_multiplier(queen["age_days"])
		var total_adults: int = nurse_count + house_count + forager_count
		var mites_per_100: float = mite_count / maxf(1.0, float(total_adults)) * 100.0
		var varroa_mod: float = QueenBehavior.varroa_laying_modifier(mites_per_100)
		var cong_mod: float = maxf(0.80, QueenBehavior.congestion_laying_modifier(int(congestion_state)))
		est_eggs = int(float(queen["laying_rate"]) * s_factor * species_mod * grade_mod * age_mod * varroa_mod * cong_mod)

	return {
		"wax_cells": est_wax,
		"bee_bread_cells": est_bb_net,
		"honey_cells": est_honey,
		"eggs_laid": est_eggs,
	}
