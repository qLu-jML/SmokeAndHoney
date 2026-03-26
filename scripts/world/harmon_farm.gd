# harmon_farm.gd -- Walt and Kacey Harmon's working farm.
# GDD S13.4: Large-scale crop farm with barn, grain bins, and machinery.
# First-pass scene: walkable farm yard with building sprites and exit door.
extends Node2D

const INTERACT_RADIUS := 60.0

func _ready() -> void:
	TimeManager.current_scene_id = "harmon_farm"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Harmon Farm"
		SceneManager.show_zone_name()
	_apply_seasonal_visuals()
	TimeManager.day_advanced.connect(_on_day_advanced)
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("Harmon Farm scene loaded.")

func _setup_exits() -> void:
	# Top edge -> County Road
	ExitHelper.create_exit(self, "top", "res://scenes/world/county_road.tscn",
		"^ County Road")

func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()

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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_interact()

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

func _enter_barn() -> void:
	TimeManager.previous_scene = "res://scenes/world/harmon_farm.tscn"
	TimeManager.next_scene = "res://scenes/world/harmon_barn_interior.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
