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
		"desc":  "+15E, suppresses drain 2 hrs",
		"hours": [6.0, 21.0],
		"period": "",
	},
	{
		"key":   "breakfast",
		"label": "Breakfast",
		"cost":  7.0,
		"energy": 40.0,
		"desc":  "Eggs & toast. +40E",
		"hours": [6.0, 11.0],
		"period": "breakfast",
	},
	{
		"key":   "lunch",
		"label": "Lunch -- Daily Special",
		"cost":  9.0,
		"energy": 45.0,
		"desc":  "Hot plate. +45E",
		"hours": [11.0, 15.0],
		"period": "lunch",
	},
	{
		"key":   "dinner",
		"label": "Dinner",
		"cost":  12.0,
		"energy": 50.0,
		"desc":  "Full plate. +50E",
		"hours": [15.0, 21.0],
		"period": "dinner",
	},
	{
		"key":   "seasonal",
		"label": "Seasonal Special",
		"cost":  10.0,
		"energy": 45.0,
		"desc":  "+45E, +5% XP today",
		"hours": [6.0, 21.0],
		"period": "seasonal",
	},
]

# -- Layout constants ----------------------------------------------------------
const PANEL_W   := 288
const PANEL_H   := 130
const PANEL_X   := 16
const PANEL_Y   := 25
const ROW_H     := 12
const ROWS_TOP  := 28
const FONT_SM   := 7
const FONT_MD   := 8

const C_ACCENT  := Color(0.95, 0.78, 0.32, 1.0)
const C_BG_BTN  := Color(0.22, 0.15, 0.07, 0.97)
const C_BG_HOV  := Color(0.35, 0.24, 0.10, 0.97)
const C_BG_SEL  := Color(0.42, 0.28, 0.08, 1.00)
const C_TEXT    := Color(0.92, 0.85, 0.65, 1.0)
const C_MUTED   := Color(0.45, 0.40, 0.28, 0.55)

# -- Scene Nodes ---------------------------------------------------------------
@onready var tv_node:     Node = $World/DinerFurniture/TVArea/DinerTV
@onready var weather_lbl: Label = $World/DinerFurniture/TVArea/WeatherLabel
@onready var rose_npc:    Node2D = $World/NPCs/RoseWaitress
@onready var menu_ui:     CanvasLayer = $MenuUI
@onready var hint_label:  Label = $World/NPCs/RoseWaitress/InteractHint

const INTERACT_RADIUS := 52.0

# -- Menu state ----------------------------------------------------------------
var _menu_open:    bool = false
var _sel: int      = 0
var _row_btns:     Array = []
var _money_lbl2:   Label  = null
var _err_lbl:      Label  = null
var _btn_order:    Button = null
var _btn_close2:   Button = null
var _err_timer:    float  = 0.0

