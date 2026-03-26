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
	# returns false and we fall through to Priority 3 (fresh game).
	if SaveManager.load_from_disk():
		SaveManager.apply_to_scene(self)
	else:
		# -- Priority 3: fresh game -- spawn the starter overwintered hive -----
		# The player's story begins in spring with one established colony that
		# survived winter.  Carniolan B-rated queen, 4 drawn frames, small
		# brood nest, adequate stores.  Placed near the player's starting area.
		_spawn_starter_hive()

	# -- Walking exits ----------------------------------------------------------
	_setup_exits()
	# Position player based on which direction they came from
	ExitHelper.position_player_from_spawn_side(self)

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	# Fixed bounds for the home property map.
	# Content: player(-14,-26), Bob(380,140), Merchant(565,290),
	#   Storage(200,220), Hive(300,350), exit-right(330,45).
	# Bounds padded ~80px beyond outermost content on each side.
	SceneManager.set_scene_bounds(Rect2(-100, -110, 750, 550))
	var uncle_bob: Node2D = get_node_or_null("World/UncleBob")
	if uncle_bob:
		SceneManager.register_scene_poi(uncle_bob.global_position, "Uncle Bob", Color(0.45, 0.85, 0.50))
		print("[HomeProperty] Registered Uncle Bob at %s" % str(uncle_bob.global_position))
	else:
		print("[HomeProperty] WARNING: UncleBob node not found!")
	var merchant: Node2D = get_node_or_null("World/Merchant")
	if merchant:
		SceneManager.register_scene_poi(merchant.global_position, "Merchant", Color(0.70, 0.50, 0.90))
		print("[HomeProperty] Registered Merchant at %s" % str(merchant.global_position))
	else:
		print("[HomeProperty] WARNING: Merchant node not found!")
	var chest: Node2D = get_node_or_null("World/StorageChest")
	if chest:
		SceneManager.register_scene_poi(chest.global_position, "Storage", Color(0.85, 0.70, 0.30))
		print("[HomeProperty] Registered Storage at %s" % str(chest.global_position))
	else:
		print("[HomeProperty] WARNING: StorageChest node not found!")
	# Hive (spawned at fixed position on fresh game)
	SceneManager.register_scene_poi(Vector2(300, 350), "Hive", Color(0.95, 0.80, 0.25))
	print("[HomeProperty] Registered Hive at (300, 350)")
	# Exits
	SceneManager.register_scene_exit("right", "County Road")
	print("[HomeProperty] Registered exit: right -> County Road")
	print("[HomeProperty] Total POIs: %d, Exits: %d" % [SceneManager._scene_pois.size(), SceneManager._scene_exits.size()])

## Spawn the starter overwintered hive on a fresh game (no save file).
## Placed south-east of the player's starting position in a logical apiary spot.
func _spawn_starter_hive() -> void:
	var world: Node = get_node_or_null("World")
	if world == null:
		return
	var hive_node: Node2D = HIVE_SCENE.instantiate()
	world.add_child(hive_node)
	# Position the hive to the right and slightly below the player start (73,141).
	# Far enough away to feel intentional, close enough to find immediately.
	hive_node.global_position = Vector2(300, 350)
	# Overwintered Carniolan B -- the benchmark test colony for spring Day 1.
	if hive_node.has_method("place_as_overwintered"):
		hive_node.place_as_overwintered("Carniolan", "B")

func _setup_exits() -> void:
	# Right edge -> County Road
	ExitHelper.create_exit(self, "right", "res://scenes/world/county_road.tscn",
		"-> County Road")
