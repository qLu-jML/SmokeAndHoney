# knowledge_log_overlay.gd -- Three-tab knowledge journal overlay.
# Tab 1: Beekeeper's Notebook (skills/knowledge entries)
# Tab 2: Hive Records (per-hive management log with player notes)
# Tab 3: Quest Log (active and completed quests from QuestManager)
# Opened by pressing J key (handled in player.gd).
# -------------------------------------------------------------------------
extends CanvasLayer

# -- Layout (320x180 viewport) -------------------------------------------
const VP_W := 320
const VP_H := 180
const MARGIN := 6
const TITLE_H := 16
const TAB_H := 14
const FOOTER_H := 10
const HEADER_H: int = TITLE_H + TAB_H + 2  # title + tabs + divider
const CONTENT_Y: int = HEADER_H
const CONTENT_H: int = VP_H - HEADER_H - FOOTER_H - 2

# -- Colours (GDD warm palette, matching PauseMenu) -----------------------
const C_DIM      := Color(0.00, 0.00, 0.00, 0.80)
const C_PANEL    := Color(0.07, 0.05, 0.03, 1.0)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE    := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT     := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED    := Color(0.55, 0.50, 0.40, 1.0)
const C_ACCENT   := Color(0.95, 0.78, 0.32, 1.0)
const C_TAB_ACT  := Color(0.18, 0.14, 0.08, 1.0)
const C_TAB_OFF  := Color(0.10, 0.08, 0.05, 1.0)
const C_SEL_BG   := Color(0.18, 0.14, 0.06, 1.0)

# -- State -----------------------------------------------------------------
var _active_tab: int = 0  # 0 = notebook, 1 = records, 2 = quests
var _scroll_offset: int = 0
var _selected_entry: int = 0
var _selected_hive: String = ""

# -- UI refs ---------------------------------------------------------------
var _root: Control = null
var _tab_notebook_bg: ColorRect = null
var _tab_notebook_lbl: Label = null
var _tab_records_bg: ColorRect = null
var _tab_records_lbl: Label = null
var _tab_quests_bg: ColorRect = null
var _tab_quests_lbl: Label = null
var _content_panel: Control = null
var _detail_panel: Control = null
var _detail_label: Label = null
var _footer_label: Label = null
var _list_labels: Array = []

# =========================================================================
# LIFECYCLE
# =========================================================================

func _ready() -> void:
	layer = 25  # Above HUD (10), below PauseMenu (30)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_content()

