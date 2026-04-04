@tool
# harvest_yard.gd -- Outdoor Level 1 honey harvest processing yard.
# Manages 5 interactive stations on the home property:
#   1. Super Pallet       -- place full supers, break into frames
#   2. Scraping Station   -- interactive de-capping minigame
#   3. Scraped Frame Pallet -- completed frames fill empty super boxes
#   4. Honey Extractor    -- tap-E gauge minigame to extract honey
#   5. Bottling Table     -- fill jars from honey bucket
# -------------------------------------------------------------------------
extends Node2D

const TILE := 32

# -- Station Enum ---------------------------------------------------------
enum Station {
	NONE,
	SUPER_PALLET,
	SCRAPING,
	SCRAPED_PALLET,
	EXTRACTOR,
	BOTTLING,
}

# -- Station world positions (pixel coords, relative to this node) --------
# Populated at runtime from editor-placed child marker nodes so each station
# can be dragged independently in the Godot editor.
# Fallback defaults match the original hardcoded layout.
var STATION_POS: Dictionary = {
	Station.SUPER_PALLET:   Vector2(0, 0),
	Station.SCRAPING:       Vector2(0, 0),
	Station.SCRAPED_PALLET: Vector2(140, 0),
	Station.EXTRACTOR:      Vector2(260, -40),
	Station.BOTTLING:       Vector2(260, 120),
}

# Map from Station enum to child node name in the scene tree.
const STATION_NODE_NAMES := {
	Station.SUPER_PALLET:   "SuperPallet",
	Station.SCRAPING:       "SuperPallet",      # Scraping happens at the super pallet
	Station.SCRAPED_PALLET: "ScrapedPallet",
	Station.EXTRACTOR:      "Extractor",
	Station.BOTTLING:       "BottlingTable",
}

# Station collision/draw sizes (pixels)
const STATION_SIZE := {
	Station.SUPER_PALLET:   Vector2(96, 64),
	Station.SCRAPED_PALLET: Vector2(96, 64),
	Station.EXTRACTOR:      Vector2(64, 64),
	Station.BOTTLING:       Vector2(96, 80),
}

# Bucket sits between extractor and bottling table
# Populated at runtime from the "HoneyBucket" child marker node.
var BUCKET_OFFSET: Vector2 = Vector2(292, 16)
const BUCKET_RADIUS := 16.0

# -- Marker node references (editor-placed Node2D children) ---------------
var _station_markers: Dictionary = {}  # Station enum -> Node2D marker node
var _bucket_marker: Node2D = null

# -- Pipeline State -------------------------------------------------------
var _frames_on_pallet: Array = []          # Frames from opened super (max 10)
var _frames_scraped: int = 0               # Count of scraped frames on scraped pallet
var _scraped_super_ready: bool = false      # True when 10 frames fill a super box
var _super_box_on_scraped: bool = false     # True when empty super box placed on scraped pallet
var _frames_in_extractor: int = 0           # Frames loaded into extractor
var _bucket_honey_lbs: float = 0.0          # Raw honey in bucket
var _bucket_beeswax_lbs: float = 0.0        # Beeswax collected
var _jars_on_table: int = 0                 # Filled jars stacked on bottling table
var _active_station: Station = Station.NONE
var _supers_on_pallet: int = 0             # How many supers stacked (0-4)
# Bucket grip / carry state
# True = bucket is sitting at the yard waiting to be picked up.
# False = player picked it up (ITEM_HONEY_BUCKET in inventory) or bucket is empty.
var _bucket_at_yard: bool = false
var _bucket_on_bottling_table: bool = false  # True when bucket placed on bottling table

# -- Minigame overlays ----------------------------------------------------
var _scraping_overlay: Node = null
var _extractor_overlay: Node = null
var _bottling_overlay: Node = null
var _minigame_active: bool = false

# -- Interaction ----------------------------------------------------------
const INTERACT_DIST := 52.0

# -- Station visual nodes -------------------------------------------------
var _station_labels: Dictionary = {}        # Station -> Label
var _debug_overlay: Node2D = null           # High-z collision debug overlay

# -- Pallet sprite nodes --------------------------------------------------
var _super_pallet_sprite: Sprite2D = null
var _scraped_pallet_sprite: Sprite2D = null
const PALLET_TEXTURE_PATH := "res://assets/sprites/objects/pallet_super.png"

# -- Super box sprite nodes (sit on top of pallets) -----------------------
# Super pallet holds up to 4 full supers shown as individual sprites in 2x2 grid.
# Each sprite uses hive_super.png at 2x scale (24x14 -> 48x28 px).
var _pallet_super_sprites: Array = []           # Array of 4 Sprite2D for super pallet slots
var _scraped_box_sprite: Sprite2D = null        # On scraped pallet (empty draft super)
var _scraped_frame_overlay: Sprite2D = null    # Frame overlay on scraped box (shows fill)
const SUPER_BOX_TEXTURE_PATH := "res://assets/sprites/hive/hive_super.png"
const SCRAPED_BOX_TEXTURE_PATH := "res://assets/sprites/hive/super_empty_draft.png"
const SUPER_BOX_SCALE_PALLET := 2.0            # 24x14 -> 48x28 (4 fit in 2x2 grid on 96x64)
const SUPER_BOX_SCALE_SCRAPED := 2.0           # 24x14 -> 48x28 (same size as pallet supers)
# Frame overlay textures for scraped pallet (loaded at runtime)
var _scraped_frame_textures: Array = []        # Index 0 = one_frame ... 9 = ten_frames
# 2x2 slot offsets relative to pallet top-left corner (pixel coords).
# Sprite2D is centered, so each offset is the top-left of the slot.
const SUPER_SLOT_OFFSETS: Array = [
	Vector2(0, 4), Vector2(48, 4),    # row 0: top-left, top-right
	Vector2(0, 32), Vector2(48, 32),  # row 1: bottom-left, bottom-right
]

# -- Jarring / Bottling table sprite node ---------------------------------
var _bottling_sprite: Sprite2D = null
const BOTTLING_TABLE_TEXTURE_PATH := "res://assets/sprites/objects/jarring_table.png"

# -- Extractor sprite node ------------------------------------------------
var _extractor_sprite: Sprite2D = null
const EXTRACTOR_TEXTURE_PATH := "res://assets/sprites/objects/honey_spinner.png"

# -- Bucket sprite node (switches between full and empty texture) ---------
var _bucket_sprite: Sprite2D = null
var _bucket_tex_full: Texture2D = null
var _bucket_tex_empty: Texture2D = null
const BUCKET_FULL_PATH  := "res://assets/sprites/objects/honey_bucket.png"
const BUCKET_EMPTY_PATH := "res://assets/sprites/objects/honey_bucket_empty.png"

# =========================================================================
# LIFECYCLE
# =========================================================================
## Read positions from editor-placed child marker nodes into STATION_POS / BUCKET_OFFSET.
## Falls back to defaults if a marker node is missing.
func _read_station_positions() -> void:
	for station_id in STATION_NODE_NAMES.keys():
		var node_name: String = STATION_NODE_NAMES[station_id]
		var marker: Node2D = get_node_or_null(node_name) as Node2D
		if marker != null:
			STATION_POS[station_id] = marker.position
			_station_markers[station_id] = marker
	var bm: Node2D = get_node_or_null("HoneyBucket") as Node2D
	if bm != null:
		BUCKET_OFFSET = bm.position
		_bucket_marker = bm

