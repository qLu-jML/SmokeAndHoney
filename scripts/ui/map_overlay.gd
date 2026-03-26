# map_overlay.gd -- Scene-level minimap showing current location detail.
# Opened by pressing M from any scene via SceneManager.
# Shows: player position, points of interest, and exits to other scenes.
# Navigation is done by WALKING, not clicking the map.
extends CanvasLayer

# -- Map Panel Layout -----------------------------------------------------------
# Viewport is 320x180
const MAP_W := 280
const MAP_H := 155
const MAP_X := 20
const MAP_Y := 12

# Map drawing area (inside panel, below header, above footer)
const AREA_X := 14.0
const AREA_Y := 24.0
const AREA_W := 252.0
const AREA_H := 100.0

# -- Internal state -------------------------------------------------------------
var _bounds: Rect2 = Rect2(-300, -100, 600, 300)
var _panel: ColorRect = null
var _header_label: Label = null
var _player_dot: ColorRect = null
var _player_lbl: Label = null
var _content_nodes: Array = []

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_player_dot()

# -- UI Build ------------------------------------------------------------------

func _build_ui() -> void:
	# Full-screen dim
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.6)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Border
	var border := ColorRect.new()
	border.size = Vector2(MAP_W + 4, MAP_H + 4)
	border.position = Vector2(MAP_X - 2, MAP_Y - 2)
	border.color = Color(0.72, 0.55, 0.22, 1.0)
	add_child(border)

	# Main panel
	_panel = ColorRect.new()
	_panel.name = "MapPanel"
	_panel.size = Vector2(MAP_W, MAP_H)
	_panel.position = Vector2(MAP_X, MAP_Y)
	_panel.color = Color(0.08, 0.07, 0.05, 0.96)
	add_child(_panel)

	# Header
	_header_label = _make_label("", 9,
		Vector2(0, 3), Vector2(MAP_W, 16),
		Color(0.95, 0.82, 0.45, 1.0))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_header_label)

	# Map area background
	var map_bg := ColorRect.new()
	map_bg.size = Vector2(AREA_W, AREA_H)
	map_bg.position = Vector2(AREA_X, AREA_Y)
	map_bg.color = Color(0.14, 0.12, 0.08, 1.0)
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(map_bg)

	# Area border
	var area_border := ColorRect.new()
	area_border.size = Vector2(AREA_W + 2, AREA_H + 2)
	area_border.position = Vector2(AREA_X - 1, AREA_Y - 1)
	area_border.color = Color(0.45, 0.35, 0.18, 0.7)
	area_border.z_index = -1
	area_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(area_border)

	# Player dot (bright green)
	_player_dot = ColorRect.new()
	_player_dot.size = Vector2(8, 8)
	_player_dot.color = Color(0.15, 1.0, 0.35, 1.0)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_dot.z_index = 10
	_panel.add_child(_player_dot)

	# Player "YOU" label
	_player_lbl = _make_label("YOU", 6,
		Vector2(0, 0), Vector2(28, 10),
		Color(0.15, 1.0, 0.35, 0.95))
	_player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_lbl.z_index = 10
	_panel.add_child(_player_lbl)

	# Footer
	var footer := _make_label("[ESC] or [M] to close  |  Walk to edges to travel", 5,
		Vector2(0, MAP_H - 14), Vector2(MAP_W, 12),
		Color(0.55, 0.50, 0.38, 0.85))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(footer)

	_rebuild_scene_content()

# -- Rebuild all map content from SceneManager data ----------------------------

func _rebuild_scene_content() -> void:
	for n in _content_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_content_nodes.clear()

	var sm: Node = get_node_or_null("/root/SceneManager")
	if not sm:
		return

	# Update header
	if _header_label:
		_header_label.text = sm.current_zone_name

	# Gather all data
	var pois: Array = sm.get_scene_pois() if sm.has_method("get_scene_pois") else []
	var exits: Array = sm.get_scene_exits() if sm.has_method("get_scene_exits") else []

	# Auto-calculate bounds from player + POIs (ignore hardcoded bounds)
	_calculate_bounds(pois)

	# Draw exits FIRST (they go at the edges of the map area)
	for ex in exits:
		_draw_exit(ex)

	# Draw POIs
	for poi in pois:
		_draw_poi(poi)

# -- Auto-calculate bounds from actual content ---------------------------------

func _calculate_bounds(pois: Array) -> void:
	# Collect all known positions: player + registered POIs
	var points: Array = []

	var player: Node2D = _find_player()
	if player:
		points.append(player.global_position)

	for poi in pois:
		if poi.has("pos"):
			points.append(poi["pos"])

	if points.size() == 0:
		# Fallback to default
		_bounds = Rect2(-300, -100, 600, 300)
		return

	# Find bounding box of all points
	var min_x: float = points[0].x
	var max_x: float = points[0].x
	var min_y: float = points[0].y
	var max_y: float = points[0].y

	for pt in points:
		if pt.x < min_x:
			min_x = pt.x
		if pt.x > max_x:
			max_x = pt.x
		if pt.y < min_y:
			min_y = pt.y
		if pt.y > max_y:
			max_y = pt.y

	# Add generous padding (at least 100px on each side, or 30% of range)
	var range_x: float = max_x - min_x
	var range_y: float = max_y - min_y
	# Ensure minimum range so single-point scenes still have a usable map
	if range_x < 200.0:
		range_x = 200.0
	if range_y < 150.0:
		range_y = 150.0

	var pad_x: float = maxf(100.0, range_x * 0.3)
	var pad_y: float = maxf(80.0, range_y * 0.3)

	_bounds = Rect2(
		min_x - pad_x,
		min_y - pad_y,
		range_x + pad_x * 2.0,
		range_y + pad_y * 2.0
	)

