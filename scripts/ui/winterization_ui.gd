# winterization_ui.gd -- Overlay for applying winterization components to a hive.
# Winter Workshop S4.
# ---------------------------------------------------------------------------
# Opened from the hive interaction menu during Deepcold (transition month).
# Shows a checklist of winterization components with Apply buttons.
# Each component consumes an inventory item and energy, then marks the hive.
# ---------------------------------------------------------------------------
extends CanvasLayer

signal closed

# -- The hive being winterized ------------------------------------------------
var target_hive: Node = null   # Hive node (scripts/world/hive.gd)

# -- Component definitions ----------------------------------------------------
# Each entry: {id, label, energy_cost, desc}
# Items must be in player inventory (or already applied) to apply.
const COMPONENTS := [
	{"id": "entrance_reducer", "label": "Entrance Reducer",
	 "energy": 2, "desc": "Reduces cold air intrusion. Required for mouse guard."},
	{"id": "mouse_guard", "label": "Mouse Guard",
	 "energy": 2, "desc": "Blocks mice from entering the hive.",
	 "requires": "entrance_reducer"},
	{"id": "top_insulation", "label": "Top Insulation Board",
	 "energy": 2, "desc": "Insulates above the cluster. Most important single item."},
	{"id": "moisture_quilt", "label": "Moisture Quilt Box",
	 "energy": 4, "desc": "Absorbs condensation. Prevents moisture drip onto cluster."},
	{"id": "vent_shim", "label": "Ventilation Shim",
	 "energy": 1, "desc": "Upper entrance for moisture escape. Improves quilt effectiveness."},
	{"id": "hive_wrap", "label": "Hive Wrap / Insulation",
	 "energy": 5, "desc": "Reduces heat loss from hive walls."},
	{"id": "candy_board", "label": "Candy Board / Fondant",
	 "energy": 4, "desc": "Emergency feed placed on top bars. Prevents starvation."},
]

# -- Layout constants ---------------------------------------------------------
const PANEL_W   := 280
const PANEL_H   := 170
const PANEL_X   := 20
const PANEL_Y   := 5
const ROW_H     := 16
const ROWS_TOP  := 24

const FONT_SM   := 7
const FONT_MD   := 8

const C_ACCENT  := Color(0.65, 0.82, 0.95, 1.0)
const C_BG      := Color(0.12, 0.14, 0.18, 0.97)
const C_BG_ROW  := Color(0.18, 0.20, 0.25, 0.95)
const C_BG_DONE := Color(0.15, 0.28, 0.15, 0.95)
const C_TEXT    := Color(0.88, 0.90, 0.92, 1.0)
const C_MUTED   := Color(0.45, 0.48, 0.52, 0.7)
const C_GREEN   := Color(0.45, 0.85, 0.45, 1.0)

# -- State --------------------------------------------------------------------
var _sel: int = 0
var _row_btns: Array = []

# -- UI refs ------------------------------------------------------------------
var _title_lbl:  Label  = null
var _desc_lbl:   Label  = null
var _status_lbl: Label  = null
var _btn_apply:  Button = null
var _btn_close:  Button = null
var _bg:         ColorRect = null

func _ready() -> void:
	layer = 100
	_build_ui()
	_refresh()

func _build_ui() -> void:
	# Background overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Panel background
	_bg = ColorRect.new()
	_bg.color = C_BG
	_bg.position = Vector2(PANEL_X, PANEL_Y)
	_bg.size = Vector2(PANEL_W, PANEL_H)
	add_child(_bg)

	# Title
	_title_lbl = Label.new()
	_title_lbl.text = "Winterize Hive"
	_title_lbl.position = Vector2(PANEL_X + 8, PANEL_Y + 4)
	_title_lbl.add_theme_font_size_override("font_size", FONT_MD)
	_title_lbl.add_theme_color_override("font_color", C_ACCENT)
	add_child(_title_lbl)

	# Component rows
	for i in range(COMPONENTS.size()):
		var comp: Dictionary = COMPONENTS[i]
		var btn := Button.new()
		btn.text = comp["label"]
		btn.position = Vector2(PANEL_X + 4, PANEL_Y + ROWS_TOP + i * ROW_H)
		btn.size = Vector2(PANEL_W - 8, ROW_H - 2)
		btn.add_theme_font_size_override("font_size", FONT_SM)
		btn.pressed.connect(_on_row_pressed.bind(i))
		add_child(btn)
		_row_btns.append(btn)

	# Description label (bottom area)
	var desc_y: float = PANEL_Y + ROWS_TOP + COMPONENTS.size() * ROW_H + 4
	_desc_lbl = Label.new()
	_desc_lbl.text = ""
	_desc_lbl.position = Vector2(PANEL_X + 8, desc_y)
	_desc_lbl.size = Vector2(PANEL_W - 16, 20)
	_desc_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_desc_lbl.add_theme_color_override("font_color", C_TEXT)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_desc_lbl)

	# Status label
	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.position = Vector2(PANEL_X + 8, desc_y + 18)
	_status_lbl.add_theme_font_size_override("font_size", FONT_SM)
	_status_lbl.add_theme_color_override("font_color", C_GREEN)
	add_child(_status_lbl)

	# Apply button
	_btn_apply = Button.new()
	_btn_apply.text = "[APPLY]"
	_btn_apply.position = Vector2(PANEL_X + PANEL_W - 120, PANEL_Y + PANEL_H - 18)
	_btn_apply.size = Vector2(50, 14)
	_btn_apply.add_theme_font_size_override("font_size", FONT_SM)
	_btn_apply.pressed.connect(_on_apply)
	add_child(_btn_apply)

	# Close button
	_btn_close = Button.new()
	_btn_close.text = "[CLOSE]"
	_btn_close.position = Vector2(PANEL_X + PANEL_W - 60, PANEL_Y + PANEL_H - 18)
	_btn_close.size = Vector2(50, 14)
	_btn_close.add_theme_font_size_override("font_size", FONT_SM)
	_btn_close.pressed.connect(_on_close)
	add_child(_btn_close)


