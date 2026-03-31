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
const PANEL_W   := 220
const PANEL_H   := 120
const PANEL_X   := 50    # (320 - 220) / 2
const PANEL_Y   := 30    # (180 - 120) / 2
const FONT_SM   := 7
const FONT_MD   := 8

# -- State ---------------------------------------------------------------
var _qty: int         = 0    # how many jars to sell (starts at max)
var _max_jars: int    = 0    # player's current honey_jar count
var _total_label: Label = null
var _qty_label: Label   = null
var _err_label: Label   = null
var _money_label: Label = null
var _err_timer: float   = 0.0

# -- Lifecycle -----------------------------------------------------------

func _ready() -> void:
	layer = 10
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_max_jars = _get_jar_count()
	_qty = _max_jars
	_build_ui()
	_refresh()

func _process(delta: float) -> void:
	if _err_timer > 0.0:
		_err_timer -= delta
		if _err_timer <= 0.0 and _err_label:
			_err_label.text = ""

# -- Input ---------------------------------------------------------------

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

	# Reset state
	_max_jars = _get_jar_count()
	_qty = _max_jars if _max_jars > 0 else 0
	_refresh()

func _show_err(msg: String) -> void:
	if _err_label:
		_err_label.text = msg
		_err_timer = 3.0

func _close() -> void:
	get_tree().paused = false
	closed.emit()
	queue_free()

# -- Helpers -------------------------------------------------------------

func _get_player() -> Node:
	var list := get_tree().get_nodes_in_group("player")
	return list[0] if list.size() > 0 else null

func _get_jar_count() -> int:
	var player: Node = _get_player()
	if player and player.has_method("count_item"):
		return player.count_item(GameData.ITEM_HONEY_JAR)
	return 0

# -- Refresh display -----------------------------------------------------

func _refresh() -> void:
	if _money_label:
		_money_label.text = "Your money: $%.0f" % GameData.money
	if _qty_label:
		var arrow_l: String = "< " if _qty > 1 else "  "
		var arrow_r: String = " >" if _qty < _max_jars else "  "
		_qty_label.text = "%s %d jar%s %s" % [arrow_l, _qty, "s" if _qty != 1 else " ", arrow_r]
	if _total_label:
		var total: int = _qty * price_per_jar
		_total_label.text = "Total: $%d" % total

# -- UI construction -----------------------------------------------------

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
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size     = Vector2(PANEL_W, PANEL_H)
	panel.color    = Color(0.07, 0.06, 0.05, 0.97)
	add_child(panel)

	# -- Border
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

	# -- Title
	var title := _make_label("-- SELL HONEY --", FONT_MD, Color(0.95, 0.80, 0.30, 1.0))
	title.position              = Vector2(PANEL_X, PANEL_Y + 5)
	title.custom_minimum_size   = Vector2(PANEL_W, 12)
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# -- Buyer name + price (with player name injection if available)
	var info_text: String = "%s buys at $%d / jar" % [buyer_name, price_per_jar]
	var name_part: String = ""
	if Engine.has_singleton("PlayerData") or get_tree().root.has_node("/root/PlayerData"):
		var pd: Node = get_tree().root.get_node_or_null("/root/PlayerData")
		if pd and "player_name" in pd:
			name_part = pd.player_name
	var greeting: String = ""
	if name_part.length() > 0:
		greeting = "\"%s, I'll pay $%d/jar!\"" % [name_part, price_per_jar]
	else:
		greeting = "%s buys at $%d / jar" % [buyer_name, price_per_jar]
	var info := _make_label(greeting, FONT_SM, Color(0.80, 0.75, 0.55, 1.0))
	info.position              = Vector2(PANEL_X, PANEL_Y + 19)
	info.custom_minimum_size   = Vector2(PANEL_W, 10)
	info.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)

	# -- Money display
	_money_label = _make_label("", FONT_SM, Color(0.95, 0.75, 0.20, 1.0))
	_money_label.position             = Vector2(PANEL_X, PANEL_Y + 31)
	_money_label.custom_minimum_size  = Vector2(PANEL_W, 10)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_money_label)

	# -- Divider
	var div := ColorRect.new()
	div.position = Vector2(PANEL_X + 4, PANEL_Y + 43)
	div.size     = Vector2(PANEL_W - 8, 1)
	div.color    = Color(0.75, 0.60, 0.20, 0.5)
	add_child(div)

	# -- "You have X jars" line
	var have_text: String = "You have %d honey jar%s" % [_max_jars, "s" if _max_jars != 1 else ""]
	var have_lbl := _make_label(have_text, FONT_SM, Color(0.85, 0.82, 0.70, 1.0))
	have_lbl.position              = Vector2(PANEL_X, PANEL_Y + 48)
	have_lbl.custom_minimum_size   = Vector2(PANEL_W, 10)
	have_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(have_lbl)

	# -- Quantity selector
	_qty_label = _make_label("", FONT_MD, Color(0.95, 0.92, 0.85, 1.0))
	_qty_label.position              = Vector2(PANEL_X, PANEL_Y + 62)
	_qty_label.custom_minimum_size   = Vector2(PANEL_W, 12)
	_qty_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_qty_label)

	# -- Total line
	_total_label = _make_label("", FONT_MD, Color(0.40, 0.85, 0.40, 1.0))
	_total_label.position              = Vector2(PANEL_X, PANEL_Y + 76)
	_total_label.custom_minimum_size   = Vector2(PANEL_W, 12)
	_total_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_total_label)

	# -- Divider 2
	var div2 := ColorRect.new()
	div2.position = Vector2(PANEL_X + 4, PANEL_Y + 90)
	div2.size     = Vector2(PANEL_W - 8, 1)
	div2.color    = Color(0.75, 0.60, 0.20, 0.5)
	add_child(div2)

	# -- Hint
	var hint := _make_label("A/D Qty   E Sell   Esc Close", FONT_SM,
							Color(0.60, 0.60, 0.60, 1.0))
	hint.position              = Vector2(PANEL_X, PANEL_Y + 94)
	hint.custom_minimum_size   = Vector2(PANEL_W, 10)
	hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	# -- Error/feedback label
	_err_label = _make_label("", FONT_SM, Color(0.95, 0.50, 0.30, 1.0))
	_err_label.position              = Vector2(PANEL_X, PANEL_Y + 106)
	_err_label.custom_minimum_size   = Vector2(PANEL_W, 10)
	_err_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_err_label)

func _make_label(text_val: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