## Helper: get the marker node for a station, or null.
func _get_marker(station: Station) -> Node2D:
	return _station_markers.get(station)

## Helper: add a child to the station marker if it exists, otherwise to self.
func _add_to_station(station: Station, child_node: Node) -> void:
	var marker: Node2D = _get_marker(station)
	if marker != null:
		marker.add_child(child_node)
	else:
		add_child(child_node)

## Initialize harvest yard with all station visuals and overlays.
func _ready() -> void:
	_read_station_positions()
	if Engine.is_editor_hint():
		# Editor: only read marker positions; _draw() handles outlines.
		queue_redraw()
		return
	add_to_group("harvest_yard")
	_create_station_visuals()
	_create_bucket_visual()
	_create_pallet_sprites()
	_create_super_box_sprites()
	_create_extractor_sprite()
	_create_bottling_sprite()
	_create_bucket_sprite()
	_create_debug_overlay()
	GameData.dev_labels_toggled.connect(_on_dev_labels_toggled)
	print("[HarvestYard] Outdoor harvest yard ready.")

## Per-frame update: editor marker tracking + runtime prompt overlay.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Track marker position changes so _draw() outlines follow drags.
		var changed: bool = false
		for station_id in _station_markers.keys():
			var marker: Node2D = _station_markers[station_id]
			if marker != null and STATION_POS[station_id] != marker.position:
				STATION_POS[station_id] = marker.position
				changed = true
		if _bucket_marker != null and BUCKET_OFFSET != _bucket_marker.position:
			BUCKET_OFFSET = _bucket_marker.position
			changed = true
		if changed:
			queue_redraw()
		return
	# -- Runtime: prompt label near player --
	if _minigame_active:
		if _prompt_label:
			_prompt_label.visible = false
		return
	var player: Node2D = _find_player()
	if player == null:
		return
	var prompt_text: String = get_nearby_prompt(player)
	if prompt_text != "":
		if _prompt_label == null:
			_prompt_label = Label.new()
			_prompt_label.add_theme_font_size_override("font_size", 5)
			_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40, 1.0))
			_prompt_label.z_index = 15
			add_child(_prompt_label)
		_prompt_label.text = prompt_text
		_prompt_label.visible = true
		_prompt_label.position = player.global_position - global_position + Vector2(-40, -24)
	else:
		if _prompt_label:
			_prompt_label.visible = false

## Create high-z overlay for collision debug that renders on top of everything.
func _create_debug_overlay() -> void:
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "CollisionDebugOverlay"
	_debug_overlay.z_index = 100
	_debug_overlay.z_as_relative = false
	_debug_overlay.set_script(load("res://scripts/debug/collision_debug_draw.gd"))
	_update_debug_overlay()
	add_child(_debug_overlay)
	_debug_overlay.visible = GameData.dev_labels_visible

## Update collision rects/circles on the debug overlay.
func _update_debug_overlay() -> void:
	if _debug_overlay == null:
		return
	var rects: Array = []
	for station_id in [Station.SUPER_PALLET, Station.SCRAPED_PALLET, Station.EXTRACTOR, Station.BOTTLING]:
		if STATION_POS.has(station_id) and STATION_SIZE.has(station_id):
			var pos: Vector2 = STATION_POS[station_id]
			var sz: Vector2 = STATION_SIZE[station_id]
			rects.append(Rect2(pos, sz))
	_debug_overlay.set_meta("rects", rects)
	_debug_overlay.set_meta("circles", [[BUCKET_OFFSET, BUCKET_RADIUS]])
	_debug_overlay.queue_redraw()

## Toggle debug overlay visibility when dev labels toggle.
func _on_dev_labels_toggled(vis: bool) -> void:
	if _debug_overlay:
		_debug_overlay.visible = vis
		_debug_overlay.queue_redraw()
	queue_redraw()

## Disconnect all signals when node exits the tree.
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _scraping_overlay:
		if _scraping_overlay.scraping_complete.is_connected(_on_scraping_complete):
			_scraping_overlay.scraping_complete.disconnect(_on_scraping_complete)
		if _scraping_overlay.scraping_cancelled.is_connected(_on_scraping_cancelled):
			_scraping_overlay.scraping_cancelled.disconnect(_on_scraping_cancelled)
	if _extractor_overlay:
		if _extractor_overlay.extraction_complete.is_connected(_on_extraction_complete):
			_extractor_overlay.extraction_complete.disconnect(_on_extraction_complete)
		if _extractor_overlay.extraction_cancelled.is_connected(_on_extraction_cancelled):
			_extractor_overlay.extraction_cancelled.disconnect(_on_extraction_cancelled)
	if _bottling_overlay:
		if _bottling_overlay.bottling_complete.is_connected(_on_bottling_complete):
			_bottling_overlay.bottling_complete.disconnect(_on_bottling_complete)
		if _bottling_overlay.bottling_cancelled.is_connected(_on_bottling_cancelled):
			_bottling_overlay.bottling_cancelled.disconnect(_on_bottling_cancelled)

# =========================================================================
# DRAWING -- Placeholder colored rectangles for each station
# =========================================================================
## Redraw all station visuals and overlays.
func _draw() -> void:
	if Engine.is_editor_hint():
		# In editor: draw faint outlines around all stations for layout visibility
		for sid in [Station.SUPER_PALLET, Station.SCRAPED_PALLET, Station.EXTRACTOR, Station.BOTTLING]:
			_draw_station_box(sid, Color(0.4, 0.3, 0.2, 0.25))
		# Bucket circle outline
		draw_circle(BUCKET_OFFSET, BUCKET_RADIUS, Color(0.4, 0.3, 0.2, 0.25))
		draw_arc(BUCKET_OFFSET, BUCKET_RADIUS, 0, TAU, 32, Color(0.25, 0.15, 0.05, 0.5), 1.5)
		return
	# Sprite2D nodes handle extractor, bucket, bottling table, and super boxes.
	_update_bucket_visual()
	_update_super_visuals()
	# Jars on bottling table
	if _jars_on_table > 0:
		_draw_jar_stacks()
	# Frame count text over super pallet
	if _supers_on_pallet > 0 and _frames_on_pallet.size() > 0:
		var sp: Vector2 = STATION_POS[Station.SUPER_PALLET]
		var ss: Vector2 = STATION_SIZE[Station.SUPER_PALLET]
		_draw_text_at(sp + Vector2(ss.x * 0.5, ss.y + 10),
			"%d frames" % _frames_on_pallet.size(), Color(0.9, 0.85, 0.6))
	# Frame count text over scraped pallet
	if _frames_scraped > 0:
		var fp: Vector2 = STATION_POS[Station.SCRAPED_PALLET]
		var fs: Vector2 = STATION_SIZE[Station.SCRAPED_PALLET]
		_draw_text_at(fp + Vector2(fs.x * 0.5, fs.y + 10),
			"%d/10 frames" % _frames_scraped, Color(0.9, 0.85, 0.6))
	# Collision debug is handled by the high-z _debug_overlay node

