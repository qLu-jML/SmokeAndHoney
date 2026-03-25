# HiveHealthCalculator.gd
# -----------------------------------------------------------------------------
# Pipeline Step 8 -- Composite Hive Health Score
#
# Produces a single 0-100 health score from weighted sub-scores.
# The score drives the visual tint on the overworld hive sprite and
# is displayed in the inspection overlay's stats panel.
#
# Sub-scores and weights (GDD S4.1):
#   Population  25%  -- adult count relative to healthy baseline
#   Brood       25%  -- brood count and pattern quality
#   Stores      20%  -- honey/pollen reserves vs. winter needs
#   Queen       20%  -- queen present, grade, age
#   Disease     10%  -- varroa load, AFB, other pathogens
#
# -----------------------------------------------------------------------------
# Science references:
#   GDD S2.4 Winter hive check: >50 lbs honey = good; 30-50 = adequate;
#       <15 lbs = likely lost colony.
#   Rosenkranz et al. (2010) -- Varroa mite impact on colony health
# -----------------------------------------------------------------------------
extends RefCounted
class_name HiveHealthCalculator

# Healthy baseline values -- scores approach 100% as colony approaches these.
const HEALTHY_ADULTS  := 30_000   # total adult bees for "full" colony
const HEALTHY_BROOD   :=  8_000   # total brood cells for "full" colony

# Science fix (HHC-2): HEALTHY_HONEY raised from 20.0 to 35.0 lbs.
# GDD S2.4 explicitly states >50 lbs is "good through winter" and 30-50 lbs
# is "adequate."  A baseline of 20 lbs was rewarding colonies that would
# likely starve in winter with near-full honey scores.
const HEALTHY_HONEY   :=    35.0  # lbs -- was 20.0; aligned with GDD S2.4
const HEALTHY_POLLEN  :=     5.0  # lbs

const W_POPULATION := 0.25
const W_BROOD      := 0.25
const W_STORES     := 0.20
const W_QUEEN      := 0.20
const W_DISEASE    := 0.10

## Calculate health score from a HiveSimulation snapshot dictionary.
static func calculate(snap: Dictionary) -> float:
	var pop_score    := _population_score(snap)
	var brood_score  := _brood_score(snap)
	var store_score  := _stores_score(snap)
	var queen_score  := _queen_score(snap)
	var disease_pen  := _disease_penalty(snap)

	var raw := pop_score   * W_POPULATION \
	         + brood_score * W_BROOD      \
	         + store_score * W_STORES     \
	         + queen_score * W_QUEEN

	# Varroa penalty applied multiplicatively through W_DISEASE weight.
	var health := raw * (1.0 - disease_pen * W_DISEASE)

	# Science fix (HHC-3): AFB is a colony-fatal disease if untreated.
	# The previous routing of afb_pen through W_DISEASE (10% weight) could
	# only reduce the health score by ~5% from AFB -- far too mild.
	# AFB now applies a direct 35-point penalty (out of 100) on the final
	# score, ensuring an AFB colony cannot appear "healthy."
	if snap.get("afb_active", false):
		health -= 0.35

	return clampf(health * 100.0, 0.0, 100.0)

static func _population_score(snap: Dictionary) -> float:
	var adults: int = snap.get("total_adults", 0)
	return clampf(float(adults) / float(HEALTHY_ADULTS), 0.0, 1.0)

static func _brood_score(snap: Dictionary) -> float:
	var brood: int = snap.get("egg_count", 0) \
	               + snap.get("larva_count", 0) \
	               + snap.get("capped_count", 0)
	return clampf(float(brood) / float(HEALTHY_BROOD), 0.0, 1.0)

static func _stores_score(snap: Dictionary) -> float:
	var honey:  float = snap.get("honey_stores",  0.0)
	var pollen: float = snap.get("pollen_stores", 0.0)
	var h_score := clampf(honey  / HEALTHY_HONEY,  0.0, 1.0)
	var p_score := clampf(pollen / HEALTHY_POLLEN, 0.0, 1.0)
	return h_score * 0.7 + p_score * 0.3

static func _queen_score(snap: Dictionary) -> float:
	if not snap.get("queen_present", false):
		return 0.0   # queen-less colony

	# Science fix (HHC-1): queen grade map corrected to match HiveSimulation's
	# grade schema ("S", "A", "B", "C", "D", "F").
	# Previous map used "A+" which was never set anywhere in the codebase,
	# causing S-grade queens to fall through to default 0.75 (a B score).
	var grade_map := {
		"S": 1.00,   # Exceptional breeder stock
		"A": 0.90,   # Strong commercial queen
		"B": 0.75,   # Standard market queen (game default)
		"C": 0.55,   # Below-average; spotty brood visible
		"D": 0.35,   # Failing; low laying rate
		"F": 0.00,   # Not laying; emergency replacement needed
	}
	return grade_map.get(snap.get("queen_grade", "B"), 0.75)

static func _disease_penalty(snap: Dictionary) -> float:
	# Varroa penalty: 0 mites = 0, 3,000 mites = 1.0 penalty multiplier.
	# This feeds into the W_DISEASE = 10% weight for mild suppression.
	var mites: float = snap.get("mite_count", 0.0)
	var varroa_pen   := clampf(mites / 3000.0, 0.0, 1.0)

	# AFB is handled as a direct score penalty in calculate() above.
	# Return only varroa here to avoid double-application.
	return varroa_pen
