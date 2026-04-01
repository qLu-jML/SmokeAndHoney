# feed_supply_interior.gd -- Tanner's Feed & Supply interior.
# GDD S13.3: Shop with seasonal stock, bulletin board, Carl Tanner NPC.
# Sells bee packages, frames, supers, treatments, and equipment.
# Seasonal stock: Spring = packages/seeds/feeders, Summer = treatments/supers,
#   Fall = winter prep supplies, Winter = reduced stock.
extends Node2D

# -- Shop Catalog --------------------------------------------------------------
# Each item: key, label, cost, seasons (empty = always), item_constant, count
const ALL_ITEMS: Array = [
	# Core equipment -- always in stock
	{
		"key": "frames",
		"label": "Frames (set of 10)",
		"cost": 24.0,
		"item": "frames",
		"qty": 10,
		"seasons": [],
		"max_qty": 5,
		"desc": "Standard Langstroth deep frames.",
	},
	{
		"key": "super_box",
		"label": "Honey Super (empty)",
		"cost": 35.0,
		"item": "super_box",
		"qty": 1,
		"seasons": [],
		"max_qty": 5,
		"desc": "Medium super box, 10-frame.",
	},
	{
		"key": "repair_kit",
		"label": "Repair Kit",
		"cost": 25.0,
		"item": "",
		"qty": 0,
		"seasons": [],
		"max_qty": 3,
		"desc": "+20 hive condition.",
		"special": "repair_kit",
	},
	{
		"key": "jars",
		"label": "Honey Jars (case of 12)",
		"cost": 14.0,
		"item": "jar",
		"qty": 12,
		"seasons": [],
		"max_qty": 10,
		"desc": "Half-pint glass jars.",
	},
	# Spring stock
	{
		"key": "bee_package",
		"label": "Bee Package (3 lb + queen)",
		"cost": 185.0,
		"item": "queen_cage",
		"qty": 1,
		"seasons": ["Spring"],
		"max_qty": 2,
		"desc": "Local stock, better queen grades.",
	},
	{
		"key": "nucleus",
		"label": "Nucleus Colony (5-frame nuc)",
		"cost": 245.0,
		"item": "beehive",
		"qty": 1,
		"seasons": ["Spring"],
		"max_qty": 2,
		"desc": "Established colony. Faster start.",
	},
	{
		"key": "syrup_feeder",
		"label": "Hive-Top Feeder",
		"cost": 12.0,
		"item": "syrup_feeder",
		"qty": 1,
		"seasons": ["Spring", "Fall"],
		"max_qty": 5,
		"desc": "For sugar syrup feeding.",
	},
	{
		"key": "swarm_trap",
		"label": "Swarm Trap",
		"cost": 28.0,
		"item": "swarm_trap",
		"qty": 1,
		"seasons": ["Spring", "Summer"],
		"max_qty": 3,
		"desc": "Catch swarms near apiary.",
	},
	# Summer / treatment stock
	{
		"key": "oxalic",
		"label": "Oxalic Acid Treatment",
		"cost": 18.0,
		"item": "treatment_oxalic",
		"qty": 1,
		"seasons": ["Summer", "Fall", "Winter"],
		"max_qty": 5,
		"desc": "High-efficacy mite treatment.",
	},
	{
		"key": "formic",
		"label": "Formic Acid Pads",
		"cost": 22.0,
		"item": "treatment_formic",
		"qty": 1,
		"seasons": ["Summer", "Fall"],
		"max_qty": 5,
		"desc": "Penetrates capped brood.",
	},
	# Fall / winter prep
	{
		"key": "queen_cage",
		"label": "Mated Queen",
		"cost": 38.0,
		"item": "queen_cage",
		"qty": 1,
		"seasons": ["Spring", "Summer"],
		"max_qty": 2,
		"desc": "Candy-plug cage. 3-5 day acceptance.",
	},
]

# -- Layout constants ----------------------------------------------------------
const PANEL_W   := 288
const PANEL_H   := 178
const PANEL_X   := 16
const PANEL_Y   := 2
const ROW_H     := 10
const ROWS_TOP  := 26
const FONT_SM   := 7
const FONT_MD   := 8

