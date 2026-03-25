# ForagerSystem.gd
# -----------------------------------------------------------------------------
# Pipeline Step 4 -- Forager Bee Resource Collection
#
# Computes how much nectar and pollen foragers collect each day, based on:
#   - forager_count       -- number of forager-cohort bees
#   - forage_pool         -- 0-1 score from ForageManager (flower availability)
#   - season_factor       -- 0-1 modifier for season (winter ? 0, summer peak ? 1)
#   - congestion_state    -- HONEY_BOUND colony limits nectar acceptance
#
# OUTPUTS:
#   {
#     "nectar_collected"  : float   -- lbs of nectar brought in today
#     "pollen_collected"  : float   -- lbs of pollen brought in today
#   }
#
# Nectar -> honey conversion is ~1/5 by weight (5 lbs nectar = 1 lb honey).
# The actual honey curing is handled by CellStateTransition / NectarProcessor.
#
# -----------------------------------------------------------------------------
# CALIBRATION (Bug FS-1 fix):
#   Real forager: 10 trips/day x 40 mg nectar/trip = 400 mg/forager/day
#   Unit conversion: 400 mg ? 453,592 mg/lb = 0.000882 lbs/forager/day
#   Previous value (0.000080) was 11x too low, causing severe honey underproduction.
#
# Science references:
#   Beekman & Ratnieks (2000) -- forager trip rates and load sizes
#   Winston (1987) -- colony-level nectar collection mechanics
# -----------------------------------------------------------------------------
extends RefCounted
class_name ForagerSystem

# Nectar carry capacity per forager per day (lbs).
# Science: 10 trips x 40 mg = 400 mg = 0.000882 lbs.
# Previous value 0.000080 was 11x below reality.
const NECTAR_PER_FORAGER := 0.000_882   # was 0.000_08 (11x too low)

# Pollen collection: ~15-25% of foragers collect pollen; ~17 mg per load,
# 2 loads per trip, ~5 pollen trips/day per pollen forager.
# 0.20 fraction x 5 trips x 2 loads x 17 mg = 34 mg/day for pollen foragers.
# Net across all foragers: ~0.15 x 34 mg = 5.1 mg/forager/day = 0.0000112 lbs.
# Keeping at 0.000020 (slightly generous) for comfortable pollen margins.
const POLLEN_PER_FORAGER := 0.000_020

# Congestion penalty -- honey-bound colony sends fewer foragers and/or stores
# less nectar (bees begin fanning it dry in passage cells or turn away scouts).
const CONGESTION_NECTAR_PENALTY := 0.40   # 40% reduction in nectar acceptance

static func process(forager_count: int,
                    forage_pool: float,
                    season_factor: float,
                    congestion_state: int) -> Dictionary:

	# Base nectar calculation.
	var nectar := float(forager_count) * NECTAR_PER_FORAGER * forage_pool * season_factor
	var pollen := float(forager_count) * POLLEN_PER_FORAGER * forage_pool * season_factor

	# -- Daily variance (Bug FS-2 fix) -----------------------------------------
	# Science: forager productivity varies ?15-25% day-to-day due to weather,
	# scout recruitment feedback loops, nectar flow microbursts, and random
	# environmental factors.  This variance is what causes two initially
	# identical hives to diverge over the season.
	# Using a uniform ?20% factor (equivalent to ?20% range on truncated normal).
	var daily_factor := randf_range(0.80, 1.20)
	nectar *= daily_factor
	pollen *= daily_factor

	# Penalise nectar if honey-bound (HiveSimulation.CongestionState.HONEY_BOUND = 2)
	if congestion_state == 2 or congestion_state == 3:
		nectar *= (1.0 - CONGESTION_NECTAR_PENALTY)

	return {
		"nectar_collected" : maxf(0.0, nectar),
		"pollen_collected" : maxf(0.0, pollen),
	}
