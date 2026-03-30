# PauseMenu.gd
# -----------------------------------------------------------------------------
# Pause screen -- opened by pressing [ESC] or [P] when no other overlay is up.
#
# Features:
#   - Pauses the game tree (get_tree().paused = true)
#   - Resume / Save / Settings / Quit buttons
#   - Settings sub-panel with Music and SFX volume sliders
#   - Warm amber/cream GDD palette
#
# Audio bus setup:
#   Ensures "Music" and "SFX" buses exist as children of Master.
#   MusicManager routes to "Music" bus; future SFX use "SFX" bus.
#   Sliders control bus volume in dB via AudioServer.
# -----------------------------------------------------------------------------
extends CanvasLayer

# -- Layout --------------------------------------------------------------------
const VP_W    := 320
const VP_H    := 180
const PANEL_W := 160
const PANEL_H := 130
const PANEL_X := (VP_W - PANEL_W) / 2
const PANEL_Y := (VP_H - PANEL_H) / 2

# Settings sub-panel
const SETTINGS_W := 150
const SETTINGS_H := 90

# -- Colors (GDD warm palette) ------------------------------------------------
const C_DIM      := Color(0.00, 0.00, 0.00, 0.68)
const C_PANEL    := Color(0.09, 0.07, 0.04, 0.97)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE    := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT     := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED    := Color(0.55, 0.50, 0.40, 1.0)

# -- State ---------------------------------------------------------------------
var _panel: Control = null
var _settings_panel: Control = null
var _open: bool = false
var _settings_open: bool = false
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _music_pct_label: Label = null
var _sfx_pct_label: Label = null

# -- Audio bus indices (cached) ------------------------------------------------
var _music_bus_idx: int = -1
var _sfx_bus_idx: int = -1

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_ensure_audio_buses()
	_build_ui()
	_build_settings_panel()
	visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if _settings_open:
				_close_settings()
			elif _open:
				_close()
			else:
				_open_menu()
			get_viewport().set_input_as_handled()

# -- Public API ----------------------------------------------------------------

func toggle() -> void:
	if _settings_open:
		_close_settings()
	elif _open:
		_close()
	else:
		_open_menu()

func open() -> void:
	if not _open:
		_open_menu()

func close() -> void:
	if _open:
		_close()

# -- Audio bus setup -----------------------------------------------------------

func _ensure_audio_buses() -> void:
	# Find or create "Music" bus
	_music_bus_idx = AudioServer.get_bus_index("Music")
	if _music_bus_idx == -1:
		AudioServer.add_bus()
		_music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus_idx, "Music")
		AudioServer.set_bus_send(_music_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_music_bus_idx, 0.0)

	# Find or create "SFX" bus
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if _sfx_bus_idx == -1:
		AudioServer.add_bus()
		_sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_sfx_bus_idx, 0.0)

	# Route MusicManager to the Music bus if it exists
	_route_music_manager()

func _route_music_manager() -> void:
	var mm: Node = get_tree().root.get_node_or_null("MusicManager")
	if mm == null:
		return
	for child in mm.get_children():
		if child is AudioStreamPlayer:
			child.bus = "Music"

