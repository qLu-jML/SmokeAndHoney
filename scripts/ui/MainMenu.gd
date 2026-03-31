# MainMenu.gd
# -----------------------------------------------------------------------------
# Startup / title screen for Smoke & Honey.
#
# Layout (320x180 viewport):
#   - Full-screen dark amber background with hex dot pattern
#   - Game logo (assets/ui/logo/game_logo.png) centered in upper half
#   - Button panel below logo:
#       [Start in Spring]             -- new game, day 1 (Quickening)
#       [Start in Fall | 2 Full Supers] -- new game, day 113 (Full-Earth)
#       [Continue]                    -- load save (disabled if no save)
#       [Quit]
#   - Version line at bottom
#   - Main theme music plays on entry; seasonal music resumes on game start
# -----------------------------------------------------------------------------
extends Node

# -- Layout --------------------------------------------------------------------
const VP_W     := 320
const VP_H     := 180
const PANEL_W  := 196
const PANEL_H  := 104
const PANEL_X  : int = (VP_W - PANEL_W) / 2
const LOGO_H   := 64    # logo display height (it is square, so width = 64 too)
const LOGO_Y   : int = 6

# -- Colors --------------------------------------------------------------------
const C_BG       := Color(0.06, 0.04, 0.02, 1.0)
const C_PANEL    := Color(0.10, 0.07, 0.03, 0.97)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE    := Color(0.95, 0.78, 0.32, 1.0)
const C_SUBTITLE := Color(0.70, 0.62, 0.45, 1.0)
const C_TEXT     := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED    := Color(0.45, 0.40, 0.30, 1.0)
const C_HONEY    := Color(0.87, 0.60, 0.10, 1.0)
const C_SPRING   := Color(0.45, 0.75, 0.30, 1.0)
const C_FALL     := Color(0.85, 0.45, 0.10, 1.0)

# -- Nodes ---------------------------------------------------------------------
var _root:         Control    = null
var _canvas:       CanvasLayer = null
var _continue_btn: Button     = null

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 0
	add_child(_canvas)

	_build_background()
	_build_logo()
	_build_panel()
	_animate_intro()

	# Start the main title theme
	if MusicManager:
		MusicManager.play_title_theme()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_quit()

# -- Background ----------------------------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	# Subtle hex dot grid
	var hex_color := Color(0.18, 0.12, 0.04, 0.45)
	for row in range(12):
		for col in range(22):
			var x: int = col * 16 + (8 if row % 2 == 1 else 0)
			var y: int = row * 14
			var dot := ColorRect.new()
			dot.color = hex_color
			dot.size  = Vector2(4, 4)
			dot.position = Vector2(x, y)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_canvas.add_child(dot)

	# Vignette edges
	for side in ["left", "right", "top", "bottom"]:
		var vign := ColorRect.new()
		vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match side:
			"left":   vign.size = Vector2(40, VP_H);  vign.position = Vector2(0, 0);          vign.color = Color(0, 0, 0, 0.4)
			"right":  vign.size = Vector2(40, VP_H);  vign.position = Vector2(VP_W - 40, 0);  vign.color = Color(0, 0, 0, 0.4)
			"top":    vign.size = Vector2(VP_W, 30);  vign.position = Vector2(0, 0);          vign.color = Color(0, 0, 0, 0.35)
			"bottom": vign.size = Vector2(VP_W, 30);  vign.position = Vector2(0, VP_H - 30);  vign.color = Color(0, 0, 0, 0.35)
		_canvas.add_child(vign)

# -- Logo ----------------------------------------------------------------------

