# BeeOverlay.gd
# -----------------------------------------------------------------------------
# Queen Finder Phase 2 -- Animated bee overlay for the InspectionOverlay.
#
# Manages a pool of BeeEntity objects (lightweight dictionaries) representing
# worker bees, queen, and attendant bees walking on a honeycomb frame.
# Renders them as sprites composited onto an RGBA canvas via Image.blend_rect().
#
# The player finds the queen by clicking her among the workers.
# No pathfinding -- bees use direct linear movement with soft repulsion.
#
# USAGE (from InspectionOverlay.gd):
#   var overlay := BeeOverlay.new()
#   overlay.init_session(sim, difficulty_rank, queen_spawned)
#   overlay.populate_frame(frame_idx, box)
#   # In _process():
#   overlay.update(delta)
#   _bee_texture_rect.texture = overlay.get_texture()
#   # On click:
#   var result := overlay.hit_test(canvas_pos)
# -----------------------------------------------------------------------------
extends RefCounted
class_name BeeOverlay

# -- Difficulty Enum ----------------------------------------------------------
enum DiffRank { EASY = 0, MEDIUM = 1, HARD = 2 }

# -- Bee State Enum -----------------------------------------------------------
enum BeeState { WALKING = 0, IDLE = 1, TURNING = 2 }

# -- Density Model Constants (GDD S8.4) --------------------------------------
const NURSE_TO_VISIBLE_RATIO := 100
const DIFFICULTY_MULT: Array = [0.33, 0.67, 1.0]  # Easy, Medium, Hard
const JITTER_MIN := -3
const JITTER_MAX := 3
const MIN_VISIBLE := 8
const MAX_VISIBLE := 120

# -- Spacing Constants (GDD S8.7) per difficulty rank -------------------------
const MIN_BEE_DIST: Array = [28.0, 17.0, 12.0]     # Easy, Medium, Hard
const CLUSTER_SPREAD: Array = [0.28, 0.20, 0.16]    # Gaussian std dev fraction

# -- Queen Spawn (GDD S2.2) --------------------------------------------------
const QUEEN_SPAWN_CHANCE := 0.80

# -- Movement Constants (GDD S8.6) -------------------------------------------
const WORKER_SPEED_MIN := 28.0
const WORKER_SPEED_MAX := 36.0
const QUEEN_SPEED_MIN  := 14.0
const QUEEN_SPEED_MAX  := 18.0
const WALK_FRAME_INTERVAL := 0.125   # 8 fps walk
const QUEEN_WALK_INTERVAL := 0.200   # 5 fps queen walk
const IDLE_FRAME_INTERVAL := 0.300   # ~3 fps idle
const WORKER_IDLE_MIN := 0.4
const WORKER_IDLE_MAX := 1.8
const QUEEN_IDLE_MIN  := 1.5
const QUEEN_IDLE_MAX  := 4.0
const TURN_DURATION   := 0.15

# -- Attendant Constants (GDD S8.5) ------------------------------------------
const ATTENDANT_RADIUS := 18.0   # px orbit distance from queen
const ATTENDANT_DRIFT  := 0.08   # rad/sec angular drift
const ATTENDANT_FOLLOW := 3.0    # lerp weight for following queen
const ATTENDANT_DIFF_MULT: Array = [1.5, 1.0, 0.5]  # Easy, Medium, Hard

# -- Attendant count by queen grade ------------------------------------------
const ATTENDANT_BY_GRADE: Dictionary = {
	"S": 11, "A+": 10, "A": 9, "B": 7, "C": 5, "D": 3, "F": 0
}

# -- Temperament Density Modifiers (GDD S8.6) --------------------------------
const TEMP_DENSITY_CALM      := 1.0
const TEMP_DENSITY_NORMAL    := 1.15
const TEMP_DENSITY_DEFENSIVE := 1.4

# -- Sprite Constants ---------------------------------------------------------
const BEE_CELL_W := 60    # spritesheet cell width
const BEE_CELL_H := 42    # spritesheet cell height
const BEE_DIRS   := 8     # E, NE, N, NW, W, SW, S, SE
const BEE_WALK_FRAMES := 4
const BEE_IDLE_FRAMES := 3
const BEE_TOTAL_FRAMES := 7  # 4 walk + 3 idle

