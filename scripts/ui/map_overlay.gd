# map_overlay.gd -- Scene-level minimap showing current location detail.
# Opened by pressing M from any scene via SceneManager.
# Shows a STATIC scaled view of the current zone with:
#   - Fixed scene bounds (set per scene, never changes while map is open)
#   - Player position dot that tracks in real-time
#   - Labeled POI markers at their actual world positions
#   - Exit markers at the edges of the walkable area
# Navigation is done by WALKING, not clicking the map.
#
# Rendering approach: uses a single Control with _draw() for all dynamic
# content (POIs, exits, player dot).  This avoids child-node z-ordering
# issues that caused markers to be invisible in earlier versions.
extends CanvasLayer

# -- Map Panel Layout (viewport is 320x180) ------------------------------------
const MAP_W := 280
const MAP_H := 155
const MAP_X := 20
const MAP_Y := 12

# Map drawing area (inside panel, below header, above footer)
const AREA_X := 14.0
const AREA_Y := 24.0
const AREA_W := 252.0
const AREA_H := 100.0

# Exit world positions (ExitHelper places triggers here)
const EXIT_WORLD_POS := {
	"right":  Vector2(330, 45),
	"left":   Vector2(-330, 45),
	"top":    Vector2(0, -100),
	"bottom": Vector2(0, 100),
}

# -- Internal state ------------------------------------------------------------
var _bounds: Rect2 = Rect2(-300, -100, 600, 300)
var _pois: Array = []
var _exits: Array = []

# UI nodes (built once in _build_ui, never replaced)
var _panel: ColorRect = null
var _header_label: Label = null
var _draw_layer: Control = null   # custom-draw surface for POIs/exits/player
var _footer_label: Label = null

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if not visible:
		return
	# Player dot moves every frame -- trigger redraw
	if _draw_layer:
		_draw_layer.queue_redraw()

# -- UI Build (one-time shell) -------------------------------------------------

func _build_ui() -> void:
	# Full-screen dim background
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.6)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Gold border
	var border := ColorRect.new()
	border.size = Vector2(MAP_W + 4, MAP_H + 4)
	border.position = Vector2(MAP_X - 2, MAP_Y - 2)
	border.color = Color(0.72, 0.55, 0.22, 1.0)
	add_child(border)

	# Dark panel background
	_panel = ColorRect.new()
	_panel.name = "MapPanel"
	_panel.size = Vector2(MAP_W, MAP_H)
	_panel.position = Vector2(MAP_X, MAP_Y)
	_panel.color = Color(0.08, 0.07, 0.05, 0.96)
	_panel.clip_contents = false
	add_child(_panel)

	# Header label (zone name)
	_header_label = Label.new()
	_header_label.position = Vector2(0, 3)
	_header_label.size = Vector2(MAP_W, 16)
	_header_label.add_theme_font_size_override("font_size", 9)
	_header_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_header_label)

	# Map area background (dark fill inside the border)
	var map_bg := ColorRect.new()
	map_bg.size = Vector2(AREA_W, AREA_H)
	map_bg.position = Vector2(AREA_X, AREA_Y)
	map_bg.color = Color(0.14, 0.12, 0.08, 1.0)
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(map_bg)

	# Map area border (thin outline)
	var ab := ColorRect.new()
	ab.size = Vector2(AREA_W + 2, AREA_H + 2)
	ab.position = Vector2(AREA_X - 1, AREA_Y - 1)
	ab.color = Color(0.45, 0.35, 0.18, 0.7)
	ab.z_index = -1
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(ab)

	# Custom draw layer -- ALL dynamic content (POIs, exits, player) goes here.
	# This Control sits on top of the map background and draws everything
	# in its _draw() callback, avoiding child-node rendering issues.
	_draw_layer = Control.new()
	_draw_layer.name = "DrawLayer"
	_draw_layer.position = Vector2.ZERO
	_draw_layer.size = Vector2(MAP_W, MAP_H)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_layer.z_index = 10
	_draw_layer.draw.connect(_on_draw_layer_draw)
	_panel.add_child(_draw_layer)

	# Footer
	_footer_label = Label.new()
	_footer_label.text = "[ESC] or [M] to close"
	_footer_label.position = Vector2(0, MAP_H - 14)
	_footer_label.size = Vector2(MAP_W, 12)
	_footer_label.add_theme_font_size_override("font_size", 5)
	_footer_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.38, 0.85))
	_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer_label.z_index = 11
	_panel.add_child(_footer_label)

