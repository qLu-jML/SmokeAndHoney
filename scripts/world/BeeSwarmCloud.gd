# BeeSwarmCloud.gd
# -----------------------------------------------------------------------------
# Visual bee swarm around the overworld hive that communicates colony health
# and activity at a glance -- no numbers, just behavior the player reads.
#
# THREE visual layers:
#   1. Entrance swarm  -- GPUParticles2D near the landing board (ambient buzz)
#   2. Overhead cloud   -- GPUParticles2D above the hive (loose dome)
#   3. Forager flights  -- Scripted Sprite2D bees that fly to nearby flowers,
#                          pause to "gather", then fly back to the hive.
#                          Purely cosmetic -- actual resource math is in the
#                          simulation pipeline (ForagerSystem.gd).
#
# All three layers are driven by snapshot data each tick.
# -----------------------------------------------------------------------------
extends Node2D
class_name BeeSwarmCloud

# -- Forager state machine ----------------------------------------------------
enum FState { TO_FLOWER, GATHERING, TO_HIVE, RESTING }

# -- Breed sprite lookup ------------------------------------------------------
# Tiny 8x8 top-down bee silhouettes with breed-specific coloring.
# Italian = golden, Buckfast = brown, Carniolan = charcoal, Caucasian = dark gray,
# Russian = near-black.  Falls back to generic bee_particle.png if missing.
const BREED_SPRITE_PATH := "res://assets/sprites/fx/bee_forager_%s.png"
const BREED_NAMES_LOWER := ["italian", "buckfast", "carniolan", "caucasian", "russian"]

# -- Particle / forager texture -----------------------------------------------
var _bee_tex: Texture2D = null
var _current_breed: String = ""

# -- GPU particle emitters (ambient buzz) ------------------------------------
var _entrance: GPUParticles2D = null
var _overhead: GPUParticles2D = null
var _entrance_mat: ParticleProcessMaterial = null
var _overhead_mat: ParticleProcessMaterial = null

# -- Composite scores (smoothed) ---------------------------------------------
var _activity: float = 0.0
var _agitation: float = 0.0
var _target_activity: float = 0.0
var _target_agitation: float = 0.0
const LERP_SPEED := 2.0

# -- Tuning: baselines -------------------------------------------------------
const POP_BASELINE := 30000.0
const FORAGER_BASELINE := 10000.0
const MITE_DANGER := 3000.0

# -- Particle tuning ----------------------------------------------------------
const ENTRANCE_MIN_AMOUNT := 1
const ENTRANCE_MAX_AMOUNT := 60
const OVERHEAD_MIN_AMOUNT := 1
const OVERHEAD_MAX_AMOUNT := 35

const SPEED_CALM_MIN := 20.0
const SPEED_CALM_MAX := 40.0
const SPEED_AGITATED_MIN := 50.0
const SPEED_AGITATED_MAX := 90.0

const ENTRANCE_SPREAD_MIN := Vector3(6.0, 2.0, 0.0)
const ENTRANCE_SPREAD_MAX := Vector3(18.0, 4.0, 0.0)
const OVERHEAD_SPREAD_MIN := Vector3(8.0, 4.0, 0.0)
const OVERHEAD_SPREAD_MAX := Vector3(22.0, 10.0, 0.0)

const COLOR_HEALTHY := Color(1.0, 1.0, 1.0, 0.90)
const COLOR_STRESSED := Color(1.0, 0.6, 0.4, 0.95)

# -- Forager tuning -----------------------------------------------------------
const FORAGER_SPEED := 70.0         # px/s flight speed
const FORAGER_SPEED_JITTER := 20.0  # +/- random per bee
const GATHER_TIME_MIN := 1.5        # seconds at flower
const GATHER_TIME_MAX := 3.5
const REST_TIME_MIN := 0.3          # seconds at hive before next trip
const REST_TIME_MAX := 1.0
const SEARCH_RADIUS := 250.0        # how far foragers look for flowers
const MAX_FORAGERS := 12            # visual cap (performance)
const MIN_FORAGERS := 1             # at least 1 if colony is alive
const FORAGER_WOBBLE := 1.5         # px amplitude of flight wobble

# -- Forager pool -------------------------------------------------------------
# Each entry: { "sprite": Sprite2D, "state": FState, "target": Vector2,
#               "timer": float, "speed": float, "wobble_phase": float }
var _foragers: Array = []
var _desired_forager_count: int = 0

