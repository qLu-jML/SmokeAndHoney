# map_overlay.gd -- Scene-level minimap showing current location detail.
# Opened by pressing M from any scene via SceneManager.
# Shows: player position, points of interest, and exits to other scenes.
# Navigation is done by WALKING, not clicking the map.
extends CanvasLayer

# -- Map Panel Layout -----------------------------------------------------------
const MAP_W := 240
const MAP_H := 140
const MAP_X := 40   # left margin in viewport coords
const MAP_Y := 20   # top margin

# -- Scene bounds (read from SceneManager, set per scene) ----------------------
var _bounds: Rect2 = Rect2(-350, -120, 700, 240)

# -- Node References ------------------------------------------------------------
var _panel: ColorRect = null
var _header_label: Label = null
var _player_dot: ColorRect = null
var _poi_nodes: Array = []
var _exit_nodes: Array = []
var _footer: Label = null

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
	# Semi-transparent full-screen dim
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.55)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Main panel (dark map background)
	_panel = ColorRect.new()
	_panel.name = "MapPanel"
	_panel.size = Vector2(MAP_W, MAP_H)
	_panel.position = Vector2(MAP_X, MAP_Y)
	_panel.color = Color(0.12, 0.10, 0.07, 0.94)
	add_child(_panel)

	# Border
	var border := ColorRect.new()
	border.size = Vector2(MAP_W + 4, MAP_H + 4)
	border.position = Vector2(MAP_X - 2, MAP_Y - 2)
	border.color = Color(0.65, 0.48, 0.18, 0.9)
	border.z_index = -1
	add_child(border)

	# Header with zone name
	var zone_name: String = "Unknown"
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm:
		zone_name = sm.current_zone_name
	_header_label = _make_label(zone_name, 8,
		Vector2(0, 4), Vector2(MAP_W, 14),
		Color(0.92, 0.78, 0.42, 1.0))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_header_label)

	# Map area background (slightly lighter)
	var map_bg := ColorRect.new()
	map_bg.size = Vector2(MAP_W - 16, MAP_H - 36)
	map_bg.position = Vector2(8, 20)
	map_bg.color = Color(0.18, 0.15, 0.10, 1.0)
	map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(map_bg)

	# Player dot (bright green, updates each frame)
	_player_dot = ColorRect.new()
	_player_dot.size = Vector2(6, 6)
	_player_dot.color = Color(0.2, 0.9, 0.3, 1.0)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_dot.z_index = 10
	_panel.add_child(_player_dot)

	# Footer hint
	_footer = _make_label("ESC / M to close", 5,
		Vector2(0, MAP_H - 13), Vector2(MAP_W, 10),
		Color(0.55, 0.50, 0.38, 0.8))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_footer)

	_rebuild_scene_content()

func _rebuild_scene_content() -> void:
	# Clear old POI and exit markers
	for n in _poi_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_poi_nodes.clear()
	for n in _exit_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_exit_nodes.clear()

	var sm: Node = get_node_or_null("/root/SceneManager")
	if not sm:
		return

	# Load scene bounds
	if sm.has_method("get_scene_bounds"):
		_bounds = sm.get_scene_bounds()

	# Update header
	if _header_label:
		_header_label.text = sm.current_zone_name

	# Draw POIs
	if sm.has_method("get_scene_pois"):
		var pois: Array = sm.get_scene_pois()
		for poi in pois:
			_draw_poi(poi)

	# Draw exits
	if sm.has_method("get_scene_exits"):
		var exits: Array = sm.get_scene_exits()
		for ex in exits:
			_draw_exit(ex)

func _draw_poi(poi: Dictionary) -> void:
	# poi = { "pos": Vector2, "label": String, "color": Color (optional) }
	var map_pos: Vector2 = _world_to_map(poi["pos"])
	var col: Color = poi.get("color", Color(0.85, 0.72, 0.35, 1.0))

	# Icon dot
	var dot := ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.position = map_pos - Vector2(2.5, 2.5)
	dot.color = col
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(dot)
	_poi_nodes.append(dot)

	# Label
	var lbl := _make_label(poi["label"], 4,
		map_pos + Vector2(-20, 4), Vector2(40, 8), col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(lbl)
	_poi_nodes.append(lbl)

func _draw_exit(ex: Dictionary) -> void:
	# ex = { "edge": String, "label": String, "target": String }
	var edge: String = ex.get("edge", "right")
	var map_area_x := 8.0
	var map_area_y := 20.0
	var map_area_w: float = MAP_W - 16.0
	var map_area_h: float = MAP_H - 36.0

	var arrow_pos := Vector2.ZERO
	var arrow_text := ""
	var label_offset := Vector2.ZERO

	match edge:
		"right":
			arrow_pos = Vector2(map_area_x + map_area_w + 1, map_area_y + map_area_h * 0.5 - 5)
			arrow_text = ">>"
			label_offset = Vector2(-4, 10)
		"left":
			arrow_pos = Vector2(map_area_x - 14, map_area_y + map_area_h * 0.5 - 5)
			arrow_text = "<<"
			label_offset = Vector2(-4, 10)
		"top":
			arrow_pos = Vector2(map_area_x + map_area_w * 0.5 - 6, map_area_y - 12)
			arrow_text = "^^"
			label_offset = Vector2(-20, -2)
		"bottom":
			arrow_pos = Vector2(map_area_x + map_area_w * 0.5 - 6, map_area_y + map_area_h + 1)
			arrow_text = "vv"
			label_offset = Vector2(-20, 10)

	# Arrow indicator
	var arrow := _make_label(arrow_text, 7,
		arrow_pos, Vector2(14, 12),
		Color(0.95, 0.55, 0.15, 1.0))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(arrow)
	_exit_nodes.append(arrow)

	# Destination label
	var dest_label: String = ex.get("label", "")
	if dest_label != "":
		var lbl := _make_label(dest_label, 4,
			arrow_pos + label_offset, Vector2(50, 8),
			Color(0.95, 0.55, 0.15, 0.85))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(lbl)
		_exit_nodes.append(lbl)

# -- Player Tracking -----------------------------------------------------------

func _update_player_dot() -> void:
	if not _player_dot or not _panel:
		return
	var player: Node2D = _find_player()
	if not player:
		return
	var map_pos: Vector2 = _world_to_map(player.global_position)
	_player_dot.position = map_pos - Vector2(3, 3)

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
	# Maps world coordinates to minimap panel coordinates using dynamic bounds
	var map_area_x := 8.0
	var map_area_y := 20.0
	var map_area_w: float = MAP_W - 16.0
	var map_area_h: float = MAP_H - 36.0

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
		map_area_x + nx * map_area_w,
		map_area_y + ny * map_area_h
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
