# county_road.gd -- The transitional corridor between home property and town.
# GDD S13.2: The county road is where the map navigation interface lives.
# Scene features: gravel road, player's truck, mailbox with flag, ditch grass,
#   background fields (Harmon farm), seasonal overlays, and map overlay trigger.
extends Node2D

# -- Node References ------------------------------------------------------------
@onready var truck_sprite:    Sprite2D = $World/Props/Truck
@onready var mailbox_sprite:  Sprite2D = $World/Props/Mailbox
@onready var seasonal_layer:  CanvasLayer = $SeasonalLayer
@onready var map_overlay:     CanvasLayer = $MapOverlay

# Interaction radius for truck / mailbox
const INTERACT_RADIUS := 56.0

# Whether the map is currently open
var _map_open: bool = false

# Pending orders flag (driven by GameData pending deliveries)
var _mailbox_has_mail: bool = false

# -- Harvestable Trees (woodlot along the roadside) --------------------------
var _harvestable_trees: Array = []
var _active_chopping_minigame: CanvasLayer = null

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	_setup_weather()
	_apply_seasonal_visuals()
	_check_mailbox_state()
	_spawn_harvestable_trees()
	TimeManager.day_advanced.connect(_on_day_advanced)
	TimeManager.current_scene_id = "county_road"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "County Road"
		SceneManager.show_zone_name()
		_register_map_markers()
	_setup_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("County Road scene loaded -- Phase 4 build.")

func _setup_exits() -> void:
	# Left edge -> Home Property
	ExitHelper.create_exit(self, "left", "res://scenes/home_property.tscn",
		"<- Home")
	# Right edge -> Cedar Bend (town)
	ExitHelper.create_exit(self, "right", "res://scenes/world/cedar_bend.tscn",
		"-> Cedar Bend")
	# Bottom edge -> Harmon Farm
	ExitHelper.create_exit(self, "bottom", "res://scenes/world/harmon_farm.tscn",
		"v Harmon Farm")
	# Top edge -> Timber Creek
	ExitHelper.create_exit(self, "top", "res://scenes/world/timber_creek.tscn",
		"^ Timber Creek")

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	# Fixed bounds: exits at x+/-330, y+/-100, with padding
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# POIs
	if truck_sprite:
		SceneManager.register_scene_poi(truck_sprite.position, "Truck", Color(0.6, 0.55, 0.45))
	if mailbox_sprite:
		SceneManager.register_scene_poi(mailbox_sprite.position, "Mailbox", Color(0.7, 0.3, 0.2))
	# Exits
	SceneManager.register_scene_exit("left", "Home")
	SceneManager.register_scene_exit("right", "Cedar Bend")
	SceneManager.register_scene_exit("bottom", "Harmon Farm")
	SceneManager.register_scene_exit("top", "Timber Creek")

func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()
	_check_mailbox_state()

# -- Seasonal Visuals -----------------------------------------------------------

func _apply_seasonal_visuals() -> void:
	if not seasonal_layer:
		return
	var season := TimeManager.current_season_name()
	# Tint the seasonal overlay canvas layer based on season
	match season:
		"Spring":
			seasonal_layer.visible = true
			# Soft greenish morning tint
			# (handled via CanvasLayer modulate -- set from code)
		"Summer":
			seasonal_layer.visible = false
		"Fall":
			seasonal_layer.visible = true
		"Winter":
			seasonal_layer.visible = true
	_update_field_sprite(season)

