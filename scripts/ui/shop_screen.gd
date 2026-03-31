extends CanvasLayer

signal closed

# -- Catalogue -----------------------------------------------------------------
const CATALOGUE := [
	{"id": "seeds",            "label": "Seeds (pkg)",   "price":   5, "max_qty": 99},
	{"id": "hive_stand",       "label": "Hive Stand",    "price":  18, "max_qty": 10},
	{"id": "deep_body",        "label": "Deep Body",     "price":  35, "max_qty": 10},
	{"id": "frames",           "label": "Frames (10pk)", "price":  18, "max_qty": 50},
	{"id": "hive_lid",         "label": "Hive Lid",      "price":  12, "max_qty": 10},
	{"id": "super_box",        "label": "Super Box",     "price":  45, "max_qty": 10},
	{"id": "beehive",          "label": "Complete Hive", "price":  85, "max_qty":  5},
	{"id": "treatment_oxalic", "label": "Oxalic Acid",   "price":  12, "max_qty": 10},
	{"id": "axe",              "label": "Axe",           "price":  15, "max_qty":  1},
	{"id": "hammer",           "label": "Hammer",        "price":  10, "max_qty":  1},
	{"id": "smoker",           "label": "Smoker",        "price":  25, "max_qty":  1},
	{"id": "bee_suit",         "label": "Bee Suit",      "price":  45, "max_qty":  1},
]

const PANEL_W   := 240
const PANEL_H   := 175
const PANEL_X   := 40     # (320 - 240) / 2
const PANEL_Y   := 31     # (180 - 118) / 2
const ROW_H     := 20
const ROWS_Y    := 38     # y inside panel where item rows start
const FONT_SM   := 7
const FONT_MD   := 8

# -- State ---------------------------------------------------------------------
var _sel  := 0
var _qtys := []

# -- UI refs -------------------------------------------------------------------
var _money_lbl:  Label
var _err_lbl:    Label
var _row_bgs:    Array = []
var _row_lbls:   Array = []
var _err_timer:  float = 0.0

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	layer = 10
	for i in CATALOGUE.size():
		_qtys.append(1)
	# Pause everything except this node
	get_tree().paused = true
	process_mode    = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0:
			_err_lbl.text = ""

# -- Input ---------------------------------------------------------------------

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

# -- Purchase logic ------------------------------------------------------------

func _try_purchase() -> void:
	var entry: Dictionary = CATALOGUE[_sel]
	var qty      : int   = _qtys[_sel]
	var cost     : float = float(entry["price"]) * float(qty)
	var player   := _get_player()
	if player == null:
		return

	if not GameData.spend_money(cost, "Shop", "%d x %s" % [qty, entry["label"]]):
		_show_err("Not enough money! Need $%.2f" % cost)
		return

	var leftover: int = player.add_item(entry["id"], qty)
	if leftover > 0:
		# Inventory full -- refund the overflow
		var refund: float = float(leftover) * float(entry["price"])
		GameData.add_money(refund)
		_show_err("Inventory full! Bought %d, refunded $%.2f." % [qty - leftover, refund])
	else:
		_show_err("Bought %d x %s for $%.2f" % [qty, entry["label"], cost])

	player.update_hud_inventory()
	_qtys[_sel] = 1
	_refresh()

func _show_err(msg: String) -> void:
	_err_lbl.text  = msg
	_err_timer     = 2.5

func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

func _get_player() -> Node:
	var list := get_tree().get_nodes_in_group("player")
	return list[0] if list.size() > 0 else null

# -- Refresh display -----------------------------------------------------------

func _refresh() -> void:
	var money: float = GameData.money
	_money_lbl.text = "Balance:  $%.2f" % money

	for i in CATALOGUE.size():
		var entry: Dictionary = CATALOGUE[i]
		var qty    : int   = _qtys[i]
		var total  : float = float(entry["price"]) * float(qty)
		var sel    := i == _sel
		_row_bgs[i].color = Color(0.25, 0.22, 0.10, 1.0) if sel else Color(0.12, 0.12, 0.12, 1.0)
		var arrow: String = ">" if sel else " "
		var name_pad: String = (entry["label"] + "           ").substr(0, 12)
		_row_lbls[i].text = "%s %s $%3d  x%2d = $%4.0f" % [
			arrow, name_pad, entry["price"], qty, total]

