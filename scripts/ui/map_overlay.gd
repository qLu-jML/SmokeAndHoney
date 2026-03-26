# map_overlay.gd -- Scene-level minimap showing current location detail.
# Opened by pressing M from any scene via SceneManager.
# Shows: player position, points of interest, and exits to other scenes.
# Navigation is done by WALKING, not clicking the map.
extends CanvasLayer

# -- Map Panel Layout -----------------------------------------------------------
# Viewport is 320x180, so the panel fills most of the screen
const MAP_W := 280
const MAP_H := 155
const MAP_X := 20
const MAP_Y := 12

# Map drawing area (inside panel, below header, above footer)
const AREA_X := 12.0
const AREA_Y := 22.0
const AREA_W := 256.0   # MAP_W - 24
const AREA_H := 108.0   # MAP_H - 47

# -- Scene bounds (read from SceneManager, set per scene) ----------------------
var _bounds: Rect2 = Rect2(-350, -120, 700, 240)

# -- Node References ------------------------------------------------------------
var _panel: ColorRect = null
var _header_label: Label = null
var _player_dot: ColorRect = null
var _player_lbl: Label = null
var _content_nodes: Array = []
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
	bg_dim.color = Color(0, 0, 0, 0.6)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Border (drawn first, behind panel)
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

	# Header with zone name
	var zone_name: String = "Unknown"
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm:
		zone_name = sm.current_zone_name
	_header_label = _make_label(zone_name, 9,
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

	# Map area border
	var area_border := ColorRect.new()
	area_border.size = Vector2(AREA_W + 2, AREA_H + 2)
	area_border.position = Vector2(AREA_X - 1, AREA_Y - 1)
	area_border.color = Color(0.45, 0.35, 0.18, 0.7)
	area_border.z_index = -1
	area_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(area_border)

	# Player dot (bright green, larger)
	_player_dot = ColorRect.new()
	_player_dot.size = Vector2(8, 8)
	_player_dot.color = Color(0.15, 1.0, 0.35, 1.0)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_dot.z_index = 10
	_panel.add_child(_player_dot)

	# Player label
	_player_lbl = _make_label("YOU", 5,
		Vector2(0, 0), Vector2(24, 8),
		Color(0.15, 1.0, 0.35, 0.9))
	_player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_lbl.z_index = 10
	_panel.add_child(_player_lbl)

	# Footer hint
	_footer = _make_label("[ESC] or [M] to close", 6,
		Vector2(0, MAP_H - 14), Vector2(MAP_W, 12),
		Color(0.55, 0.50, 0.38, 0.85))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_footer)

	_rebuild_scene_content()

func _rebuild_scene_content() -> void:
	# Clear old markers
	for n in _content_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_content_nodes.clear()

	var sm: Node = get_node_or_null("/root/SceneManager")
	if not sm:
		return

	# Load scene bounds
	if sm.has_method("get_scene_bounds"):
		_bounds = sm.get_scene_bounds()

	# Update header
	if _header_label:
		_header_label.text = sm.current_zone_name

	# Draw registered POIs
	if sm.has_method("get_scene_pois"):
		var pois: Array = sm.get_scene_pois()
		for poi in pois:
			_draw_poi(poi)

	# If no registered POIs, auto-scan the scene tree
	if sm.has_method("get_scene_pois"):
		var pois: Array = sm.get_scene_pois()
		if pois.size() == 0:
			_auto_scan_scene()

	# Draw exits (always -- these are critical)
	if sm.has_method("get_scene_exits"):
		var exits: Array = sm.get_scene_exits()
		for ex in exits:
			_draw_exit(ex)

	# If no exits registered, show a hint
	if sm.has_method("get_scene_exits"):
		var exits: Array = sm.get_scene_exits()
		if exits.size() == 0:
			var hint := _make_label("Walk to screen edges to travel", 5,
				Vector2(AREA_X, AREA_Y + AREA_H - 10), Vector2(AREA_W, 10),
				Color(0.7, 0.6, 0.4, 0.6))
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_panel.add_child(hint)
			_content_nodes.append(hint)

# -- Auto-scan scene tree for notable children ---------------------------------

func _auto_scan_scene() -> void:
	var root: Node = get_tree().current_scene
	if not root:
		return
	var world: Node = root.get_node_or_null("World")
	var scan_root: Node = world if world else root
	_scan_children(scan_root, 0)

func _scan_children(node: Node, depth: int) -> void:
	if depth > 3:
		return
	for child in node.get_children():
		if not (child is Node2D):
			continue
		var n2d: Node2D = child as Node2D
		# Skip the player, walls, tilemaps, cameras, UI elements
		var cname: String = child.name.to_lower()
		if cname.find("player") >= 0 or cname.find("wall") >= 0:
			continue
		if cname.find("tilemap") >= 0 or cname.find("camera") >= 0:
			continue
		if cname.find("collision") >= 0 or cname.find("static") >= 0:
			continue
		if cname.find("overlay") >= 0 or cname.find("grid") >= 0:
			continue
		if cname.find("exit") >= 0 or cname.find("spawn") >= 0:
			continue
		if cname.find("lifecycle") >= 0 or cname.find("spawner") >= 0:
			continue
		# Must be visible and have a reasonable position
		if not n2d.visible:
			continue
		# Use the display name (capitalize, remove underscores)
		var display: String = child.name.replace("_", " ")
		# Pick color based on type
		var col := Color(0.75, 0.65, 0.40, 1.0)
		if cname.find("npc") >= 0 or cname.find("bob") >= 0 or cname.find("walt") >= 0:
			col = Color(0.45, 0.85, 0.50, 1.0)
		elif cname.find("merchant") >= 0 or cname.find("shop") >= 0:
			col = Color(0.70, 0.50, 0.90, 1.0)
		elif cname.find("chest") >= 0 or cname.find("storage") >= 0:
			col = Color(0.85, 0.70, 0.30, 1.0)
		elif cname.find("hive") >= 0:
			col = Color(0.95, 0.80, 0.25, 1.0)

		_draw_poi({"pos": n2d.global_position, "label": display, "color": col})

		# Don't recurse into children of things we already drew
		if depth < 2:
			_scan_children(child, depth + 1)

