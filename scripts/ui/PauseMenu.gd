# PauseMenu.gd
# -----------------------------------------------------------------------------
# Pause screen -- opened by pressing [ESC] or [P] when no other overlay is up.
# Uses custom Control+ColorRect+Label buttons instead of Godot Button nodes
# to get pixel-perfect sizing at the 320x180 viewport.
# -----------------------------------------------------------------------------
extends CanvasLayer

# -- Layout --------------------------------------------------------------------
const VP_W    := 320
const VP_H    := 180
const PANEL_W := 130
const PANEL_H := 155
const PANEL_X: int = (VP_W - PANEL_W) / 2
const PANEL_Y: int = (VP_H - PANEL_H) / 2

const SETTINGS_W := 150
const SETTINGS_H := 134

const CONTROLS_W := 190
const CONTROLS_H := 176

const BTN_H := 14
const BTN_GAP := 3

# -- Colors (GDD warm palette) ------------------------------------------------
const C_DIM      := Color(0.00, 0.00, 0.00, 0.72)
const C_PANEL    := Color(0.07, 0.05, 0.03, 0.96)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE    := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT     := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED    := Color(0.55, 0.50, 0.40, 1.0)

# Button colors
const C_BTN_FILL     := Color(0.13, 0.09, 0.04, 1.0)
const C_BTN_BORDER   := Color(0.55, 0.37, 0.10, 1.0)
const C_BTN_FILL_H   := Color(0.24, 0.16, 0.05, 1.0)
const C_BTN_BORDER_H := Color(0.90, 0.62, 0.15, 1.0)
const C_BTN_FILL_P   := Color(0.08, 0.06, 0.02, 1.0)
const C_BTN_BORDER_P := Color(0.45, 0.30, 0.08, 1.0)
const C_BTN_TEXT     := Color(0.88, 0.82, 0.68, 1.0)
const C_BTN_TEXT_H   := Color(1.00, 0.92, 0.60, 1.0)
const C_BTN_TEXT_P   := Color(0.70, 0.62, 0.48, 1.0)

# -- State ---------------------------------------------------------------------
var _panel: Control = null
var _settings_panel: Control = null
var _open: bool = false
var _settings_open: bool = false
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _music_pct_label: Label = null
var _sfx_pct_label: Label = null
var _master_slider: HSlider = null
var _mute_checkbox: CheckBox = null
var _controls_panel: Control = null
var _controls_open: bool = false
var _exit_confirm: Control = null
var _exit_confirm_open: bool = false
var _music_bus_idx: int = -1
var _sfx_bus_idx: int = -1

# -- Lifecycle -----------------------------------------------------------------

## Initializes the pause menu UI and sets up the input system.
func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_ensure_audio_buses()
	_build_ui()
	_build_settings_panel()
	_build_controls_panel()
	_build_exit_confirm()
	visible = false

## Handles ESC key to toggle the pause menu.
## Disconnects all signals when the node is removed from the scene tree.
func _exit_tree() -> void:
	# Disconnect slider signals
	if _music_slider and _music_slider.value_changed.is_connected(_on_music_vol):
		_music_slider.value_changed.disconnect(_on_music_vol)
	if _sfx_slider and _sfx_slider.value_changed.is_connected(_on_sfx_vol):
		_sfx_slider.value_changed.disconnect(_on_sfx_vol)
	if _master_slider and _master_slider.value_changed.is_connected(_on_master_vol):
		_master_slider.value_changed.disconnect(_on_master_vol)
	# Disconnect mute toggle
	if _mute_checkbox and _mute_checkbox.toggled.is_connected(_on_mute):
		_mute_checkbox.toggled.disconnect(_on_mute)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if _exit_confirm_open:
				_close_exit_confirm()
			elif _settings_open:
				_close_settings()
			elif _controls_open:
				_close_controls()
			elif _open:
				_close()
			else:
				_open_menu()
			get_viewport().set_input_as_handled()

# -- Public API ----------------------------------------------------------------

## Toggles the pause menu open or closed.
func toggle() -> void:
	if _exit_confirm_open:
		_close_exit_confirm()
	elif _settings_open:
		_close_settings()
	elif _controls_open:
		_close_controls()
	elif _open:
		_close()
	else:
		_open_menu()

