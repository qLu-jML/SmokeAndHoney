extends Node2D

const HIVE_SCENE   := preload("res://scenes/hive.tscn")
const FLOWER_SCENE := preload("res://scenes/flowers/flowers.tscn")
const TREE_SCENE   := preload("res://scenes/world/seasonal_tree.tscn")

# Building door triggers: node_name -> interior scene path
var _building_triggers: Dictionary = {}

# -- Workbench (shed crafting station) ----------------------------------------
var _workbench_node: Node2D = null
var _workbench_hint: Label = null
var _active_workbench_ui: CanvasLayer = null
const WORKBENCH_POS := Vector2(520, -20)  # Near buildings, right of honey house
const WORKBENCH_RADIUS := 48.0

func _ready() -> void:
	TimeManager.current_scene_id = "home"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Home Property"
		SceneManager.show_zone_name()
		_register_map_markers()
	# -- Weather visuals (overlay tint + rain/snow particles) ------------------
	_setup_weather()
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
	# Door zones and exit zones are now placed as nodes in the .tscn file
	# so they are visible and draggable in the Godot editor.
	# Legacy dynamic creation is kept as a fallback only.
	if not _has_scene_exit("ExitRight_CountyRoad"):
		_setup_exits()
	if not _has_scene_door("FarmhouseDoor"):
		_setup_building_triggers()

	# Position player based on which direction they came from
	ExitHelper.position_player_from_spawn_side(self)

	# -- Farmstead Trees (early spring forage before dandelion bloom) ----------
	_spawn_trees()

	# -- Outdoor Harvest Yard (Level 1 manual processing) ---------------------
	_spawn_harvest_yard()

	# -- Shed Workbench (crafting station for frames/boxes from lumber) --------
	_spawn_workbench()

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	# Fixed bounds for the home property map.
	# Content spans from Willow(-160,120) to Cottonwood(620,220),
	#   ElmDead(280,480), buildings, NPCs, hive(300,350).
	# Bounds padded ~80px beyond outermost content on each side.
	SceneManager.set_scene_bounds(Rect2(-240, -130, 1640, 700))
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
	# Nap bench
	var bench: Node2D = get_node_or_null("World/NapBench")
	if bench:
		SceneManager.register_scene_poi(bench.global_position, "Bench", Color(0.55, 0.75, 0.85))
	# Hive (spawned at fixed position on fresh game)
	SceneManager.register_scene_poi(Vector2(300, 350), "Hive", Color(0.95, 0.80, 0.25))
	# Harvest Yard (outdoor processing area)
	SceneManager.register_scene_poi(Vector2(580, 380), "Harvest Yard", Color(0.85, 0.65, 0.30))
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

	if GameData.new_game_mode == 1:
		# Fall start: strong colony with 2 filled honey supers, day 113.
		# The player jumps straight into the fall harvest workflow.
		if hive_node.has_method("place_as_fall_harvest"):
			hive_node.place_as_fall_harvest("Carniolan", "A")
		# Reset mode so Continue saves don't re-trigger fall setup
		GameData.new_game_mode = 0
	else:
		# Default spring start: overwintered Carniolan S, day 1.
		if hive_node.has_method("place_as_overwintered"):
			hive_node.place_as_overwintered("Carniolan", "S")

func _has_scene_exit(exit_name: String) -> bool:
	var world: Node = get_node_or_null("World")
	if world and world.get_node_or_null(exit_name):
		return true
	return false

func _has_scene_door(door_name: String) -> bool:
	# Check if door zones exist on building children
	var farmhouse: Node = get_node_or_null("World/Buildings/Farmhouse")
	if farmhouse and farmhouse.get_node_or_null(door_name):
		return true
	return false

