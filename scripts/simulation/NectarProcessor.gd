# NectarProcessor.gd
# -----------------------------------------------------------------------------
# Pipeline Step 5 -- Nectar -> Honey Conversion Logistics
#
# Converts raw nectar weight into in-frame cell deposits.
# The actual cell-state transitions (nectar->curing->capped->premium) are driven
# by CellStateTransition on subsequent ticks.  This step determines *how many*
# new S_NECTAR cells are written into drawn-empty frame cells.
#
# Nectar conversion ratio: 5 lbs nectar -> 1 lb honey (approx).
# One S_CAPPED_HONEY cell holds 1/3500 x 5.0 lbs ? 0.00143 lbs.
#
# INPUTS:
#   nectar_collected -- float lbs from ForagerSystem
#   frames           -- Array[HiveFrame] to deposit into (supers first, then brood)
#
# OUTPUTS:
#   { "cells_deposited" : int }
#
# STATUS: STUB -- HiveSimulation._sync_honey_to_frames() does this inline today.
# -----------------------------------------------------------------------------
extends RefCounted
class_name NectarProcessor

const LBS_PER_FULL_DEEP  := 5.0    # lbs honey in a full deep frame
const LBS_PER_FULL_SUPER := 4.0    # lbs honey in a full super frame (40 lbs per 10-frame super)
const DEEP_SIZE          := 3500
const SUPER_SIZE         := 2450

## Returns lbs-per-cell for a given frame (accounts for deep vs super grid size).
static func lbs_per_cell(frame) -> float:
	var full_lbs: float = frame.lbs_per_full_frame() if frame.has_method("lbs_per_full_frame") else LBS_PER_FULL_DEEP
	var size: int = frame.grid_size if &"grid_size" in frame else DEEP_SIZE
	return full_lbs / float(size)

static func process(nectar_lbs: float, frames: Array) -> Dictionary:
	var deposited    := 0
	# Calculate cells_needed per-frame because deep vs super frames hold different amounts
	var remaining_lbs := nectar_lbs

	for frame in frames:
		if remaining_lbs <= 0.0:
			break
		var per_cell := lbs_per_cell(frame)
		var f_size: int = frame.grid_size if &"grid_size" in frame else DEEP_SIZE
		# Deposit on side A
		for i in f_size:
			if remaining_lbs <= 0.0:
				break
			if frame.cells[i] == CellStateTransition.S_DRAWN_EMPTY:
				frame.cells[i]    = CellStateTransition.S_NECTAR
				frame.cell_age[i] = 0
				deposited         += 1
				remaining_lbs     -= per_cell
		# Deposit on side B
		for i in f_size:
			if remaining_lbs <= 0.0:
				break
			if frame.cells_b[i] == CellStateTransition.S_DRAWN_EMPTY:
				frame.cells_b[i]    = CellStateTransition.S_NECTAR
				frame.cell_age_b[i] = 0
				deposited           += 1
				remaining_lbs       -= per_cell

	return { "cells_deposited": deposited }
