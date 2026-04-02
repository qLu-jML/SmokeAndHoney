# weather_particles.gd -- Rain/snow particle system with collision awareness
# ============================================================================
# Procedural rain and snow using Godot's built-in drawing (no GPU particles
# needed for the pixel-art aesthetic). Renders as a Node2D child of the
# scene's World node so particles scroll with the camera.
#
# COLLISION SYSTEM:
#   - Registers tree canopy and grass/bush areas as "occluder" rects
#   - A percentage of raindrops that land in occluder zones get "caught":
#     they stop short and produce a small splash at the canopy/grass level
#   - Remaining drops fall through to ground level
#   - This creates the visual effect of rain hitting foliage realistically
#
# PERFORMANCE:
#   - Uses simple arrays of structs (Dictionaries) for particle state
#   - Draws via _draw() with draw_line() for rain, draw_rect() for snow
#   - Particle count scales with viewport (typ. 80-150 for 320x180)
# ============================================================================
extends Node2D

# -- Configuration -----------------------------------------------------------
var max_rain_drops: int = 120
var max_snowflakes: int = 80
var rain_speed_min: float = 120.0    # px/sec
var rain_speed_max: float = 180.0
var snow_speed_min: float = 15.0
var snow_speed_max: float = 30.0
var rain_length: float = 4.0         # line length in pixels
var wind_offset: float = 0.0         # horizontal drift from wind

# -- Occluder system (tree canopies, grass, bushes) --------------------------
# Each occluder: { "rect": Rect2, "catch_rate": float, "height_offset": float }
# catch_rate: 0.0-1.0 chance a drop hitting this area stops at the occluder
# height_offset: how far above ground the canopy sits (drops stop here)
var _occluders: Array = []

# -- Particle pools ----------------------------------------------------------
var _rain_drops: Array = []
var _snowflakes: Array = []
var _splashes: Array = []        # tiny splash effects at impact points

# -- State -------------------------------------------------------------------
var _active: bool = false
var _is_snow: bool = false
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _spawn_rect: Rect2 = Rect2(-20, -40, 360, 0)  # spawn strip above viewport
@warning_ignore("unused_private_class_variable")
var _ground_y: float = 200.0     # bottom of the play area

const VP_W: int = 320
const VP_H: int = 180

# Rain/snow colors (muted, fits the art style -- no pure white or bright blue)
const RAIN_COLOR_LIGHT := Color(0.65, 0.70, 0.78, 0.45)
const RAIN_COLOR_DARK  := Color(0.50, 0.55, 0.65, 0.55)
const SNOW_COLOR       := Color(0.88, 0.90, 0.92, 0.60)
const SPLASH_COLOR     := Color(0.60, 0.65, 0.72, 0.40)

## Ready.
func _ready() -> void:
	# Weather overlay is screen-space, so we don't follow camera per se --
	# we just draw across the viewport bounds.
	z_index = 90  # above most game objects, below UI

	if WeatherManager:
		WeatherManager.weather_changed.connect(_on_weather_changed)
		_apply_weather(WeatherManager.current_weather)

	# Auto-register occluders from scene tree
	call_deferred("_scan_for_occluders")

## Process.

## Disconnect signals when exiting tree.
func _exit_tree() -> void:
	pass  # Signal cleanup handled by node references
func _process(delta: float) -> void:
	if not _active:
		# Fade out remaining splashes
		if _splashes.size() > 0:
			_update_splashes(delta)
			queue_redraw()
		return

	if _is_snow:
		_update_snow(delta)
	else:
		_update_rain(delta)

	_update_splashes(delta)
	queue_redraw()

func _draw() -> void:
	if not _active and _splashes.size() == 0:
		return

	# Get camera offset so particles appear in screen space
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_offset: Vector2 = Vector2.ZERO
	if cam:
		cam_offset = cam.get_screen_center_position() - Vector2(VP_W / 2.0, VP_H / 2.0)

	if _is_snow:
		_draw_snow(cam_offset)
	else:
		_draw_rain(cam_offset)

	_draw_splashes(cam_offset)

# ============================================================================
# RAIN
# ============================================================================