func _build_ui() -> void:
	# Root Control fills the CanvasLayer so anchors work
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Full-screen dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = C_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	# Solid panel background
	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2.ZERO
	panel_bg.size = Vector2(VP_W, VP_H)
	panel_bg.color = C_PANEL
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel_bg)

	# Outer border
	_root.add_child(_border(Vector2.ZERO, Vector2(VP_W, VP_H), C_BORDER))

	# -- Title bar --
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.14, 0.09, 0.03, 1.0)
	title_bg.position = Vector2(0, 0)
	title_bg.size = Vector2(VP_W, TITLE_H)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_bg)

	var title_lbl := Label.new()
	title_lbl.text = "KNOWLEDGE JOURNAL"
	title_lbl.position = Vector2(0, 1)
	title_lbl.size = Vector2(VP_W, TITLE_H - 2)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 8)
	title_lbl.add_theme_color_override("font_color", C_TITLE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_lbl)

	_root.add_child(_hdiv(2, TITLE_H, VP_W - 4, C_BORDER))

	# -- Tab bar (three clickable tabs below title) --
	var tab_y: int = TITLE_H
	var tab_w: int = VP_W / 3

	# Notebook tab
	_tab_notebook_bg = ColorRect.new()
	_tab_notebook_bg.position = Vector2(1, tab_y)
	_tab_notebook_bg.size = Vector2(tab_w - 1, TAB_H)
	_tab_notebook_bg.color = C_TAB_ACT
	_tab_notebook_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_notebook_bg.gui_input.connect(_on_tab_notebook_click)
	_root.add_child(_tab_notebook_bg)

	_tab_notebook_lbl = Label.new()
	_tab_notebook_lbl.text = "Notebook"
	_tab_notebook_lbl.position = Vector2(1, tab_y)
	_tab_notebook_lbl.size = Vector2(tab_w - 1, TAB_H)
	_tab_notebook_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_notebook_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tab_notebook_lbl.add_theme_font_size_override("font_size", 6)
	_tab_notebook_lbl.add_theme_color_override("font_color", C_ACCENT)
	_tab_notebook_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tab_notebook_lbl)

	# Records tab
	_tab_records_bg = ColorRect.new()
	_tab_records_bg.position = Vector2(tab_w, tab_y)
	_tab_records_bg.size = Vector2(tab_w, TAB_H)
	_tab_records_bg.color = C_TAB_OFF
	_tab_records_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_records_bg.gui_input.connect(_on_tab_records_click)
	_root.add_child(_tab_records_bg)

	_tab_records_lbl = Label.new()
	_tab_records_lbl.text = "Hive Records"
	_tab_records_lbl.position = Vector2(tab_w, tab_y)
	_tab_records_lbl.size = Vector2(tab_w, TAB_H)
	_tab_records_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_records_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tab_records_lbl.add_theme_font_size_override("font_size", 6)
	_tab_records_lbl.add_theme_color_override("font_color", C_MUTED)
	_tab_records_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tab_records_lbl)

	# Quest Log tab
	_tab_quests_bg = ColorRect.new()
	_tab_quests_bg.position = Vector2(tab_w * 2, tab_y)
	_tab_quests_bg.size = Vector2(tab_w - 1, TAB_H)
	_tab_quests_bg.color = C_TAB_OFF
	_tab_quests_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_quests_bg.gui_input.connect(_on_tab_quests_click)
	_root.add_child(_tab_quests_bg)

	_tab_quests_lbl = Label.new()
	_tab_quests_lbl.text = "Quest Log"
	_tab_quests_lbl.position = Vector2(tab_w * 2, tab_y)
	_tab_quests_lbl.size = Vector2(tab_w - 1, TAB_H)
	_tab_quests_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_quests_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tab_quests_lbl.add_theme_font_size_override("font_size", 6)
	_tab_quests_lbl.add_theme_color_override("font_color", C_MUTED)
	_tab_quests_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tab_quests_lbl)

	# Divider below tabs
	_root.add_child(_hdiv(2, tab_y + TAB_H, VP_W - 4, C_BORDER))

	# -- Content area --
	_content_panel = Control.new()
	_content_panel.position = Vector2(MARGIN, CONTENT_Y + 2)
	_content_panel.size = Vector2(VP_W - MARGIN * 2, CONTENT_H)
	_content_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content_panel)

	# -- Detail view (shown when entry is selected, overlays content) --
	_detail_panel = Control.new()
	_detail_panel.position = Vector2(MARGIN, CONTENT_Y + 2)
	_detail_panel.size = Vector2(VP_W - MARGIN * 2, CONTENT_H)
	_detail_panel.visible = false
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_detail_panel)

	var detail_bg := ColorRect.new()
	detail_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_bg.color = C_PANEL
	detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(detail_bg)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 5)
	_detail_label.add_theme_color_override("font_color", C_TEXT)
	_detail_label.position = Vector2(4, 2)
	_detail_label.size = Vector2(VP_W - MARGIN * 2 - 8, CONTENT_H - 4)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(_detail_label)

	# -- Footer hint bar --
	_root.add_child(_hdiv(2, VP_H - FOOTER_H - 2, VP_W - 4, C_BORDER_D))

	_footer_label = Label.new()
	_footer_label.add_theme_font_size_override("font_size", 4)
	_footer_label.add_theme_color_override("font_color", C_MUTED)
	_footer_label.text = "[W/S] Scroll   [E] View   [Backspace] Back   [ESC/J] Close   [Tab] Switch"
	_footer_label.position = Vector2(MARGIN, VP_H - FOOTER_H)
	_footer_label.size = Vector2(VP_W - MARGIN * 2, FOOTER_H)
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_footer_label)

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
			_active_tab = (_active_tab + 1) % 3
			_scroll_offset = 0
			_selected_entry = 0
			_selected_hive = ""
			_detail_panel.visible = false
			_update_tab_styles()
			_refresh_content()
		KEY_W:
			if _detail_panel.visible:
				pass  # no scrolling in detail view
			else:
				_selected_entry = maxi(0, _selected_entry - 1)
				_clamp_scroll()
				_refresh_content()
		KEY_S:
			if _detail_panel.visible:
				pass
			else:
				_selected_entry += 1
				_clamp_scroll()
				_refresh_content()
		KEY_E:
			_select_current()
		KEY_BACKSPACE:
			if _detail_panel.visible:
				_detail_panel.visible = false
				_refresh_content()
			elif _selected_hive != "":
				_selected_hive = ""
				_selected_entry = 0
				_scroll_offset = 0
				_refresh_content()
	get_viewport().set_input_as_handled()

