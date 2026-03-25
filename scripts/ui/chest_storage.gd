# chest_storage.gd -- Modal Storage Chest UI (10 x 5 grid + player hotbar)
# Keyboard-driven transfer UI. WASD navigate, E transfers full stack,
# Shift+E transfers single item, Q toggles chest/inventory focus, Esc closes.
extends CanvasLayer

# Reference to the world chest whose storage we are viewing
var chest_ref: Node = null

# Layout constants (320x180 viewport)
const VP_W        := 320
const VP_H        := 180
const PANEL_W     := 280
const PANEL_H     := 160
const PANEL_X     := 20
const PANEL_Y     := 10

const SLOT_SIZE   := 14
const SLOT_GAP    := 1
const SLOT_STEP   := SLOT_SIZE + SLOT_GAP  # 15

const GRID_COLS   := 10
const GRID_ROWS   := 5
const CHEST_SLOTS := GRID_COLS * GRID_ROWS  # 50

# Grid origin inside panel
const GRID_X      := 5
const GRID_Y      := 22

# Player inventory row
const INV_COLS    := 10
const INV_Y       := 108

const FONT_SM     := 7
const FONT_MD     := 8

# -- State --------------------------------------------------------------------
enum Focus { CHEST, PLAYER }
var _focus: Focus = Focus.CHEST
var _cursor_x: int = 0
var _cursor_y: int = 0

# -- UI refs ------------------------------------------------------------------
var _chest_slot_rects: Array = []
var _chest_count_lbls: Array = []
var _inv_slot_rects:   Array = []
var _inv_count_lbls:   Array = []
var _cursor_panel:     Panel = null
var _info_lbl:         Label = null
var _hint_lbl:         Label = null

# -- Colours ------------------------------------------------------------------
const C_BORDER     := Color(0.75, 0.60, 0.20, 1.0)
const C_GOLD       := Color(0.95, 0.80, 0.30, 1.0)
const C_TEXT       := Color(0.95, 0.92, 0.85, 1.0)
const C_DIM        := Color(0.60, 0.60, 0.60, 1.0)
const C_SLOT_EMPTY := Color(0.18, 0.13, 0.05, 1.0)
const C_PANEL_BG   := Color(0.07, 0.06, 0.05, 0.97)
const C_CURSOR     := Color(0.95, 0.78, 0.32, 1.0)

# Slot colour map (matches hud.gd)
var SLOT_COLORS := {}
var LONG_NAME := {}

