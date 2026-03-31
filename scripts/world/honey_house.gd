# honey_house.gd -- Honey House interior with harvest pipeline stations.
# Replaces generic_interior.gd for the Honey House scene.
# Manages 5 interactive stations: Super Prep, Frame Holder, Uncapping,
# Honey Spinner, and Canning Table.
# -----------------------------------------------------------------------------
extends Node2D

# -- Room layout (same interface as generic_interior.gd) -----------------------
@export var room_width: int = 12
@export var room_height: int = 10
@export var door_col: int = 5
@export var zone_name: String = "Honey House"
@export var scene_id: String = "honey_house"
@export var exit_scene: String = "res://scenes/home_property.tscn"
@export var floor_color: Color = Color(0.62, 0.55, 0.42, 1.0)
@export var wall_color: Color = Color(0.40, 0.28, 0.15, 1.0)

const TILE := 32

# -- Pipeline State Machine ---------------------------------------------------
enum Station {
	NONE,
	SUPER_PREP,
	FRAME_HOLDER,
	UNCAPPING,
	SPINNER,
	CANNING,
	BUCKET,        # Honey bucket on the floor near the spinner
}

# Current harvest pipeline data
var _frames_in_holder: Array = []      # Array of frame data dicts from the super
var _frames_uncapped: Array = []       # Frames that have been uncapped and ready for spinner
var _frames_in_spinner: Array = []     # Frames loaded into the spinner
var _bucket_honey_lbs: float = 0.0     # Honey in the white bucket (lbs)
var _bucket_beeswax_lbs: float = 0.0   # Beeswax collected during uncapping
var _spinner_spinning: bool = false     # Is spinner currently active?
var _spinner_progress: float = 0.0     # 0.0 to 1.0 spin progress
var _active_station: Station = Station.NONE
var _player_carrying_bucket: bool = false  # True after player picks up honey bucket
var _bucket_on_table:        bool = false  # True after bucket placed on canning table
var _jars_on_table: Array = []            # Sprite2D nodes for filled jars on table

# Jar sprite path (filled honey jar displayed on the canning table)
const JAR_SPRITE_PATH := "res://assets/sprites/items/honey_jar_standard.png"
# Max jars that fit on the table in one row before wrapping
const TABLE_JARS_PER_ROW := 4

# -- Station interaction zones ------------------------------------------------
var _station_areas: Dictionary = {}    # Station -> Rect2 (world coords)
var _station_labels: Dictionary = {}   # Station -> Label node
var _station_prompts: Dictionary = {}  # Station -> Label node (E prompt)

# -- Player reference ---------------------------------------------------------
var _player_cache: Node2D = null
var _transitioning := false

# -- Spinner button-mash tracking --------------------------------------------
const SPINNER_DURATION := 20.0        # seconds of mashing required
const SPINNER_PRESS_VALUE := 0.012    # each E press adds this to progress (need ~83 presses)
var _spinner_timer: float = 0.0

# -- Uncapping overlay -------------------------------------------------------
var _uncapping_active: bool = false
var _uncapping_frame_idx: int = 0      # which frame in _frames_in_holder we're uncapping
var _uncapping_overlay: Node = null
const SCRAPING_MINIGAME_PATH := "res://scripts/ui/scraping_minigame.gd"

# -- Canning state -----------------------------------------------------------
var _canning_active: bool = false

# -- Sprites -----------------------------------------------------------------
var _spinner_sprite: Sprite2D = null   # Honey spinner graphic
var _bucket_sprite: Sprite2D = null    # Honey bucket graphic

# -- UI Elements -------------------------------------------------------------
var _status_label: Label = null        # Shows current pipeline status
var _progress_bar: ColorRect = null    # Spinner progress bar
var _progress_fill: ColorRect = null
var _carry_label: Label = null         # Shows "Carrying bucket" when player holds it

# -- Station Rects (tile coordinates) ----------------------------------------
# Layout (12x10 room):
#   Row 0: wall
#   Row 1: Super Prep (cols 1-3) | Frame Holder (cols 5-7)
#   Row 2-3: (continued)
#   Row 4: Uncapping Station (cols 1-3)
#   Row 5-6: Spinner (cols 5-8, larger)
#   Row 7: Canning Table (cols 1-4) | Honey Shelf (cols 6-10)
#   Row 8: floor
#   Row 9: wall + door

