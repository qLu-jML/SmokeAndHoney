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

## Grade modifier table -- multiplies base laying_rate (2000).
## S-tier queen lays 1500-2000 eggs/day depending on season/age/stress.
## S=1.00 is the baseline (best real-world queens). Lower grades scale down.
static func grade_modifier(grade: String) -> float:
	match grade:
		"S":  return 1.00   # 1500-2000 eggs/day (peak season)
		"A":  return 0.85   # 1275-1700
		"B":  return 0.70   # 1050-1400
		"C":  return 0.55   # 825-1100
		"D":  return 0.35   # 525-700
		"F":  return 0.00   # dead or absent queen
		_:    return 0.70   # default to B-tier

## Queen age curve -- performance peaks year 2, declines after.
## Validated by Karpathy Phase 4: 5-year lifecycle with natural decline.
## queen_age_days: total days since queen was introduced.
static func queen_age_multiplier(queen_age_days: int) -> float:
	var years: float = float(queen_age_days) / 224.0
	if years <= 1.0:
		return 1.00
	elif years <= 2.0:
		return 1.05   # peak performance in year 2
	elif years <= 3.0:
		return 1.05 - (years - 2.0) * 0.15   # 1.05 -> 0.90
	elif years <= 4.0:
		return 0.90 - (years - 3.0) * 0.20   # 0.90 -> 0.70
	else:
		return maxf(0.10, 0.70 - (years - 4.0) * 0.15)   # gradual decline

## Congestion penalty on queen laying rate.
## Validated by Karpathy Phase 4+8: only severe congestion cuts laying.
static func congestion_laying_modifier(congestion_state: int) -> float:
	match congestion_state:
		0: return 1.00   # NORMAL
		1: return 0.75   # BROOD_BOUND
		2: return 0.85   # HONEY_BOUND
		3: return 0.50   # FULLY_CONGESTED
		_: return 1.00

## Varroa stress on queen laying -- mite load reduces laying rate.
## mites_per_100: mite count per 100 adult bees.
## Validated by Karpathy Phase 4: disease pressure on queen performance.
static func varroa_laying_modifier(mites_per_100: float) -> float:
	if mites_per_100 < 1.0:
		return 1.00
	elif mites_per_100 < 2.0:
		return 0.95
	elif mites_per_100 < 3.0:
		return 0.85
	elif mites_per_100 < 5.0:
		return 0.70
	elif mites_per_100 < 8.0:
		return 0.50
	else:
		return 0.25

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
