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

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	_apply_seasonal_visuals()
	_check_mailbox_state()
	TimeManager.day_advanced.connect(_on_day_advanced)
	TimeManager.current_scene_id = "county_road"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "County Road"
		SceneManager.show_zone_name()
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