const PREP_RECT     := Rect2(1, 1, 3, 2)
const HOLDER_RECT   := Rect2(5, 1, 3, 2)
const UNCAP_RECT    := Rect2(1, 4, 3, 2)
const SPINNER_RECT  := Rect2(5, 4, 4, 3)
const CANNING_RECT  := Rect2(1, 7, 4, 1)
const SHELF_RECT    := Rect2(6, 7, 5, 1)
# Tile where the honey bucket rests on the floor (bottom-right of spinner, in aisle)
const BUCKET_TILE   := Vector2(5, 7)

# -- Lifecycle ----------------------------------------------------------------
func _ready() -> void:
	TimeManager.current_scene_id = scene_id
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = zone_name
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(0, 0, room_width * TILE, room_height * TILE))
		SceneManager.register_scene_poi(
			Vector2(door_col * TILE + TILE * 0.5, (room_height - 1) * TILE),
			"Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Exit")

	_build_walls()
	_create_stations()
	_create_ui()
	_place_player()
	queue_redraw()
	print("Honey House interior loaded.")

func _place_player() -> void:
	var player: Node2D = get_node_or_null("player") as Node2D
	if player:
		player.position = Vector2((room_width * 0.5) * TILE, (room_height - 2) * TILE)

# -- Drawing ------------------------------------------------------------------
func _draw() -> void:
	var door_color := Color(0.30, 0.15, 0.04, 1.0)
	var edge_color := Color(0.25, 0.15, 0.05, 1.0)
	for row in range(room_height):
		for col in range(room_width):
			var r := Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE))
			var fill: Color
			if row == 0 or col == 0 or col == room_width - 1:
				fill = wall_color
			elif row == room_height - 1 and col == door_col:
				fill = door_color
			else:
				fill = floor_color
			draw_rect(r, fill, true)
			draw_rect(r, edge_color, false, 0.5)

	# Draw station areas -- spinner uses real sprite, others use colored rect
	_draw_station_rect(PREP_RECT, Color(0.52, 0.42, 0.26, 1.0))     # wood brown
	_draw_station_rect(HOLDER_RECT, Color(0.48, 0.38, 0.22, 1.0))   # darker wood
	_draw_station_rect(UNCAP_RECT, Color(0.50, 0.40, 0.24, 1.0))    # medium wood
	# SPINNER_RECT: drawn by _spinner_sprite Sprite2D node (no ColorRect fill)
	_draw_station_rect(CANNING_RECT, Color(0.58, 0.48, 0.30, 1.0))  # warm wood
	_draw_station_rect(SHELF_RECT, Color(0.62, 0.48, 0.30, 1.0))    # shelf brown

func _draw_station_rect(tile_rect: Rect2, color: Color) -> void:
	var px_rect := Rect2(tile_rect.position * TILE, tile_rect.size * TILE)
	draw_rect(px_rect, color, true)
	draw_rect(px_rect, Color(0.25, 0.15, 0.05, 1.0), false, 1.0)

