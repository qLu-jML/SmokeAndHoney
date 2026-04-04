# knowledge_log_overlay.gd -- Two-tab knowledge journal overlay.
# Tab 1: Beekeeper's Notebook (skills/knowledge entries)
# Tab 2: Hive Records (per-hive management log with player notes)
# Opened by pressing J key (handled in player.gd).
# -------------------------------------------------------------------------
extends CanvasLayer

# -- Layout (320x180 viewport) -------------------------------------------
const VP_W := 320
const VP_H := 180
const TAB_H := 14
const CONTENT_Y := TAB_H + 2
const CONTENT_H := VP_H - TAB_H - 4

# -- Colours ---------------------------------------------------------------
const C_BG := Color(0.06, 0.05, 0.04, 0.96)
const C_TAB_ACTIVE := Color(0.18, 0.14, 0.08, 1.0)
const C_TAB_INACTIVE := Color(0.10, 0.08, 0.05, 1.0)
const C_ACCENT := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT := Color(0.90, 0.85, 0.70, 1.0)
const C_MUTED := Color(0.55, 0.50, 0.42, 1.0)
const C_ENTRY_BG := Color(0.12, 0.10, 0.06, 0.90)

# -- State -----------------------------------------------------------------
var _active_tab: int = 0  # 0 = notebook, 1 = records
var _scroll_offset: int = 0
var _selected_entry: int = -1
var _selected_hive: String = ""

# -- UI refs ---------------------------------------------------------------
var _bg: ColorRect = null
var _tab_notebook_btn: Button = null
var _tab_records_btn: Button = null
var _content_panel: Control = null
var _detail_label: Label = null
var _list_labels: Array = []

# =========================================================================
# LIFECYCLE
# =========================================================================

func _ready() -> void:
	layer = 12
	_build_ui()
	_refresh_content()

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = C_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Tab buttons
	_tab_notebook_btn = _make_tab_btn("Notebook", 0, true)
	_tab_notebook_btn.position = Vector2(2, 1)
	_tab_notebook_btn.pressed.connect(_on_tab_notebook)
	add_child(_tab_notebook_btn)

	_tab_records_btn = _make_tab_btn("Hive Records", VP_W / 2, false)
	_tab_records_btn.position = Vector2(VP_W / 2, 1)
	_tab_records_btn.pressed.connect(_on_tab_records)
	add_child(_tab_records_btn)

	# Tab divider
	var div := ColorRect.new()
	div.color = C_ACCENT
	div.position = Vector2(0, TAB_H)
	div.size = Vector2(VP_W, 1)
	add_child(div)

	# Content panel (rebuilt on tab switch)
	_content_panel = Control.new()
	_content_panel.position = Vector2(0, CONTENT_Y)
	_content_panel.size = Vector2(VP_W, CONTENT_H)
	add_child(_content_panel)

	# Detail label (shown when entry is selected)
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 5)
	_detail_label.add_theme_color_override("font_color", C_TEXT)
	_detail_label.position = Vector2(4, CONTENT_Y)
	_detail_label.custom_minimum_size = Vector2(VP_W - 8, CONTENT_H)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_label.visible = false
	add_child(_detail_label)

	# Footer hint
	var footer := Label.new()
	footer.add_theme_font_size_override("font_size", 5)
	footer.add_theme_color_override("font_color", C_MUTED)
	footer.text = "[W/S] Scroll  [E] Select  [ESC/J] Close  [Tab] Switch"
	footer.position = Vector2(4, VP_H - 10)
	add_child(footer)

func _make_tab_btn(label: String, _x_pos: int, active: bool) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	sb.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", C_ACCENT if active else C_MUTED)
	btn.size = Vector2(VP_W / 2 - 2, TAB_H - 2)
	return btn

# =========================================================================
# INPUT
# =========================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE, KEY_J:
			queue_free()
		KEY_TAB:
			_active_tab = 1 - _active_tab
			_scroll_offset = 0
			_selected_entry = -1
			_selected_hive = ""
			_detail_label.visible = false
			_refresh_content()
		KEY_W:
			_scroll_offset = maxi(0, _scroll_offset - 1)
			_refresh_content()
		KEY_S:
			_scroll_offset += 1
			_refresh_content()
		KEY_E:
			_select_current()
		KEY_BACKSPACE:
			if _detail_label.visible:
				_detail_label.visible = false
				_refresh_content()
	get_viewport().set_input_as_handled()

# =========================================================================
# TAB SWITCHING
# =========================================================================

func _on_tab_notebook() -> void:
	_active_tab = 0
	_scroll_offset = 0
	_selected_entry = -1
	_detail_label.visible = false
	_update_tab_styles()
	_refresh_content()

func _on_tab_records() -> void:
	_active_tab = 1
	_scroll_offset = 0
	_selected_hive = ""
	_detail_label.visible = false
	_update_tab_styles()
	_refresh_content()