# -- Cached flower positions (refreshed periodically) ------------------------
var _flower_targets: Array = []   # Array of Vector2 (global positions)
var _flower_scan_timer: float = 0.0
const FLOWER_SCAN_INTERVAL := 3.0  # seconds between scans

# -- Hive reference position (global coords for forager return) ---------------
var _hive_entrance_local := Vector2(0.0, -4.0)

# =============================================================================
#  LIFECYCLE
# =============================================================================

## Ready.
func _ready() -> void:
	# Load generic fallback -- breed-specific texture applied on first snapshot
	_bee_tex = load("res://assets/sprites/fx/bee_particle.png") as Texture2D
	if _bee_tex == null:
		push_warning("BeeSwarmCloud: bee_particle.png not found")

	_setup_entrance_emitter()
	_setup_overhead_emitter()

	_entrance.emitting = false
	_overhead.emitting = false

## Swap all particle + forager textures to match the colony's breed.
func _set_breed(species: String) -> void:
	var key: String = species.to_lower()
	if key == _current_breed:
		return  # already using this breed
	_current_breed = key

	# Try to load the breed-specific sprite
	var path: String = BREED_SPRITE_PATH % key
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		# Fallback to generic
		tex = load("res://assets/sprites/fx/bee_particle.png") as Texture2D
	if tex == null:
		return
	_bee_tex = tex

	# Update GPU particle emitters
	if _entrance:
		_entrance.texture = _bee_tex
	if _overhead:
		_overhead.texture = _bee_tex

	# Update all existing forager sprites
	for f in _foragers:
		if is_instance_valid(f["sprite"]):
			f["sprite"].texture = _bee_tex

## Process.
func _process(delta: float) -> void:
	# Smooth particle scores
	_activity = lerp(_activity, _target_activity, LERP_SPEED * delta)
	_agitation = lerp(_agitation, _target_agitation, LERP_SPEED * delta)
	_apply_to_materials()

	# Periodically rescan for flowers
	_flower_scan_timer -= delta
	if _flower_scan_timer <= 0.0:
		_flower_scan_timer = FLOWER_SCAN_INTERVAL
		_refresh_flower_targets()

	# Manage forager pool size
	_sync_forager_pool()

	# Tick each active forager
	_tick_foragers(delta)

# =============================================================================
#  PUBLIC API
# =============================================================================

func update_from_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		_target_activity = 0.0
		_target_agitation = 0.0
		_desired_forager_count = 0
		_entrance.emitting = false
		_overhead.emitting = false
		return

	# -- Breed texture --------------------------------------------------------
	var species: String = snap.get("queen_species", "Carniolan")
	_set_breed(species)

	# -- Activity score -------------------------------------------------------
	# Population and foragers are the dominant signals -- a new hive with
	# 8k bees should look nearly empty, a booming 30k hive should buzz.
	# Health is a light modifier so sick hives look slightly subdued.
	var pop_ratio: float = clampf(float(snap.get("total_adults", 0)) / POP_BASELINE, 0.0, 1.0)
	var forager_ratio: float = clampf(float(snap.get("forager_count", 0)) / FORAGER_BASELINE, 0.0, 1.0)
	var health_ratio: float = clampf(float(snap.get("health_score", 50.0)) / 100.0, 0.0, 1.0)

	# Population 50% | Foragers 35% | Health 15%
	var raw_activity: float = pop_ratio * 0.50 + forager_ratio * 0.35 + health_ratio * 0.15
	_target_activity = clampf(raw_activity, 0.0, 1.0)

	# -- Agitation score ------------------------------------------------------
	var congestion: int = snap.get("congestion_state", 0)
	var congestion_factor: float = 0.0
	if congestion == 1 or congestion == 2:
		congestion_factor = 0.4
	elif congestion == 3:
		congestion_factor = 0.7

	var mite_factor: float = clampf(float(snap.get("mite_count", 0.0)) / MITE_DANGER, 0.0, 1.0)
	var afb_factor: float = 1.0 if snap.get("afb_active", false) else 0.0
	var stress_from_health: float = clampf(1.0 - health_ratio, 0.0, 1.0)

	var raw_agitation: float = congestion_factor * 0.35 + mite_factor * 0.25 \
		+ afb_factor * 0.20 + stress_from_health * 0.20
	_target_agitation = clampf(raw_agitation, 0.0, 1.0)

	# -- Emitter enable -------------------------------------------------------
	var should_emit: bool = _target_activity > 0.05
	_entrance.emitting = should_emit
	# Overhead only for colonies with real presence
	_overhead.emitting = should_emit and _target_activity > 0.40

	# -- Forager count (scales with forager_count from snapshot) ---------------
	var raw_foragers: int = snap.get("forager_count", 0)
	# Squared curve: few foragers = almost nothing visible, many = full fleet
	var forager_t: float = clampf(float(raw_foragers) / FORAGER_BASELINE, 0.0, 1.0)
	var visual_count: int = int(forager_t * forager_t * float(MAX_FORAGERS))
	# Only guarantee a minimum if there are substantial foragers
	if raw_foragers >= 1000 and visual_count < MIN_FORAGERS:
		visual_count = MIN_FORAGERS
	_desired_forager_count = visual_count

