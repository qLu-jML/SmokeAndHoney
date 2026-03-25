# flower_lifecycle_manager.gd -- Seasonal flower growth, spread, and lifecycle system
# -----------------------------------------------------------------------------
# Replaces garden beds, wildflower_scatter, and dandelion_spawner with a
# unified organic flower system.
#
# Each SEASON receives a random quality ranking: S > A > B > C > D > F
# B rank is "average" -- supports 1-2 hives in the starting area.
#
# 5-Phase Lifecycle per tile:
#   SEED -> SPROUT -> GROWING -> MATURE -> WITHERED -> (removed)
#   Only MATURE plants produce nectar and pollen (protein).
#   WITHERED plants persist 4-6 days, occupying space to prevent runaway spread.
#   Spread only occurs FROM mature tiles; new tiles begin as SEED.
#
# Calendar (224-day year, 28 days/month, 8 months):
#   Spring:  Quickening (0) + Greening (1)     -- Days 1-56
#   Summer:  Wide-Clover (2) + High-Sun (3)    -- Days 57-112
#   Fall:    Full-Earth (4) + Reaping (5)       -- Days 113-168
#   Winter:  Deepcold (6) + Kindlemonth (7)     -- Days 169-224
#
# Iowa-native (or naturalized) bee forage -- bloom windows (day-of-year):
#   Dandelion:        Day 5-50   (early spring, first forage)
#   White Clover:     Day 30-140 (late spring -> early fall, Iowa honey backbone)
#   Wild Bergamot:    Day 55-105 (summer prairie native, Monarda fistulosa)
#   Purple Coneflower:Day 60-130 (summer native, Echinacea purpurea)
#   Sunflower:        Day 80-130 (mid-summer -> early fall, crop + wild)
#   Goldenrod:        Day 110-165 (late summer -> fall, heavy nectar)
#   Aster:            Day 120-165 (fall, New England Aster, last major flow)
#
# Attach this script to a Node2D in the World scene.
# -----------------------------------------------------------------------------
extends Node2D
class_name FlowerLifecycleManager

# -- Signals ------------------------------------------------------------------
signal season_ranked(season_name: String, rank: String)
signal flowers_updated(total_count: int)

# -- Phase Constants --------------------------------------------------------
const PHASE_SEED     := 0
const PHASE_SPROUT   := 1
const PHASE_GROWING  := 2
const PHASE_MATURE   := 3
const PHASE_WITHERED := 4
const PHASE_NAMES := ["seed", "sprout", "growing", "mature", "withered"]

# -- NU Scaling -------------------------------------------------------------
# Per-tile nectar/pollen values are whole-number "points" (1-5 scale).
# NU_SCALE converts tile-point totals into GDD-scale Nectar Units:
#   Zone NU = sum(mature_tiles x species_points) / NU_SCALE
# Calibrated so B-rank wildflowers alone produce ~35-43 NU at peak summer,
# supporting 1-2 hives (20 NU/week demand per hive). Player-planted gardens
# and trees push toward the GDD's 80-100 NU "fully developed" target.
const NU_SCALE := 250

# Withered phase duration range (days)
const WITHER_MIN_DAYS := 4
const WITHER_MAX_DAYS := 6

# -- Season Ranking Constants -------------------------------------------------
const RANKS := ["S", "A", "B", "C", "D", "F"]

# Probability weights for each rank (B is most common)
const RANK_WEIGHTS := {
	"S": 0.05,   # 5%  -- exceptional year
	"A": 0.15,   # 15% -- good year
	"B": 0.35,   # 35% -- average year
	"C": 0.25,   # 25% -- below average
	"D": 0.15,   # 15% -- poor year
	"F": 0.05,   # 5%  -- total failure
}

# -- Density & Spread Parameters by Rank --------------------------------------
const RANK_PARAMS := {
	"S": { "initial_density": 0.30, "spread_chance": 0.12, "max_coverage": 0.55 },
	"A": { "initial_density": 0.22, "spread_chance": 0.08, "max_coverage": 0.42 },
	"B": { "initial_density": 0.16, "spread_chance": 0.05, "max_coverage": 0.30 },
	"C": { "initial_density": 0.10, "spread_chance": 0.025, "max_coverage": 0.20 },
	"D": { "initial_density": 0.05, "spread_chance": 0.008, "max_coverage": 0.10 },
	"F": { "initial_density": 0.02, "spread_chance": 0.0,   "max_coverage": 0.04 },
}

