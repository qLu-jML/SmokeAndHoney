# dandelion_spawner.gd -- Spring dandelion bloom system for Smoke & Honey
# -----------------------------------------------------------------------------
# GDD S14.8.1: Dandelions -- The Spring Lifeline
#
# At the start of each spring (Month 0 / Quickening), this system:
#   1. Performs a single annual "bloom quality" roll
#   2. Assigns a quality outcome: POOR / AVERAGE / GOOD / EXCEPTIONAL
#   3. Calculates a density ratio (0.0-1.0) that controls dandelion spawn count
#   4. Populates DandelionLayer Sprite2D children across the scene's grass tiles
#   5. Despawns all dandelions at the end of spring (start of Month 2 / Wide-Clover)
#
# GDD bloom quality / NU table:
#   POOR        density 0.05-0.15  NU contribution: 1-2
#   AVERAGE     density 0.20-0.40  NU contribution: 3-5
#   GOOD        density 0.50-0.72  NU contribution: 6-9
#   EXCEPTIONAL density 0.80-1.00  NU contribution: 10-14
#
# Bloom timing: base = late Quickening (day 18-24 of spring).
#   EXCEPTIONAL: ?early shift (arrives day 12-16)
#   POOR:        ?late shift  (arrives day 22-28, may overlap Greening)
#
# Grass grid: hardcoded for HomeProperty; scene-specific subclasses can
# override _get_grass_zone_rect() to define their own planting footprint.
# -----------------------------------------------------------------------------
extends Node2D

# -- Signals -------------------------------------------------------------------
## Fires when the annual roll is complete. Quality and density are final.
signal bloom_quality_rolled(outcome: String, density: float, bloom_day: int)
## Fires when dandelions become visible this year (bloom_day reached).
signal dandelions_bloomed(outcome: String, count: int)
## Fires when dandelions are removed (start of summer or player mows).
signal dandelions_cleared()

# -- Quality outcome constants -------------------------------------------------
const QUALITY_POOR        := "POOR"
const QUALITY_AVERAGE     := "AVERAGE"
const QUALITY_GOOD        := "GOOD"
const QUALITY_EXCEPTIONAL := "EXCEPTIONAL"

# -- NU contribution per outcome (mid-range values used for ForageManager) -----
const NU_BY_QUALITY: Dictionary = {
	QUALITY_POOR:        2.0,
	QUALITY_AVERAGE:     4.0,
	QUALITY_GOOD:        7.5,
	QUALITY_EXCEPTIONAL: 12.0,
}

# -- Density range per outcome -------------------------------------------------
const DENSITY_RANGE: Dictionary = {
	QUALITY_POOR:        [0.05, 0.15],
	QUALITY_AVERAGE:     [0.20, 0.40],
	QUALITY_GOOD:        [0.50, 0.72],
	QUALITY_EXCEPTIONAL: [0.80, 1.00],
}

# -- Bloom timing: day-of-spring for first sprouts ----------------------------
# Dandelions sprout in late Quickening (last week) through early Greening.
# Quality shifts the arrival: EXCEPTIONAL arrives earlier, POOR later.
# S-rank = day 21, F-rank = day 28 (last day of Quickening).
# bloom_day is day-within-year (not day-within-month).
const BLOOM_DAY_BY_QUALITY: Dictionary = {
	QUALITY_EXCEPTIONAL: 21,  # early last week of Quickening
	QUALITY_GOOD:        23,  # mid last week
	QUALITY_AVERAGE:     25,  # late last week
	QUALITY_POOR:        28,  # very end of Quickening / start of Greening
}

# -- Dandelion tile sprite path ------------------------------------------------
const DANDELION_SPRITE := "res://assets/sprites/world/forage/dandelion_tile.png"

# -- State ---------------------------------------------------------------------
var current_year:    int    = -1   # last year we rolled for
var current_outcome: String = ""   # quality outcome for this spring
var current_density: float  = 0.0  # spawn density ratio 0.0-1.0
var bloom_day:       int    = 0    # in-year day when bloom becomes visible
var _bloomed:        bool   = false
var _prior_goldenrod_good: bool = false  # set by ForageManager at end of fall

# Node holding spawned dandelion Sprites.  Must be a child of this node named
# "DandelionLayer" (created automatically if not present).
var _layer: Node2D = null

