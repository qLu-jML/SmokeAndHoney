# cedar_bend.gd -- Main street of Cedar Bend, Iowa.
# GDD S13.3: Cedar Bend is a single main street view navigated by walking.
# Phase 4: Full scene shell -- 5 interactive building facades, ambient pedestrians,
#   seasonal overlays, Saturday Market overlay, and building E-triggers.
extends Node2D

# -- Scene State ----------------------------------------------------------------
@warning_ignore("unused_private_class_variable")
var _current_scene_path: String = ""

# Building door triggers (populated in _ready from child nodes)
var _building_triggers: Dictionary = {}  # { node_name: scene_path }

# -- Pedestrian System ----------------------------------------------------------
var _pedestrians: Array = []
const PEDESTRIAN_SPEED := 25.0
const PEDESTRIAN_SPAWN_INTERVAL := 18.0
var _ped_timer: float = 0.0

# -- Saturday Market ------------------------------------------------------------
var _market_overlay_active: bool = false

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	_setup_weather()
	_setup_building_triggers()
	_apply_seasonal_visuals()
	_check_saturday_market()
	_spawn_initial_pedestrians()
	TimeManager.day_advanced.connect(_on_day_advanced)
	TimeManager.current_scene_id = "cedar_bend"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Cedar Bend"
		SceneManager.show_zone_name()
		_register_map_markers()
	_setup_zone_exits()
	ExitHelper.position_player_from_spawn_side(self)
	print("Cedar Bend scene loaded -- Phase 4 build.")

func _setup_zone_exits() -> void:
	# Left edge -> County Road
	ExitHelper.create_exit(self, "left", "res://scenes/world/county_road.tscn",
		"<- County Road")
	# Right edge -> Community Garden
	ExitHelper.create_exit(self, "right", "res://scenes/world/community_garden.tscn",
		"-> Garden")
	# Bottom edge -> Fairgrounds
	ExitHelper.create_exit(self, "bottom", "res://scenes/world/fairgrounds.tscn",
		"v Fairgrounds")

func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(Rect2(-800, -300, 1600, 600))
	# Buildings as POIs
	var buildings: Node = get_node_or_null("World/Buildings")
	if buildings:
		for bname in ["CrossroadsDiner", "FeedSupply", "PostOffice", "GrangeHall"]:
			var b: Node2D = buildings.get_node_or_null(bname) as Node2D
			if b:
				var lbl: String = bname
				match bname:
					"CrossroadsDiner": lbl = "Diner"
					"FeedSupply": lbl = "Feed & Supply"
					"PostOffice": lbl = "Post Office"
					"GrangeHall": lbl = "Grange Hall"
				SceneManager.register_scene_poi(b.position, lbl, Color(0.8, 0.6, 0.3))
	# Exits
	SceneManager.register_scene_exit("left", "County Road")
	SceneManager.register_scene_exit("right", "Garden")
	SceneManager.register_scene_exit("bottom", "Fairgrounds")

func _on_day_advanced(_day: int) -> void:
	_apply_seasonal_visuals()
	_check_saturday_market()

# -- Building Triggers ----------------------------------------------------------

func _setup_building_triggers() -> void:
	_building_triggers = {
		"CrossroadsDiner":    "res://scenes/world/diner_interior.tscn",
		"FeedSupply":         "res://scenes/world/feed_supply_interior.tscn",
		"PostOffice":         "res://scenes/world/post_office_interior.tscn",
		"GrangeHall":         "",   # Only open on meeting nights -- handled specially
		"SaturdayMarket":     "",   # Overlay, not a sub-scene
	}
	# Create Area2D door zones on each building for collision-based entry.
	# The player walks into the door area to enter the building.
	for bname in _building_triggers.keys():
		if bname == "SaturdayMarket":
			continue  # Market is an overlay, not a building with a door
		var bnode: Node2D = get_node_or_null("World/Buildings/" + bname) as Node2D
		if not bnode:
			continue
		if bnode.get_node_or_null("DoorZone"):
			continue
		var area: Area2D = Area2D.new()
		area.name = "DoorZone"
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitoring = true
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(30, 14)
		shape.shape = rect
		# Door is at bottom-center of building sprite
		shape.position = Vector2(0, 80)
		area.add_child(shape)
		bnode.add_child(area)
		area.body_entered.connect(_on_door_entered.bind(bname))
		print("[Cedar Bend] Created door zone for %s" % bname)

