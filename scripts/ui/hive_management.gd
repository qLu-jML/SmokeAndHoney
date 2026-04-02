# hive_management.gd - Hive Management UI overlay.
# Opened when player has Gloves active and presses E near a colonized hive.
# Uses the same absolute-pixel layout technique as the HUD dev panel so
# buttons render with proper visible StyleBoxFlat backgrounds and borders.
#
# Viewport: 320x180.  Panel: 262x160, centred at (29, 10).
extends CanvasLayer

# - External references (set before adding to tree) -------------------------
var hive_ref: Node = null   # The Hive node (scripts/world/hive.gd)

# - Viewport / panel constants -----------------------------------------------
const VP_W: int  = 320
const VP_H: int  = 180
const PNL_W: int = 262
const PNL_H: int = 160
const PNL_X: int = 29    # (320 - 262) / 2
const PNL_Y: int = 10    # (180 - 160) / 2

# - Accent colours (matching HUD palette) ------------------------------------
const C_ACCENT:   Color = Color(0.95, 0.78, 0.32, 1.0)   # gold border
const C_BG:       Color = Color(0.15, 0.10, 0.05, 0.97)  # dark panel bg
const C_TEXT:     Color = Color(0.92, 0.85, 0.65, 1.0)   # normal text
const C_MUTED:    Color = Color(0.45, 0.40, 0.28, 0.55)  # disabled text
const C_STATUS:   Color = Color(0.95, 0.82, 0.40, 1.0)   # status msg
const C_BTN_BG:   Color = Color(0.22, 0.15, 0.07, 0.97)  # button bg
const C_HOVER_BG: Color = Color(0.35, 0.24, 0.10, 0.97)  # hover bg

# - Internal refs -----------------------------------------------------------
var _btn_add_deep:     Button = null
var _btn_add_super:    Button = null
var _btn_remove_super: Button = null
var _btn_add_excluder: Button = null
var _btn_rotate:       Button = null
var _info_lbl:         Label  = null
var _status_lbl:       Label  = null

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

# - UI construction (absolute pixel coords matching HUD dev-panel style) ----

