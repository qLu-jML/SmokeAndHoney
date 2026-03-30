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

# -- Drag-and-drop state -----------------------------------------------------
var _drag_active: bool = false
var _drag_item: String = ""             # Item ID being dragged
var _drag_count: int = 0                # Stack count being dragged
var _drag_source_focus: Focus = Focus.CHEST  # Where the item came from
var _drag_source_slot: int = 0          # Slot index in source
var _drag_icon: TextureRect = null      # Floating icon following mouse
var _drag_count_lbl: Label = null       # Count label on floating icon

# -- UI refs ------------------------------------------------------------------
var _chest_slot_rects: Array = []
var _chest_slot_icons: Array = []
var _chest_count_lbls: Array = []
var _inv_slot_rects:   Array = []
var _inv_slot_icons:   Array = []
var _inv_count_lbls:   Array = []
var _cursor_panel:     Panel = null
var _info_lbl:         Label = null
var _hint_lbl:         Label = null

# Loaded item textures (item_id -> Texture2D)
var _item_textures: Dictionary = {}

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
	_load_item_textures()
	_build_ui()
	_refresh()

func _load_item_textures() -> void:
	var ITEM_SPRITE_MAP: Dictionary = {
		GameData.ITEM_RAW_HONEY: "raw_honey.png",
		GameData.ITEM_HONEY_JAR: "honey_jar_standard.png",
		GameData.ITEM_BEESWAX: "beeswax.png",
		GameData.ITEM_POLLEN: "pollen.png",
		GameData.ITEM_SEEDS: "seeds.png",
		GameData.ITEM_FRAMES: "frames.png",
		GameData.ITEM_SUPER_BOX: "super_box.png",
		GameData.ITEM_BEEHIVE: "beehive.png",
		GameData.ITEM_HIVE_STAND: "hive_stand.png",
		GameData.ITEM_DEEP_BODY: "deep_body.png",
		GameData.ITEM_LID: "hive_lid.png",
		GameData.ITEM_TREATMENT_OXALIC: "treatment_oxalic.png",
		GameData.ITEM_TREATMENT_FORMIC: "treatment_formic.png",
		GameData.ITEM_SYRUP_FEEDER: "syrup_feeder.png",
		GameData.ITEM_QUEEN_CAGE: "queen_cage.png",
		GameData.ITEM_HIVE_TOOL: "hive_tool.png",
		GameData.ITEM_PACKAGE_BEES: "package_bees.png",
		GameData.ITEM_DEEP_BOX: "deep_box.png",
		GameData.ITEM_QUEEN_EXCLUDER: "queen_excluder.png",
		GameData.ITEM_FULL_SUPER: "full_super.png",
		GameData.ITEM_JAR: "jar.png",
		GameData.ITEM_HONEY_BULK: "honey_bulk.png",
		GameData.ITEM_FERMENTED_HONEY: "fermented_honey.png",
		GameData.ITEM_CHEST: "chest.png",
		GameData.ITEM_SUGAR_SYRUP: "sugar_syrup.png",
		GameData.ITEM_GLOVES: "gloves.png",
		GameData.ITEM_COMB_SCRAPER: "uncapping_knife.png",
	}
	for item_id in ITEM_SPRITE_MAP:
		var p: String = "res://assets/sprites/items/%s" % ITEM_SPRITE_MAP[item_id]
		if ResourceLoader.exists(p):
			_item_textures[item_id] = load(p)