func _process(delta: float) -> void:
	_update_market_hint()
	_update_pedestrians(delta)
	_ped_timer += delta
	if _ped_timer >= PEDESTRIAN_SPAWN_INTERVAL:
		_ped_timer = 0.0
		_maybe_spawn_pedestrian()

# -- Door Collision Entry -------------------------------------------------------

func _on_door_entered(body: Node2D, building_name: String) -> void:
	if body.name != "player":
		return

	# Special cases first
	if building_name == "GrangeHall":
		_try_enter_grange()
		return

	var target_scene: String = _building_triggers.get(building_name, "")
	if target_scene == "":
		print("[Cedar Bend] %s -- coming soon!" % building_name)
		return

	# Energy check: entering buildings costs 2 energy
	if not GameData.deduct_energy(2.0):
		print("[Cedar Bend] Too tired to go in.")
		return

	print("[Cedar Bend] Entering %s ..." % building_name)
	TimeManager.previous_scene = "res://scenes/world/cedar_bend.tscn"
	TimeManager.next_scene = target_scene
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

func _try_enter_grange() -> void:
	# Grange Hall is only open on meeting night -- once per in-game month (day 14 or 15)
	var day_of_month: int = TimeManager.current_day_of_month()
	if day_of_month == 14 or day_of_month == 15:
		var hour: float = TimeManager.current_hour
		if hour >= 18.0 and hour <= 22.0:
			print("[Cedar Bend] Grange Hall meeting tonight -- entering...")
			TimeManager.previous_scene = "res://scenes/world/cedar_bend.tscn"
			TimeManager.next_scene = "res://scenes/world/grange_interior.tscn"
			get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
			return
	print("[Cedar Bend] Grange Hall: meeting on the 14th at 6pm. Check the marquee sign.")

# -- Seasonal Visuals -----------------------------------------------------------

func _apply_seasonal_visuals() -> void:
	var season: String = TimeManager.current_season_name()
	var seasonal_layer: CanvasLayer = get_node_or_null("SeasonalLayer") as CanvasLayer
	if seasonal_layer:
		seasonal_layer.visible = (season != "Summer")

	# Update street modulate
	var street: Node2D = get_node_or_null("World/Street") as Node2D
	if street:
		match season:
			"Spring":
				street.modulate = Color(0.96, 0.94, 0.90, 1.0)
			"Summer":
				street.modulate = Color(1.0, 1.0, 1.0, 1.0)
			"Fall":
				street.modulate = Color(0.98, 0.92, 0.82, 1.0)
			"Winter":
				street.modulate = Color(0.92, 0.95, 1.0, 1.0)

	# Diner window light: brighter during open hours
	var diner_glow: CanvasItem = get_node_or_null("World/Buildings/CrossroadsDiner/WindowGlow") as CanvasItem
	if diner_glow:
		var hour: float = TimeManager.current_hour
		diner_glow.visible = (hour >= 6.0 and hour <= 21.0)

# -- Saturday Market ------------------------------------------------------------

const MARKET_INTERACT_RADIUS := 48.0

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E and _market_overlay_active:
		_try_market_interact()

func _update_market_hint() -> void:
	var hint: Label = get_node_or_null("World/SaturdayMarket/FrankNPC/MarketInteractHint") as Label
	if not hint:
		return
	if not _market_overlay_active:
		hint.visible = false
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		hint.visible = false
		return
	var frank: Node2D = get_node_or_null("World/SaturdayMarket/FrankNPC") as Node2D
	if not frank:
		hint.visible = false
		return
	var dist: float = player.global_position.distance_to(frank.global_position)
	hint.visible = dist <= MARKET_INTERACT_RADIUS

func _try_market_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var frank: Node2D = get_node_or_null("World/SaturdayMarket/FrankNPC") as Node2D
	if not frank or not frank.visible:
		return
	var dist: float = player.global_position.distance_to(frank.global_position)
	if dist > MARKET_INTERACT_RADIUS:
		return
	_open_market_sell()

func _open_market_sell() -> void:
	var scene: PackedScene = load("res://scenes/ui/sell_screen.tscn") as PackedScene
	if scene == null:
		push_error("[Cedar Bend] Failed to load sell_screen.tscn")
		return
	var sell_ui: Node = scene.instantiate()
	# Apply standing price multiplier (GDD S9)
	var base_price: int = 10
	var mult: float = GameData.get_standing_price_mult()
	var adjusted_price: int = int(float(base_price) * mult)
	sell_ui.price_per_jar = adjusted_price
	sell_ui.buyer_name = "Frank"
	get_tree().root.add_child(sell_ui)

