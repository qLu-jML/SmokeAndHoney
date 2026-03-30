# ForagerSystem.gd
# -----------------------------------------------------------------------------
# Pipeline Step 4 -- Forager Bee Resource Collection
#
# NEW MODEL (Nathan's NU/PU unit system):
#   1. Zone has a total NU (Nectar Unit) and PU (Pollen Unit) pool
#   2. Pool is divided equally among all colonies in that zone
#   3. Each forager collects 2-6 NU and 1-2 PU per day (discrete units)
#   4. Collection is capped by available zone resources for this colony
#   5. Weather and season still apply as multipliers on forager efficiency
#
# OUTPUTS:
#   {
#     "nu_collected"  : int   -- nectar units brought in today
#     "pu_collected"  : int   -- pollen units brought in today
#   }
# -----------------------------------------------------------------------------
extends RefCounted
class_name ForagerSystem

# Per-forager collection range (discrete units per day)
const NU_PER_FORAGER_MIN := 2
const NU_PER_FORAGER_MAX := 6
const PU_PER_FORAGER_MIN := 1
const PU_PER_FORAGER_MAX := 2

# Congestion penalty -- only FULLY_CONGESTED colonies lose foraging output.
const CONGESTION_PENALTY := 0.25   # 25% reduction when fully congested


## Calculate daily forager collection in NU and PU.
## zone_nu: total NU available for this colony (already divided by colony count)
## zone_pu: total PU available for this colony (already divided by colony count)
## forager_count: number of forager bees in this colony
## weather_season_mult: combined weather * season modifier (0-1)
## congestion_state: 0-3 from CongestionDetector
static func process(forager_count: int,
                    zone_nu: int,
                    zone_pu: int,
                    weather_season_mult: float,
                    congestion_state: int) -> Dictionary:

	if forager_count <= 0 or weather_season_mult <= 0.0:
		return { "nu_collected": 0, "pu_collected": 0 }

	# Each forager collects a random amount within the per-forager range.
	# For performance, calculate an average per-forager yield with variance
	# rather than rolling per-forager dice for 10,000+ foragers.
	var avg_nu_per_forager: float = float(NU_PER_FORAGER_MIN + NU_PER_FORAGER_MAX) / 2.0
	var avg_pu_per_forager: float = float(PU_PER_FORAGER_MIN + PU_PER_FORAGER_MAX) / 2.0

	# Daily variance (15-25% range on total output)
	var daily_factor: float = randf_range(0.80, 1.20)

	# Raw potential collection (before zone cap)
	var raw_nu: int = int(float(forager_count) * avg_nu_per_forager * weather_season_mult * daily_factor)
	var raw_pu: int = int(float(forager_count) * avg_pu_per_forager * weather_season_mult * daily_factor)

	# Congestion penalty -- fully congested hives can't process as much
	if congestion_state == 3:
		raw_nu = int(float(raw_nu) * (1.0 - CONGESTION_PENALTY))
		raw_pu = int(float(raw_pu) * (1.0 - CONGESTION_PENALTY))

	# Cap by what the zone actually has available for this colony
	var nu_collected: int = mini(raw_nu, zone_nu)
	var pu_collected: int = mini(raw_pu, zone_pu)

	return {
		"nu_collected": maxi(0, nu_collected),
		"pu_collected": maxi(0, pu_collected),
	}
