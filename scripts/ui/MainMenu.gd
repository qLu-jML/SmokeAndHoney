# MainMenu.gd
# Startup / title screen for Smoke & Honey.
#
# Layout (320x180 viewport, 6x scaled to 1920x1080):
#   - Dark background with subtle warm center glow
#   - Game logo centered via Sprite2D (avoids TextureRect sizing issues)
#   - Buttons: Start, Continue, Quit
#   - Version label at the very bottom
#   - Main theme music plays on entry
# -------------------------------------------------------------------------
extends Node

# -- Viewport ------------------------------------------------------------------
const VP_W := 320
const VP_H := 180

# -- Button sizing (viewport pixels) ------------------------------------------
const BTN_W := 130
const BTN_H := 12
const BTN_SPACE := 3   # gap between buttons

# -- Colors --------------------------------------------------------------------
const C_BG: Color = Color(0.05, 0.03, 0.01, 1.0)
const C_TITLE: Color = Color(0.95, 0.78, 0.32, 1.0)
const C_SUBTITLE: Color = Color(0.70, 0.62, 0.45, 1.0)
const C_TEXT: Color = Color(0.88, 0.83, 0.68, 1.0)
const C_MUTED: Color = Color(0.45, 0.40, 0.30, 1.0)
const C_HONEY: Color = Color(0.87, 0.60, 0.10, 1.0)
const C_SPRING: Color = Color(0.45, 0.75, 0.30, 1.0)

# -- State ---------------------------------------------------------------------
var _canvas: CanvasLayer = null
var _continue_btn: Button = null

# =============================================================================
# Lifecycle
# =============================================================================

## Initialize the main menu scene.
func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 0
	add_child(_canvas)

	_build_background()
	_build_logo()
	_build_buttons()
	_build_version()
	_animate_intro()

	if MusicManager:
		MusicManager.play_title_theme()

## Handle input events (ESC to quit).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

# =============================================================================
# Background
# =============================================================================

## Build the background and warm glow effect.
func _build_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	# Warm glow behind logo area
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(0.10, 0.06, 0.02, 0.30)
	var gw: int = 200
	var gh: int = 90
	glow.size = Vector2(gw, gh)
	glow.position = Vector2((VP_W - gw) / 2.0, 2)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(glow)

# =============================================================================
# Logo - TextureRect (Control) so it renders in the same layer as other Controls
# =============================================================================

## Build and display the game logo.
func _build_logo() -> void:
	var logo_tex: Texture2D = null

	# Try load() first (uses imported .ctex if available)
	var res: Resource = load("res://assets/ui/logo/game_logo.png")
	if res is Texture2D:
		logo_tex = res as Texture2D
		print("[MainMenu] Logo loaded via load()")

	# Fallback: load raw image bytes from disk
	if logo_tex == null:
		var abs_path: String = ProjectSettings.globalize_path("res://assets/ui/logo/game_logo.png")
		var img: Image = Image.load_from_file(abs_path)
		if img == null or img.get_width() == 0:
			abs_path = ProjectSettings.globalize_path("res://assets/ui/logo/game_logo.jpg")
			img = Image.load_from_file(abs_path)
		if img != null and img.get_width() > 0:
			logo_tex = ImageTexture.create_from_image(img)
			print("[MainMenu] Logo loaded via Image.load_from_file()")

	if logo_tex != null:
		var target_w: int = 80
		var target_h: int = 80
		var logo_rect: TextureRect = TextureRect.new()
		logo_rect.texture = logo_tex
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.size = Vector2(target_w, target_h)
		logo_rect.position = Vector2((VP_W - target_w) / 2.0, 4)
		logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(logo_rect)
		print("[MainMenu] Logo displayed as TextureRect %dx%d" % [target_w, target_h])
	else:
		push_warning("[MainMenu] Logo not found - text fallback")
		var title: Label = _lbl("Smoke & Honey", 14,
			Vector2(0, 20), Vector2(VP_W, 24), C_TITLE)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas.add_child(title)
		var sub: Label = _lbl("A Cedar Bend Story", 7,
			Vector2(0, 48), Vector2(VP_W, 12), C_SUBTITLE)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_canvas.add_child(sub)

# =============================================================================
# Buttons
# =============================================================================

## Build the main menu buttons and dividers.
func _build_buttons() -> void:
	var cx: float = (VP_W - BTN_W) / 2.0
	# Start buttons below logo area
	var y: int = 92

	# Thin amber divider above buttons
	var div1: ColorRect = ColorRect.new()
	div1.color = Color(0.80, 0.53, 0.10, 0.20)
	div1.size = Vector2(BTN_W, 1)
	div1.position = Vector2(cx, y - 3)
	div1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(div1)

	# -- Start -- (_make_btn adds to _canvas internally via wrapper)
	var btn_start: Button = _make_btn("Start", Vector2(cx, y), C_SPRING)
	btn_start.pressed.connect(_on_start)
	y += BTN_H + BTN_SPACE

	# -- Continue --
	var has_save: bool = _check_save_exists()
	_continue_btn = _make_btn("Continue", Vector2(cx, y), C_HONEY)
	_continue_btn.pressed.connect(_on_continue)
	if not has_save:
		_continue_btn.disabled = true
		_continue_btn.get_parent().modulate = Color(1, 1, 1, 0.30)
	y += BTN_H + BTN_SPACE

	# Small divider
	var div2: ColorRect = ColorRect.new()
	div2.color = Color(0.47, 0.28, 0.05, 0.30)
	div2.size = Vector2(BTN_W - 30, 1)
	div2.position = Vector2(cx + 15, y)
	div2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(div2)
	y += 4

	# -- Quit --
	var btn_quit: Button = _make_btn("Quit", Vector2(cx, y), C_MUTED)
	btn_quit.pressed.connect(get_tree().quit)

	# Thin amber divider below buttons
	y += BTN_H + 3
	var div3: ColorRect = ColorRect.new()
	div3.color = Color(0.80, 0.53, 0.10, 0.20)
	div3.size = Vector2(BTN_W, 1)
	div3.position = Vector2(cx, y)
	div3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(div3)