# -- Load scene data from SceneManager ----------------------------------------

func _load_scene_data() -> void:
	_pois.clear()
	_exits.clear()

	var sm = get_node_or_null("/root/SceneManager")
	if not sm:
		print("[MapOverlay] ERROR: SceneManager not found!")
		return

	# Header
	if _header_label:
		_header_label.text = sm.current_zone_name

	# Bounds
	if sm.has_method("get_scene_bounds"):
		_bounds = sm.get_scene_bounds()
	print("[MapOverlay] Zone: %s  Bounds: %s" % [sm.current_zone_name, str(_bounds)])

	# Copy POI and exit data
	if sm.has_method("get_scene_pois"):
		var raw_pois: Array = sm.get_scene_pois()
		for p in raw_pois:
			_pois.append(p.duplicate())
	if sm.has_method("get_scene_exits"):
		var raw_exits: Array = sm.get_scene_exits()
		for e in raw_exits:
			_exits.append(e.duplicate())

	print("[MapOverlay] Loaded %d POIs, %d exits" % [_pois.size(), _exits.size()])
	for p in _pois:
		var mp: Vector2 = _world_to_map(p["pos"])
		print("[MapOverlay]   POI '%s' world=%s map=%s" % [p.get("label","?"), str(p["pos"]), str(mp)])
	for e in _exits:
		print("[MapOverlay]   Exit edge='%s' label='%s'" % [e.get("edge","?"), e.get("label","?")])

# -- Custom Draw (all POIs, exits, player rendered here) -----------------------

func _on_draw_layer_draw() -> void:
	_draw_exits_on(_draw_layer)
	_draw_pois_on(_draw_layer)
	_draw_player_on(_draw_layer)

