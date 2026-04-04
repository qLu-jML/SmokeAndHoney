# shop_screen.gd -- General store UI (Carl's Feed & Supply / Market booths)
# -------------------------------------------------------------------------
# Opens as a CanvasLayer overlay. Caller sets 'shop_name' before adding.
# Click a row to select an item, adjust qty with [-][+] or A/D,
# then press [BUY] or E to purchase. Esc or [CLOSE] to dismiss.
# -------------------------------------------------------------------------
extends CanvasLayer

signal closed

# -- Shop config (set before adding to tree) ------------------------------
var shop_name: String = "Carl's Feed & Supply"

# -- Catalogue ------------------------------------------------------------
const CATALOGUE := [
	{"id": "seeds",            "label": "Seeds (pkg)",   "price":  5, "max_qty": 99},
	{"id": "hive_stand",       "label": "Hive Stand",    "price": 18, "max_qty": 10},
	{"id": "deep_body",        "label": "Deep Body",     "price": 35, "max_qty": 10},
	{"id": "frames",           "label": "Frames (10pk)", "price": 18, "max_qty": 50},
	{"id": "hive_lid",         "label": "Hive Lid",      "price": 12, "max_qty": 10},
	{"id": "super_box",        "label": "Super Box",     "price": 45, "max_qty": 10},
	{"id": "beehive",          "label": "Full Hive Kit", "price": 85, "max_qty":  5},
	{"id": "treatment_oxalic", "label": "Oxalic Acid",   "price": 12, "max_qty": 10},
	{"id": "axe",              "label": "Axe",           "price": 15, "max_qty":  1},
	{"id": "hammer",           "label": "Hammer",        "price": 10, "max_qty":  1},
	{"id": "smoker",           "label": "Smoker",        "price": 25, "max_qty":  1},
	{"id": "bee_suit",         "label": "Bee Suit",      "price": 45, "max_qty":  1},
	# Winterization supplies (Winter Workshop S4)
	{"id": "entrance_reducer", "label": "Entrance Reducer", "price":  5, "max_qty": 10},
	{"id": "mouse_guard",      "label": "Mouse Guard",      "price":  8, "max_qty": 10},
	{"id": "hive_wrap",        "label": "Hive Wrap",        "price": 15, "max_qty": 10},
	{"id": "top_insulation",   "label": "Top Insulation",   "price":  8, "max_qty": 10},
	# Equipment maintenance (Winter Workshop S7)
	{"id": "furniture_polish", "label": "Furniture Polish", "price":  6, "max_qty": 10},
]

# -- Layout ---------------------------------------------------------------
const PANEL_W   := 288
const PANEL_H   := 178
const PANEL_X   := 16     # (320 - 288) / 2
const PANEL_Y   := 2
const ROW_H     := 10     # height of each item row in pixels
const ROWS_TOP  := 26     # y-offset (inside panel) where first row starts

const FONT_SM   := 7
const FONT_MD   := 8

const C_ACCENT  := Color(0.95, 0.78, 0.32, 1.0)
const C_BG_BTN  := Color(0.22, 0.15, 0.07, 0.97)
const C_BG_HOV  := Color(0.35, 0.24, 0.10, 0.97)
const C_BG_SEL  := Color(0.42, 0.28, 0.08, 1.00)
const C_TEXT    := Color(0.92, 0.85, 0.65, 1.0)
const C_MUTED   := Color(0.45, 0.40, 0.28, 0.55)

# -- State ----------------------------------------------------------------
var _sel: int    = 0
var _qtys: Array = []

# -- UI refs --------------------------------------------------------------
var _money_lbl:   Label  = null
var _err_lbl:     Label  = null
var _qty_lbl:     Label  = null
var _btn_minus:   Button = null
var _btn_plus:    Button = null
var _btn_buy:     Button = null
var _btn_close:   Button = null
var _row_btns:    Array  = []
var _err_timer:   float  = 0.0

# Pre-built shared row stylebboxes (swapped in _refresh for performance)
var _sty_row_normal:     StyleBoxFlat = null
var _sty_row_sel:        StyleBoxFlat = null
var _sty_row_hover_n:    StyleBoxFlat = null
var _sty_row_hover_s:    StyleBoxFlat = null

# -- Lifecycle ------------------------------------------------------------

## Initializes the shop UI, pauses the game, and sets up initial quantities.
func _ready() -> void:
	layer = 10
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in CATALOGUE.size():
		_qtys.append(1)
	_build_ui()
	_refresh()

## Updates error message timer each frame.
func _process(delta: float) -> void:
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0 and _err_lbl:
			_err_lbl.text = ""

# -- Input ----------------------------------------------------------------

## Handles keyboard input for item selection, quantity adjustment, and purchase.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_W:
			_sel = maxi(0, _sel - 1)
		KEY_S:
			_sel = mini(CATALOGUE.size() - 1, _sel + 1)
		KEY_A:
			_qtys[_sel] = maxi(1, _qtys[_sel] - 1)
		KEY_D:
			_qtys[_sel] = mini(CATALOGUE[_sel]["max_qty"], _qtys[_sel] + 1)
		KEY_E:
			_try_purchase()
		KEY_ESCAPE:
			_close()
	_refresh()

