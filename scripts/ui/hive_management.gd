# hive_management.gd -- Hive Management UI overlay.
# Opened when player has Gloves active and presses E near a colonized hive.
# Allows: add deep bodies (max 2, locked once added), add honey supers
# (max 10), remove the top super for harvest transport, toggle queen
# excluder, and rotate deeps (swap bottom to top).
# All box operations consume items from inventory and call hive.gd methods.
extends CanvasLayer

# -- External references (set before adding to tree) -------------------------
var hive_ref: Node = null   # The Hive node (scripts/world/hive.gd)

# -- Internal state ----------------------------------------------------------
var _panel: ColorRect = null
var _title_lbl: Label = null
var _info_lbl: Label = null
var _btn_add_deep: Button = null
var _btn_add_super: Button = null
var _btn_remove_super: Button = null
var _btn_add_excluder: Button = null
var _btn_rotate: Button = null
var _status_lbl: Label = null

const PANEL_W: int = 300
const PANEL_H: int = 220

func _ready() -> void:
	add_to_group("hive_management_overlay")
	layer = 50
	_build_ui()
	_refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_X:
			_close()
			get_viewport().set_input_as_handled()

# -- UI Construction ---------------------------------------------------------

func _build_ui() -> void:
	# Dark overlay
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(15)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Main panel -- warm brown
	_panel = ColorRect.new()
	_panel.name = "MgmtPanel"
	_panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -PANEL_W / 2)
	_panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  PANEL_W / 2)
	_panel.set_anchor_and_offset(SIDE_TOP,    0.5, -PANEL_H / 2)
	_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  PANEL_H / 2)
	_panel.color = Color(0.22, 0.15, 0.08, 0.95)
	add_child(_panel)

	# Title
	_title_lbl = Label.new()
	_title_lbl.name = "Title"
	_title_lbl.text = "Hive Management"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.50))
	_title_lbl.add_theme_font_size_override("font_size", 11)
	_title_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -140)
	_title_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  140)
	_title_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, -108)
	_title_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  -92)
	add_child(_title_lbl)

	# Info label (shows current hive config -- deeps / supers / excluder)
	_info_lbl = Label.new()
	_info_lbl.name = "InfoLabel"
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.50))
	_info_lbl.add_theme_font_size_override("font_size", 8)
	_info_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -140)
	_info_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  140)
	_info_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,  -90)
	_info_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  -74)
	add_child(_info_lbl)

	# Buttons -- 5 action buttons, 20px tall, 3px gap
	# Span: -70 to +42 (5*20 + 4*3 = 112px)
	var btn_y: int = -70
	var btn_h: int = 20
	var btn_gap: int = 3

	_btn_add_deep     = _make_button("BtnAddDeep",     btn_y); btn_y += btn_h + btn_gap
	_btn_add_super    = _make_button("BtnAddSuper",    btn_y); btn_y += btn_h + btn_gap
	_btn_remove_super = _make_button("BtnRemoveSuper", btn_y); btn_y += btn_h + btn_gap
	_btn_add_excluder = _make_button("BtnAddExcluder", btn_y); btn_y += btn_h + btn_gap
	_btn_rotate       = _make_button("BtnRotate",      btn_y)

	_btn_add_deep.pressed.connect(_on_add_deep)
	_btn_add_super.pressed.connect(_on_add_super)
	_btn_remove_super.pressed.connect(_on_remove_super)
	_btn_add_excluder.pressed.connect(_on_add_excluder)
	_btn_rotate.pressed.connect(_on_rotate)

	# Status toast
	_status_lbl = Label.new()
	_status_lbl.name = "StatusLbl"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.45))
	_status_lbl.add_theme_font_size_override("font_size", 8)
	_status_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -140)
	_status_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  140)
	_status_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,   56)
	_status_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   72)
	_status_lbl.text = ""
	add_child(_status_lbl)

	# Close hint
	var close_lbl: Label = Label.new()
	close_lbl.name = "CloseHint"
	close_lbl.text = "[ESC] Close"
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35))
	close_lbl.add_theme_font_size_override("font_size", 7)
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -140)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  140)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,   76)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   90)
	add_child(close_lbl)

func _make_button(btn_name: String, y_offset: int) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -130)
	btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  130)
	btn.set_anchor_and_offset(SIDE_TOP,    0.5,  y_offset)
	btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  y_offset + 20)
	btn.add_theme_color_override("font_color", Color(0.88, 0.80, 0.58))
	btn.add_theme_font_size_override("font_size", 8)
	add_child(btn)
	return btn

# -- Refresh UI state --------------------------------------------------------