# =========================================================================
# TAB SWITCHING
# =========================================================================

func _on_tab_notebook_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_active_tab = 0
		_scroll_offset = 0
		_selected_entry = 0
		_selected_hive = ""
		_detail_panel.visible = false
		_update_tab_styles()
		_refresh_content()

func _on_tab_records_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_active_tab = 1
		_scroll_offset = 0
		_selected_entry = 0
		_selected_hive = ""
		_detail_panel.visible = false
		_update_tab_styles()
		_refresh_content()

func _on_tab_quests_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_active_tab = 2
		_scroll_offset = 0
		_selected_entry = 0
		_selected_hive = ""
		_detail_panel.visible = false
		_update_tab_styles()
		_refresh_content()

func _update_tab_styles() -> void:
	# Reset all tabs to inactive
	_tab_notebook_bg.color = C_TAB_OFF
	_tab_notebook_lbl.add_theme_color_override("font_color", C_MUTED)
	_tab_records_bg.color = C_TAB_OFF
	_tab_records_lbl.add_theme_color_override("font_color", C_MUTED)
	_tab_quests_bg.color = C_TAB_OFF
	_tab_quests_lbl.add_theme_color_override("font_color", C_MUTED)
	# Highlight active tab
	if _active_tab == 0:
		_tab_notebook_bg.color = C_TAB_ACT
		_tab_notebook_lbl.add_theme_color_override("font_color", C_ACCENT)
	elif _active_tab == 1:
		_tab_records_bg.color = C_TAB_ACT
		_tab_records_lbl.add_theme_color_override("font_color", C_ACCENT)
	else:
		_tab_quests_bg.color = C_TAB_ACT
		_tab_quests_lbl.add_theme_color_override("font_color", C_ACCENT)

# =========================================================================
# CONTENT RENDERING
# =========================================================================

func _refresh_content() -> void:
	for child in _content_panel.get_children():
		child.queue_free()
	_list_labels.clear()

	if _active_tab == 0:
		_render_notebook()
	elif _active_tab == 1:
		_render_records()
	else:
		_render_quests()