func _update_rain(delta: float) -> void:
	# Spawn new drops to maintain pool
	while _rain_drops.size() < max_rain_drops:
		_rain_drops.append(_make_rain_drop())

	# Get camera position for screen-space spawning
	var cam: Camera2D = get_viewport().get_camera_2d()
	var cam_offset: Vector2 = Vector2.ZERO
	if cam:
		cam_offset = cam.get_screen_center_position() - Vector2(VP_W / 2.0, VP_H / 2.0)

	var i: int = _rain_drops.size() - 1
	while i >= 0:
		var drop: Dictionary = _rain_drops[i]
		var speed: float = drop["speed"]

		# Move down + wind drift
		drop["x"] += wind_offset * delta
		drop["y"] += speed * delta

		# World-space position of the drop
		var world_x: float = drop["x"] + cam_offset.x
		var world_y: float = drop["y"] + cam_offset.y

		# Check occluder collision
		var caught: bool = false
		for occ in _occluders:
			var r: Rect2 = occ["rect"]
			if r.has_point(Vector2(world_x, world_y)):
				if randf() < occ["catch_rate"]:
					# Drop caught by canopy/grass -- splash at occluder surface
					_spawn_splash(drop["x"], drop["y"] - (world_y - r.position.y) * 0.3)
					caught = true
					break

		# Ground hit or caught
		if caught or drop["y"] > VP_H + 10:
			if not caught and randf() < 0.3:
				_spawn_splash(drop["x"], float(VP_H) - 2.0)
			_rain_drops[i] = _make_rain_drop()
		i -= 1

func _make_rain_drop() -> Dictionary:
	return {
		"x": randf_range(-10.0, float(VP_W) + 10.0),
		"y": randf_range(-40.0, -5.0),
		"speed": randf_range(rain_speed_min, rain_speed_max),
		"shade": randf(),  # 0=light, 1=dark for depth variation
	}

func _draw_rain(cam_offset: Vector2) -> void:
	for drop in _rain_drops:
		var x: float = drop["x"]
		var y: float = drop["y"]
		var shade: float = drop["shade"]
		var color: Color = RAIN_COLOR_LIGHT.lerp(RAIN_COLOR_DARK, shade)
		# Rain streaks: short diagonal lines (wind gives them angle)
		var end_x: float = x + wind_offset * 0.02
		var end_y: float = y + rain_length
		# Thinner drops in background (shade closer to 1 = farther)
		var width: float = 1.0 if shade < 0.5 else 0.5
		draw_line(
			Vector2(x, y) + cam_offset * 0.0,   # screen-space
			Vector2(end_x, end_y) + cam_offset * 0.0,
			color, width)

# ============================================================================
# SNOW
# ============================================================================

func _update_snow(delta: float) -> void:
	while _snowflakes.size() < max_snowflakes:
		_snowflakes.append(_make_snowflake())

	var i: int = _snowflakes.size() - 1
	while i >= 0:
		var flake: Dictionary = _snowflakes[i]
		# Gentle floating with horizontal wobble
		flake["wobble_t"] += delta * flake["wobble_speed"]
		flake["x"] += sin(flake["wobble_t"]) * 8.0 * delta + wind_offset * 0.5 * delta
		flake["y"] += flake["speed"] * delta

		if flake["y"] > VP_H + 5:
			_snowflakes[i] = _make_snowflake()
		i -= 1

func _make_snowflake() -> Dictionary:
	return {
		"x": randf_range(-10.0, float(VP_W) + 10.0),
		"y": randf_range(-30.0, -3.0),
		"speed": randf_range(snow_speed_min, snow_speed_max),
		"size": randf_range(1.0, 2.5),
		"wobble_t": randf() * TAU,
		"wobble_speed": randf_range(1.5, 3.0),
		"alpha": randf_range(0.3, 0.7),
	}

@warning_ignore("unused_parameter")
func _draw_snow(cam_offset: Vector2) -> void:
	for flake in _snowflakes:
		var x: float = flake["x"]
		var y: float = flake["y"]
		var sz: float = flake["size"]
		var color: Color = SNOW_COLOR
		color.a = flake["alpha"]
		# Small pixel rectangles for snow (fits pixel art style)
		draw_rect(Rect2(x - sz * 0.5, y - sz * 0.5, sz, sz), color)

# ============================================================================
# SPLASHES (tiny impact effects)
# ============================================================================

func _spawn_splash(x: float, y: float) -> void:
	if _splashes.size() > 60:
		return  # cap splash count for performance
	_splashes.append({
		"x": x,
		"y": y,
		"life": 0.15,  # seconds
		"max_life": 0.15,
		"size": randf_range(1.0, 2.0),
	})

func _update_splashes(delta: float) -> void:
	var i: int = _splashes.size() - 1
	while i >= 0:
		_splashes[i]["life"] -= delta
		if _splashes[i]["life"] <= 0.0:
			_splashes.remove_at(i)
		i -= 1

@warning_ignore("unused_parameter")
func _draw_splashes(cam_offset: Vector2) -> void:
	for splash in _splashes:
		var life_ratio: float = splash["life"] / splash["max_life"]
		var alpha: float = life_ratio * 0.5
		var radius: float = splash["size"] * (1.0 + (1.0 - life_ratio) * 1.5)
		var color: Color = SPLASH_COLOR
		color.a = alpha
		# Expanding circle effect (small, pixel-scale)
		draw_rect(
			Rect2(splash["x"] - radius, splash["y"] - 0.5, radius * 2.0, 1.0),
			color)

