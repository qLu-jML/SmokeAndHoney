# ScrapeFrame.gd
# Minimal super-frame data object for the scraping/uncapping minigame.
# Mirrors the interface FrameRenderer expects (same as HiveSimulation.HiveFrame)
# so render_honeycomb() can consume it directly.
#
# Usage:
#   var sf := ScrapeFrame.new()
#   sf.fill_for_harvest(85.0)   # 85% capped honey
#   var tex := renderer.render_honeycomb(sf, 0)
# -----------------------------------------------------------------------------
extends RefCounted
class_name ScrapeFrame

# Medium super frame: 70 cols x 35 rows = 2450 cells per side
const SUPER_COLS := 70
const SUPER_ROWS := 35
const SUPER_SIZE := 2450

var cells:      PackedByteArray   # Side A cell states
var cells_b:    PackedByteArray   # Side B cell states
var grid_cols:  int = SUPER_COLS
var grid_rows:  int = SUPER_ROWS
var grid_size:  int = SUPER_SIZE

## Initialize a super frame with empty foundation on both sides.
func _init() -> void:
	cells   = PackedByteArray()
	cells_b = PackedByteArray()
	cells.resize(SUPER_SIZE)
	cells_b.resize(SUPER_SIZE)
	cells.fill(CellStateTransition.S_EMPTY_FOUNDATION)
	cells_b.fill(CellStateTransition.S_EMPTY_FOUNDATION)

## Get cell state at (x,y) on the given side (0=A, 1=B).
## Required by FrameRenderer dirty-check and geometry path.
func get_cell(x: int, y: int, side: int = 0) -> int:
	var i: int = y * grid_cols + x
	return int(cells[i]) if side == 0 else int(cells_b[i])

## Fill both sides with realistic honey-super distribution for harvest minigame.
## capping_pct: percentage of cells to mark as capped (S_PREMIUM_HONEY).
## Remainder marked as S_CURING_HONEY (still ripening). No empty cells.
func fill_for_harvest(capping_pct: float) -> void:
	var cap_norm: float = clampf(capping_pct / 100.0, 0.0, 1.0)
	# Build fresh local arrays, then assign -- avoids any copy-on-write ambiguity
	var new_a: PackedByteArray = PackedByteArray()
	var new_b: PackedByteArray = PackedByteArray()
	new_a.resize(SUPER_SIZE)
	new_b.resize(SUPER_SIZE)
	for i in SUPER_SIZE:
		new_a[i] = _pick_state(cap_norm)
		new_b[i] = _pick_state(cap_norm)
	cells   = new_a
	cells_b = new_b

## Pick a state (PREMIUM_HONEY or CURING_HONEY) based on capping percentage.
func _pick_state(cap_norm: float) -> int:
	var r: float = randf()
	if r < cap_norm:
		# Capped cells are premium honey: aged, ready to harvest
		return CellStateTransition.S_PREMIUM_HONEY
	else:
		# Uncapped cells are still curing -- honey is present but not yet sealed
		return CellStateTransition.S_CURING_HONEY

## Fill from actual hive frame cell data (preserves exact inspection appearance).
## cells_a and cells_b must be PackedByteArray of length >= SUPER_SIZE.
@warning_ignore("shadowed_variable")
func fill_from_hive_data(cells_a: PackedByteArray, cells_b: PackedByteArray) -> void:
	var new_a: PackedByteArray = PackedByteArray()
	var new_b: PackedByteArray = PackedByteArray()
	new_a.resize(SUPER_SIZE)
	new_b.resize(SUPER_SIZE)
	var src_len_a: int = cells_a.size()
	var src_len_b: int = cells_b.size()
	for i in SUPER_SIZE:
		# Copy real state; default to premium honey if source is shorter
		new_a[i] = int(cells_a[i]) if i < src_len_a else CellStateTransition.S_PREMIUM_HONEY
		new_b[i] = int(cells_b[i]) if i < src_len_b else CellStateTransition.S_PREMIUM_HONEY
	cells   = new_a
	cells_b = new_b

## Count capped honey cells on one side (used for progress tracking).
## Returns number of S_CAPPED_HONEY or S_PREMIUM_HONEY cells on the given side.
func count_capped(side: int = 0) -> int:
	var arr: PackedByteArray = cells if side == 0 else cells_b
	var n: int = 0
	for i in SUPER_SIZE:
		var s: int = int(arr[i])
		if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
			n += 1
	return n