## Opens the pause menu and pauses the game.
func open() -> void:
	if not _open:
		_open_menu()

## Closes the pause menu and resumes the game.
func close() -> void:
	if _open:
		_close()

# -- Audio bus setup -----------------------------------------------------------

## Ensures all required audio buses exist in the audio system.
func _ensure_audio_buses() -> void:
	_music_bus_idx = AudioServer.get_bus_index("Music")
	if _music_bus_idx == -1:
		AudioServer.add_bus()
		_music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus_idx, "Music")
		AudioServer.set_bus_send(_music_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_music_bus_idx, 0.0)
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if _sfx_bus_idx == -1:
		AudioServer.add_bus()
		_sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, "Master")
		AudioServer.set_bus_volume_db(_sfx_bus_idx, 0.0)
	var mm: Node = get_tree().root.get_node_or_null("MusicManager")
	if mm:
		for child in mm.get_children():
			if child is AudioStreamPlayer:
				child.bus = "Music"

# -- UI: Main panel ------------------------------------------------------------
# Pixel layout (PANEL_H=138):
#   0-18   title bar + PAUSED label + divider at 18
#   22-34  status line 1 (h=12)
#   36-48  status line 2 (h=12)
#   52     divider
#   56-70  Resume    (14px btn)
#   73-87  Save      (3px gap)
#   90-104 Settings  (3px gap)
#   107-121 Exit     (3px gap)
#   126-134 [ESC] Close hint

## Constructs the main pause menu UI with panels and buttons.
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = C_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = Control.new()
	_panel.name = "PausePanel"
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Solid background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)

	# Borders
	_panel.add_child(_border(Vector2.ZERO, Vector2(PANEL_W, PANEL_H), C_BORDER))
	_panel.add_child(_border(Vector2(2, 2), Vector2(PANEL_W - 4, PANEL_H - 4), C_BORDER_D))

	# Title bar
	var tbg := ColorRect.new()
	tbg.color = Color(0.14, 0.09, 0.03, 1.0)
	tbg.size = Vector2(PANEL_W, 18)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(tbg)

	_panel.add_child(_centered_label("PAUSED", 9, 2, 16, PANEL_W, C_TITLE))
	_panel.add_child(_hdiv(4, 18, PANEL_W - 8, C_BORDER))

	# Status
	var s1 := _centered_label("", 6, 22, 12, PANEL_W - 16, C_TEXT)
	s1.name = "StatusLabel"
	s1.position.x = 8
	_panel.add_child(s1)

	var s2 := _centered_label("", 6, 36, 12, PANEL_W - 16, C_MUTED)
	s2.name = "StatusLabel2"
	s2.position.x = 8
	_panel.add_child(s2)

	_panel.add_child(_hdiv(10, 52, PANEL_W - 20, C_BORDER_D))

	# Buttons -- custom Control nodes, pixel-perfect
	var bw: int = PANEL_W - 30
	var bx: int = 15
	var by := 56
	var btn_data: Array = [
		["Resume", Callable(self, "_on_resume")],
		["Save", Callable(self, "_on_save")],
		["Controls", Callable(self, "_on_controls")],
		["Settings", Callable(self, "_on_settings")],
		["Exit", Callable(self, "_on_exit")],
	]
	for info in btn_data:
		var btn: Control = _make_btn(info[0], Vector2(bx, by), Vector2(bw, BTN_H), info[1])
		_panel.add_child(btn)
		by += BTN_H + BTN_GAP

	# ESC hint well below last button
	_panel.add_child(_centered_label("[ESC] Close", 4, 143, 8, PANEL_W, C_MUTED))

# -- UI: Settings sub-panel ---------------------------------------------------