# -- Lifecycle -----------------------------------------------------------------

## Ready.
func _ready() -> void:
	# Register in group so ForageManager and SaveManager can find this node
	# via get_first_node_in_group("dandelion_spawner") regardless of scene layout.
	add_to_group("dandelion_spawner")

	_layer = get_node_or_null("DandelionLayer")
	if _layer == null:
		_layer = Node2D.new()
		_layer.name = "DandelionLayer"
		add_child(_layer)

	# Connect to TimeManager signals
	if TimeManager.has_signal("month_changed"):
		TimeManager.month_changed.connect(_on_month_changed)
	if TimeManager.has_signal("day_advanced"):
		TimeManager.day_advanced.connect(_on_day_advanced)

# -- Signal handlers -----------------------------------------------------------

const DANDELION_DEATH_DAY := 64  # Day of year when all dandelions die (Wide-Clover day 8)

## On month changed.

## Disconnect signals when exiting tree.
func _exit_tree() -> void:
	pass  # Signal cleanup handled by node references
func _on_month_changed(month_name: String) -> void:
	match month_name:
		"Quickening":
			# Spring begins -- perform the annual roll
			_do_annual_roll()

## On day advanced.
func _on_day_advanced(new_day: int) -> void:
	# Check for despawn -- dandelions die by day 64 (Wide-Clover day 8)
	if _bloomed:
		var year_start: int = (TimeManager.current_year() - 1) * TimeManager.YEAR_LENGTH
		var day_of_year: int = new_day - year_start
		if day_of_year >= DANDELION_DEATH_DAY:
			_clear_dandelions()
		return

	if current_outcome.is_empty():
		return
	# Check if we've hit the bloom day for this spring
	# bloom_day is stored as day-within-year (1-224); convert to absolute day
	var spring_start_day: int = (TimeManager.current_year() - 1) * TimeManager.YEAR_LENGTH + 1
	var absolute_bloom_day: int = spring_start_day + (bloom_day - 1)
	if new_day >= absolute_bloom_day:
		_spawn_dandelions()

# -- Annual Roll Logic ---------------------------------------------------------

## Performs the one-time-per-year dandelion bloom quality assessment.
## GDD S14.8.1 roll factors:
##   50% -- base random component (die roll)
##   20% -- weather pattern seed (derived from year seed)
##   15% -- prior fall conditions (goldenrod quality -> seed set)
##   15% -- long-term site factors (hardcoded mild positive for home property)
func _do_annual_roll() -> void:
	var year := TimeManager.current_year()
	if year == current_year:
		return  # already rolled this year
	current_year = year
	_bloomed = false

	# Reproducible per-year seed so reloading gives same result
	var year_seed := year * 73856093 ^ year * 19349663
	var rng := RandomNumberGenerator.new()
	rng.seed = year_seed

	# -- 1. Base random component (50% weight) ---------------------------------
	var base_roll := rng.randf()  # 0.0-1.0

	# -- 2. Weather pattern seed (20% weight) ----------------------------------
	# Derived from year -- even years slightly warmer (earlier bloom), odd cooler
	var weather_roll := rng.randf()
	var weather_bias: float = 0.05 if (year % 2 == 0) else -0.05

	# -- 3. Prior fall conditions (15% weight) ---------------------------------
	# More seed set last fall -> better bloom this spring
	var fall_bonus: float = 0.1 if _prior_goldenrod_good else -0.05

	# -- 4. Long-term site factors (15% weight) --------------------------------
	# Home property: modest positive (mowed lawn borders, disturbed soil = good)
	var site_factor := 0.05

	# -- Weighted composite score -----------------------------------------------
	var score := (base_roll * 0.50) + (weather_roll * 0.20) + weather_bias + fall_bonus + site_factor
	score = clampf(score, 0.0, 1.0)

	# -- Map score to outcome ---------------------------------------------------
	if score < 0.22:
		current_outcome = QUALITY_POOR
	elif score < 0.50:
		current_outcome = QUALITY_AVERAGE
	elif score < 0.78:
		current_outcome = QUALITY_GOOD
	else:
		current_outcome = QUALITY_EXCEPTIONAL

	# -- Density within range ---------------------------------------------------
	var d_range: Array = DENSITY_RANGE[current_outcome]
	current_density = d_range[0] + rng.randf() * (d_range[1] - d_range[0])

	# -- Bloom day -- quality shifts timing within late Quickening --------------
	bloom_day = BLOOM_DAY_BY_QUALITY.get(current_outcome, 25)

	print("Dandelion Roll - Year %d: %s (density %.2f, bloom day %d)" % [
		year, current_outcome, current_density, bloom_day
	])

	bloom_quality_rolled.emit(current_outcome, current_density, bloom_day)

	# Inform ForageManager so it can update spring NU
	ForageManager.set_dandelion_bloom(current_outcome, current_density)

	# Do NOT immediately spawn -- wait for bloom_day via _on_day_advanced()