# -- Flower Type Definitions --------------------------------------------------
# bloom_start/end: day-of-year (1-224)
# peak_start/peak_end: sub-window within bloom for the MATURE phase
# nu_nectar/nu_pollen: forage contribution per mature tile
# phase_days: approximate days each non-terminal phase lasts
#   (calculated from bloom window length at runtime)
const FLOWER_TYPES := {
	# -- SPRING ----------------------------------------------------------------
	# Dandelion (Taraxacum officinale) -- Iowa's first spring forage.
	# Naturalized weed, appears in lawns/fields as soon as frost breaks.
	# Moderate nectar, good pollen. Short bloom, but critical for buildup.
	"dandelion": {
		"bloom_start": 1,  "bloom_end": 50,
		"peak_start":  3,  "peak_end":  40,
		"nu_nectar": 3,    "nu_pollen": 3,
		"edge_bias": false,
	},

	# -- SPRING -> FALL (backbone) ----------------------------------------------
	# White Clover (Trifolium repens) -- THE Iowa honey plant.
	# Naturalized throughout Iowa pastures, roadsides, lawns.
	# Longest bloom of any species; highest nectar producer. Light, mild honey.
	"clover": {
		"bloom_start": 30,  "bloom_end": 140,
		"peak_start":  42,  "peak_end":  118,
		"nu_nectar": 4,     "nu_pollen": 2,
		"edge_bias": false,
	},

	# -- SUMMER ----------------------------------------------------------------
	# Wild Bergamot (Monarda fistulosa) -- Native Iowa prairie perennial.
	# Lavender-pink tubular flowers, excellent nectar source.
	# Found in prairie remnants, roadsides, dry uplands across Iowa.
	"bergamot": {
		"bloom_start": 55,  "bloom_end": 105,
		"peak_start":  65,  "peak_end":  95,
		"nu_nectar": 3,     "nu_pollen": 2,
		"edge_bias": false,
	},

	# Purple Coneflower (Echinacea purpurea) -- Iconic Iowa prairie native.
	# Tall daisy-like blooms with drooping pink-purple petals, dark cone center.
	# Good pollen source, moderate nectar. Found in every Iowa prairie planting.
	"coneflower": {
		"bloom_start": 60,  "bloom_end": 130,
		"peak_start":  72,  "peak_end":  115,
		"nu_nectar": 2,     "nu_pollen": 3,
		"edge_bias": false,
	},

	# Sunflower (Helianthus annuus) -- Iowa crop and wild species.
	# Massive pollen producer, moderate nectar. Grows along field edges.
	"sunflower": {
		"bloom_start": 80,  "bloom_end": 130,
		"peak_start":  90,  "peak_end":  120,
		"nu_nectar": 2,     "nu_pollen": 4,
		"edge_bias": false,
	},

	# -- FALL ------------------------------------------------------------------
	# Goldenrod (Solidago spp.) -- Iowa's dominant fall nectar source.
	# Multiple native species across the state. Heavy nectar, moderate pollen.
	# Produces dark, strongly flavored "fall honey." Grows in field margins.
	"goldenrod": {
		"bloom_start": 110, "bloom_end": 165,
		"peak_start":  118, "peak_end":  155,
		"nu_nectar": 3,     "nu_pollen": 1,
		"edge_bias": true,
	},

	# New England Aster (Symphyotrichum novae-angliae) -- Native fall companion.
	# Purple-rayed flowers, pairs with goldenrod for the last major flow.
	# Moderate nectar and pollen. Found in moist prairies, ditches.
	"aster": {
		"bloom_start": 120, "bloom_end": 165,
		"peak_start":  128, "peak_end":  158,
		"nu_nectar": 2,     "nu_pollen": 2,
		"edge_bias": true,
	},
}

# -- Grass Zone / Tile Grid ---------------------------------------------------
const TILE_SIZE     := 16
const GRASS_ORIGIN  := Vector2(-14, -26)
const GRASS_SIZE    := Vector2(1600, 900)
var _grid_cols: int
var _grid_rows: int
var _total_tiles: int

