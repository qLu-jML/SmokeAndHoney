# SceneManager.gd -- Global scene transition and map overlay manager.
# Handles M-key map overlay from any scene, zone minimap display,
# and scene transition routing.
# Autoloaded as "SceneManager" in project.godot.
extends Node

# -- Map Overlay ----------------------------------------------------------------
var _map_overlay_scene: PackedScene = null
var _map_overlay_instance: Node = null
var _map_open: bool = false

# -- Scene POI and Exit Registration -------------------------------------------
# Each scene populates these in _ready(); map overlay reads them.
# POI format: { "pos": Vector2, "label": String, "color": Color (optional) }
# Exit format: { "edge": String, "label": String }
var _scene_pois: Array = []
var _scene_exits: Array = []
var _scene_bounds: Rect2 = Rect2(-350, -120, 700, 240)  # default bounds

func register_scene_poi(world_pos: Vector2, label: String, color: Color = Color(0.85, 0.72, 0.35, 1.0)) -> void:
	_scene_pois.append({"pos": world_pos, "label": label, "color": color})

func register_scene_exit(edge: String, label: String) -> void:
	_scene_exits.append({"edge": edge, "label": label})

func set_scene_bounds(bounds: Rect2) -> void:
	_scene_bounds = bounds

func clear_scene_markers() -> void:
	_scene_pois.clear()
	_scene_exits.clear()
	_scene_bounds = Rect2(-350, -120, 700, 240)

func get_scene_pois() -> Array:
	return _scene_pois

func get_scene_exits() -> Array:
	return _scene_exits

func get_scene_bounds() -> Rect2:
	return _scene_bounds

# -- Zone Minimap ---------------------------------------------------------------
var _zone_label: Label = null
var _zone_bg: ColorRect = null
var _zone_visible: bool = false
var _zone_fade_timer: float = 0.0
const ZONE_DISPLAY_TIME := 3.0

# Current zone name for display
var current_zone_name: String = "Home Property"

func _ready() -> void:
	# Pre-load the map overlay scene
	if ResourceLoader.exists("res://scenes/ui/map_overlay.tscn"):
		_map_overlay_scene = load("res://scenes/ui/map_overlay.tscn")
	_build_zone_hud()

func _build_zone_hud() -> void:
	# Small label in top-left showing current zone when M is pressed briefly
	var canvas := CanvasLayer.new()
	canvas.name = "ZoneHUD"
	canvas.layer = 25
	add_child(canvas)

	_zone_bg = ColorRect.new()
	_zone_bg.size = Vector2(140, 18)
	_zone_bg.position = Vector2(90, 2)
	_zone_bg.color = Color(0.12, 0.08, 0.04, 0.75)
	_zone_bg.visible = false
	_zone_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_zone_bg)

	_zone_label = Label.new()
	_zone_label.text = ""
	_zone_label.position = Vector2(0, 1)
	_zone_label.size = Vector2(140, 16)
	_zone_label.add_theme_font_size_override("font_size", 7)
	_zone_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1.0))
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_bg.add_child(_zone_label)

func _process(delta: float) -> void:
	if _zone_visible:
		_zone_fade_timer -= delta
		if _zone_fade_timer <= 0.0:
			_zone_visible = false
			if _zone_bg:
				_zone_bg.visible = false

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_M:
		# Don't open map if a UI overlay is blocking
		if get_tree().paused:
			return
		_toggle_map()

func _toggle_map() -> void:
	if _map_open:
		_close_map()
	else:
		_open_map()

func _open_map() -> void:
	if _map_overlay_instance and is_instance_valid(_map_overlay_instance):
		_map_overlay_instance.open()
		_map_open = true
		return

	# Instantiate a fresh overlay
	if _map_overlay_scene:
		_map_overlay_instance = _map_overlay_scene.instantiate()
		get_tree().root.add_child(_map_overlay_instance)
		_map_overlay_instance.open()
		_map_open = true
	else:
		# Fallback: just show zone name
		show_zone_name()

func _close_map() -> void:
	_map_open = false
	if _map_overlay_instance and is_instance_valid(_map_overlay_instance):
		_map_overlay_instance.close()

func show_zone_name() -> void:
	# Flash the current zone name on screen
	if _zone_label:
		_zone_label.text = current_zone_name
	if _zone_bg:
		_zone_bg.visible = true
	_zone_visible = true
	_zone_fade_timer = ZONE_DISPLAY_TIME

# -- Scene Transition Helpers ---------------------------------------------------

func go_to_scene(scene_path: String, from_scene: String = "") -> void:
	if from_scene != "":
		TimeManager.previous_scene = from_scene
	TimeManager.next_scene = scene_path
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")

func go_back() -> void:
	# Return to the previous scene (e.g., exiting an interior)
	var target: String = TimeManager.previous_scene
	if target == "":
		target = "res://scenes/home_property.tscn"
	TimeManager.next_scene = target
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
