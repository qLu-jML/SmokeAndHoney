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
# Layout based on Nathan's mockup: stations right of house, south area
const STATION_POS := {
	Station.SUPER_PALLET:   Vector2(0, 0),
	Station.SCRAPING:       Vector2(0, 0),       # Same as super pallet (scrape at the pallet)
	Station.SCRAPED_PALLET: Vector2(140, 0),
	Station.EXTRACTOR:      Vector2(260, -40),
	Station.BOTTLING:       Vector2(260, 120),
}

# Station collision/draw sizes (pixels)
const STATION_SIZE := {
	Station.SUPER_PALLET:   Vector2(96, 64),
	Station.SCRAPED_PALLET: Vector2(96, 64),
	Station.EXTRACTOR:      Vector2(64, 64),
	Station.BOTTLING:       Vector2(96, 80),
}

# Bucket sits between extractor and bottling table
const BUCKET_OFFSET := Vector2(260, 50)
const BUCKET_RADIUS := 16.0

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

# -- Pallet sprite nodes --------------------------------------------------
var _super_pallet_sprite: Sprite2D = null
var _scraped_pallet_sprite: Sprite2D = null
const PALLET_TEXTURE_PATH := "res://assets/sprites/objects/pallet_super.png"

# -- Super box sprite nodes (sit on top of pallets) -----------------------
# Super pallet holds up to 4 full supers shown as individual sprites in 2x2 grid.
# Each sprite uses hive_super.png at 2x scale (24x14 -> 48x28 px).
var _pallet_super_sprites: Array = []           # Array of 4 Sprite2D for super pallet slots
var _scraped_box_sprite: Sprite2D = null        # On scraped pallet (fills as scraped)
const SUPER_BOX_TEXTURE_PATH := "res://assets/sprites/hive/hive_super.png"
const SUPER_BOX_SCALE_PALLET := 2.0            # 24x14 -> 48x28 (4 fit in 2x2 grid on 96x64)
const SUPER_BOX_SCALE_SCRAPED := 4.0           # 24x14 -> 96x56 (one super fills scraped pallet)
# 2x2 slot offsets relative to pallet top-left corner (pixel coords).
# Sprite2D is centered, so each offset is the top-left of the slot.
const SUPER_SLOT_OFFSETS: Array = [
	Vector2(0, 4), Vector2(48, 4),    # row 0: top-left, top-right
	Vector2(0, 32), Vector2(48, 32),  # row 1: bottom-left, bottom-right
]

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
func _ready() -> void:
	add_to_group("harvest_yard")
	_create_station_visuals()
	_create_bucket_visual()
	_create_pallet_sprites()
	_create_super_box_sprites()
	_create_extractor_sprite()
	_create_bucket_sprite()
	print("[HarvestYard] Outdoor harvest yard ready.")

# =========================================================================
# DRAWING -- Placeholder colored rectangles for each station
# =========================================================================
func _draw() -> void:
	# Sprite2D nodes handle extractor, bucket, and super boxes -- just update state.
	_update_bucket_visual()
	_update_super_visuals()
	# Bottling Table - warm wood placeholder (Leonardo asset pending)
	_draw_station_box(Station.BOTTLING, Color(0.60, 0.42, 0.25, 1.0))
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

func _draw_station_box(station: Station, color: Color) -> void:
	var pos: Vector2 = STATION_POS[station]
	var sz: Vector2 = STATION_SIZE[station]
	var rect := Rect2(pos, sz)
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.25, 0.15, 0.05), false, 1.5)

func _draw_jar_stacks() -> void:
	var bp: Vector2 = STATION_POS[Station.BOTTLING]
	var bs: Vector2 = STATION_SIZE[Station.BOTTLING]
	var jar_w := 6
	var jar_h := 8
	var jar_gap := 2
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

func _draw_text_at(pos: Vector2, text: String, color: Color) -> void:
	# Simple text rendering using draw_string
	var font: Font = ThemeDB.fallback_font
	if font:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 5, color)

# =========================================================================
# PALLET SPRITES -- Load the wooden pallet art for the two pallet stations
# =========================================================================
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
	_super_pallet_sprite = Sprite2D.new()
	_super_pallet_sprite.name = "SuperPalletSprite"
	if tex != null:
		_super_pallet_sprite.texture = tex
	# Sprite origin is center; offset to align top-left corner with station pos
	_super_pallet_sprite.position = STATION_POS[Station.SUPER_PALLET] + sp_size * 0.5
	_super_pallet_sprite.z_index = 3
	add_child(_super_pallet_sprite)

	# Scraped Frame Pallet sprite (reuses same texture)
	_scraped_pallet_sprite = Sprite2D.new()
	_scraped_pallet_sprite.name = "ScrapedPalletSprite"
	if tex != null:
		_scraped_pallet_sprite.texture = tex
	_scraped_pallet_sprite.position = STATION_POS[Station.SCRAPED_PALLET] + sc_size * 0.5
	_scraped_pallet_sprite.z_index = 3
	add_child(_scraped_pallet_sprite)