# -- UI Construction: Main panel -----------------------------------------------

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
	outer_sty.bg_color = Color(0, 0, 0, 0)
	outer_sty.draw_center = false
	outer_sty.border_color = C_BORDER
	outer_sty.set_border_width_all(1)
	var outer_brd := Panel.new()
	outer_brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_brd.add_theme_stylebox_override("panel", outer_sty)
	_panel.add_child(outer_brd)

	# Inner border (inset 2px)
	var inner_sty := StyleBoxFlat.new()
	inner_sty.bg_color = Color(0, 0, 0, 0)
	inner_sty.draw_center = false
	inner_sty.border_color = C_BORDER_D
	inner_sty.set_border_width_all(1)
	var inner_brd := Panel.new()
	inner_brd.position = Vector2(2, 2)
	inner_brd.size = Vector2(PANEL_W - 4, PANEL_H - 4)
	inner_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_brd.add_theme_stylebox_override("panel", inner_sty)
	_panel.add_child(inner_brd)

	# -- Title bar -------------------------------------------------
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.18, 0.12, 0.04, 1.0)
	title_bg.size = Vector2(PANEL_W, 18)
	title_bg.position = Vector2(0, 0)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title_bg)

	var title := _lbl("PAUSED", 9, Vector2(0, 4), Vector2(PANEL_W, 12), C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(title)

	# Title divider
	var title_div := ColorRect.new()
	title_div.color = C_BORDER
	title_div.size = Vector2(PANEL_W - 4, 1)
	title_div.position = Vector2(2, 18)
	_panel.add_child(title_div)

	# -- Status info -----------------------------------------------
	var status := _lbl("", 6, Vector2(10, 24), Vector2(PANEL_W - 20, 8), C_TEXT)
	status.name = "StatusLabel"
	_panel.add_child(status)

	var status2 := _lbl("", 6, Vector2(10, 33), Vector2(PANEL_W - 20, 8), C_MUTED)
	status2.name = "StatusLabel2"
	_panel.add_child(status2)

	var div2 := ColorRect.new()
	div2.color = Color(0.47, 0.28, 0.05, 0.60)
	div2.size = Vector2(PANEL_W - 20, 1)
	div2.position = Vector2(10, 44)
	_panel.add_child(div2)

	# -- Buttons ---------------------------------------------------
	var btn_y := 50
	for btn_data in [
		["Resume",     "_on_resume"],
		["Save",       "_on_save"],
		["Settings",   "_on_settings"],
		["Quit Game",  "_on_quit"],
	]:
		var btn := _make_button(btn_data[0], Vector2(20, btn_y), Vector2(PANEL_W - 40, 14))
		btn.pressed.connect(Callable(self, btn_data[1]))
		_panel.add_child(btn)
		btn_y += 16

	# Close hint
	var close_hint := _lbl("[ESC] to close", 5,
		Vector2(0, PANEL_H - 10), Vector2(PANEL_W, 7), C_MUTED)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(close_hint)

# -- UI Construction: Settings sub-panel ---------------------------------------

func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.size = Vector2(SETTINGS_W, SETTINGS_H)
	_settings_panel.position = Vector2(
		(VP_W - SETTINGS_W) / 2.0,
		(VP_H - SETTINGS_H) / 2.0
	)
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.visible = false
	add_child(_settings_panel)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(bg)

	# Border
	var brd_sty := StyleBoxFlat.new()
	brd_sty.bg_color = Color(0, 0, 0, 0)
	brd_sty.draw_center = false
	brd_sty.border_color = C_BORDER
	brd_sty.set_border_width_all(1)
	var brd := Panel.new()
	brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brd.add_theme_stylebox_override("panel", brd_sty)
	_settings_panel.add_child(brd)

	# Title
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.18, 0.12, 0.04, 1.0)
	title_bg.size = Vector2(SETTINGS_W, 16)
	title_bg.position = Vector2(0, 0)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(title_bg)

	var title := _lbl("AUDIO SETTINGS", 7, Vector2(0, 3), Vector2(SETTINGS_W, 10), C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_panel.add_child(title)

	var title_div := ColorRect.new()
	title_div.color = C_BORDER
	title_div.size = Vector2(SETTINGS_W - 4, 1)
	title_div.position = Vector2(2, 16)
	_settings_panel.add_child(title_div)

	# -- Music volume row ------------------------------------------
	var music_label := _lbl("Music", 6, Vector2(10, 22), Vector2(40, 10), C_TEXT)
	_settings_panel.add_child(music_label)

	_music_slider = _make_slider(Vector2(50, 22), Vector2(70, 10))
	_music_slider.value = _db_to_percent(_get_bus_volume_db("Music"))
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_settings_panel.add_child(_music_slider)

	_music_pct_label = _lbl(str(int(_music_slider.value)) + "%", 6,
		Vector2(122, 22), Vector2(24, 10), C_MUTED)
	_settings_panel.add_child(_music_pct_label)

	# -- SFX volume row --------------------------------------------
	var sfx_label := _lbl("Effects", 6, Vector2(10, 38), Vector2(40, 10), C_TEXT)
	_settings_panel.add_child(sfx_label)

	_sfx_slider = _make_slider(Vector2(50, 38), Vector2(70, 10))
	_sfx_slider.value = _db_to_percent(_get_bus_volume_db("SFX"))
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_settings_panel.add_child(_sfx_slider)

	_sfx_pct_label = _lbl(str(int(_sfx_slider.value)) + "%", 6,
		Vector2(122, 38), Vector2(24, 10), C_MUTED)
	_settings_panel.add_child(_sfx_pct_label)

	# -- Master volume row -----------------------------------------
	var master_label := _lbl("Master", 6, Vector2(10, 54), Vector2(40, 10), C_TEXT)
	_settings_panel.add_child(master_label)

	var master_slider := _make_slider(Vector2(50, 54), Vector2(70, 10))
	master_slider.value = _db_to_percent(_get_bus_volume_db("Master"))
	master_slider.value_changed.connect(_on_master_volume_changed)
	master_slider.name = "MasterSlider"
	_settings_panel.add_child(master_slider)

	var master_pct := _lbl(str(int(master_slider.value)) + "%", 6,
		Vector2(122, 54), Vector2(24, 10), C_MUTED)
	master_pct.name = "MasterPctLabel"
	_settings_panel.add_child(master_pct)

	# -- Back button -----------------------------------------------
	var back_btn := _make_button("Back", Vector2(45, SETTINGS_H - 20), Vector2(60, 14))
	back_btn.pressed.connect(_close_settings)
	_settings_panel.add_child(back_btn)

# -- Slider factory ------------------------------------------------------------

func _make_slider(pos: Vector2, sz: Vector2) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = sz
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = 100.0

	# Style the slider track
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.20, 0.14, 0.06, 1.0)
	track.border_color = Color(0.47, 0.28, 0.05, 0.6)
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	s.add_theme_stylebox_override("slider", track)

	# Grabber icon -- use a small flat stylebox as the grabber
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.90, 0.62, 0.15, 1.0)
	grabber.set_corner_radius_all(2)
	s.add_theme_stylebox_override("grabber_area", grabber)

	return s