func _draw_pois_on(ctrl: Control) -> void:
	for poi in _pois:
		var map_pos: Vector2 = _world_to_map(poi["pos"])
		map_pos = _clamp_to_area(map_pos)
		var col: Color = poi.get("color", Color(0.85, 0.72, 0.35, 1.0))

		# Black outline
		ctrl.draw_rect(Rect2(map_pos - Vector2(6, 6), Vector2(12, 12)),
			Color(0, 0, 0, 0.6))
		# Colored square
		ctrl.draw_rect(Rect2(map_pos - Vector2(5, 5), Vector2(10, 10)), col)
		# Label above
		var label_text: String = poi.get("label", "?")
		var font: Font = ctrl.get_theme_default_font()
		var fsize: int = 6
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var text_pos: Vector2 = Vector2(map_pos.x - text_size.x * 0.5, map_pos.y - 8)
		ctrl.draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _draw_exits_on(ctrl: Control) -> void:
	for ex in _exits:
		var edge: String = ex.get("edge", "right")
		var dest: String = ex.get("label", "???")
		var world_pos: Vector2 = EXIT_WORLD_POS.get(edge, Vector2.ZERO)
		var map_pos: Vector2 = _world_to_map(world_pos)

		# Push to edge
		match edge:
			"right":
				map_pos.x = AREA_X + AREA_W - 6
			"left":
				map_pos.x = AREA_X + 6
			"top":
				map_pos.y = AREA_Y + 6
			"bottom":
				map_pos.y = AREA_Y + AREA_H - 6
		map_pos = _clamp_to_area(map_pos)

		# Orange stripe along exit edge
		var stripe_color := Color(1.0, 0.6, 0.15, 0.35)
		match edge:
			"right":
				ctrl.draw_rect(Rect2(AREA_X + AREA_W - 5, AREA_Y, 5, AREA_H), stripe_color)
			"left":
				ctrl.draw_rect(Rect2(AREA_X, AREA_Y, 5, AREA_H), stripe_color)
			"top":
				ctrl.draw_rect(Rect2(AREA_X, AREA_Y, AREA_W, 4), stripe_color)
			"bottom":
				ctrl.draw_rect(Rect2(AREA_X, AREA_Y + AREA_H - 4, AREA_W, 4), stripe_color)

		# Arrow glyph
		var arrow_text := ""
		match edge:
			"right":  arrow_text = ">>"
			"left":   arrow_text = "<<"
			"top":    arrow_text = "^^"
			"bottom": arrow_text = "vv"

		var font: Font = ctrl.get_theme_default_font()
		var arrow_size: Vector2 = font.get_string_size(arrow_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
		ctrl.draw_string(font,
			Vector2(map_pos.x - arrow_size.x * 0.5, map_pos.y + 4),
			arrow_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(1.0, 0.65, 0.15, 1.0))

		# Destination label
		var dest_text := "to " + dest
		var dest_size: Vector2 = font.get_string_size(dest_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
		var dest_pos := Vector2.ZERO
		match edge:
			"right":
				dest_pos = Vector2(map_pos.x - dest_size.x - 4, map_pos.y + 3)
			"left":
				dest_pos = Vector2(map_pos.x + 10, map_pos.y + 3)
			"top":
				dest_pos = Vector2(map_pos.x - dest_size.x * 0.5, map_pos.y + 14)
			"bottom":
				dest_pos = Vector2(map_pos.x - dest_size.x * 0.5, map_pos.y - 10)
		ctrl.draw_string(font, dest_pos, dest_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
			Color(1.0, 0.70, 0.25, 0.95))

func _draw_player_on(ctrl: Control) -> void:
	var player: Node2D = _find_player()
	if not player:
		return
	var map_pos: Vector2 = _world_to_map(player.global_position)
	map_pos = _clamp_to_area(map_pos)

	# Green dot with black outline
	ctrl.draw_rect(Rect2(map_pos - Vector2(5, 5), Vector2(10, 10)),
		Color(0, 0, 0, 0.7))
	ctrl.draw_rect(Rect2(map_pos - Vector2(4, 4), Vector2(8, 8)),
		Color(0.15, 1.0, 0.35, 1.0))

	# "YOU" label
	var font: Font = ctrl.get_theme_default_font()
	var text_size: Vector2 = font.get_string_size("YOU", HORIZONTAL_ALIGNMENT_CENTER, -1, 7)
	ctrl.draw_string(font,
		Vector2(map_pos.x - text_size.x * 0.5, map_pos.y - 7),
		"YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		Color(0.15, 1.0, 0.35, 0.95))

# -- Coordinate Mapping --------------------------------------------------------

func _world_to_map(world_pos: Vector2) -> Vector2:
	var bw: float = _bounds.size.x
	var bh: float = _bounds.size.y
	if bw < 1.0:
		bw = 1.0
	if bh < 1.0:
		bh = 1.0
	var nx: float = (world_pos.x - _bounds.position.x) / bw
	var ny: float = (world_pos.y - _bounds.position.y) / bh
	nx = clampf(nx, 0.0, 1.0)
	ny = clampf(ny, 0.0, 1.0)
	return Vector2(AREA_X + nx * AREA_W, AREA_Y + ny * AREA_H)

func _clamp_to_area(pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, AREA_X + 4, AREA_X + AREA_W - 4)
	pos.y = clampf(pos.y, AREA_Y + 4, AREA_Y + AREA_H - 4)
	return pos

func _find_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var p: Node = tree.get_first_node_in_group("player")
	if p and p is Node2D:
		return p as Node2D
	return null

# -- Public API ----------------------------------------------------------------

func open() -> void:
	_load_scene_data()
	visible = true
	if _draw_layer:
		_draw_layer.queue_redraw()

func close() -> void:
	visible = false
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm._map_open = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