# -- Station Setup ------------------------------------------------------------
func _create_stations() -> void:
	var props := get_node_or_null("Props")
	if props:
		# Remove old placeholder props
		for child in props.get_children():
			child.queue_free()

	_station_areas[Station.SUPER_PREP]   = Rect2(PREP_RECT.position * TILE, PREP_RECT.size * TILE)
	_station_areas[Station.FRAME_HOLDER] = Rect2(HOLDER_RECT.position * TILE, HOLDER_RECT.size * TILE)
	_station_areas[Station.UNCAPPING]    = Rect2(UNCAP_RECT.position * TILE, UNCAP_RECT.size * TILE)
	_station_areas[Station.SPINNER]      = Rect2(SPINNER_RECT.position * TILE, SPINNER_RECT.size * TILE)
	_station_areas[Station.CANNING]      = Rect2(CANNING_RECT.position * TILE, CANNING_RECT.size * TILE)
	_station_areas[Station.BUCKET]       = Rect2(BUCKET_TILE * TILE, Vector2(TILE, TILE))

	# Create labels for each station
	_add_station_label(Station.SUPER_PREP, "Super Prep", PREP_RECT)
	_add_station_label(Station.FRAME_HOLDER, "Frame Holder", HOLDER_RECT)
	_add_station_label(Station.UNCAPPING, "Uncapping", UNCAP_RECT)
	_add_station_label(Station.SPINNER, "Honey Spinner", SPINNER_RECT)
	_add_station_label(Station.CANNING, "Canning Table", CANNING_RECT)
	# Shelf label
	var shelf_lbl := Label.new()
	shelf_lbl.text = "Honey Storage"
	shelf_lbl.add_theme_font_size_override("font_size", 4)
	shelf_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30, 1.0))
	shelf_lbl.position = Vector2(SHELF_RECT.position.x * TILE + 8, SHELF_RECT.position.y * TILE - 12)
	add_child(shelf_lbl)

	# -- Spinner Sprite2D -------------------------------------------------------
	var spinner_tex: Texture2D = load("res://assets/sprites/objects/honey_spinner.png") as Texture2D
	if spinner_tex:
		_spinner_sprite = Sprite2D.new()
		_spinner_sprite.texture = spinner_tex
		# Sprite2D is centered by default; offset to align top-left with SPINNER_RECT
		_spinner_sprite.position = Vector2(
			SPINNER_RECT.position.x * TILE + (SPINNER_RECT.size.x * TILE) * 0.5,
			SPINNER_RECT.position.y * TILE + (SPINNER_RECT.size.y * TILE) * 0.5)
		_spinner_sprite.z_index = 2
		add_child(_spinner_sprite)

	# -- Bucket Sprite2D (floor near spinner output) ----------------------------
	var bucket_tex: Texture2D = load("res://assets/sprites/objects/honey_bucket.png") as Texture2D
	if bucket_tex:
		_bucket_sprite = Sprite2D.new()
		_bucket_sprite.texture = bucket_tex
		_bucket_sprite.position = Vector2(
			BUCKET_TILE.x * TILE + TILE * 0.5,
			BUCKET_TILE.y * TILE + TILE * 0.5)
		_bucket_sprite.z_index = 3
		_bucket_sprite.visible = false  # Hidden until honey is extracted
		add_child(_bucket_sprite)

	# Prompt label for the bucket station (no header label, just the E prompt)
	var bucket_prompt := Label.new()
	bucket_prompt.text = ""
	bucket_prompt.add_theme_font_size_override("font_size", 5)
	bucket_prompt.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
	bucket_prompt.position = Vector2(
		BUCKET_TILE.x * TILE - 10,
		(BUCKET_TILE.y + 1) * TILE + 2)
	bucket_prompt.size = Vector2(70, 10)
	bucket_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bucket_prompt.visible = false
	add_child(bucket_prompt)
	_station_prompts[Station.BUCKET] = bucket_prompt

func _add_station_label(station: Station, text: String, tile_rect: Rect2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30, 1.0))
	lbl.position = Vector2(tile_rect.position.x * TILE + 2, tile_rect.position.y * TILE - 12)
	add_child(lbl)
	_station_labels[station] = lbl

	# Interaction prompt (hidden by default)
	var prompt := Label.new()
	prompt.text = ""
	prompt.add_theme_font_size_override("font_size", 5)
	prompt.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
	prompt.position = Vector2(
		tile_rect.position.x * TILE + (tile_rect.size.x * TILE * 0.5) - 30,
		(tile_rect.position.y + tile_rect.size.y) * TILE + 2)
	prompt.size = Vector2(60, 10)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false
	add_child(prompt)
	_station_prompts[station] = prompt

# -- UI Elements -------------------------------------------------------------
func _create_ui() -> void:
	# Status label at top of screen
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", Color(0.90, 0.85, 0.70, 1.0))
	_status_label.position = Vector2(TILE + 4, 4)
	_status_label.size = Vector2((room_width - 2) * TILE, 10)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.z_index = 10
	add_child(_status_label)

	# Progress bar (for spinner) - hidden until needed
	_progress_bar = ColorRect.new()
	_progress_bar.color = Color(0.2, 0.2, 0.2, 0.8)
	_progress_bar.size = Vector2(120, 8)
	@warning_ignore("INTEGER_DIVISION")
	_progress_bar.position = Vector2((room_width * TILE - 120) / 2, room_height * TILE - 48)
	_progress_bar.visible = false
	_progress_bar.z_index = 15
	add_child(_progress_bar)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.95, 0.78, 0.32, 1.0)
	_progress_fill.size = Vector2(0, 6)
	_progress_fill.position = Vector2(1, 1)
	_progress_bar.add_child(_progress_fill)

	# Carrying indicator -- shown at top when player holds the honey bucket
	_carry_label = Label.new()
	_carry_label.text = ""
	_carry_label.add_theme_font_size_override("font_size", 5)
	_carry_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
	_carry_label.position = Vector2(TILE + 4, 14)
	_carry_label.size = Vector2((room_width - 2) * TILE, 10)
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carry_label.z_index = 10
	_carry_label.visible = false
	add_child(_carry_label)

