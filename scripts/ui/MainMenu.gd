# MainMenu.gd
# -----------------------------------------------------------------------------
# Main menu / title screen for Smoke & Honey.
#
# Features:
#   - Animated title plate (Smoke & Honey logo area)
#   - New Game button
#   - Continue button (grayed out if no save exists)
#   - Settings stub (future)
#   - Quit button
#   - Background: dark amber with subtle bee-hive hex pattern
#   - Hooks into SaveManager for continue detection
# -----------------------------------------------------------------------------
extends Node

# -- Layout --------------------------------------------------------------------
const VP_W    := 320
const VP_H    := 180
const PANEL_W := 200
const PANEL_H := 150
const PANEL_X := (VP_W - PANEL_W) / 2
const PANEL_Y := (VP_H - PANEL_H) / 2

# -- Colors --------------------------------------------------------------------
const C_BG        := Color(0.06, 0.04, 0.02, 1.0)
const C_PANEL     := Color(0.10, 0.07, 0.03, 0.97)
const C_BORDER    := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D  := Color(0.47, 0.28, 0.05, 1.0)
const C_TITLE     := Color(0.95, 0.78, 0.32, 1.0)
const C_SUBTITLE  := Color(0.70, 0.62, 0.45, 1.0)
const C_TEXT      := Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED     := Color(0.45, 0.40, 0.30, 1.0)
const C_HONEY     := Color(0.87, 0.60, 0.10, 1.0)

# -- Nodes ---------------------------------------------------------------------
var _root:     Control = null
var _canvas:   CanvasLayer = null
var _continue_btn: Button = null

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 0
	add_child(_canvas)

	_build_background()
	_build_panel()
	_animate_intro()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_quit()

# -- Background ----------------------------------------------------------------

func _build_background() -> void:
	# Dark base
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	# Subtle hex pattern (drawn as tiny amber dots)
	var pattern := Node2D.new()
	pattern.z_index = -1
	# Node2D doesn't have mouse_filter; just skip it (pattern is non-interactive)
	_canvas.add_child(pattern)

	# Draw hex grid as ColorRects (approximate, non-interactive)
	# Each "cell" is 18x20 offset grid
	var hex_color := Color(0.18, 0.12, 0.04, 0.45)
	for row in range(12):
		for col in range(22):
			var x: int = col * 16 + (8 if row % 2 == 1 else 0)
			var y := row * 14
			# Draw a tiny 3x3 diamond-ish shape
			var dot := ColorRect.new()
			dot.color = hex_color
			dot.size  = Vector2(4, 4)
			dot.position = Vector2(x, y)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_canvas.add_child(dot)

	# Vignette -- darker edges
	for side in ["left", "right", "top", "bottom"]:
		var vign := ColorRect.new()
		vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match side:
			"left":   vign.size = Vector2(40, VP_H);  vign.position = Vector2(0, 0);           vign.color = Color(0, 0, 0, 0.4)
			"right":  vign.size = Vector2(40, VP_H);  vign.position = Vector2(VP_W - 40, 0);   vign.color = Color(0, 0, 0, 0.4)
			"top":    vign.size = Vector2(VP_W, 30);  vign.position = Vector2(0, 0);           vign.color = Color(0, 0, 0, 0.35)
			"bottom": vign.size = Vector2(VP_W, 30);  vign.position = Vector2(0, VP_H - 30);   vign.color = Color(0, 0, 0, 0.35)
		_canvas.add_child(vign)

# -- Panel ---------------------------------------------------------------------

