# CongestionDetector.gd
# -----------------------------------------------------------------------------
# Pipeline Step 7 -- Hive Congestion Analysis
#
# Determines whether the colony is space-constrained.  There are four states:
#
#   NORMAL          -- adequate empty cells for queen and storage
#   BROOD_BOUND     -- brood occupies so much space the queen can't lay more
#   HONEY_BOUND     -- honey storage is full, foragers store in brood area
#   FULLY_CONGESTED -- both brood and honey crowding simultaneously
#
# Output feeds back into ForagerSystem (nectar acceptance) and QueenBehavior
# (swarm impulse) on subsequent ticks.
#
# Thresholds are expressed as fractions of total drawn-comb cells.
#
# -----------------------------------------------------------------------------
# Science references:
#   Seeley (2010) "Honeybee Democracy" -- swarm preparation triggers
#   Winston (1987) -- honey-bound and brood-bound colony behavior
# -----------------------------------------------------------------------------
extends RefCounted
class_name CongestionDetector

# Fraction of cells that must be honey/nectar to trigger HONEY_BOUND.
# Science: colonies begin storing nectar in the brood area (honey-bound behavior)
# when honey occupies ~60-65% of available drawn comb.
# Previous value 0.70 was slightly too permissive.
const HONEY_BOUND_THRESHOLD  := 0.62   # was 0.70

# Fraction of cells that must be brood to trigger BROOD_BOUND.
# Science: queen cell construction (swarm prep) begins when the queen struggles
# to find laying space -- typically at ~65-70% brood density.
# Previous value 0.75 meant the colony was already in severe distress before
# brood-bound was flagged.
const BROOD_BOUND_THRESHOLD  := 0.65   # was 0.75

# Total occupancy threshold for swarm prep to begin.
# Science: Seeley (2010) documents swarm preparations starting when brood +
# honey together occupy ~78-82% of the brood box.
const SWARM_PREP_THRESHOLD   := 0.78

## Evaluate congestion given cell counts from a HiveSimulation's boxes.
## Returns one of HiveSimulation.CongestionState as an int (0-3).
## consecutive_congestion: how many consecutive ticks the colony has been in
##   a non-NORMAL congestion state (from HiveSimulation.consecutive_congestion).
##   Used to gate swarm_prep -- a single crowded day doesn't trigger swarm impulse.
static func evaluate(brood_cells: int,
                     honey_cells:  int,
                     total_drawn:  int,
                     consecutive_congestion: int = 0) -> Dictionary:
	if total_drawn <= 0:
		return {"state": 0, "swarm_prep": false}   # NORMAL

	var brood_frac := float(brood_cells) / float(total_drawn)
	var honey_frac := float(honey_cells) / float(total_drawn)

	var brood_bound := brood_frac >= BROOD_BOUND_THRESHOLD
	var honey_bound := honey_frac >= HONEY_BOUND_THRESHOLD

	var state: int
	if brood_bound and honey_bound:
		state = 3   # FULLY_CONGESTED
	elif honey_bound:
		state = 2   # HONEY_BOUND
	elif brood_bound:
		state = 1   # BROOD_BOUND
	else:
		state = 0   # NORMAL

	# Swarm prep flag: total occupancy exceeds swarm threshold for 7+ consecutive
	# days.  Science: worker bees begin building queen cells 7-14 days before
	# the actual swarm departs.  One crowded day is not enough; sustained pressure
	# is required.
	var total_frac := brood_frac + honey_frac
	var swarm_prep := (total_frac >= SWARM_PREP_THRESHOLD and consecutive_congestion >= 7)

	return {"state": state, "swarm_prep": swarm_prep}