# -- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# ---- Mouse input (drag-and-drop) ----------------------------------------
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_mouse_click(event.position, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_mouse_click(event.position, true)
		_refresh()
		return

	if event is InputEventMouseMotion:
		_on_mouse_move(event.position)
		# Update cursor position to match hovered slot
		_update_cursor_from_mouse(event.position)
		return

	# ---- Keyboard input (original controls) ---------------------------------
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()

	# Cancel drag on ESC
	if event.keycode == KEY_ESCAPE:
		if _drag_active:
			_cancel_drag()
		else:
			_close()
		_refresh()
		return

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

# -- Mouse drag-and-drop ------------------------------------------------------

## Handle a mouse click at the given screen position.
## single_item: true = right-click (pick up / drop 1 item), false = left-click (full stack)
func _on_mouse_click(pos: Vector2, single_item: bool) -> void:
	var hit: Dictionary = _slot_at_position(pos)
	if hit.is_empty():
		# Clicked outside any slot -- cancel drag if active
		if _drag_active:
			_cancel_drag()
		return

	var hit_focus: Focus = hit["focus"] as Focus
	var hit_slot: int = hit["slot"]

	if not _drag_active:
		# -- PICK UP from slot --
		_pickup_from_slot(hit_focus, hit_slot, single_item)
	else:
		# -- DROP onto slot --
		_drop_onto_slot(hit_focus, hit_slot, single_item)

## Pick up an item stack (or single) from a slot to start dragging
func _pickup_from_slot(source_focus: Focus, slot_idx: int, single: bool) -> void:
	var slot_data = _read_slot(source_focus, slot_idx)
	if slot_data == null:
		return

	var amount: int = 1 if single else int(slot_data["count"])
	_drag_active = true
	_drag_item = slot_data["item"]
	_drag_count = amount
	_drag_source_focus = source_focus
	_drag_source_slot = slot_idx

	# Remove from source
	_remove_from_slot(source_focus, slot_idx, amount)

	# Show floating drag icon
	_show_drag_icon()
	_refresh()

## Drop the dragged item onto a target slot
func _drop_onto_slot(target_focus: Focus, target_slot: int, single: bool) -> void:
	var drop_count: int = 1 if single else _drag_count
	drop_count = mini(drop_count, _drag_count)

	var target_data = _read_slot(target_focus, target_slot)
	var actually_placed: int = 0

	if target_data == null:
		# Empty slot -- place items directly
		actually_placed = _place_into_slot(target_focus, target_slot, _drag_item, drop_count)
	elif target_data["item"] == _drag_item:
		# Same item -- try to merge stacks
		actually_placed = _merge_into_slot(target_focus, target_slot, _drag_item, drop_count)
	else:
		# Different item -- swap if dropping full stack
		if not single and drop_count == _drag_count:
			_swap_with_slot(target_focus, target_slot)
			return
		else:
			# Cannot merge different items with partial drop -- do nothing
			return

	_drag_count -= actually_placed
	if _drag_count <= 0:
		_end_drag()
	else:
		_update_drag_label()

	_refresh()
	# Sync player HUD
	var player := _get_player()
	if player and player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

## Swap dragged item with a different item in the target slot
func _swap_with_slot(target_focus: Focus, target_slot: int) -> void:
	var target_data = _read_slot(target_focus, target_slot)
	if target_data == null:
		return

	# Pick up the target slot contents
	var swap_item: String = target_data["item"]
	var swap_count: int = target_data["count"]

	# Place the dragged item into the target slot
	_clear_slot(target_focus, target_slot)
	_place_into_slot(target_focus, target_slot, _drag_item, _drag_count)

	# The swapped item becomes the new drag
	_drag_item = swap_item
	_drag_count = swap_count
	_update_drag_icon()
	_refresh()
	var player := _get_player()
	if player and player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

## Move the floating drag icon with the mouse
func _on_mouse_move(pos: Vector2) -> void:
	if _drag_active and _drag_icon:
		_drag_icon.position = pos - Vector2(7, 7)

## Update keyboard cursor position to match which slot the mouse is hovering
func _update_cursor_from_mouse(pos: Vector2) -> void:
	var hit: Dictionary = _slot_at_position(pos)
	if hit.is_empty():
		return
	_focus = hit["focus"] as Focus
	if _focus == Focus.CHEST:
		_cursor_x = hit["slot"] % GRID_COLS
		_cursor_y = hit["slot"] / GRID_COLS
	else:
		_cursor_x = hit["slot"]
		_cursor_y = 0
	_refresh()

## Cancel the current drag -- return items to source
func _cancel_drag() -> void:
	if not _drag_active:
		return
	# Return items to source slot
	_place_into_slot(_drag_source_focus, _drag_source_slot, _drag_item, _drag_count)
	_end_drag()
	_refresh()
	var player := _get_player()
	if player and player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

func _end_drag() -> void:
	_drag_active = false
	_drag_item = ""
	_drag_count = 0
	if _drag_icon:
		_drag_icon.queue_free()
		_drag_icon = null
		_drag_count_lbl = null

func _show_drag_icon() -> void:
	if _drag_icon:
		_drag_icon.queue_free()

	_drag_icon = TextureRect.new()
	_drag_icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.z_index = 50
	_drag_icon.modulate = Color(1, 1, 1, 0.85)

	var tex = _item_textures.get(_drag_item, null)
	if tex:
		_drag_icon.texture = tex
	else:
		# Fallback: tinted rect
		var fallback := ColorRect.new()
		fallback.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		fallback.color = SLOT_COLORS.get(_drag_item, Color(0.5, 0.4, 0.2))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_icon.add_child(fallback)

	# Count label on the drag icon
	_drag_count_lbl = _make_label("x%d" % _drag_count, 4, C_TEXT)
	_drag_count_lbl.position = Vector2(1, 7)
	_drag_count_lbl.custom_minimum_size = Vector2(SLOT_SIZE - 2, 6)
	_drag_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_drag_icon.add_child(_drag_count_lbl)

	add_child(_drag_icon)

func _update_drag_icon() -> void:
	if not _drag_icon:
		_show_drag_icon()
		return
	var tex = _item_textures.get(_drag_item, null)
	if tex:
		_drag_icon.texture = tex
		# Remove any fallback children
		for c in _drag_icon.get_children():
			if c is ColorRect:
				c.queue_free()
	_update_drag_label()

func _update_drag_label() -> void:
	if _drag_count_lbl:
		_drag_count_lbl.text = "x%d" % _drag_count

# -- Slot read/write helpers (abstract over chest vs player inventory) --------

## Returns the slot data dict at a given focus+index, or null
func _read_slot(focus: Focus, slot_idx: int):
	if focus == Focus.CHEST:
		if chest_ref and slot_idx >= 0 and slot_idx < chest_ref.storage.size():
			return chest_ref.storage[slot_idx]
	else:
		var player := _get_player()
		if player and slot_idx >= 0 and slot_idx < player.inventory.size():
			return player.inventory[slot_idx]
	return null

## Remove a number of items from a specific slot
func _remove_from_slot(focus: Focus, slot_idx: int, amount: int) -> void:
	if focus == Focus.CHEST:
		if chest_ref:
			chest_ref.remove_slot(slot_idx, amount)
	else:
		var player := _get_player()
		if player and slot_idx >= 0 and slot_idx < player.inventory.size():
			var slot = player.inventory[slot_idx]
			if slot != null:
				slot["count"] -= amount
				if slot["count"] <= 0:
					player.inventory[slot_idx] = null

## Place items directly into a specific empty slot. Returns how many were placed.
func _place_into_slot(focus: Focus, slot_idx: int, item_name: String, amount: int) -> int:
	var player := _get_player()
	var max_stack: int = 20
	if player and player.has_method("get_max_stack"):
		max_stack = player.get_max_stack(item_name)

	var to_place: int = mini(amount, max_stack)

	if focus == Focus.CHEST:
		if chest_ref and slot_idx >= 0 and slot_idx < chest_ref.storage.size():
			if chest_ref.storage[slot_idx] == null:
				chest_ref.storage[slot_idx] = {"item": item_name, "count": to_place}
				return to_place
			elif chest_ref.storage[slot_idx]["item"] == item_name:
				var space: int = max_stack - chest_ref.storage[slot_idx]["count"]
				var add: int = mini(to_place, space)
				chest_ref.storage[slot_idx]["count"] += add
				return add
	else:
		if player and slot_idx >= 0 and slot_idx < player.inventory.size():
			if player.inventory[slot_idx] == null:
				player.inventory[slot_idx] = {"item": item_name, "count": to_place}
				return to_place
			elif player.inventory[slot_idx]["item"] == item_name:
				var space: int = max_stack - player.inventory[slot_idx]["count"]
				var add: int = mini(to_place, space)
				player.inventory[slot_idx]["count"] += add
				return add
	return 0

## Merge items into a slot that already has the same item. Returns how many merged.
func _merge_into_slot(focus: Focus, slot_idx: int, item_name: String, amount: int) -> int:
	return _place_into_slot(focus, slot_idx, item_name, amount)

## Clear a slot completely
func _clear_slot(focus: Focus, slot_idx: int) -> void:
	if focus == Focus.CHEST:
		if chest_ref and slot_idx >= 0 and slot_idx < chest_ref.storage.size():
			chest_ref.storage[slot_idx] = null
	else:
		var player := _get_player()
		if player and slot_idx >= 0 and slot_idx < player.inventory.size():
			player.inventory[slot_idx] = null

## Determine which slot (if any) the given screen position is over.
## Returns {"focus": Focus, "slot": int} or {} if not over any slot.
func _slot_at_position(pos: Vector2) -> Dictionary:
	# Check chest grid slots
	var chest_origin_x: float = float(PANEL_X + GRID_X)
	var chest_origin_y: float = float(PANEL_Y + GRID_Y)
	var grid_w: float = float(GRID_COLS * SLOT_STEP)
	var grid_h: float = float(GRID_ROWS * SLOT_STEP)

	if pos.x >= chest_origin_x and pos.x < chest_origin_x + grid_w:
		if pos.y >= chest_origin_y and pos.y < chest_origin_y + grid_h:
			var col: int = int((pos.x - chest_origin_x) / float(SLOT_STEP))
			var row: int = int((pos.y - chest_origin_y) / float(SLOT_STEP))
			col = clampi(col, 0, GRID_COLS - 1)
			row = clampi(row, 0, GRID_ROWS - 1)
			return {"focus": Focus.CHEST, "slot": row * GRID_COLS + col}

	# Check player inventory row
	var inv_origin_x: float = float(PANEL_X + GRID_X)
	var inv_origin_y: float = float(PANEL_Y + INV_Y)
	var inv_w: float = float(INV_COLS * SLOT_STEP)
	var inv_h: float = float(SLOT_STEP)

	if pos.x >= inv_origin_x and pos.x < inv_origin_x + inv_w:
		if pos.y >= inv_origin_y and pos.y < inv_origin_y + inv_h:
			var col: int = int((pos.x - inv_origin_x) / float(SLOT_STEP))
			col = clampi(col, 0, INV_COLS - 1)
			return {"focus": Focus.PLAYER, "slot": col}

	return {}

# -- Close --------------------------------------------------------------------

func _close() -> void:
	# Return any dragged items before closing
	if _drag_active:
		_cancel_drag()
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
				var tex = _item_textures.get(slot["item"], null)
				if tex != null:
					_chest_slot_icons[i].texture = tex
					_chest_slot_icons[i].visible = true
					_chest_slot_rects[i].color = C_SLOT_EMPTY
				else:
					_chest_slot_icons[i].visible = false
					_chest_slot_rects[i].color = SLOT_COLORS.get(slot["item"], Color(0.35, 0.28, 0.12))
				_chest_count_lbls[i].text = "x%d" % slot["count"]
			else:
				_chest_slot_icons[i].visible = false
				_chest_slot_rects[i].color = C_SLOT_EMPTY
				_chest_count_lbls[i].text = ""

	# Player inventory
	var player := _get_player()
	if player:
		for i in INV_COLS:
			var slot = player.inventory[i] if i < player.inventory.size() else null
			if slot != null:
				var tex = _item_textures.get(slot["item"], null)
				if tex != null:
					_inv_slot_icons[i].texture = tex
					_inv_slot_icons[i].visible = true
					_inv_slot_rects[i].color = C_SLOT_EMPTY
				else:
					_inv_slot_icons[i].visible = false
					_inv_slot_rects[i].color = SLOT_COLORS.get(slot["item"], Color(0.35, 0.28, 0.12))
				_inv_count_lbls[i].text = "x%d" % slot["count"]
			else:
				_inv_slot_icons[i].visible = false
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

	# Info label: show item name under cursor (or drag info)
	if _info_lbl:
		if _drag_active:
			var name_str: String = LONG_NAME.get(_drag_item, _drag_item.capitalize())
			_info_lbl.text = "Holding: %s (x%d)" % [name_str, _drag_count]
		else:
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

			var icon := TextureRect.new()
			icon.position = Vector2.ZERO
			icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.visible = false
			slot_rect.add_child(icon)

			var count_lbl := _make_label("", 4, C_TEXT)
			count_lbl.position = Vector2(1, 7)
			count_lbl.custom_minimum_size = Vector2(SLOT_SIZE - 2, 6)
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slot_rect.add_child(count_lbl)

			_chest_slot_rects.append(slot_rect)
			_chest_slot_icons.append(icon)
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

		var icon := TextureRect.new()
		icon.position = Vector2.ZERO
		icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot_rect.add_child(icon)

		var count_lbl := _make_label("", 4, C_TEXT)
		count_lbl.position = Vector2(1, 7)
		count_lbl.custom_minimum_size = Vector2(SLOT_SIZE - 2, 6)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot_rect.add_child(count_lbl)

		_inv_slot_rects.append(slot_rect)
		_inv_slot_icons.append(icon)
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
	_hint_lbl = _make_label("Click Drag | Right-Click x1 | WASD+E | Esc Close",
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
