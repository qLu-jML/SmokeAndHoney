# catalogue_ui.gd -- Annual Beekeeping Catalogue browsing and ordering UI.
# Winter Workshop S6.
# ---------------------------------------------------------------------------
# Opened when June delivers the catalogue (Kindlemonth Day 5-7).
# Shows a browsable list of items with prices and descriptions.
# Player selects items, adjusts quantity, and places orders.
# Early order bonus: first 3 days get A+B grade queens. After that, B+C only.
# Full payment at order time. Delivery on Quickening Day 1.
# ---------------------------------------------------------------------------
extends CanvasLayer

signal closed

# -- Layout -------------------------------------------------------------------
const PANEL_W   := 288
const PANEL_H   := 178
const PANEL_X   := 16
const PANEL_Y   := 2
const ROW_H     := 12
const ROWS_TOP  := 26

const FONT_SM   := 7
const FONT_MD   := 8

const C_ACCENT  := Color(0.85, 0.72, 0.42, 1.0)
const C_BG      := Color(0.14, 0.10, 0.06, 0.97)
const C_TEXT    := Color(0.92, 0.85, 0.65, 1.0)
const C_MUTED   := Color(0.45, 0.40, 0.28, 0.55)
const C_GREEN   := Color(0.45, 0.85, 0.45, 1.0)
const C_EARLY   := Color(0.95, 0.85, 0.35, 1.0)

# -- State --------------------------------------------------------------------
var _sel: int = 0
var _qtys: Array = []
var _available_items: Array = []  # Filtered by game year
var _row_btns: Array = []

# -- UI refs ------------------------------------------------------------------
var _title_lbl:  Label  = null
var _desc_lbl:   Label  = null
var _money_lbl:  Label  = null
var _status_lbl: Label  = null
var _btn_order:  Button = null
var _btn_close:  Button = null
var _qty_lbl:    Label  = null


func _ready() -> void:
	layer = 100
	_filter_items()
	_build_ui()
	_refresh()


func _filter_items() -> void:
	_available_items = []
	var year: int = GameData.get_game_year()
	var is_early: bool = GameData.is_catalogue_early()
	for item in GameData.CATALOGUE_ITEMS:
		if item.get("year", 1) > year:
			continue
		if item.get("early_only", false) and not is_early:
			continue
		_available_items.append(item)
	# Init quantities
	_qtys = []
	for i in range(_available_items.size()):
		_qtys.append(1)


func _build_ui() -> void:
	# Background overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Panel bg
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.position = Vector2(PANEL_X, PANEL_Y)
	bg.size = Vector2(PANEL_W, PANEL_H)
	add_child(bg)

	# Title
	_title_lbl = Label.new()
	var early_tag: String = " [EARLY ORDER]" if GameData.is_catalogue_early() else ""
	_title_lbl.text = "Annual Beekeeping Catalogue%s" % early_tag
	_title_lbl.position = Vector2(PANEL_X + 8, PANEL_Y + 4)
	_title_lbl.add_theme_font_size_override("font_size", FONT_MD)
	_title_lbl.add_theme_color_override("font_color", C_ACCENT)
	add_child(_title_lbl)

	# Money label
	_money_lbl = Label.new()
	_money_lbl.position = Vector2(PANEL_X + PANEL_W - 70, PANEL_Y + 4)
	_money_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_money_lbl.add_theme_color_override("font_color", C_TEXT)
	add_child(_money_lbl)

	# Item rows
	var max_rows: int = mini(_available_items.size(), 8)
	for i in range(max_rows):
		var item: Dictionary = _available_items[i]
		var btn := Button.new()
		btn.text = "%s  $%d" % [item["label"], item["price"]]
		btn.position = Vector2(PANEL_X + 4, PANEL_Y + ROWS_TOP + i * ROW_H)
		btn.size = Vector2(PANEL_W - 8, ROW_H - 2)
		btn.add_theme_font_size_override("font_size", FONT_SM)
		btn.pressed.connect(_on_row_pressed.bind(i))
		add_child(btn)
		_row_btns.append(btn)

	# Quantity label
	var qty_y: float = PANEL_Y + ROWS_TOP + max_rows * ROW_H + 2
	_qty_lbl = Label.new()
	_qty_lbl.text = "Qty: 1"
	_qty_lbl.position = Vector2(PANEL_X + 8, qty_y)
	_qty_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_qty_lbl.add_theme_color_override("font_color", C_TEXT)
	add_child(_qty_lbl)

	# Description
	_desc_lbl = Label.new()
	_desc_lbl.text = ""
	_desc_lbl.position = Vector2(PANEL_X + 60, qty_y)
	_desc_lbl.size = Vector2(PANEL_W - 68, 16)
	_desc_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_desc_lbl.add_theme_color_override("font_color", C_TEXT)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_desc_lbl)

	# Status
	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.position = Vector2(PANEL_X + 8, qty_y + 16)
	_status_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_status_lbl.add_theme_color_override("font_color", C_GREEN)
	add_child(_status_lbl)

	# Order button
	_btn_order = Button.new()
	_btn_order.text = "[ORDER]"
	_btn_order.position = Vector2(PANEL_X + PANEL_W - 120, PANEL_Y + PANEL_H - 18)
	_btn_order.size = Vector2(50, 14)
	_btn_order.add_theme_font_size_override("font_size", FONT_SM)
	_btn_order.pressed.connect(_on_order)
	add_child(_btn_order)

	# Close button
	_btn_close = Button.new()
	_btn_close.text = "[CLOSE]"
	_btn_close.position = Vector2(PANEL_X + PANEL_W - 60, PANEL_Y + PANEL_H - 18)
	_btn_close.size = Vector2(50, 14)
	_btn_close.add_theme_font_size_override("font_size", FONT_SM)
	_btn_close.pressed.connect(_on_close)
	add_child(_btn_close)


