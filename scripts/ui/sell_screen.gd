# sell_screen.gd -- Honey selling UI (simple confirm dialog)
# -----------------------------------------------------------------------
# Displayed when the player interacts with a honey buyer (Carl at Feed &
# Supply or Frank at the Saturday Market).  Shows jar count, price per
# jar, lets the player choose quantity with A/D, and confirm with E.
#
# Usage:
#   var screen = load("res://scenes/ui/sell_screen.tscn").instantiate()
#   screen.price_per_jar = 10   # Saturday Market rate
#   screen.buyer_name    = "Frank"
#   get_tree().root.add_child(screen)
# -----------------------------------------------------------------------
extends CanvasLayer

signal closed

# -- Configuration (set before adding to tree) ---------------------------
var price_per_jar: int  = 8       # default: Feed & Supply everyday rate
var buyer_name: String  = "Carl"  # NPC name shown in title bar

# -- Layout constants ----------------------------------------------------
const PANEL_W   := 224
const PANEL_H   := 140
const PANEL_X   := 48    # (320 - 224) / 2
const PANEL_Y   := 20
const FONT_SM   := 7
const FONT_MD   := 8

# Accent / button colours (matching HUD palette)
const C_ACCENT  := Color(0.95, 0.78, 0.32, 1.0)
const C_BG_BTN  := Color(0.22, 0.15, 0.07, 0.97)
const C_BG_HOV  := Color(0.35, 0.24, 0.10, 0.97)
const C_TEXT    := Color(0.92, 0.85, 0.65, 1.0)
const C_MUTED   := Color(0.45, 0.40, 0.28, 0.55)

# -- State ---------------------------------------------------------------
var _qty: int          = 0    # how many jars to sell (starts at max)
var _max_jars: int     = 0    # player's current honey_jar count
var _total_label: Label  = null
var _qty_label: Label    = null
var _err_label: Label    = null
var _money_label: Label  = null
var _btn_minus: Button   = null
var _btn_plus: Button    = null
var _btn_sell: Button    = null
var _btn_cancel: Button  = null
var _err_timer: float    = 0.0

# -- Lifecycle -----------------------------------------------------------

## Initializes the sell screen UI and state. Sets up pause, loads jar count, and builds the interface.
func _ready() -> void:
	layer = 10
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_max_jars = _get_jar_count()
	_qty = _max_jars
	_build_ui()
	_refresh()

## Updates error message timer each frame, clearing the message when time expires.
func _process(delta: float) -> void:
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0 and _err_label:
			_err_label.text = ""

# -- Input ---------------------------------------------------------------

## Handles keyboard input for quantity adjustment and sell/cancel actions.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()

	match event.keycode:
		KEY_A:
			_qty = maxi(1, _qty - 1)
		KEY_D:
			_qty = mini(_max_jars, _qty + 1)
		KEY_E:
			_try_sell()
		KEY_ESCAPE:
			_close()

	_refresh()

# -- Sell logic ----------------------------------------------------------

## Validates jar availability and player state, then completes the sale transaction.
func _try_sell() -> void:
	if _max_jars <= 0:
		_show_err("You have no honey jars to sell!")
		return
	if _qty <= 0:
		_show_err("Select at least 1 jar.")
		return

	var player: Node = _get_player()
	if player == null:
		return

	# Remove jars from inventory
	var success: bool = player.consume_item(GameData.ITEM_HONEY_JAR, _qty)
	if not success:
		_show_err("Not enough jars!")
		return

	# Add money
	var earnings: float = float(_qty) * float(price_per_jar)
	GameData.add_money(earnings)

	# XP: 2 XP per $10 earned (GDD S7.1)
	var sale_xp: int = int(earnings / 10.0) * 2
	if sale_xp < 1:
		sale_xp = 1
	GameData.add_xp(sale_xp)

	# Market participation XP: 15-25 points (GDD S7.1)
	var market_xp: int = randi_range(GameData.XP_MARKET_PARTICIPATION_MIN, GameData.XP_MARKET_PARTICIPATION_MAX)
	GameData.add_xp(market_xp)

	# Community standing: +3 per market transaction (GDD S9)
	GameData.reputation = minf(GameData.reputation + 3.0, 1000.0)

	# Log the sale as income
	GameData.expense_log.append({
		"category": "Honey Sale",
		"amount": -earnings,
		"description": "%d jars @ $%d to %s" % [_qty, price_per_jar, buyer_name],
		"day": TimeManager.current_day,
	})
	# Bound log size
	if GameData.expense_log.size() > 365:
		GameData.expense_log.pop_front()

	_show_err("Sold %d jars for $%d!" % [_qty, int(earnings)])
	player.update_hud_inventory()

	# Quest events: market sale + attendance tracking
	QuestManager.notify_event("first_market_sale", {
		"qty": _qty,
		"earnings": int(earnings),
		"buyer": buyer_name,
	})
	# Saturday Regulars: track product type and earnings for compound objective
	QuestManager.notify_event("market_sale_tracked", {
		"earnings": int(earnings),
		"product": "honey",
	})
	QuestManager.notify_event("market_attended", {})

	# Reset state
	_max_jars = _get_jar_count()
	_qty = _max_jars if _max_jars > 0 else 0
	_refresh()