func _update_field_sprite(season: String) -> void:
	# The Harmon farm background sprite swaps based on season and crop
	var field_node := get_node_or_null("World/Background/HarmonField")
	if not field_node:
		return
	var year := TimeManager.current_year()
	# Simple crop rotation: odd years = corn, even = soy
	var crop: String = "corn" if year % 2 == 1 else "soy"
	@warning_ignore("unused_variable")
	var sprite_key := "field_%s_%s" % [crop, season.to_lower()]
	# Fallback: use modulate to suggest season change
	match season:
		"Spring":
			field_node.modulate = Color(0.85, 0.92, 0.78, 1.0)   # pale green spring
		"Summer":
			field_node.modulate = Color(0.82, 0.90, 0.70, 1.0)   # rich summer green
		"Fall":
			field_node.modulate = Color(0.95, 0.80, 0.50, 1.0)   # golden fall
		"Winter":
			field_node.modulate = Color(0.88, 0.92, 0.95, 1.0)   # cold desaturated

# -- Mailbox State --------------------------------------------------------------

func _check_mailbox_state() -> void:
	# Flag is UP when player has pending deliveries in GameData
	var has_pending: bool = _has_pending_deliveries()
	_mailbox_has_mail = has_pending
	_update_mailbox_sprite()

func _has_pending_deliveries() -> bool:
	# Check GameData for pending deliveries (bee packages, supply orders, etc.)
	# This integrates with any pending_orders array you add to GameData in Phase 5+.
	if "pending_deliveries" in GameData and GameData.pending_deliveries.size() > 0:
		return true
	return false

func _update_mailbox_sprite() -> void:
	if not mailbox_sprite:
		return
	var flag_up_path := "res://assets/sprites/world/mailbox_flag_up.png"
	var flag_dn_path := "res://assets/sprites/world/mailbox_flag_down.png"
	if _mailbox_has_mail and ResourceLoader.exists(flag_up_path):
		mailbox_sprite.texture = load(flag_up_path)
	elif ResourceLoader.exists(flag_dn_path):
		mailbox_sprite.texture = load(flag_dn_path)

# -- Input ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_try_interact()

# -- Interaction ----------------------------------------------------------------

func _try_interact() -> void:
	if _active_chopping_minigame:
		return  # Block interaction while chopping
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	# Check truck proximity -- opens map
	if truck_sprite:
		var dist := player.global_position.distance_to(truck_sprite.global_position)
		if dist <= INTERACT_RADIUS:
			_toggle_map()
			return

	# Check mailbox proximity -- collect pending deliveries
	if mailbox_sprite:
		var dist := player.global_position.distance_to(mailbox_sprite.global_position)
		if dist <= INTERACT_RADIUS:
			_interact_mailbox()
			return

	# Check harvestable trees -- chop for logs
	_try_chop_nearest_tree()

func _toggle_map() -> void:
	if _map_open:
		_close_map()
	else:
		_open_map()

func _open_map() -> void:
	if not map_overlay:
		push_error("MapOverlay node not found in CountyRoad scene.")
		return
	_map_open = true
	map_overlay.open()

func _close_map() -> void:
	_map_open = false
	if map_overlay:
		map_overlay.close()

func _interact_mailbox() -> void:
	if not _mailbox_has_mail:
		print("[Mailbox] Nothing waiting today.")
		return

	# Collect deliveries from GameData
	if "pending_deliveries" in GameData and GameData.pending_deliveries.size() > 0:
		var player := get_tree().get_first_node_in_group("player")
		for delivery in GameData.pending_deliveries:
			if player and player.has_method("add_item"):
				player.add_item(delivery["item"], delivery["count"])
			print("[Mailbox] Received: %d x %s" % [delivery["count"], delivery["item"]])
		GameData.pending_deliveries.clear()
		_mailbox_has_mail = false
		_update_mailbox_sprite()
		print("[Mailbox] All deliveries collected!")
	else:
		print("[Mailbox] No pending deliveries.")

# -- Harvestable Tree Spawning ------------------------------------------------

