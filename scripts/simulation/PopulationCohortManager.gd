# PopulationCohortManager.gd
# -----------------------------------------------------------------------------
# Pipeline Step 2 -- Adult Bee Cohort Lifecycle
#
# Manages the three adult-bee cohorts (nurse, house, forager) through their
# natural age-progression.  Newly emerged bees enter the nurse cohort;
# nurses graduate to house bees, then to foragers over ~21 days.
#
# INPUTS  (TransitionResult from CellStateTransition + colony state):
#   emerged_workers -- bees that eclosed today (from CellStateTransition result)
#   emerged_drones  -- drones that eclosed today
#   season_factor   -- 0.0-1.0 colony vigour modifier from TimeManager
#
# OUTPUTS (mutates HiveSimulation fields directly, returns summary dict):
#   {
#     "nurse_count"   : int,
#     "house_count"   : int,
#     "forager_count" : int,
#     "drone_count"   : int,
#     "daily_deaths"  : int,
#   }
#
# -----------------------------------------------------------------------------
# Science references:
#   Winston (1987) "The Biology of the Honey Bee" -- worker lifespan and roles
#   Amdam & Omholt (2002) "The regulatory anatomy of honeybee lifespan" --
#       winter bee (diutinus) longevity: vitellogenin upregulation allows
#       4-6 month lifespan vs. 4-6 week summer lifespan
#   Seeley (1995) "The Wisdom of the Hive" -- forager fraction 25-33% of adults
# -----------------------------------------------------------------------------
extends RefCounted
class_name PopulationCohortManager

# Summer baseline mortality rates (fraction of cohort that dies per day).
# These apply at season_factor = 1.0 (peak summer).
# Validated by Karpathy research Phase 2: S-tier 5-year population dynamics.
# S-tier targets: 55-70k summer peak, 20-30k winter minimum.
const NURSE_MORTALITY_SUMMER   := 0.0023  # ~43-day avg lifespan; most nurses
                                           # graduate rather than die
const HOUSE_MORTALITY_SUMMER   := 0.0038
const FORAGER_MORTALITY_SUMMER := 0.037   # ~27-day avg forager lifespan
                                           # (predation + exhaustion)
const DRONE_MORTALITY_SUMMER   := 0.012   # summer drones; expelled aggressively
                                           # as season_factor drops (see below)

# Winter mortality rates -- models the long-lived diutinus (winter bee) phenotype.
# Science: Amdam & Omholt (2002) -- winter bees downregulate foraging-related genes
# and upregulate vitellogenin; cluster mortality is driven by starvation/cold, not
# normal senescence.  Effective lifespan 90-180 days vs. 25-45 days in summer.
# Validated by Karpathy Phase 2: winter cluster maintains 20-30k for S-tier.
const NURSE_MORTALITY_WINTER   := 0.018   # ~56-day lifespan in winter cluster
const HOUSE_MORTALITY_WINTER   := 0.018
const FORAGER_MORTALITY_WINTER := 0.030   # higher than indoor bees even in
                                           # winter; occasional cleansing flights

# Days a bee spends in each cohort before graduating.
const NURSE_DAYS   := 12   # Days 1-12 post-emergence: nurse/hive phase
# HOUSE_DAYS extended from 9 to 12 to reduce forager fraction from ~42% toward
# real-world target of 25-33% of adult workers.
const HOUSE_DAYS   := 12   # Days 13-24 post-emergence: house bee/comb builder

# Winter threshold: below this season_factor, apply winter bee dynamics.
const WINTER_THRESHOLD := 0.12  # Deepcold (0.08) and Kindlemonth (0.05)