# -- Canvas size (matches FrameRenderer honeycomb) ----------------------------
const CANVAS_W := 1833
const CANVAS_H := 755

# -- Click hit radius (GDD S10.1) --------------------------------------------
const HIT_RADIUS := 18.0

# -- Spatial Hash for soft repulsion ------------------------------------------
const HASH_CELL_SIZE := 20

# -- XP Rewards by difficulty (GDD S10.2) ------------------------------------
const XP_BY_RANK: Array = [10, 15, 25]   # Easy, Medium, Hard

# -- Breed spritesheet paths --------------------------------------------------
const BREED_NAMES: Array = ["italian", "buckfast", "carniolan", "caucasian", "russian"]
const SPRITE_BASE := "res://assets/sprites/bees/"

# =============================================================================
# SESSION STATE (set once per inspection)
# =============================================================================
var _difficulty_rank: int = DiffRank.MEDIUM
var _queen_spawned: bool = false
var _temperament_density_mult: float = 1.0
var _queen_grade: String = "B"
var _queen_species: String = "Italian"
var _queen_age_days: int = 0
var _queen_frame_idx: int = 4
var _nurse_count: int = 0

# =============================================================================
# FRAME STATE (recalculated per frame flip)
# =============================================================================
var _bees: Array = []          # Array of dictionaries (BeeEntity)
var _queen_entity: Dictionary = {}
var _has_queen_on_frame: bool = false
var _queen_found: bool = false

# =============================================================================
# RENDERING STATE
# =============================================================================
var _canvas: Image = null
var _texture: ImageTexture = null
var _breed_sheets: Dictionary = {}   # "breed_role" -> Image
var _sheets_loaded: bool = false

# RNG for deterministic session
var _rng: RandomNumberGenerator = null

# =============================================================================
# PUBLIC API
# =============================================================================

## Call once per inspection session after rolling difficulty and queen visibility.
func init_session(sim: HiveSimulation, difficulty_rank: int, queen_spawned: bool) -> void:
	_difficulty_rank = clampi(difficulty_rank, 0, 2)
	_queen_spawned = queen_spawned
	_queen_found = false

	# Extract queen data from simulation
	_queen_grade = sim.queen.get("grade", "B")
	_queen_species = sim.queen.get("species", "Italian")
	_queen_age_days = sim.queen.get("age_days", 0)
	_nurse_count = sim.nurse_count

	# Temperament -> density modifier
	var temp: float = sim.queen.get("temperament", 1.0)
	if temp >= 0.9:
		_temperament_density_mult = TEMP_DENSITY_CALM
	elif temp >= 0.7:
		_temperament_density_mult = TEMP_DENSITY_NORMAL
	else:
		_temperament_density_mult = TEMP_DENSITY_DEFENSIVE

	# Find which frame the queen is on
	_queen_frame_idx = _find_queen_frame(sim)

	# RNG for this session
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	_ensure_sprites_loaded()
	_ensure_canvas()