func _init_color_maps() -> void:
	SLOT_COLORS = {
		GameData.ITEM_RAW_HONEY: Color(0.78, 0.52, 0.08),
		GameData.ITEM_HONEY_JAR: Color(0.85, 0.62, 0.12),
		GameData.ITEM_BEESWAX: Color(0.88, 0.78, 0.28),
		GameData.ITEM_POLLEN: Color(0.88, 0.75, 0.20),
		GameData.ITEM_SEEDS: Color(0.35, 0.55, 0.28),
		GameData.ITEM_FRAMES: Color(0.58, 0.42, 0.18),
		GameData.ITEM_SUPER_BOX: Color(0.52, 0.36, 0.14),
		GameData.ITEM_BEEHIVE: Color(0.48, 0.32, 0.10),
		GameData.ITEM_HIVE_STAND: Color(0.55, 0.38, 0.18),
		GameData.ITEM_DEEP_BODY: Color(0.50, 0.34, 0.14),
		GameData.ITEM_LID: Color(0.44, 0.30, 0.10),
		GameData.ITEM_TREATMENT_OXALIC: Color(0.22, 0.52, 0.60),
		GameData.ITEM_TREATMENT_FORMIC: Color(0.22, 0.42, 0.72),
		GameData.ITEM_SYRUP_FEEDER: Color(0.30, 0.55, 0.65),
		GameData.ITEM_QUEEN_CAGE: Color(0.65, 0.55, 0.12),
		GameData.ITEM_HIVE_TOOL: Color(0.45, 0.40, 0.32),
		GameData.ITEM_PACKAGE_BEES: Color(0.72, 0.62, 0.18),
		GameData.ITEM_DEEP_BOX: Color(0.50, 0.35, 0.15),
		GameData.ITEM_QUEEN_EXCLUDER: Color(0.55, 0.56, 0.58),
		GameData.ITEM_FULL_SUPER: Color(0.75, 0.58, 0.15),
		GameData.ITEM_JAR: Color(0.60, 0.65, 0.70),
		GameData.ITEM_HONEY_BULK: Color(0.72, 0.50, 0.10),
		GameData.ITEM_FERMENTED_HONEY: Color(0.55, 0.35, 0.15),
		GameData.ITEM_CHEST: Color(0.55, 0.38, 0.22),
	}
	LONG_NAME = {
		GameData.ITEM_RAW_HONEY: "Raw Honey",
		GameData.ITEM_HONEY_JAR: "Honey Jar",
		GameData.ITEM_BEESWAX: "Beeswax",
		GameData.ITEM_POLLEN: "Pollen",
		GameData.ITEM_SEEDS: "Seeds",
		GameData.ITEM_FRAMES: "Frames",
		GameData.ITEM_SUPER_BOX: "Super Box",
		GameData.ITEM_BEEHIVE: "Hive (Complete)",
		GameData.ITEM_HIVE_STAND: "Hive Stand",
		GameData.ITEM_DEEP_BODY: "Deep Body",
		GameData.ITEM_LID: "Hive Lid",
		GameData.ITEM_TREATMENT_OXALIC: "Oxalic Acid",
		GameData.ITEM_TREATMENT_FORMIC: "Formic Acid",
		GameData.ITEM_SYRUP_FEEDER: "Syrup Feeder",
		GameData.ITEM_QUEEN_CAGE: "Queen Cage",
		GameData.ITEM_HIVE_TOOL: "Hive Tool",
		GameData.ITEM_PACKAGE_BEES: "Package Bees",
		GameData.ITEM_DEEP_BOX: "Deep Body (expansion)",
		GameData.ITEM_QUEEN_EXCLUDER: "Queen Excluder",
		GameData.ITEM_FULL_SUPER: "Full Honey Super",
		GameData.ITEM_JAR: "Empty Jar",
		GameData.ITEM_HONEY_BULK: "Bulk Honey (5lb)",
		GameData.ITEM_FERMENTED_HONEY: "Fermented Honey",
		GameData.ITEM_CHEST: "Storage Chest",
	}

# -- Lifecycle ----------------------------------------------------------------

func _ready() -> void:
	layer = 10
	add_to_group("chest_storage_overlay")
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_color_maps()
	_build_ui()
	_refresh()

# -- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()

	match event.keycode:
		KEY_W:
			if _focus == Focus.CHEST:
				_cursor_y = maxi(0, _cursor_y - 1)
			else:
				_focus = Focus.CHEST
				_cursor_y = GRID_ROWS - 1
		KEY_S:
			if _focus == Focus.CHEST:
				if _cursor_y < GRID_ROWS - 1:
					_cursor_y += 1
				else:
					_focus = Focus.PLAYER
					_cursor_y = 0
		KEY_A:
			_cursor_x = maxi(0, _cursor_x - 1)
		KEY_D:
			var max_x: int = GRID_COLS - 1 if _focus == Focus.CHEST else INV_COLS - 1
			_cursor_x = mini(max_x, _cursor_x + 1)
		KEY_Q:
			if _focus == Focus.CHEST:
				_focus = Focus.PLAYER
				_cursor_y = 0
			else:
				_focus = Focus.CHEST
				_cursor_y = 0
		KEY_E:
			var is_shift: bool = event.shift_pressed
			_transfer(is_shift)
		KEY_ESCAPE:
			_close()

	_refresh()

# -- Transfer logic -----------------------------------------------------------

func _transfer(single: bool) -> void:
	if chest_ref == null:
		return
	var player := _get_player()
	if player == null:
		return

	if _focus == Focus.CHEST:
		# Move from chest to player
		var slot_idx := _cursor_y * GRID_COLS + _cursor_x
		if slot_idx >= chest_ref.storage.size() or chest_ref.storage[slot_idx] == null:
			return
		var slot = chest_ref.storage[slot_idx]
		var amount: int = 1 if single else int(slot["count"])
		var leftover: int = player.add_item(slot["item"], amount)
		var taken: int = amount - leftover
		if taken > 0:
			chest_ref.remove_slot(slot_idx, taken)
		player.update_hud_inventory()
	else:
		# Move from player to chest
		var slot_idx := _cursor_x
		if slot_idx >= player.inventory.size() or player.inventory[slot_idx] == null:
			return
		var slot = player.inventory[slot_idx]
		var amount: int = 1 if single else int(slot["count"])
		var item_name: String = slot["item"]
		var leftover: int = chest_ref.add_item(item_name, amount)
		var taken: int = amount - leftover
		if taken > 0:
			player.consume_item(item_name, taken)
		player.update_hud_inventory()