## Advance cohort counts by one day: nurses graduate to house bees, house bees
## to foragers, with seasonal mortality rates. Mutates hive_sim fields directly.
## Returns dict with final counts: nurse_count, house_count, forager_count, drone_count.
## hive_sim: HiveSimulation node reference (mutated)
## transition_result: dict from CellStateTransition with emerged_workers/drones
## season_factor: float 0-1 from TimeManager (determines winter vs summer dynamics)
static func process(hive_sim: HiveSimulation,
                    transition_result: Dictionary,
                    season_factor: float) -> Dictionary:

	var is_winter := season_factor <= WINTER_THRESHOLD

	# -- Select mortality rates based on season ---------------------------------
	var nurse_mort: float   = NURSE_MORTALITY_WINTER   if is_winter else NURSE_MORTALITY_SUMMER
	var house_mort: float   = HOUSE_MORTALITY_WINTER   if is_winter else HOUSE_MORTALITY_SUMMER
	var forager_mort: float = FORAGER_MORTALITY_WINTER if is_winter else FORAGER_MORTALITY_SUMMER

	# Drone expulsion: dramatically accelerates as season_factor drops below 0.65.
	# Science: drones are expelled from the hive in fall as nectar flows end.
	# At s_factor=0.35 (Reaping): ~11% daily drone loss ? 10-day expulsion window.
	# At s_factor=0.08 (Deepcold): ~16% daily -- few drones survive deep winter.
	var drone_mort: float
	if season_factor >= 0.65:
		drone_mort = DRONE_MORTALITY_SUMMER                                # 1.2%/day
	else:
		drone_mort = 0.012 + (1.0 - season_factor) * 0.15                 # up to ~16%
	drone_mort = clampf(drone_mort, DRONE_MORTALITY_SUMMER, 0.20)

	# -- Graduate nurses -> house bees, house bees -> foragers -------------------
	# In winter: nurses do not graduate to house bees (cluster is static);
	# house bees do not graduate to foragers (no flight, no recruitment).
	# Science: winter cluster bees cycle tasks internally but don't progress
	# through the summer behavioral sequence.
	var graduate_nurse: int
	var graduate_house: int
	if is_winter:
		graduate_nurse = 0
		graduate_house = 0
	else:
		graduate_nurse = int(float(hive_sim.nurse_count)  / float(NURSE_DAYS))
		# Phase-5 cohesion fix: removed season_factor multiplier from grad_house.
		# Science: house bees progress to forager cohort at their natural biological
		# rate regardless of season.  Multiplying by season_factor caused house bees
		# to accumulate in fall (fewer graduating, low mortality) which then inflated
		# the winter cluster to 30,000+ instead of the correct 8,000-15,000.
		# The season_factor already correctly reduces FORAGING via ForagerSystem's
		# forage_pool and season_factor inputs; the cohort progression itself is
		# not gated by season in real biology.
		graduate_house = int(float(hive_sim.house_count)  / float(HOUSE_DAYS))

	# -- Apply cohort changes ---------------------------------------------------
	hive_sim.nurse_count   += transition_result.get("emerged_workers", 0)
	hive_sim.nurse_count   -= graduate_nurse
	hive_sim.nurse_count   -= int(float(hive_sim.nurse_count) * nurse_mort)

	hive_sim.house_count   += graduate_nurse
	hive_sim.house_count   -= graduate_house
	hive_sim.house_count   -= int(float(hive_sim.house_count) * house_mort)

	hive_sim.forager_count += graduate_house
	hive_sim.forager_count -= int(float(hive_sim.forager_count) * forager_mort)

	hive_sim.drone_count   += transition_result.get("emerged_drones", 0)
	hive_sim.drone_count   -= int(float(hive_sim.drone_count) * drone_mort)

	# Clamp to zero
	hive_sim.nurse_count   = maxi(0, hive_sim.nurse_count)
	hive_sim.house_count   = maxi(0, hive_sim.house_count)
	hive_sim.forager_count = maxi(0, hive_sim.forager_count)
	hive_sim.drone_count   = maxi(0, hive_sim.drone_count)

	var total_adults := hive_sim.nurse_count + hive_sim.house_count + hive_sim.forager_count
	return {
		"nurse_count"   : hive_sim.nurse_count,
		"house_count"   : hive_sim.house_count,
		"forager_count" : hive_sim.forager_count,
		"drone_count"   : hive_sim.drone_count,
		"total_adults"  : total_adults,
	}