# -- Walls (same as generic_interior) ----------------------------------------
func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	_add_shape(body, 0, 0, room_width, 1)
	_add_shape(body, 0, 1, 1, room_height - 1)
	_add_shape(body, room_width - 1, 1, 1, room_height - 1)
	_add_shape(body, 0, room_height - 1, door_col, 1)
	_add_shape(body, door_col + 1, room_height - 1, room_width - door_col - 1, 1)

	# Station collision bodies (players walk around stations, not through them)
	_add_station_collision(body, PREP_RECT)
	_add_station_collision(body, HOLDER_RECT)
	_add_station_collision(body, UNCAP_RECT)
	_add_station_collision(body, SPINNER_RECT)
	_add_station_collision(body, CANNING_RECT)
	_add_station_collision(body, SHELF_RECT)

func _add_station_collision(body: StaticBody2D, tile_rect: Rect2) -> void:
	_add_shape(body, int(tile_rect.position.x), int(tile_rect.position.y),
		int(tile_rect.size.x), int(tile_rect.size.y))

func _add_shape(body: StaticBody2D, tx: int, ty: int, tw: int, th: int) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(tw * TILE, th * TILE)
	cs.shape = rs
	cs.position = Vector2((tx + tw * 0.5) * TILE, (ty + th * 0.5) * TILE)
	body.add_child(cs)

# -- Door exit (same as generic_interior) -------------------------------------
func _door_world_rect() -> Rect2:
	return Rect2(global_position + Vector2(door_col * TILE, (room_height - 1) * TILE),
				 Vector2(TILE, TILE))

func _feet_rect(player_gpos: Vector2) -> Rect2:
	return Rect2(player_gpos + Vector2(-7.0, 6.0), Vector2(14.0, 10.0))

# -- Main Loop ----------------------------------------------------------------
func _process(delta: float) -> void:
	if _transitioning:
		return

	# Spinner animation update
	if _spinner_spinning:
		_spinner_timer += delta
		if _spinner_timer >= SPINNER_DURATION or _spinner_progress >= 1.0:
			_finish_spinning()

	var player := _find_player()
	if player == null:
		return

	# Door exit check
	var feet: Rect2 = _feet_rect((player as Node2D).global_position)
	var door := _door_world_rect()
	var isect := door.intersection(feet)
	if isect.get_area() > feet.get_area() * 0.5:
		_trigger_exit()
		return

	# Station proximity checks
	_update_station_prompts(player as Node2D)

func _find_player() -> Node:
	if _player_cache and is_instance_valid(_player_cache):
		return _player_cache
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_cache = players[0] as Node2D
		return _player_cache
	return null

# -- Station Proximity & Prompts ----------------------------------------------
const INTERACT_DIST := 48.0

func _update_station_prompts(player: Node2D) -> void:
	# While the uncapping minigame overlay is open, hide all prompts
	if _uncapping_active:
		for station_id in _station_prompts:
			var lbl: Label = _station_prompts.get(station_id)
			if lbl:
				lbl.visible = false
		_active_station = Station.NONE
		return

	var ppos: Vector2 = player.global_position
	_active_station = Station.NONE
	var nearest_dist: float = INF
	var nearest_station: Station = Station.NONE

	# Sync bucket sprite visibility with state
	if _bucket_sprite:
		_bucket_sprite.visible = (_bucket_honey_lbs > 0.0 and not _player_carrying_bucket)

	# Sync carry label
	if _carry_label:
		if _player_carrying_bucket:
			_carry_label.text = "[ Carrying honey bucket -- %.1f lbs ]" % _bucket_honey_lbs
			_carry_label.visible = true
		else:
			_carry_label.visible = false

	for station_id in _station_areas:
		var s: Station = station_id as Station

		# When carrying bucket, only CANNING is interactable
		if _player_carrying_bucket and s != Station.CANNING:
			var pl: Label = _station_prompts.get(s)
			if pl:
				pl.visible = false
			continue

		# BUCKET station only valid when honey present and not carrying
		if s == Station.BUCKET and (_bucket_honey_lbs <= 0.0 or _player_carrying_bucket):
			var pl: Label = _station_prompts.get(s)
			if pl:
				pl.visible = false
			continue

		var area: Rect2 = _station_areas[s]
		var center: Vector2 = area.get_center()
		var dist: float = ppos.distance_to(center)
		var threshold: float = INTERACT_DIST + area.size.length() * 0.3

		if dist < threshold and dist < nearest_dist:
			nearest_dist = dist
			nearest_station = s

	# Show prompt only for the nearest valid station; hide all others
	for station_id in _station_prompts:
		var s: Station = station_id as Station
		var lbl: Label = _station_prompts.get(s)
		if not lbl:
			continue
		if s == nearest_station:
			lbl.text = _get_station_prompt(s)
			lbl.visible = lbl.text != ""
		else:
			lbl.visible = false

	_active_station = nearest_station

