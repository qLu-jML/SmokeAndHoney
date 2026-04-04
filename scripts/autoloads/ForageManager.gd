# ForageManager.gd -- Tracks forage pool strength per apiary zone.
# Feeds a forage_level float (0.0-1.0) into HiveSimulation each tick.
# Autoloaded as "ForageManager" in project.godot.
# -----------------------------------------------------------------------------
# GDD S14.2 Forage Pool Calculation:
#   Forage Pool (NU) = (Sum of plant NUs) x Weather Modifier x Crop Modifier
#
# Now integrates with FlowerLifecycleManager for dynamic, tile-based forage
# sourced from the season ranking system (S/A/B/C/D/F).
# -----------------------------------------------------------------------------
extends Node

# -- Bloom Calendar (reference data, used by is_blooming() for UI queries) ----
# Months: 0=Quickening, 1=Greening, 2=Wide-Clover, 3=High-Sun,
#         4=Full-Earth, 5=Reaping, 6=Deepcold, 7=Kindlemonth
# Nectar/pollen values here are whole-number points (1-5 scale), matching
# FlowerLifecycleManager.FLOWER_TYPES. Trees use higher values per unit
# because one tree represents a large canopy vs. a single 16px flower tile.
# Validated by Karpathy Phase 6: Iowa native flower species with bloom windows.
# Research uses day-of-year (0-223); converted to month indices here.
# Nectar/pollen values 1-5 scale, matching FlowerLifecycleManager.
const PLANT_DATA: Dictionary = {
	# Dandelion days 21-64 -> months 0-2 (overlaps slightly into Wide-Clover)
	"dandelion":     { "start": 0, "end": 2,  "nectar": 3, "pollen": 3 },
	# Phase 6: Willow early spring only
	"willow":        { "start": 0, "end": 0,  "nectar": 1, "pollen": 4 },
	# Phase 6: Fruit trees (apple/cherry/pear) months 0-1
	"fruit_tree":    { "start": 0, "end": 1,  "nectar": 3, "pollen": 3 },
	# Phase 6: Black Locust days 45-65 -> month 1-2
	"black_locust":  { "start": 1, "end": 2,  "nectar": 5, "pollen": 2 },
	# Phase 6: White Clover days 40-110 -> months 1-3
	"clover":        { "start": 1, "end": 3,  "nectar": 4, "pollen": 2 },
	# Phase 6: Basswood/Linden days 70-95 -> months 2-3
	"linden":        { "start": 2, "end": 3,  "nectar": 5, "pollen": 2 },
	# Phase 6: Prairie Clover days 80-130 -> months 2-4
	"prairie_clover": { "start": 2, "end": 4,  "nectar": 3, "pollen": 3 },
	"bergamot":      { "start": 2, "end": 3,  "nectar": 3, "pollen": 2 },
	"coneflower":    { "start": 2, "end": 4,  "nectar": 2, "pollen": 3 },
	"sunflower":     { "start": 3, "end": 4,  "nectar": 2, "pollen": 4 },
	# Phase 6: Goldenrod days 115-155 -> months 4-5
	"goldenrod":     { "start": 4, "end": 5,  "nectar": 3, "pollen": 4 },
	# Phase 6: Aster days 130-165 -> months 4-5
	"aster":         { "start": 4, "end": 5,  "nectar": 2, "pollen": 3 },
}

# -- State --------------------------------------------------------------------
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _forage_pools: Dictionary = {}

# -- Signals ------------------------------------------------------------------
@warning_ignore("UNUSED_SIGNAL")
signal forage_updated(level: float)

# -- Public API ---------------------------------------------------------------