## Builds the settings panel with audio sliders.
func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.size = Vector2(SETTINGS_W, SETTINGS_H)
	_settings_panel.position = Vector2(
		(VP_W - SETTINGS_W) / 2.0, (VP_H - SETTINGS_H) / 2.0)
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.visible = false
	add_child(_settings_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(bg)
	_settings_panel.add_child(
		_border(Vector2.ZERO, Vector2(SETTINGS_W, SETTINGS_H), C_BORDER))

	var tbg := ColorRect.new()
	tbg.color = Color(0.14, 0.09, 0.03, 1.0)
	tbg.size = Vector2(SETTINGS_W, 18)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(tbg)
	_settings_panel.add_child(
		_centered_label("SETTINGS", 9, 2, 16, SETTINGS_W, C_TITLE))
	_settings_panel.add_child(_hdiv(4, 18, SETTINGS_W - 8, C_BORDER))

	var ry := 24
	var lx := 10
	var sx := 48
	var sw := 70
	var px := 120

	# Music row
	_settings_panel.add_child(_vlabel("Music", 6, Vector2(lx, ry), Vector2(36, 14)))
	_music_slider = _make_slider(Vector2(sx, ry + 2), Vector2(sw, 10))
	_music_slider.value = _db_to_pct(_bus_vol("Music"))
	_music_slider.value_changed.connect(_on_music_vol)
	_settings_panel.add_child(_music_slider)
	_music_pct_label = _vlabel(str(int(_music_slider.value)) + "%", 6,
		Vector2(px, ry), Vector2(26, 14))
	_music_pct_label.add_theme_color_override("font_color", C_MUTED)
	_settings_panel.add_child(_music_pct_label)
	ry += 18

	# SFX row
	_settings_panel.add_child(_vlabel("Effects", 6, Vector2(lx, ry), Vector2(36, 14)))
	_sfx_slider = _make_slider(Vector2(sx, ry + 2), Vector2(sw, 10))
	_sfx_slider.value = _db_to_pct(_bus_vol("SFX"))
	_sfx_slider.value_changed.connect(_on_sfx_vol)
	_settings_panel.add_child(_sfx_slider)
	_sfx_pct_label = _vlabel(str(int(_sfx_slider.value)) + "%", 6,
		Vector2(px, ry), Vector2(26, 14))
	_sfx_pct_label.add_theme_color_override("font_color", C_MUTED)
	_settings_panel.add_child(_sfx_pct_label)
	ry += 18

	# Master row
	_settings_panel.add_child(_vlabel("Master", 6, Vector2(lx, ry), Vector2(36, 14)))
	_master_slider = _make_slider(Vector2(sx, ry + 2), Vector2(sw, 10))
	_master_slider.value = _db_to_pct(_bus_vol("Master"))
	_master_slider.value_changed.connect(_on_master_vol)
	_master_slider.name = "MasterSlider"
	_settings_panel.add_child(_master_slider)
	var mp := _vlabel(str(int(_master_slider.value)) + "%", 6, Vector2(px, ry), Vector2(26, 14))
	mp.name = "MasterPctLabel"
	mp.add_theme_color_override("font_color", C_MUTED)
	_settings_panel.add_child(mp)
	ry += 20

	_settings_panel.add_child(_hdiv(10, ry, SETTINGS_W - 20, C_BORDER_D))
	ry += 6

	# Mute checkbox
	_mute_checkbox = CheckBox.new()
	_mute_checkbox.text = "Mute Music"
	_mute_checkbox.position = Vector2(lx, ry)
	_mute_checkbox.size = Vector2(SETTINGS_W - 20, 14)
	_mute_checkbox.add_theme_font_size_override("font_size", 6)
	_mute_checkbox.add_theme_color_override("font_color", C_TEXT)
	_mute_checkbox.focus_mode = Control.FOCUS_NONE
	var mi: int = AudioServer.get_bus_index("Music")
	if mi != -1:
		_mute_checkbox.button_pressed = AudioServer.is_bus_mute(mi)
	_mute_checkbox.toggled.connect(_on_mute)
	_settings_panel.add_child(_mute_checkbox)

	var back: Control = _make_btn("Back",
		Vector2((SETTINGS_W - 60) / 2.0, SETTINGS_H - 22),
		Vector2(60, BTN_H), Callable(self, "_close_settings"))
	_settings_panel.add_child(back)

# -- Slider factory ------------------------------------------------------------

## Creates a styled audio volume slider.
func _make_slider(pos: Vector2, sz: Vector2) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = sz
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = 100.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.18, 0.12, 0.05, 1.0)
	track.border_color = C_BORDER_D
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	s.add_theme_stylebox_override("slider", track)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.90, 0.62, 0.15, 1.0)
	grab.set_corner_radius_all(2)
	s.add_theme_stylebox_override("grabber_area", grab)
	return s

# -- Volume helpers ------------------------------------------------------------