# -- Button callbacks -----------------------------------------------------

## Selects an item row when clicked.
func _on_row_click(idx: int) -> void:
	_sel = idx
	_refresh()

## Decreases the selected quantity by 1.
func _on_minus() -> void:
	_qtys[_sel] = maxi(1, _qtys[_sel] - 1)
	_refresh()

## Increases the selected quantity by 1.
func _on_plus() -> void:
	_qtys[_sel] = mini(CATALOGUE[_sel]["max_qty"], _qtys[_sel] + 1)
	_refresh()

# -- Purchase logic -------------------------------------------------------

## Validates and completes the purchase transaction.
func _try_purchase() -> void:
	var entry: Dictionary = CATALOGUE[_sel]
	var qty: int = _qtys[_sel]
	var cost: float = float(entry["price"]) * float(qty)
	var player: Node = _get_player()
	if player == null:
		return
	if not GameData.spend_money(cost, "Shop", "%d x %s" % [qty, entry["label"]]):
		_show_err("Need $%.0f  (have $%.0f)" % [cost, GameData.money])
		return
	var leftover: int = player.add_item(entry["id"], qty)
	if leftover > 0:
		var refund: float = float(leftover) * float(entry["price"])
		GameData.add_money(refund)
		_show_err("Inv full! Bought %d, refunded $%.0f." % [qty - leftover, refund])
	else:
		_show_err("Bought %d x %s!" % [qty, entry["label"]])
	player.update_hud_inventory()
	_qtys[_sel] = 1
	_refresh()

## Displays an error or feedback message for 2.5 seconds.
func _show_err(msg: String) -> void:
	if _err_lbl:
		_err_lbl.text = msg
		_err_timer = 2.5

## Closes the shop and resumes the game.
func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

## Returns the player node from the player group.
func _get_player() -> Node:
	var list := get_tree().get_nodes_in_group("player")
	return list[0] if list.size() > 0 else null

# -- Refresh display ------------------------------------------------------

## Updates all UI labels to reflect current shop state.
func _refresh() -> void:
	if _money_lbl:
		_money_lbl.text = "Balance: $%.0f" % GameData.money

	for i in _row_btns.size():
		var btn: Button = _row_btns[i]
		var entry: Dictionary = CATALOGUE[i]
		var is_sel: bool = (i == _sel)
		# Build row label: name padded to 16 chars + price right-aligned
		var name_s: String = entry["label"]
		while name_s.length() < 16:
			name_s += " "
		name_s = name_s.substr(0, 16)
		btn.text = "%s $%d" % [name_s, entry["price"]]
		# Swap pre-built stylebboxes -- avoids creating garbage every frame
		if is_sel:
			btn.add_theme_stylebox_override("normal", _sty_row_sel)
			btn.add_theme_stylebox_override("hover",  _sty_row_hover_s)
			btn.add_theme_color_override("font_color", C_ACCENT)
		else:
			btn.add_theme_stylebox_override("normal", _sty_row_normal)
			btn.add_theme_stylebox_override("hover",  _sty_row_hover_n)
			btn.add_theme_color_override("font_color", C_TEXT)

	if _qty_lbl:
		_qty_lbl.text = "x%d" % _qtys[_sel]

	if _btn_minus:
		_btn_minus.disabled = (_qtys[_sel] <= 1)
	if _btn_plus:
		_btn_plus.disabled = (_qtys[_sel] >= CATALOGUE[_sel]["max_qty"])
	if _btn_buy:
		var cost: float = float(CATALOGUE[_sel]["price"]) * float(_qtys[_sel])
		_btn_buy.disabled = (GameData.money < cost)

# -- UI construction ------------------------------------------------------