# ============================================================================
# OCCLUDER SYSTEM
# ============================================================================

## Scan the scene tree for nodes tagged as weather occluders.
## Trees, grass patches, and buildings can add themselves to the "weather_occluder"
## group, or we detect them by node name patterns.
func _scan_for_occluders() -> void:
	_occluders.clear()

	# Method 1: Nodes in the "weather_occluder" group
	for node in get_tree().get_nodes_in_group("weather_occluder"):
		if node is Node2D:
			var n2d: Node2D = node as Node2D
			var rect: Rect2 = _estimate_node_rect(n2d)
			if rect.size.x > 0 and rect.size.y > 0:
				_occluders.append({
					"rect": rect,
					"catch_rate": node.get_meta("weather_catch_rate", 0.5),
					"node": node,
				})

	# Method 2: Auto-detect by name patterns (trees, bushes, grass)
	_scan_children_recursive(get_parent())

	if _occluders.size() > 0:
		print("[WeatherParticles] Registered %d occluders" % _occluders.size())

func _scan_children_recursive(node: Node) -> void:
	if not node:
		return
	for child in node.get_children():
		if child is Node2D:
			var name_lower: String = child.name.to_lower()
			var catch_rate: float = 0.0

			# Tree canopies catch ~60% of rain
			if "tree" in name_lower:
				catch_rate = 0.6
			# Bushes catch ~40%
			elif "bush" in name_lower or "shrub" in name_lower:
				catch_rate = 0.4
			# Grass patches catch ~20% (shorter, more gaps)
			elif "grass" in name_lower:
				catch_rate = 0.2
			# Awnings and roofs catch nearly all rain
			elif "roof" in name_lower or "awning" in name_lower:
				catch_rate = 0.9

			if catch_rate > 0.0:
				var rect: Rect2 = _estimate_node_rect(child as Node2D)
				if rect.size.x > 0 and rect.size.y > 0:
					# Avoid duplicates
					var already: bool = false
					for occ in _occluders:
						if occ.get("node") == child:
							already = true
							break
					if not already:
						_occluders.append({
							"rect": rect,
							"catch_rate": catch_rate,
							"node": child,
						})

		# Don't recurse too deep (performance)
		if child.get_child_count() > 0 and child.get_child_count() < 50:
			_scan_children_recursive(child)

func _estimate_node_rect(node: Node2D) -> Rect2:
	# Try to get bounds from a Sprite2D child or the node itself
	if node is Sprite2D:
		var spr: Sprite2D = node as Sprite2D
		if spr.texture:
			var tex_size: Vector2 = spr.texture.get_size()
			var pos: Vector2 = spr.global_position
			if spr.centered:
				pos -= tex_size * 0.5
			return Rect2(pos, tex_size)

	# Check for Sprite2D children
	for child in node.get_children():
		if child is Sprite2D:
			var spr: Sprite2D = child as Sprite2D
			if spr.texture:
				var tex_size: Vector2 = spr.texture.get_size()
				var pos: Vector2 = spr.global_position
				if spr.centered:
					pos -= tex_size * 0.5
				return Rect2(pos, tex_size)

	# Fallback: use a default rect around the node position
	# Only if we matched by name (so we know it should be an occluder)
	return Rect2(node.global_position - Vector2(16, 16), Vector2(32, 32))

# ============================================================================
# WEATHER CHANGE HANDLING
# ============================================================================

## On weather changed.
func _on_weather_changed(new_weather: String) -> void:
	_apply_weather(new_weather)

func _apply_weather(weather: String) -> void:
	var was_active: bool = _active

	match weather:
		"Rainy":
			_active = true
			_is_snow = WeatherManager.is_snowing()
			wind_offset = WeatherManager.current_wind_mph * 1.5
			if _is_snow:
				max_snowflakes = 80
			else:
				max_rain_drops = 120
		_:
			_active = false
			# Clear particles gradually (they'll fall off screen)
			if was_active:
				# Keep existing drops but stop spawning new ones
				pass

	# Windy weather adds drift to any active precipitation
	if weather == "Windy":
		wind_offset = WeatherManager.current_wind_mph * 2.0

## Clear particles.
func _clear_particles() -> void:
	_rain_drops.clear()
	_snowflakes.clear()
	queue_redraw()

## Manually register an occluder (for dynamic objects like placed trees).
func register_occluder(node: Node2D, catch_rate: float = 0.5) -> void:
	var rect: Rect2 = _estimate_node_rect(node)
	if rect.size.x > 0:
		_occluders.append({
			"rect": rect,
			"catch_rate": catch_rate,
			"node": node,
		})

## Remove occluder when a node is removed.
func unregister_occluder(node: Node2D) -> void:
	for i in range(_occluders.size() - 1, -1, -1):
		if _occluders[i].get("node") == node:
			_occluders.remove_at(i)