func _refresh() -> void:
	_money_lbl.text = "$%.0f" % GameData.money

	for i in range(_row_btns.size()):
		var btn: Button = _row_btns[i]
		if i == _sel:
			btn.add_theme_color_override("font_color", C_ACCENT)
		else:
			btn.add_theme_color_override("font_color", C_TEXT)

	if _sel >= 0 and _sel < _available_items.size():
		var item: Dictionary = _available_items[_sel]
		var qty: int = _qtys[_sel]
		var cost: float = item["price"] * qty
		_qty_lbl.text = "Qty: %d  Total: $%d" % [qty, int(cost)]
		_desc_lbl.text = item.get("desc", "")

		if item.get("early_only", false):
			_status_lbl.text = "Early order exclusive!"
			_status_lbl.add_theme_color_override("font_color", C_EARLY)
		elif cost > GameData.money:
			_status_lbl.text = "Not enough money."
			_status_lbl.add_theme_color_override("font_color", C_MUTED)
		else:
			_status_lbl.text = "Delivers Quickening Day 1."
			_status_lbl.add_theme_color_override("font_color", C_GREEN)

		_btn_order.disabled = (cost > GameData.money)


func _on_row_pressed(index: int) -> void:
	_sel = index
	_refresh()


func _on_order() -> void:
	if _sel < 0 or _sel >= _available_items.size():
		return
	var item: Dictionary = _available_items[_sel]
	var qty: int = _qtys[_sel]
	var cost: float = item["price"] * qty
	if cost > GameData.money:
		return

	# Deduct money
	GameData.money -= cost
	GameData.money_changed.emit(GameData.money)

	# Record order
	var order: Dictionary = {
		"item": item["id"],
		"count": qty,
		"price": cost,
		"quality": "A" if GameData.is_catalogue_early() else "B",
	}
	GameData.catalogue_orders.append(order)

	# Add to pending deliveries (arrive Quickening Day 1)
	GameData.pending_deliveries.append({
		"item": item["id"],
		"count": qty,
		"source": "catalogue",
	})

	if NotificationManager:
		NotificationManager.notify(
			"Ordered %dx %s ($%d). Arrives Quickening Day 1." % [qty, item["label"], int(cost)],
			NotificationManager.T_INFO, 4.0)

	_refresh()


func _on_close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_on_close()
				get_viewport().set_input_as_handled()
			KEY_W, KEY_UP:
				_sel = max(0, _sel - 1)
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				_sel = min(_available_items.size() - 1, _sel + 1)
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				if _sel >= 0 and _sel < _qtys.size():
					_qtys[_sel] = max(1, _qtys[_sel] - 1)
					_refresh()
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				if _sel >= 0 and _sel < _qtys.size():
					_qtys[_sel] = min(10, _qtys[_sel] + 1)
					_refresh()
				get_viewport().set_input_as_handled()
			KEY_E, KEY_ENTER:
				_on_order()
				get_viewport().set_input_as_handled()