## Populate bee entities for a specific frame. Call when player navigates frames.
func populate_frame(frame_idx: int, box: Variant) -> void:
	_bees.clear()
	_has_queen_on_frame = false

	if box == null:
		return

	# Calculate visible bee count using the 8-step density pipeline
	var frame_share: float = box.get_frame_brood_share(frame_idx)
	var base_visible: int = int(roundf(float(_nurse_count) * frame_share / float(NURSE_TO_VISIBLE_RATIO)))
	base_visible = int(roundf(float(base_visible) * DIFFICULTY_MULT[_difficulty_rank]))
	base_visible = int(roundf(float(base_visible) * _temperament_density_mult))
	var jitter: int = _rng.randi_range(JITTER_MIN, JITTER_MAX)
	var visible: int = base_visible + jitter

	# Special case: dead hive (0 nurses) stays at 0
	if _nurse_count > 0:
		visible = clampi(visible, MIN_VISIBLE, MAX_VISIBLE)
	else:
		visible = clampi(visible, 0, 3)

	# Get cluster spread and min dist for this difficulty
	var spread: float = CLUSTER_SPREAD[_difficulty_rank]
	var min_dist: float = MIN_BEE_DIST[_difficulty_rank]

	# Determine breed for sprites
	var breed_key: String = _queen_species.to_lower()
	if breed_key not in BREED_NAMES:
		breed_key = "italian"

	# Spawn worker bees
	for _i in visible:
		var bee: Dictionary = _create_worker(breed_key, spread)
		_bees.append(bee)

	# Spawn queen + attendants on the correct frame
	if _queen_spawned and frame_idx == _queen_frame_idx and not _queen_found:
		_has_queen_on_frame = true
		var queen_bee: Dictionary = _create_queen(breed_key, spread)
		_queen_entity = queen_bee
		_bees.append(queen_bee)

		# Spawn attendants
		var base_attendants: int = ATTENDANT_BY_GRADE.get(_queen_grade, 7)
		var att_mult: float = ATTENDANT_DIFF_MULT[_difficulty_rank]
		var num_attendants: int = int(roundf(float(base_attendants) * att_mult))
		num_attendants = clampi(num_attendants, 0, 12)

		for ai in num_attendants:
			var att: Dictionary = _create_attendant(breed_key, queen_bee, ai, num_attendants)
			_bees.append(att)

	# Apply initial spacing -- nudge bees apart to respect min_dist
	for _pass in 5:
		_apply_soft_repulsion(0.016, min_dist)

## Update all bee entities (movement, animation). Call from _process(delta).
func update(delta: float) -> void:
	var min_dist: float = MIN_BEE_DIST[_difficulty_rank]
	var spread: float = CLUSTER_SPREAD[_difficulty_rank]

	for bee in _bees:
		if bee.get("is_attendant", false):
			_update_attendant(bee, delta)
		else:
			_update_bee(bee, delta, spread)

	# Soft repulsion pass
	_apply_soft_repulsion(delta, min_dist)

## Render all bees to the overlay canvas and return the texture.
func get_texture() -> ImageTexture:
	if _canvas == null:
		_ensure_canvas()

	# Clear canvas to transparent
	_canvas.fill(Color(0, 0, 0, 0))

	# Y-sort bees for depth ordering
	_bees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["pos_y"] < b["pos_y"]
	)

	# Composite each bee sprite
	for bee in _bees:
		_draw_bee(bee)

	# Draw queen highlight if found
	if _queen_found and _has_queen_on_frame:
		_draw_queen_highlight()

	_texture.update(_canvas)
	return _texture

## Hit test a click position (in honeycomb canvas coordinates).
## Returns: { "hit": true/false, "is_queen": true/false, "bee": dict or null, "xp": int }
func hit_test(canvas_pos: Vector2) -> Dictionary:
	# Test in reverse Y-order (topmost drawn bees first)
	var sorted_bees: Array = _bees.duplicate()
	sorted_bees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["pos_y"] > b["pos_y"]
	)

	for bee in sorted_bees:
		var dx: float = canvas_pos.x - bee["pos_x"]
		var dy: float = canvas_pos.y - bee["pos_y"]
		if dx * dx + dy * dy < HIT_RADIUS * HIT_RADIUS:
			if bee.get("is_queen", false):
				_queen_found = true
				return {
					"hit": true,
					"is_queen": true,
					"bee": bee,
					"xp": XP_BY_RANK[_difficulty_rank]
				}
			else:
				# Wrong bee -- mark for flash feedback
				bee["flash_timer"] = 0.2
				return {
					"hit": true,
					"is_queen": false,
					"bee": bee,
					"xp": 0
				}

	return { "hit": false, "is_queen": false, "bee": null, "xp": 0 }

## Returns true if the queen has been found this inspection.
func is_queen_found() -> bool:
	return _queen_found

## Returns true if the queen entity is on the current frame.
func has_queen_on_current_frame() -> bool:
	return _has_queen_on_frame

## Returns true if queen was spawned at all this inspection.
func is_queen_spawned() -> bool:
	return _queen_spawned