## Returns forage level (0.0-1.0) for a given world position.
## Queries FlowerLifecycleManager for actual tile-based flower density data.
func calculate_forage_pool(world_position: Vector2) -> float:
	var month: int = TimeManager.current_month_index()

	# Winter: no forage at all
	if month >= 6:
		return 0.0

	# Try to get dynamic forage from FlowerLifecycleManager
	var flm := _get_flower_manager()
	if flm:
		var forage_data: Dictionary = flm.get_forage_at(world_position)
		var nectar: float = forage_data.get("nectar", 0.0)
		var pollen: float = forage_data.get("pollen", 0.0)

		# Add contributions from all placed SeasonalTree instances
		var tree_forage: Dictionary = _get_tree_forage(month)
		nectar += tree_forage.get("nectar", 0.0)
		pollen += tree_forage.get("pollen", 0.0)

		# Combined NU (nectar-weighted since that's what makes honey)
		var total_nu: float = nectar * 0.7 + pollen * 0.3

		# Normalize to 0-1 range.  Peak expected NU at B rank is ~3-4.
		# S rank could reach 6-8.  Use 8.0 as normalization ceiling.
		var level := clampf(total_nu / 8.0, 0.0, 1.0)
		return level

	# -- Fallback: hardcoded baseline (if FlowerLifecycleManager not found) ---
	var baseline: float
	match month:
		0: baseline = 0.15
		1: baseline = 0.45
		2: baseline = 1.00
		3: baseline = 1.00
		4: baseline = 0.70
		5: baseline = 0.35
		_: baseline = 0.0
	return clampf(baseline, 0.0, 1.0)

## Returns the dominant nectar source name for a position (for varietal labeling).
func get_dominant_plant(_world_position: Vector2) -> String:
	var flm := _get_flower_manager()
	if flm:
		return flm.get_dominant_plant()

	# Fallback
	var month: int = TimeManager.current_month_index()
	match month:
		0, 1: return "wildflower"
		2, 3: return "clover"
		4, 5: return "goldenrod"
	return "mixed"

## Check if a given plant type is currently in bloom.
func is_blooming(plant_type: String) -> bool:
	# First check dynamic flower manager
	var flm := _get_flower_manager()
	if flm:
		var blooming: Array = flm.get_blooming_types()
		if plant_type in blooming:
			return true

	# Fall back to static bloom calendar
	if not PLANT_DATA.has(plant_type):
		return false
	var data: Dictionary = PLANT_DATA[plant_type]
	var month: int = TimeManager.current_month_index()
	return month >= data["start"] and month <= data["end"]

## Returns a human-readable forage status label (for UI display).
## GDD S14.4: Abundant / Adequate / Stressed / Dearth
func get_forage_status_label(world_position: Vector2) -> String:
	var level := calculate_forage_pool(world_position)
	if level >= 0.80: return "Abundant"
	if level >= 0.50: return "Adequate"
	if level >= 0.20: return "Stressed"
	return "Dearth"

## Legacy: called by old DandelionSpawner. Now a no-op (no-operation).
func set_dandelion_bloom(_outcome: String, _density: float) -> void:
	pass  # No longer used -- FlowerLifecycleManager manages all flowers

## Legacy: goldenrod end-of-season hook. Now a no-op (no-operation).
func report_goldenrod_end_of_season(_was_good: bool) -> void:
	pass  # No longer used -- FlowerLifecycleManager manages all flowers

# -- Internal -----------------------------------------------------------------

## Sum nectar/pollen from all SeasonalTree instances in the "trees" group.
## Each tree reports its own contribution based on species and bloom window.
## NU values are divided by NU_SCALE (250) to match flower tile scale.
func _get_tree_forage(month: int) -> Dictionary:
	var total_nectar := 0.0
	var total_pollen := 0.0
	var trees := get_tree().get_nodes_in_group("trees")
	for tree_node in trees:
		if tree_node.has_method("get_forage_contribution"):
			var contrib: Dictionary = tree_node.get_forage_contribution(month)
			total_nectar += contrib.get("nectar", 0.0)
			total_pollen += contrib.get("pollen", 0.0)
	# Scale tree NU down to match flower tile density scale
	# One tree with 8 NU total should contribute roughly as much as
	# a patch of 20-30 mature flower tiles (which yield ~0.5-1.0 after NU_SCALE)
	# Using /10 so a willow (2 nectar + 6 pollen) gives ~0.2 nectar + 0.6 pollen
	return { "nectar": total_nectar / 10.0, "pollen": total_pollen / 10.0 }


## Find the FlowerLifecycleManager in the scene tree.
func _get_flower_manager() -> FlowerLifecycleManager:
	var node := get_tree().get_first_node_in_group("flower_lifecycle_manager")
	return node as FlowerLifecycleManager if node is FlowerLifecycleManager else null