# =========================================================================
# SUPER BOX SPRITES -- Show hive_super.png on pallets, tinted by fill level
# =========================================================================
func _create_super_box_sprites() -> void:
	var abs_path: String = ProjectSettings.globalize_path(SUPER_BOX_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	var tex: Texture2D = null
	if img != null:
		tex = ImageTexture.create_from_image(img)
	else:
		push_warning("[HarvestYard] Super box texture not found: " + SUPER_BOX_TEXTURE_PATH)

	var pallet_origin: Vector2 = STATION_POS[Station.SUPER_PALLET]
	# Half the size of one super at SUPER_BOX_SCALE_PALLET for centering (24/2*2, 14/2*2)
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
		# Top-left of slot -> center for Sprite2D (which is centered by default)
		sp.position = pallet_origin + slot_offset + half
		sp.z_index = 4
		sp.visible = false
		add_child(sp)
		_pallet_super_sprites.append(sp)

	# Scraped pallet: empty super box placed here, fills as frames are scraped
	var sc_size: Vector2 = STATION_SIZE[Station.SCRAPED_PALLET]
	_scraped_box_sprite = Sprite2D.new()
	_scraped_box_sprite.name = "ScrapedBoxSprite"
	if tex != null:
		_scraped_box_sprite.texture = tex
	_scraped_box_sprite.scale = Vector2(SUPER_BOX_SCALE_SCRAPED, SUPER_BOX_SCALE_SCRAPED)
	_scraped_box_sprite.position = STATION_POS[Station.SCRAPED_PALLET] + sc_size * 0.5 + Vector2(0, -4)
	_scraped_box_sprite.z_index = 4
	_scraped_box_sprite.visible = false
	add_child(_scraped_box_sprite)

## Update super box sprite visibility and tint based on pipeline state.
## Super pallet shows one sprite per queued super (up to 4).
## Top super dims as frames are scraped out of it; others stay fully golden.
## Scraped pallet: starts pale, warms to golden as frames fill it.
func _update_super_visuals() -> void:
	if _pallet_super_sprites.size() < 4 or _scraped_box_sprite == null:
		return

	# -- Super pallet: show one sprite per queued super, top super dims --
	for i in range(4):
		var sp: Sprite2D = _pallet_super_sprites[i]
		if i < _supers_on_pallet:
			sp.visible = true
			# The topmost queued super (highest index) is the one being scraped.
			# Dim it based on remaining frames; others stay fully golden.
			if i == _supers_on_pallet - 1:
				var fill: float = clampf(float(_frames_on_pallet.size()) / 10.0, 0.0, 1.0)
				sp.modulate = Color(
					lerpf(0.65, 1.0, fill),
					lerpf(0.50, 0.85, fill),
					lerpf(0.30, 0.45, fill),
					1.0)
			else:
				sp.modulate = Color(1.0, 0.85, 0.42, 1.0)  # fully golden
		else:
			sp.visible = false

	# -- Scraped pallet: show when empty super box is placed --
	_scraped_box_sprite.visible = _super_box_on_scraped
	if _super_box_on_scraped:
		# Pale/empty when no frames, warms to golden as it fills
		var fill: float = clampf(float(_frames_scraped) / 10.0, 0.0, 1.0)
		_scraped_box_sprite.modulate = Color(
			lerpf(0.65, 1.0, fill),
			lerpf(0.50, 0.85, fill),
			lerpf(0.30, 0.45, fill),
			1.0)

# =========================================================================
# EXTRACTOR SPRITE -- Leonardo art replaces the placeholder circle
# =========================================================================
func _create_extractor_sprite() -> void:
	var abs_path: String = ProjectSettings.globalize_path(EXTRACTOR_TEXTURE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	_extractor_sprite = Sprite2D.new()
	_extractor_sprite.name = "ExtractorSprite"
	if img != null:
		_extractor_sprite.texture = ImageTexture.create_from_image(img)
	else:
		push_warning("[HarvestYard] Extractor texture not found: " + EXTRACTOR_TEXTURE_PATH)
	# Scale down to fit 64x64 station area (sprite is 128x96 natural)
	_extractor_sprite.scale = Vector2(0.5, 0.5)
	# Center sprite at the extractor station center
	var ext_pos: Vector2 = STATION_POS[Station.EXTRACTOR]
	var ext_size: Vector2 = STATION_SIZE[Station.EXTRACTOR]
	_extractor_sprite.position = ext_pos + ext_size * 0.5
	_extractor_sprite.z_index = 3
	add_child(_extractor_sprite)

# =========================================================================
# BUCKET SPRITE -- Preload full + empty textures, switch on state change
# =========================================================================
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
	_bucket_sprite.z_index = 4
	_bucket_sprite.visible = false
	add_child(_bucket_sprite)

## Update bucket sprite visibility, position, and texture to match pipeline state.
## Called from _draw() so it fires on every queue_redraw().
func _update_bucket_visual() -> void:
	if _bucket_sprite == null:
		return
	var bucket_visible: bool = _bucket_at_yard or _bucket_on_bottling_table
	_bucket_sprite.visible = bucket_visible
	if not bucket_visible:
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
func _create_station_visuals() -> void:
	_add_label(Station.SUPER_PALLET, "Super Pallet")
	_add_label(Station.SCRAPED_PALLET, "Scraped Frames")
	_add_label(Station.EXTRACTOR, "Honey Extractor")
	_add_label(Station.BOTTLING, "Bottling Table")

	# Create collision bodies so player walks around stations
	var body := StaticBody2D.new()
	body.name = "StationCollisions"
	add_child(body)
	_add_collision_rect(body, Station.SUPER_PALLET)
	_add_collision_rect(body, Station.SCRAPED_PALLET)
	_add_collision_rect(body, Station.BOTTLING)
	# Extractor is circular but we approximate with a rect
	var ext_pos: Vector2 = STATION_POS[Station.EXTRACTOR]
	var ext_size: Vector2 = STATION_SIZE[Station.EXTRACTOR]
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = ext_size
	cs.shape = rs
	cs.position = ext_pos + ext_size * 0.5
	body.add_child(cs)

func _add_label(station: Station, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
	var pos: Vector2 = STATION_POS[station]
	lbl.position = Vector2(pos.x, pos.y - 10)
	lbl.z_index = 5
	add_child(lbl)
	_station_labels[station] = lbl

func _add_collision_rect(body: StaticBody2D, station: Station) -> void:
	var pos: Vector2 = STATION_POS[station]
	var sz: Vector2 = STATION_SIZE[station]
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = sz
	cs.shape = rs
	cs.position = pos + sz * 0.5
	body.add_child(cs)

func _create_bucket_visual() -> void:
	# Bucket is just drawn; label added
	var lbl := Label.new()
	lbl.text = "Honey Bucket"
	lbl.add_theme_font_size_override("font_size", 3)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6, 1.0))
	lbl.position = BUCKET_OFFSET + Vector2(-20, BUCKET_RADIUS + 2)
	lbl.z_index = 5
	add_child(lbl)

# =========================================================================
# INTERACTION -- Called by player._perform_action via group check
# =========================================================================

## Try to interact with the nearest station. Returns true if handled.
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
				return "[E] Start Extraction (%d frames)" % _frames_in_extractor
			if _scraped_super_ready:
				return "Take super from scraped pallet first"
			return "Load scraped super first"
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

func _on_scraping_cancelled() -> void:
	_minigame_active = false
	if _scraping_overlay:
		_scraping_overlay.queue_free()
		_scraping_overlay = null

# -- Scraped Frame Pallet: place super box or pick up completed super -----
func _action_scraped_pallet(player: Node2D) -> void:
	# Pick up completed scraped super -> load into extractor
	if _scraped_super_ready:
		_frames_in_extractor = _frames_scraped
		_frames_scraped = 0
		_scraped_super_ready = false
		_super_box_on_scraped = false
		_notify("Scraped super loaded! Head to the extractor.")
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

# -- Extractor: load super and run extraction minigame --------------------
@warning_ignore("unused_parameter")
func _action_extractor(player: Node2D) -> void:
	if _frames_in_extractor == 0:
		# Check if player just picked up scraped super
		if _scraped_super_ready:
			_notify("Pick up the scraped super from the pallet first!")
		else:
			_notify("No frames to extract! Scrape a super first.")
		return

	_start_extractor_minigame()

func _start_extractor_minigame() -> void:
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

func _on_extraction_complete() -> void:
	_minigame_active = false
	if _extractor_overlay:
		_extractor_overlay.queue_free()
		_extractor_overlay = null

	# Calculate honey yield (4 lbs per frame)
	var total_honey: float = float(_frames_in_extractor) * 4.0
	_bucket_honey_lbs += total_honey
	_frames_in_extractor = 0
	# Bucket is now full -- player must pick it up with the bucket grip
	_bucket_at_yard = true

	_notify("Honey extracted! %.1f lbs in bucket. Use Bucket Grip to carry it to bottling table!" % _bucket_honey_lbs)
	GameData.add_xp(GameData.XP_HARVEST)
	queue_redraw()

func _on_extraction_cancelled() -> void:
	_minigame_active = false
	if _extractor_overlay:
		_extractor_overlay.queue_free()
		_extractor_overlay = null

# -- Bottling Table: fill jars or collect filled jars ---------------------
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
## Player equips ITEM_BUCKET_GRIP and presses E near the honey bucket.
## Transfers the full bucket to their inventory as ITEM_HONEY_BUCKET.
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
func _get_held_item(player: Node2D) -> String:
	if player.has_method("get_active_item_name"):
		return player.get_active_item_name()
	return ""

func _find_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _notify(msg: String) -> void:
	var nm: Node = get_tree().root.get_node_or_null("NotificationManager")
	if nm and nm.has_method("notify"):
		nm.notify(msg)

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

func _process(_delta: float) -> void:
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
		# Position prompt near player
		_prompt_label.position = player.global_position - global_position + Vector2(-40, -24)
	else:
		if _prompt_label:
			_prompt_label.visible = false
