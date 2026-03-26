# map_overlay.gd -- Display-only county map showing current location.
# Opened by pressing M from any scene via SceneManager.
# Shows all discovered locations with a "You Are Here" marker.
# Navigation is done by WALKING, not clicking the map.
extends CanvasLayer

# -- Map Panel Layout -----------------------------------------------------------
const PANEL_W := 280
const PANEL_H := 150
const PANEL_X := 20
const PANEL_Y := 15

# -- Location Registry ----------------------------------------------------------
# Each entry: { id, label, map_pos (on-panel), pin_color_fallback }
# Unlock state is checked dynamically from GameData.
var locations: Array = [
	{"id": "home",             "label": "Home Property",    "map_pos": Vector2(42, 50)},
	{"id": "county_road",      "label": "County Road",      "map_pos": Vector2(100, 55)},
	{"id": "cedar_bend",       "label": "Cedar Bend",       "map_pos": Vector2(170, 38)},
	{"id": "harmon_farm",      "label": "Harmon Farm",      "map_pos": Vector2(100, 90)},
	{"id": "timber_creek",     "label": "Timber Creek",     "map_pos": Vector2(42, 90)},
	{"id": "community_garden", "label": "Community Garden",  "map_pos": Vector2(220, 65)},
	{"id": "fairgrounds",      "label": "Fairgrounds",      "map_pos": Vector2(220, 100)},
]

# IDs of locations the player has discovered (visited at least once)
# In first-pass, everything is visible. Later this can be gated.
var discovered: Array = [
	"home", "county_road", "cedar_bend", "harmon_farm",
	"timber_creek", "community_garden", "fairgrounds",
]

# -- Node References ------------------------------------------------------------
var _panel: ColorRect = null
var _pin_nodes: Array = []
var _you_are_here: Label = null

# -- Road/path lines between connected locations --------------------------------
# Pairs of location IDs that are connected by walkable paths
var _connections: Array = [
	["home", "county_road"],
	["county_road", "cedar_bend"],
	["county_road", "harmon_farm"],
	["county_road", "timber_creek"],
	["cedar_bend", "community_garden"],
	["cedar_bend", "fairgrounds"],
]

# -- Lifecycle ------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

# -- UI Build ------------------------------------------------------------------

func _build_ui() -> void:
	# Semi-transparent full-screen dim
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0, 0, 0, 0.55)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_dim)

	# Main panel (parchment)
	_panel = ColorRect.new()
	_panel.name = "MapPanel"
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.color = Color(0.855, 0.765, 0.596, 1.0)
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

	# Header
	var header := _make_label("MILLHAVEN COUNTY", 10,
		Vector2(0, 6), Vector2(PANEL_W, 16),
		Color(0.235, 0.176, 0.110, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(header)

	# Footer hint
	var footer := _make_label("press ESC or M to close", 6,
		Vector2(0, PANEL_H - 14), Vector2(PANEL_W, 12),
		Color(0.39, 0.33, 0.22, 1.0))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(footer)

	# "You Are Here" label (positioned dynamically)
	_you_are_here = _make_label("* You Are Here *", 5,
		Vector2(0, 0), Vector2(80, 10),
		Color(0.80, 0.22, 0.15, 1.0))
	_you_are_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_you_are_here)

	_rebuild_pins()

func _rebuild_pins() -> void:
	for n in _pin_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_pin_nodes.clear()

	for loc in locations:
		_spawn_pin(loc)

func _spawn_pin(loc: Dictionary) -> void:
	if not _panel:
		return
	var is_discovered: bool = loc["id"] in discovered
	var is_current: bool = (loc["id"] == TimeManager.current_scene_id)

	var pin_container := Control.new()
	pin_container.name = "Pin_" + loc["id"]
	pin_container.size = Vector2(50, 20)
	pin_container.position = loc["map_pos"] - Vector2(25, 6)
	pin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(pin_container)
	_pin_nodes.append(pin_container)

	if not is_discovered:
		# Unknown location -- show "?"
		var q := _make_label("?", 7,
			Vector2(20, 2), Vector2(10, 12),
			Color(0.50, 0.47, 0.42, 1.0))
		pin_container.add_child(q)
		return

	# Pin dot
	var dot := ColorRect.new()
	dot.size = Vector2(6, 6)
	dot.position = Vector2(22, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_current:
		dot.color = Color(0.85, 0.25, 0.18, 1.0)   # red for current location
	else:
		dot.color = Color(0.55, 0.40, 0.18, 1.0)   # brown for other locations
	pin_container.add_child(dot)

	# Location label
	var lbl := _make_label(loc["label"], 5,
		Vector2(0, -8), Vector2(50, 10),
		Color(0.22, 0.16, 0.08, 1.0) if is_discovered else Color(0.55, 0.50, 0.44, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin_container.add_child(lbl)

	# Position "You Are Here" on current location
	if is_current and _you_are_here:
		_you_are_here.position = loc["map_pos"] - Vector2(40, -10)

# -- Drawing road connections ---------------------------------------------------

func _draw_connections() -> void:
	# Draw faint lines between connected locations on the map
	for conn in _connections:
		var from_pos: Vector2 = Vector2.ZERO
		var to_pos: Vector2 = Vector2.ZERO
		for loc in locations:
			if loc["id"] == conn[0]:
				from_pos = loc["map_pos"]
			elif loc["id"] == conn[1]:
				to_pos = loc["map_pos"]
		if from_pos != Vector2.ZERO or to_pos != Vector2.ZERO:
			# We draw these as ColorRect "road" segments between pins
			pass  # Road lines handled in queue_redraw approach below

# -- Public API -----------------------------------------------------------------

func open() -> void:
	_rebuild_pins()
	visible = true

func close() -> void:
	visible = false
	# Notify SceneManager
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
