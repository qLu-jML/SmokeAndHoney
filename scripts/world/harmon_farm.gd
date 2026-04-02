# harmon_farm.gd -- Walt and Kacey Harmon's working farm.
# GDD S13.4: Large-scale crop farm with barn, grain bins, and machinery.
# First-pass scene: walkable farm yard with building sprites and exit door.
extends Node2D

const INTERACT_RADIUS: float = 60.0

## Initialize the Harmon Farm scene: weather, season, exits, and signal connections.
func _ready() -> void:
	_setup_weather()
	TimeManager.current_scene_id = "harmon_farm"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Harmon Farm"
		SceneManager.show_zone_name()
		_register_map_markers()
	_apply_seasonal_visuals()
	TimeManager.day_advanced.connect(_on_day_advanced)
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("Harmon Farm scene loaded.")

## Create dynamic exits for the farm.
func _setup_exits() -> void:
	# Top edge -> County Road
	ExitHelper.create_exit(self, "top", "res://scenes/world/county_road.tscn",
		"^ County Road")

## Register map markers for buildings and NPCs.
func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# Buildings
	var barn: Node2D = get_node_or_null("World/Buildings/Barn") as Node2D
	if barn:
		SceneManager.register_scene_poi(barn.position, "Barn", Color(0.7, 0.4, 0.2))
	var farmhouse: Node2D = get_node_or_null("World/Buildings/Farmhouse") as Node2D
	if farmhouse:
		SceneManager.register_scene_poi(farmhouse.position, "Farmhouse", Color(0.8, 0.6, 0.3))
	# NPCs
	var walt: Node2D = get_node_or_null("World/NPCs/Walt") as Node2D
	if walt:
		SceneManager.register_scene_poi(walt.position, "Walt", Color(0.5, 0.8, 0.5))
	var kacey: Node2D = get_node_or_null("World/NPCs/Kacey") as Node2D
	if kacey:
		SceneManager.register_scene_poi(kacey.position, "Kacey", Color(0.5, 0.8, 0.5))
	# Exits
	SceneManager.register_scene_exit("top", "County Road")

## Handle day advancement to update seasonal visuals.
func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()

## Apply seasonal color tinting to the fields.
func _apply_seasonal_visuals() -> void:
	var season: String = TimeManager.current_season_name()
	var field: Node2D = get_node_or_null("World/Fields") as Node2D
	if field:
		match season:
			"Spring":
				field.modulate = Color(0.85, 0.92, 0.78, 1.0)
			"Summer":
				field.modulate = Color(0.82, 0.90, 0.70, 1.0)
			"Fall":
				field.modulate = Color(0.95, 0.80, 0.50, 1.0)
			"Winter":
				field.modulate = Color(0.88, 0.92, 0.95, 1.0)

## Handle input events for interactions.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

## Attempt to interact with nearby buildings or NPCs.
func _try_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	# Check barn proximity
	var barn: Node2D = get_node_or_null("World/Buildings/HarmonBarn") as Node2D
	if barn:
		var dist: float = player.global_position.distance_to(barn.global_position)
		if dist <= INTERACT_RADIUS:
			_enter_barn()
			return
	# Check NPC proximity -- Walt Harmon
	var walt: Node2D = get_node_or_null("World/NPCs/WaltHarmon") as Node2D
	if walt:
		var dist: float = player.global_position.distance_to(walt.global_position)
		if dist <= INTERACT_RADIUS:
			print("[Harmon Farm] Walt: 'Morning! Crops are looking good this year.'")
			return
	# Check NPC proximity -- Kacey Harmon
	var kacey: Node2D = get_node_or_null("World/NPCs/KaceyHarmon") as Node2D
	if kacey:
		var dist: float = player.global_position.distance_to(kacey.global_position)
		if dist <= INTERACT_RADIUS:
			print("[Harmon Farm] Kacey: 'Hey there! Check out the bees by the windbreak.'")
			return

## Transition to the barn interior scene.
func _enter_barn() -> void:
	TimeManager.previous_scene = "res://scenes/world/harmon_farm.tscn"
	TimeManager.next_scene = "res://scenes/world/harmon_barn_interior.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

## Set up weather overlay and particles for this scene.
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

## Disconnect TimeManager signals when leaving the scene tree.
func _exit_tree() -> void:
	if TimeManager and TimeManager.is_connected("day_advanced", Callable(self, "_on_day_advanced")):
		TimeManager.day_advanced.disconnect(_on_day_advanced)