# -- State --------------------------------------------------------------------
# Per-season ranking (persists across the year, re-rolled each season)
var season_rankings: Dictionary = {}

# flower_grid[type_name] = Dictionary of { Vector2i : { "phase": int, "day": int } }
#   phase = current lifecycle phase (PHASE_SEED .. PHASE_WITHERED)
#   day   = absolute day (TimeManager.current_day) when this tile entered its phase
var flower_grid: Dictionary = {}

# Active Sprite2D nodes per tile: { sprite_key(String) : Sprite2D }
var _active_sprites: Dictionary = {}

# Loaded textures cache: { "dandelion_seed" : Texture2D, ... }
var _textures: Dictionary = {}

# Sprite parent node
var _flower_layer: Node2D = null

# Track which flower types have been initially spawned this year
var _spawned_this_year: Dictionary = {}

# Pre-computed phase durations per type: { type_name: { 0: days, 1: days, ... } }
var _phase_durations: Dictionary = {}

# RNG with year-based seed for reproducibility
var _rng: RandomNumberGenerator

# Track current year to detect new year
var _current_year: int = -1

# -- Lifecycle ----------------------------------------------------------------

func _ready() -> void:
	add_to_group("flower_lifecycle_manager")
	add_to_group("flowers")

	_grid_cols = int(GRASS_SIZE.x / TILE_SIZE)
	_grid_rows = int(GRASS_SIZE.y / TILE_SIZE)
	_total_tiles = _grid_cols * _grid_rows

	_flower_layer = Node2D.new()
	_flower_layer.name = "FlowerLayer"
	add_child(_flower_layer)

	# Pre-load phase textures for every species
	for type_name in FLOWER_TYPES:
		for phase_name in PHASE_NAMES:
			var tex_key := "%s_%s" % [type_name, phase_name]
			var path := "res://assets/sprites/world/forage/%s.png" % tex_key
			var tex = load(path)
			if tex:
				_textures[tex_key] = tex
			else:
				push_warning("FlowerLifecycleManager: Missing texture %s" % path)

	# Initialize flower grids
	for type_name in FLOWER_TYPES:
		flower_grid[type_name] = {}

	# Compute phase durations for each flower type
	_compute_phase_durations()

	# Connect to TimeManager signals
	if TimeManager.has_signal("day_advanced"):
		TimeManager.day_advanced.connect(_on_day_advanced)
	if TimeManager.has_signal("season_changed"):
		TimeManager.season_changed.connect(_on_season_changed)

	_rng = RandomNumberGenerator.new()

	_check_year_change()
	_update_flowers()

# -- Phase Duration Computation ------------------------------------------------
# Each flower's bloom window is divided into gameplay-friendly phases.
# Early phases (seed/sprout/growing) are kept SHORT so the player sees
# visible progress each day. Mature is the longest phase (productive window).
# Withered is fixed at 4-6 days to block spread and add visual variety.
#
# Target proportions (of bloom_len minus wither):
#   SEED 2-3 days, SPROUT 2-4 days, GROWING 3-6 days, MATURE = remainder
# This ensures even short-lived dandelions (45 days) feel dynamic.

func _compute_phase_durations() -> void:
	for type_name in FLOWER_TYPES:
		var def: Dictionary = FLOWER_TYPES[type_name]
		var bloom_len: int = def["bloom_end"] - def["bloom_start"]
		var wither_days: int = 5  # middle of 4-6 range

		# Growth window = total bloom minus wither period
		var growth_window: int = maxi(bloom_len - wither_days, 10)

		# Scale early phases with bloom length but cap them for snappy gameplay
		var seed_d: int   = clampi(int(growth_window * 0.06), 2, 4)
		var sprout_d: int = clampi(int(growth_window * 0.07), 2, 5)
		var grow_d: int   = clampi(int(growth_window * 0.10), 3, 7)
		var mature_d: int = maxi(growth_window - seed_d - sprout_d - grow_d, 5)

		_phase_durations[type_name] = {
			PHASE_SEED: seed_d,
			PHASE_SPROUT: sprout_d,
			PHASE_GROWING: grow_d,
			PHASE_MATURE: mature_d,
			PHASE_WITHERED: wither_days,
		}