func _get_station_prompt(station: Station) -> String:
	match station:
		Station.SUPER_PREP:
			var player := _find_player()
			if player and player.has_method("count_item"):
				var count: int = player.count_item(GameData.ITEM_FULL_SUPER)
				if count > 0:
					return "[E] Break Open Super"
			return "Bring a Full Super"
		Station.FRAME_HOLDER:
			if _frames_in_holder.size() > 0:
				return "[E] Take Frame (%d)" % _frames_in_holder.size()
			return "Empty"
		Station.UNCAPPING:
			if _frames_in_holder.size() > 0:
				return "[E] Uncap Frame"
			return "Load frames first"
		Station.SPINNER:
			if _spinner_spinning:
				return "Press [E] faster!"
			if _frames_uncapped.size() > 0 and _frames_in_spinner.size() < 10:
				return "[E] Load Frame (%d/10)" % _frames_in_spinner.size()
			if _frames_in_spinner.size() > 0:
				return "[E] Spin! (%d frames)" % _frames_in_spinner.size()
			return "Spinner (%d/10)" % _frames_in_spinner.size()
		Station.CANNING:
			if _bucket_on_table:
				if _bucket_honey_lbs < 1.0 or not _player_has_jars():
					return "[E] Collect jars (%d)" % _jars_on_table.size()
				return "[E] Fill jar (%.1f lbs left)" % _bucket_honey_lbs
			elif _player_carrying_bucket:
				return "[E] Place bucket on table"
			elif _bucket_honey_lbs > 0.0:
				return "[E] Pick up bucket (%.1f lbs)" % _bucket_honey_lbs
			return "No honey yet"
		Station.BUCKET:
			if _bucket_honey_lbs > 0.0 and not _player_carrying_bucket and not _bucket_on_table:
				return "[E] Pick up bucket (%.1f lbs)" % _bucket_honey_lbs
	return ""

# -- Input Handling -----------------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_E:
		if event.echo and _spinner_spinning:
			# Repeated E presses during spinning
			_spinner_progress += SPINNER_PRESS_VALUE
			_update_spinner_bar()
			get_viewport().set_input_as_handled()
			return
		if not event.echo:
			_interact_with_station()
			get_viewport().set_input_as_handled()

func _interact_with_station() -> void:
	match _active_station:
		Station.SUPER_PREP:
			_action_super_prep()
		Station.FRAME_HOLDER:
			pass  # Visual only -- frames auto-move to uncapping
		Station.UNCAPPING:
			_action_uncapping()
		Station.SPINNER:
			_action_spinner()
		Station.CANNING:
			_action_canning()
		Station.BUCKET:
			_action_pickup_bucket()

# -- Station Actions ----------------------------------------------------------

## SUPER PREP: Break open a full super into individual frames.
func _action_super_prep() -> void:
	var player := _find_player()
	if player == null or not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_FULL_SUPER, 1):
		_show_status("No full super in inventory!")
		return
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

	# Generate 10 frame data entries from the super.
	# Each frame carries a ScrapeFrame object with realistic cell state data so
	# the uncapping minigame can render the exact InspectionOverlay view.
	_frames_in_holder.clear()
	for i in 10:
		var sf: ScrapeFrame = ScrapeFrame.new()
		sf.fill_for_harvest(85.0)   # 85% capped honey, Level 1 default
		_frames_in_holder.append({
			"frame_idx": i,
			"honey_lbs": 4.0,   # Full medium super frame (40 lbs per 10-frame super)
			"capping_pct": 85.0,
			"uncapped": false,
			"beeswax_lbs": 0.0,
			"scrap_frame": sf,  # ScrapeFrame for the de-capping minigame
		})
	_show_status("Super opened! 10 frames loaded into Frame Holder.")
	# Return the empty super box to player inventory
	if player.has_method("add_item"):
		player.add_item(GameData.ITEM_SUPER_BOX, 1)
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()