const C_ACCENT  := Color(0.95, 0.78, 0.32, 1.0)
const C_BG_BTN  := Color(0.22, 0.15, 0.07, 0.97)
const C_BG_HOV  := Color(0.35, 0.24, 0.10, 0.97)
const C_BG_SEL  := Color(0.42, 0.28, 0.08, 1.00)
const C_TEXT    := Color(0.92, 0.85, 0.65, 1.0)
const C_MUTED   := Color(0.45, 0.40, 0.28, 0.55)

const INTERACT_RADIUS := 52.0
const BULLETIN_RADIUS := 48.0

@onready var carl_npc:       Node2D = $World/NPCs/CarlTanner
@onready var bulletin_board: Node2D = $World/Props/BulletinBoard
@onready var shop_ui:        CanvasLayer = $ShopUI
@onready var bulletin_ui:    CanvasLayer = $BulletinUI
@onready var shop_hint:      Label  = $World/NPCs/CarlTanner/InteractHint
@onready var board_hint:     Label  = $World/Props/BulletinBoard/InteractHint

var _shop_open:     bool = false
var _bulletin_open: bool = false

# -- Shop state ----------------------------------------------------------------
var _sel: int    = 0
var _qtys: Array = []
var _money_lbl2:  Label  = null
var _shop_err:    Label  = null
var _qty_lbl:     Label  = null
var _btn_minus:   Button = null
var _btn_plus:    Button = null
var _btn_buy:     Button = null
var _btn_sell:    Button = null
var _btn_close2:  Button = null
var _row_btns:    Array  = []
var _err_timer:   float  = 0.0

# Pre-built shared row styleboxes
var _sty_row_normal:  StyleBoxFlat = null
var _sty_row_sel:     StyleBoxFlat = null
var _sty_row_hover_n: StyleBoxFlat = null
var _sty_row_hover_s: StyleBoxFlat = null

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	TimeManager.current_scene_id = "feed_supply_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Tanner's Feed & Supply"
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(-160, -90, 320, 180))
		SceneManager.register_scene_poi(Vector2(0, -30), "Shop Counter", Color(0.7, 0.5, 0.3))
		SceneManager.register_scene_poi(Vector2(0, 80), "Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Cedar Bend")
	for _i in ALL_ITEMS.size():
		_qtys.append(1)
	_build_shop_ui()
	_build_bulletin_ui()
	_update_seasonal_shelves()
	TimeManager.day_advanced.connect(_on_day_advanced)
	print("Tanner's Feed & Supply interior loaded.")

func _on_day_advanced(_day: int) -> void:
	_update_seasonal_shelves()

# -- Seasonal Shelves ----------------------------------------------------------

func _update_seasonal_shelves() -> void:
	var _season: String = TimeManager.current_season_name()
	var shelves: Sprite2D = get_node_or_null("World/Furniture/Shelves") as Sprite2D
	if not shelves:
		return
	match _season:
		"Spring":
			shelves.modulate = Color(0.88, 0.98, 0.82, 1)
		"Summer":
			shelves.modulate = Color(1.0, 0.97, 0.88, 1)
		"Fall":
			shelves.modulate = Color(0.98, 0.92, 0.78, 1)
		"Winter":
			shelves.modulate = Color(0.90, 0.92, 0.96, 1)

# -- Interaction ---------------------------------------------------------------

func _process(delta: float) -> void:
	_update_hints()
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0 and _shop_err:
			_shop_err.text = ""