# -- Signal Handlers ----------------------------------------------------------

func _on_season_changed(season_name: String) -> void:
	_check_year_change()
	_roll_season_ranking(season_name)

func _on_day_advanced(_new_day: int) -> void:
	_check_year_change()
	_update_flowers()

# -- Year Management ----------------------------------------------------------

func _check_year_change() -> void:
	var year := TimeManager.current_year()
	if year != _current_year:
		_current_year = year
		_rng.seed = year * 73856093
		_spawned_this_year.clear()
		for type_name in flower_grid:
			flower_grid[type_name].clear()
		_clear_all_sprites()
		for season in ["spring", "summer", "fall", "winter"]:
			if not season_rankings.has(season):
				_roll_season_ranking(season)

# -- Ranking System -----------------------------------------------------------

func _roll_season_ranking(season_name: String) -> void:
	var key := season_name.to_lower()
	if key in ["quickening", "greening"]:
		key = "spring"
	elif key in ["wide-clover", "high-sun"]:
		key = "summer"
	elif key in ["full-earth", "reaping"]:
		key = "fall"
	elif key in ["deepcold", "kindlemonth"]:
		key = "winter"

	var roll := _rng.randf()
	var cumulative := 0.0
	var rank := "B"
	for r in RANKS:
		cumulative += RANK_WEIGHTS[r]
		if roll <= cumulative:
			rank = r
			break

	season_rankings[key] = rank
	print("? Season rank for %s: %s" % [key, rank])
	season_ranked.emit(key, rank)

func get_current_rank() -> String:
	var month := TimeManager.current_month_index()
	var season: String
	if month <= 1:
		season = "spring"
	elif month <= 3:
		season = "summer"
	elif month <= 5:
		season = "fall"
	else:
		season = "winter"
	return season_rankings.get(season, "B")

# -- Core Flower Update (called daily) ----------------------------------------

func _update_flowers() -> void:
	var day_of_year := _get_day_of_year()
	var abs_day: int = TimeManager.current_day
	var rank := get_current_rank()
	var params: Dictionary = RANK_PARAMS[rank]

	for type_name in FLOWER_TYPES:
		var def: Dictionary = FLOWER_TYPES[type_name]
		var bloom_start: int = def["bloom_start"]
		var bloom_end:   int = def["bloom_end"]
		var is_in_window := (day_of_year >= bloom_start and day_of_year <= bloom_end)

		var grid: Dictionary = flower_grid[type_name]

		if is_in_window:
			# Initial spawn if first time this year
			if not _spawned_this_year.has(type_name):
				_initial_spawn(type_name, params, abs_day)
				_spawned_this_year[type_name] = true

			# Advance phases for existing tiles
			_advance_phases(type_name, abs_day)

			# Spread from mature tiles
			_spread_flowers(type_name, params, abs_day)

		else:
			# Outside bloom window -- if past bloom_end, force remaining to wither
			if day_of_year > bloom_end and not grid.is_empty():
				_force_wither_all(type_name, abs_day)
				_advance_phases(type_name, abs_day)

		# Update sprites for all existing tiles
		_update_sprites(type_name)

	# Emit update signal
	var total := 0
	for type_name in flower_grid:
		total += flower_grid[type_name].size()
	flowers_updated.emit(total)

# -- Initial Spawn ------------------------------------------------------------

func _initial_spawn(type_name: String, params: Dictionary, abs_day: int) -> void:
	var def: Dictionary = FLOWER_TYPES[type_name]
	var density: float = params["initial_density"]
	var edge_bias: bool = def.get("edge_bias", false)
	var grid: Dictionary = flower_grid[type_name]

	# Dandelions get a fast start -- they overwinter as rosettes and pop
	# immediately when spring arrives, so ~60% spawn already GROWING/MATURE
	var fast_start: bool = (type_name == "dandelion")

	for row in range(_grid_rows):
		for col in range(_grid_cols):
			var tile := Vector2i(col, row)
			if grid.has(tile):
				continue

			var is_edge := (row <= 2 or row >= _grid_rows - 3 or col <= 2 or col >= _grid_cols - 3)
			var effective_density := density
			if edge_bias and is_edge:
				effective_density *= 1.5
			elif not edge_bias and is_edge:
				effective_density *= 0.8

			if _rng.randf() < effective_density:
				var start_phase: int = PHASE_SEED
				if fast_start:
					# 30% start mature, 30% growing, 20% sprout, 20% seed
					var roll: float = _rng.randf()
					if roll < 0.30:
						start_phase = PHASE_MATURE
					elif roll < 0.60:
						start_phase = PHASE_GROWING
					elif roll < 0.80:
						start_phase = PHASE_SPROUT
				grid[tile] = { "phase": start_phase, "day": abs_day }