func _refresh() -> void:
	if not hive_ref or not is_instance_valid(hive_ref):
		return
	var sim: Node = hive_ref.get("simulation")
	if not sim:
		return

	var deeps: int = sim.deep_count() if sim.has_method("deep_count") else 1
	var supers: int = sim.super_count() if sim.has_method("super_count") else 0
	var has_excl: bool = false
	var excl_val = sim.get("has_excluder")
	if excl_val != null:
		has_excl = bool(excl_val)

	_info_lbl.text = "Deeps: %d/2   Supers: %d/10   Excluder: %s" % [
		deeps, supers, "Yes" if has_excl else "No"
	]

	var has_deep_item: bool = _player_has_item(GameData.ITEM_DEEP_BOX) or _player_has_item(GameData.ITEM_DEEP_BODY)
	var has_super_item: bool = _player_has_item(GameData.ITEM_SUPER_BOX)
	var has_excl_item: bool = _player_has_item(GameData.ITEM_QUEEN_EXCLUDER)

	# Add Deep button
	if deeps >= 2:
		_btn_add_deep.text = "Add Deep Body  [max 2/2]"
		_btn_add_deep.disabled = true
	elif not has_deep_item:
		_btn_add_deep.text = "Add Deep Body  [need Deep Body]"
		_btn_add_deep.disabled = true
	else:
		_btn_add_deep.text = "Add Deep Body"
		_btn_add_deep.disabled = false

	# Add Super button
	if supers >= 10:
		_btn_add_super.text = "Add Honey Super  [max 10/10]"
		_btn_add_super.disabled = true
	elif not has_super_item:
		_btn_add_super.text = "Add Honey Super  [need Super Box]"
		_btn_add_super.disabled = true
	else:
		_btn_add_super.text = "Add Honey Super  (%d/10)" % supers
		_btn_add_super.disabled = false

	# Remove Super button
	if supers <= 0:
		_btn_remove_super.text = "Remove Super  [none on hive]"
		_btn_remove_super.disabled = true
	else:
		_btn_remove_super.text = "Remove Super for Harvest"
		_btn_remove_super.disabled = false

	# Excluder button
	if has_excl:
		_btn_add_excluder.text = "Add Queen Excluder  [installed]"
		_btn_add_excluder.disabled = true
	elif not has_excl_item:
		_btn_add_excluder.text = "Add Queen Excluder  [need item]"
		_btn_add_excluder.disabled = true
	else:
		_btn_add_excluder.text = "Add Queen Excluder"
		_btn_add_excluder.disabled = false

	# Rotate button
	if deeps < 2:
		_btn_rotate.text = "Rotate Deeps  [need 2 deeps]"
		_btn_rotate.disabled = true
	else:
		_btn_rotate.text = "Rotate Deeps"
		_btn_rotate.disabled = false

	_update_btn_colors()

func _update_btn_colors() -> void:
	var btns: Array = [_btn_add_deep, _btn_add_super, _btn_remove_super, _btn_add_excluder, _btn_rotate]
	for btn in btns:
		if btn.disabled:
			btn.add_theme_color_override("font_color", Color(0.45, 0.40, 0.30, 0.55))
		else:
			btn.add_theme_color_override("font_color", Color(0.88, 0.80, 0.58))

# -- Actions -----------------------------------------------------------------

func _on_add_deep() -> void:
	var player: Node = _get_player()
	if not player:
		return
	if not player.has_method("consume_item"):
		return
	# Accept either deep_body or deep_box
	var consumed: bool = player.consume_item(GameData.ITEM_DEEP_BOX, 1)
	if not consumed:
		consumed = player.consume_item(GameData.ITEM_DEEP_BODY, 1)
	if not consumed:
		_show_status("No Deep Body in inventory!")
		return
	if hive_ref.has_method("try_add_deep"):
		hive_ref.try_add_deep()
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_show_status("Deep body added!")
	_refresh()

func _on_add_super() -> void:
	var player: Node = _get_player()
	if not player:
		return
	if not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_SUPER_BOX, 1):
		_show_status("No Super Box in inventory!")
		return
	var added: bool = false
	if hive_ref.has_method("try_add_super"):
		added = hive_ref.try_add_super()
	if not added:
		# Refund the consumed item
		if player.has_method("add_item"):
			player.add_item(GameData.ITEM_SUPER_BOX, 1)
		_show_status("Cannot add super (hive not ready or max reached)")
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
		_refresh()
		return
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_show_status("Honey super added!")
	_refresh()

func _on_remove_super() -> void:
	var player: Node = _get_player()
	if not player:
		return
	if not hive_ref.has_method("try_remove_top_super"):
		_show_status("Remove super not supported!")
		return
	var removed: Object = hive_ref.try_remove_top_super()
	if removed == null:
		_show_status("No supers to remove!")
		return
	if player.has_method("add_item"):
		player.add_item(GameData.ITEM_FULL_SUPER, 1)
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_show_status("Super removed -- take it to the Honey House!")
	_refresh()

func _on_add_excluder() -> void:
	var player: Node = _get_player()
	if not player:
		return
	if not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_QUEEN_EXCLUDER, 1):
		_show_status("No Queen Excluder in inventory!")
		return
	if hive_ref.has_method("try_add_excluder"):
		hive_ref.try_add_excluder()
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_show_status("Queen excluder installed!")
	_refresh()

func _on_rotate() -> void:
	if hive_ref.has_method("try_rotate_deeps"):
		if hive_ref.try_rotate_deeps():
			_show_status("Deeps rotated -- bottom box moved to top!")
		else:
			_show_status("Cannot rotate -- need 2 deep bodies.")
	_refresh()

# -- Helpers -----------------------------------------------------------------

func _get_player() -> Node:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _player_has_item(item_name: String) -> bool:
	var player: Node = _get_player()
	if not player:
		return false
	if player.has_method("count_item"):
		return player.count_item(item_name) > 0
	# Fallback: check inventory array directly
	var inv: Array = player.get("inventory") as Array
	if inv == null:
		return false
	for slot in inv:
		if slot != null and slot is Dictionary and slot.get("item", "") == item_name:
			return true
	return false

func _show_status(msg: String) -> void:
	if _status_lbl:
		_status_lbl.text = msg

func _close() -> void:
	queue_free()