# Pre-built shared row styleboxes
var _sty_row_normal:  StyleBoxFlat = null
var _sty_row_sel:     StyleBoxFlat = null
var _sty_row_hover_n: StyleBoxFlat = null
var _sty_row_hover_s: StyleBoxFlat = null

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
	var uncle_bob_node: Node2D = get_node_or_null("World/NPCs/UncleBoB") as Node2D
	if uncle_bob_node:
		var is_tuesday: bool = (TimeManager.current_day % 7) == 2
		var hour: float = TimeManager.current_hour
		uncle_bob_node.visible = is_tuesday and (hour >= 7.0 and hour <= 10.0)

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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Menu keyboard navigation
	if _menu_open:
		get_viewport().set_input_as_handled()
		match event.keycode:
			KEY_W:
				_sel = maxi(0, _sel - 1)
			KEY_S:
				_sel = mini(MENU_ITEMS.size() - 1, _sel + 1)
			KEY_E:
				_on_order_selected()
			KEY_ESCAPE, KEY_X:
				_close_menu()
		_refresh_menu_state()
		return

	match event.keycode:
		KEY_E:
			_try_interact_rose()
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

	# Pre-build shared row styleboxes
	_sty_row_normal = StyleBoxFlat.new()
	_sty_row_normal.bg_color = Color(0.14, 0.10, 0.05, 1.0)
	_sty_row_normal.set_border_width_all(0)
	_sty_row_normal.set_content_margin_all(1)

	_sty_row_sel = StyleBoxFlat.new()
	_sty_row_sel.bg_color = C_BG_SEL
	_sty_row_sel.border_color = C_ACCENT
	_sty_row_sel.set_border_width_all(1)
	_sty_row_sel.set_content_margin_all(1)

	_sty_row_hover_n = StyleBoxFlat.new()
	_sty_row_hover_n.bg_color = Color(0.28, 0.20, 0.08, 1.0)
	_sty_row_hover_n.set_border_width_all(0)
	_sty_row_hover_n.set_content_margin_all(1)

	_sty_row_hover_s = StyleBoxFlat.new()
	_sty_row_hover_s.bg_color = C_BG_HOV
	_sty_row_hover_s.border_color = C_ACCENT
	_sty_row_hover_s.set_border_width_all(1)
	_sty_row_hover_s.set_content_margin_all(1)

	# -- Dim backdrop
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_ui.add_child(dim)

	# -- Main panel
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.07, 0.04, 0.97)
	panel.anchor_left = 0; panel.anchor_top = 0
	panel.anchor_right = 0; panel.anchor_bottom = 0
	panel.offset_left   = PANEL_X
	panel.offset_top    = PANEL_Y
	panel.offset_right  = PANEL_X + PANEL_W
	panel.offset_bottom = PANEL_Y + PANEL_H
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	menu_ui.add_child(panel)

	# -- Gold border
	for r in _d_border_rects(PANEL_X, PANEL_Y, PANEL_W, PANEL_H):
		menu_ui.add_child(r)

	# -- Title bar background
	var tbar := ColorRect.new()
	tbar.color = Color(0.28, 0.18, 0.06, 0.90)
	tbar.anchor_left = 0; tbar.anchor_right = 0
	tbar.offset_left   = PANEL_X + 1
	tbar.offset_right  = PANEL_X + PANEL_W - 1
	tbar.offset_top    = PANEL_Y + 1
	tbar.offset_bottom = PANEL_Y + 14
	menu_ui.add_child(tbar)

	_d_label("-- THE CROSSROADS DINER --",
		PANEL_X + 1, PANEL_Y + 2, PANEL_W - 2, 12,
		FONT_MD, Color(0.95, 0.80, 0.30, 1.0), true)

	_d_divider(PANEL_X + 1, PANEL_Y + 14, PANEL_W - 2, C_ACCENT)

	# -- Status line (time / energy / money)
	_money_lbl2 = _d_label("", PANEL_X + 4, PANEL_Y + 15, PANEL_W - 8, 10,
		FONT_SM, Color(0.95, 0.75, 0.20, 1.0), false)

	_d_divider(PANEL_X + 4, PANEL_Y + 26, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Menu item rows (5 items, ROW_H=12)
	for i in MENU_ITEMS.size():
		var ry: int = PANEL_Y + ROWS_TOP + i * ROW_H
		var btn: Button = Button.new()
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", FONT_SM)
		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_stylebox_override("normal", _sty_row_normal)
		btn.add_theme_stylebox_override("hover", _sty_row_hover_n)
		var sb_pr := StyleBoxFlat.new()
		sb_pr.bg_color = Color(0.50, 0.35, 0.10, 1.0)
		sb_pr.set_border_width_all(0)
		sb_pr.set_content_margin_all(1)
		btn.add_theme_stylebox_override("pressed", sb_pr)
		var sb_fo := StyleBoxFlat.new()
		sb_fo.bg_color = Color(0, 0, 0, 0)
		sb_fo.set_border_width_all(0)
		btn.add_theme_stylebox_override("focus", sb_fo)
		btn.anchor_left = 0; btn.anchor_top = 0
		btn.anchor_right = 0; btn.anchor_bottom = 0
		btn.offset_left   = PANEL_X + 4
		btn.offset_top    = ry
		btn.offset_right  = PANEL_X + PANEL_W - 4
		btn.offset_bottom = ry + ROW_H - 1
		btn.z_index = 5
		btn.pressed.connect(_on_row_click.bind(i))
		menu_ui.add_child(btn)
		_row_btns.append(btn)

	var rows_bottom: int = PANEL_Y + ROWS_TOP + MENU_ITEMS.size() * ROW_H

	_d_divider(PANEL_X + 4, rows_bottom, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Control row: [ORDER] [CLOSE]
	var cy: int = rows_bottom + 2

	_btn_order = _d_make_btn("ORDER", PANEL_X + PANEL_W - 146, cy, 68, 13)
	_btn_order.add_theme_font_size_override("font_size", FONT_MD)
	_btn_order.pressed.connect(_on_order_selected)
	menu_ui.add_child(_btn_order)

	_btn_close2 = _d_make_btn("CLOSE", PANEL_X + PANEL_W - 74, cy, 66, 13)
	_btn_close2.add_theme_font_size_override("font_size", FONT_MD)
	_btn_close2.pressed.connect(_close_menu)
	menu_ui.add_child(_btn_close2)

	# -- Keyboard hint
	_d_label("W/S or click to select  E to order  ESC close",
		PANEL_X + 4, rows_bottom + 16, PANEL_W - 8, 6,
		5, Color(0.45, 0.42, 0.32, 0.85), true)

	# -- Error / feedback label
	_err_lbl = _d_label("", PANEL_X + 4, rows_bottom + 22, PANEL_W - 8, 8,
		FONT_SM, Color(0.95, 0.50, 0.30, 1.0), true)

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

	# Update status line
	if _money_lbl2:
		_money_lbl2.text = "Time: %s   Energy: %d/%d   Balance: $%.0f" % [
			TimeManager.format_time(),
			int(GameData.energy), int(GameData.max_energy),
			GameData.money
		]

	for i in _row_btns.size():
		var btn: Button = _row_btns[i]
		if not is_instance_valid(btn):
			continue
		var item_data: Dictionary = MENU_ITEMS[i]
		var is_sel: bool = (i == _sel)

		var available: bool = true

		# Time check
		var h_min: float = item_data["hours"][0]
		var h_max: float = item_data["hours"][1]
		if hour < h_min or hour > h_max:
			available = false

		# Meal-period check
		var period: String = item_data["period"]
		var already_eaten: bool = (period != "" and GameData.has_eaten_meal(period))
		if already_eaten:
			available = false

		# Build row text
		var name_s: String = item_data["label"]
		while name_s.length() < 22:
			name_s += " "
		name_s = name_s.substr(0, 22)

		if already_eaten:
			btn.text = "%s -- Already eaten" % name_s
		elif not available:
			btn.text = "%s -- Not served now" % name_s
		else:
			btn.text = "%s $%.0f  (%s)" % [name_s, item_data["cost"], item_data["desc"]]

		btn.disabled = not available

		# Swap pre-built styleboxes
		if is_sel and available:
			btn.add_theme_stylebox_override("normal", _sty_row_sel)
			btn.add_theme_stylebox_override("hover", _sty_row_hover_s)
			btn.add_theme_color_override("font_color", C_ACCENT)
		elif available:
			btn.add_theme_stylebox_override("normal", _sty_row_normal)
			btn.add_theme_stylebox_override("hover", _sty_row_hover_n)
			btn.add_theme_color_override("font_color", C_TEXT)
		else:
			btn.add_theme_stylebox_override("normal", _sty_row_normal)
			btn.add_theme_stylebox_override("hover", _sty_row_normal)
			btn.add_theme_color_override("font_color", C_MUTED)

	if _btn_order:
		# Disable ORDER if selected item is unavailable
		var sel_item: Dictionary = MENU_ITEMS[_sel]
		var sel_avail: bool = true
		var sh_min: float = sel_item["hours"][0]
		var sh_max: float = sel_item["hours"][1]
		if hour < sh_min or hour > sh_max:
			sel_avail = false
		var sp: String = sel_item["period"]
		if sp != "" and GameData.has_eaten_meal(sp):
			sel_avail = false
		if GameData.money < sel_item["cost"]:
			sel_avail = false
		_btn_order.disabled = not sel_avail

# -- Row callbacks -------------------------------------------------------------

func _on_row_click(idx: int) -> void:
	_sel = idx
	_refresh_menu_state()

# -- Order logic ---------------------------------------------------------------

func _on_order_selected() -> void:
	var item_data: Dictionary = MENU_ITEMS[_sel]
	var cost: float   = item_data["cost"]
	var energy: float = item_data["energy"]
	var period: String = item_data["period"]

	if not GameData.spend_money(cost, "Food", item_data["label"]):
		_show_err("Not enough money!")
		return

	GameData.restore_energy(energy)

	if item_data["key"] == "coffee":
		GameData.apply_coffee_buff()
	if item_data["key"] == "seasonal":
		GameData.apply_xp_buff()
		GameData.add_xp(5)

	if period != "":
		GameData.record_meal(period)

	print("[Diner] Ordered %s -- $%.0f, +%.0f energy" % [item_data["label"], cost, energy])
	_show_err("+%.0f energy" % energy)
	_close_menu()

func _show_err(msg: String) -> void:
	if _err_lbl:
		_err_lbl.text = msg
		_err_timer = 2.5

# override _process to handle hints and error timer
func _process(delta: float) -> void:
	_update_hints()
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0 and _err_lbl:
			_err_lbl.visible = false

# -- Exit ---------------------------------------------------------------------

func _exit_diner() -> void:
	print("[Diner] Leaving -- returning to Cedar Bend.")
	TimeManager.previous_scene = "res://scenes/world/diner_interior.tscn"
	TimeManager.next_scene     = "res://scenes/world/cedar_bend.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

# -- Menu UI widget helpers (prefixed _d_ to separate from scene logic) --------

func _d_label(text_val: String, x: int, y: int, w: int, h: int,
		fsize: int, col: Color, centred: bool) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0; l.anchor_top = 0
	l.anchor_right = 0; l.anchor_bottom = 0
	l.offset_left = x; l.offset_top = y
	l.offset_right = x + w; l.offset_bottom = y + h
	l.z_index = 5
	menu_ui.add_child(l)
	return l

func _d_divider(x: int, y: int, w: int, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.anchor_left = 0; d.anchor_right = 0
	d.offset_left = x; d.offset_right = x + w
	d.offset_top = y; d.offset_bottom = y + 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_ui.add_child(d)

func _d_border_rects(x: int, y: int, w: int, h: int) -> Array:
	var rects: Array = []
	for coords in [
		[x,         y,         w, 1],
		[x,         y + h - 1, w, 1],
		[x,         y,         1, h],
		[x + w - 1, y,         1, h],
	]:
		var r := ColorRect.new()
		r.color = C_ACCENT
		r.anchor_left = 0; r.anchor_right = 0
		r.offset_left   = coords[0]; r.offset_top    = coords[1]
		r.offset_right  = coords[0] + coords[2]
		r.offset_bottom = coords[1] + coords[3]
		r.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		rects.append(r)
	return rects

func _d_make_btn(label_text: String, x: int, y: int, w: int, h: int) -> Button:
	var btn := Button.new()
	btn.text       = label_text
	btn.clip_text  = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", FONT_SM)
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_ACCENT)
	btn.add_theme_color_override("font_pressed_color",  Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", C_MUTED)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		if state_name == "normal":
			sb.bg_color = C_BG_BTN
		elif state_name == "hover":
			sb.bg_color = C_BG_HOV
		elif state_name == "pressed":
			sb.bg_color = Color(0.12, 0.08, 0.03, 0.97)
		elif state_name == "disabled":
			sb.bg_color = Color(0.14, 0.09, 0.04, 0.55)
		else:
			sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = C_ACCENT
		sb.set_border_width_all(1)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state_name, sb)
	btn.anchor_left = 0; btn.anchor_top = 0
	btn.anchor_right = 0; btn.anchor_bottom = 0
	btn.offset_left = x; btn.offset_top = y
	btn.offset_right = x + w; btn.offset_bottom = y + h
	btn.z_index = 10
	return btn