## UNCAPPING: Launch the scraping minigame for the next frame from the holder.
func _action_uncapping() -> void:
	if _uncapping_active:
		return  # Minigame already open

	if _frames_in_holder.size() == 0:
		_show_status("No frames to uncap! Break open a super first.")
		return

	if not GameData.deduct_energy(1.0):
		_show_status("Too tired to uncap!")
		return

	_uncapping_active = true
	_uncapping_frame_idx = 0

	var frame_data: Dictionary = _frames_in_holder[0]

	# Build the overlay (script extends CanvasLayer -- same launch pattern as harvest_yard)
	var overlay_script: GDScript = load(SCRAPING_MINIGAME_PATH) as GDScript
	_uncapping_overlay = CanvasLayer.new()
	_uncapping_overlay.layer = 20
	_uncapping_overlay.name = "UncapOverlay"
	_uncapping_overlay.set_script(overlay_script)

	# Set frame data BEFORE add_child so _ready() sees it
	var sf: Object = frame_data.get("scrap_frame", null)
	_uncapping_overlay.set("frame", sf)
	_uncapping_overlay.set("frame_index", 10 - _frames_in_holder.size() + 1)
	_uncapping_overlay.set("frame_total", 10)

	_uncapping_overlay.scraping_complete.connect(_on_uncapping_complete)
	_uncapping_overlay.scraping_cancelled.connect(_on_uncapping_cancelled)
	add_child(_uncapping_overlay)

func _on_uncapping_complete() -> void:
	if _uncapping_overlay == null:
		return

	# Read how many cells were actually scraped for wax calculation
	var cells_scraped: int = 0
	if _uncapping_overlay.has_method("get"):
		cells_scraped = int(_uncapping_overlay.get("result_cells_scraped"))
	# Fallback: assume full frame (both sides)
	if cells_scraped == 0:
		cells_scraped = 4900

	_uncapping_overlay.queue_free()
	_uncapping_overlay = null
	_uncapping_active = false

	if _frames_in_holder.size() == 0:
		return

	var frame_data: Dictionary = _frames_in_holder[0]
	_frames_in_holder.remove_at(0)

	var wax_lbs: float = float(cells_scraped) * 0.00015
	frame_data["uncapped"] = true
	frame_data["beeswax_lbs"] = wax_lbs

	_frames_uncapped.append(frame_data)
	_bucket_beeswax_lbs += wax_lbs

	var remaining: int = _frames_in_holder.size()
	_show_status("Frame uncapped! Wax: %.2f lbs. %d frames remaining." % [wax_lbs, remaining])

func _on_uncapping_cancelled() -> void:
	if _uncapping_overlay:
		_uncapping_overlay.queue_free()
		_uncapping_overlay = null
	_uncapping_active = false
	# Refund energy since player didn't complete the frame
	GameData.restore_energy(1.0)
	_show_status("Uncapping cancelled.")

## SPINNER: Load frames or start spinning.
func _action_spinner() -> void:
	if _spinner_spinning:
		# Each non-echo E press during spinning
		_spinner_progress += SPINNER_PRESS_VALUE
		_update_spinner_bar()
		return

	# If there are uncapped frames and spinner not full, load one
	if _frames_uncapped.size() > 0 and _frames_in_spinner.size() < 10:
		var frame_data: Dictionary = _frames_uncapped[0]
		_frames_uncapped.remove_at(0)
		_frames_in_spinner.append(frame_data)
		_show_status("Frame loaded into spinner (%d/10)." % _frames_in_spinner.size())
		return

	# If spinner has frames and no more to load (or full), start spinning
	if _frames_in_spinner.size() > 0:
		_start_spinning()
		return

	_show_status("Load uncapped frames into the spinner first!")

func _start_spinning() -> void:
	_spinner_spinning = true
	_spinner_progress = 0.0
	_spinner_timer = 0.0
	_progress_bar.visible = true
	_update_spinner_bar()
	_show_status("Press [E] repeatedly to spin! Keep going for 20 seconds!")