func _update_hints() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	if carl_npc and shop_hint:
		var d_shop: float = player.global_position.distance_to(carl_npc.global_position)
		shop_hint.visible = (d_shop <= INTERACT_RADIUS) and not _shop_open and not _bulletin_open
	if bulletin_board and board_hint:
		var d_board: float = player.global_position.distance_to(bulletin_board.global_position)
		board_hint.visible = (d_board <= BULLETIN_RADIUS) and not _shop_open and not _bulletin_open

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Shop keyboard navigation
	if _shop_open:
		get_viewport().set_input_as_handled()
		match event.keycode:
			KEY_W:
				_sel = maxi(0, _sel - 1)
			KEY_S:
				_sel = mini(ALL_ITEMS.size() - 1, _sel + 1)
			KEY_A:
				_qtys[_sel] = maxi(1, _qtys[_sel] - 1)
			KEY_D:
				var mq: int = ALL_ITEMS[_sel].get("max_qty", 5)
				_qtys[_sel] = mini(mq, _qtys[_sel] + 1)
			KEY_E:
				_on_buy_selected()
			KEY_ESCAPE, KEY_X:
				_close_shop()
		_refresh_shop()
		return

	# Bulletin board close
	if _bulletin_open:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_X:
			_close_bulletin()
		return

	# Not in any menu
	match event.keycode:
		KEY_E:
			_try_interact()
		KEY_ESCAPE, KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			_exit_supply()

func _try_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	if carl_npc:
		var d_carl: float = player.global_position.distance_to(carl_npc.global_position)
		if d_carl <= INTERACT_RADIUS:
			_open_shop()
			return
	if bulletin_board:
		var d_board: float = player.global_position.distance_to(bulletin_board.global_position)
		if d_board <= BULLETIN_RADIUS:
			_open_bulletin()
			return

# -- Shop UI -------------------------------------------------------------------