# =============================================================================
# Version line
# =============================================================================

## Build the version label at the bottom of the screen.
func _build_version() -> void:
	var ver: Label = _lbl("v0.1 dev - Cedar Bend, Iowa", 4,
		Vector2(0, VP_H - 8), Vector2(VP_W, 6), C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(ver)

# =============================================================================
# Intro fade
# =============================================================================

## Animate the intro fade from black.
func _animate_intro() -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 1)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	var tw: Tween = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.8)
	await tw.finished
	if is_instance_valid(overlay):
		overlay.queue_free()

# =============================================================================
# Button handlers
# =============================================================================

## Reset common game state for a new game.
func _reset_common_state() -> void:
	GameData.money        = 500.0
	GameData.energy       = 100.0
	GameData.player_level = 1
	GameData.xp           = 0
	GameData.reputation   = 0.0
	GameData.player_inventory       = []
	GameData.player_inventory_valid = false
	TimeManager.current_hour = 6.0

## Start a new game.
func _on_start() -> void:
	_reset_common_state()
	# Always start in Spring (day 1)
	GameData.new_game_mode = 0
	TimeManager.current_day = 1
	# Skip character creation -- set defaults and go straight to gameplay
	if not PlayerData.character_created:
		PlayerData.player_name = "Beekeeper"
		PlayerData.backstory_tag = "newcomer"
		PlayerData.character_created = true
	_transition_to_game()

## Load and continue from the last saved game.
func _on_continue() -> void:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("load_from_disk"):
		sm.load_from_disk()
	_transition_to_game()

## Fade to black and transition to the main game scene.
func _transition_to_game() -> void:
	if MusicManager:
		MusicManager.resume_seasonal_music()
	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.z_index = 99
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/home_property.tscn")

# =============================================================================
# Save detection
# =============================================================================

## Check if a save file exists.
func _check_save_exists() -> bool:
	var sm: Node = get_tree().root.get_node_or_null("SaveManager")
	if sm and sm.has_method("has_save"):
		return sm.has_save()
	return FileAccess.file_exists("user://smoke_and_honey_save.json")

# =============================================================================
# Button factory - wrapper Control enforces fixed size
# =============================================================================

## Create a styled menu button with the given label and accent color.
func _make_btn(label: String, pos: Vector2, accent: Color) -> Button:
	var wrapper: Control = Control.new()
	wrapper.position = pos
	wrapper.size = Vector2(BTN_W, BTN_H)
	wrapper.clip_contents = true
	_canvas.add_child(wrapper)

	var btn: Button = Button.new()
	btn.text = label
	btn.anchor_left = 0.0
	btn.anchor_top = 0.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 0
	btn.offset_top = 0
	btn.offset_right = 0
	btn.offset_bottom = 0
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 6)
	btn.add_theme_constant_override("h_separation", 0)

	var dim: Color = accent.darkened(0.50)

	var sty_n: StyleBoxFlat = StyleBoxFlat.new()
	sty_n.bg_color = Color(0.08, 0.05, 0.02, 0.85)
	sty_n.border_color = dim
	sty_n.set_border_width_all(1)
	sty_n.set_corner_radius_all(0)
	sty_n.set_content_margin_all(1)

	var sty_h: StyleBoxFlat = StyleBoxFlat.new()
	sty_h.bg_color = Color(0.16, 0.10, 0.03, 0.92)
	sty_h.border_color = accent
	sty_h.set_border_width_all(1)
	sty_h.set_corner_radius_all(0)
	sty_h.set_content_margin_all(1)

	var sty_p: StyleBoxFlat = StyleBoxFlat.new()
	sty_p.bg_color = Color(0.04, 0.03, 0.01, 0.95)
	sty_p.border_color = dim
	sty_p.set_border_width_all(1)
	sty_p.set_corner_radius_all(0)
	sty_p.set_content_margin_all(1)

	btn.add_theme_stylebox_override("normal",  sty_n)
	btn.add_theme_stylebox_override("hover",   sty_h)
	btn.add_theme_stylebox_override("pressed", sty_p)
	btn.add_theme_stylebox_override("focus",   sty_n)

	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   accent.lightened(0.30))
	btn.add_theme_color_override("font_pressed_color", Color(0.65, 0.58, 0.45, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.38, 0.34, 0.26, 1.0))
	wrapper.add_child(btn)
	return btn

# =============================================================================
# Label helper
# =============================================================================

## Create a styled label with the given text and color.
func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
