# post_office_interior.gd -- Cedar Bend Post Office interior.
# GDD S13.3: June the postmaster behind the counter. Player collects pending
#   deliveries and confirms outgoing shipments. Minimal interior.
#   Spring: buzzing package box present (bee packages pending delivery).
extends Node2D

const INTERACT_RADIUS: float = 54.0

@onready var june_npc: Node2D = $World/NPCs/JunePostmaster
@onready var package_box: Node2D = $World/Props/PackageBox
@onready var counter_ui: CanvasLayer = $CounterUI
@onready var june_hint: Label = $World/NPCs/JunePostmaster/InteractHint

var _counter_open: bool = false

# -- Lifecycle -----------------------------------------------------------------

## Initialize the post office: scene info, counter UI, and signal connections.
func _ready() -> void:
	TimeManager.current_scene_id = "post_office_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Cedar Bend Post Office"
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(-160, -90, 320, 180))
		SceneManager.register_scene_poi(Vector2(0, -30), "Counter", Color(0.7, 0.5, 0.3))
		SceneManager.register_scene_poi(Vector2(0, 80), "Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Cedar Bend")
	_build_counter_ui()
	_update_package_visibility()
	TimeManager.day_advanced.connect(_on_day_advanced)
	print("Cedar Bend Post Office interior loaded.")

## Handle day advancement to update package visibility.
func _on_day_advanced(_day: int) -> void:
	_update_package_visibility()

# -- Package Box Visibility ----------------------------------------------------

func _update_package_visibility() -> void:
	# The "buzzing package box" is visible in Spring when pending deliveries exist
	if not package_box:
		return
	var season := TimeManager.current_season_name()
	var has_pending: bool = GameData.pending_deliveries.size() > 0
	package_box.visible = (season == "Spring") or has_pending

# -- Interaction ---------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_hints()

func _update_hints() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not june_npc or not june_hint:
		return
	var dist := player.global_position.distance_to(june_npc.global_position)
	june_hint.visible = (dist <= INTERACT_RADIUS) and not _counter_open

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if not _counter_open:
					_try_interact_june()
			KEY_ESCAPE, KEY_X:
				if _counter_open:
					_close_counter()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_BACKSPACE:
				get_viewport().set_input_as_handled()
				_exit_post_office()

func _try_interact_june() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not june_npc:
		return
	var dist := player.global_position.distance_to(june_npc.global_position)
	if dist <= INTERACT_RADIUS:
		_open_counter()

# -- Counter / Delivery UI -----------------------------------------------------

func _build_counter_ui() -> void:
	if not counter_ui:
		return

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(15)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = 2
	counter_ui.add_child(overlay)

	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -160)
	panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  160)
	panel.set_anchor_and_offset(SIDE_TOP,    0.5, -130)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  130)
	panel.color = Color(0.18, 0.20, 0.28, 0.97)
	counter_ui.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "Cedar Bend Post Office"
	title.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	title.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	title.set_anchor_and_offset(SIDE_TOP,    0.5, -123)
	title.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -103)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95, 1))
	title.add_theme_font_size_override("font_size", 12)
	counter_ui.add_child(title)

	var june_says := Label.new()
	june_says.name = "JuneSays"
	june_says.set_anchor_and_offset(SIDE_LEFT,   0.5, -152)
	june_says.set_anchor_and_offset(SIDE_RIGHT,  0.5,  152)
	june_says.set_anchor_and_offset(SIDE_TOP,    0.5, -100)
	june_says.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  -72)
	june_says.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	june_says.add_theme_color_override("font_color", Color(0.78, 0.84, 0.90, 1))
	june_says.add_theme_font_size_override("font_size", 7)
	june_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counter_ui.add_child(june_says)

	# Delivery list area
	var delivery_lbl := Label.new()
	delivery_lbl.name = "DeliveryList"
	delivery_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -148)
	delivery_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  148)
	delivery_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,  -68)
	delivery_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   55)
	delivery_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.70, 1))
	delivery_lbl.add_theme_font_size_override("font_size", 7)
	counter_ui.add_child(delivery_lbl)

	# Collect all button
	var collect_btn := Button.new()
	collect_btn.name = "CollectBtn"
	collect_btn.text = "Collect All Packages"
	collect_btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -100)
	collect_btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  100)
	collect_btn.set_anchor_and_offset(SIDE_TOP,    0.5,   58)
	collect_btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   82)
	collect_btn.add_theme_font_size_override("font_size", 8)
	collect_btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.70, 1))
	collect_btn.pressed.connect(_collect_all_deliveries)
	counter_ui.add_child(collect_btn)

	var close_lbl := Label.new()
	close_lbl.text = "[X] or [ESC] to close"
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,   100)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   118)
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55, 1))
	close_lbl.add_theme_font_size_override("font_size", 6)
	counter_ui.add_child(close_lbl)

	counter_ui.visible = false

func _open_counter() -> void:
	_counter_open = true
	counter_ui.visible = true
	_refresh_counter()

func _close_counter() -> void:
	_counter_open = false
	counter_ui.visible = false

func _refresh_counter() -> void:
	var june_says: Label = counter_ui.get_node_or_null("JuneSays") as Label
	var delivery_lbl: Label = counter_ui.get_node_or_null("DeliveryList") as Label
	var collect_btn: Button = counter_ui.get_node_or_null("CollectBtn") as Button
	var deliveries := GameData.pending_deliveries
	var has_items: bool = deliveries.size() > 0

	if june_says:
		if has_items:
			june_says.text = "Morning! Got some packages here for you."
		else:
			june_says.text = "Nothing waiting for you today.\nCheck back after placing an order at Tanner's."

	if delivery_lbl:
		if has_items:
			var lines: Array = []
			for d in deliveries:
				lines.append("  * %d x %s" % [d["count"], d["item"].replace("_", " ").capitalize()])
			delivery_lbl.text = "Packages ready for pickup:\n" + "\n".join(lines)
		else:
			delivery_lbl.text = ""

	if collect_btn:
		collect_btn.visible = has_items
		collect_btn.disabled = not has_items

func _collect_all_deliveries() -> void:
	var deliveries := GameData.pending_deliveries.duplicate()
	if deliveries.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player")
	for d in deliveries:
		if player and player.has_method("add_item"):
			player.add_item(d["item"], d["count"])
		print("[Post Office] Collected: %d x %s" % [d["count"], d["item"]])

	GameData.pending_deliveries.clear()
	_update_package_visibility()

	print("[Post Office] All packages collected!")
	_close_counter()

# -- Exit ---------------------------------------------------------------------

func _exit_post_office() -> void:
	print("[Post Office] Leaving -- returning to Cedar Bend.")
	TimeManager.previous_scene = "res://scenes/world/post_office_interior.tscn"
	TimeManager.next_scene     = "res://scenes/world/cedar_bend.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