## Retrieves the current volume (dB) for an audio bus.
func _bus_vol(bus: String) -> float:
	var i: int = AudioServer.get_bus_index(bus)
	if i == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(i)

## Sets the volume (dB) for an audio bus.
func _set_bus(bus: String, db: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, db)
	AudioServer.set_bus_mute(i, db <= -60.0)

## Converts a percentage (0-100) to decibels.
func _pct_to_db(p: float) -> float:
	if p <= 0.0:
		return -80.0
	return linear_to_db(p / 100.0)

## Converts decibels to a percentage (0-100).
func _db_to_pct(db: float) -> float:
	if db <= -60.0:
		return 0.0
	return db_to_linear(db) * 100.0

## Handles music volume slider changes.
func _on_music_vol(v: float) -> void:
	_set_bus("Music", _pct_to_db(v))
	if _music_pct_label:
		_music_pct_label.text = str(int(v)) + "%"
	if v > 0.0 and _mute_checkbox and _mute_checkbox.button_pressed:
		_mute_checkbox.set_pressed_no_signal(false)

## Handles SFX volume slider changes.
func _on_sfx_vol(v: float) -> void:
	_set_bus("SFX", _pct_to_db(v))
	if _sfx_pct_label:
		_sfx_pct_label.text = str(int(v)) + "%"

## Handles mute toggle changes.
func _on_mute(muted: bool) -> void:
	var i: int = AudioServer.get_bus_index("Music")
	if i != -1:
		AudioServer.set_bus_mute(i, muted)

## Handles master volume slider changes.
func _on_master_vol(v: float) -> void:
	_set_bus("Master", _pct_to_db(v))
	var l: Label = _settings_panel.get_node_or_null("MasterPctLabel") as Label
	if l:
		l.text = str(int(v)) + "%"

# -- Custom button factory (no Godot Button -- pure pixel control) ------------
# Each "button" is a Control with two ColorRect children (border + fill) and
# a Label child. Mouse hover/press colors are applied manually via signals.
# This avoids Godot's Button auto-expand and minimum-size calculations that
# break at 320x180 viewports.

## Creates a styled button with theme overrides.
func _make_btn(label_text: String, pos: Vector2, sz: Vector2,
		callback: Callable) -> Control:
	var root := Control.new()
	root.position = pos
	root.size = sz
	root.custom_minimum_size = sz
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Border rect (outer) -- acts as a 1px border around the fill
	var border_rect := ColorRect.new()
	border_rect.name = "Border"
	border_rect.position = Vector2.ZERO
	border_rect.size = sz
	border_rect.color = C_BTN_BORDER
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(border_rect)

	# Fill rect (inner) -- inset by 1px on each side
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2(1, 1)
	fill.size = Vector2(sz.x - 2, sz.y - 2)
	fill.color = C_BTN_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)

	# Label -- nudged up 2px to visually center (Godot font descent
	# pushes text low at small sizes)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = label_text
	lbl.position = Vector2(0, -2)
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", C_BTN_TEXT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

	# Hover state
	root.mouse_entered.connect(func() -> void:
		border_rect.color = C_BTN_BORDER_H
		fill.color = C_BTN_FILL_H
		lbl.add_theme_color_override("font_color", C_BTN_TEXT_H)
	)
	root.mouse_exited.connect(func() -> void:
		border_rect.color = C_BTN_BORDER
		fill.color = C_BTN_FILL
		lbl.add_theme_color_override("font_color", C_BTN_TEXT)
	)

	# Click handling
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					border_rect.color = C_BTN_BORDER_P
					fill.color = C_BTN_FILL_P
					lbl.add_theme_color_override("font_color", C_BTN_TEXT_P)
				else:
					# Released inside -- fire callback
					border_rect.color = C_BTN_BORDER_H
					fill.color = C_BTN_FILL_H
					lbl.add_theme_color_override("font_color", C_BTN_TEXT_H)
					callback.call()
	)

	return root

# -- Open / Close --------------------------------------------------------------

## Opens the main menu UI.
func _open_menu() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	_refresh_status()
	_panel.visible = true
	_settings_panel.visible = false
	_settings_open = false
	_controls_open = false
	if _controls_panel:
		_controls_panel.visible = false
	_exit_confirm_open = false
	if _exit_confirm:
		_exit_confirm.visible = false
	_panel.position.y = float(PANEL_Y) - 16.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:y", float(PANEL_Y), 0.15)

