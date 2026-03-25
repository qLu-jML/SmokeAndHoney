# PauseMenu.gd
# -----------------------------------------------------------------------------
# Pause screen -- opened by pressing [P] from the HUD or by PauseMenu.tscn.
#
# Features:
#   - Pauses the game tree (Engine.time_scale = 0)
#   - Resume / Save & Quit buttons
#   - Shows current day/season summary
#   - Warm amber/cream GDD palette, panel_wood.png texture if available
#
# USAGE:
#   var pm = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
#   get_tree().current_scene.add_child(pm)
# -----------------------------------------------------------------------------
extends CanvasLayer

# -- Layout --------------------------------------------------------------------
const VP_W    := 320
const VP_H    := 180
const PANEL_W := 150
const PANEL_H := 120
const PANEL_X := (VP_W - PANEL_W) / 2
const PANEL_Y := (VP_H - PANEL_H) / 2

# -- Colors --------------------------------------------------------------------
const C_DIM      := Color(0.00, 0.00, 0.00, 0.68)
const C_PANEL    := Color(0.09, 0.07, 0.04, 0.97)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE    := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT     := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED    := Color(0.55, 0.50, 0.40, 1.0)

# -- State ---------------------------------------------------------------------
var _panel: Control = null
var _open:  bool    = false

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	layer = 30          # above HUD (1), below NotificationManager (50)
	add_to_group("pause_menu")
	_build_ui()
	visible = false     # start hidden

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if _open:
				_close()
			get_viewport().set_input_as_handled()

# -- Public API ----------------------------------------------------------------

func toggle() -> void:
	if _open: _close()
	else:     _open_menu()

func open() -> void:
	if not _open: _open_menu()

func close() -> void:
	if _open: _close()

# -- UI Construction -----------------------------------------------------------

func _build_ui() -> void:
	# Full-screen dim
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = C_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Panel root
	_panel = Control.new()
	_panel.name = "PausePanel"
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Panel background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)

	# Optional wood panel texture
	var tex_path := "res://assets/sprites/ui/menu_panel.png"
	if ResourceLoader.exists(tex_path):
		var tex := TextureRect.new()
		tex.texture = load(tex_path)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(tex)

	# Outer border
	var outer_sty := StyleBoxFlat.new()
	outer_sty.bg_color = Color(0,0,0,0); outer_sty.draw_center = false
	outer_sty.border_color = C_BORDER; outer_sty.set_border_width_all(1)
	var outer_brd := Panel.new()
	outer_brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_brd.add_theme_stylebox_override("panel", outer_sty)
	_panel.add_child(outer_brd)

	# Inner border (inset 2px)
	var inner_sty := StyleBoxFlat.new()
	inner_sty.bg_color = Color(0,0,0,0); inner_sty.draw_center = false
	inner_sty.border_color = C_BORDER_D; inner_sty.set_border_width_all(1)
	var inner_brd := Panel.new()
	inner_brd.position = Vector2(2, 2)
	inner_brd.size = Vector2(PANEL_W - 4, PANEL_H - 4)
	inner_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_brd.add_theme_stylebox_override("panel", inner_sty)
	_panel.add_child(inner_brd)

	# -- Title bar ----------------------------------------------------
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.18, 0.12, 0.04, 1.0)
	title_bg.size  = Vector2(PANEL_W, 18)
	title_bg.position = Vector2(0, 0)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title_bg)

	var title := _lbl("?  PAUSED", 9, Vector2(0, 4), Vector2(PANEL_W, 12), C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	# Title divider
	var title_div := ColorRect.new()
	title_div.color = C_BORDER
	title_div.size  = Vector2(PANEL_W - 4, 1)
	title_div.position = Vector2(2, 18)
	_panel.add_child(title_div)

	# -- Status info ---------------------------------------------------
	var status := _lbl("", 6, Vector2(10, 24), Vector2(PANEL_W - 20, 8), C_TEXT)
	status.name = "StatusLabel"
	_panel.add_child(status)

	var status2 := _lbl("", 6, Vector2(10, 33), Vector2(PANEL_W - 20, 8), C_MUTED)
	status2.name = "StatusLabel2"
	_panel.add_child(status2)

	var div2 := ColorRect.new()
	div2.color = Color(0.47, 0.28, 0.05, 0.60)
	div2.size  = Vector2(PANEL_W - 20, 1)
	div2.position = Vector2(10, 44)
	_panel.add_child(div2)

	# -- Buttons -------------------------------------------------------
	var btn_y := 52
	for btn_data in [
		["?  Resume",       "_on_resume"],
		["?  Map",         "_on_map"],
		["?  Save",        "_on_save"],
		["?  Main Menu",   "_on_main_menu"],
	]:
		var btn := _make_button(btn_data[0], Vector2(20, btn_y), Vector2(PANEL_W - 40, 14))
		btn.pressed.connect(Callable(self, btn_data[1]))
		_panel.add_child(btn)
		btn_y += 16

	# Close hint
	var close_hint := _lbl("[P] or [ESC] to close", 5,
		Vector2(0, PANEL_H - 10), Vector2(PANEL_W, 7), C_MUTED)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(close_hint)

func _make_button(label: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = pos
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	# Normal style
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.10, 0.04, 1.0)
	normal.border_color = Color(0.60, 0.40, 0.10, 1.0)
	normal.set_border_width_all(1)
	# Hover style
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.28, 0.18, 0.06, 1.0)
	hover.border_color = Color(0.90, 0.62, 0.15, 1.0)
	hover.set_border_width_all(1)
	# Pressed style
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.07, 0.03, 1.0)
	pressed.border_color = Color(0.55, 0.35, 0.08, 1.0)
	pressed.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus",   normal)
	btn.add_theme_color_override("font_color",         Color(0.90, 0.85, 0.70, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.60, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.65, 0.50, 1.0))
	return btn