## Returns the difficulty rank for this session.
func get_difficulty_rank() -> int:
	return _difficulty_rank

# =============================================================================
# BEE ENTITY CREATION
# =============================================================================

func _create_worker(breed_key: String, spread: float) -> Dictionary:
	var pos: Vector2 = _gaussian_position(spread)
	var speed: float = _rng.randf_range(WORKER_SPEED_MIN, WORKER_SPEED_MAX)
	var target: Vector2 = _gaussian_position(spread)

	return {
		"pos_x": pos.x,
		"pos_y": pos.y,
		"target_x": target.x,
		"target_y": target.y,
		"direction": _rng.randi_range(0, 7),
		"anim_frame": _rng.randi_range(0, 3),
		"anim_timer": _rng.randf_range(0.0, WALK_FRAME_INTERVAL),
		"state": BeeState.WALKING,
		"idle_remaining": 0.0,
		"speed": speed,
		"is_queen": false,
		"is_attendant": false,
		"breed_key": breed_key,
		"flash_timer": 0.0,
	}

func _create_queen(breed_key: String, spread: float) -> Dictionary:
	# Queen spawns in the brood zone center area
	var center_x: float = float(CANVAS_W) * 0.5
	var center_y: float = float(CANVAS_H) * 0.4
	var jx: float = _rng.randf_range(-60.0, 60.0)
	var jy: float = _rng.randf_range(-40.0, 40.0)
	var pos_x: float = clampf(center_x + jx, 60.0, float(CANVAS_W) - 60.0)
	var pos_y: float = clampf(center_y + jy, 40.0, float(CANVAS_H) - 40.0)

	# Age-based speed modifier: older queens move slower
	var age_mod: float = maxf(0.6, 1.0 - float(_queen_age_days) / 1500.0)
	var speed: float = _rng.randf_range(QUEEN_SPEED_MIN, QUEEN_SPEED_MAX) * age_mod

	return {
		"pos_x": pos_x,
		"pos_y": pos_y,
		"target_x": pos_x + _rng.randf_range(-20.0, 20.0),
		"target_y": pos_y + _rng.randf_range(-15.0, 15.0),
		"direction": _rng.randi_range(0, 7),
		"anim_frame": 0,
		"anim_timer": 0.0,
		"state": BeeState.IDLE,
		"idle_remaining": _rng.randf_range(QUEEN_IDLE_MIN, QUEEN_IDLE_MAX),
		"speed": speed,
		"is_queen": true,
		"is_attendant": false,
		"breed_key": breed_key,
		"flash_timer": 0.0,
	}

func _create_attendant(breed_key: String, queen: Dictionary, idx: int, total: int) -> Dictionary:
	var angle: float = float(idx) / maxf(float(total), 1.0) * TAU
	var ax: float = queen["pos_x"] + cos(angle) * ATTENDANT_RADIUS
	var ay: float = queen["pos_y"] + sin(angle) * ATTENDANT_RADIUS

	return {
		"pos_x": ax,
		"pos_y": ay,
		"target_x": ax,
		"target_y": ay,
		"direction": _angle_to_dir(atan2(queen["pos_y"] - ay, queen["pos_x"] - ax)),
		"anim_frame": 4,  # idle facing queen
		"anim_timer": _rng.randf_range(0.0, IDLE_FRAME_INTERVAL),
		"state": BeeState.IDLE,
		"idle_remaining": 999.0,
		"speed": 0.0,
		"is_queen": false,
		"is_attendant": true,
		"breed_key": breed_key,
		"flash_timer": 0.0,
		"slot_angle": angle,
	}

# =============================================================================
# BEE MOVEMENT UPDATE
# =============================================================================

func _update_bee(bee: Dictionary, delta: float, spread: float) -> void:
	# Update flash timer
	if bee["flash_timer"] > 0.0:
		bee["flash_timer"] = maxf(0.0, bee["flash_timer"] - delta)

	var s: int = bee["state"]

	if s == BeeState.WALKING:
		_update_walking(bee, delta, spread)
	elif s == BeeState.IDLE:
		_update_idle(bee, delta, spread)
	elif s == BeeState.TURNING:
		bee["idle_remaining"] -= delta
		if bee["idle_remaining"] <= 0.0:
			bee["state"] = BeeState.WALKING

	# Advance animation
	_advance_animation(bee, delta)

