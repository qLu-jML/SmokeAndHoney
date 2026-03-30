# timber_creek.gd -- Timber Creek nature area.
# GDD S13.5: Wooded creek valley with rich forage, wildlife, and walking trails.
# First-pass scene: walkable trail area with trees, creek, and wildlife sprites.
extends Node2D

func _ready() -> void:
	_setup_weather()
	TimeManager.current_scene_id = "timber_creek"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Timber Creek"
		SceneManager.show_zone_name()
		_register_map_markers()
	_apply_seasonal_visuals()
	TimeManager.day_advanced.connect(_on_day_advanced)
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("Timber Creek scene loaded.")

func _setup_exits() -> void:
	# Bottom edge -> County Road
	ExitHelper.create_exit(self, "bottom", "res://scenes/world/county_road.tscn",
		"v County Road")

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# Nature landmarks
	var creek: Node2D = get_node_or_null("World/Creek") as Node2D
	if creek:
		SceneManager.register_scene_poi(creek.position, "Creek", Color(0.3, 0.6, 0.85))
	var signpost: Node2D = get_node_or_null("World/Props/Signpost") as Node2D
	if signpost:
		SceneManager.register_scene_poi(signpost.position, "Signpost", Color(0.7, 0.55, 0.3))
	# Exits
	SceneManager.register_scene_exit("bottom", "County Road")

func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()

func _apply_seasonal_visuals() -> void:
	var season: String = TimeManager.current_season_name()
	var trees: Node2D = get_node_or_null("World/Trees") as Node2D
	if trees:
		match season:
			"Spring":
				trees.modulate = Color(0.90, 1.0, 0.85, 1.0)
			"Summer":
				trees.modulate = Color(1.0, 1.0, 1.0, 1.0)
			"Fall":
				trees.modulate = Color(1.0, 0.88, 0.72, 1.0)
			"Winter":
				trees.modulate = Color(0.85, 0.88, 0.95, 1.0)
	var creek: Node2D = get_node_or_null("World/Creek") as Node2D
	if creek:
		match season:
			"Spring":
				creek.modulate = Color(0.80, 0.75, 0.65, 1.0)   # turbid spring runoff
			"Winter":
				creek.modulate = Color(0.85, 0.90, 1.0, 1.0)    # icy
			_:
				creek.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _setup_weather() -> void:
	if get_node_or_null("WeatherOverlay") == null:
		var overlay: CanvasLayer = CanvasLayer.new()
		overlay.name = "WeatherOverlay"
		overlay.set_script(load("res://scripts/world/weather_overlay.gd"))
		add_child(overlay)
	var world: Node = get_node_or_null("World")
	if world != null and world.get_node_or_null("WeatherParticles") == null:
		var particles: Node2D = Node2D.new()
		particles.name = "WeatherParticles"
		particles.set_script(load("res://scripts/world/weather_particles.gd"))
		world.add_child(particles)