# -- Open / Close --------------------------------------------------------------

func _open_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_refresh_status()
	# Slide in from above
	_panel.position.y = float(PANEL_Y) - 20.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:y", float(PANEL_Y), 0.18)

func _close() -> void:
	_open = false
	get_tree().paused = false
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "position:y", float(PANEL_Y) - 20.0, 0.12)
	await tw.finished
	visible = false

func _refresh_status() -> void:
	var s: Label = _panel.get_node_or_null("StatusLabel") as Label
	var s2: Label = _panel.get_node_or_null("StatusLabel2") as Label
	if s:
		s.text = "%s * Day %d * Year %d" % [
			TimeManager.current_season_name(),
			TimeManager.current_day_of_month(),
			TimeManager.current_year()
		]
	if s2:
		s2.text = "$%.2f  *  ? %d%%  *  %s" % [
			GameData.money,
			int(GameData.energy),
			GameData.get_level_title()
		]

# -- Button handlers -----------------------------------------------------------

func _on_resume() -> void:
	_close()

func _on_map() -> void:
	_close()
	# Find the map overlay in the current scene and open it
	await get_tree().create_timer(0.05).timeout
	var map := get_tree().get_first_node_in_group("map_overlay")
	if map and map.has_method("open"):
		map.open()

func _on_save() -> void:
	# Hook into SaveManager if available
	if get_tree().root.has_node("SaveManager"):
		var sm := get_tree().root.get_node_or_null("SaveManager")
		if sm and sm.has_method("save_game"):
			sm.save_game()
			if has_node("PausePanel/StatusLabel"):
				$PausePanel/StatusLabel.text = "? Game saved!"
	else:
		print("[PauseMenu] SaveManager not found -- save skipped")

func _on_main_menu() -> void:
	_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

# -- Helper --------------------------------------------------------------------

func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new(); l.text = text; l.position = pos; l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