# -- Phase Advancement --------------------------------------------------------
# Each tile tracks when it entered its current phase.
# If enough days have passed, it advances to the next phase.
# Withered tiles are removed after their duration expires.

func _advance_phases(type_name: String, abs_day: int) -> void:
	var grid: Dictionary = flower_grid[type_name]
	var durations: Dictionary = _phase_durations[type_name]
	var to_remove: Array = []

	for tile: Vector2i in grid:
		var data: Dictionary = grid[tile]
		var phase: int = data["phase"]
		var entered: int = data["day"]
		var dur: int = durations.get(phase, 5)

		# For WITHERED, randomize duration per-tile using tile hash
		if phase == PHASE_WITHERED:
			var tile_hash: int = (tile.x * 7919 + tile.y * 6271) & 0xFFFF
			dur = WITHER_MIN_DAYS + (tile_hash % (WITHER_MAX_DAYS - WITHER_MIN_DAYS + 1))

		var days_in_phase: int = abs_day - entered
		if days_in_phase >= dur:
			if phase < PHASE_WITHERED:
				# Advance to next phase
				data["phase"] = phase + 1
				data["day"] = abs_day
			else:
				# WITHERED expired -- mark for removal
				to_remove.append(tile)

	for tile in to_remove:
		grid.erase(tile)
		_remove_sprite(type_name, tile)

# -- Force Wither (post-bloom cleanup) ----------------------------------------

func _force_wither_all(type_name: String, abs_day: int) -> void:
	var grid: Dictionary = flower_grid[type_name]
	for tile: Vector2i in grid:
		var data: Dictionary = grid[tile]
		if data["phase"] < PHASE_WITHERED:
			data["phase"] = PHASE_WITHERED
			data["day"] = abs_day

# -- Daily Spread -------------------------------------------------------------
# Only MATURE tiles can spread. New tiles start as SEED.

func _spread_flowers(type_name: String, params: Dictionary, abs_day: int) -> void:
	var spread_chance: float = params["spread_chance"]
	var max_coverage:  float = params["max_coverage"]

	if spread_chance <= 0.0:
		return

	var grid: Dictionary = flower_grid[type_name]
	var max_tiles := int(float(_total_tiles) * max_coverage)

	if grid.size() >= max_tiles:
		return

	# Collect only MATURE tiles as spread sources
	var mature_tiles: Array = []
	for tile: Vector2i in grid:
		var data: Dictionary = grid[tile]
		if data["phase"] == PHASE_MATURE:
			mature_tiles.append(tile)

	if mature_tiles.is_empty():
		return

	var check_count := mini(mature_tiles.size(), 200)
	for _i in range(check_count):
		if grid.size() >= max_tiles:
			break

		var source: Vector2i = mature_tiles[_rng.randi_range(0, mature_tiles.size() - 1)]

		var dx := _rng.randi_range(-1, 1)
		var dy := _rng.randi_range(-1, 1)
		if dx == 0 and dy == 0:
			continue

		var target := Vector2i(source.x + dx, source.y + dy)

		if target.x < 0 or target.x >= _grid_cols or target.y < 0 or target.y >= _grid_rows:
			continue

		# Skip if already occupied by ANY phase of this type (including withered)
		if grid.has(target):
			continue

		if _rng.randf() < spread_chance:
			grid[target] = { "phase": PHASE_SEED, "day": abs_day }

# -- Sprite Management --------------------------------------------------------

