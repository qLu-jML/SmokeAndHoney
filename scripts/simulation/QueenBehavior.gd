# QueenBehavior.gd
# -----------------------------------------------------------------------------
# Pipeline Step 6 -- Queen Laying Pattern & Colony Events
#
# Manages the laying queen's elliptical brood-nest pattern and triggers:
#   - Normal laying (egg -> cell)
#   - Supersedure detection (old/failing queen replaced)
#   - Swarm impulse (overcrowded colony wanting to split)
#   - Queen-less detection (no queen present -> colony stress)
#
# The queen lays center-out through frames using QUEEN_FRAME_ORDER.
# Within each frame she fills an ellipse, skipping occupied cells.
#
# STATUS: Inline logic in HiveSimulation._queen_lay() handles laying today.
#         Supersedure and swarm events are STUB -- will be added in Phase 2.
# -----------------------------------------------------------------------------
extends RefCounted
class_name QueenBehavior

# Swarm impulse triggers when occupied cells exceed this fraction of total cells.
const SWARM_THRESHOLD        := 0.82   # 82% full -> swarm risk builds
const SWARM_DAYS_THRESHOLD   := 7      # consecutive days above threshold -> swarm

# Supersedure triggers when queen age exceeds this many days.
const SUPERSEDURE_AGE_DAYS   := 730    # ~2 years

# Probability of a supersedure event per day once conditions are met.
const SUPERSEDURE_CHANCE     := 0.04

## Check whether a swarm event should fire.
## Returns true if the colony should swarm today.
static func should_swarm(occupied_fraction: float,
                         consecutive_congestion_days: int) -> bool:
	return occupied_fraction >= SWARM_THRESHOLD and \
	       consecutive_congestion_days >= SWARM_DAYS_THRESHOLD

## Check whether the queen should be superseded.
## Returns true if a supersedure cell should be started.
static func should_supersede(queen_age_days: int, queen_health: float) -> bool:
	if queen_age_days < SUPERSEDURE_AGE_DAYS and queen_health > 0.5:
		return false
	return randf() < SUPERSEDURE_CHANCE

## Grade modifier table (GDD Table 3.2) -- multiplies laying_rate.
static func grade_modifier(grade: String) -> float:
	match grade:
		"A+": return 1.20
		"A":  return 1.10
		"B":  return 1.00
		"C":  return 0.85
		"D":  return 0.65
		_:    return 1.00

## Species seasonal modifier -- how well the species ramps up/down with season.
## season_factor: 0-1 from TimeManager.season_factor().
static func species_seasonal_modifier(species: String, season_factor: float) -> float:
	match species:
		"Italian":
			# Ramps up fast in spring, maintains summer, tapers in fall.
			return lerpf(0.15, 1.0, season_factor)
		"Carniolan":
			# Explosive spring build-up, shuts down sharply in fall.
			return lerpf(0.05, 1.0, pow(season_factor, 0.7))
		"Russian":
			# Conservative -- resists over-wintering losses.
			return lerpf(0.25, 0.90, season_factor)
		"Buckfast":
			# Balanced -- moderate all-season performance.
			return lerpf(0.20, 0.95, season_factor)
		_:
			return lerpf(0.10, 1.0, season_factor)