func _update_walking(bee: Dictionary, delta: float, spread: float) -> void:
	var dx: float = bee["target_x"] - bee["pos_x"]
	var dy: float = bee["target_y"] - bee["pos_y"]
	var dist: float = sqrt(dx * dx + dy * dy)

	if dist < 2.0:
		# Arrived at target
		if bee.get("is_queen", false):
			# Queen pauses longer
			bee["state"] = BeeState.IDLE
			bee["idle_remaining"] = _rng.randf_range(QUEEN_IDLE_MIN, QUEEN_IDLE_MAX)
			bee["anim_frame"] = 4
		else:
			# Workers: 70% idle, 30% new target immediately
			if _rng.randf() < 0.7:
				bee["state"] = BeeState.IDLE
				bee["idle_remaining"] = _rng.randf_range(WORKER_IDLE_MIN, WORKER_IDLE_MAX)
				bee["anim_frame"] = 4
			else:
				_pick_new_target(bee, spread)
		return

	# Move toward target
	var nx: float = dx / dist
	var ny: float = dy / dist
	var step: float = bee["speed"] * delta
	bee["pos_x"] += nx * minf(step, dist)
	bee["pos_y"] += ny * minf(step, dist)

	# Update direction (8-way quantized)
	bee["direction"] = _angle_to_dir(atan2(dy, dx))

func _update_idle(bee: Dictionary, delta: float, spread: float) -> void:
	bee["idle_remaining"] -= delta
	if bee["idle_remaining"] <= 0.0:
		_pick_new_target(bee, spread)
		# Brief turning pause before walking
		bee["state"] = BeeState.TURNING
		bee["idle_remaining"] = _rng.randf_range(0.1, 0.2)

func _update_attendant(bee: Dictionary, delta: float) -> void:
	if _queen_entity.is_empty():
		return

	# Update flash timer
	if bee["flash_timer"] > 0.0:
		bee["flash_timer"] = maxf(0.0, bee["flash_timer"] - delta)

	# Orbit slowly around queen
	bee["slot_angle"] = bee.get("slot_angle", 0.0) + ATTENDANT_DRIFT * delta
	var ideal_x: float = _queen_entity["pos_x"] + cos(bee["slot_angle"]) * ATTENDANT_RADIUS
	var ideal_y: float = _queen_entity["pos_y"] + sin(bee["slot_angle"]) * ATTENDANT_RADIUS

	# Smoothly follow
	bee["pos_x"] = lerpf(bee["pos_x"], ideal_x, ATTENDANT_FOLLOW * delta)
	bee["pos_y"] = lerpf(bee["pos_y"], ideal_y, ATTENDANT_FOLLOW * delta)

	# Face toward queen
	var qdx: float = _queen_entity["pos_x"] - bee["pos_x"]
	var qdy: float = _queen_entity["pos_y"] - bee["pos_y"]
	bee["direction"] = _angle_to_dir(atan2(qdy, qdx))

	# Idle animation
	_advance_animation(bee, delta)

# =============================================================================
# TARGET SELECTION
# =============================================================================

