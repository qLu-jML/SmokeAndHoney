extends Node2D

const HIVE_SCENE   := preload("res://scenes/hive.tscn")
const FLOWER_SCENE := preload("res://scenes/flowers/flowers.tscn")

func _ready() -> void:
	TimeManager.current_scene_id = "home"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Home Property"
		SceneManager.show_zone_name()
		_register_map_markers()
	# -- Priority 1: returning from an interior scene --------------------------
	# The player walked through a door (house -> exterior).  TimeManager carries
	# the hive / flower / player-position state across the scene change.
	if TimeManager.came_from_interior:
		TimeManager.came_from_interior = false

		var world: Node = get_node_or_null("World")
		if world == null:
			return

		# Restore hives
		for entry in TimeManager.exterior_hives:
			var h: Node2D = HIVE_SCENE.instantiate()
			world.add_child(h)
			h.global_position = entry["pos"]
			if entry.has("tile"):
				h.set_meta("tile_coords", entry["tile"])

		# Restore flowers
		for entry in TimeManager.exterior_flowers:
			var f: Node2D = FLOWER_SCENE.instantiate()
			world.add_child(f)
			f.global_position = entry["pos"]

		# Reposition player at the door they exited from
		var player = get_node_or_null("World/player")
		if player and player is Node2D:
			(player as Node2D).global_position = TimeManager.player_return_pos

		return   # interior-return handled; skip save-load path

	# -- Priority 2: load an existing save on game startup ---------------------
	# load_from_disk() reads + validates user://smoke_and_honey_save.json.
	# If successful, apply_to_scene() spawns saved hives and flowers, restores
	# player position and inventory, and rehydrates all autoload state.
	# If no save file exists (first run) or it is corrupted, load_from_disk()
	# returns false and we skip silently -- the scene starts as a fresh game.
	if SaveManager.load_from_disk():
		SaveManager.apply_to_scene(self)

	# -- Walking exits ----------------------------------------------------------
	_setup_exits()
	# Position player based on which direction they came from
	ExitHelper.position_player_from_spawn_side(self)

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	# Home scene is larger than default -- set bounds from wall positions
	SceneManager.set_scene_bounds(Rect2(-580, -350, 2667, 1635))
	# POIs -- buildings and notable objects
	var house_node: Node2D = get_node_or_null("World/House")
	if house_node:
		SceneManager.register_scene_poi(house_node.position, "House", Color(0.8, 0.6, 0.3))
	var uncle_bob: Node2D = get_node_or_null("World/UncleBob")
	if uncle_bob:
		SceneManager.register_scene_poi(uncle_bob.position, "Uncle Bob", Color(0.5, 0.8, 0.5))
	var merchant: Node2D = get_node_or_null("World/Merchant")
	if merchant:
		SceneManager.register_scene_poi(merchant.position, "Merchant", Color(0.7, 0.5, 0.9))
	var chest: Node2D = get_node_or_null("World/StorageChest")
	if chest:
		SceneManager.register_scene_poi(chest.position, "Storage", Color(0.6, 0.55, 0.4))
	# Exits
	SceneManager.register_scene_exit("right", "County Road")

func _setup_exits() -> void:
	# Right edge -> County Road
	ExitHelper.create_exit(self, "right", "res://scenes/world/county_road.tscn",
		"-> County Road")
