# fairgrounds.gd -- County Fairgrounds.
# GDD S13.7: Seasonal event location with honey competitions and exhibitions.
# First-pass scene: large open area with gate, tents, and booths.
extends Node2D

const INTERACT_RADIUS: float = 60.0

## Initialize the fairgrounds: weather, event state, exits, and signals.
func _ready() -> void:
	_setup_weather()
	TimeManager.current_scene_id = "fairgrounds"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "County Fairgrounds"
		SceneManager.show_zone_name()
		_register_map_markers()
	_update_event_state()
	TimeManager.day_advanced.connect(_on_day_advanced)
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("County Fairgrounds scene loaded.")

## Create dynamic exits for the fairgrounds.
func _setup_exits() -> void:
	# Top edge -> Cedar Bend
	ExitHelper.create_exit(self, "top", "res://scenes/world/cedar_bend.tscn",
		"^ Cedar Bend")

## Register map markers for fairgrounds features.
func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# Fairgrounds features
	var gate: Node2D = get_node_or_null("World/Buildings/Gate") as Node2D
	if gate:
		SceneManager.register_scene_poi(gate.position, "Gate", Color(0.7, 0.4, 0.2))
	var booths: Node2D = get_node_or_null("World/EventBooths") as Node2D
	if booths and booths.visible:
		SceneManager.register_scene_poi(booths.position, "Event Booths", Color(0.9, 0.7, 0.2))
	# Exits
	SceneManager.register_scene_exit("top", "Cedar Bend")

## Handle day advancement to update event state.
func _on_day_advanced(_day: int) -> void:
	_update_event_state()

## Update event visibility and signage based on current season.
func _update_event_state() -> void:
	# Fairgrounds are only fully active during fair season (Fall, days 113-140)
	var season: String = TimeManager.current_season_name()
	var booths: Node2D = get_node_or_null("World/EventBooths") as Node2D
	if booths:
		booths.visible = (season == "Fall")
	var off_season_sign: Node2D = get_node_or_null("World/Props/OffSeasonSign") as Node2D
	if off_season_sign:
		off_season_sign.visible = (season != "Fall")

## Handle input events for interactions.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

## Attempt to interact with nearby NPCs or buildings.
func _try_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	# Check Harwick Office
	var office: Node2D = get_node_or_null("World/Buildings/HarwickOffice") as Node2D
	if office:
		var dist: float = player.global_position.distance_to(office.global_position)
		if dist <= INTERACT_RADIUS:
			print("[Fairgrounds] Ellen Harwick's office -- 'The county fair is coming up!'")
			return

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