func set_hive_extents(entrance_y: float, top_y: float) -> void:
	_entrance.position = Vector2(0.0, entrance_y + 2.0)
	_overhead.position = Vector2(0.0, top_y - 6.0)
	_hive_entrance_local = Vector2(0.0, entrance_y)

# =============================================================================
#  FORAGER FLIGHT SYSTEM
# =============================================================================

func _refresh_flower_targets() -> void:
	_flower_targets.clear()
	var hive_global: Vector2 = global_position + _hive_entrance_local
	# Scan for flower nodes in the scene
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var flowers: Array = tree.get_nodes_in_group("flowers")
	for f in flowers:
		if f is Node2D:
			var fpos: Vector2 = (f as Node2D).global_position
			if fpos.distance_to(hive_global) <= SEARCH_RADIUS:
				_flower_targets.append(fpos)

	# Also check for flower lifecycle manager tiles (mature flowers on tilemap)
	var flm: Node = tree.get_first_node_in_group("flower_lifecycle_manager")
	if flm != null and flm.has_method("get_blooming_types"):
		# Query each blooming type's mature tile positions
		if flm.get("flower_grid") is Dictionary:
			var grid: Dictionary = flm.flower_grid
			for type_name in grid:
				var tiles: Dictionary = grid[type_name]
				for tile_pos in tiles:
					var tile_data: Dictionary = tiles[tile_pos]
					# Phase 3 = MATURE (producing nectar)
					if tile_data.get("phase", 0) == 3:
						# Convert tile to world position
						# FlowerLifecycleManager uses 16px tiles with grass_origin
						var world_pos := Vector2(
							float(tile_pos.x) * 16.0,
							float(tile_pos.y) * 16.0
						)
						if "grass_origin" in flm:
							world_pos += flm.grass_origin
						if world_pos.distance_to(hive_global) <= SEARCH_RADIUS:
							_flower_targets.append(world_pos)

	# If no real flowers found, generate some fake nearby positions so the
	# visual still works -- player sees bees flying around even if flowers
	# are outside the search radius or managed differently.
	if _flower_targets.is_empty():
		for i in 6:
			var angle: float = randf() * TAU
			var dist: float = randf_range(60.0, SEARCH_RADIUS * 0.7)
			_flower_targets.append(hive_global + Vector2(cos(angle), sin(angle)) * dist)

func _sync_forager_pool() -> void:
	# Add foragers if we need more
	while _foragers.size() < _desired_forager_count:
		_spawn_forager()

	# Remove excess foragers
	while _foragers.size() > _desired_forager_count:
		var f: Dictionary = _foragers.pop_back()
		if is_instance_valid(f["sprite"]):
			f["sprite"].queue_free()

func _spawn_forager() -> void:
	var spr := Sprite2D.new()
	spr.texture = _bee_tex
	spr.z_index = 5
	# Start at the hive entrance
	spr.position = _hive_entrance_local
	spr.scale = Vector2(0.6, 0.6)
	add_child(spr)

	var forager := {
		"sprite": spr,
		"state": FState.RESTING,
		"target": Vector2.ZERO,
		"timer": randf_range(0.0, REST_TIME_MAX),  # stagger start
		"speed": FORAGER_SPEED + randf_range(-FORAGER_SPEED_JITTER, FORAGER_SPEED_JITTER),
		"wobble_phase": randf() * TAU,
	}
	_foragers.append(forager)