## Draw a colored rectangle for a station at its position and size.
func _draw_station_box(station: Station, color: Color) -> void:
	var pos: Vector2 = STATION_POS[station]
	var sz: Vector2 = STATION_SIZE[station]
	var rect := Rect2(pos, sz)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.25, 0.15, 0.05), false, 1.5)

## Draw stacked jars on the bottling table.
func _draw_jar_stacks() -> void:
	var bp: Vector2 = STATION_POS[Station.BOTTLING]
	var bs: Vector2 = STATION_SIZE[Station.BOTTLING]
	var jar_w: int = 6
	var jar_h: int = 8
	var jar_gap: int = 2
	var start_x: int = int(bp.x) + 4
	var start_y: int = int(bp.y) + int(bs.y) - jar_h - 4
	@warning_ignore("integer_division")
	for i in range(_jars_on_table):
		var stack: int = i / 5
		var in_stack: int = i % 5
		var jx: float = float(start_x + stack * (jar_w + 3))
		var jy: float = float(start_y - in_stack * (jar_h + jar_gap))
		draw_rect(Rect2(jx, jy, jar_w, jar_h), Color(0.95, 0.78, 0.25, 0.9), true)
		draw_rect(Rect2(jx, jy, jar_w, jar_h), Color(0.6, 0.5, 0.2), false, 0.5)

## Draw text at a specific position with the specified color.
func _draw_text_at(pos: Vector2, text: String, color: Color) -> void:
	# Simple text rendering using draw_string
	var font: Font = ThemeDB.fallback_font
	if font:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 5, color)