func _build_shop_ui() -> void:
	if not shop_ui:
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
	shop_ui.add_child(dim)

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
	shop_ui.add_child(panel)

	# -- Gold border
	for r in _s_border_rects(PANEL_X, PANEL_Y, PANEL_W, PANEL_H):
		shop_ui.add_child(r)

	# -- Title bar background
	var tbar := ColorRect.new()
	tbar.color = Color(0.28, 0.18, 0.06, 0.90)
	tbar.anchor_left = 0; tbar.anchor_right = 0
	tbar.offset_left   = PANEL_X + 1
	tbar.offset_right  = PANEL_X + PANEL_W - 1
	tbar.offset_top    = PANEL_Y + 1
	tbar.offset_bottom = PANEL_Y + 14
	shop_ui.add_child(tbar)

	_s_label("-- TANNER'S FEED & SUPPLY --",
		PANEL_X + 1, PANEL_Y + 2, PANEL_W - 2, 12,
		FONT_MD, Color(0.95, 0.80, 0.30, 1.0), true)

	_s_divider(PANEL_X + 1, PANEL_Y + 14, PANEL_W - 2, C_ACCENT)

	# -- Balance line
	_money_lbl2 = _s_label("", PANEL_X + 4, PANEL_Y + 15, PANEL_W - 8, 10,
		FONT_SM, Color(0.95, 0.75, 0.20, 1.0), false)

	_s_divider(PANEL_X + 4, PANEL_Y + 25, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Item rows (11 items, ROW_H=10 each)
	for i in ALL_ITEMS.size():
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
		shop_ui.add_child(btn)
		_row_btns.append(btn)

	var rows_bottom: int = PANEL_Y + ROWS_TOP + ALL_ITEMS.size() * ROW_H

	_s_divider(PANEL_X + 4, rows_bottom, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Control row: [-] qty [+] ... [BUY] [SELL] [CLOSE]
	var cy: int = rows_bottom + 2

	_btn_minus = _s_make_btn("<", PANEL_X + 8, cy, 20, 13)
	_btn_minus.pressed.connect(_on_minus)
	shop_ui.add_child(_btn_minus)

	_qty_lbl = _s_label("x1", PANEL_X + 30, cy, 40, 13, FONT_SM, C_TEXT, true)

	_btn_plus = _s_make_btn(">", PANEL_X + 72, cy, 20, 13)
	_btn_plus.pressed.connect(_on_plus)
	shop_ui.add_child(_btn_plus)

	_btn_buy = _s_make_btn("BUY", PANEL_X + PANEL_W - 198, cy, 54, 13)
	_btn_buy.add_theme_font_size_override("font_size", FONT_MD)
	_btn_buy.pressed.connect(_on_buy_selected)
	shop_ui.add_child(_btn_buy)

	_btn_sell = _s_make_btn("SELL HONEY", PANEL_X + PANEL_W - 140, cy, 68, 13)
	_btn_sell.add_theme_font_size_override("font_size", FONT_SM)
	_btn_sell.add_theme_color_override("font_color", Color(0.40, 0.85, 0.40, 1.0))
	_btn_sell.add_theme_color_override("font_hover_color", Color(0.50, 0.95, 0.50, 1.0))
	_btn_sell.pressed.connect(_on_sell_honey)
	shop_ui.add_child(_btn_sell)

	_btn_close2 = _s_make_btn("CLOSE", PANEL_X + PANEL_W - 68, cy, 60, 13)
	_btn_close2.add_theme_font_size_override("font_size", FONT_MD)
	_btn_close2.pressed.connect(_close_shop)
	shop_ui.add_child(_btn_close2)

	# -- Keyboard hint
	_s_label("W/S select  A/D qty  E buy  ESC close",
		PANEL_X + 4, rows_bottom + 16, PANEL_W - 8, 6,
		5, Color(0.45, 0.42, 0.32, 0.85), true)

	# -- Error / feedback label
	_shop_err = _s_label("", PANEL_X + 4, rows_bottom + 22, PANEL_W - 8, 8,
		FONT_SM, Color(0.95, 0.50, 0.30, 1.0), true)

	shop_ui.visible = false

func _open_shop() -> void:
	_shop_open = true
	shop_ui.visible = true
	_refresh_shop()

func _close_shop() -> void:
	_shop_open = false
	shop_ui.visible = false

func _refresh_shop() -> void:
	var season: String = TimeManager.current_season_name()

	if _money_lbl2:
		_money_lbl2.text = "Balance: $%.0f" % GameData.money

	for i in _row_btns.size():
		var btn: Button = _row_btns[i]
		if not is_instance_valid(btn):
			continue
		var item_data: Dictionary = ALL_ITEMS[i]
		var is_sel: bool = (i == _sel)

		# Check season availability
		var s: Array = item_data.get("seasons", [])
		var in_season: bool = s.is_empty() or s.has(season)

		# Build row text
		var name_s: String = item_data["label"]
		while name_s.length() < 22:
			name_s += " "
		name_s = name_s.substr(0, 22)

		if in_season:
			btn.text = "%s $%.0f" % [name_s, item_data["cost"]]
		else:
			btn.text = "%s [out of season]" % name_s

		btn.disabled = not in_season

		# Swap pre-built styleboxes
		if is_sel and in_season:
			btn.add_theme_stylebox_override("normal", _sty_row_sel)
			btn.add_theme_stylebox_override("hover", _sty_row_hover_s)
			btn.add_theme_color_override("font_color", C_ACCENT)
		elif in_season:
			btn.add_theme_stylebox_override("normal", _sty_row_normal)
			btn.add_theme_stylebox_override("hover", _sty_row_hover_n)
			btn.add_theme_color_override("font_color", C_TEXT)
		else:
			btn.add_theme_stylebox_override("normal", _sty_row_normal)
			btn.add_theme_stylebox_override("hover", _sty_row_normal)
			btn.add_theme_color_override("font_color", C_MUTED)

	if _qty_lbl:
		_qty_lbl.text = "x%d" % _qtys[_sel]

	# Check if selected item is in season
	var sel_seasons: Array = ALL_ITEMS[_sel].get("seasons", [])
	var sel_in_season: bool = sel_seasons.is_empty() or sel_seasons.has(season)

	if _btn_minus:
		_btn_minus.disabled = (_qtys[_sel] <= 1) or not sel_in_season
	if _btn_plus:
		var mq: int = ALL_ITEMS[_sel].get("max_qty", 5)
		_btn_plus.disabled = (_qtys[_sel] >= mq) or not sel_in_season
	if _btn_buy:
		var cost: float = float(ALL_ITEMS[_sel]["cost"]) * float(_qtys[_sel])
		_btn_buy.disabled = (GameData.money < cost) or not sel_in_season

# -- Row callbacks -------------------------------------------------------------

func _on_row_click(idx: int) -> void:
	_sel = idx
	_refresh_shop()

func _on_minus() -> void:
	_qtys[_sel] = maxi(1, _qtys[_sel] - 1)
	_refresh_shop()

func _on_plus() -> void:
	var mq: int = ALL_ITEMS[_sel].get("max_qty", 5)
	_qtys[_sel] = mini(mq, _qtys[_sel] + 1)
	_refresh_shop()

# -- Purchase logic ------------------------------------------------------------

func _on_buy_selected() -> void:
	var item_data: Dictionary = ALL_ITEMS[_sel]

	# Season check
	var season: String = TimeManager.current_season_name()
	var s: Array = item_data.get("seasons", [])
	if not s.is_empty() and not s.has(season):
		_show_shop_err("Not available this season!")
		return

	var buy_qty: int = _qtys[_sel]
	var unit_cost: float = item_data["cost"]
	var total_cost: float = unit_cost * float(buy_qty)

	if not GameData.spend_money(total_cost, "Supply", "%d x %s" % [buy_qty, item_data["label"]]):
		_show_shop_err("Need $%.0f  (have $%.0f)" % [total_cost, GameData.money])
		return

	# Deliver items
	var item_id: String = item_data.get("item", "")
	var per_qty: int = item_data.get("qty", 1)
	var total_items: int = per_qty * buy_qty

	if item_id != "":
		GameData.pending_deliveries.append({"item": item_id, "count": total_items})
		_show_shop_err("Ordered %d x %s -- arrives at mailbox." % [buy_qty, item_data["label"]])
		print("[Supply] Ordered %d x %s (%d items) -- arrives at mailbox." % [buy_qty, item_data["label"], total_items])
	else:
		_show_shop_err("Bought %d x %s!" % [buy_qty, item_data["label"]])
		print("[Supply] Bought %d x %s" % [buy_qty, item_data["label"]])

	_qtys[_sel] = 1
	_refresh_shop()

func _show_shop_err(msg: String) -> void:
	if _shop_err:
		_shop_err.text = msg
		_err_timer = 2.5

# -- Sell Honey ----------------------------------------------------------------

func _on_sell_honey() -> void:
	_close_shop()
	var scene: PackedScene = load("res://scenes/ui/sell_screen.tscn") as PackedScene
	if scene == null:
		push_error("[Supply] Failed to load sell_screen.tscn")
		return
	var sell_ui: Node = scene.instantiate()
	sell_ui.price_per_jar = 8
	sell_ui.buyer_name = "Carl"
	get_tree().root.add_child(sell_ui)
	sell_ui.closed.connect(_on_sell_closed)

func _on_sell_closed() -> void:
	_open_shop()

# -- Bulletin Board UI ---------------------------------------------------------

func _build_bulletin_ui() -> void:
	if not bulletin_ui:
		return

	var overlay: ColorRect = ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulletin_ui.add_child(overlay)

	var panel: ColorRect = ColorRect.new()
	panel.anchor_left = 0; panel.anchor_right = 0
	panel.anchor_top = 0; panel.anchor_bottom = 0
	panel.offset_left   = 0
	panel.offset_right  = 320
	panel.offset_top    = 10
	panel.offset_bottom = 170
	panel.color = Color(0.28, 0.20, 0.10, 0.97)
	bulletin_ui.add_child(panel)

	# Gold border for bulletin
	for r in _s_border_rects(0, 10, 320, 160):
		bulletin_ui.add_child(r)

	var title: Label = Label.new()
	title.text = "Community Bulletin Board"
	title.anchor_left = 0; title.anchor_right = 0
	title.anchor_top = 0; title.anchor_bottom = 0
	title.offset_left   = 5
	title.offset_right  = 315
	title.offset_top    = 13
	title.offset_bottom = 28
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1))
	title.add_theme_font_size_override("font_size", 11)
	bulletin_ui.add_child(title)

	_s_divider_to(bulletin_ui, 5, 29, 310, C_ACCENT)

	var content: Label = Label.new()
	content.name = "BulletinContent"
	content.anchor_left = 0; content.anchor_right = 0
	content.anchor_top = 0; content.anchor_bottom = 0
	content.offset_left   = 8
	content.offset_right  = 312
	content.offset_top    = 31
	content.offset_bottom = 148
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", Color(0.82, 0.75, 0.58, 1))
	content.add_theme_font_size_override("font_size", 7)
	bulletin_ui.add_child(content)

	var close_lbl: Label = Label.new()
	close_lbl.text = "[X] or [ESC] to close"
	close_lbl.anchor_left = 0; close_lbl.anchor_right = 0
	close_lbl.anchor_top = 0; close_lbl.anchor_bottom = 0
	close_lbl.offset_left   = 5
	close_lbl.offset_right  = 315
	close_lbl.offset_top    = 152
	close_lbl.offset_bottom = 165
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.32, 1))
	close_lbl.add_theme_font_size_override("font_size", 6)
	bulletin_ui.add_child(close_lbl)

	bulletin_ui.visible = false