func _tick_foragers(delta: float) -> void:
	for f in _foragers:
		if not is_instance_valid(f["sprite"]):
			continue
		var spr: Sprite2D = f["sprite"]

		match f["state"]:
			FState.RESTING:
				f["timer"] -= delta
				if f["timer"] <= 0.0:
					# Pick a flower and head out
					f["target"] = _pick_flower_target()
					f["state"] = FState.TO_FLOWER

			FState.TO_FLOWER:
				var local_target: Vector2 = f["target"] - global_position
				var dir: Vector2 = (local_target - spr.position)
				var dist: float = dir.length()
				if dist < 3.0:
					# Arrived at flower
					spr.position = local_target
					f["state"] = FState.GATHERING
					f["timer"] = randf_range(GATHER_TIME_MIN, GATHER_TIME_MAX)
				else:
					var move: float = f["speed"] * delta
					spr.position += dir.normalized() * move
					# Wobble perpendicular to flight direction
					f["wobble_phase"] += delta * 8.0
					var perp := Vector2(-dir.y, dir.x).normalized()
					spr.position += perp * sin(f["wobble_phase"]) * FORAGER_WOBBLE * delta * 10.0

			FState.GATHERING:
				f["timer"] -= delta
				# Tiny idle wobble while gathering
				f["wobble_phase"] += delta * 3.0
				spr.position.x += sin(f["wobble_phase"]) * 0.15 * delta * 10.0
				if f["timer"] <= 0.0:
					# Head back to hive
					f["target"] = global_position + _hive_entrance_local
					f["state"] = FState.TO_HIVE

			FState.TO_HIVE:
				var local_target: Vector2 = _hive_entrance_local
				var dir: Vector2 = (local_target - spr.position)
				var dist: float = dir.length()
				if dist < 3.0:
					spr.position = local_target
					f["state"] = FState.RESTING
					f["timer"] = randf_range(REST_TIME_MIN, REST_TIME_MAX)
				else:
					var move: float = f["speed"] * delta
					spr.position += dir.normalized() * move
					f["wobble_phase"] += delta * 8.0
					var perp := Vector2(-dir.y, dir.x).normalized()
					spr.position += perp * sin(f["wobble_phase"]) * FORAGER_WOBBLE * delta * 10.0

func _pick_flower_target() -> Vector2:
	if _flower_targets.is_empty():
		# Fallback: random direction
		var angle: float = randf() * TAU
		return global_position + Vector2(cos(angle), sin(angle)) * randf_range(60.0, 150.0)
	return _flower_targets[randi() % _flower_targets.size()]

# =============================================================================
#  GPU PARTICLE EMITTER SETUP
# =============================================================================

func _setup_entrance_emitter() -> void:
	_entrance = GPUParticles2D.new()
	_entrance.name = "EntranceSwarm"
	_entrance.amount = ENTRANCE_MIN_AMOUNT
	_entrance.lifetime = 2.5
	_entrance.randomness = 0.6
	_entrance.fixed_fps = 30
	_entrance.z_index = 3
	_entrance.visibility_rect = Rect2(-40, -30, 80, 60)

	_entrance_mat = ParticleProcessMaterial.new()
	_entrance_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_entrance_mat.emission_box_extents = Vector3(10.0, 3.0, 0.0)
	_entrance_mat.direction = Vector3(1.0, -0.3, 0.0)
	_entrance_mat.spread = 65.0
	_entrance_mat.initial_velocity_min = SPEED_CALM_MIN
	_entrance_mat.initial_velocity_max = SPEED_CALM_MAX
	_entrance_mat.gravity = Vector3(0.0, 4.0, 0.0)
	_entrance_mat.turbulence_enabled = true
	_entrance_mat.turbulence_noise_strength = 2.5
	_entrance_mat.turbulence_noise_speed_random = 0.3
	_entrance_mat.turbulence_noise_speed = Vector3(0.4, 0.4, 0.0)
	_entrance_mat.scale_min = 0.6
	_entrance_mat.scale_max = 0.6
	_entrance_mat.color = COLOR_HEALTHY

	_entrance.process_material = _entrance_mat
	if _bee_tex:
		_entrance.texture = _bee_tex
	add_child(_entrance)

