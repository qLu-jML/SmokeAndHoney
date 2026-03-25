# map_overlay.gd -- World navigation map (parchment county map).
# Opened by pressing M or interacting with the truck on County Road.
# GDD S13.2: The county road is where the map navigation interface lives.
# Phase 4: Full visual build -- parchment background, animated pins, travel confirmation.
extends CanvasLayer

# -- Signals -------------------------------------------------------------------
signal destination_selected(scene_path: String)

# -- Map Panel Layout -----------------------------------------------------------
# Panel anchored to center of screen.
const PANEL_W := 280
const PANEL_H := 150
const PANEL_X := 20   # centered in 320-wide viewport
const PANEL_Y := 15

# -- Destination Registry -------------------------------------------------------
# Each entry: { label, scene_path, unlocked, map_pos (on-panel), pin_color }
# map_pos is relative to panel origin (0,0).
var destinations: Array = [
	{
		"id":         "home",
		"label":      "Home Property",
		"scene_path": "res://scenes/TestEnvironment.tscn",
		"unlocked":   true,
		"map_pos":    Vector2(42, 55),
		"pin_key":    "map_pin_home",
		"desc":       "Your apiary -- the starting point of everything.",
	},
	{
		"id":         "county_road",
		"label":      "County Road",
		"scene_path": "res://scenes/world/county_road.tscn",
		"unlocked":   true,
		"map_pos":    Vector2(140, 60),
		"pin_key":    "map_pin_road",
		"desc":       "The gravel road connecting home to town.",
	},
	{
		"id":         "cedar_bend",
		"label":      "Cedar Bend",
		"scene_path": "res://scenes/world/cedar_bend.tscn",
		"unlocked":   false,
		"map_pos":    Vector2(230, 55),
		"pin_key":    "map_pin_town",
		"desc":       "The town. Feed store, diner, post office, Saturday market.",
	},
]

# -- Node References ------------------------------------------------------------
var _panel: ColorRect = null
var _background: Sprite2D = null
var _pin_nodes: Array = []
var _confirm_overlay: ColorRect = null
var _selected_dest: Dictionary = {}
var _hover_label: Label = null

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	# Unlock Cedar Bend if player is at least level 2 or has Community Standing >= 100
	_refresh_unlock_states()

func _refresh_unlock_states() -> void:
	for d in destinations:
		if d["id"] == "cedar_bend":
			if GameData.player_level >= 2 or GameData.reputation >= 100.0:
				d["unlocked"] = true
	_rebuild_pins()

# -- UI Build ------------------------------------------------------------------