func _check_saturday_market() -> void:
	# GDD S13.3: Saturday Market overlay active on spring-fall Saturdays
	var is_saturday: bool = _is_saturday()
	var season: String = TimeManager.current_season_name()
	var market_season: bool = (season != "Winter")
	var should_show: bool = is_saturday and market_season

	var market_node: Node2D = get_node_or_null("World/SaturdayMarket") as Node2D
	if market_node:
		market_node.visible = should_show
	_market_overlay_active = should_show

func _is_saturday() -> bool:
	# Day-of-week from current_day. 7-day week; day 1 of year = Sunday.
	var day: int = TimeManager.current_day
	return (day % 7) == 6  # 0=Sun, 1=Mon ... 6=Sat

# -- Ambient Pedestrians --------------------------------------------------------
# GDD S13.3: "A handful of townspeople walk the sidewalk at various times."

const PED_SPRITES = [
	"res://assets/sprites/npc/pedestrian_a.png",
	"res://assets/sprites/npc/pedestrian_b.png",
	"res://assets/sprites/npc/pedestrian_c.png",
	"res://assets/sprites/npc/pedestrian_d.png",
	"res://assets/sprites/npc/pedestrian_e.png",
	"res://assets/sprites/npc/pedestrian_f.png",
]
const PED_WAYPOINTS = [
	Vector2(-560, 70),
	Vector2(-320, 70),
	Vector2(-100, 70),
	Vector2(100, 70),
	Vector2(340, 70),
	Vector2(520, 70),
]
const MAX_PEDESTRIANS := 4

func _spawn_initial_pedestrians() -> void:
	var hour: float = TimeManager.current_hour
	# Pedestrians only between 7:00 and 20:00
	if hour < 7.0 or hour > 20.0:
		return
	var count: int = 2 if hour >= 11.0 and hour <= 14.0 else 1
	for i in range(count):
		_spawn_pedestrian()

func _maybe_spawn_pedestrian() -> void:
	if _pedestrians.size() >= MAX_PEDESTRIANS:
		return
	var hour: float = TimeManager.current_hour
	if hour < 7.0 or hour > 20.0:
		return
	if randf() < 0.4:
		_spawn_pedestrian()

func _spawn_pedestrian() -> void:
	var ped_root: Node2D = get_node_or_null("World/Pedestrians") as Node2D
	if not ped_root:
		return

	var spr: Sprite2D = Sprite2D.new()
	var tex_path: String = PED_SPRITES[randi() % PED_SPRITES.size()]
	if ResourceLoader.exists(tex_path):
		spr.texture = load(tex_path)
	else:
		# Fallback: colored rect
		var fb_img: Image = Image.create(64, 80, false, Image.FORMAT_RGBA8)
		fb_img.fill(Color(0.5, 0.4, 0.3, 1.0))
		spr.texture = ImageTexture.create_from_image(fb_img)

	# Random start position off-screen left or right
	var start_x: float = -700.0 if randf() < 0.5 else 700.0
	spr.position = Vector2(start_x, 70.0 + randf_range(-8.0, 8.0))
	spr.z_index = 2

	# Pick random target waypoint
	var target_wp: Vector2 = PED_WAYPOINTS[randi() % PED_WAYPOINTS.size()]
	spr.set_meta("target", target_wp)
	spr.set_meta("speed", PEDESTRIAN_SPEED * randf_range(0.7, 1.3))

	ped_root.add_child(spr)
	_pedestrians.append(spr)

func _update_pedestrians(delta: float) -> void:
	var to_remove: Array = []
	for ped in _pedestrians:
		if not is_instance_valid(ped):
			to_remove.append(ped)
			continue
		var target: Vector2 = ped.get_meta("target", Vector2.ZERO)
		var speed: float = ped.get_meta("speed", PEDESTRIAN_SPEED)
		var dir: Vector2 = (target - ped.position)
		var dist: float = dir.length()
		if dist < 4.0:
			# Reached waypoint -- pick new one or despawn
			if randf() < 0.3:
				# Despawn off-screen
				ped.queue_free()
				to_remove.append(ped)
			else:
				var new_wp: Vector2 = PED_WAYPOINTS[randi() % PED_WAYPOINTS.size()]
				ped.set_meta("target", new_wp)
		else:
			ped.position += dir.normalized() * speed * delta
			# Flip sprite based on direction
			if dir.x < 0:
				ped.flip_h = true
			else:
				ped.flip_h = false

	for dead in to_remove:
		_pedestrians.erase(dead)

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