func _render_notebook() -> void:
	var entries: Array = KnowledgeLog.get_unlocked_entries()
	if entries.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 6)
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.text = "No entries unlocked yet.\nInspect your hive and talk to Uncle Bob!"
		empty_lbl.position = Vector2(4, 20)
		empty_lbl.size = Vector2(VP_W - MARGIN * 2 - 8, 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_panel.add_child(empty_lbl)
		return

	# Clamp selected entry
	_selected_entry = clampi(_selected_entry, 0, entries.size() - 1)

	var row_h: int = 11
	var max_visible: int = CONTENT_H / row_h
	_clamp_scroll_to(entries.size(), max_visible)

	for i in range(_scroll_offset, mini(_scroll_offset + max_visible, entries.size())):
		var entry: Dictionary = entries[i]
		var is_selected: bool = i == _selected_entry
		var row_y: int = (i - _scroll_offset) * row_h

		# Selection highlight
		if is_selected:
			var sel_bg := ColorRect.new()
			sel_bg.color = C_SEL_BG
			sel_bg.position = Vector2(0, row_y)
			sel_bg.size = Vector2(VP_W - MARGIN * 2, row_h)
			sel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content_panel.add_child(sel_bg)

		# Category tag
		var cat_lbl := Label.new()
		cat_lbl.add_theme_font_size_override("font_size", 4)
		cat_lbl.add_theme_color_override("font_color", C_MUTED)
		cat_lbl.text = entry["category"].to_upper()
		cat_lbl.position = Vector2(4, row_y + 1)
		cat_lbl.size = Vector2(40, row_h)
		cat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(cat_lbl)

		# Entry title
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 5)
		title.add_theme_color_override("font_color", C_ACCENT if is_selected else C_TEXT)
		title.text = entry["title"]
		title.position = Vector2(46, row_y + 1)
		title.size = Vector2(VP_W - MARGIN * 2 - 50, row_h)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(title)

		_list_labels.append({"index": i, "label": title})

	# Scroll indicator
	if entries.size() > max_visible:
		var indicator := Label.new()
		indicator.add_theme_font_size_override("font_size", 4)
		indicator.add_theme_color_override("font_color", C_MUTED)
		indicator.text = "%d/%d" % [_selected_entry + 1, entries.size()]
		indicator.position = Vector2(VP_W - MARGIN * 2 - 30, CONTENT_H - 8)
		indicator.size = Vector2(28, 8)
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(indicator)

func _render_records() -> void:
	if _selected_hive != "":
		_render_hive_records(_selected_hive)
		return

	var hive_keys: Array = KnowledgeLog.hive_records.keys()
	if hive_keys.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 6)
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.text = "No hive records yet.\nInspect your hives to start logging!"
		empty_lbl.position = Vector2(4, 20)
		empty_lbl.size = Vector2(VP_W - MARGIN * 2 - 8, 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_panel.add_child(empty_lbl)
		return

	_selected_entry = clampi(_selected_entry, 0, hive_keys.size() - 1)

	var row_h: int = 11
	var max_visible: int = CONTENT_H / row_h
	_clamp_scroll_to(hive_keys.size(), max_visible)

	for i in range(_scroll_offset, mini(_scroll_offset + max_visible, hive_keys.size())):
		var key: String = hive_keys[i]
		var records: Array = KnowledgeLog.get_hive_records(key)
		var is_selected: bool = i == _selected_entry
		var row_y: int = (i - _scroll_offset) * row_h

		if is_selected:
			var sel_bg := ColorRect.new()
			sel_bg.color = C_SEL_BG
			sel_bg.position = Vector2(0, row_y)
			sel_bg.size = Vector2(VP_W - MARGIN * 2, row_h)
			sel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content_panel.add_child(sel_bg)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.add_theme_color_override("font_color", C_ACCENT if is_selected else C_TEXT)
		lbl.text = "%s  (%d records)" % [key, records.size()]
		lbl.position = Vector2(4, row_y + 1)
		lbl.size = Vector2(VP_W - MARGIN * 2 - 8, row_h)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(lbl)
		_list_labels.append({"index": i, "label": lbl, "hive_key": key})

func _render_hive_records(hive_key: String) -> void:
	var records: Array = KnowledgeLog.get_hive_records(hive_key)

	# Header with hive name
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 6)
	header.add_theme_color_override("font_color", C_ACCENT)
	header.text = hive_key
	header.position = Vector2(4, 0)
	header.size = Vector2(VP_W - MARGIN * 2 - 8, 12)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_panel.add_child(header)

	var back_hint := Label.new()
	back_hint.add_theme_font_size_override("font_size", 4)
	back_hint.add_theme_color_override("font_color", C_MUTED)
	back_hint.text = "[Backspace] Back"
	back_hint.position = Vector2(VP_W - MARGIN * 2 - 60, 2)
	back_hint.size = Vector2(58, 10)
	back_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	back_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_panel.add_child(back_hint)

	if records.size() == 0:
		var empty := Label.new()
		empty.add_theme_font_size_override("font_size", 5)
		empty.add_theme_color_override("font_color", C_MUTED)
		empty.text = "No records for this hive yet."
		empty.position = Vector2(4, 16)
		_content_panel.add_child(empty)
		return

	var row_h: int = 10
	var start_y: int = 14
	var max_visible: int = (CONTENT_H - start_y) / row_h
	var start: int = clampi(_scroll_offset, 0, maxi(0, records.size() - max_visible))
	_scroll_offset = start

	for i in range(start, mini(start + max_visible, records.size())):
		var rec: Dictionary = records[i]
		var note_mark: String = " *" if rec.get("player_note", "") != "" else ""
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 5)
		lbl.add_theme_color_override("font_color", C_TEXT)
		lbl.text = "Day %d: %s - %s%s" % [
			rec.get("day", 0), rec.get("action", ""),
			rec.get("details", ""), note_mark]
		lbl.position = Vector2(4, start_y + (i - start) * row_h)
		lbl.size = Vector2(VP_W - MARGIN * 2 - 8, row_h)
		lbl.clip_contents = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(lbl)