func _update_sprites(type_name: String) -> void:
	var grid: Dictionary = flower_grid[type_name]

	# Remove sprites for tiles that no longer exist
	var keys_to_remove: Array = []
	var prefix := type_name + "_"
	for sprite_key: String in _active_sprites:
		if sprite_key.begins_with(prefix):
			# Extract tile coords from key
			var parts: PackedStringArray = sprite_key.split("_")
			if parts.size() >= 3:
				# Key format: "typename_x_y" but typename may have underscores
				# Use suffix approach
				pass

	# Simpler approach: rebuild sprites for all tiles
	for tile: Vector2i in grid:
		var data: Dictionary = grid[tile]
		var phase: int = data["phase"]
		var phase_name: String = PHASE_NAMES[phase]
		var tex_key := "%s_%s" % [type_name, phase_name]
		var sprite_key := _sprite_key(type_name, tile)

		var tex = _textures.get(tex_key)
		if tex == null:
			continue

		if _active_sprites.has(sprite_key):
			var sprite: Sprite2D = _active_sprites[sprite_key]
			# Update texture if phase changed
			if sprite.texture != tex:
				sprite.texture = tex
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			# Create new sprite
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = _tile_to_world(tile)
			sprite.z_index = 1

			# Per-tile visual variation
			var tile_hash := (tile.x * 7919 + tile.y * 6271) & 0xFFFF
			var t_rng := float(tile_hash) / 65535.0
			sprite.rotation = (t_rng - 0.5) * 0.35
			var s := 0.85 + t_rng * 0.25
			sprite.scale = Vector2(s, s)
			sprite.flip_h = (tile_hash % 3 == 0)

			_flower_layer.add_child(sprite)
			_active_sprites[sprite_key] = sprite

	# Remove orphaned sprites (tiles that were erased)
	var valid_keys: Dictionary = {}
	for tile: Vector2i in grid:
		valid_keys[_sprite_key(type_name, tile)] = true

	var orphans: Array = []
	for sprite_key: String in _active_sprites:
		if sprite_key.begins_with(type_name + "_"):
			if not valid_keys.has(sprite_key):
				orphans.append(sprite_key)

	for key in orphans:
		var sprite: Sprite2D = _active_sprites[key]
		sprite.queue_free()
		_active_sprites.erase(key)

func _remove_sprite(type_name: String, tile: Vector2i) -> void:
	var sprite_key := _sprite_key(type_name, tile)
	if _active_sprites.has(sprite_key):
		var sprite: Sprite2D = _active_sprites[sprite_key]
		sprite.queue_free()
		_active_sprites.erase(sprite_key)

func _clear_all_sprites() -> void:
	for key in _active_sprites:
		var sprite: Sprite2D = _active_sprites[key]
		if is_instance_valid(sprite):
			sprite.queue_free()
	_active_sprites.clear()

# -- Public API ----------------------------------------------------------------

## Returns the forage at a world position as GDD-scale NU.
## Only MATURE tiles contribute nectar and pollen.
## Result is divided by NU_SCALE to convert tile-points to GDD NU.
func get_forage_at(world_pos: Vector2) -> Dictionary:
	var result := { "nectar": 0.0, "pollen": 0.0 }
	var sample_tile := _world_to_tile(world_pos)
	var sample_radius := 2

	for type_name in FLOWER_TYPES:
		var def: Dictionary = FLOWER_TYPES[type_name]
		var grid: Dictionary = flower_grid[type_name]
		if grid.is_empty():
			continue

		# Count MATURE tiles in sample area
		var mature_count := 0
		var total_sampled := 0
		for dy in range(-sample_radius, sample_radius + 1):
			for dx in range(-sample_radius, sample_radius + 1):
				var check := Vector2i(sample_tile.x + dx, sample_tile.y + dy)
				if check.x >= 0 and check.x < _grid_cols and check.y >= 0 and check.y < _grid_rows:
					total_sampled += 1
					if grid.has(check):
						var data: Dictionary = grid[check]
						if data["phase"] == PHASE_MATURE:
							mature_count += 1

		if total_sampled == 0 or mature_count == 0:
			continue

		var local_density: float = float(mature_count) / float(total_sampled)
		result["nectar"] += float(def["nu_nectar"]) * local_density / float(NU_SCALE)
		result["pollen"] += float(def["nu_pollen"]) * local_density / float(NU_SCALE)

	return result

