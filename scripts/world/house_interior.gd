# house_interior.gd -- Player's farmhouse interior (sprite-based).
# 15x10 tiles at 32px = 480x320 room with cozy Leonardo-generated art.
extends Node2D

const TILE     := 32
const W        := 15
const H        := 10
const DOOR_COL := 7   # 0-indexed centre column (15 tiles wide)

# Bed interaction zone (right side of room, matches art placement)
const BED_MIN_COL := 11
const BED_MAX_COL := 13
const BED_MIN_ROW := 3
const BED_MAX_ROW := 5

var _transitioning := false
var _prompt_label: Label = null
var _summary_overlay: ColorRect = null

# Bed centre in pixels for distance check
var _bed_centre := Vector2(
	(BED_MIN_COL + (BED_MAX_COL - BED_MIN_COL + 1) * 0.5) * TILE,
	(BED_MIN_ROW + (BED_MAX_ROW - BED_MIN_ROW + 1) * 0.5) * TILE)
const BED_RADIUS := 64.0   # how close the player must be to interact

## Ready.
func _ready() -> void:
	TimeManager.current_scene_id = "house_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "House Interior"
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(0, 0, W * TILE, H * TILE))
		SceneManager.register_scene_poi(
			Vector2(DOOR_COL * TILE + TILE * 0.5, (H - 1) * TILE),
			"Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_poi(
			Vector2((BED_MIN_COL + 1) * TILE, (BED_MIN_ROW + 1) * TILE),
			"Bed", Color(0.3, 0.5, 0.8))
		SceneManager.register_scene_exit("bottom", "Outside")
	if not get_node_or_null("Background"):
		_build_background()
	if not get_node_or_null("Walls"):
		_build_walls()
	if not get_node_or_null("BedPrompt"):
		_build_prompt_label()
	else:
		_prompt_label = get_node("BedPrompt") as Label
	_place_player()

# -- Background sprite ---------------------------------------------------------


## Disconnect signals when exiting tree.
func _exit_tree() -> void:
	pass  # Signal cleanup handled by node references
func _build_background() -> void:
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.z_index = -10
	# Load image at runtime to avoid import-pipeline issues
	var path := "res://assets/sprites/interiors/house_interior_bg.png"
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		push_error("house_interior: failed to load background from %s" % abs_path)
		return
	var tex := ImageTexture.create_from_image(img)
	bg.texture = tex
	add_child(bg)

# -- Player spawn --------------------------------------------------------------

func _place_player() -> void:
	var player: Node2D = get_node_or_null("player") as Node2D
	if player:
		# Spawn just above the door so player enters from the bottom
		player.position = Vector2(DOOR_COL * TILE + TILE * 0.5, (H - 2) * TILE)

# -- Collision walls -----------------------------------------------------------

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	# Top wall
	_add_shape(body, 0, 0, W, 1)
	# Left wall
	_add_shape(body, 0, 1, 1, H - 1)
	# Right wall
	_add_shape(body, W - 1, 1, 1, H - 1)
	# Bottom wall left of door
	_add_shape(body, 0, H - 1, DOOR_COL, 1)
	# Bottom wall right of door
	_add_shape(body, DOOR_COL + 1, H - 1, W - DOOR_COL - 1, 1)
	# Door column (row H-1, col DOOR_COL) intentionally has NO collision

func _add_shape(body: StaticBody2D, tx: int, ty: int, tw: int, th: int) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(tw * TILE, th * TILE)
	cs.shape = rs
	cs.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	body.add_child(cs)

# -- Bed interaction (distance-based) ------------------------------------------

func _is_player_near_bed() -> bool:
	var player := _find_player()
	if player == null:
		return false
	return (player as Node2D).global_position.distance_to(_bed_centre) <= BED_RADIUS

func _build_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "BedPrompt"
	_prompt_label.text = "[E] Sleep"
	_prompt_label.add_theme_font_size_override("font_size", 10)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(
		(BED_MIN_COL + 1) * TILE - 24,
		(BED_MIN_ROW - 1) * TILE)
	_prompt_label.z_index = 20
	_prompt_label.visible = false
	add_child(_prompt_label)

# -- Input: bed sleep on E ----------------------------------------------------

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E and _is_player_near_bed():
		_do_sleep()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_trigger()

func _do_sleep() -> void:
	if _summary_overlay and is_instance_valid(_summary_overlay):
		return
	_show_daily_summary()
	print("[House] Player went to sleep.")

# -- Daily Summary Overlay (self-contained, mirrors HUD version) ---------------