func _build_ui() -> void:
	# Full-screen dark overlay
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.50)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Outer border rect (1px accent colour)
	var border: ColorRect = ColorRect.new()
	border.name = "PanelBorder"
	border.color = C_ACCENT
	border.position = Vector2(PNL_X - 1, PNL_Y - 1)
	border.size     = Vector2(PNL_W + 2,  PNL_H + 2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# Main panel background
	var panel: ColorRect = ColorRect.new()
	panel.name = "Panel"
	panel.color = C_BG
	panel.position = Vector2(PNL_X, PNL_Y)
	panel.size     = Vector2(PNL_W, PNL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	# Title bar strip
	var title_bar: ColorRect = ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.color = Color(0.28, 0.18, 0.06, 0.90)
	title_bar.position = Vector2(PNL_X + 1, PNL_Y + 1)
	title_bar.size     = Vector2(PNL_W - 2, 14)
	add_child(title_bar)

	_make_label("Title", "Hive Management",
		Vector2(PNL_X + 1, PNL_Y + 2),
		Vector2(PNL_W - 2, 12),
		9, C_ACCENT, true)

	# Title / info divider
	var div1: ColorRect = ColorRect.new()
	div1.color = C_ACCENT
	div1.position = Vector2(PNL_X + 1, PNL_Y + 15)
	div1.size     = Vector2(PNL_W - 2, 1)
	add_child(div1)

	# Info strip
	var info_bar: ColorRect = ColorRect.new()
	info_bar.color = Color(0.12, 0.08, 0.03, 0.80)
	info_bar.position = Vector2(PNL_X + 1, PNL_Y + 16)
	info_bar.size     = Vector2(PNL_W - 2, 12)
	add_child(info_bar)

	_info_lbl = _make_label("InfoLbl", "",
		Vector2(PNL_X + 2, PNL_Y + 17),
		Vector2(PNL_W - 4, 11),
		7, Color(0.78, 0.70, 0.50), true)

	# Info / buttons divider
	var div2: ColorRect = ColorRect.new()
	div2.color = Color(0.40, 0.30, 0.12, 0.60)
	div2.position = Vector2(PNL_X + 1, PNL_Y + 28)
	div2.size     = Vector2(PNL_W - 2, 1)
	add_child(div2)

	# - Buttons (14px tall, 3px gap, starting at y=30 inside panel) ----------
	var BX: int  = PNL_X + 5         # button left edge
	var BW: int  = PNL_W - 10        # button width
	var BY: int  = PNL_Y + 30        # first button top
	var BH: int  = 14                 # button height
	var GAP: int = 3                  # gap between buttons

	_btn_add_deep     = _make_button("BtnAddDeep",     BX, BY,             BW, BH)
	_btn_add_super    = _make_button("BtnAddSuper",    BX, BY + (BH+GAP),  BW, BH)
	_btn_remove_super = _make_button("BtnRemoveSuper", BX, BY + (BH+GAP)*2,BW, BH)
	_btn_add_excluder = _make_button("BtnAddExcluder", BX, BY + (BH+GAP)*3,BW, BH)
	_btn_rotate       = _make_button("BtnRotate",      BX, BY + (BH+GAP)*4,BW, BH)

	_btn_add_deep.pressed.connect(_on_add_deep)
	_btn_add_super.pressed.connect(_on_add_super)
	_btn_remove_super.pressed.connect(_on_remove_super)
	_btn_add_excluder.pressed.connect(_on_add_excluder)
	_btn_rotate.pressed.connect(_on_rotate)

	# Status label
	_status_lbl = _make_label("StatusLbl", "",
		Vector2(PNL_X + 2, PNL_Y + PNL_H - 20),
		Vector2(PNL_W - 4, 11),
		7, C_STATUS, true)

	# Bottom divider
	var div3: ColorRect = ColorRect.new()
	div3.color = Color(0.40, 0.30, 0.12, 0.60)
	div3.position = Vector2(PNL_X + 1, PNL_Y + PNL_H - 21)
	div3.size     = Vector2(PNL_W - 2, 1)
	add_child(div3)

	# Close hint
	_make_label("CloseHint", "[ESC] Close",
		Vector2(PNL_X + 2, PNL_Y + PNL_H - 9),
		Vector2(PNL_W - 4, 8),
		6, Color(0.48, 0.42, 0.30), true)

# - Widget factories --------------------------------------------------------

## Create a button using the same pattern as the HUD dev panel.
## Anchor = 0 everywhere; positioned by absolute pixel rect.
func _make_button(btn_name: String, x: int, y: int, w: int, h: int) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   C_ACCENT)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", C_MUTED)
	# Override every state (same loop as hud._create_dev_button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		if state == "normal":
			sb.bg_color = C_BTN_BG
		elif state == "hover":
			sb.bg_color = C_HOVER_BG
		elif state == "pressed":
			sb.bg_color = Color(0.12, 0.08, 0.03, 0.97)
		elif state == "disabled":
			sb.bg_color = Color(0.14, 0.09, 0.04, 0.55)
		else:  # focus
			sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = C_ACCENT
		sb.set_border_width_all(1)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.z_index = 25
	# Absolute rect (anchor = 0, offset = absolute pixels)
	btn.anchor_left   = 0
	btn.anchor_top    = 0
	btn.anchor_right  = 0
	btn.anchor_bottom = 0
	btn.offset_left   = x
	btn.offset_top    = y
	btn.offset_right  = x + w
	btn.offset_bottom = y + h
	add_child(btn)
	return btn

## Create a Label with absolute pixel rect.
func _make_label(lbl_name: String, text_val: String,
		pos: Vector2, sz: Vector2,
		font_sz: int, col: Color, centred: bool) -> Label:
	var lbl: Label = Label.new()
	lbl.name = lbl_name
	lbl.text = text_val
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	if centred:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.anchor_left   = 0
	lbl.anchor_top    = 0
	lbl.anchor_right  = 0
	lbl.anchor_bottom = 0
	lbl.offset_left   = pos.x
	lbl.offset_top    = pos.y
	lbl.offset_right  = pos.x + sz.x
	lbl.offset_bottom = pos.y + sz.y
	lbl.z_index = 26
	add_child(lbl)
	return lbl

# - Refresh button states ---------------------------------------------------

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

	_info_lbl.text = "Deeps: %d/3   Supers: %d/5   Excluder: %s" % [
		deeps, supers, "Yes" if has_excl else "No"
	]

	var has_deep_item:  bool = _player_has_item(GameData.ITEM_DEEP_BOX) or _player_has_item(GameData.ITEM_DEEP_BODY)
	var has_super_item: bool = _player_has_item(GameData.ITEM_SUPER_BOX)
	var has_excl_item:  bool = _player_has_item(GameData.ITEM_QUEEN_EXCLUDER)
	var already_carrying: bool = _player_has_item(GameData.ITEM_FULL_SUPER)

	# Add Deep
	if deeps >= 3:
		_set_btn(_btn_add_deep, "Add Deep Body  [max 3/3]", true)
	elif not has_deep_item:
		_set_btn(_btn_add_deep, "Add Deep Body  [need item]", true)
	else:
		_set_btn(_btn_add_deep, "Add Deep Body", false)

	# Add Super
	if supers >= 5:
		_set_btn(_btn_add_super, "Add Honey Super  [max 5/5]", true)
	elif not has_super_item:
		_set_btn(_btn_add_super, "Add Honey Super  [need item]", true)
	else:
		_set_btn(_btn_add_super, "Add Honey Super  (%d/5)" % supers, false)

	# Remove Super - smart: checks honey content to show correct action
	if already_carrying:
		_set_btn(_btn_remove_super, "Remove Super  [hands full!]", true)
	elif supers <= 0:
		_set_btn(_btn_remove_super, "Remove Super  [none on hive]", true)
	else:
		var has_honey: bool = hive_ref.has_method("top_super_has_honey") and hive_ref.top_super_has_honey()
		if has_honey:
			_set_btn(_btn_remove_super, "Remove Super for Harvest", false)
		else:
			_set_btn(_btn_remove_super, "Return Empty Super to Inventory", false)

	# Add Excluder
	if has_excl:
		_set_btn(_btn_add_excluder, "Add Queen Excluder  [installed]", true)
	elif not has_excl_item:
		_set_btn(_btn_add_excluder, "Add Queen Excluder  [need item]", true)
	else:
		_set_btn(_btn_add_excluder, "Add Queen Excluder", false)

	# Rotate Deeps
	if deeps < 2:
		_set_btn(_btn_rotate, "Rotate Deeps  [need 2 deeps]", true)
	else:
		_set_btn(_btn_rotate, "Rotate Deeps", false)

func _set_btn(btn: Button, text_val: String, disabled_val: bool) -> void:
	btn.text = text_val
	btn.disabled = disabled_val

# - Actions -----------------------------------------------------------------

func _on_add_deep() -> void:
	var player: Node = _get_player()
	if not player or not player.has_method("consume_item"):
		return
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
	if not player or not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_SUPER_BOX, 1):
		_show_status("No Super Box in inventory!")
		return
	var added: bool = false
	if hive_ref.has_method("try_add_super"):
		added = hive_ref.try_add_super()
	if not added:
		if player.has_method("add_item"):
			player.add_item(GameData.ITEM_SUPER_BOX, 1)
		_show_status("Cannot add super (hive not ready or max)")
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
	# Carry limit: only one full super at a time (empty supers always OK)
	var has_honey: bool = hive_ref.has_method("top_super_has_honey") and hive_ref.top_super_has_honey()
	if has_honey and player.has_method("count_item"):
		if player.count_item(GameData.ITEM_FULL_SUPER) > 0:
			_show_status("Hands full! Take super to Honey House first.")
			_refresh()
			return
	if not hive_ref.has_method("try_remove_top_super"):
		_show_status("Remove super not supported!")
		return
	var removed: Object = hive_ref.try_remove_top_super()
	if removed == null:
		_show_status("No supers to remove!")
		return
	# Give back the correct item based on honey content
	if player.has_method("add_item"):
		if has_honey:
			# Store actual frame cell data so honey house / harvest yard can
			# recreate the exact cell distribution the player saw in inspection.
			GameData.harvested_super_frames.clear()
			if removed.has_method("get") or "frames" in removed:
				for frame in removed.frames:
					GameData.harvested_super_frames.append({
						"cells_a": frame.cells.duplicate(),
						"cells_b": frame.cells_b.duplicate(),
						"cols": frame.grid_cols,
						"rows": frame.grid_rows,
					})
			player.add_item(GameData.ITEM_FULL_SUPER, 1)
			if player.has_method("update_hud_inventory"):
				player.update_hud_inventory()
			# Auto-close: super is now in the player's hands, no need to stay in menu
			_close()
			return
		else:
			player.add_item(GameData.ITEM_SUPER_BOX, 1)
			_show_status("Empty super returned to inventory.")
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()
	_refresh()

func _on_add_excluder() -> void:
	var player: Node = _get_player()
	if not player or not player.has_method("consume_item"):
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
			_show_status("Deeps rotated - bottom box moved to top!")
		else:
			_show_status("Cannot rotate - need 2 deep bodies.")
	_refresh()

# - Helpers -----------------------------------------------------------------

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