func _update_tab_styles() -> void:
	var sb_a := StyleBoxFlat.new()
	sb_a.bg_color = C_TAB_ACTIVE
	var sb_i := StyleBoxFlat.new()
	sb_i.bg_color = C_TAB_INACTIVE
	if _active_tab == 0:
		_tab_notebook_btn.add_theme_stylebox_override("normal", sb_a)
		_tab_notebook_btn.add_theme_color_override("font_color", C_ACCENT)
		_tab_records_btn.add_theme_stylebox_override("normal", sb_i)
		_tab_records_btn.add_theme_color_override("font_color", C_MUTED)
	else:
		_tab_notebook_btn.add_theme_stylebox_override("normal", sb_i)
		_tab_notebook_btn.add_theme_color_override("font_color", C_MUTED)
		_tab_records_btn.add_theme_stylebox_override("normal", sb_a)
		_tab_records_btn.add_theme_color_override("font_color", C_ACCENT)

# =========================================================================
# CONTENT RENDERING
# =========================================================================

func _refresh_content() -> void:
	# Clear previous content
	for child in _content_panel.get_children():
		child.queue_free()
	_list_labels.clear()

	if _active_tab == 0:
		_render_notebook()
	else:
		_render_records()

func _render_notebook() -> void:
	var entries: Array = KnowledgeLog.get_unlocked_entries()
	if entries.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 6)
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.text = "No entries unlocked yet. Keep exploring!"
		empty_lbl.position = Vector2(10, 20)
		_content_panel.add_child(empty_lbl)
		return

	var row_h: int = 10
	var max_visible: int = CONTENT_H / row_h - 1
	var start: int = clampi(_scroll_offset, 0, maxi(0, entries.size() - max_visible))
	_scroll_offset = start

	for i in range(start, mini(start + max_visible, entries.size())):
		var entry: Dictionary = entries[i]
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 5)
		var is_selected: bool = i == _selected_entry
		lbl.add_theme_color_override("font_color", C_ACCENT if is_selected else C_TEXT)
		lbl.text = "%s  [%s]" % [entry["title"], entry["category"]]
		lbl.position = Vector2(6, (i - start) * row_h)
		_content_panel.add_child(lbl)
		_list_labels.append({"index": i, "label": lbl})

func _render_records() -> void:
	if _selected_hive != "":
		_render_hive_records(_selected_hive)
		return

	var hive_keys: Array = KnowledgeLog.hive_records.keys()
	if hive_keys.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 6)
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.text = "No hive records yet. Inspect your hives!"
		empty_lbl.position = Vector2(10, 20)
		_content_panel.add_child(empty_lbl)
		return

	var row_h: int = 10
	var max_visible: int = CONTENT_H / row_h - 1
	var start: int = clampi(_scroll_offset, 0, maxi(0, hive_keys.size() - max_visible))
	_scroll_offset = start

	for i in range(start, mini(start + max_visible, hive_keys.size())):
		var key: String = hive_keys[i]
		var records: Array = KnowledgeLog.get_hive_records(key)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 5)
		var is_selected: bool = i == _selected_entry
		lbl.add_theme_color_override("font_color", C_ACCENT if is_selected else C_TEXT)
		lbl.text = "%s  (%d records)" % [key, records.size()]
		lbl.position = Vector2(6, (i - start) * row_h)
		_content_panel.add_child(lbl)
		_list_labels.append({"index": i, "label": lbl, "hive_key": key})

func _render_hive_records(hive_key: String) -> void:
	var records: Array = KnowledgeLog.get_hive_records(hive_key)
	var title_lbl := Label.new()
	title_lbl.add_theme_font_size_override("font_size", 6)
	title_lbl.add_theme_color_override("font_color", C_ACCENT)
	title_lbl.text = hive_key + "  [Backspace to go back]"
	title_lbl.position = Vector2(4, 0)
	_content_panel.add_child(title_lbl)

	var row_h: int = 10
	var max_visible: int = (CONTENT_H / row_h) - 2
	var start: int = clampi(_scroll_offset, 0, maxi(0, records.size() - max_visible))
	_scroll_offset = start

	for i in range(start, mini(start + max_visible, records.size())):
		var rec: Dictionary = records[i]
		var note_mark: String = " *" if rec.get("player_note", "") != "" else ""
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.add_theme_color_override("font_color", C_TEXT)
		lbl.text = "Day %d: %s - %s%s" % [rec.get("day", 0), rec.get("action", ""), rec.get("details", ""), note_mark]
		lbl.position = Vector2(6, 12 + (i - start) * row_h)
		_content_panel.add_child(lbl)

# =========================================================================
# SELECTION
# =========================================================================

func _select_current() -> void:
	if _active_tab == 0:
		# Show notebook entry detail
		var entries: Array = KnowledgeLog.get_unlocked_entries()
		if _selected_entry >= 0 and _selected_entry < entries.size():
			var entry: Dictionary = entries[_selected_entry]
			_detail_label.text = "%s\n\n%s" % [entry["title"], entry["body"]]
			_detail_label.visible = true
		elif _selected_entry < 0 and entries.size() > 0:
			_selected_entry = 0
			_refresh_content()
	elif _active_tab == 1:
		# Select a hive to view its records
		if _selected_hive == "":
			var hive_keys: Array = KnowledgeLog.hive_records.keys()
			if _selected_entry >= 0 and _selected_entry < hive_keys.size():
				_selected_hive = hive_keys[_selected_entry]
				_scroll_offset = 0
				_refresh_content()
			elif _selected_entry < 0 and hive_keys.size() > 0:
				_selected_entry = 0
				_refresh_content()