## Closes the pause menu.
func _close() -> void:
	_open = false
	_settings_open = false
	_controls_open = false
	_exit_confirm_open = false
	get_tree().paused = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_panel, "position:y", float(PANEL_Y) - 16.0, 0.10)
	await tw.finished
	visible = false
	_settings_panel.visible = false
	if _controls_panel:
		_controls_panel.visible = false
	if _exit_confirm:
		_exit_confirm.visible = false

## Updates the status display (paused/unpaused state).
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
		s2.text = "$%.2f | E:%d%% | %s" % [
			GameData.money, int(GameData.energy), GameData.get_level_title()
		]

## Opens the settings panel.
func _on_settings() -> void:
	_settings_open = true
	_panel.visible = false
	_settings_panel.visible = true
	if _music_slider:
		_music_slider.value = _db_to_pct(_bus_vol("Music"))
	if _sfx_slider:
		_sfx_slider.value = _db_to_pct(_bus_vol("SFX"))
	if _master_slider:
		_master_slider.value = _db_to_pct(_bus_vol("Master"))
	var i: int = AudioServer.get_bus_index("Music")
	if i != -1 and _mute_checkbox:
		_mute_checkbox.set_pressed_no_signal(AudioServer.is_bus_mute(i))

## Closes the settings panel.
func _close_settings() -> void:
	_settings_open = false
	_settings_panel.visible = false
	_panel.visible = true

# -- UI: Controls reference panel -----------------------------------------------

## Builds the controls/keybindings reference panel.
func _build_controls_panel() -> void:
	_controls_panel = Control.new()
	_controls_panel.name = "ControlsPanel"
	_controls_panel.size = Vector2(CONTROLS_W, CONTROLS_H)
	_controls_panel.position = Vector2(
		(VP_W - CONTROLS_W) / 2.0, (VP_H - CONTROLS_H) / 2.0)
	_controls_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_panel.visible = false
	add_child(_controls_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_panel.add_child(bg)
	_controls_panel.add_child(
		_border(Vector2.ZERO, Vector2(CONTROLS_W, CONTROLS_H), C_BORDER))

	# Title bar (compact)
	var tbg := ColorRect.new()
	tbg.color = Color(0.14, 0.09, 0.03, 1.0)
	tbg.size = Vector2(CONTROLS_W, 14)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_panel.add_child(tbg)
	_controls_panel.add_child(
		_centered_label("CONTROLS", 7, 1, 12, CONTROLS_W, C_TITLE))
	_controls_panel.add_child(_hdiv(4, 14, CONTROLS_W - 8, C_BORDER))

	# Two-column layout sized for 320x180 viewport.
	# Row height 7px, font size 4, tight section gaps.
	var ry := 17
	var kx := 6       # key column x
	var dx := 40      # description column x
	var rh := 7       # row height
	var sg := 2       # section gap
	var fs := 4       # font size for rows
	var hs := 4       # font size for headers

	# Movement
	_controls_panel.add_child(_ctrl_label("MOVEMENT", hs, Vector2(kx, ry), C_TITLE))
	ry += rh + 1
	ry = _ctrl_row(kx, dx, ry, rh, fs, "WASD", "Move")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "Shift", "Run")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "Z", "Sleep / Next day")
	ry += sg

	# Interaction
	_controls_panel.add_child(_ctrl_label("INTERACTION", hs, Vector2(kx, ry), C_TITLE))
	ry += rh + 1
	ry = _ctrl_row(kx, dx, ry, rh, fs, "E", "Interact / Use / Confirm")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "R", "Rotate")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "1-9", "Select inventory slot")
	ry += sg

	# Menus
	_controls_panel.add_child(_ctrl_label("MENUS", hs, Vector2(kx, ry), C_TITLE))
	ry += rh + 1
	ry = _ctrl_row(kx, dx, ry, rh, fs, "ESC / P", "Pause menu")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "J", "Knowledge Journal")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "Tab", "Info panel")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "M", "Map")
	ry += sg

	# Hive Inspection
	_controls_panel.add_child(_ctrl_label("HIVE INSPECTION", hs, Vector2(kx, ry), C_TITLE))
	ry += rh + 1
	ry = _ctrl_row(kx, dx, ry, rh, fs, "W / S", "Navigate boxes")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "A / D", "Switch frames")
	ry = _ctrl_row(kx, dx, ry, rh, fs, "F", "Flip frame side")

	# Back button at bottom
	var back: Control = _make_btn("Back",
		Vector2((CONTROLS_W - 50) / 2.0, CONTROLS_H - 18),
		Vector2(50, 12), Callable(self, "_close_controls"))
	_controls_panel.add_child(back)