func _spawn_harvestable_trees() -> void:
	# 8 trees along the right-side tree line of the county road.
	# Spread along the top portion so they don't block road or exits.
	var tree_script: GDScript = load("res://scripts/world/harvestable_tree.gd")
	var tree_data: Array = [
		{"id": "county_oak_1",    "label": "Oak",     "pos": Vector2(200, -120)},
		{"id": "county_oak_2",    "label": "Oak",     "pos": Vector2(340, -140)},
		{"id": "county_maple_1",  "label": "Maple",   "pos": Vector2(480, -110)},
		{"id": "county_ash_1",    "label": "Ash",     "pos": Vector2(-100, -130)},
		{"id": "county_ash_2",    "label": "Ash",     "pos": Vector2(50, -115)},
		{"id": "county_walnut_1", "label": "Walnut",  "pos": Vector2(620, -125)},
		{"id": "county_elm_1",    "label": "Elm",     "pos": Vector2(-250, -135)},
		{"id": "county_hickory_1","label": "Hickory", "pos": Vector2(150, -145)},
	]
	var world_node: Node = get_node_or_null("World")
	if not world_node:
		world_node = self
	for td in tree_data:
		var tree_node := Node2D.new()
		tree_node.set_script(tree_script)
		tree_node.tree_id = td["id"]
		tree_node.tree_label = td["label"]
		tree_node.position = td["pos"]
		world_node.add_child(tree_node)
		_harvestable_trees.append(tree_node)

func _process(_delta: float) -> void:
	if _active_chopping_minigame:
		return  # Don't update hints while minigame is active
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	for tree in _harvestable_trees:
		if tree and tree.has_method("update_hint_visibility"):
			tree.update_hint_visibility(player.global_position)

# -- Chopping Interaction -----------------------------------------------------

func _try_chop_nearest_tree() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	# Check axe in inventory
	if player.has_method("get_item_count"):
		if player.get_item_count(GameData.ITEM_AXE) <= 0:
			print("[County Road] You need an axe to chop trees. Buy one at the shop.")
			return
	# Check energy
	if GameData.energy < 15.0:
		print("[County Road] Too tired to chop trees.")
		return
	# Find nearest choppable tree in range
	var best_tree: Node2D = null
	var best_dist: float = 9999.0
	for tree in _harvestable_trees:
		if not tree or not tree.has_method("is_choppable"):
			continue
		if not tree.is_choppable():
			continue
		if not tree.is_player_in_range(player.global_position):
			continue
		var d: float = player.global_position.distance_to(tree.global_position)
		if d < best_dist:
			best_dist = d
			best_tree = tree
	if best_tree == null:
		return  # No tree in range
	_start_chopping(best_tree)

func _start_chopping(tree_node: Node2D) -> void:
	var mg_script: GDScript = load("res://scripts/ui/chopping_minigame.gd")
	_active_chopping_minigame = CanvasLayer.new()
	_active_chopping_minigame.set_script(mg_script)
	add_child(_active_chopping_minigame)

	_active_chopping_minigame.chopping_complete.connect(
		func(logs: int) -> void:
			_on_chopping_complete(tree_node, logs))
	_active_chopping_minigame.chopping_cancelled.connect(_on_chopping_cancelled)

func _on_chopping_complete(tree_node: Node2D, logs: int) -> void:
	# Mark tree as chopped (regrows after TREE_REGROW_DAYS)
	if tree_node and tree_node.has_method("mark_chopped"):
		tree_node.mark_chopped()
	# Give player logs
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("add_item"):
		var leftover: int = player.add_item(GameData.ITEM_LOGS, logs)
		if leftover > 0:
			print("[County Road] Inventory full! %d logs lost." % leftover)
	print("[County Road] Chopped tree -- earned %d logs." % logs)
	_cleanup_chopping_minigame()

func _on_chopping_cancelled() -> void:
	print("[County Road] Chopping cancelled.")
	_cleanup_chopping_minigame()

func _cleanup_chopping_minigame() -> void:
	if _active_chopping_minigame:
		_active_chopping_minigame.queue_free()
		_active_chopping_minigame = null

# -- Weather Setup -----------------------------------------------------------

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
