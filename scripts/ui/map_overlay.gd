# map_overlay.gd -- Scene-level minimap showing current location detail.
# Opened by pressing M from any scene via SceneManager.
# Shows a STATIC scaled view of the current zone with:
#   - Fixed scene bounds (set per scene, never changes while map is open)
#   - Player position dot that tracks in real-time
#   - Labeled POI markers at their actual world positions
#   - Exit markers at the edges of the walkable area
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

# -- Internal state (set once when map opens, stays fixed) ----------------------
var _bounds: Rect2 = Rect2(-300, -100, 600, 300)

var _panel: ColorRect = null
var _header_label: Label = null
var _player_dot: ColorRect = null
var _player_lbl: Label = null
var _content_nodes: Array = []

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_player_dot()

# -- UI Build (one-time shell) -------------------------------------------------

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

	# Panel
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
	var ab := ColorRect.new()
	ab.size = Vector2(AREA_W + 2, AREA_H + 2)
	ab.position = Vector2(AREA_X - 1, AREA_Y - 1)
	ab.color = Color(0.45, 0.35, 0.18, 0.7)
	ab.z_index = -1
	ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(ab)

	# Player dot
	_player_dot = ColorRect.new()
	_player_dot.size = Vector2(8, 8)
	_player_dot.color = Color(0.15, 1.0, 0.35, 1.0)
	_player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_dot.z_index = 10
	_panel.add_child(_player_dot)

	# "YOU" label
	_player_lbl = _make_label("YOU", 6,
		Vector2(0, 0), Vector2(28, 10),
		Color(0.15, 1.0, 0.35, 0.95))
	_player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_lbl.z_index = 10
	_panel.add_child(_player_lbl)

	# Footer
	var footer := _make_label("[ESC] or [M] to close", 5,
		Vector2(0, MAP_H - 14), Vector2(MAP_W, 12),
		Color(0.55, 0.50, 0.38, 0.85))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(footer)

# -- Populate map content from SceneManager data -------------------------------

func _rebuild_scene_content() -> void:
	# Clear previous content
	for n in _content_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_content_nodes.clear()

	var sm: Node = get_node_or_null("/root/SceneManager")
	if not sm:
		return

	# Header
	if _header_label:
		_header_label.text = sm.current_zone_name

	# Use the FIXED scene bounds registered by the scene script.
	# These never change while the scene is loaded, giving a stable map.
	if sm.has_method("get_scene_bounds"):
		_bounds = sm.get_scene_bounds()

	var pois: Array = sm.get_scene_pois() if sm.has_method("get_scene_pois") else []
	var exits: Array = sm.get_scene_exits() if sm.has_method("get_scene_exits") else []

	# Draw exits first (behind POIs)
	for ex in exits:
		_draw_exit(ex)

	# Draw POIs
	for poi in pois:
		_draw_poi(poi)

# -- Draw POI ------------------------------------------------------------------

func _draw_poi(poi: Dictionary) -> void:
	var map_pos: Vector2 = _world_to_map(poi["pos"])
	var col: Color = poi.get("color", Color(0.85, 0.72, 0.35, 1.0))

	# Clamp inside map area
	map_pos = _clamp_to_area(map_pos)

	# Outline
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

	# Label above
	var lbl := _make_label(poi.get("label", "?"), 6,
		map_pos + Vector2(-35, -14), Vector2(70, 10), col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 3
	_panel.add_child(lbl)
	_content_nodes.append(lbl)

# -- Draw Exit -----------------------------------------------------------------
# Exits are drawn as orange arrow markers at the world-space edge where the
# exit trigger lives (ExitHelper places them at x=+/-330, y=+/-100).
# This way the arrow sits at the correct position on the static map.

const EXIT_WORLD_POS := {
	"right":  Vector2(330, 45),
	"left":   Vector2(-330, 45),
	"top":    Vector2(0, -100),
	"bottom": Vector2(0, 100),
}

func _draw_exit(ex: Dictionary) -> void:
	var edge: String = ex.get("edge", "right")
	var dest: String = ex.get("label", "???")
	var world_pos: Vector2 = EXIT_WORLD_POS.get(edge, Vector2.ZERO)

	var map_pos: Vector2 = _world_to_map(world_pos)
	# Push exit markers to the edge of the map area so they read as "exits"
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

	# Orange stripe along the exit edge
	var stripe := ColorRect.new()
	stripe.color = Color(1.0, 0.6, 0.15, 0.35)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match edge:
		"right":
			stripe.size = Vector2(5, AREA_H)
			stripe.position = Vector2(AREA_X + AREA_W - 5, AREA_Y)
		"left":
			stripe.size = Vector2(5, AREA_H)
			stripe.position = Vector2(AREA_X, AREA_Y)
		"top":
			stripe.size = Vector2(AREA_W, 4)
			stripe.position = Vector2(AREA_X, AREA_Y)
		"bottom":
			stripe.size = Vector2(AREA_W, 4)
			stripe.position = Vector2(AREA_X, AREA_Y + AREA_H - 4)
	stripe.z_index = 1
	_panel.add_child(stripe)
	_content_nodes.append(stripe)

	# Arrow glyph
	var arrow_text := ""
	match edge:
		"right":  arrow_text = ">>"
		"left":   arrow_text = "<<"
		"top":    arrow_text = "^^"
		"bottom": arrow_text = "vv"

	var arrow := _make_label(arrow_text, 9,
		map_pos + Vector2(-8, -7), Vector2(16, 14),
		Color(1.0, 0.65, 0.15, 1.0))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.z_index = 5
	_panel.add_child(arrow)
	_content_nodes.append(arrow)

	# Destination label next to arrow
	var lbl_offset := Vector2.ZERO
	match edge:
		"right":
			lbl_offset = Vector2(-60, -7)
		"left":
			lbl_offset = Vector2(10, -7)
		"top":
			lbl_offset = Vector2(-25, 8)
		"bottom":
			lbl_offset = Vector2(-25, -18)

	var dest_lbl := _make_label("to " + dest, 6,
		map_pos + lbl_offset, Vector2(60, 10),
		Color(1.0, 0.70, 0.25, 0.95))
	dest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dest_lbl.z_index = 5
	_panel.add_child(dest_lbl)
	_content_nodes.append(dest_lbl)

# -- Player Tracking (only thing that moves) -----------------------------------

func _update_player_dot() -> void:
	if not _player_dot or not _panel:
		return
	var player: Node2D = _find_player()
	if not player:
		return
	var map_pos: Vector2 = _world_to_map(player.global_position)
	map_pos = _clamp_to_area(map_pos)
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
	return Vector2(AREA_X + nx * AREA_W, AREA_Y + ny * AREA_H)

func _clamp_to_area(pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, AREA_X + 4, AREA_X + AREA_W - 4)
	pos.y = clampf(pos.y, AREA_Y + 4, AREA_Y + AREA_H - 4)
	return pos

# -- Public API -----------------------------------------------------------------

func open() -> void:
	_rebuild_scene_content()
	visible = true

func close() -> void:
	visible = false
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm:
		sm._map_open = false

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