# -- Draw POI ------------------------------------------------------------------

func _draw_poi(poi: Dictionary) -> void:
	var map_pos: Vector2 = _world_to_map(poi["pos"])
	var col: Color = poi.get("color", Color(0.85, 0.72, 0.35, 1.0))

	# Clamp to map area
	map_pos.x = clampf(map_pos.x, AREA_X + 4, AREA_X + AREA_W - 4)
	map_pos.y = clampf(map_pos.y, AREA_Y + 4, AREA_Y + AREA_H - 4)

	# Diamond marker (rotated square via two overlapping rects)
	var dot := ColorRect.new()
	dot.size = Vector2(8, 8)
	dot.position = map_pos - Vector2(4, 4)
	dot.color = col
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(dot)
	_content_nodes.append(dot)

	# Darker outline
	var outline := ColorRect.new()
	outline.size = Vector2(10, 10)
	outline.position = map_pos - Vector2(5, 5)
	outline.color = Color(0, 0, 0, 0.5)
	outline.z_index = -1
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outline)
	_content_nodes.append(outline)

	# Label (bigger, readable)
	var lbl := _make_label(poi["label"], 6,
		map_pos + Vector2(-30, 6), Vector2(60, 10), col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(lbl)
	_content_nodes.append(lbl)

# -- Draw Exit -----------------------------------------------------------------

func _draw_exit(ex: Dictionary) -> void:
	var edge: String = ex.get("edge", "right")
	var dest: String = ex.get("label", "???")

	# Position arrow indicators at the edges of the map area
	# Make them BIG and obvious
	var arrow_pos := Vector2.ZERO
	var arrow_text := ""
	var label_pos := Vector2.ZERO
	var label_w := 80.0

	# Exit stripe (colored bar at the edge)
	var stripe := ColorRect.new()
	stripe.color = Color(0.95, 0.55, 0.15, 0.35)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE

	match edge:
		"right":
			arrow_pos = Vector2(AREA_X + AREA_W - 2, AREA_Y + AREA_H * 0.5 - 6)
			arrow_text = ">>"
			label_pos = Vector2(AREA_X + AREA_W - 6, AREA_Y + AREA_H * 0.5 + 6)
			stripe.size = Vector2(4, AREA_H)
			stripe.position = Vector2(AREA_X + AREA_W - 4, AREA_Y)
		"left":
			arrow_pos = Vector2(AREA_X - 8, AREA_Y + AREA_H * 0.5 - 6)
			arrow_text = "<<"
			label_pos = Vector2(AREA_X - 10, AREA_Y + AREA_H * 0.5 + 6)
			stripe.size = Vector2(4, AREA_H)
			stripe.position = Vector2(AREA_X, AREA_Y)
		"top":
			arrow_pos = Vector2(AREA_X + AREA_W * 0.5 - 6, AREA_Y - 2)
			arrow_text = "^^"
			label_pos = Vector2(AREA_X + AREA_W * 0.5 - 40, AREA_Y - 1)
			stripe.size = Vector2(AREA_W, 3)
			stripe.position = Vector2(AREA_X, AREA_Y)
		"bottom":
			arrow_pos = Vector2(AREA_X + AREA_W * 0.5 - 6, AREA_Y + AREA_H - 8)
			arrow_text = "vv"
			label_pos = Vector2(AREA_X + AREA_W * 0.5 - 40, AREA_Y + AREA_H + 1)
			stripe.size = Vector2(AREA_W, 3)
			stripe.position = Vector2(AREA_X, AREA_Y + AREA_H - 3)

	_panel.add_child(stripe)
	_content_nodes.append(stripe)

	# Arrow text (big, bright orange)
	var arrow := _make_label(arrow_text, 8,
		arrow_pos, Vector2(16, 14),
		Color(1.0, 0.6, 0.15, 1.0))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.z_index = 5
	_panel.add_child(arrow)
	_content_nodes.append(arrow)

	# Destination name
	var dest_lbl := _make_label("to " + dest, 6,
		label_pos, Vector2(label_w, 10),
		Color(1.0, 0.65, 0.2, 0.95))
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
	# Clamp to map area
	map_pos.x = clampf(map_pos.x, AREA_X + 4, AREA_X + AREA_W - 4)
	map_pos.y = clampf(map_pos.y, AREA_Y + 4, AREA_Y + AREA_H - 4)
	_player_dot.position = map_pos - Vector2(4, 4)
	if _player_lbl:
		_player_lbl.position = map_pos + Vector2(-12, -12)

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