# -- UI construction -----------------------------------------------------------

func _build_ui() -> void:
	# -- Dim backdrop ----------------------------------------------------------
	var dim := ColorRect.new()
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color         = Color(0, 0, 0, 0.55)
	dim.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# -- Main panel ------------------------------------------------------------
	var panel := ColorRect.new()
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size     = Vector2(PANEL_W, PANEL_H)
	panel.color    = Color(0.07, 0.06, 0.05, 0.97)
	add_child(panel)

	# -- Border ----------------------------------------------------------------
	var border := Panel.new()
	border.position = Vector2(PANEL_X, PANEL_Y)
	border.size     = Vector2(PANEL_W, PANEL_H)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty := StyleBoxFlat.new()
	sty.bg_color          = Color(0, 0, 0, 0)
	sty.draw_center       = false
	sty.border_color      = Color(0.75, 0.60, 0.20, 1.0)
	sty.border_width_left  = 1
	sty.border_width_right = 1
	sty.border_width_top   = 1
	sty.border_width_bottom = 1
	border.add_theme_stylebox_override("panel", sty)
	add_child(border)

	# -- Title -----------------------------------------------------------------
	var title := _make_label("-- MERCHANT --", FONT_MD, Color(0.95, 0.80, 0.30, 1.0))
	title.position              = Vector2(PANEL_X, PANEL_Y + 5)
	title.custom_minimum_size   = Vector2(PANEL_W, 12)
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# -- Money display ---------------------------------------------------------
	_money_lbl = _make_label("Balance: $0.00", FONT_SM, Color(0.95, 0.75, 0.20, 1.0))
	_money_lbl.position             = Vector2(PANEL_X + 8, PANEL_Y + 19)
	_money_lbl.custom_minimum_size  = Vector2(PANEL_W - 16, 10)
	add_child(_money_lbl)

	# -- Divider ---------------------------------------------------------------
	var div := ColorRect.new()
	div.position = Vector2(PANEL_X + 4, PANEL_Y + 31)
	div.size     = Vector2(PANEL_W - 8, 1)
	div.color    = Color(0.75, 0.60, 0.20, 0.5)
	add_child(div)

	# -- Item rows -------------------------------------------------------------
	for i in CATALOGUE.size():
		var row_y := PANEL_Y + ROWS_Y + i * ROW_H

		var bg := ColorRect.new()
		bg.position = Vector2(PANEL_X + 4, row_y)
		bg.size     = Vector2(PANEL_W - 8, ROW_H - 2)
		add_child(bg)
		_row_bgs.append(bg)

		var lbl := _make_label("", FONT_SM, Color(0.95, 0.92, 0.85, 1.0))
		lbl.position            = Vector2(PANEL_X + 6, row_y + 2)
		lbl.custom_minimum_size = Vector2(PANEL_W - 12, ROW_H - 4)
		add_child(lbl)
		_row_lbls.append(lbl)

	# -- Second divider --------------------------------------------------------
	var div2 := ColorRect.new()
	div2.position = Vector2(PANEL_X + 4, PANEL_Y + ROWS_Y + CATALOGUE.size() * ROW_H + 2)
	div2.size     = Vector2(PANEL_W - 8, 1)
	div2.color    = Color(0.75, 0.60, 0.20, 0.5)
	add_child(div2)

	# -- Hint ------------------------------------------------------------------
	var hint_y := PANEL_Y + ROWS_Y + CATALOGUE.size() * ROW_H + 6
	var hint := _make_label("W/S Select   A/D Qty   E Buy   Esc Close", FONT_SM,
							Color(0.60, 0.60, 0.60, 1.0))
	hint.position            = Vector2(PANEL_X + 4, hint_y)
	hint.custom_minimum_size = Vector2(PANEL_W - 8, 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	# -- Error/feedback label --------------------------------------------------
	_err_lbl = _make_label("", FONT_SM, Color(0.95, 0.50, 0.30, 1.0))
	_err_lbl.position            = Vector2(PANEL_X + 4, hint_y + 13)
	_err_lbl.custom_minimum_size = Vector2(PANEL_W - 8, 10)
	_err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_err_lbl)

# -- Helper --------------------------------------------------------------------

func _make_label(text_val: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
