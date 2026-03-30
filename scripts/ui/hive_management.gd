# hive_management.gd -- Hive Management UI overlay.
# Opened when player has Gloves active and presses E near a colonized hive.
# Allows: add deep bodies (max 2, locked once added), add honey supers
# (max 10), toggle queen excluder, rotate deeps (swap bottom to top).
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
var _btn_add_excluder: Button = null
var _btn_rotate: Button = null
var _btn_close: Button = null
var _status_lbl: Label = null

const PANEL_W: int = 240
const PANEL_H: int = 150

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
	_title_lbl.add_theme_font_size_override("font_size", 10)
	_title_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -115)
	_title_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  115)
	_title_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, -(PANEL_H / 2) + 4)
	_title_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -(PANEL_H / 2) + 18)
	add_child(_title_lbl)

	# Info label (shows current hive config)
	_info_lbl = Label.new()
	_info_lbl.name = "InfoLabel"
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.50))
	_info_lbl.add_theme_font_size_override("font_size", 7)
	_info_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -115)
	_info_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  115)
	_info_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, -(PANEL_H / 2) + 18)
	_info_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -(PANEL_H / 2) + 34)
	add_child(_info_lbl)

	# Buttons -- 4 action buttons in a vertical column
	var btn_y: int = -(PANEL_H / 2) + 36
	var btn_h: int = 20
	var btn_gap: int = 3

	_btn_add_deep = _make_button("BtnAddDeep", btn_y)
	btn_y += btn_h + btn_gap
	_btn_add_super = _make_button("BtnAddSuper", btn_y)
	btn_y += btn_h + btn_gap
	_btn_add_excluder = _make_button("BtnAddExcluder", btn_y)
	btn_y += btn_h + btn_gap
	_btn_rotate = _make_button("BtnRotate", btn_y)

	_btn_add_deep.pressed.connect(_on_add_deep)
	_btn_add_super.pressed.connect(_on_add_super)
	_btn_add_excluder.pressed.connect(_on_add_excluder)
	_btn_rotate.pressed.connect(_on_rotate)

	# Status toast
	_status_lbl = Label.new()
	_status_lbl.name = "StatusLbl"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.45))
	_status_lbl.add_theme_font_size_override("font_size", 7)
	_status_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -115)
	_status_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  115)
	_status_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, (PANEL_H / 2) - 26)
	_status_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5, (PANEL_H / 2) - 14)
	_status_lbl.text = ""
	add_child(_status_lbl)

	# Close hint
	var close_lbl: Label = Label.new()
	close_lbl.name = "CloseHint"
	close_lbl.text = "[ESC] Close"
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35))
	close_lbl.add_theme_font_size_override("font_size", 6)
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -115)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  115)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, (PANEL_H / 2) - 14)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5, (PANEL_H / 2) - 2)
	add_child(close_lbl)

func _make_button(btn_name: String, y_offset: int) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -100)
	btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  100)
	btn.set_anchor_and_offset(SIDE_TOP,    0.5,  y_offset)
	btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  y_offset + 20)
	btn.add_theme_color_override("font_color", Color(0.88, 0.80, 0.58))
	btn.add_theme_font_size_override("font_size", 7)
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
	var has_excl: bool = sim.get("has_excluder") if sim.get("has_excluder") != null else false

	_info_lbl.text = "Deeps: %d/2  |  Supers: %d/10  |  Excluder: %s" % [
		deeps, supers, "Yes" if has_excl else "No"
	]

	# Get player inventory counts
	var player: Node = _get_player()
	var has_deep_item: bool = _player_has_item(GameData.ITEM_DEEP_BOX) or _player_has_item(GameData.ITEM_DEEP_BODY)
	var has_super_item: bool = _player_has_item(GameData.ITEM_SUPER_BOX)
	var has_excl_item: bool = _player_has_item(GameData.ITEM_QUEEN_EXCLUDER)

	# Add Deep button
	if deeps >= 2:
		_btn_add_deep.text = "Deep Body -- LOCKED (2/2 installed)"
		_btn_add_deep.disabled = true
	elif not has_deep_item:
		_btn_add_deep.text = "Add Deep Body -- (need Deep Body item)"
		_btn_add_deep.disabled = true
	else:
		_btn_add_deep.text = "Add Deep Body (permanent)"
		_btn_add_deep.disabled = false

	# Add Super button
	if supers >= 10:
		_btn_add_super.text = "Honey Super -- MAX (10/10)"
		_btn_add_super.disabled = true
	elif not has_super_item:
		_btn_add_super.text = "Add Honey Super -- (need Super Box item)"
		_btn_add_super.disabled = true
	else:
		_btn_add_super.text = "Add Honey Super (%d/10)" % supers
		_btn_add_super.disabled = false

	# Excluder button
	if has_excl:
		_btn_add_excluder.text = "Queen Excluder -- Already installed"
		_btn_add_excluder.disabled = true
	elif not has_excl_item:
		_btn_add_excluder.text = "Add Excluder -- (need Excluder item)"
		_btn_add_excluder.disabled = true
	else:
		_btn_add_excluder.text = "Add Queen Excluder"
		_btn_add_excluder.disabled = false

	# Rotate button
	if deeps < 2:
		_btn_rotate.text = "Rotate Deeps -- (need 2 deeps)"
		_btn_rotate.disabled = true
	else:
		_btn_rotate.text = "Rotate Deeps (bottom -> top)"
		_btn_rotate.disabled = false

	_update_btn_colors()

func _update_btn_colors() -> void:
	for btn in [_btn_add_deep, _btn_add_super, _btn_add_excluder, _btn_rotate]:
		if btn.disabled:
			btn.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35, 0.6))
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
	_show_status("Deep body added -- permanently locked in!")
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
		# Super failed to add -- refund the consumed item
		if player.has_method("add_item"):
			player.add_item(GameData.ITEM_SUPER_BOX, 1)
		_show_status("Cannot add super (max reached or hive not ready)")
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
		_refresh()
		return
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_show_status("Honey super added!")
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
