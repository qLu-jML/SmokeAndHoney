# diner_interior.gd -- The Crossroads Diner interior scene.
# GDD S5.5: Breakfast $7/40E (6-11), Lunch $9/45E (11-15), Dinner $12/50E (15-21),
#   Coffee $2/15E+drain-suppress (all day), Seasonal Special $10/45E+XP buff.
# TV above the counter shows a weather graphic derived from TimeManager forecast.
# NPC encounters: Uncle Bob on Tuesdays, Darlene on Friday mornings.
# Meal periods: once per period per game-day (no double-dipping).
extends Node2D

# -- Menu Data -----------------------------------------------------------------
const MENU_ITEMS: Array = [
	{
		"key":   "coffee",
		"label": "Coffee",
		"cost":  2.0,
		"energy": 15.0,
		"desc":  "+15 energy, suppresses drain 2 hrs",
		"hours": [6.0, 21.0],
		"period": "",          # No per-period restriction on coffee
	},
	{
		"key":   "breakfast",
		"label": "Breakfast",
		"cost":  7.0,
		"energy": 40.0,
		"desc":  "Eggs & toast. +40 energy.",
		"hours": [6.0, 11.0],
		"period": "breakfast",
	},
	{
		"key":   "lunch",
		"label": "Lunch -- Daily Special",
		"cost":  9.0,
		"energy": 45.0,
		"desc":  "Hot plate. +45 energy.",
		"hours": [11.0, 15.0],
		"period": "lunch",
	},
	{
		"key":   "dinner",
		"label": "Dinner",
		"cost":  12.0,
		"energy": 50.0,
		"desc":  "Full plate. +50 energy.",
		"hours": [15.0, 21.0],
		"period": "dinner",
	},
	{
		"key":   "seasonal",
		"label": "Seasonal Special",
		"cost":  10.0,
		"energy": 45.0,
		"desc":  "+45 energy, +5% XP gain today",
		"hours": [6.0, 21.0],
		"period": "seasonal",
	},
]

# -- Scene Nodes (populated in _ready) -----------------------------------------
@onready var tv_node:     Node = $World/DinerFurniture/TVArea/DinerTV
@onready var weather_lbl: Label = $World/DinerFurniture/TVArea/WeatherLabel
@onready var rose_npc:    Node2D = $World/NPCs/RoseWaitress
@onready var menu_ui:     CanvasLayer = $MenuUI
@onready var hint_label:  Label = $World/NPCs/RoseWaitress/InteractHint

const INTERACT_RADIUS := 52.0

# Menu panel nodes (built in code in MenuUI layer)
var _menu_panel:   ColorRect = null
var _menu_open:    bool = false
var _menu_buttons: Array = []

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	TimeManager.current_scene_id = "diner_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Crossroads Diner"
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(-160, -90, 320, 180))
		SceneManager.register_scene_poi(Vector2(0, -40), "Counter", Color(0.7, 0.5, 0.3))
		SceneManager.register_scene_poi(Vector2(0, 80), "Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Cedar Bend")
	_build_menu_ui()
	_update_tv_weather()
	_update_npc_visibility()
	TimeManager.day_advanced.connect(_on_day_advanced)
	print("Crossroads Diner interior loaded.")

func _on_day_advanced(_day: int) -> void:
	_update_tv_weather()
	_update_npc_visibility()

# -- TV Weather Display ---------------------------------------------------------

func _update_tv_weather() -> void:
	if not weather_lbl:
		return
	var season: String = TimeManager.current_season_name()
	var day: int = TimeManager.current_day_of_month()
	# Simple forecast message based on season + day parity
	var forecast: String
	match season:
		"Spring":
			forecast = "SPRING SHOWERS\nHigh 58deg  Low 42deg"
		"Summer":
			forecast = "SUNNY & WARM\nHigh 84deg  Low 67deg"
		"Fall":
			if day % 3 == 0:
				forecast = "CLOUDY, CHANCE RAIN\nHigh 52deg  Low 38deg"
			else:
				forecast = "PARTLY CLOUDY\nHigh 61deg  Low 44deg"
		"Winter":
			if day % 4 == 0:
				forecast = "SNOW POSSIBLE\nHigh 28deg  Low 16deg"
			else:
				forecast = "COLD & CLEAR\nHigh 32deg  Low 18deg"
		_:
			forecast = "FAIR\nHigh 65deg  Low 48deg"
	weather_lbl.text = forecast