func _setup_building_triggers() -> void:
	_building_triggers = {
		"Farmhouse":  "res://scenes/house/house_interior.tscn",
		"HoneyHouse": "res://scenes/world/honey_house.tscn",
	}
	# Create Area2D door zones on each building for collision-based entry.
	# The player walks into the door area to enter the building.
	for bname in _building_triggers.keys():
		var bnode: Node2D = get_node_or_null("World/Buildings/" + bname) as Node2D
		if not bnode:
			continue
		# Skip if a DoorZone already exists (scene might define one)
		if bnode.get_node_or_null("DoorZone"):
			continue
		var area: Area2D = Area2D.new()
		area.name = "DoorZone"
		# Door zones detect physics bodies (player is on layer 1)
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitoring = true
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		# Door hit zone: centered at bottom of sprite (where the door is)
		# Farmhouse and HoneyHouse doors are at the bottom-center of the sprite
		rect.size = Vector2(30, 14)
		shape.shape = rect
		# Position the door zone at the bottom of the building sprite
		# (sprites are centered, so door is roughly at y = sprite_height/2)
		shape.position = Vector2(0, 60)
		area.add_child(shape)
		bnode.add_child(area)
		# Connect the body_entered signal to our door handler
		area.body_entered.connect(_on_door_entered.bind(bname))
		print("[HomeProperty] Created door zone for %s" % bname)

func _on_door_entered(body: Node2D, building_name: String) -> void:
	# Only the player triggers door entry
	if body.name != "player":
		return
	var target_scene: String = _building_triggers.get(building_name, "")
	if target_scene == "":
		return
	# Save exterior state before entering interior
	_save_exterior_state()
	TimeManager.came_from_interior = false
	TimeManager.player_return_pos = body.global_position
	print("[HomeProperty] Entering %s -> %s" % [building_name, target_scene])
	SceneManager.go_to_scene(target_scene)

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

## Spawn the outdoor harvest yard (Level 1 manual processing stations).
## Positioned south-east of the main buildings, near the hive.
func _spawn_harvest_yard() -> void:
	var world: Node = get_node_or_null("World")
	if world == null:
		return
	# Don't duplicate if already exists (e.g. returning from interior)
	if world.get_node_or_null("HarvestYard"):
		return
	var yard := Node2D.new()
	yard.name = "HarvestYard"
	yard.set_script(load("res://scripts/world/harvest_yard.gd"))
	world.add_child(yard)
	# Position the yard south-east of existing buildings
	# Farmhouse at (80,-80), HoneyHouse at (450,-40), Hive at (300,350)
	# Place processing area right of hive, accessible from hive walk
	yard.global_position = Vector2(480, 350)
	yard.z_index = 2  # Above flowers (z=1) so bottling table is not hidden
	print("[HomeProperty] Harvest yard spawned at %s" % str(yard.global_position))

## Spawn farmstead trees that provide early-spring forage before the dandelion bloom.
## Iowa farmstead layout: willows near creek/pond, silver maple in yard, wild plum
## along fenceline, fruit trees near house, cottonwood as windbreak, basswood for
## summer honey flow. An old dead elm provides atmosphere but no forage.
## These trees feed the hive from Day 1 through the "trees" group forage system.
func _spawn_trees() -> void:
	var world: Node = get_node_or_null("World")
	if world == null:
		return
	# Don't duplicate if trees already exist (returning from interior)
	if world.get_node_or_null("FarmsteadTrees"):
		return

	var tree_root := Node2D.new()
	tree_root.name = "FarmsteadTrees"
	world.add_child(tree_root)

	# Tree layout data: [tree_type, position, flip, name]
	# Scene bounds: Rect2(-240, -130, 1640, 700)
	# Farmhouse ~(80,-80), HoneyHouse ~(450,-40), Hive ~(300,350), Player start ~(73,141)
	var tree_defs: Array = [
		# -- WILLOWS (month 0): earliest spring pollen + nectar lifeline --
		# Creek-side willows at the south-west edge of the property
		["willow",         Vector2(-120, 280),  false, "WillowCreek1"],
		["willow",         Vector2(-160, 120),  true,  "WillowCreek2"],

		# -- SILVER MAPLE (month 0): yard shade tree with heavy early pollen --
		["silver_maple",   Vector2(160, -40),   false, "SilverMapleYard"],

		# -- WILD PLUM (months 0-1): fenceline thicket along west edge --
		["wild_plum",      Vector2(-100, 400),  false, "WildPlumFence1"],
		["wild_plum",      Vector2(-140, 480),  true,  "WildPlumFence2"],

		# -- COTTONWOOD (months 0-1): tall windbreak at far north-east --
		["cottonwood",     Vector2(680, -60),   false, "CottonwoodWind"],

		# -- APPLE TREE (month 1): farmhouse fruit tree, bridges into Greening --
		["apple_tree",     Vector2(180, -100),  false, "AppleTreeYard"],

		# -- BASSWOOD/LINDEN (months 2-3): premium summer honey tree, far south-east --
		["basswood_linden", Vector2(820, 450),  false, "BasswoodSouth"],

		# -- ELM DEAD: atmosphere, no forage -- far south-west away from hive --
		["elm_dead",       Vector2(-80, 520),   true,  "ElmDead"],

		# -- SYCAMORE (months 0-1): minor pollen, nice visual near buildings --
		["sycamore",       Vector2(350, -60),   false, "SycamoreNorth"],
	]

	for td in tree_defs:
		var tree_node: Node2D = TREE_SCENE.instantiate()
		tree_node.name = td[3]
		tree_node.set("tree_type", td[0])
		tree_node.set("flip", td[2])
		tree_root.add_child(tree_node)
		tree_node.global_position = td[1]

	print("[HomeProperty] Spawned %d farmstead trees" % tree_defs.size())