func _refresh() -> void:
	if target_hive == null:
		return
	var wstate: Dictionary = target_hive.winterization
	_title_lbl.text = "Winterize: %s  [%s]" % [
		target_hive.hive_name if target_hive.hive_name != "" else "Hive",
		target_hive.get_winterization_tier()]

	for i in range(COMPONENTS.size()):
		var comp: Dictionary = COMPONENTS[i]
		var cid: String = comp["id"]
		var applied: bool = wstate.get(cid, false)
		var btn: Button = _row_btns[i]

		if applied:
			btn.text = "[x] %s" % comp["label"]
			btn.add_theme_color_override("font_color", C_GREEN)
		else:
			var has_item: bool = _player_has_item(cid)
			var prefix: String = "[ ] " if has_item else "[-] "
			btn.text = "%s%s  (%d E)" % [prefix, comp["label"], comp["energy"]]
			if has_item:
				btn.add_theme_color_override("font_color", C_TEXT)
			else:
				btn.add_theme_color_override("font_color", C_MUTED)

	_update_desc()


func _update_desc() -> void:
	if _sel < 0 or _sel >= COMPONENTS.size():
		return
	var comp: Dictionary = COMPONENTS[_sel]
	var cid: String = comp["id"]
	var applied: bool = target_hive.winterization.get(cid, false)

	if applied:
		_desc_lbl.text = comp["desc"]
		_status_lbl.text = "Already applied."
		_btn_apply.disabled = true
	else:
		_desc_lbl.text = comp["desc"]
		var can_apply: bool = _can_apply(comp)
		if not _player_has_item(cid):
			_status_lbl.text = "Need %s in inventory." % comp["label"]
			_btn_apply.disabled = true
		elif comp.has("requires") and not target_hive.winterization.get(comp["requires"], false):
			_status_lbl.text = "Requires %s first." % comp["requires"].replace("_", " ")
			_btn_apply.disabled = true
		elif GameData.energy < comp["energy"]:
			_status_lbl.text = "Not enough energy (%d needed)." % comp["energy"]
			_btn_apply.disabled = true
		else:
			_status_lbl.text = "Ready to apply. Cost: %d energy." % comp["energy"]
			_btn_apply.disabled = false


func _can_apply(comp: Dictionary) -> bool:
	var cid: String = comp["id"]
	if target_hive.winterization.get(cid, false):
		return false
	if not _player_has_item(cid):
		return false
	if comp.has("requires") and not target_hive.winterization.get(comp["requires"], false):
		return false
	if GameData.energy < comp["energy"]:
		return false
	return true


func _player_has_item(item_id: String) -> bool:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		return false
	if player_node.has_method("has_item"):
		return player_node.has_item(item_id)
	return false


func _on_row_pressed(index: int) -> void:
	_sel = index
	_refresh()


func _on_apply() -> void:
	if _sel < 0 or _sel >= COMPONENTS.size():
		return
	var comp: Dictionary = COMPONENTS[_sel]
	var cid: String = comp["id"]
	if not _can_apply(comp):
		return

	# Consume item from inventory
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("consume_item"):
		player_node.consume_item(cid, 1)

	# Consume energy
	GameData.energy = maxf(0.0, GameData.energy - comp["energy"])
	GameData.energy_changed.emit(GameData.energy)

	# Mark component applied
	target_hive.winterization[cid] = true

	# Notification
	if NotificationManager:
		NotificationManager.notify(
			"%s applied to %s" % [comp["label"],
			target_hive.hive_name if target_hive.hive_name != "" else "Hive"],
			NotificationManager.T_INFO, 3.0)

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
				_sel = min(COMPONENTS.size() - 1, _sel + 1)
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_E, KEY_ENTER:
				_on_apply()
				get_viewport().set_input_as_handled()