func _build_logo() -> void:
	var logo_path := "res://assets/ui/logo/game_logo.png"
	if ResourceLoader.exists(logo_path):
		var logo := TextureRect.new()
		logo.texture = load(logo_path)
		logo.size = Vector2(LOGO_H, LOGO_H)
		# Center horizontally; LOGO_Y from top
		logo.position = Vector2((VP_W - LOGO_H) / 2.0, float(LOGO_Y))
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(logo)
	else:
		# Fallback: text logo if PNG not found
		var title := _lbl("Smoke & Honey", 14,
			Vector2(0.0, float(LOGO_Y) + 16.0), Vector2(float(VP_W), 20.0), C_TITLE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas.add_child(title)
		var sub := _lbl("A Cedar Bend Story", 7,
			Vector2(0.0, float(LOGO_Y) + 38.0), Vector2(float(VP_W), 12.0), C_SUBTITLE)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas.add_child(sub)

# -- Panel ---------------------------------------------------------------------

func _build_panel() -> void:
	# Panel sits just below the logo
	var panel_y: int = LOGO_Y + LOGO_H + 4
	_root = Control.new()
	_root.name = "MainMenuPanel"
	_root.size = Vector2(PANEL_W, PANEL_H)
	_root.position = Vector2(PANEL_X, panel_y)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_root)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Outer border
	var osty := StyleBoxFlat.new()
	osty.bg_color = Color(0, 0, 0, 0); osty.draw_center = false
	osty.border_color = C_BORDER; osty.set_border_width_all(2)
	var obrd := Panel.new()
	obrd.set_anchors_preset(Control.PRESET_FULL_RECT)
	obrd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obrd.add_theme_stylebox_override("panel", osty)
	_root.add_child(obrd)

	# Inner border
	var isty := StyleBoxFlat.new()
	isty.bg_color = Color(0, 0, 0, 0); isty.draw_center = false
	isty.border_color = C_BORDER_D; isty.set_border_width_all(1)
	var ibrd := Panel.new()
	ibrd.position = Vector2(3, 3)
	ibrd.size = Vector2(PANEL_W - 6, PANEL_H - 6)
	ibrd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ibrd.add_theme_stylebox_override("panel", isty)
	_root.add_child(ibrd)

	# Divider line under panel top
	var div := ColorRect.new()
	div.color    = Color(0.47, 0.28, 0.05, 0.60)
	div.size     = Vector2(PANEL_W - 20, 1)
	div.position = Vector2(10, 8)
	_root.add_child(div)

	# -- Buttons -------------------------------------------------------
	var has_save := _check_save_exists()
	var btn_y    := 14

	# "Start in Spring" -- standard day-1 new game
	var btn_spring := _make_button("> Start in Spring", Vector2(16, btn_y), Vector2(PANEL_W - 32, 17), C_SPRING)
	btn_spring.pressed.connect(_on_start_spring)
	_root.add_child(btn_spring)
	btn_y += 21

	# "Start in Fall | 2 Full Supers" -- fall day-113 new game
	var btn_fall := _make_button("> Start in Fall  |  2 Full Supers", Vector2(16, btn_y), Vector2(PANEL_W - 32, 17), C_FALL)
	btn_fall.pressed.connect(_on_start_fall)
	_root.add_child(btn_fall)
	btn_y += 21

	# Divider
	var div2 := ColorRect.new()
	div2.color    = Color(0.47, 0.28, 0.05, 0.45)
	div2.size     = Vector2(PANEL_W - 40, 1)
	div2.position = Vector2(20, btn_y)
	_root.add_child(div2)
	btn_y += 6

	# Continue
	_continue_btn = _make_button("> Continue", Vector2(16, btn_y), Vector2(PANEL_W - 32, 17), C_HONEY)
	_continue_btn.pressed.connect(_on_continue)
	if not has_save:
		_continue_btn.disabled = true
		_continue_btn.modulate = Color(1.0, 1.0, 1.0, 0.40)
	_root.add_child(_continue_btn)
	btn_y += 21

	# Quit
	var btn_quit := _make_button("> Quit", Vector2(16, btn_y), Vector2(PANEL_W - 32, 17), C_MUTED)
	btn_quit.pressed.connect(_on_quit)
	_root.add_child(btn_quit)

	# Version line
	var ver := _lbl("v0.1 dev  *  Cedar Bend, Iowa", 5,
		Vector2(0, PANEL_H - 9), Vector2(PANEL_W, 7), C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(ver)

# -- Animation -----------------------------------------------------------------

func _animate_intro() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	_root.position.y = _root.position.y + 30.0
	_root.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.7)
	tw.tween_property(_root, "position:y", _root.position.y - 30.0, 0.5).set_delay(0.3)
	tw.tween_property(_root, "modulate:a", 1.0, 0.5).set_delay(0.3)
	await tw.finished
	if is_instance_valid(overlay):
		overlay.queue_free()

# -- Button handlers -----------------------------------------------------------

func _reset_common_state() -> void:
	GameData.money        = 500.0
	GameData.energy       = 100.0
	GameData.player_level = 1
	GameData.xp           = 0
	GameData.reputation   = 0.0
	TimeManager.current_hour = 6.0

func _on_start_spring() -> void:
	_reset_common_state()
	GameData.new_game_mode       = 0
	TimeManager.current_day      = 1
	_transition_to_game()

func _on_start_fall() -> void:
	_reset_common_state()
	GameData.new_game_mode       = 1
	# Day 113 = first day of Full-Earth (Fall M1) in the 8-month calendar
	TimeManager.current_day      = 113
	_transition_to_game()

func _on_continue() -> void:
	var sm := get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("load_from_disk"):
		sm.load_from_disk()
	_transition_to_game()

func _on_quit() -> void:
	_quit()

func _quit() -> void:
	get_tree().quit()

func _transition_to_game() -> void:
	# Hand music back to seasonal system
	if MusicManager:
		MusicManager.resume_seasonal_music()

	# Fade to black, then load home_property
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/home_property.tscn")

# -- Save detection ------------------------------------------------------------

func _check_save_exists() -> bool:
	var sm := get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("has_save"):
		return sm.has_save()
	return FileAccess.file_exists("user://smoke_and_honey_save.json")

# -- Helpers -------------------------------------------------------------------

func _make_button(label: String, pos: Vector2, sz: Vector2,
		accent: Color = C_HONEY) -> Button:
	var btn := Button.new()
	btn.text = label; btn.position = pos; btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	var border_dim := accent.darkened(0.35)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.08, 0.03, 1.0)
	normal.border_color = border_dim; normal.set_border_width_all(1)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.14, 0.05, 1.0)
	hover.border_color = accent; hover.set_border_width_all(1)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.05, 0.02, 1.0)
	pressed.border_color = border_dim; pressed.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus",   normal)
	btn.add_theme_color_override("font_color",          Color(0.90, 0.85, 0.70, 1.0))
	btn.add_theme_color_override("font_hover_color",    accent.lightened(0.2))
	btn.add_theme_color_override("font_pressed_color",  Color(0.70, 0.62, 0.50, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.30, 1.0))
	return btn

func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new(); l.text = text; l.position = pos; l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