## Displays an error message for 3 seconds.
func _show_err(msg: String) -> void:
	if _err_label:
		_err_label.text = msg
		_err_timer = 3.0

## Closes the sell screen, resumes the game, and emits the closed signal.
func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

# -- Helpers -------------------------------------------------------------

## Returns the player node from the 'player' group, or null if not found.
func _get_player() -> Node:
	var list := get_tree().get_nodes_in_group("player")
	return list[0] if list.size() > 0 else null

## Returns the player's current honey jar inventory count.
func _get_jar_count() -> int:
	var player: Node = _get_player()
	if player and player.has_method("count_item"):
		return player.count_item(GameData.ITEM_HONEY_JAR)
	return 0

# -- Refresh display -----------------------------------------------------

## Decreases quantity by 1 (minimum 1) and refreshes display.
func _on_minus() -> void:
	_qty = maxi(1, _qty - 1)
	_refresh()

## Increases quantity by 1 (maximum jar count) and refreshes display.
func _on_plus() -> void:
	_qty = mini(_max_jars, _qty + 1)
	_refresh()

## Updates all UI labels to reflect current state (money, quantity, total, button states).
func _refresh() -> void:
	if _money_label:
		_money_label.text = "Your money: $%.0f" % GameData.money
	if _qty_label:
		_qty_label.text = "%d jar%s" % [_qty, "s" if _qty != 1 else ""]
	if _total_label:
		var total: int = _qty * price_per_jar
		_total_label.text = "Total: $%d" % total
	if _btn_minus:
		_btn_minus.disabled = (_qty <= 1 or _max_jars <= 0)
	if _btn_plus:
		_btn_plus.disabled = (_qty >= _max_jars or _max_jars <= 0)
	if _btn_sell:
		_btn_sell.disabled = (_max_jars <= 0 or _qty <= 0)

# -- UI construction -----------------------------------------------------