# -- Close --------------------------------------------------------------------

func _close() -> void:
	get_tree().paused = false
	queue_free()

func _get_player() -> Node:
	var list := get_tree().get_nodes_in_group("player")
	return list[0] if list.size() > 0 else null

# -- Refresh display ----------------------------------------------------------

func _refresh() -> void:
	# Chest grid
	if chest_ref:
		for i in CHEST_SLOTS:
			var slot = chest_ref.storage[i] if i < chest_ref.storage.size() else null
			if slot != null:
				_chest_slot_rects[i].color = SLOT_COLORS.get(slot["item"], Color(0.35, 0.28, 0.12))
				_chest_count_lbls[i].text = "x%d" % slot["count"]
			else:
				_chest_slot_rects[i].color = C_SLOT_EMPTY
				_chest_count_lbls[i].text = ""

	# Player inventory
	var player := _get_player()
	if player:
		for i in INV_COLS:
			var slot = player.inventory[i] if i < player.inventory.size() else null
			if slot != null:
				_inv_slot_rects[i].color = SLOT_COLORS.get(slot["item"], Color(0.35, 0.28, 0.12))
				_inv_count_lbls[i].text = "x%d" % slot["count"]
			else:
				_inv_slot_rects[i].color = C_SLOT_EMPTY
				_inv_count_lbls[i].text = ""

	# Cursor position
	if _cursor_panel:
		var cx: float
		var cy: float
		if _focus == Focus.CHEST:
			cx = PANEL_X + GRID_X + _cursor_x * SLOT_STEP - 1
			cy = PANEL_Y + GRID_Y + _cursor_y * SLOT_STEP - 1
		else:
			cx = PANEL_X + GRID_X + _cursor_x * SLOT_STEP - 1
			cy = PANEL_Y + INV_Y + _cursor_y * SLOT_STEP - 1
		_cursor_panel.position = Vector2(cx, cy)

	# Info label: show item name under cursor
	if _info_lbl:
		var slot_data = _get_cursor_slot()
		if slot_data != null:
			var name_str: String = LONG_NAME.get(slot_data["item"], slot_data["item"].capitalize())
			_info_lbl.text = "%s (x%d)" % [name_str, slot_data["count"]]
		else:
			_info_lbl.text = ""

func _get_cursor_slot():
	if _focus == Focus.CHEST and chest_ref:
		var idx := _cursor_y * GRID_COLS + _cursor_x
		if idx < chest_ref.storage.size():
			return chest_ref.storage[idx]
	elif _focus == Focus.PLAYER:
		var player := _get_player()
		if player and _cursor_x < player.inventory.size():
			return player.inventory[_cursor_x]
	return null