# -- NPC Presence --------------------------------------------------------------

func _update_npc_visibility() -> void:
	# Uncle Bob: breakfast at the diner on Tuesdays (day % 7 == 2), 7:00-10:00
	var uncle_bob_node: Node2D = get_node_or_null("World/NPCs/UncleBoB") as Node2D
	if uncle_bob_node:
		var is_tuesday: bool = (TimeManager.current_day % 7) == 2
		var hour: float = TimeManager.current_hour
		uncle_bob_node.visible = is_tuesday and (hour >= 7.0 and hour <= 10.0)

	# Darlene: coffee on Friday mornings (day % 7 == 5), 7:30-9:30
	var darlene_node: Node2D = get_node_or_null("World/NPCs/DarleneGuest") as Node2D
	if darlene_node:
		var is_friday: bool = (TimeManager.current_day % 7) == 5
		var hour2: float = TimeManager.current_hour
		darlene_node.visible = is_friday and (hour2 >= 7.5 and hour2 <= 9.5)

# -- Interaction ---------------------------------------------------------------

func _update_hints() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not rose_npc:
		return
	var dist: float = player.global_position.distance_to(rose_npc.global_position)
	if hint_label:
		hint_label.visible = (dist <= INTERACT_RADIUS) and not _menu_open

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if not _menu_open:
					_try_interact_rose()
			KEY_ESCAPE, KEY_X:
				if _menu_open:
					_close_menu()
			KEY_BACKSPACE:
				_exit_diner()

func _try_interact_rose() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not rose_npc:
		return
	var dist: float = player.global_position.distance_to(rose_npc.global_position)
	if dist <= INTERACT_RADIUS:
		_open_menu()

# -- Menu UI -------------------------------------------------------------------

func _build_menu_ui() -> void:
	if not menu_ui:
		return

	# Dark overlay
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(15)  # full rect
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = 2
	menu_ui.add_child(overlay)

	# Panel -- warm parchment
	_menu_panel = ColorRect.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -160)
	_menu_panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  160)
	_menu_panel.set_anchor_and_offset(SIDE_TOP,    0.5, -140)
	_menu_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  140)
	_menu_panel.color = Color(0.27, 0.18, 0.09, 0.97)
	menu_ui.add_child(_menu_panel)

	# Title
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "The Crossroads Diner"
	title.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	title.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	title.set_anchor_and_offset(SIDE_TOP,    0.5, -133)
	title.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1))
	title.add_theme_font_size_override("font_size", 12)
	menu_ui.add_child(title)

	# Subtitle with hour info
	var sub: Label = Label.new()
	sub.name = "Subtitle"
	sub.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	sub.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	sub.set_anchor_and_offset(SIDE_TOP,    0.5, -113)
	sub.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  -98)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.70, 0.62, 0.45, 1))
	sub.add_theme_font_size_override("font_size", 7)
	sub.name = "SubLabel"
	menu_ui.add_child(sub)

	# Build one button row per menu item
	for i in range(MENU_ITEMS.size()):
		var item: Dictionary = MENU_ITEMS[i]
		var btn: Button = Button.new()
		btn.name = "MenuBtn_" + item["key"]
		# Positioned as rows inside the panel
		btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -148)
		btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  148)
		var row_y = -93 + i * 38
		btn.set_anchor_and_offset(SIDE_TOP,    0.5,  row_y)
		btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  row_y + 32)
		btn.text = "%s  --  $%.0f  (%s)" % [item["label"], item["cost"], item["desc"]]
		btn.add_theme_color_override("font_color", Color(0.88, 0.80, 0.60, 1))
		btn.add_theme_font_size_override("font_size", 7)
		var key: String = item["key"]  # capture for lambda
		btn.pressed.connect(_on_order.bind(key))
		_menu_buttons.append(btn)
		menu_ui.add_child(btn)

	# Close hint
	var close_lbl: Label = Label.new()
	close_lbl.name = "CloseHint"
	close_lbl.text = "[X] or [ESC] to close"
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,  115)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  132)
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.38, 1))
	close_lbl.add_theme_font_size_override("font_size", 6)
	menu_ui.add_child(close_lbl)

	menu_ui.visible = false