func _setup_overhead_emitter() -> void:
	_overhead = GPUParticles2D.new()
	_overhead.name = "OverheadCloud"
	_overhead.amount = OVERHEAD_MIN_AMOUNT
	_overhead.lifetime = 3.5
	_overhead.randomness = 0.7
	_overhead.fixed_fps = 30
	_overhead.z_index = 4
	_overhead.visibility_rect = Rect2(-50, -40, 100, 80)

	_overhead_mat = ParticleProcessMaterial.new()
	_overhead_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_overhead_mat.emission_box_extents = Vector3(10.0, 6.0, 0.0)
	_overhead_mat.direction = Vector3(0.0, -1.0, 0.0)
	_overhead_mat.spread = 80.0
	_overhead_mat.initial_velocity_min = SPEED_CALM_MIN * 0.7
	_overhead_mat.initial_velocity_max = SPEED_CALM_MAX * 0.7
	_overhead_mat.gravity = Vector3(0.0, 3.0, 0.0)
	_overhead_mat.turbulence_enabled = true
	_overhead_mat.turbulence_noise_strength = 4.0
	_overhead_mat.turbulence_noise_speed_random = 0.4
	_overhead_mat.turbulence_noise_speed = Vector3(0.5, 0.5, 0.0)
	_overhead_mat.scale_min = 0.6
	_overhead_mat.scale_max = 0.6
	_overhead_mat.color = COLOR_HEALTHY

	_overhead.process_material = _overhead_mat
	if _bee_tex:
		_overhead.texture = _bee_tex
	add_child(_overhead)

# =============================================================================
#  GPU PARTICLE MATERIAL UPDATES
# =============================================================================

func _apply_to_materials() -> void:
	if _entrance_mat == null or _overhead_mat == null:
		return

	# Cubic curve: new/weak hive = almost nothing, booming = full swarm
	# activity 0.25 -> 0.016, 0.5 -> 0.125, 0.75 -> 0.42, 1.0 -> 1.0
	var curve: float = _activity * _activity * _activity
	var entrance_amount: int = int(lerp(
		float(ENTRANCE_MIN_AMOUNT), float(ENTRANCE_MAX_AMOUNT), curve
	))
	var overhead_amount: int = int(lerp(
		float(OVERHEAD_MIN_AMOUNT), float(OVERHEAD_MAX_AMOUNT), curve
	))
	if _agitation > 0.5:
		var boost: float = (_agitation - 0.5) * 2.0
		entrance_amount = int(float(entrance_amount) * (1.0 + boost * 0.6))
		overhead_amount = int(float(overhead_amount) * (1.0 + boost * 0.8))

	_entrance.amount = clampi(entrance_amount, ENTRANCE_MIN_AMOUNT, 80)
	_overhead.amount = clampi(overhead_amount, OVERHEAD_MIN_AMOUNT, 50)

	var speed_min: float = lerp(SPEED_CALM_MIN, SPEED_AGITATED_MIN, _agitation)
	var speed_max: float = lerp(SPEED_CALM_MAX, SPEED_AGITATED_MAX, _agitation)
	_entrance_mat.initial_velocity_min = speed_min
	_entrance_mat.initial_velocity_max = speed_max
	_overhead_mat.initial_velocity_min = speed_min * 0.7
	_overhead_mat.initial_velocity_max = speed_max * 0.7

	# Spread also uses the squared curve -- weak hive = tight cluster
	_entrance_mat.emission_box_extents = ENTRANCE_SPREAD_MIN.lerp(ENTRANCE_SPREAD_MAX, curve)
	_overhead_mat.emission_box_extents = OVERHEAD_SPREAD_MIN.lerp(OVERHEAD_SPREAD_MAX, curve)

	var turb_strength: float = lerp(1.5, 6.0, _agitation)
	_entrance_mat.turbulence_noise_strength = turb_strength
	_overhead_mat.turbulence_noise_strength = turb_strength * 1.3

	var tint: Color = COLOR_HEALTHY.lerp(COLOR_STRESSED, _agitation * 0.7)
	_entrance_mat.color = tint
	_overhead_mat.color = tint

	_entrance.lifetime = lerp(3.0, 1.8, _agitation)
	_overhead.lifetime = lerp(4.0, 2.5, _agitation)