# -- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	# Dim backdrop
	var dim := ColorRect.new()
	dim.anchor_right  = 1.0
	dim.anchor_bottom = 1.0
	dim.color         = Color(0, 0, 0, 0.55)
	dim.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Main panel
	var panel := ColorRect.new()
	panel.position = Vector2(PANEL_X, PANEL_Y)
	panel.size     = Vector2(PANEL_W, PANEL_H)
	panel.color    = C_PANEL_BG
	add_child(panel)

	# Border
	var border := Panel.new()
	border.position = Vector2(PANEL_X, PANEL_Y)
	border.size     = Vector2(PANEL_W, PANEL_H)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty := StyleBoxFlat.new()
	sty.bg_color           = Color(0, 0, 0, 0)
	sty.draw_center        = false
	sty.border_color       = C_BORDER
	sty.border_width_left  = 1
	sty.border_width_right = 1
	sty.border_width_top   = 1
	sty.border_width_bottom = 1
	border.add_theme_stylebox_override("panel", sty)
	add_child(border)

	# Title
	var title := _make_label("-- STORAGE CHEST --", FONT_MD, C_GOLD)
	title.position             = Vector2(PANEL_X, PANEL_Y + 5)
	title.custom_minimum_size  = Vector2(PANEL_W, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Chest label
	var chest_lbl := _make_label("Chest", FONT_SM, C_DIM)
	chest_lbl.position = Vector2(PANEL_X + GRID_X, PANEL_Y + GRID_Y - 9)
	add_child(chest_lbl)

	# Chest grid (10x5 = 50 slots)
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var sx := PANEL_X + GRID_X + col * SLOT_STEP
			var sy := PANEL_Y + GRID_Y + row * SLOT_STEP
			var slot_rect := ColorRect.new()
			slot_rect.position = Vector2(sx, sy)
			slot_rect.size     = Vector2(SLOT_SIZE, SLOT_SIZE)
			slot_rect.color    = C_SLOT_EMPTY
			add_child(slot_rect)

			var count_lbl := _make_label("", 4, C_TEXT)
			count_lbl.position = Vector2(1, 7)
			count_lbl.custom_minimum_size = Vector2(SLOT_SIZE - 2, 6)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slot_rect.add_child(count_lbl)

			_chest_slot_rects.append(slot_rect)
			_chest_count_lbls.append(count_lbl)

	# Divider
	var div_y := PANEL_Y + GRID_Y + GRID_ROWS * SLOT_STEP + 4
	var div := ColorRect.new()
	div.position = Vector2(PANEL_X + 4, div_y)
	div.size     = Vector2(PANEL_W - 8, 1)
	div.color    = Color(0.75, 0.60, 0.20, 0.5)
	add_child(div)

	# Player inventory label
	var inv_lbl := _make_label("Inventory", FONT_SM, C_DIM)
	inv_lbl.position = Vector2(PANEL_X + GRID_X, PANEL_Y + INV_Y - 9)
	add_child(inv_lbl)

	# Player inventory row (10 slots)
	for col in INV_COLS:
		var sx := PANEL_X + GRID_X + col * SLOT_STEP
		var sy := PANEL_Y + INV_Y
		var slot_rect := ColorRect.new()
		slot_rect.position = Vector2(sx, sy)
		slot_rect.size     = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_rect.color    = C_SLOT_EMPTY
		add_child(slot_rect)

		var count_lbl := _make_label("", 4, C_TEXT)
		count_lbl.position = Vector2(1, 7)
		count_lbl.custom_minimum_size = Vector2(SLOT_SIZE - 2, 6)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot_rect.add_child(count_lbl)

		_inv_slot_rects.append(slot_rect)
		_inv_count_lbls.append(count_lbl)

	# Cursor highlight
	_cursor_panel = Panel.new()
	_cursor_panel.size = Vector2(SLOT_SIZE + 2, SLOT_SIZE + 2)
	_cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cursor_sty := StyleBoxFlat.new()
	cursor_sty.bg_color           = Color(0, 0, 0, 0)
	cursor_sty.draw_center        = false
	cursor_sty.border_color       = C_CURSOR
	cursor_sty.border_width_left  = 2
	cursor_sty.border_width_right = 2
	cursor_sty.border_width_top   = 2
	cursor_sty.border_width_bottom = 2
	_cursor_panel.add_theme_stylebox_override("panel", cursor_sty)
	add_child(_cursor_panel)

	# Info label (item name under cursor)
	_info_lbl = _make_label("", FONT_SM, C_TEXT)
	_info_lbl.position             = Vector2(PANEL_X + GRID_X + GRID_COLS * SLOT_STEP + 8, PANEL_Y + GRID_Y)
	_info_lbl.custom_minimum_size  = Vector2(110, 40)
	_info_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info_lbl)

	# Hint bar
	_hint_lbl = _make_label("WASD Move  E Transfer  Shift+E x1  Q Switch  Esc Close",
							FONT_SM, C_DIM)
	_hint_lbl.position             = Vector2(PANEL_X + 4, PANEL_Y + PANEL_H - 14)
	_hint_lbl.custom_minimum_size  = Vector2(PANEL_W - 8, 10)
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint_lbl)

# -- Helper -------------------------------------------------------------------

func _make_label(text_val: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text_val
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