# -- Volume helpers ------------------------------------------------------------

func _get_bus_volume_db(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)

func _set_bus_volume_db(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, db)
	# Mute if slider at zero
	AudioServer.set_bus_mute(idx, db <= -60.0)

func _percent_to_db(pct: float) -> float:
	# 0% = muted (-80dB), 100% = 0dB, logarithmic curve
	if pct <= 0.0:
		return -80.0
	return linear_to_db(pct / 100.0)

func _db_to_percent(db: float) -> float:
	if db <= -60.0:
		return 0.0
	return db_to_linear(db) * 100.0

# -- Slider callbacks ----------------------------------------------------------

func _on_music_volume_changed(value: float) -> void:
	_set_bus_volume_db("Music", _percent_to_db(value))
	if _music_pct_label:
		_music_pct_label.text = str(int(value)) + "%"

func _on_sfx_volume_changed(value: float) -> void:
	_set_bus_volume_db("SFX", _percent_to_db(value))
	if _sfx_pct_label:
		_sfx_pct_label.text = str(int(value)) + "%"

func _on_master_volume_changed(value: float) -> void:
	_set_bus_volume_db("Master", _percent_to_db(value))
	var lbl: Label = _settings_panel.get_node_or_null("MasterPctLabel") as Label
	if lbl:
		lbl.text = str(int(value)) + "%"

# -- Button factory ------------------------------------------------------------

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
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_color_override("font_color", Color(0.90, 0.85, 0.70, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.00, 0.92, 0.60, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.65, 0.50, 1.0))
	return btn

# -- Open / Close main panel ---------------------------------------------------

func _open_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_refresh_status()
	# Slide in from above
	_panel.visible = true
	_settings_panel.visible = false
	_settings_open = false
	_panel.position.y = float(PANEL_Y) - 20.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:y", float(PANEL_Y), 0.18)

func _close() -> void:
	_open = false
	_settings_open = false
	get_tree().paused = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "position:y", float(PANEL_Y) - 20.0, 0.12)
	await tw.finished
	visible = false
	_settings_panel.visible = false

func _refresh_status() -> void:
	var s: Label = _panel.get_node_or_null("StatusLabel") as Label
	var s2: Label = _panel.get_node_or_null("StatusLabel2") as Label
	if s and TimeManager:
		s.text = "%s - Day %d - Year %d" % [
			TimeManager.current_season_name(),
			TimeManager.current_day_of_month(),
			TimeManager.current_year()
		]
	if s2 and GameData:
		s2.text = "$%.2f  |  E:%d%%  |  %s" % [
			GameData.money,
			int(GameData.energy),
			GameData.get_level_title()
		]

# -- Settings open / close -----------------------------------------------------

func _on_settings() -> void:
	_settings_open = true
	_panel.visible = false
	_settings_panel.visible = true
	# Refresh slider positions to current bus volumes
	if _music_slider:
		_music_slider.value = _db_to_percent(_get_bus_volume_db("Music"))
	if _sfx_slider:
		_sfx_slider.value = _db_to_percent(_get_bus_volume_db("SFX"))
	var ms: HSlider = _settings_panel.get_node_or_null("MasterSlider") as HSlider
	if ms:
		ms.value = _db_to_percent(_get_bus_volume_db("Master"))

func _close_settings() -> void:
	_settings_open = false
	_settings_panel.visible = false
	_panel.visible = true

# -- Button handlers -----------------------------------------------------------

func _on_resume() -> void:
	_close()

func _on_save() -> void:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("save_game"):
		sm.save_game()
		var lbl: Label = _panel.get_node_or_null("StatusLabel") as Label
		if lbl:
			lbl.text = "Game saved!"
	else:
		print("[PauseMenu] SaveManager not found -- save skipped")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

# -- Helper --------------------------------------------------------------------

func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
