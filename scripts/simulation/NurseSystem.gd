# NurseSystem.gd
# -----------------------------------------------------------------------------
# Pipeline Step 3 -- Nurse Bee Brood Care
#
# Determines whether the colony has sufficient nurse bees to:
#   - Feed all open larvae (affects larval nutrition and emergence weight)
#   - Cap larvae on schedule (delay if understaffed)
#   - Clean vacated cells (see CellStateTransition VACATED constants)
#   - Produce royal jelly for queen cells
#
# OUTPUT (context flags injected into the next tick's CellStateTransition ctx):
#   {
#     "has_nurse_bees" : bool    -- adequate nursing coverage (ratio >= 0.4)
#     "nurse_ratio"    : float   -- nurses per open larva
#     "rjelly_surplus" : float   -- surplus royal jelly for queen rearing (0-1)
#     "capping_delay"  : int     -- 0-2 extra days before larva is capped
#   }
#
# Science references:
#   Winston (1987) "The Biology of the Honey Bee" -- nurse:larva ratios
#   Seeley (1995) "The Wisdom of the Hive" -- colony workforce allocation
#
# A healthy summer colony has 6,000-8,000 nurse bees (bees 0-10 days old) and
# 8,000-10,000 open larvae, giving a nurse:larva ratio of 0.6-1.0.
# This ratio is fully adequate for brood care.  The previous IDEAL_NURSE_RATIO
# of 2.0 incorrectly classified healthy colonies as under-staffed.
# -----------------------------------------------------------------------------
extends RefCounted
class_name NurseSystem

# Nurse:larva ratio at which care is considered excellent (royal jelly surplus).
# Science: 1.0+ nurse per larva = abundant nursing; colonies rarely exceed 1.2
# except in early spring with few larvae and many overwintered bees.
const IDEAL_NURSE_RATIO  := 1.2   # was 2.0 -- corrected to match real colony data

# Minimum adequate ratio -- below 0.4, capping is significantly delayed.
const ADEQUATE_RATIO     := 0.4

# Absolute minimum nurse count for any brood care.
# Science: a colony with <1,500 nurses cannot adequately feed a typical brood
# nest. Previous threshold of 500 was too low.
const MIN_NURSE_COUNT    := 1500  # was 500

static func process(nurse_count: int, open_larva_count: int) -> Dictionary:
	var ratio := (float(nurse_count) / maxf(1.0, float(open_larva_count)))

	# Adequate = has enough nurses to cover basics (ratio >= ADEQUATE_RATIO * 0.5
	# AND above MIN_NURSE_COUNT). This controls vacated-cell cleaning rate and
	# the has_nurse_bees flag injected into CellStateTransition.
	var adequate := nurse_count >= MIN_NURSE_COUNT and ratio >= (ADEQUATE_RATIO * 0.5)

	# Royal jelly surplus: only produced when ratio exceeds IDEAL_NURSE_RATIO * 0.5.
	# Science: hypopharyngeal glands produce maximal royal jelly only when nurses
	# are not fully occupied with routine larval feeding.  At ratio 0.6 (typical),
	# glands are at capacity; surplus only emerges above ratio ~0.8.
	var rjelly := clampf((ratio - IDEAL_NURSE_RATIO * 0.5) / IDEAL_NURSE_RATIO, 0.0, 1.0)

	# Capping delay: when understaffed, larvae are under-fed and take longer to
	# reach the weight/maturity cue that triggers capping by nurse bees.
	# Science: delays of 1-2 days observed in colonies with nurse:larva < 0.5.
	var capping_delay: int
	if ratio >= ADEQUATE_RATIO:
		capping_delay = 0   # Normal: capped on day 9 as expected
	elif ratio >= ADEQUATE_RATIO * 0.5:
		capping_delay = 1   # Mild stress: capped on day 10
	else:
		capping_delay = 2   # Severe stress: capped on day 11

	return {
		"has_nurse_bees" : adequate,
		"nurse_ratio"    : ratio,
		"rjelly_surplus" : rjelly,
		"capping_delay"  : capping_delay,
	}