# -- Draw POI ------------------------------------------------------------------

func _draw_poi(poi: Dictionary) -> void:
	var map_pos: Vector2 = _world_to_map(poi["pos"])
	var col: Color = poi.get("color", Color(0.85, 0.72, 0.35, 1.0))

	# Clamp to map area with margin
	map_pos.x = clampf(map_pos.x, AREA_X + 6, AREA_X + AREA_W - 6)
	map_pos.y = clampf(map_pos.y, AREA_Y + 6, AREA_Y + AREA_H - 6)

	# Dark outline
	var outline := ColorRect.new()
	outline.size = Vector2(12, 12)
	outline.position = map_pos - Vector2(6, 6)
	outline.color = Color(0, 0, 0, 0.6)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outline)
	_content_nodes.append(outline)

	# Colored marker
	var dot := ColorRect.new()
	dot.size = Vector2(10, 10)
	dot.position = map_pos - Vector2(5, 5)
	dot.color = col
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 2
	_panel.add_child(dot)
	_content_nodes.append(dot)

	# Label ABOVE the marker
	var label_text: String = poi.get("label", "?")
	var lbl := _make_label(label_text, 6,
		map_pos + Vector2(-35, -14), Vector2(70, 10), col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 3
	_panel.add_child(lbl)
	_content_nodes.append(lbl)

# -- Draw Exit -----------------------------------------------------------------

func _draw_exit(ex: Dictionary) -> void:
	var edge: String = ex.get("edge", "right")
	var dest: String = ex.get("label", "???")

	# Position: exit indicators go at the edge of the map area
	# They consist of: a colored stripe, an arrow, and a destination label
	var stripe := ColorRect.new()
	stripe.color = Color(1.0, 0.6, 0.15, 0.45)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var arrow_pos := Vector2.ZERO
	var arrow_text := ""
	var label_pos := Vector2.ZERO

	match edge:
		"right":
			stripe.size = Vector2(6, AREA_H)
			stripe.position = Vector2(AREA_X + AREA_W - 6, AREA_Y)
			arrow_pos = Vector2(AREA_X + AREA_W - 14, AREA_Y + AREA_H * 0.5 - 6)
			arrow_text = ">>"
			label_pos = Vector2(AREA_X + AREA_W - 55, AREA_Y + AREA_H * 0.5 + 6)
		"left":
			stripe.size = Vector2(6, AREA_H)
			stripe.position = Vector2(AREA_X, AREA_Y)
			arrow_pos = Vector2(AREA_X + 2, AREA_Y + AREA_H * 0.5 - 6)
			arrow_text = "<<"
			label_pos = Vector2(AREA_X - 5, AREA_Y + AREA_H * 0.5 + 6)
		"top":
			stripe.size = Vector2(AREA_W, 5)
			stripe.position = Vector2(AREA_X, AREA_Y)
			arrow_pos = Vector2(AREA_X + AREA_W * 0.5 - 6, AREA_Y + 2)
			arrow_text = "^^"
			label_pos = Vector2(AREA_X + AREA_W * 0.5 - 30, AREA_Y + 12)
		"bottom":
			stripe.size = Vector2(AREA_W, 5)
			stripe.position = Vector2(AREA_X, AREA_Y + AREA_H - 5)
			arrow_pos = Vector2(AREA_X + AREA_W * 0.5 - 6, AREA_Y + AREA_H - 14)
			arrow_text = "vv"
			label_pos = Vector2(AREA_X + AREA_W * 0.5 - 30, AREA_Y + AREA_H - 24)

	stripe.z_index = 1
	_panel.add_child(stripe)
	_content_nodes.append(stripe)

	# Arrow (big, bright)
	var arrow := _make_label(arrow_text, 9,
		arrow_pos, Vector2(16, 14),
		Color(1.0, 0.65, 0.15, 1.0))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.z_index = 5
	_panel.add_child(arrow)
	_content_nodes.append(arrow)

	# Destination name
	var dest_lbl := _make_label("to " + dest, 6,
		label_pos, Vector2(70, 10),
		Color(1.0, 0.70, 0.25, 0.95))
	dest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dest_lbl.z_index = 5
	_panel.add_child(dest_lbl)
	_content_nodes.append(dest_lbl)

# -- Player Tracking -----------------------------------------------------------

func _update_player_dot() -> void:
	if not _player_dot or not _panel:
		return
	var player: Node2D = _find_player()
	if not player:
		return
	var map_pos: Vector2 = _world_to_map(player.global_position)
	map_pos.x = clampf(map_pos.x, AREA_X + 5, AREA_X + AREA_W - 5)
	map_pos.y = clampf(map_pos.y, AREA_Y + 5, AREA_Y + AREA_H - 5)
	_player_dot.position = map_pos - Vector2(4, 4)
	if _player_lbl:
		_player_lbl.position = map_pos + Vector2(-14, -14)

func _find_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var p: Node = tree.get_first_node_in_group("player")
	if p and p is Node2D:
		return p as Node2D
	return null

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

	return Vector2(
		AREA_X + nx * AREA_W,
		AREA_Y + ny * AREA_H
	)

# -- Public API -----------------------------------------------------------------

func open() -> void:
	_rebuild_scene_content()
	visible = true

func close() -> void:
	visible = false
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm:
		sm._map_open = false

# -- Input ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
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