# =========================================================================
# PALLET SPRITES -- Load the wooden pallet art for the two pallet stations
# =========================================================================
## Create sprite nodes for both pallets.
func _create_pallet_sprites() -> void:
	var tex: Texture2D = null
	var abs_path: String = ProjectSettings.globalize_path(PALLET_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	if img != null:
		tex = ImageTexture.create_from_image(img)
	else:
		print("[HarvestYard] WARNING: pallet texture not found at ", PALLET_TEXTURE_PATH)

	var sp_size: Vector2 = STATION_SIZE[Station.SUPER_PALLET]   # 96x64
	var sc_size: Vector2 = STATION_SIZE[Station.SCRAPED_PALLET] # 96x64

	# Super Pallet sprite
	# Position at bottom edge of station for correct y-sort depth ordering.
	# Sprite visual is shifted up via offset so it still appears in the right place.
	_super_pallet_sprite = Sprite2D.new()
	_super_pallet_sprite.name = "SuperPalletSprite"
	if tex != null:
		_super_pallet_sprite.texture = tex
	# Local coords: marker is already at station position
	_super_pallet_sprite.position = Vector2(sp_size.x * 0.5, sp_size.y)
	_super_pallet_sprite.offset.y = -sp_size.y * 0.5
	_add_to_station(Station.SUPER_PALLET, _super_pallet_sprite)

	# Scraped Frame Pallet sprite (reuses same texture)
	_scraped_pallet_sprite = Sprite2D.new()
	_scraped_pallet_sprite.name = "ScrapedPalletSprite"
	if tex != null:
		_scraped_pallet_sprite.texture = tex
	# Local coords: marker is already at station position
	_scraped_pallet_sprite.position = Vector2(sc_size.x * 0.5, sc_size.y)
	_scraped_pallet_sprite.offset.y = -sc_size.y * 0.5
	_add_to_station(Station.SCRAPED_PALLET, _scraped_pallet_sprite)

# =========================================================================
# SUPER BOX SPRITES -- Show hive_super.png on pallets, tinted by fill level
# =========================================================================
## Create super box sprite nodes for both pallets.
func _create_super_box_sprites() -> void:
	var abs_path: String = ProjectSettings.globalize_path(SUPER_BOX_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	var tex: Texture2D = null
	if img != null:
		tex = ImageTexture.create_from_image(img)
	else:
		push_warning("[HarvestYard] Super box texture not found: " + SUPER_BOX_TEXTURE_PATH)

	# Local coords: super box sprites are children of the SuperPallet marker
	var half: Vector2 = Vector2(24.0, 14.0) * SUPER_BOX_SCALE_PALLET * 0.5

	# Create 4 individual super sprites in a 2x2 grid on the super pallet.
	_pallet_super_sprites.clear()
	for i in range(4):
		var slot_offset: Vector2 = SUPER_SLOT_OFFSETS[i]
		var sp := Sprite2D.new()
		sp.name = "PalletSuper%d" % i
		if tex != null:
			sp.texture = tex
		sp.scale = Vector2(SUPER_BOX_SCALE_PALLET, SUPER_BOX_SCALE_PALLET)
		# Local to marker -- no pallet_origin offset needed
		sp.position = slot_offset + half
		sp.visible = false
		_add_to_station(Station.SUPER_PALLET, sp)
		_pallet_super_sprites.append(sp)

	# Scraped pallet: empty draft super placed here, fills as frames are scraped
	var sc_size: Vector2 = STATION_SIZE[Station.SCRAPED_PALLET]
	_scraped_box_sprite = Sprite2D.new()
	_scraped_box_sprite.name = "ScrapedBoxSprite"
	# Load new draft super sprite (48x41 at native size)
	var draft_abs: String = ProjectSettings.globalize_path(SCRAPED_BOX_TEXTURE_PATH)
	var draft_img: Image = Image.load_from_file(draft_abs)
	if draft_img != null:
		_scraped_box_sprite.texture = ImageTexture.create_from_image(draft_img)
	elif tex != null:
		_scraped_box_sprite.texture = tex  # fallback to old super
	# Local to marker
	_scraped_box_sprite.position = sc_size * 0.5
	_scraped_box_sprite.visible = false
	_add_to_station(Station.SCRAPED_PALLET, _scraped_box_sprite)

	# Frame overlay sprite (sits inside the draft super cavity, shows fill progress)
	_scraped_frame_overlay = Sprite2D.new()
	_scraped_frame_overlay.name = "ScrapedFrameOverlay"
	_scraped_frame_overlay.position = sc_size * 0.5
	_scraped_frame_overlay.visible = false
	_scraped_frame_overlay.z_index = 1  # above the box sprite
	_add_to_station(Station.SCRAPED_PALLET, _scraped_frame_overlay)

	# Load frame overlay textures (one_frame through ten_frames)
	var frame_names: Array = [
		"one_frame", "two_frames", "three_frames", "four_frames",
		"five_frames", "sixFrames", "seven_frames", "eight_frames",
		"nine_frames", "ten_frames"
	]
	_scraped_frame_textures.clear()
	for fname in frame_names:
		var fpath: String = "res://assets/sprites/hive/%s.png" % fname
		var f_abs: String = ProjectSettings.globalize_path(fpath)
		var f_img: Image = Image.load_from_file(f_abs)
		if f_img != null:
			_scraped_frame_textures.append(ImageTexture.create_from_image(f_img))
		else:
			_scraped_frame_textures.append(null)

## Update super box sprite visibility and tint based on pipeline state.
## Super pallet shows one sprite per queued super (up to 4).
## Top super dims as frames are scraped out of it; others stay fully golden.
## Scraped pallet: starts pale, warms to golden as frames fill it.
## Update visibility and positions of super box sprites based on current state.
func _update_super_visuals() -> void:
	if _pallet_super_sprites.size() < 4 or _scraped_box_sprite == null:
		return

	# -- Super pallet: show one sprite per queued super --
	for i in range(4):
		var sp: Sprite2D = _pallet_super_sprites[i]
		if i < _supers_on_pallet:
			sp.visible = true
			if GameData.dev_labels_visible:
				# Dev mode: top super dims as frames are scraped; others honey-orange.
				if i == _supers_on_pallet - 1:
					var fill: float = clampf(float(_frames_on_pallet.size()) / 10.0, 0.0, 1.0)
					sp.modulate = Color(
						lerpf(0.65, 1.0, fill),
						lerpf(0.50, 0.85, fill),
						lerpf(0.30, 0.45, fill),
						1.0)
				else:
					sp.modulate = Color(1.0, 0.85, 0.42, 1.0)
			else:
				sp.modulate = Color(1.0, 1.0, 1.0, 1.0)  # always white for player
		else:
			sp.visible = false

	# -- Scraped pallet: show when empty super box is placed --
	_scraped_box_sprite.visible = _super_box_on_scraped
	if _scraped_frame_overlay != null:
		_scraped_frame_overlay.visible = _super_box_on_scraped and _frames_scraped > 0
	if _super_box_on_scraped:
		_scraped_box_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Update frame overlay to show current fill level
		if _scraped_frame_overlay != null and _frames_scraped > 0:
			var frame_idx: int = clampi(_frames_scraped - 1, 0, _scraped_frame_textures.size() - 1)
			if frame_idx < _scraped_frame_textures.size() and _scraped_frame_textures[frame_idx] != null:
				_scraped_frame_overlay.texture = _scraped_frame_textures[frame_idx]
				_scraped_frame_overlay.visible = true
			else:
				_scraped_frame_overlay.visible = false
		elif _scraped_frame_overlay != null:
			_scraped_frame_overlay.visible = false

# =========================================================================
# EXTRACTOR SPRITE -- Leonardo art replaces the placeholder circle
# =========================================================================
## Create the extractor sprite node.
func _create_extractor_sprite() -> void:
	var abs_path: String = ProjectSettings.globalize_path(EXTRACTOR_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	_extractor_sprite = Sprite2D.new()
	_extractor_sprite.name = "ExtractorSprite"
	if img != null:
		_extractor_sprite.texture = ImageTexture.create_from_image(img)
	else:
		push_warning("[HarvestYard] Extractor texture not found: " + EXTRACTOR_TEXTURE_PATH)
	# Sprite is 64x64 native -- matches the 64x64 station area, no scaling needed.
	# Local to marker -- position at bottom edge for y-sort depth ordering.
	var ext_size: Vector2 = STATION_SIZE[Station.EXTRACTOR]
	_extractor_sprite.position = Vector2(ext_size.x * 0.5, ext_size.y)
	_extractor_sprite.offset.y = -ext_size.y * 0.5
	_add_to_station(Station.EXTRACTOR, _extractor_sprite)

# =========================================================================
# BOTTLING TABLE SPRITE -- Jarring table Leonardo art
# =========================================================================
## Create the bottling / jarring table sprite node.
func _create_bottling_sprite() -> void:
	var abs_path: String = ProjectSettings.globalize_path(BOTTLING_TABLE_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	_bottling_sprite = Sprite2D.new()
	_bottling_sprite.name = "BottlingTableSprite"
	if img != null:
		_bottling_sprite.texture = ImageTexture.create_from_image(img)
	else:
		push_warning("[HarvestYard] Bottling table texture not found: " + BOTTLING_TABLE_TEXTURE_PATH)
	# Sprite is 96x72 -- fits the 96x80 station area without scaling.
	var btl_size: Vector2 = STATION_SIZE[Station.BOTTLING]
	# Local to marker -- position at bottom edge for y-sort depth ordering.
	_bottling_sprite.position = Vector2(btl_size.x * 0.5, btl_size.y)
	_bottling_sprite.offset.y = -btl_size.y * 0.5
	_add_to_station(Station.BOTTLING, _bottling_sprite)

# =========================================================================
# BUCKET SPRITE -- Preload full + empty textures, switch on state change
# =========================================================================
## Create the bucket sprite node and load textures.
func _create_bucket_sprite() -> void:
	# Preload both textures so we never reload from disk on state change
	var full_abs: String = ProjectSettings.globalize_path(BUCKET_FULL_PATH)
	var empty_abs: String = ProjectSettings.globalize_path(BUCKET_EMPTY_PATH)
	var img_full: Image = Image.load_from_file(full_abs)
	var img_empty: Image = Image.load_from_file(empty_abs)
	if img_full != null:
		_bucket_tex_full = ImageTexture.create_from_image(img_full)
	else:
		push_warning("[HarvestYard] Bucket full texture not found: " + BUCKET_FULL_PATH)
	if img_empty != null:
		_bucket_tex_empty = ImageTexture.create_from_image(img_empty)
	else:
		push_warning("[HarvestYard] Bucket empty texture not found: " + BUCKET_EMPTY_PATH)
	_bucket_sprite = Sprite2D.new()
	_bucket_sprite.name = "BucketSprite"
	_bucket_sprite.texture = _bucket_tex_empty
	_bucket_sprite.position = BUCKET_OFFSET
	_bucket_sprite.visible = true  # Show empty bucket at its spot
	add_child(_bucket_sprite)

## Update bucket sprite visibility, position, and texture to match pipeline state.
## Called from _draw() so it fires on every queue_redraw().
## Update bucket sprite texture based on whether it contains honey.
func _update_bucket_visual() -> void:
	if _bucket_sprite == null:
		return
	# Bucket is always visible at its resting spot (empty texture).
	# It moves to the bottling table when placed there, or hides only when
	# the player is physically carrying it (picked up into inventory).
	var player_carrying: bool = not _bucket_at_yard and not _bucket_on_bottling_table and _bucket_honey_lbs > 0.0
	_bucket_sprite.visible = not player_carrying
	if player_carrying:
		return
	# Move to bottling table when placed there, otherwise stay at yard spot
	if _bucket_on_bottling_table:
		var btp: Vector2 = STATION_POS[Station.BOTTLING]
		var bts: Vector2 = STATION_SIZE[Station.BOTTLING]
		_bucket_sprite.position = Vector2(btp.x + bts.x - 24.0, btp.y + bts.y * 0.5)
	else:
		_bucket_sprite.position = BUCKET_OFFSET
	# Full vs empty texture
	if _bucket_honey_lbs >= 1.0:
		if _bucket_tex_full != null:
			_bucket_sprite.texture = _bucket_tex_full
	else:
		if _bucket_tex_empty != null:
			_bucket_sprite.texture = _bucket_tex_empty

# =========================================================================
# STATION VISUALS -- Create labels and collision areas
# =========================================================================
## Create all station visual nodes with collision boxes and labels.
## Each station gets its own StaticBody2D + label parented under its marker.
func _create_station_visuals() -> void:
	_add_label(Station.SUPER_PALLET, "Super Pallet")
	_add_label(Station.SCRAPED_PALLET, "Scraped Frames")
	_add_label(Station.EXTRACTOR, "Honey Extractor")
	_add_label(Station.BOTTLING, "Bottling Table")

	# Create one collision body per station, parented under its marker
	for station_id in [Station.SUPER_PALLET, Station.SCRAPED_PALLET, Station.EXTRACTOR, Station.BOTTLING]:
		var sz: Vector2 = STATION_SIZE[station_id]
		var body := StaticBody2D.new()
		body.name = "Collision"
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = sz
		cs.shape = rs
		cs.position = sz * 0.5  # local center
		body.add_child(cs)
		_add_to_station(station_id, body)

## Add a label node for a station (parented under its marker).
func _add_label(station: Station, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
	# Local to marker
	lbl.position = Vector2(0, -10)
	lbl.z_index = 5
	_add_to_station(station, lbl)
	_station_labels[station] = lbl

## Create the bucket area and collision detection.
func _create_bucket_visual() -> void:
	# Bucket label parented under bucket marker
	var lbl := Label.new()
	lbl.text = "Honey Bucket"
	lbl.add_theme_font_size_override("font_size", 3)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6, 1.0))
	# Local to bucket marker
	lbl.position = Vector2(-20, BUCKET_RADIUS + 2)
	lbl.z_index = 5
	if _bucket_marker != null:
		_bucket_marker.add_child(lbl)
	else:
		add_child(lbl)

# =========================================================================
# INTERACTION -- Called by player._perform_action via group check
# =========================================================================

## Try to interact with the nearest station. Returns true if handled.
## Check if player can interact with harvest yard and process interaction.
func try_interact(player: Node2D) -> bool:
	if _minigame_active:
		return false
	var ppos: Vector2 = player.global_position
	var best_station: Station = Station.NONE
	var best_dist: float = 999.0

	# Check each station proximity
	for station_id in [Station.SUPER_PALLET, Station.SCRAPED_PALLET, Station.EXTRACTOR, Station.BOTTLING]:
		var s_pos: Vector2 = global_position + STATION_POS[station_id]
		var s_size: Vector2 = STATION_SIZE.get(station_id, Vector2(64, 64))
		var center: Vector2 = s_pos + s_size * 0.5
		var dist: float = ppos.distance_to(center)
		var threshold: float = INTERACT_DIST + s_size.length() * 0.3
		if dist < threshold and dist < best_dist:
			best_dist = dist
			best_station = station_id

	# Check bucket area for picking it up (requires ITEM_BUCKET_GRIP)
	var bucket_center: Vector2 = global_position + BUCKET_OFFSET
	var bucket_dist: float = ppos.distance_to(bucket_center)
	if _bucket_at_yard and bucket_dist < INTERACT_DIST:
		_active_station = Station.NONE
		_action_pick_up_bucket(player)
		return true

	if best_station == Station.NONE:
		return false

	_active_station = best_station
	_do_station_action(player)
	return true

## Get the prompt text for the nearest station (for player HUD display)
## Get the interaction prompt text for the nearby station.
func get_nearby_prompt(player: Node2D) -> String:
	if _minigame_active:
		return ""
	var ppos: Vector2 = player.global_position
	# Bucket prompt
	if _bucket_at_yard:
		var bucket_center: Vector2 = global_position + BUCKET_OFFSET
		if ppos.distance_to(bucket_center) < INTERACT_DIST:
			var held: String = _get_held_item(player)
			if held == GameData.ITEM_BUCKET_GRIP:
				return "[E] Pick up Honey Bucket (%.1f lbs)" % _bucket_honey_lbs
			return "Need Bucket Grip to carry"
	for station_id in [Station.SUPER_PALLET, Station.SCRAPED_PALLET, Station.EXTRACTOR, Station.BOTTLING]:
		var s_pos: Vector2 = global_position + STATION_POS[station_id]
		var s_size: Vector2 = STATION_SIZE.get(station_id, Vector2(64, 64))
		var center: Vector2 = s_pos + s_size * 0.5
		var dist: float = ppos.distance_to(center)
		var threshold: float = INTERACT_DIST + s_size.length() * 0.3
		if dist < threshold:
			return _get_prompt_text(station_id, player)
	return ""

## Get context-specific prompt text for a station based on current state.
func _get_prompt_text(station: Station, player: Node2D) -> String:
	match station:
		Station.SUPER_PALLET:
			if _frames_on_pallet.size() > 0:
				var held: String = ""
				if player.has_method("get_active_item_name"):
					held = player.get_active_item_name()
				if held == GameData.ITEM_COMB_SCRAPER:
					if not _super_box_on_scraped:
						return "Place Super Box on scraped pallet first!"
					return "[E] Scrape Frame (%d left)" % _frames_on_pallet.size()
				return "Equip Scraper to de-cap"
			if _supers_on_pallet >= 4:
				return "Pallet full (4 supers)"
			if player.has_method("count_item"):
				var count: int = player.count_item(GameData.ITEM_FULL_SUPER)
				if count > 0:
					return "[E] Place Super (%d/4 on pallet)" % _supers_on_pallet
			return "Bring a Full Super"
		Station.SCRAPED_PALLET:
			if _scraped_super_ready:
				return "[E] Take Scraped Super to Extractor"
			if _super_box_on_scraped:
				if _frames_scraped > 0:
					return "Super Box: %d/10 frames" % _frames_scraped
				return "Super Box ready - scrape frames to fill"
			# No super box placed yet -- prompt player to place one
			if player.has_method("get_active_item_name"):
				var held: String = player.get_active_item_name()
				if held == GameData.ITEM_SUPER_BOX:
					return "[E] Place Super Box on Pallet"
			if player.has_method("count_item"):
				var count: int = player.count_item(GameData.ITEM_SUPER_BOX)
				if count > 0:
					return "Select Super Box to place here"
			return "Need Super Box to receive frames"
		Station.EXTRACTOR:
			if _frames_in_extractor > 0:
				return "[E] Load Super + Start Extraction (%d frames)" % _frames_in_extractor
			if player.has_method("count_item") and player.call("count_item", GameData.ITEM_SCRAPED_SUPER) > 0:
				return "[E] Load Scraped Super into Extractor"
			if _scraped_super_ready:
				return "Pick up scraped super from pallet first"
			return "Scrape a super first"
		Station.BOTTLING:
			# Collect finished jars (bucket empty or gone)
			if _jars_on_table > 0 and not _bucket_on_bottling_table:
				return "[E] Collect Jars (%d)" % _jars_on_table
			# Bucket is on table -- need jars selected to start filling
			if _bucket_on_bottling_table:
				if _jars_on_table > 0 and _bucket_honey_lbs < 1.0:
					return "[E] Collect Jars (%d)" % _jars_on_table
				var held_b: String = _get_held_item(player)
				if held_b == GameData.ITEM_JAR:
					return "[E] Start Jarring (%.1f lbs honey)" % _bucket_honey_lbs
				return "Select Empty Jars to start"
			# Bucket not placed yet -- need to carry it here
			if _bucket_honey_lbs >= 1.0:
				var held_b: String = _get_held_item(player)
				var has_bkt: bool = player.has_method("count_item") and player.call("count_item", GameData.ITEM_HONEY_BUCKET) > 0
				if held_b == GameData.ITEM_HONEY_BUCKET or held_b == GameData.ITEM_BUCKET_GRIP or has_bkt:
					return "[E] Place Bucket (%.1f lbs)" % _bucket_honey_lbs
				return "Carry honey bucket here first"
			if _jars_on_table > 0:
				return "[E] Collect Jars (%d)" % _jars_on_table
			return "No honey to bottle"
	return ""

# =========================================================================
# STATION ACTIONS
# =========================================================================
## Execute the action for the current active station.
func _do_station_action(player: Node2D) -> void:
	match _active_station:
		Station.SUPER_PALLET:
			_action_super_pallet(player)
		Station.SCRAPED_PALLET:
			_action_scraped_pallet(player)
		Station.EXTRACTOR:
			_action_extractor(player)
		Station.BOTTLING:
			_action_bottling(player)

# -- Super Pallet: place super or start scraping --------------------------
## Handle player interaction with the super pallet station.
func _action_super_pallet(player: Node2D) -> void:
	# If frames already on pallet, check for scraper to start minigame
	if _frames_on_pallet.size() > 0:
		var held: String = ""
		if player.has_method("get_active_item_name"):
			held = player.get_active_item_name()
		if held == GameData.ITEM_COMB_SCRAPER:
			_start_scraping_minigame()
		else:
			_notify("Equip the Comb Scraper to de-cap frames!")
		return

	# Limit pallet to 4 supers
	if _supers_on_pallet >= 4:
		_notify("Pallet is full! Process some supers first.")
		return

	# Place a full super on the pallet
	if not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_FULL_SUPER, 1):
		_notify("No full super in inventory!")
		return
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

	# Generate 10 frames from the super using actual hive cell data.
	# Append to existing frames so multiple supers queue up.
	var stored: Array = GameData.harvested_super_frames
	for i in 10:
		var sf: ScrapeFrame = ScrapeFrame.new()
		if i < stored.size():
			sf.fill_from_hive_data(stored[i]["cells_a"], stored[i]["cells_b"])
		else:
			sf.fill_for_harvest(100.0)  # fallback: assume fully capped
		_frames_on_pallet.append({
			"frame_idx": i,
			"honey_lbs": 4.0,
			"capping_pct": 100.0,
			"scrap_frame": sf,
		})
	# Consume stored data so it is not reused for a different super
	GameData.harvested_super_frames.clear()
	_supers_on_pallet += 1

	# Return the empty super box to inventory
	if player.has_method("add_item"):
		player.add_item(GameData.ITEM_SUPER_BOX, 1)
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()

	_notify("Super placed! %d/4 on pallet. Equip Scraper to de-cap." % _supers_on_pallet)
	queue_redraw()

# -- Scraping Minigame Launch ---------------------------------------------
## Start the scraping minigame overlay.
func _start_scraping_minigame() -> void:
	if _frames_on_pallet.size() == 0:
		return
	_minigame_active = true

	# Deduct energy for scraping
	if not GameData.deduct_energy(2.0):
		_notify("Too tired to scrape!")
		_minigame_active = false
		return

	# Create the scraping overlay
	var overlay_script: GDScript = load("res://scripts/ui/scraping_minigame.gd")
	_scraping_overlay = CanvasLayer.new()
	_scraping_overlay.layer = 20
	_scraping_overlay.name = "ScrapingOverlay"
	_scraping_overlay.set_script(overlay_script)

	# Pass actual frame cell data so de-capping matches inspection view
	var frame_data_d: Dictionary = _frames_on_pallet[0]
	var sf: Object = frame_data_d.get("scrap_frame", null)
	_scraping_overlay.set("frame", sf)
	var total_frames: int = _supers_on_pallet * 10
	_scraping_overlay.set("frame_index", total_frames - _frames_on_pallet.size() + 1)
	_scraping_overlay.set("frame_total", total_frames)

	add_child(_scraping_overlay)
	_scraping_overlay.add_to_group("inspection_overlay")

	# Connect completion signal
	if _scraping_overlay.has_signal("scraping_complete"):
		_scraping_overlay.scraping_complete.connect(_on_scraping_complete)
	if _scraping_overlay.has_signal("scraping_cancelled"):
		_scraping_overlay.scraping_cancelled.connect(_on_scraping_cancelled)

## Handle scraping minigame completion and frame processing.
func _on_scraping_complete() -> void:
	_minigame_active = false
	if _scraping_overlay:
		_scraping_overlay.queue_free()
		_scraping_overlay = null

	# Check if there's a super box on the scraped pallet to receive frames
	if not _super_box_on_scraped:
		_notify("Place an empty Super Box on the scraped pallet first!")
		queue_redraw()
		return

	var wax_per_frame: float = 4900.0 * 0.00015  # ~0.735 lbs per frame

	# DevMode: auto-scrape all remaining frames in one shot (up to fill the super box)
	if GameData.dev_labels_visible and _frames_on_pallet.size() > 0:
		var max_to_scrape: int = mini(_frames_on_pallet.size(), 10 - _frames_scraped)
		for _fi in range(max_to_scrape):
			if _frames_on_pallet.size() > 0:
				_frames_on_pallet.remove_at(0)
				_bucket_beeswax_lbs += wax_per_frame
				_frames_scraped += 1
		if _frames_scraped >= 10:
			_scraped_super_ready = true
		_supers_on_pallet = _frames_on_pallet.size() / 10 if _frames_on_pallet.size() >= 10 else (0 if _frames_on_pallet.size() == 0 else 1)
		_notify("[DevMode] All frames auto-scraped! Super ready for extractor.")
		_try_give_beeswax()
		queue_redraw()
		return

	# Normal: Remove the single scraped frame from pallet
	if _frames_on_pallet.size() > 0:
		_frames_on_pallet.remove_at(0)
		_bucket_beeswax_lbs += wax_per_frame
		_frames_scraped += 1

		if _frames_scraped >= 10:
			_scraped_super_ready = true
			_notify("All 10 frames scraped! Take super to extractor.")
		else:
			_notify("Frame scraped! Wax: %.2f lbs. %d/%d done." % [
				wax_per_frame, _frames_scraped, _frames_scraped + _frames_on_pallet.size()])

	if _frames_on_pallet.size() == 0:
		_supers_on_pallet = maxi(0, _supers_on_pallet - 1)
	elif _frames_on_pallet.size() % 10 == 0 and _supers_on_pallet > 0:
		@warning_ignore("integer_division")
		_supers_on_pallet = _frames_on_pallet.size() / 10

	# Add accumulated beeswax to player
	_try_give_beeswax()
	queue_redraw()

## Handle scraping minigame cancellation by the player.
func _on_scraping_cancelled() -> void:
	_minigame_active = false
	if _scraping_overlay:
		_scraping_overlay.queue_free()
		_scraping_overlay = null

# -- Scraped Frame Pallet: place super box or pick up completed super -----
## Handle player interaction with the scraped pallet station.
func _action_scraped_pallet(player: Node2D) -> void:
	# Pick up completed scraped super -> give to player as ITEM_SCRAPED_SUPER
	if _scraped_super_ready:
		if player.has_method("add_item"):
			var overflow: int = player.add_item(GameData.ITEM_SCRAPED_SUPER, 1)
			if overflow > 0:
				_notify("Inventory full! Can't pick up scraped super.")
				return
		_frames_in_extractor = _frames_scraped
		_frames_scraped = 0
		_scraped_super_ready = false
		_super_box_on_scraped = false
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
		_notify("Scraped super in hand! Take it to the extractor.")
		queue_redraw()
		return

	# If no super box placed yet, try to place one from inventory
	if not _super_box_on_scraped:
		var held: String = ""
		if player.has_method("get_active_item_name"):
			held = player.get_active_item_name()
		if held == GameData.ITEM_SUPER_BOX:
			if player.has_method("consume_item") and player.consume_item(GameData.ITEM_SUPER_BOX, 1):
				_super_box_on_scraped = true
				if player.has_method("update_hud_inventory"):
					player.update_hud_inventory()
				_notify("Super box placed! Scrape frames to fill it.")
				queue_redraw()
				return
		# Not holding a super box
		_notify("Select an empty Super Box and place it here to receive frames.")
		return

	# Super box is placed but not full yet
	if _frames_scraped > 0:
		_notify("Still scraping... %d/10 frames in the super box." % _frames_scraped)
	else:
		_notify("Super box is ready. Scrape frames at the other pallet.")

# -- Extractor: player must carry ITEM_SCRAPED_SUPER and drop it in -------
## Handle player interaction with the extractor station.
func _action_extractor(player: Node2D) -> void:
	# If frames already loaded (from this carry action), run the minigame
	if _frames_in_extractor > 0:
		_start_extractor_minigame(player)
		return

	# Player must be holding a scraped super to load the extractor
	if not player.has_method("consume_item"):
		return
	if not player.consume_item(GameData.ITEM_SCRAPED_SUPER, 1):
		if _scraped_super_ready:
			_notify("Pick up the scraped super from the pallet first!")
		else:
			_notify("No scraped super in hand! Scrape frames first.")
		return

	# Consume scraped super and immediately return the empty box
	if player.has_method("add_item"):
		player.add_item(GameData.ITEM_SUPER_BOX, 1)
	if player.has_method("update_hud_inventory"):
		player.update_hud_inventory()

	# _frames_in_extractor was already set when the player picked up from pallet
	_notify("Scraped super loaded! Empty box returned to inventory.")
	_start_extractor_minigame(player)

@warning_ignore("unused_parameter")
## Start the extractor minigame with honey extraction gauge.
func _start_extractor_minigame(player: Node2D) -> void:
	_minigame_active = true

	# Deduct energy
	var energy_cost: float = float(_frames_in_extractor) * 1.5
	if not GameData.deduct_energy(energy_cost):
		_notify("Too tired to run the extractor!")
		_minigame_active = false
		return

	var overlay_script: GDScript = load("res://scripts/ui/extractor_minigame.gd")
	_extractor_overlay = CanvasLayer.new()
	_extractor_overlay.layer = 20
	_extractor_overlay.name = "ExtractorOverlay"
	_extractor_overlay.set_script(overlay_script)
	add_child(_extractor_overlay)
	_extractor_overlay.add_to_group("inspection_overlay")

	if _extractor_overlay.has_signal("extraction_complete"):
		_extractor_overlay.extraction_complete.connect(_on_extraction_complete)
	if _extractor_overlay.has_signal("extraction_cancelled"):
		_extractor_overlay.extraction_cancelled.connect(_on_extraction_cancelled)

## Handle extractor minigame completion and honey collection.
func _on_extraction_complete() -> void:
	_minigame_active = false
	if _extractor_overlay:
		_extractor_overlay.queue_free()
		_extractor_overlay = null

	# Calculate honey yield (4 lbs per frame)
	var total_honey: float = float(_frames_in_extractor) * 4.0
	_bucket_honey_lbs += total_honey

	# Return empty frames to player (they were inside the scraped super)
	var frames_back: int = _frames_in_extractor
	_frames_in_extractor = 0

	# Bucket is now full -- player must pick it up with the bucket grip
	_bucket_at_yard = true

	var player: Node2D = _find_player()
	if player and player.has_method("add_item"):
		player.add_item(GameData.ITEM_FRAMES, frames_back)
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()

	_notify("Extracted! %.1f lbs in bucket. Got %d frames back. Use Bucket Grip!" % [_bucket_honey_lbs, frames_back])
	GameData.add_xp(GameData.XP_HARVEST)
	QuestManager.notify_event("harvest_complete", {"lbs": _bucket_honey_lbs})
	queue_redraw()

## Handle extractor minigame cancellation by the player.
func _on_extraction_cancelled() -> void:
	_minigame_active = false
	if _extractor_overlay:
		_extractor_overlay.queue_free()
		_extractor_overlay = null

# -- Bottling Table: fill jars or collect filled jars ---------------------
## Handle player interaction with the bottling table station.
func _action_bottling(player: Node2D) -> void:
	# -- Collect finished jars (bucket done or removed) -----------------------
	if _jars_on_table > 0 and not _bucket_on_bottling_table:
		_collect_jars(player)
		return

	# -- Bucket is on table: start jarring if jars selected -------------------
	if _bucket_on_bottling_table:
		# Collect jars when honey is exhausted
		if _jars_on_table > 0 and _bucket_honey_lbs < 1.0:
			_collect_jars(player)
			return
		# Check if player has empty jars selected (active slot)
		var held: String = _get_held_item(player)
		# If player is NOT holding empty jars but there are filled jars,
		# let them collect the filled jars (e.g. holding bucket grip or any other item)
		if held != GameData.ITEM_JAR:
			if _jars_on_table > 0:
				_collect_jars(player)
				return
			_notify("Select Empty Jars in your inventory, then press [E].")
			return
		_start_bottling_minigame(player)
		return

	# -- Bucket not on table yet: place it ------------------------------------
	if _bucket_honey_lbs >= 1.0:
		var held: String = _get_held_item(player)
		var has_bkt: bool = player.has_method("count_item") and player.call("count_item", GameData.ITEM_HONEY_BUCKET) > 0
		if held != GameData.ITEM_HONEY_BUCKET and held != GameData.ITEM_BUCKET_GRIP and not has_bkt:
			_notify("Carry the honey bucket here with your Bucket Grip first!")
			return
		# Consume the carried bucket item from inventory
		if player.has_method("consume_item"):
			player.consume_item(GameData.ITEM_HONEY_BUCKET, 1)
			if player.has_method("update_hud_inventory"):
				player.update_hud_inventory()
		_bucket_at_yard = false
		_bucket_on_bottling_table = true
		queue_redraw()
		_notify("Bucket placed! Select Empty Jars and press [E] to start jarring.")
		return

	# -- Collect leftover jars ------------------------------------------------
	if _jars_on_table > 0:
		_collect_jars(player)
		return

	_notify("No honey to bottle! Extract honey first.")

## Collect filled jars from the bottling table into player inventory.
func _collect_jars(player: Node2D) -> void:
	if _jars_on_table <= 0:
		return
	var to_collect: int = _jars_on_table
	if player.has_method("add_item"):
		var remaining: int = player.add_item(GameData.ITEM_HONEY_JAR, to_collect)
		var collected: int = to_collect - remaining
		_jars_on_table -= collected
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
		if remaining > 0:
			_notify("Collected %d jars! %d left (inventory full)." % [collected, remaining])
		else:
			_notify("Collected %d honey jars! Sell at the market." % collected)
	# Only remove bucket from table if jars are all collected AND bucket is empty
	if _jars_on_table <= 0 and _bucket_honey_lbs < 1.0:
		_bucket_on_bottling_table = false
	queue_redraw()

## Start the bottling minigame with jar filling.
func _start_bottling_minigame(player: Node2D) -> void:
	# Check for empty jars in inventory
	var jar_count: int = 0
	if player.has_method("count_item"):
		jar_count = player.count_item(GameData.ITEM_JAR)
	if jar_count <= 0:
		_notify("No empty jars! Buy some from Feed & Supply.")
		return

	_minigame_active = true

	var honey_available: float = _bucket_honey_lbs
	var jars_to_use: int = mini(jar_count, int(honey_available))
	jars_to_use = mini(jars_to_use, 40)  # 40 jar max per session

	# Consume jars from player inventory upfront
	if player.has_method("consume_item"):
		player.consume_item(GameData.ITEM_JAR, jars_to_use)
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()

	# DevMode: skip the bottling minigame, instantly fill all jars
	if GameData.dev_labels_visible:
		_minigame_active = false
		_notify("[DevMode] All %d jars filled instantly!" % jars_to_use)
		_on_bottling_complete(jars_to_use)
		return

	var overlay_script: GDScript = load("res://scripts/ui/bottling_minigame.gd")
	_bottling_overlay = CanvasLayer.new()
	_bottling_overlay.layer = 20
	_bottling_overlay.name = "BottlingOverlay"
	_bottling_overlay.set_script(overlay_script)
	# Pass data to overlay before adding to tree
	_bottling_overlay.set_meta("honey_available", honey_available)
	_bottling_overlay.set_meta("jars_available", jars_to_use)
	add_child(_bottling_overlay)
	_bottling_overlay.add_to_group("inspection_overlay")

	if _bottling_overlay.has_signal("bottling_complete"):
		_bottling_overlay.bottling_complete.connect(_on_bottling_complete)
	if _bottling_overlay.has_signal("bottling_cancelled"):
		_bottling_overlay.bottling_cancelled.connect(_on_bottling_cancelled)

## Handle bottling minigame completion and jar filling.
func _on_bottling_complete(jars_filled: int) -> void:
	_minigame_active = false
	if _bottling_overlay:
		_bottling_overlay.queue_free()
		_bottling_overlay = null

	_bucket_honey_lbs -= float(jars_filled)
	_bucket_honey_lbs = maxf(0.0, _bucket_honey_lbs)
	_jars_on_table += jars_filled

	_notify("%d jars filled! Collect from table to sell." % jars_filled)
	queue_redraw()

## Handle bottling minigame cancellation, returning unused jars.
func _on_bottling_cancelled(jars_filled: int, jars_unused: int) -> void:
	_minigame_active = false
	if _bottling_overlay:
		_bottling_overlay.queue_free()
		_bottling_overlay = null

	# Return unused jars to player
	if jars_unused > 0:
		var player: Node2D = _find_player()
		if player and player.has_method("add_item"):
			player.add_item(GameData.ITEM_JAR, jars_unused)
			if player.has_method("update_hud_inventory"):
				player.update_hud_inventory()

	if jars_filled > 0:
		_bucket_honey_lbs -= float(jars_filled)
		_bucket_honey_lbs = maxf(0.0, _bucket_honey_lbs)
		_jars_on_table += jars_filled

	queue_redraw()

# =========================================================================
# BUCKET GRIP ACTION
# =========================================================================
## Player picks up the full bucket and adds it to inventory.
func _action_pick_up_bucket(player: Node2D) -> void:
	if not _bucket_at_yard or _bucket_honey_lbs < 1.0:
		_notify("The bucket is empty -- nothing to carry.")
		return
	var held: String = _get_held_item(player)
	if held != GameData.ITEM_BUCKET_GRIP:
		_notify("Equip your Bucket Grip to carry the honey bucket!")
		return
	# Check carry space
	if player.has_method("count_item"):
		if player.count_item(GameData.ITEM_HONEY_BUCKET) >= 1:
			_notify("You are already carrying a honey bucket!")
			return
	# Give player the full bucket as a carry item
	if player.has_method("add_item"):
		var overflow: int = player.add_item(GameData.ITEM_HONEY_BUCKET, 1)
		if overflow > 0:
			_notify("No room in inventory for the bucket!")
			return
		if player.has_method("update_hud_inventory"):
			player.update_hud_inventory()
	_bucket_at_yard = false
	queue_redraw()
	_notify("Bucket picked up! Carry it to the Bottling Table.")

# =========================================================================
# HELPERS
# =========================================================================
## Get the name of the item the player is currently holding.
func _get_held_item(player: Node2D) -> String:
	if player.has_method("get_active_item_name"):
		return player.get_active_item_name()
	return ""

## Find the player node in the scene.
func _find_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

## Send a notification message to the NotificationManager.
func _notify(msg: String) -> void:
	var nm: Node = get_tree().root.get_node_or_null("NotificationManager")
	if nm and nm.has_method("notify"):
		nm.notify(msg)

## Attempt to give collected beeswax to the player.
func _try_give_beeswax() -> void:
	if _bucket_beeswax_lbs < 1.0:
		GameData.beeswax_fractional += _bucket_beeswax_lbs
		GameData.beeswax_lifetime += _bucket_beeswax_lbs
	else:
		var whole_lbs: int = int(_bucket_beeswax_lbs)
		var player: Node2D = _find_player()
		if player and player.has_method("add_item"):
			player.add_item(GameData.ITEM_BEESWAX, whole_lbs)
			if player.has_method("update_hud_inventory"):
				player.update_hud_inventory()
		GameData.beeswax_fractional += _bucket_beeswax_lbs - float(whole_lbs)
		GameData.beeswax_lifetime += _bucket_beeswax_lbs
	_bucket_beeswax_lbs = 0.0

	# Check if fractional beeswax has accumulated to a full pound
	if GameData.beeswax_fractional >= 1.0:
		var extra: int = int(GameData.beeswax_fractional)
		var player: Node2D = _find_player()
		if player and player.has_method("add_item"):
			player.add_item(GameData.ITEM_BEESWAX, extra)
		GameData.beeswax_fractional -= float(extra)

# -- Prompt overlay (floating text near stations) -------------------------
var _prompt_label: Label = null