# =========================================================================
# SELECTION
# =========================================================================

func _select_current() -> void:
	if _active_tab == 0:
		var entries: Array = KnowledgeLog.get_unlocked_entries()
		if _selected_entry >= 0 and _selected_entry < entries.size():
			var entry: Dictionary = entries[_selected_entry]
			_detail_label.text = "%s\n\n%s" % [entry["title"], entry["body"]]
			_detail_panel.visible = true
	elif _active_tab == 1:
		if _selected_hive == "":
			var hive_keys: Array = KnowledgeLog.hive_records.keys()
			if _selected_entry >= 0 and _selected_entry < hive_keys.size():
				_selected_hive = hive_keys[_selected_entry]
				_scroll_offset = 0
				_refresh_content()
	elif _active_tab == 2:
		# Show quest detail
		var quest_list: Array = _build_quest_list()
		if _selected_entry >= 0 and _selected_entry < quest_list.size():
			var q: Dictionary = quest_list[_selected_entry]
			var status_str: String = "ACTIVE" if q["active"] else "COMPLETED"
			var desc: String = q.get("description", "No details available.")
			var hint: String = q.get("hint", "")
			var text: String = "%s  [%s]\n\n%s" % [q["title"], status_str, desc]
			if hint != "" and q["active"]:
				text += "\n\nObjective: %s" % hint
			_detail_label.text = text
			_detail_panel.visible = true

# =========================================================================
# SCROLL HELPERS
# =========================================================================

## Clamp scroll offset so the selected entry is always visible.
func _clamp_scroll() -> void:
	var count: int = 0
	if _active_tab == 0:
		count = KnowledgeLog.get_unlocked_entries().size()
	elif _active_tab == 1:
		if _selected_hive != "":
			count = KnowledgeLog.get_hive_records(_selected_hive).size()
		else:
			count = KnowledgeLog.hive_records.keys().size()
	else:
		count = _build_quest_list().size()
	_selected_entry = clampi(_selected_entry, 0, maxi(0, count - 1))
	var row_h: int = 11
	var max_visible: int = CONTENT_H / row_h
	if _selected_entry < _scroll_offset:
		_scroll_offset = _selected_entry
	elif _selected_entry >= _scroll_offset + max_visible:
		_scroll_offset = _selected_entry - max_visible + 1
	_scroll_offset = clampi(_scroll_offset, 0, maxi(0, count - max_visible))

func _clamp_scroll_to(count: int, max_visible: int) -> void:
	if _scroll_offset > maxi(0, count - max_visible):
		_scroll_offset = maxi(0, count - max_visible)

# =========================================================================
# QUEST LOG
# =========================================================================