# -- Spawning -----------------------------------------------------------------

## Spawns dandelion sprites across the grass zone at the computed density.
## Override _get_grass_zone_rect() in a sub-scene for a different footprint.
func _spawn_dandelions() -> void:
	if _bloomed:
		return
	_bloomed = true

	# Clear any leftover dandelions from last year
	for child in _layer.get_children():
		child.queue_free()

	var zone := _get_grass_zone_rect()
	var tex: Texture2D = load(DANDELION_SPRITE) as Texture2D
	if tex == null:
		push_warning("DandelionSpawner: Could not load %s" % DANDELION_SPRITE)
		return

	# Grid of 16x16 tiles; probability = density
	var tile_w := 16
	var tile_h := 16
	var count  := 0

	var rng := RandomNumberGenerator.new()
	rng.seed = TimeManager.current_year() * 91234567

	# Edge tiles near paths/fences more likely -- GDD S14.8.1 spatial bias
	var cols := int(zone.size.x / tile_w)
	var rows := int(zone.size.y / tile_h)

	for row in range(rows):
		for col in range(cols):
			# Edge bias: tiles within 2 of the border get +25% chance
			var is_edge: bool = (row <= 1 or row >= rows-2 or col <= 1 or col >= cols-2)
			var threshold: float = current_density + (0.25 if is_edge else 0.0)
			if rng.randf() < clampf(threshold, 0.0, 1.0):
				var sprite := Sprite2D.new()
				sprite.texture = tex
				@warning_ignore("INTEGER_DIVISION")
				sprite.position = Vector2(
					zone.position.x + col * tile_w + tile_w / 2,
					zone.position.y + row * tile_h + tile_h / 2
				)
				# z_index 1 -- renders below equipment/buildings (which use z=3+)
				sprite.z_index = 1
				_layer.add_child(sprite)
				count += 1

	print("Dandelions spawned: %d (density=%.2f, %s)" % [count, current_density, current_outcome])
	dandelions_bloomed.emit(current_outcome, count)

## Removes all spawned dandelion sprites.
func _clear_dandelions() -> void:
	for child in _layer.get_children():
		child.queue_free()
	_bloomed = false
	dandelions_cleared.emit()
	print("Dandelions cleared for summer.")

# -- Area / Zone ----------------------------------------------------------------

## Returns the grass footprint rect in world space for dandelion seeding.
## HomeProperty grass covers roughly the tilemap playable area.
## Override per scene for accuracy.
func _get_grass_zone_rect() -> Rect2:
	# HomeProperty: the playable lawn/field area excluding paths and buildings.
	# Rough footprint based on tilemap position and known scene bounds.
	return Rect2(Vector2(-14, -26), Vector2(1600, 900))

# -- Public API -----------------------------------------------------------------

## Returns the current year's dandelion NU contribution for a forage calculation.
func get_dandelion_nu() -> float:
	if not _bloomed or current_outcome.is_empty():
		return 0.0
	# Only contributes during Quickening (month 0) and Greening (month 1)
	var month := TimeManager.current_month_index()
	if month > 1:
		return 0.0
	return NU_BY_QUALITY.get(current_outcome, 0.0)

## Called by mowing action -- removes dandelions from a specific tile zone.
## target_rect is in world space. Dandelions removed stay gone for 2-3 weeks.
func mow_area(target_rect: Rect2) -> int:
	var removed := 0
	for child in _layer.get_children():
		if child is Sprite2D and target_rect.has_point(child.position):
			child.queue_free()
			removed += 1
	print("Mowed %d dandelions." % removed)
	return removed

## Set by ForageManager at end of fall to inform next spring's roll.
func set_prior_goldenrod_quality(was_good: bool) -> void:
	_prior_goldenrod_good = was_good