func _pick_new_target(bee: Dictionary, spread: float) -> void:
	var roll: float = _rng.randf()

	if bee.get("is_queen", false):
		# Queen: 60% continue forward, 25% adjacent, 15% slight turn
		if roll < 0.60:
			# Continue roughly same direction (1-2 cells forward)
			var dir_vec: Vector2 = _dir_to_vector(bee["direction"])
			var steps: float = _rng.randf_range(15.0, 40.0)
			bee["target_x"] = clampf(bee["pos_x"] + dir_vec.x * steps, 60.0, float(CANVAS_W) - 60.0)
			bee["target_y"] = clampf(bee["pos_y"] + dir_vec.y * steps, 40.0, float(CANVAS_H) - 40.0)
		elif roll < 0.85:
			# Adjacent cell
			var offset_x: float = _rng.randf_range(-26.0, 26.0)
			var offset_y: float = _rng.randf_range(-15.0, 15.0)
			bee["target_x"] = clampf(bee["pos_x"] + offset_x, 60.0, float(CANVAS_W) - 60.0)
			bee["target_y"] = clampf(bee["pos_y"] + offset_y, 40.0, float(CANVAS_H) - 40.0)
		else:
			# Slight turn
			var new_dir: int = (bee["direction"] + _rng.randi_range(-2, 2) + 8) % 8
			bee["direction"] = new_dir
			var dir_vec: Vector2 = _dir_to_vector(new_dir)
			bee["target_x"] = clampf(bee["pos_x"] + dir_vec.x * 20.0, 60.0, float(CANVAS_W) - 60.0)
			bee["target_y"] = clampf(bee["pos_y"] + dir_vec.y * 20.0, 40.0, float(CANVAS_H) - 40.0)
	else:
		# Worker: 60% nearby, 30% center-biased, 10% random
		if roll < 0.60:
			# Nearby (1-3 cells)
			var offset_x: float = _rng.randf_range(-78.0, 78.0)
			var offset_y: float = _rng.randf_range(-45.0, 45.0)
			bee["target_x"] = clampf(bee["pos_x"] + offset_x, 10.0, float(CANVAS_W) - 10.0)
			bee["target_y"] = clampf(bee["pos_y"] + offset_y, 10.0, float(CANVAS_H) - 10.0)
		elif roll < 0.90:
			# Center-biased
			var center_x: float = float(CANVAS_W) * 0.5
			var center_y: float = float(CANVAS_H) * 0.45
			var t: float = _rng.randf_range(0.2, 0.5)
			bee["target_x"] = lerpf(bee["pos_x"], center_x, t) + _rng.randf_range(-26.0, 26.0)
			bee["target_y"] = lerpf(bee["pos_y"], center_y, t) + _rng.randf_range(-15.0, 15.0)
			bee["target_x"] = clampf(bee["target_x"], 10.0, float(CANVAS_W) - 10.0)
			bee["target_y"] = clampf(bee["target_y"], 10.0, float(CANVAS_H) - 10.0)
		else:
			# Random position on frame
			bee["target_x"] = _rng.randf_range(40.0, float(CANVAS_W) - 40.0)
			bee["target_y"] = _rng.randf_range(30.0, float(CANVAS_H) - 30.0)

# =============================================================================
# ANIMATION
# =============================================================================

func _advance_animation(bee: Dictionary, delta: float) -> void:
	var interval: float
	if bee["state"] == BeeState.WALKING:
		interval = QUEEN_WALK_INTERVAL if bee.get("is_queen", false) else WALK_FRAME_INTERVAL
	else:
		interval = IDLE_FRAME_INTERVAL

	bee["anim_timer"] -= delta
	if bee["anim_timer"] <= 0.0:
		bee["anim_timer"] += interval
		if bee["state"] == BeeState.WALKING:
			bee["anim_frame"] = (bee["anim_frame"] + 1) % BEE_WALK_FRAMES
		else:
			# Idle loop: frames 4-6
			var idle_idx: int = bee["anim_frame"] - 4
			if idle_idx < 0:
				idle_idx = 0
			idle_idx = (idle_idx + 1) % BEE_IDLE_FRAMES
			bee["anim_frame"] = 4 + idle_idx

# =============================================================================
# SOFT REPULSION (Spatial Hash)
# =============================================================================

func _apply_soft_repulsion(delta: float, min_dist: float) -> void:
	if _bees.size() < 2:
		return

	# Build spatial hash
	var grid: Dictionary = {}
	for i in _bees.size():
		var bx: int = int(_bees[i]["pos_x"]) / HASH_CELL_SIZE
		var by: int = int(_bees[i]["pos_y"]) / HASH_CELL_SIZE
		var key: int = bx * 10000 + by
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)

	# Check neighbors
	var push_scale: float = 0.3 * delta * 60.0
	for key in grid:
		var cell_indices: Array = grid[key]
		# Check same cell
		for i in cell_indices.size():
			for j in range(i + 1, cell_indices.size()):
				_repulse_pair(_bees[cell_indices[i]], _bees[cell_indices[j]], min_dist, push_scale)
		# Check adjacent cells
		var bx: int = key / 10000
		var by: int = key % 10000
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0:
					continue
				var neighbor_key: int = (bx + ox) * 10000 + (by + oy)
				if grid.has(neighbor_key):
					for i in cell_indices:
						for j in grid[neighbor_key]:
							_repulse_pair(_bees[i], _bees[j], min_dist, push_scale)

