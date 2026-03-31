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

func _init() -> void:
	cells   = PackedByteArray()
	cells_b = PackedByteArray()
	cells.resize(SUPER_SIZE)
	cells_b.resize(SUPER_SIZE)
	cells.fill(CellStateTransition.S_EMPTY_FOUNDATION)
	cells_b.fill(CellStateTransition.S_EMPTY_FOUNDATION)

# Required by FrameRenderer dirty-check / geometry path
func get_cell(x: int, y: int, side: int = 0) -> int:
	var i: int = y * grid_cols + x
	return int(cells[i]) if side == 0 else int(cells_b[i])

# Fill both sides with a realistic honey-super distribution:
#   capping_pct % of cells -> S_CAPPED_HONEY
#   some residual cells    -> S_CURING_HONEY (nearly capped)
#   remainder              -> S_DRAWN_EMPTY (empty drawn comb)
func fill_for_harvest(capping_pct: float) -> void:
	var cap_norm: float = clampf(capping_pct / 100.0, 0.0, 1.0)
	var curing_pct: float = (1.0 - cap_norm) * 0.5  # half the uncapped cells are curing
	# Build fresh local arrays, then assign -- avoids any copy-on-write ambiguity
	var new_a: PackedByteArray = PackedByteArray()
	var new_b: PackedByteArray = PackedByteArray()
	new_a.resize(SUPER_SIZE)
	new_b.resize(SUPER_SIZE)
	for i in SUPER_SIZE:
		new_a[i] = _pick_state(cap_norm, curing_pct)
		new_b[i] = _pick_state(cap_norm, curing_pct)
	cells   = new_a
	cells_b = new_b

func _pick_state(cap_norm: float, curing_norm: float) -> int:
	var r: float = randf()
	if r < cap_norm:
		# Harvest-ready frames have aged to premium honey (S_PREMIUM_HONEY = 9)
		return CellStateTransition.S_PREMIUM_HONEY
	elif r < cap_norm + curing_norm:
		return CellStateTransition.S_CURING_HONEY
	else:
		return CellStateTransition.S_DRAWN_EMPTY

# Count capped cells on one side (used for progress tracking)
func count_capped(side: int = 0) -> int:
	var arr: PackedByteArray = cells if side == 0 else cells_b
	var n: int = 0
	for i in SUPER_SIZE:
		var s: int = int(arr[i])
		if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
			n += 1
	return n