## Adds one key-description row to the controls panel. Returns next y.
func _ctrl_row(kx: int, dx: int, y: int, rh: int, fs: int,
		key: String, desc: String) -> int:
	_controls_panel.add_child(_ctrl_label(key, fs, Vector2(kx, y), C_BTN_TEXT_H))
	_controls_panel.add_child(_ctrl_label(desc, fs, Vector2(dx, y), C_TEXT))
	return y + rh

## Helper: creates a small label for controls panel rows.
func _ctrl_label(text: String, font_size: int, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(150, 10)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Opens the controls panel.
func _on_controls() -> void:
	_controls_open = true
	_panel.visible = false
	_controls_panel.visible = true

## Closes the controls panel.
func _close_controls() -> void:
	_controls_open = false
	_controls_panel.visible = false
	_panel.visible = true

## Resumes the game from the pause menu.
func _on_resume() -> void:
	_close()

## Saves the game.
func _on_save() -> void:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("save_game"):
		sm.save_game()
		var lbl: Label = _panel.get_node_or_null("StatusLabel") as Label
		if lbl:
			lbl.text = "Game saved!"

## Shows the exit confirmation dialog.
func _on_exit() -> void:
	_exit_confirm_open = true
	_panel.visible = false
	_exit_confirm.visible = true

## Saves and exits to the main menu.
func _on_save_and_exit() -> void:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("save_game"):
		sm.save_game()
	get_tree().paused = false
	get_tree().quit()

## Exits to the main menu without saving.
func _on_exit_no_save() -> void:
	get_tree().paused = false
	get_tree().quit()

## Closes the exit confirmation dialog.
func _close_exit_confirm() -> void:
	_exit_confirm_open = false
	_exit_confirm.visible = false
	_panel.visible = true

# -- Exit confirm dialog -------------------------------------------------------

## Builds the exit confirmation UI.
func _build_exit_confirm() -> void:
	var ew := 140
	var eh := 80
	_exit_confirm = Control.new()
	_exit_confirm.name = "ExitConfirm"
	_exit_confirm.size = Vector2(ew, eh)
	_exit_confirm.position = Vector2((VP_W - ew) / 2.0, (VP_H - eh) / 2.0)
	_exit_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_confirm.visible = false
	add_child(_exit_confirm)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_confirm.add_child(bg)
	_exit_confirm.add_child(_border(Vector2.ZERO, Vector2(ew, eh), C_BORDER))

	_exit_confirm.add_child(
		_centered_label("Save before exiting?", 7, 4, 14, ew, C_TITLE))
	_exit_confirm.add_child(_hdiv(6, 20, ew - 12, C_BORDER))

	var bw := 110
	var bx: float = (ew - bw) / 2.0
	var b1: Control = _make_btn("Save & Exit",
		Vector2(bx, 24), Vector2(bw, BTN_H),
		Callable(self, "_on_save_and_exit"))
	_exit_confirm.add_child(b1)
	var b2: Control = _make_btn("Exit Without Saving",
		Vector2(bx, 24 + BTN_H + BTN_GAP), Vector2(bw, BTN_H),
		Callable(self, "_on_exit_no_save"))
	_exit_confirm.add_child(b2)
	var b3: Control = _make_btn("Cancel",
		Vector2(bx, 24 + (BTN_H + BTN_GAP) * 2), Vector2(bw, BTN_H),
		Callable(self, "_close_exit_confirm"))
	_exit_confirm.add_child(b3)

# -- Helpers -------------------------------------------------------------------

## Creates a panel with a colored border.
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

## Creates a horizontal divider line.
func _hdiv(x: int, y: int, w: int, color: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.size = Vector2(w, 1)
	d.position = Vector2(x, y)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

## Creates a centered label.
func _centered_label(text: String, font_size: int, y: int, h: int,
		w: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(w, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Creates a vertically-aligned label.
func _vlabel(text: String, font_size: int, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", C_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
