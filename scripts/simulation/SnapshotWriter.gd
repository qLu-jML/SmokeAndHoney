# SnapshotWriter.gd
# -----------------------------------------------------------------------------
# Pipeline Step 9 -- Snapshot Serialiser
#
# Collects all colony metrics into a flat Dictionary that other systems
# (hive.gd label, InspectionOverlay, HUD, save system) can read safely
# without holding a live reference to internal HiveSimulation state.
#
# The snapshot is written once per tick at the end of the pipeline.
# Outside consumers should treat last_snapshot as read-only.
#
# KEYS produced:
#   days_elapsed    int      -- total days since hive was placed
#   queen_present   bool
#   queen_grade     String   -- "A+", "A", "B", "C", "D"
#   queen_species   String   -- "Italian", "Carniolan", etc.
#   queen_age       int      -- days the queen has been laying
#   egg_count       int
#   larva_count     int
#   capped_count    int
#   drone_count     int
#   varroa_cells    int      -- cells in S_VARROA state
#   afb_cells       int      -- cells in S_AFB state
#   nurse_count     int
#   house_count     int
#   forager_count   int
#   total_adults    int
#   honey_stores    float    -- lbs of capped honey equivalent
#   pollen_stores   float    -- lbs
#   mite_count      float    -- raw mite number
#   congestion_state int     -- HiveSimulation.CongestionState value
#   health_score    float    -- 0-100 composite score
#   afb_active      bool     -- true if AFB disease flag is set
# -----------------------------------------------------------------------------
extends RefCounted
class_name SnapshotWriter

## Build and return the snapshot dictionary from a live HiveSimulation.
## Pass a pre-calculated health_score to avoid re-running HiveHealthCalculator here.
## Pass frame_counts (from CellStateTransition.sum_frame_counts) when available --
## this skips 5 separate count_state() passes that each scan 35,000 cells.
static func write(hive_sim: HiveSimulation, health_score: float,
                  frame_counts: Dictionary = {}) -> Dictionary:

	var egg_count:    int
	var larva_count:  int
	var capped_count: int
	var varroa_cells: int
	var afb_cells:    int

	if frame_counts.is_empty():
		# Fallback path (e.g. harvest_honey or _ready snapshot): scan frames now.
		var brood_box = hive_sim.boxes[0]
		var c: Dictionary = CellStateTransition.sum_frame_counts(brood_box.frames)
		egg_count    = c[CellStateTransition.S_EGG]
		larva_count  = c[CellStateTransition.S_OPEN_LARVA]
		capped_count = c[CellStateTransition.S_CAPPED_BROOD] + c[CellStateTransition.S_CAPPED_DRONE]
		varroa_cells = c[CellStateTransition.S_VARROA]
		afb_cells    = c[CellStateTransition.S_AFB]
	else:
		# Hot path: reuse the counts already computed in tick().
		egg_count    = frame_counts[CellStateTransition.S_EGG]
		larva_count  = frame_counts[CellStateTransition.S_OPEN_LARVA]
		capped_count = frame_counts[CellStateTransition.S_CAPPED_BROOD] \
		             + frame_counts[CellStateTransition.S_CAPPED_DRONE]
		varroa_cells = frame_counts[CellStateTransition.S_VARROA]
		afb_cells    = frame_counts[CellStateTransition.S_AFB]

	var total_adults: int = hive_sim.nurse_count + hive_sim.house_count + hive_sim.forager_count

	return {
		"days_elapsed"     : hive_sim.days_elapsed,
		"queen_present"    : hive_sim.queen.get("present",     true),
		"queen_grade"      : hive_sim.queen.get("grade",       "B"),
		"queen_species"    : hive_sim.queen.get("species",     "Italian"),
		"queen_age"        : hive_sim.queen.get("age_days",    0),
		"egg_count"        : egg_count,
		"larva_count"      : larva_count,
		"capped_count"     : capped_count,
		"varroa_cells"     : varroa_cells,
		"afb_cells"        : afb_cells,
		"nurse_count"      : hive_sim.nurse_count,
		"house_count"      : hive_sim.house_count,
		"forager_count"    : hive_sim.forager_count,
		"drone_count"      : hive_sim.drone_count,
		"total_adults"     : total_adults,
		"honey_stores"     : hive_sim.honey_stores,
		"pollen_stores"    : hive_sim.pollen_stores,
		"mite_count"       : hive_sim.mite_count,
		"congestion_state" : hive_sim.congestion_state,
		"health_score"     : health_score,
		"afb_active"       : hive_sim.disease_flags.has("AFB"),
	}
