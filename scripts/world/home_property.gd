extends Node2D

const HIVE_SCENE   := preload("res://scenes/hive.tscn")
const FLOWER_SCENE := preload("res://scenes/flowers/flowers.tscn")

const INTERACT_RADIUS := 100.0

# Building door triggers: node_name -> interior scene path
var _building_triggers: Dictionary = {}

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

	# -- Building entry triggers ------------------------------------------------
	_setup_building_triggers()

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
	# Buildings
	var farmhouse: Node2D = get_node_or_null("World/Buildings/Farmhouse")
	if farmhouse:
		SceneManager.register_scene_poi(farmhouse.global_position, "Farmhouse", Color(0.85, 0.65, 0.40))
	var honey_house: Node2D = get_node_or_null("World/Buildings/HoneyHouse")
	if honey_house:
		SceneManager.register_scene_poi(honey_house.global_position, "Honey House", Color(0.90, 0.70, 0.30))
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

func _setup_building_triggers() -> void:
	_building_triggers = {
		"Farmhouse":  "res://scenes/house/house_interior.tscn",
		"HoneyHouse": "res://scenes/world/honey_house.tscn",
	}

func _process(_delta: float) -> void:
	var player: Node2D = get_node_or_null("World/player") as Node2D
	if not player:
		return
	# Show/hide hints on buildings based on proximity
	for bname in _building_triggers.keys():
		var bnode: Node2D = get_node_or_null("World/Buildings/" + bname) as Node2D
		if not bnode:
			continue
		var dist: float = player.global_position.distance_to(bnode.global_position)
		var hint: Label = bnode.get_node_or_null("InteractHint") as Label
		if hint:
			hint.visible = dist < INTERACT_RADIUS

	# Handle E key to enter buildings
	if Input.is_action_just_pressed("interact"):
		_try_enter_building(player)

func _try_enter_building(player: Node2D) -> void:
	var closest_name: String = ""
	var closest_dist: float = INF
	for bname in _building_triggers.keys():
		var bnode: Node2D = get_node_or_null("World/Buildings/" + bname) as Node2D
		if not bnode:
			continue
		var dist: float = player.global_position.distance_to(bnode.global_position)
		if dist < INTERACT_RADIUS and dist < closest_dist:
			closest_dist = dist
			closest_name = bname
	if closest_name == "":
		return
	var target_scene: String = _building_triggers.get(closest_name, "")
	if target_scene == "":
		return
	# Save exterior state before entering interior
	_save_exterior_state()
	TimeManager.came_from_interior = false
	TimeManager.player_return_pos = player.global_position
	print("[HomeProperty] Entering %s -> %s" % [closest_name, target_scene])
	SceneManager.change_scene(target_scene)

func _save_exterior_state() -> void:
	var world: Node = get_node_or_null("World")
	if not world:
		return
	TimeManager.exterior_hives.clear()
	TimeManager.exterior_flowers.clear()
	for child in world.get_children():
		if child.has_method("get_hive_data"):
			TimeManager.exterior_hives.append({
				"pos": child.global_position,
				"tile": child.get_meta("tile_coords", Vector2i.ZERO)
			})
		elif child.is_in_group("flowers"):
			TimeManager.exterior_flowers.append({
				"pos": child.global_position
			})

func _setup_exits() -> void:
	# Right edge -> County Road
	ExitHelper.create_exit(self, "right", "res://scenes/world/county_road.tscn",
		"-> County Road")