func _repulse_pair(a: Dictionary, b: Dictionary, min_dist: float, push_scale: float) -> void:
	var dx: float = a["pos_x"] - b["pos_x"]
	var dy: float = a["pos_y"] - b["pos_y"]
	var dist_sq: float = dx * dx + dy * dy
	if dist_sq >= min_dist * min_dist or dist_sq < 0.01:
		return
	var dist: float = sqrt(dist_sq)
	var overlap: float = min_dist - dist
	var px: float = dx / dist * overlap * push_scale
	var py: float = dy / dist * overlap * push_scale
	a["pos_x"] = clampf(a["pos_x"] + px, 5.0, float(CANVAS_W) - 5.0)
	a["pos_y"] = clampf(a["pos_y"] + py, 5.0, float(CANVAS_H) - 5.0)
	b["pos_x"] = clampf(b["pos_x"] - px, 5.0, float(CANVAS_W) - 5.0)
	b["pos_y"] = clampf(b["pos_y"] - py, 5.0, float(CANVAS_H) - 5.0)

# =============================================================================
# RENDERING
# =============================================================================

func _draw_bee(bee: Dictionary) -> void:
	var breed_key: String = bee.get("breed_key", "italian")
	var role_key: String = "queen" if bee.get("is_queen", false) else "worker"
	var sheet_key: String = breed_key + "_" + role_key

	var sheet: Image = _breed_sheets.get(sheet_key)
	if sheet == null:
		return

	# Source rect from spritesheet: col = anim_frame, row = direction
	var src_x: int = bee["anim_frame"] * BEE_CELL_W
	var src_y: int = bee["direction"] * BEE_CELL_H

	# Clamp source rect to sheet dimensions
	if src_x + BEE_CELL_W > sheet.get_width() or src_y + BEE_CELL_H > sheet.get_height():
		return

	var src_rect := Rect2i(src_x, src_y, BEE_CELL_W, BEE_CELL_H)

	# Destination centered on bee position
	var dst_x: int = int(bee["pos_x"]) - BEE_CELL_W / 2
	var dst_y: int = int(bee["pos_y"]) - BEE_CELL_H / 2

	# Clamp to canvas bounds
	if dst_x < -BEE_CELL_W or dst_x >= CANVAS_W or dst_y < -BEE_CELL_H or dst_y >= CANVAS_H:
		return

	_canvas.blend_rect(sheet, src_rect, Vector2i(dst_x, dst_y))

	# Flash red overlay if wrong-bee click feedback active
	if bee.get("flash_timer", 0.0) > 0.0:
		_draw_flash(bee)

func _draw_flash(bee: Dictionary) -> void:
	# Draw a small red circle at bee position for wrong-click feedback
	var cx: int = int(bee["pos_x"])
	var cy: int = int(bee["pos_y"])
	var r: int = 8
	for py in range(maxi(0, cy - r), mini(CANVAS_H, cy + r)):
		for px in range(maxi(0, cx - r), mini(CANVAS_W, cx + r)):
			var ddx: int = px - cx
			var ddy: int = py - cy
			if ddx * ddx + ddy * ddy < r * r:
				var existing: Color = _canvas.get_pixel(px, py)
				var blended: Color = existing.blend(Color(0.9, 0.2, 0.15, 0.4))
				_canvas.set_pixel(px, py, blended)