func _open_menu() -> void:
	_menu_open = true
	menu_ui.visible = true
	_refresh_menu_state()

func _close_menu() -> void:
	_menu_open = false
	menu_ui.visible = false

func _refresh_menu_state() -> void:
	var hour: float = TimeManager.current_hour
	# Update subtitle
	var sub: Label = menu_ui.get_node_or_null("SubLabel") as Label
	if sub:
		sub.text = "Time: %s  --  Energy: %d/%d  --  Money: $%.0f" % [
			TimeManager.format_time(),
			int(GameData.energy), int(GameData.max_energy),
			GameData.money
		]

	for btn in _menu_buttons:
		if not is_instance_valid(btn):
			continue
		# Find the matching item
		var key_str: String = btn.name.replace("MenuBtn_", "")
		var item_data: Dictionary = {}
		for it in MENU_ITEMS:
			if it["key"] == key_str:
				item_data = it
				break
		if item_data.is_empty():
			continue

		var available: bool = true
		# Time check
		var h_min: float = item_data["hours"][0]
		var h_max: float = item_data["hours"][1]
		if hour < h_min or hour > h_max:
			available = false
		# Meal-period check
		var period: String = item_data["period"]
		if period != "" and GameData.has_eaten_meal(period):
			available = false
			btn.text = item_data["label"] + "  -- Already eaten today"
		else:
			btn.text = "%s  --  $%.0f  (%s)" % [item_data["label"], item_data["cost"], item_data["desc"]]

		btn.disabled = not available
		var col: Color = Color(0.88, 0.80, 0.60, 1) if available else Color(0.50, 0.45, 0.35, 0.6)
		btn.add_theme_color_override("font_color", col)

func _on_order(key: String) -> void:
	var item_data: Dictionary = {}
	for it in MENU_ITEMS:
		if it["key"] == key:
			item_data = it
			break
	if item_data.is_empty():
		return

	var cost: float   = item_data["cost"]
	var energy: float = item_data["energy"]
	var period: String = item_data["period"]

	# Spend money
	if not GameData.spend_money(cost, "Food", item_data["label"]):
		_show_toast("Not enough money!")
		return

	# Restore energy
	GameData.restore_energy(energy)

	# Apply special effects
	if key == "coffee":
		GameData.apply_coffee_buff()
	if key == "seasonal":
		GameData.apply_xp_buff()
		GameData.add_xp(5)   # Small immediate XP for the experience

	# Record meal period
	if period != "":
		GameData.record_meal(period)

	print("[Diner] Ordered %s -- $%.0f, +%.0f energy" % [item_data["label"], cost, energy])
	_show_toast("+%.0f energy" % energy)
	_close_menu()

# -- Toast Notification --------------------------------------------------------

var _toast_timer: float = 0.0
var _toast_label: Label = null

func _show_toast(msg: String) -> void:
	if not _toast_label:
		_toast_label = Label.new()
		_toast_label.add_theme_color_override("font_color", Color(0.90, 0.82, 0.55, 1))
		_toast_label.add_theme_font_size_override("font_size", 9)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.set_anchors_preset(7)  # center top
		_toast_label.set_anchor_and_offset(SIDE_LEFT,   0.5, -100)
		_toast_label.set_anchor_and_offset(SIDE_RIGHT,  0.5,  100)
		_toast_label.set_anchor_and_offset(SIDE_TOP,    0.0,   20)
		_toast_label.set_anchor_and_offset(SIDE_BOTTOM, 0.0,   40)
		menu_ui.add_child(_toast_label)
	_toast_label.text = msg
	_toast_label.visible = true
	_toast_timer = 2.5

func _process_toast(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label:
			_toast_label.visible = false

# override _process to also handle toast
func _process(delta: float) -> void:
	_update_hints()
	_process_toast(delta)

# -- Exit ---------------------------------------------------------------------

func _exit_diner() -> void:
	print("[Diner] Leaving -- returning to Cedar Bend.")
	TimeManager.previous_scene = "res://scenes/world/diner_interior.tscn"
	TimeManager.next_scene     = "res://scenes/world/cedar_bend.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
