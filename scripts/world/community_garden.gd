# community_garden.gd -- Cedar Bend Community Garden & Park.
# GDD S13.6: Public garden near town with forage plots, park benches, and plaques.
# First-pass scene: walkable garden area with plots, benches, and NPC.
extends Node2D

const INTERACT_RADIUS := 60.0

func _ready() -> void:
	TimeManager.current_scene_id = "community_garden"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Community Garden"
		SceneManager.show_zone_name()
		_register_map_markers()
	_apply_seasonal_visuals()
	TimeManager.day_advanced.connect(_on_day_advanced)
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("Community Garden scene loaded.")

func _setup_exits() -> void:
	# Left edge -> Cedar Bend
	ExitHelper.create_exit(self, "left", "res://scenes/world/cedar_bend.tscn",
		"<- Cedar Bend")

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# Garden features
	var plaque: Node2D = get_node_or_null("World/Props/Plaque") as Node2D
	if plaque:
		SceneManager.register_scene_poi(plaque.position, "Plaque", Color(0.7, 0.55, 0.3))
	var bench: Node2D = get_node_or_null("World/Props/Bench") as Node2D
	if bench:
		SceneManager.register_scene_poi(bench.position, "Bench", Color(0.6, 0.5, 0.4))
	# NPC
	var terri: Node2D = get_node_or_null("World/NPCs/DrTerri") as Node2D
	if terri:
		SceneManager.register_scene_poi(terri.position, "Dr. Terri", Color(0.5, 0.8, 0.5))
	# Exits
	SceneManager.register_scene_exit("left", "Cedar Bend")

func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()

func _apply_seasonal_visuals() -> void:
	var season: String = TimeManager.current_season_name()
	var garden: Node2D = get_node_or_null("World/Garden") as Node2D
	if garden:
		match season:
			"Spring":
				garden.modulate = Color(0.88, 0.95, 0.82, 1.0)
			"Summer":
				garden.modulate = Color(1.0, 1.0, 1.0, 1.0)
			"Fall":
				garden.modulate = Color(0.98, 0.90, 0.75, 1.0)
			"Winter":
				garden.modulate = Color(0.90, 0.92, 0.98, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

func _try_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	# Check NPC -- Dr. Terri Vogel (entomologist)
	var terri: Node2D = get_node_or_null("World/NPCs/TerriVogel") as Node2D
	if terri:
		var dist: float = player.global_position.distance_to(terri.global_position)
		if dist <= INTERACT_RADIUS:
			print("[Garden] Dr. Vogel: 'The native pollinators are thriving here!'")
			return
	# Check garden plaque
	var plaque: Node2D = get_node_or_null("World/Props/GardenPlaque") as Node2D
	if plaque:
		var dist: float = player.global_position.distance_to(plaque.global_position)
		if dist <= INTERACT_RADIUS:
			print("[Garden] Plaque: 'Cedar Bend Community Pollinator Garden - Est. 1987'")
			return