func _draw_queen_highlight() -> void:
	if _queen_entity.is_empty():
		return
	# Draw gold circle around found queen
	var cx: int = int(_queen_entity["pos_x"])
	var cy: int = int(_queen_entity["pos_y"])
	var r: int = 22
	var r_inner: int = 19
	for py in range(maxi(0, cy - r - 1), mini(CANVAS_H, cy + r + 1)):
		for px in range(maxi(0, cx - r - 1), mini(CANVAS_W, cx + r + 1)):
			var ddx: int = px - cx
			var ddy: int = py - cy
			var dist_sq: int = ddx * ddx + ddy * ddy
			if dist_sq < r * r and dist_sq >= r_inner * r_inner:
				var existing: Color = _canvas.get_pixel(px, py)
				var blended: Color = existing.blend(Color(0.95, 0.78, 0.32, 0.7))
				_canvas.set_pixel(px, py, blended)

# =============================================================================
# SPRITE LOADING
# =============================================================================

func _ensure_sprites_loaded() -> void:
	if _sheets_loaded:
		return
	_sheets_loaded = true

	for breed in BREED_NAMES:
		for role in ["worker", "queen"]:
			var key: String = breed + "_" + role
			var path: String = SPRITE_BASE + key + "_spritesheet.png"
			var abs_path: String = ProjectSettings.globalize_path(path)
			var img := Image.new()
			var err: int = img.load(abs_path)
			if err != OK:
				push_warning("BeeOverlay: could not load %s (error %d)" % [abs_path, err])
				# Create fallback colored rect
				img = Image.create(BEE_CELL_W * BEE_TOTAL_FRAMES, BEE_CELL_H * BEE_DIRS, false, Image.FORMAT_RGBA8)
				var c: Color = Color(0.8, 0.6, 0.2, 0.8) if role == "queen" else Color(0.6, 0.5, 0.3, 0.8)
				img.fill(c)
			else:
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
			_breed_sheets[key] = img

func _ensure_canvas() -> void:
	if _canvas != null:
		return
	_canvas = Image.create(CANVAS_W, CANVAS_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_canvas)

# =============================================================================
# POSITION HELPERS
# =============================================================================

## Generate a position using Gaussian distribution centered on frame.
func _gaussian_position(spread: float) -> Vector2:
	var center_x: float = float(CANVAS_W) * 0.5
	var center_y: float = float(CANVAS_H) * 0.45
	var std_x: float = float(CANVAS_W) * spread
	var std_y: float = float(CANVAS_H) * spread

	# Box-Muller transform for Gaussian random
	var u1: float = maxf(_rng.randf(), 0.0001)
	var u2: float = _rng.randf()
	var z0: float = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	var z1: float = sqrt(-2.0 * log(u1)) * sin(TAU * u2)

	var px: float = clampf(center_x + z0 * std_x, 20.0, float(CANVAS_W) - 20.0)
	var py: float = clampf(center_y + z1 * std_y, 15.0, float(CANVAS_H) - 15.0)
	return Vector2(px, py)

## Find which frame the queen is on (center-out, first with eggs).
func _find_queen_frame(sim: HiveSimulation) -> int:
	if sim.boxes.is_empty():
		return 4
	var box: Variant = sim.boxes[0]
	for fi in HiveSimulation.QUEEN_FRAME_ORDER:
		if fi < box.frames.size():
			if CellStateTransition.count_state(box.frames[fi], CellStateTransition.S_EGG) > 0:
				return fi
	return HiveSimulation.QUEEN_FRAME_ORDER[0]

## Convert angle (radians, screen-space Y-down) to 8-way direction index.
## Spritesheet rows use math convention (Y-up): 0=E, 1=NE, 2=N, 3=NW, 4=W, 5=SW, 6=S, 7=SE
## So we negate the angle to flip Y before quantizing.
func _angle_to_dir(angle: float) -> int:
	var a: float = fmod(-angle + TAU, TAU)
	var idx: int = int(roundf(a / (TAU / 8.0))) % 8
	return idx

## Convert 8-way direction index to unit vector in screen-space (Y-down).
## Negates Y because sprite directions use math convention (Y-up).
func _dir_to_vector(dir: int) -> Vector2:
	var angle: float = float(dir) * (TAU / 8.0)
	return Vector2(cos(angle), -sin(angle))