# -- Workbench (shed crafting station) ----------------------------------------

func _spawn_workbench() -> void:
	var world: Node = get_node_or_null("World")
	if world == null:
		return
	if world.get_node_or_null("Workbench"):
		return  # Already exists

	_workbench_node = Node2D.new()
	_workbench_node.name = "Workbench"
	_workbench_node.position = WORKBENCH_POS
	world.add_child(_workbench_node)

	# Visual: small brown table
	var table := ColorRect.new()
	table.color = Color(0.50, 0.35, 0.18, 1.0)
	table.size = Vector2(28, 16)
	table.position = Vector2(-14, -8)
	_workbench_node.add_child(table)

	# Table top (lighter)
	var top := ColorRect.new()
	top.color = Color(0.62, 0.48, 0.28, 1.0)
	top.size = Vector2(24, 12)
	top.position = Vector2(-12, -6)
	_workbench_node.add_child(top)

	# Interaction hint
	_workbench_hint = Label.new()
	_workbench_hint.text = "[E] Workbench"
	_workbench_hint.add_theme_font_size_override("font_size", 5)
	_workbench_hint.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	_workbench_hint.position = Vector2(-20, -22)
	_workbench_hint.visible = false
	_workbench_node.add_child(_workbench_hint)

	# Dev label
	var dev_lbl := Label.new()
	dev_lbl.text = "Workbench"
	dev_lbl.add_theme_font_size_override("font_size", 4)
	dev_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5, 0.6))
	dev_lbl.position = Vector2(-16, 10)
	dev_lbl.visible = GameData.dev_labels_visible
	dev_lbl.add_to_group("dev_label")
	_workbench_node.add_child(dev_lbl)

	# Register as POI
	if get_node_or_null("/root/SceneManager"):
		SceneManager.register_scene_poi(WORKBENCH_POS, "Workbench", Color(0.70, 0.55, 0.30))

	print("[HomeProperty] Workbench spawned at %s" % str(WORKBENCH_POS))

func _process(_delta: float) -> void:
	if _active_workbench_ui:
		return
	# Update workbench hint visibility based on player proximity
	if _workbench_node and _workbench_hint:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var dist: float = player.global_position.distance_to(_workbench_node.global_position)
			_workbench_hint.visible = dist <= WORKBENCH_RADIUS

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E:
		_try_workbench_interact()

func _try_workbench_interact() -> void:
	if _active_workbench_ui:
		return
	if not _workbench_node:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var dist: float = player.global_position.distance_to(_workbench_node.global_position)
	if dist > WORKBENCH_RADIUS:
		return
	_open_workbench()

func _open_workbench() -> void:
	var wb_script: GDScript = load("res://scripts/ui/workbench_ui.gd")
	_active_workbench_ui = CanvasLayer.new()
	_active_workbench_ui.set_script(wb_script)
	add_child(_active_workbench_ui)
	_active_workbench_ui.workbench_closed.connect(_close_workbench)

func _close_workbench() -> void:
	if _active_workbench_ui:
		_active_workbench_ui.queue_free()
		_active_workbench_ui = null

func _setup_exits() -> void:
	# Right edge -> County Road (pushed further right to make room for harvest yard)
	ExitHelper.create_exit(self, "right", "res://scenes/world/county_road.tscn",
		"-> County Road", 600.0)

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