func _update_spinner_bar() -> void:
	_spinner_progress = clampf(_spinner_progress, 0.0, 1.0)
	if _progress_fill:
		_progress_fill.size.x = 118.0 * _spinner_progress

func _finish_spinning() -> void:
	_spinner_spinning = false
	_progress_bar.visible = false

	# Calculate total honey yield
	var total_honey: float = 0.0
	for frame_data in _frames_in_spinner:
		total_honey += frame_data.get("honey_lbs", 4.0)

	# Deduct energy: 1.5 per frame
	var energy_cost: float = float(_frames_in_spinner.size()) * 1.5
	GameData.deduct_energy(energy_cost)

	_bucket_honey_lbs += total_honey
	_frames_in_spinner.clear()

	# Add beeswax to player inventory
	if _bucket_beeswax_lbs >= 1.0:
		var whole_lbs: int = int(_bucket_beeswax_lbs)
		var player := _find_player()
		if player and player.has_method("add_item"):
			player.add_item(GameData.ITEM_BEESWAX, whole_lbs)
			if player.has_method("update_hud_inventory"):
				player.update_hud_inventory()
		GameData.beeswax_fractional += _bucket_beeswax_lbs - float(whole_lbs)
		GameData.beeswax_lifetime += _bucket_beeswax_lbs
	else:
		GameData.beeswax_fractional += _bucket_beeswax_lbs
		GameData.beeswax_lifetime += _bucket_beeswax_lbs
	_bucket_beeswax_lbs = 0.0

	# Check if fractional beeswax has accumulated to a full pound
	if GameData.beeswax_fractional >= 1.0:
		var extra: int = int(GameData.beeswax_fractional)
		var player := _find_player()
		if player and player.has_method("add_item"):
			player.add_item(GameData.ITEM_BEESWAX, extra)
		GameData.beeswax_fractional -= float(extra)

	_show_status("Honey extracted! %.1f lbs in bucket. Pick it up and take it to the canning table!" % _bucket_honey_lbs)

	# Make bucket visible on the floor near the spinner
	if _bucket_sprite:
		_bucket_sprite.position = Vector2(
			BUCKET_TILE.x * TILE + TILE * 0.5,
			BUCKET_TILE.y * TILE + TILE * 0.5)
		_bucket_sprite.visible = true

	# XP for extraction
	GameData.add_xp(GameData.XP_HARVEST)

## BUCKET PICKUP: Player picks up the honey bucket from the floor.
## Also adds ITEM_HONEY_BUCKET to inventory so the carry sprite shows on the player.
func _action_pickup_bucket() -> void:
	if _bucket_honey_lbs <= 0.0:
		_show_status("Bucket is empty -- spin honey first!")
		return
	if _player_carrying_bucket:
		_show_status("You are already carrying the bucket!")
		return
	_player_carrying_bucket = true
	if _bucket_sprite:
		_bucket_sprite.visible = false
	# Add to player inventory so carry sprite becomes visible
	var player := _find_player()
	if player and player.has_method("add_item"):
		player.add_item(GameData.ITEM_HONEY_BUCKET, 1)
	_show_status("Picked up bucket (%.1f lbs). Carry it to the canning table!" % _bucket_honey_lbs)

## Returns true if the player has at least one empty jar in inventory.
func _player_has_jars() -> bool:
	var player := _find_player()
	if player == null or not player.has_method("count_item"):
		return false
	return player.count_item(GameData.ITEM_JAR) > 0

## Place a filled-jar sprite on the canning table surface, lined up left to right.
func _place_jar_sprite_on_table() -> void:
	var jar_tex: Texture2D = load(JAR_SPRITE_PATH) as Texture2D
	if jar_tex == null:
		return
	var jar_sprite := Sprite2D.new()
	jar_sprite.texture = jar_tex
	# Layout: jars line up along the canning table (CANNING_RECT row 7, cols 1-4)
	# Place them left to right, wrapping after TABLE_JARS_PER_ROW
	var n: int = _jars_on_table.size()
	var col_idx: int = n % TABLE_JARS_PER_ROW
	@warning_ignore("INTEGER_DIVISION")
	var row_idx: int = n / TABLE_JARS_PER_ROW
	var table_px_x: float = (CANNING_RECT.position.x + 0.5 + float(col_idx)) * TILE
	var table_px_y: float = (CANNING_RECT.position.y + 0.5 + float(row_idx) * 0.6) * TILE
	jar_sprite.position = Vector2(table_px_x, table_px_y)
	jar_sprite.z_index = 4
	add_child(jar_sprite)
	_jars_on_table.append(jar_sprite)