## Returns the total raw nectar points available in the current zone.
## Only counts MATURE tiles. Formula: sum(mature_tiles x species_nectar_points).
## This is the map-wide total of all individual plant nectar values combined.
## To convert to GDD-scale NU for hive demand comparisons, divide by NU_SCALE.
func get_total_zone_nectar() -> int:
	var total_points := 0

	for type_name in FLOWER_TYPES:
		var def: Dictionary = FLOWER_TYPES[type_name]
		var grid: Dictionary = flower_grid[type_name]
		if grid.is_empty():
			continue

		var mature_count := 0
		for tile: Vector2i in grid:
			var data: Dictionary = grid[tile]
			if data["phase"] == PHASE_MATURE:
				mature_count += 1

		if mature_count > 0:
			total_points += def["nu_nectar"] * mature_count

	return total_points

## Returns the total raw pollen points available in the current zone.
## Only counts MATURE tiles. Formula: sum(mature_tiles x species_pollen_points).
## This is the map-wide total of all individual plant pollen values combined.
## To convert to GDD-scale PU for hive demand comparisons, divide by NU_SCALE.
func get_total_zone_pollen() -> int:
	var total_points := 0

	for type_name in FLOWER_TYPES:
		var def: Dictionary = FLOWER_TYPES[type_name]
		var grid: Dictionary = flower_grid[type_name]
		if grid.is_empty():
			continue

		var mature_count := 0
		for tile: Vector2i in grid:
			var data: Dictionary = grid[tile]
			if data["phase"] == PHASE_MATURE:
				mature_count += 1

		if mature_count > 0:
			total_points += def["nu_pollen"] * mature_count

	return total_points

## Convenience: returns GDD-scale NU (raw points / NU_SCALE) for hive demand math.
func get_zone_nectar_gdd_scale() -> float:
	return float(get_total_zone_nectar()) / float(NU_SCALE)

## Convenience: returns GDD-scale PU (raw points / NU_SCALE) for hive demand math.
func get_zone_pollen_gdd_scale() -> float:
	return float(get_total_zone_pollen()) / float(NU_SCALE)

## Returns the dominant blooming plant name (for varietal honey labeling)
func get_dominant_plant() -> String:
	var best_type := ""
	var best_count := 0

	for type_name in FLOWER_TYPES:
		var grid: Dictionary = flower_grid[type_name]
		var mature_count := 0
		for tile: Vector2i in grid:
			var data: Dictionary = grid[tile]
			if data["phase"] == PHASE_MATURE:
				mature_count += 1
		if mature_count > best_count:
			best_count = mature_count
			best_type = type_name

	return best_type if best_type != "" else "wildflower"

## Returns a list of flower types that currently have mature tiles
func get_blooming_types() -> Array:
	var result: Array = []
	for type_name in FLOWER_TYPES:
		var grid: Dictionary = flower_grid[type_name]
		for tile: Vector2i in grid:
			var data: Dictionary = grid[tile]
			if data["phase"] == PHASE_MATURE:
				result.append(type_name)
				break
	return result

## Called by external systems (e.g. hud.gd +Day button) to advance flowers.
func advance_day_with_global(new_day: int) -> void:
	_check_year_change()
	_update_flowers()

# -- Helpers ------------------------------------------------------------------

func _get_day_of_year() -> int:
	var abs_day := TimeManager.current_day
	var year_len := TimeManager.YEAR_LENGTH
	return ((abs_day - 1) % year_len) + 1

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(
		GRASS_ORIGIN.x + float(tile.x) * TILE_SIZE + TILE_SIZE * 0.5,
		GRASS_ORIGIN.y + float(tile.y) * TILE_SIZE + TILE_SIZE * 0.5
	)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int((world_pos.x - GRASS_ORIGIN.x) / TILE_SIZE), 0, _grid_cols - 1),
		clampi(int((world_pos.y - GRASS_ORIGIN.y) / TILE_SIZE), 0, _grid_rows - 1),
	)

func _sprite_key(type_name: String, tile: Vector2i) -> String:
	return "%s_%d_%d" % [type_name, tile.x, tile.y]