func _show_daily_summary() -> void:
	# We need a CanvasLayer so the overlay draws on top of everything
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	_summary_overlay = overlay

	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.07, 0.04, 0.97)
	panel.size = Vector2(180, 130)
	panel.position = Vector2(70, 25)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	# Optional panel texture
	var ptex := "res://assets/sprites/ui/menu_panel.png"
	if ResourceLoader.exists(ptex):
		var tex := TextureRect.new()
		tex.texture = load(ptex)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex)

	# Gold border
	var bsty := StyleBoxFlat.new()
	bsty.bg_color = Color(0, 0, 0, 0)
	bsty.draw_center = false
	bsty.border_color = Color(0.75, 0.60, 0.25, 1.0)
	bsty.set_border_width_all(1)
	var brd := Panel.new()
	brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brd.add_theme_stylebox_override("panel", bsty)
	panel.add_child(brd)

	# Title
	var title := _make_lbl("*  Day %d Complete  *" % TimeManager.current_day, 8,
		Vector2(10, 8), Vector2(160, 14), Color(0.95, 0.80, 0.35, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# Date
	var date_lbl := _make_lbl(
		"%s %d, Year %d - %s" % [TimeManager.current_month_name(),
		TimeManager.current_day_of_month(), TimeManager.current_year(),
		TimeManager.current_season_name()], 6,
		Vector2(10, 22), Vector2(160, 10), Color(0.70, 0.65, 0.55, 1.0))
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(date_lbl)

	# Divider
	var div := ColorRect.new()
	div.color = Color(0.75, 0.60, 0.25, 0.40)
	div.size = Vector2(160, 1)
	div.position = Vector2(10, 35)
	panel.add_child(div)

	# Stats
	var player := _find_player()
	var honey_cnt := 0
	if player and player.has_method("get_item_count"):
		honey_cnt = player.get_item_count(GameData.ITEM_RAW_HONEY) + player.get_item_count(GameData.ITEM_HONEY_JAR)

	var stats: Array = [
		["Balance", "$%.2f" % GameData.money],
		["Energy", "%d / %d" % [int(GameData.energy), int(GameData.max_energy)]],
		["Honey", "%d lbs" % honey_cnt],
	]

	var sy := 42
	for pair in stats:
		var row := _make_lbl("%-12s  %s" % [pair[0], pair[1]], 6,
			Vector2(16, sy), Vector2(148, 10), Color(0.85, 0.82, 0.75, 1.0))
		panel.add_child(row)
		sy += 12

	# Tomorrow preview
	@warning_ignore("INTEGER_DIVISION")
	var nm_idx: int = ((TimeManager.current_day) % TimeManager.YEAR_LENGTH) / TimeManager.MONTH_LENGTH
	var prev := _make_lbl("Tomorrow: Day %d  (%s)" % [TimeManager.current_day + 1,
		TimeManager.MONTH_NAMES[nm_idx]], 6,
		Vector2(10, sy + 2), Vector2(160, 10), Color(0.55, 0.65, 0.50, 1.0))
	prev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(prev)

	# Accept button
	var btn := Button.new()
	btn.text = "Begin Day %d" % (TimeManager.current_day + 1)
	btn.size = Vector2(100, 16)
	btn.position = Vector2(40, 110)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	panel.add_child(btn)
	btn.pressed.connect(_on_summary_accepted.bind(canvas))

## On summary accepted.
func _on_summary_accepted(canvas_layer: CanvasLayer) -> void:
	# Save the game BEFORE advancing -- captures end-of-day state.
	# Dev mode advance_day (G-key / HUD button) intentionally skips saving.
	var ok := SaveManager.save_game()
	if ok:
		print("[House] Game saved (bed sleep) -- Day %d" % TimeManager.current_day)
	else:
		push_warning("[House] Save failed before day advance!")

	# Advance hives / flowers in the exterior world (if any are cached)
	for h in get_tree().get_nodes_in_group("hive"):
		if h.has_method("advance_day"):
			h.advance_day()
	for fl in get_tree().get_nodes_in_group("flowers"):
		if fl.has_method("advance_day_with_global"):
			fl.advance_day_with_global(TimeManager.current_day + 1)
	canvas_layer.queue_free()
	_summary_overlay = null
	TimeManager.start_new_day()
	GameData.full_restore_energy()

func _make_lbl(text: String, font_size: int, pos: Vector2, sz: Vector2, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# -- Door overlap check (runs every frame) ------------------------------------

func _door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(DOOR_COL * TILE, (H - 1) * TILE),
				 Vector2(TILE, TILE))

# Player feet rect -- matches CollisionShape2D: size 14x10, centre at (0, 11)
func _feet_rect(player_gpos: Vector2) -> Rect2:
	return Rect2(player_gpos + Vector2(-7.0, 6.0), Vector2(14.0, 10.0))

## Process.
func _process(_delta: float) -> void:
	if _transitioning:
		return
	var player := _find_player()
	if player == null:
		return

	# Update bed prompt visibility
	var near_bed := _is_player_near_bed()
	if _prompt_label:
		_prompt_label.visible = near_bed

	# Door exit check
	var feet: Rect2 = _feet_rect((player as Node2D).global_position)
	var door := _door_world_rect()
	var isect := door.intersection(feet)
	# Trigger when >50% of the foot rectangle is inside the door tile
	if isect.get_area() > feet.get_area() * 0.5:
		_trigger()

## Find player.
func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _trigger() -> void:
	_transitioning = true
	TimeManager.came_from_interior = true
	# Nudge the return position south of the door so the player does not
	# immediately re-enter the building on the other side.
	var player := _find_player()
	if player:
		# Use the saved entry position but push 40px below the door zone
		TimeManager.player_return_pos = TimeManager.player_return_pos + Vector2(0, 40)
	TimeManager.next_scene = "res://scenes/home_property.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