## CANNING: Three-phase jarring workflow.
## Phase 1 -- no bucket: auto-pickup if honey available, else show message.
## Phase 2 -- carrying bucket: press E to place it on the canning table.
## Phase 3 -- bucket on table: press E to fill jars one by one.
##            When bucket empty or no more jars: press E to collect all jars.
func _action_canning() -> void:
	# -- Phase 1: no bucket anywhere, check if we can auto-pickup ---------------
	if not _player_carrying_bucket and not _bucket_on_table:
		if _bucket_honey_lbs > 0.0:
			_action_pickup_bucket()
		else:
			_show_status("No honey yet! Extract honey first.")
		return

	# -- Phase 2: player is carrying bucket, place it on table ------------------
	if _player_carrying_bucket and not _bucket_on_table:
		_bucket_on_table = true
		_player_carrying_bucket = false
		# Remove carry item from inventory so sprite disappears
		var player := _find_player()
		if player and player.has_method("consume_item"):
			player.consume_item(GameData.ITEM_HONEY_BUCKET, 1)
		# Move the bucket sprite to sit on the canning table
		if _bucket_sprite:
			_bucket_sprite.position = Vector2(
				(CANNING_RECT.position.x + CANNING_RECT.size.x - 1) * TILE + TILE * 0.5,
				CANNING_RECT.position.y * TILE + TILE * 0.5)
			_bucket_sprite.visible = true
		_show_status("Bucket placed! Press [E] to fill jars from your inventory.")
		return

	# -- Phase 3: bucket is on table, fill jars or collect ----------------------
	if _bucket_on_table:
		# Collect all when done
		if _bucket_honey_lbs < 1.0 or not _player_has_jars():
			_collect_all_jars()
			return
		# Fill one jar
		var player := _find_player()
		if player == null:
			return
		if not player.has_method("count_item") or player.count_item(GameData.ITEM_JAR) < 1:
			_show_status("No empty jars! Buy some from the Feed & Supply.")
			return
		if not player.consume_item(GameData.ITEM_JAR, 1):
			return
		_bucket_honey_lbs -= 1.0
		_place_jar_sprite_on_table()
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
		if _bucket_honey_lbs < 1.0 or not _player_has_jars():
			var why: String = "Bucket empty!" if _bucket_honey_lbs < 1.0 else "No more jars!"
			_show_status("%s %d jars filled. Press [E] to collect them all!" % [why, _jars_on_table.size()])
			# Hide the now-empty bucket sprite
			if _bucket_sprite:
				_bucket_sprite.visible = false
		else:
			var jars_left: int = player.count_item(GameData.ITEM_JAR)
			_show_status("Jar filled! %d on table. %.1f lbs left. %d jars remaining." % [
				_jars_on_table.size(), _bucket_honey_lbs, jars_left])

## Collect all jars from the canning table into the player's inventory at once.
func _collect_all_jars() -> void:
	if _jars_on_table.is_empty():
		_show_status("Nothing on the table yet!")
		return
	var player := _find_player()
	var jar_count: int = _jars_on_table.size()
	if player and player.has_method("add_item"):
		player.add_item(GameData.ITEM_HONEY_JAR, jar_count)
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
	# Remove all jar sprites from scene
	for jar_sprite in _jars_on_table:
		if is_instance_valid(jar_sprite):
			jar_sprite.queue_free()
	_jars_on_table.clear()
	# Clean up table state
	_bucket_on_table = false
	_bucket_honey_lbs = 0.0
	if _bucket_sprite:
		_bucket_sprite.visible = false
	GameData.add_xp(GameData.XP_HARVEST)
	_show_status("Collected %d honey jars! Take them to town to sell." % jar_count)

# -- Helpers ------------------------------------------------------------------
func _show_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg
	# Also push to notification manager if available
	var nm := get_tree().root.get_node_or_null("NotificationManager")
	if nm and nm.has_method("notify"):
		nm.notify(msg)

func _trigger_exit() -> void:
	_transitioning = true
	var target: String = exit_scene
	if target == "":
		target = TimeManager.previous_scene
	if target == "":
		target = "res://scenes/home_property.tscn"
	TimeManager.came_from_interior = true
	TimeManager.next_scene = target
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