func _open_bulletin() -> void:
	_bulletin_open = true
	bulletin_ui.visible = true
	_refresh_bulletin()

func _close_bulletin() -> void:
	_bulletin_open = false
	bulletin_ui.visible = false

func _refresh_bulletin() -> void:
	var content: Label = bulletin_ui.get_node_or_null("BulletinContent") as Label
	if not content:
		return
	var season: String = TimeManager.current_season_name()
	var day: int = TimeManager.current_day_of_month()
	var notices: String = _generate_bulletin_notices(season, day)
	content.text = notices

func _generate_bulletin_notices(season: String, day: int) -> String:
	var lines: Array = []

	# Grange Hall meeting notice
	if day <= 13:
		lines.append("* Cedar Valley Grange Meeting -- %s 14, 6:00 PM\n       All members welcome. Agenda: upcoming fair schedule." % season)
	elif day == 14 or day == 15:
		lines.append("* TONIGHT: Grange Hall Meeting -- 6:00 PM\n       Cedar Valley Grange Hall. Bring your questions!")
	else:
		var next_month: int = int(float(TimeManager.current_day) / 30.0) + 2
		lines.append("* Next Grange Meeting -- Month %d, Day 14" % next_month)

	lines.append("")

	match season:
		"Spring":
			lines.append("* Bee packages now in stock -- limited supply.\n       Call ahead or stop in. First come, first served.")
			lines.append("")
			lines.append("* Cedar Bend Community Garden -- volunteer days\n       Saturdays 8 AM, east lot behind the post office.")
		"Summer":
			lines.append("* Saturday Market -- every Saturday through Fall.\n       Vendors: Frank Fischbach (honey), Harmon Farm (produce).")
			lines.append("")
			lines.append("* Mite Treatment Reminder\n       Treatment window opens late summer. Check your counts.")
		"Fall":
			lines.append("* Fall County Fair -- Date TBD (see fairground sign)\n       Honey competition registration open now.")
			lines.append("")
			lines.append("* Winter prep supplies in stock.\n       Syrup feeders, mouse guards, entrance reducers.")
		"Winter":
			lines.append("* Reduced hours through Winter.\n       Open Tue-Sat 9 AM-4 PM.")
			lines.append("")
			lines.append("* Spring package pre-orders open.\n       Reserve your bees now -- quantities limited.")

	return "\n".join(lines)

# -- Exit ---------------------------------------------------------------------

func _exit_supply() -> void:
	print("[Supply] Leaving -- returning to Cedar Bend.")
	TimeManager.previous_scene = "res://scenes/world/feed_supply_interior.tscn"
	TimeManager.next_scene     = "res://scenes/world/cedar_bend.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

# -- Shop UI widget helpers (prefixed _s_ to separate from scene logic) --------

func _s_label(text_val: String, x: int, y: int, w: int, h: int,
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
	shop_ui.add_child(l)
	return l

func _s_divider(x: int, y: int, w: int, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.anchor_left = 0; d.anchor_right = 0
	d.offset_left = x; d.offset_right = x + w
	d.offset_top = y; d.offset_bottom = y + 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_ui.add_child(d)

func _s_divider_to(parent: Node, x: int, y: int, w: int, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.anchor_left = 0; d.anchor_right = 0
	d.offset_left = x; d.offset_right = x + w
	d.offset_top = y; d.offset_bottom = y + 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)

func _s_border_rects(x: int, y: int, w: int, h: int) -> Array:
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

func _s_make_btn(label_text: String, x: int, y: int, w: int, h: int) -> Button:
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