func _build_ui() -> void:
	# Semi-transparent full-screen dim
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.55)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Main panel
	_panel = ColorRect.new()
	_panel.name = "MapPanel"
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.color = Color(0.855, 0.765, 0.596, 1.0)  # parchment fallback color
	add_child(_panel)

	# Parchment background texture
	var bg_tex_path := "res://assets/sprites/ui/map_background.png"
	if ResourceLoader.exists(bg_tex_path):
		var bg_sprite := TextureRect.new()
		bg_sprite.texture = load(bg_tex_path)
		bg_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		bg_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(bg_sprite)

	# -- Header --------------------------------------------------------------
	var header := _make_label("MILLHAVEN COUNTY", 10,
		Vector2(0, 8), Vector2(PANEL_W, 16),
		Color(0.235, 0.176, 0.110, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(header)

	var sub_header := _make_label("press ESC or M to close  *  click a destination to travel", 6,
		Vector2(0, PANEL_H - 14), Vector2(PANEL_W, 12),
		Color(0.39, 0.33, 0.22, 1.0))
	sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(sub_header)

	# -- Hover / description label --------------------------------------------
	_hover_label = _make_label("", 7,
		Vector2(10, PANEL_H - 28), Vector2(PANEL_W - 20, 14),
		Color(0.30, 0.22, 0.12, 1.0))
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_hover_label)

	# -- Build pins -----------------------------------------------------------
	_rebuild_pins()

func _rebuild_pins() -> void:
	# Clear existing pin nodes
	for n in _pin_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_pin_nodes.clear()

	for dest in destinations:
		_spawn_pin(dest)

func _spawn_pin(dest: Dictionary) -> void:
	if not _panel:
		return
	var pin_container := Control.new()
	pin_container.name = "Pin_" + dest["id"]
	pin_container.size = Vector2(40, 40)
	pin_container.position = dest["map_pos"] - Vector2(20, 36)  # offset so tip lands on pos
	_panel.add_child(pin_container)
	_pin_nodes.append(pin_container)

	# Pin sprite
	var pin_key: String = dest["pin_key"] if dest["unlocked"] else "map_pin_locked"
	var pin_tex_path := "res://assets/sprites/ui/%s.png" % pin_key
	if ResourceLoader.exists(pin_tex_path):
		var pin_spr := TextureRect.new()
		pin_spr.texture = load(pin_tex_path)
		pin_spr.size = Vector2(16, 20)
		pin_spr.position = Vector2(12, 16)
		pin_spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin_container.add_child(pin_spr)
	else:
		# Fallback colored circle
		var fb := ColorRect.new()
		fb.size = Vector2(10, 10)
		fb.position = Vector2(15, 20)
		fb.color = Color(0.78, 0.27, 0.22, 1.0) if dest["unlocked"] else Color(0.5, 0.5, 0.5, 1.0)
		fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin_container.add_child(fb)

	# Location label
	var lbl: Label = _make_label(dest["label"], 6,
		Vector2(-10, 2), Vector2(60, 12),
		Color(0.22, 0.16, 0.08, 1.0) if dest["unlocked"] else Color(0.55, 0.50, 0.44, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin_container.add_child(lbl)

	# Interaction area (invisible clickable rect)
	if dest["unlocked"]:
		var hit := Button.new()
		hit.flat = true
		hit.size = Vector2(40, 40)
		hit.position = Vector2(0, 0)
		# Custom style -- transparent
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0, 0, 0, 0)
		style_normal.draw_center = false
		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = Color(1.0, 0.85, 0.35, 0.20)
		style_hover.border_color = Color(0.78, 0.53, 0.08, 0.70)
		style_hover.set_border_width_all(1)
		hit.add_theme_stylebox_override("normal", style_normal)
		hit.add_theme_stylebox_override("hover", style_hover)
		hit.add_theme_stylebox_override("focus", style_normal)
		hit.add_theme_stylebox_override("pressed", style_hover)
		pin_container.add_child(hit)
		hit.pressed.connect(_on_pin_pressed.bind(dest))
		hit.mouse_entered.connect(_on_pin_hovered.bind(dest))
		hit.mouse_exited.connect(_on_pin_exit)
	else:
		# Locked label
		var locked_lbl := _make_label("?", 7,
			Vector2(12, 22), Vector2(16, 12),
			Color(0.50, 0.47, 0.42, 1.0))
		pin_container.add_child(locked_lbl)

# -- Interaction ----------------------------------------------------------------

func _on_pin_hovered(dest: Dictionary) -> void:
	if _hover_label:
		_hover_label.text = dest["desc"]

func _on_pin_exit() -> void:
	if _hover_label:
		_hover_label.text = ""

func _on_pin_pressed(dest: Dictionary) -> void:
	_selected_dest = dest
	_show_confirm(dest)

func _show_confirm(dest: Dictionary) -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()

	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.65)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_confirm_overlay = ov

	var box := ColorRect.new()
	box.size = Vector2(180, 80)
	box.position = Vector2(
		(PANEL_W / 2.0) - 90 + PANEL_X,
		(PANEL_H / 2.0) - 40 + PANEL_Y
	)
	box.color = Color(0.855, 0.780, 0.62, 0.97)
	ov.add_child(box)

	# Border
	var border_s := StyleBoxFlat.new()
	border_s.bg_color = Color(0, 0, 0, 0)
	border_s.draw_center = false
	border_s.border_color = Color(0.47, 0.35, 0.14, 1.0)
	border_s.set_border_width_all(2)
	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.add_theme_stylebox_override("panel", border_s)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(border)

	var title := _make_label("Travel to:", 7,
		Vector2(0, 6), Vector2(180, 12),
		Color(0.47, 0.35, 0.14, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var dest_lbl: Label = _make_label(dest["label"], 8,
		Vector2(0, 18), Vector2(180, 14),
		Color(0.22, 0.14, 0.05, 1.0))
	dest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dest_lbl)

	# Energy cost reminder
	var energy_lbl := _make_label("(costs 5 energy)", 6,
		Vector2(0, 34), Vector2(180, 10),
		Color(0.50, 0.40, 0.25, 1.0))
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(energy_lbl)

	# Confirm / Cancel buttons
	var btn_yes := Button.new()
	btn_yes.text = "Travel"
	btn_yes.size = Vector2(66, 16)
	btn_yes.position = Vector2(16, 52)
	btn_yes.add_theme_font_size_override("font_size", 7)
	btn_yes.focus_mode = Control.FOCUS_NONE
	box.add_child(btn_yes)
	btn_yes.pressed.connect(_on_confirm_travel)

	var btn_no := Button.new()
	btn_no.text = "Cancel"
	btn_no.size = Vector2(66, 16)
	btn_no.position = Vector2(98, 52)
	btn_no.add_theme_font_size_override("font_size", 7)
	btn_no.focus_mode = Control.FOCUS_NONE
	box.add_child(btn_no)
	btn_no.pressed.connect(_on_cancel_travel)

func _on_confirm_travel() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	if _selected_dest.is_empty():
		close()
		return
	GameData.deduct_energy(5.0)
	travel_to(_selected_dest["scene_path"])

func _on_cancel_travel() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null

# -- Public API -----------------------------------------------------------------

func open() -> void:
	_refresh_unlock_states()
	visible = true

func close() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	visible = false

func unlock_destination(dest_id: String) -> void:
	for d in destinations:
		if d["id"] == dest_id:
			d["unlocked"] = true
	_rebuild_pins()

func travel_to(scene_path: String) -> void:
	close()
	TimeManager.next_scene = scene_path
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

# -- Input ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			if _confirm_overlay and is_instance_valid(_confirm_overlay):
				_on_cancel_travel()
			else:
				close()

# -- Helpers --------------------------------------------------------------------

func _make_label(text: String, font_size: int,
		pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = sz
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