## Build a combined list of active quests (first) then completed quests.
## Each entry is a dict: {id, title, hint, description, active}
func _build_quest_list() -> Array:
	var result: Array = []
	# Active quests first
	for qid in QuestManager.active_quests:
		if QuestManager.active_quests[qid] != QuestManager.QuestState.ACTIVE:
			continue
		var qdef: Dictionary = QuestDefs.QUESTS.get(qid, {})
		result.append({
			"id": qid,
			"title": qdef.get("title", qid),
			"hint": qdef.get("hint", ""),
			"description": qdef.get("description", ""),
			"active": true,
		})
	# Completed quests
	for qid in QuestManager.completed_quests:
		var qdef: Dictionary = QuestDefs.QUESTS.get(qid, {})
		result.append({
			"id": qid,
			"title": qdef.get("title", qid),
			"hint": qdef.get("hint", ""),
			"description": qdef.get("description", ""),
			"active": false,
		})
	return result

func _render_quests() -> void:
	var quest_list: Array = _build_quest_list()
	if quest_list.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 6)
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.text = "No quests yet.\nTalk to Uncle Bob to get started!"
		empty_lbl.position = Vector2(4, 20)
		empty_lbl.size = Vector2(VP_W - MARGIN * 2 - 8, 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_panel.add_child(empty_lbl)
		return

	_selected_entry = clampi(_selected_entry, 0, quest_list.size() - 1)

	var row_h: int = 11
	var max_visible: int = CONTENT_H / row_h
	_clamp_scroll_to(quest_list.size(), max_visible)

	for i in range(_scroll_offset, mini(_scroll_offset + max_visible, quest_list.size())):
		var q: Dictionary = quest_list[i]
		var is_selected: bool = i == _selected_entry
		var row_y: int = (i - _scroll_offset) * row_h

		# Selection highlight
		if is_selected:
			var sel_bg := ColorRect.new()
			sel_bg.color = C_SEL_BG
			sel_bg.position = Vector2(0, row_y)
			sel_bg.size = Vector2(VP_W - MARGIN * 2, row_h)
			sel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content_panel.add_child(sel_bg)

		# Status tag (ACTIVE / DONE)
		var tag_lbl := Label.new()
		tag_lbl.add_theme_font_size_override("font_size", 4)
		if q["active"]:
			tag_lbl.add_theme_color_override("font_color", C_ACCENT)
			tag_lbl.text = "ACTIVE"
		else:
			tag_lbl.add_theme_color_override("font_color", C_MUTED)
			tag_lbl.text = "DONE"
		tag_lbl.position = Vector2(4, row_y + 1)
		tag_lbl.size = Vector2(34, row_h)
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(tag_lbl)

		# Quest title
		var title := Label.new()
		title.add_theme_font_size_override("font_size", 5)
		title.add_theme_color_override("font_color", C_ACCENT if is_selected else C_TEXT)
		title.text = q["title"]
		title.position = Vector2(40, row_y + 1)
		title.size = Vector2(VP_W - MARGIN * 2 - 44, row_h)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(title)

		_list_labels.append({"index": i, "label": title})

	# Scroll indicator
	if quest_list.size() > max_visible:
		var indicator := Label.new()
		indicator.add_theme_font_size_override("font_size", 4)
		indicator.add_theme_color_override("font_color", C_MUTED)
		indicator.text = "%d/%d" % [_selected_entry + 1, quest_list.size()]
		indicator.position = Vector2(VP_W - MARGIN * 2 - 30, CONTENT_H - 8)
		indicator.size = Vector2(28, 8)
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_panel.add_child(indicator)

# =========================================================================
# UI HELPERS (matching PauseMenu style)
# =========================================================================

func _border(pos: Vector2, sz: Vector2, color: Color) -> Panel:
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0, 0, 0, 0)
	sty.draw_center = false
	sty.border_color = color
	sty.set_border_width_all(1)
	var p := Panel.new()
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", sty)
	return p

func _hdiv(x: int, y: int, w: int, color: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.size = Vector2(w, 1)
	d.position = Vector2(x, y)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d