## Constructs the complete shop interface.
func _build_ui() -> void:
	# Pre-build shared row stylebboxes
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
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

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
	add_child(panel)

	# -- Gold border
	for er in _border_rects(PANEL_X, PANEL_Y, PANEL_W, PANEL_H):
		add_child(er)

	# -- Title bar background
	var tbar := ColorRect.new()
	tbar.color = Color(0.28, 0.18, 0.06, 0.90)
	tbar.anchor_left = 0; tbar.anchor_right = 0
	tbar.offset_left   = PANEL_X + 1
	tbar.offset_right  = PANEL_X + PANEL_W - 1
	tbar.offset_top    = PANEL_Y + 1
	tbar.offset_bottom = PANEL_Y + 14
	add_child(tbar)

	_abs_label("-- " + shop_name.to_upper() + " --",
		PANEL_X + 1, PANEL_Y + 2, PANEL_W - 2, 12,
		FONT_MD, Color(0.95, 0.80, 0.30, 1.0), true)

	_divider(PANEL_X + 1, PANEL_Y + 14, PANEL_W - 2, C_ACCENT)

	# -- Balance line
	_money_lbl = _abs_label("", PANEL_X + 4, PANEL_Y + 15, PANEL_W - 8, 10,
		FONT_SM, Color(0.95, 0.75, 0.20, 1.0), false)

	_divider(PANEL_X + 4, PANEL_Y + 25, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Item rows (all 12, ROW_H=10 each)
	for i in CATALOGUE.size():
		var ry: int = PANEL_Y + ROWS_TOP + i * ROW_H
		var btn: Button = Button.new()
		btn.clip_text   = true
		btn.focus_mode  = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", FONT_SM)
		btn.add_theme_color_override("font_color",         C_TEXT)
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		# Apply initial normal style (will be swapped in _refresh)
		btn.add_theme_stylebox_override("normal",   _sty_row_normal)
		btn.add_theme_stylebox_override("hover",    _sty_row_hover_n)
		var sb_pr := StyleBoxFlat.new()
		sb_pr.bg_color = Color(0.50, 0.35, 0.10, 1.0)
		sb_pr.set_border_width_all(0)
		sb_pr.set_content_margin_all(1)
		btn.add_theme_stylebox_override("pressed",  sb_pr)
		var sb_fo := StyleBoxFlat.new()
		sb_fo.bg_color = Color(0, 0, 0, 0)
		sb_fo.set_border_width_all(0)
		btn.add_theme_stylebox_override("focus", sb_fo)
		btn.anchor_left   = 0; btn.anchor_top    = 0
		btn.anchor_right  = 0; btn.anchor_bottom = 0
		btn.offset_left   = PANEL_X + 4
		btn.offset_top    = ry
		btn.offset_right  = PANEL_X + PANEL_W - 4
		btn.offset_bottom = ry + ROW_H - 1
		btn.z_index = 5
		btn.pressed.connect(_on_row_click.bind(i))
		add_child(btn)
		_row_btns.append(btn)

	# Compute where the rows end (absolute y)
	var rows_bottom: int = PANEL_Y + ROWS_TOP + CATALOGUE.size() * ROW_H

	_divider(PANEL_X + 4, rows_bottom, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.40))

	# -- Control row: [-] qty [+]  ...gap...  [BUY] [CLOSE]
	var cy: int = rows_bottom + 2

	_btn_minus = _make_btn("<", PANEL_X + 8, cy, 20, 13)
	_btn_minus.pressed.connect(_on_minus)
	add_child(_btn_minus)

	_qty_lbl = _abs_label("x1", PANEL_X + 30, cy, 40, 13, FONT_SM, C_TEXT, true)

	_btn_plus = _make_btn(">", PANEL_X + 72, cy, 20, 13)
	_btn_plus.pressed.connect(_on_plus)
	add_child(_btn_plus)

	# BUY and CLOSE on the right side
	_btn_buy = _make_btn("BUY", PANEL_X + PANEL_W - 154, cy, 68, 13)
	_btn_buy.add_theme_font_size_override("font_size", FONT_MD)
	_btn_buy.pressed.connect(_try_purchase)
	add_child(_btn_buy)

	_btn_close = _make_btn("CLOSE", PANEL_X + PANEL_W - 82, cy, 74, 13)
	_btn_close.add_theme_font_size_override("font_size", FONT_MD)
	_btn_close.pressed.connect(_close)
	add_child(_btn_close)

	# -- Keyboard hint
	_abs_label("W/S or click to select  A/D or <> qty  E to buy",
		PANEL_X + 4, rows_bottom + 16, PANEL_W - 8, 6,
		5, Color(0.45, 0.42, 0.32, 0.85), true)

	# -- Error / feedback label
	_err_lbl = _abs_label("", PANEL_X + 4, rows_bottom + 22, PANEL_W - 8, 8,
		FONT_SM, Color(0.95, 0.50, 0.30, 1.0), true)

# -- Widget helpers -------------------------------------------------------

## Creates an absolutely-positioned label.
func _abs_label(text_val: String, x: int, y: int, w: int, h: int,
		fsize: int, col: Color, centred: bool) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if centred:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left   = 0; l.anchor_top    = 0
	l.anchor_right  = 0; l.anchor_bottom = 0
	l.offset_left   = x; l.offset_top    = y
	l.offset_right  = x + w; l.offset_bottom = y + h
	l.z_index = 5
	add_child(l)
	return l

## Creates a horizontal divider line.
func _divider(x: int, y: int, w: int, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.anchor_left = 0; d.anchor_right = 0
	d.offset_left  = x; d.offset_right  = x + w
	d.offset_top   = y; d.offset_bottom = y + 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(d)

## Generates border rectangles for a panel.
func _border_rects(x: int, y: int, w: int, h: int) -> Array:
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

## Creates a styled button with theme overrides.
func _make_btn(label_text: String, x: int, y: int, w: int, h: int) -> Button:
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
	btn.anchor_left   = 0; btn.anchor_top    = 0
	btn.anchor_right  = 0; btn.anchor_bottom = 0
	btn.offset_left   = x; btn.offset_top    = y
	btn.offset_right  = x + w; btn.offset_bottom = y + h
	btn.z_index = 10
	return btn