func _build_panel() -> void:
	_root = Control.new()
	_root.name = "MainMenuPanel"
	_root.size = Vector2(PANEL_W, PANEL_H)
	_root.position = Vector2(PANEL_X, PANEL_Y)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_root)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_PANEL
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Wood texture overlay if available
	var panel_tex := "res://assets/sprites/ui/panel_wood.png"
	if ResourceLoader.exists(panel_tex):
		var tex := TextureRect.new()
		tex.texture = load(panel_tex)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_TILE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(tex)

	# Outer border
	var osty := StyleBoxFlat.new()
	osty.bg_color = Color(0,0,0,0); osty.draw_center = false
	osty.border_color = C_BORDER; osty.set_border_width_all(2)
	var obrd := Panel.new()
	obrd.set_anchors_preset(Control.PRESET_FULL_RECT)
	obrd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obrd.add_theme_stylebox_override("panel", osty)
	_root.add_child(obrd)

	# Inner border
	var isty := StyleBoxFlat.new()
	isty.bg_color = Color(0,0,0,0); isty.draw_center = false
	isty.border_color = C_BORDER_D; isty.set_border_width_all(1)
	var ibrd := Panel.new()
	ibrd.position = Vector2(3, 3)
	ibrd.size = Vector2(PANEL_W - 6, PANEL_H - 6)
	ibrd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ibrd.add_theme_stylebox_override("panel", isty)
	_root.add_child(ibrd)

	# -- Title plate ---------------------------------------------------
	var title_plate := ColorRect.new()
	title_plate.color    = Color(0.18, 0.12, 0.04, 1.0)
	title_plate.size     = Vector2(PANEL_W - 8, 36)
	title_plate.position = Vector2(4, 6)
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_plate)

	# Honey accent line on plate
	var honey_line := ColorRect.new()
	honey_line.color    = C_HONEY
	honey_line.size     = Vector2(PANEL_W - 8, 1)
	honey_line.position = Vector2(0, 35)
	title_plate.add_child(honey_line)

	# Title plate texture
	var tp_tex := "res://assets/sprites/ui/title_plate.png"
	if ResourceLoader.exists(tp_tex):
		var tp := TextureRect.new()
		tp.texture = load(tp_tex)
		tp.set_anchors_preset(Control.PRESET_FULL_RECT)
		tp.stretch_mode = TextureRect.STRETCH_SCALE
		tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_plate.add_child(tp)

	# Bee icon in title
	var bee_icon := _icon("icon_bee.png", Vector2(10, 8), Vector2(18, 18))
	title_plate.add_child(bee_icon)

	# Title text
	var title := _lbl("Smoke & Honey", 12, Vector2(32, 6), Vector2(PANEL_W - 60, 14), C_TITLE)
	title_plate.add_child(title)

	var subtitle := _lbl("A Cedar Bend Story", 6, Vector2(32, 21), Vector2(PANEL_W - 60, 8), C_SUBTITLE)
	title_plate.add_child(subtitle)

	# Second bee icon (right side)
	var bee2 := _icon("icon_bee.png", Vector2(PANEL_W - 32, 8), Vector2(18, 18))
	title_plate.add_child(bee2)

	# Divider
	var div := ColorRect.new()
	div.color    = Color(0.47, 0.28, 0.05, 0.60)
	div.size     = Vector2(PANEL_W - 20, 1)
	div.position = Vector2(10, 46)
	_root.add_child(div)

	# -- Buttons -------------------------------------------------------
	var has_save := _check_save_exists()
	var btn_y    := 54

	var btn_new := _make_button("?  New Game", Vector2(24, btn_y), Vector2(PANEL_W - 48, 16))
	btn_new.pressed.connect(_on_new_game)
	_root.add_child(btn_new)
	btn_y += 20

	_continue_btn = _make_button("?  Continue", Vector2(24, btn_y), Vector2(PANEL_W - 48, 16))
	_continue_btn.pressed.connect(_on_continue)
	if not has_save:
		_continue_btn.disabled = true
		_continue_btn.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_root.add_child(_continue_btn)
	btn_y += 20

	var btn_settings := _make_button("?  Settings (soon)", Vector2(24, btn_y), Vector2(PANEL_W - 48, 16))
	btn_settings.pressed.connect(_on_settings)
	btn_settings.disabled = true
	btn_settings.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_root.add_child(btn_settings)
	btn_y += 20

	var btn_quit := _make_button("?  Quit", Vector2(24, btn_y), Vector2(PANEL_W - 48, 16))
	btn_quit.pressed.connect(_on_quit)
	_root.add_child(btn_quit)

	# Version line
	var ver := _lbl("v0.1 dev  *  Cedar Bend, Iowa", 5,
		Vector2(0, PANEL_H - 10), Vector2(PANEL_W, 7), C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(ver)

# -- Animation -----------------------------------------------------------------

func _animate_intro() -> void:
	# Fade in from black
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# Panel starts off-screen below
	_root.position.y = float(PANEL_Y) + 30.0
	_root.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.6)
	tw.tween_property(_root, "position:y", float(PANEL_Y), 0.5).set_delay(0.2)
	tw.tween_property(_root, "modulate:a", 1.0, 0.5).set_delay(0.2)
	await tw.finished
	if is_instance_valid(overlay):
		overlay.queue_free()

# -- Button handlers -----------------------------------------------------------

func _on_new_game() -> void:
	# Reset game state
	GameData.money       = 500.0
	GameData.energy      = 100.0
	GameData.player_level = 1
	GameData.xp          = 0
	GameData.reputation  = 0.0
	TimeManager.current_day  = 1
	TimeManager.current_hour = 6.0
	_transition_to_game()

func _on_continue() -> void:
	# Load from SaveManager if available
	var sm := get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("load_from_disk"):
		sm.load_from_disk()
	_transition_to_game()

func _on_settings() -> void:
	pass  # Settings screen -- future

func _on_quit() -> void:
	_quit()

func _quit() -> void:
	get_tree().quit()

func _transition_to_game() -> void:
	# Fade to black then load the main game scene
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/TestEnvironment.tscn")

# -- Save detection ------------------------------------------------------------

func _check_save_exists() -> bool:
	# Check for a SaveManager autoload or a save file on disk
	var sm := get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("has_save"):
		return sm.has_save()
	# Fallback: check for the actual save file path
	return FileAccess.file_exists("user://smoke_and_honey_save.json")

# -- Helpers -------------------------------------------------------------------

func _make_button(label: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label; btn.position = pos; btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.10, 0.04, 1.0)
	normal.border_color = Color(0.60, 0.40, 0.10, 1.0); normal.set_border_width_all(1)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.28, 0.18, 0.06, 1.0)
	hover.border_color = Color(0.90, 0.62, 0.15, 1.0); hover.set_border_width_all(1)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.10, 0.07, 0.03, 1.0)
	pressed.border_color = Color(0.55, 0.35, 0.08, 1.0); pressed.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus",   normal)
	btn.add_theme_color_override("font_color",         Color(0.90, 0.85, 0.70, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.92, 0.60, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.65, 0.50, 1.0))
	btn.add_theme_color_override("font_disabled_color",Color(0.50, 0.45, 0.38, 1.0))
	return btn

func _icon(fname: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.position = pos; tr.size = sz
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/sprites/ui/" + fname
	if ResourceLoader.exists(path): tr.texture = load(path)
	return tr

func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new(); l.text = text; l.position = pos; l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