## Builds the entire sell screen UI with panels, buttons, labels, and styling.
func _build_ui() -> void:
	# -- Dim backdrop
	var dim := ColorRect.new()
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color         = Color(0, 0, 0, 0.55)
	dim.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# -- Main panel
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.07, 0.04, 0.97)
	panel.anchor_left   = 0; panel.anchor_top    = 0
	panel.anchor_right  = 0; panel.anchor_bottom = 0
	panel.offset_left   = PANEL_X;          panel.offset_top    = PANEL_Y
	panel.offset_right  = PANEL_X + PANEL_W; panel.offset_bottom = PANEL_Y + PANEL_H
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(panel)

	# -- Gold border (1px accent line around panel)
	for edge_rect in _border_rects(PANEL_X, PANEL_Y, PANEL_W, PANEL_H):
		add_child(edge_rect)

	# -- Title bar
	var title_bar := ColorRect.new()
	title_bar.color = Color(0.28, 0.18, 0.06, 0.90)
	title_bar.anchor_left = 0; title_bar.anchor_right = 0
	title_bar.offset_left = PANEL_X + 1; title_bar.offset_right = PANEL_X + PANEL_W - 1
	title_bar.offset_top  = PANEL_Y + 1; title_bar.offset_bottom = PANEL_Y + 16
	add_child(title_bar)

	_abs_label("-- SELL HONEY --", PANEL_X + 1, PANEL_Y + 3,
		PANEL_W - 2, 12, FONT_MD, Color(0.95, 0.80, 0.30, 1.0), true)

	_divider(PANEL_X + 1, PANEL_Y + 16, PANEL_W - 2, C_ACCENT)

	# -- Buyer greeting
	var name_part: String = ""
	var pd: Node = get_tree().root.get_node_or_null("/root/PlayerData")
	if pd and "player_name" in pd:
		name_part = str(pd.get("player_name"))
	var greeting: String = ""
	if name_part.length() > 0:
		greeting = "\"%s, I'll pay $%d/jar!\"" % [name_part, price_per_jar]
	else:
		greeting = "%s buys at $%d / jar" % [buyer_name, price_per_jar]
	_abs_label(greeting, PANEL_X + 2, PANEL_Y + 19,
		PANEL_W - 4, 10, FONT_SM, Color(0.80, 0.75, 0.55, 1.0), true)

	# -- Money display
	_money_label = _abs_label("", PANEL_X + 2, PANEL_Y + 31,
		PANEL_W - 4, 10, FONT_SM, Color(0.95, 0.75, 0.20, 1.0), true)

	_divider(PANEL_X + 4, PANEL_Y + 43, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.5))

	# -- "You have X jars"
	var have_text: String = "You have %d honey jar%s" % [_max_jars, "s" if _max_jars != 1 else ""]
	_abs_label(have_text, PANEL_X + 2, PANEL_Y + 47,
		PANEL_W - 4, 10, FONT_SM, Color(0.85, 0.82, 0.70, 1.0), true)

	# -- Quantity row: [-] qty [+]
	#    Layout: [-] = 22px | qty label = 130px | [+] = 22px
	#    Total = 174, centered in PANEL_W=224 -> margin = (224-174)/2 = 25px
	var QY: int = PANEL_Y + 60
	var QL: int = PANEL_X + 25   # left of [-]
	_btn_minus = _make_btn("<", QL,      QY, 22, 13)
	_btn_minus.pressed.connect(_on_minus)
	add_child(_btn_minus)

	_qty_label = _abs_label("", QL + 24, QY + 1, 130, 12,
		FONT_MD, Color(0.95, 0.92, 0.85, 1.0), true)

	_btn_plus = _make_btn(">", QL + 156, QY, 22, 13)
	_btn_plus.pressed.connect(_on_plus)
	add_child(_btn_plus)

	# -- Total line
	_total_label = _abs_label("", PANEL_X + 2, PANEL_Y + 77,
		PANEL_W - 4, 12, FONT_MD, Color(0.40, 0.85, 0.40, 1.0), true)

	_divider(PANEL_X + 4, PANEL_Y + 92, PANEL_W - 8, Color(0.60, 0.50, 0.20, 0.5))

	# -- Action buttons: [SELL] and [CANCEL] side by side
	#    Two 86px buttons with 16px gap and 18px margin each side
	var AY: int = PANEL_Y + 97
	_btn_sell = _make_btn("SELL", PANEL_X + 18, AY, 86, 16)
	_btn_sell.add_theme_font_size_override("font_size", FONT_MD)
	_btn_sell.pressed.connect(_try_sell)
	add_child(_btn_sell)

	_btn_cancel = _make_btn("CANCEL", PANEL_X + 120, AY, 86, 16)
	_btn_cancel.add_theme_font_size_override("font_size", FONT_MD)
	_btn_cancel.pressed.connect(_close)
	add_child(_btn_cancel)

	# -- Keyboard hint (small, below buttons)
	_abs_label("A/D or click  <>  to set qty", PANEL_X + 2, PANEL_Y + 116,
		PANEL_W - 4, 8, 5, Color(0.45, 0.42, 0.32, 0.85), true)

	# -- Error/feedback label
	_err_label = _abs_label("", PANEL_X + 2, PANEL_Y + 126,
		PANEL_W - 4, 12, FONT_SM, Color(0.95, 0.50, 0.30, 1.0), true)

# -- Widget helpers -------------------------------------------------------

## Creates an absolutely-positioned label with the specified properties.
func _abs_label(text_val: String, x: int, y: int, w: int, h: int,
		fsize: int, col: Color, centred: bool) -> Label:
	var l: Label = Label.new()
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

## Creates a horizontal divider line at the specified position with given color.
func _divider(x: int, y: int, w: int, col: Color) -> void:
	var d: ColorRect = ColorRect.new()
	d.color = col
	d.anchor_left = 0; d.anchor_right = 0
	d.offset_left = x; d.offset_right = x + w
	d.offset_top  = y; d.offset_bottom = y + 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(d)

## Generates the four border rectangles (top, bottom, left, right) for a panel.
func _border_rects(x: int, y: int, w: int, h: int) -> Array:
	var rects: Array = []
	for coords in [
		[x,         y,         w, 1],  # top
		[x,         y + h - 1, w, 1],  # bottom
		[x,         y,         1, h],  # left
		[x + w - 1, y,         1, h],  # right
	]:
		var r: ColorRect = ColorRect.new()
		r.color  = C_ACCENT
		r.anchor_left = 0; r.anchor_right = 0
		r.offset_left  = coords[0]; r.offset_top    = coords[1]
		r.offset_right = coords[0] + coords[2]
		r.offset_bottom = coords[1] + coords[3]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rects.append(r)
	return rects

## Creates a styled button with theme overrides for all button states.
func _make_btn(label_text: String, x: int, y: int, w: int, h: int) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", FONT_SM)
	btn.add_theme_color_override("font_color",          C_TEXT)
	btn.add_theme_color_override("font_hover_color",    C_ACCENT)
	btn.add_theme_color_override("font_pressed_color",  Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", C_MUTED)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
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

