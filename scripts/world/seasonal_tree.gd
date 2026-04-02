@tool
# seasonal_tree.gd -- Node2D tree with seasonal sprites, collision, and forage
# ---------------------------------------------------------------------------
# @tool: renders in the Godot editor so you can see and drag trees visually.
# Drop SeasonalTree.tscn into any world scene under a y_sort_enabled parent.
# The node position = trunk base. The sprite draws upward from there.
# Player walks behind the canopy when above the tree, in front when below.
#
# Forage: Each tree contributes nectar (NU) and pollen (PU) to ForageManager
# during its bloom window (forage_month_start..forage_month_end). Trees add
# themselves to the "trees" group so ForageManager can query all instances.
#
# GDD S14 tree NU values (per tree, scaled for ~40 trees across property):
#   Willow:        10.0 NU -- pollen-heavy (nectar 3.75, pollen 6.25)
#   Silver Maple:   7.0 NU -- pollen-heavy (nectar 2.0, pollen 5.0)
#   Wild Plum:      5.5 NU -- balanced    (nectar 3.0, pollen 2.5)
#   Apple Tree:     8.75 NU -- balanced   (nectar 5.0, pollen 3.75)
#   Cherry Tree:    8.25 NU -- balanced   (nectar 4.5, pollen 3.75)
#   Pear Tree:      8.25 NU -- balanced   (nectar 4.5, pollen 3.75)
#   Linden:        18.75 NU -- nectar-heavy (nectar 15.0, pollen 3.75)
#   Cottonwood:     3.0 NU -- pollen-only (nectar 0, pollen 3.0)
#   Sycamore:       2.0 NU -- pollen-only (nectar 0, pollen 2.0)
#   Elm (dead):     0 NU -- no forage
#
# Collision: small StaticBody2D at the trunk base blocks player movement.
#
# Naming convention in assets/sprites/environment/trees/:
#   {tree_type}_spring.png, {tree_type}_summer.png,
#   {tree_type}_fall.png,   {tree_type}_winter.png
# Optional: {tree_type}_bloom.png
# ---------------------------------------------------------------------------
extends Node2D
class_name SeasonalTree

# -- Exported Configuration --------------------------------------------------

## Which tree species. Must match filename prefix in trees/ folder.
@export var tree_type: String = "willow":
	set(value):
		tree_type = value
		# Rebuild visuals when changed in editor Inspector
		if is_inside_tree():
			_rebuild()

## If true, the sprite flips horizontally for visual variety.
@export var flip: bool = false:
	set(value):
		flip = value
		if _sprite:
			_sprite.flip_h = flip

## Optional: day-of-year range when bloom texture replaces spring texture.
@export var bloom_start: int = 0
@export var bloom_end: int = 0

## Width of the trunk collision box in pixels.
@export var trunk_collision_width: float = 16.0:
	set(value):
		trunk_collision_width = value
		if is_inside_tree():
			_rebuild_collision()

## Height of the trunk collision box in pixels.
@export var trunk_collision_height: float = 12.0:
	set(value):
		trunk_collision_height = value
		if is_inside_tree():
			_rebuild_collision()

# -- Forage Configuration ---------------------------------------------------
# These are set automatically from TREE_FORAGE_DATA based on tree_type,
# but can be overridden in the Inspector for custom trees.

## Nectar Units this tree contributes during its bloom window.
## PU allows queen to lay eggs (pollen = protein for brood).
@export var pollen_pu: float = 6.0

## Nectar Units this tree contributes during its bloom window.
## NU allows wax and honey production.
@export var nectar_nu: float = 2.0

## First month index this tree produces forage (0=Quickening .. 7=Kindlemonth).
@export var forage_month_start: int = 0

## Last month index this tree produces forage.
@export var forage_month_end: int = 0

# -- Species Forage Defaults -------------------------------------------------
# GDD S14 values. Keys match tree_type strings.
# Months: 0=Quickening, 1=Greening, 2=Wide-Clover, 3=High-Sun,
#         4=Full-Earth, 5=Reaping, 6=Deepcold, 7=Kindlemonth
## Forage values per tree, scaled for ~40 trees across the full property.
## Original values (designed for 10 trees) divided by 4 so the aggregate
## forage pool stays the same now that trees cover the whole grass area.
const TREE_FORAGE_DATA: Dictionary = {
	# Willow: earliest spring bloomer, catkins loaded with pollen, light nectar.
	# A mature willow is a lifeline for overwintered colonies.
	"willow": {
		"nectar": 3.75, "pollen": 6.25,
		"month_start": 0, "month_end": 0,
	},
	# Silver maple: very early spring, heavy pollen from catkins, minimal nectar.
	"silver_maple": {
		"nectar": 2.0, "pollen": 5.0,
		"month_start": 0, "month_end": 0,
	},
	# Wild plum: early bloomer, good nectar + pollen, spans Quickening-Greening.
	"wild_plum": {
		"nectar": 3.0, "pollen": 2.5,
		"month_start": 0, "month_end": 1,
	},
	# Fruit trees: classic spring nectar sources. Bloom in Greening only.
	"apple_tree": {
		"nectar": 5.0, "pollen": 3.75,
		"month_start": 1, "month_end": 1,
	},
	"cherry_tree": {
		"nectar": 4.5, "pollen": 3.75,
		"month_start": 1, "month_end": 1,
	},
	"pear_tree": {
		"nectar": 4.5, "pollen": 3.75,
		"month_start": 1, "month_end": 1,
	},
	# Basswood/linden: the PREMIUM summer nectar tree. Legendary honey yield.
	"basswood_linden": {
		"nectar": 15.0, "pollen": 3.75,
		"month_start": 2, "month_end": 3,
	},
	# Cottonwood: wind-pollinated, no nectar, moderate pollen and propolis resin.
	"cottonwood": {
		"nectar": 0.0, "pollen": 3.0,
		"month_start": 0, "month_end": 1,
	},
	# Sycamore: minor pollen only, mainly shade/structure.
	"sycamore": {
		"nectar": 0.0, "pollen": 2.0,
		"month_start": 0, "month_end": 1,
	},
	# Dead elm: no forage contribution.
	"elm_dead": {
		"nectar": 0.0, "pollen": 0.0,
		"month_start": 0, "month_end": 0,
	},
}

# -- Internal State ----------------------------------------------------------

var _textures: Dictionary = {}
var _bloom_texture: CompressedTexture2D = null
var _current_season: String = ""
var _sprite: Sprite2D = null
var _body: StaticBody2D = null
var _debug_overlay: Node2D = null

const TREE_PATH := "res://assets/sprites/environment/trees/"

# -- Lifecycle ---------------------------------------------------------------

## Initialize the seasonal tree: sprite, collision, textures, and forage.
func _ready() -> void:
	# Match player z_index so y-sort actually determines draw order
	z_index = 1

	# Apply species-specific forage defaults if tree_type is known
	_apply_forage_defaults()

	# Runtime-only: register in trees group and connect signals
	if not Engine.is_editor_hint():
		add_to_group("trees")

	# Build sprite and collision (works in both editor and runtime)
	_rebuild()

	# Runtime-only: connect to TimeManager for season changes and debug overlay
	if not Engine.is_editor_hint():
		_create_debug_overlay()
		GameData.dev_labels_toggled.connect(_on_dev_labels_toggled)
		if TimeManager:
			TimeManager.season_changed.connect(_on_season_changed)
			TimeManager.day_advanced.connect(_on_day_advanced)
			_apply_season(TimeManager.current_season_name())


## Full rebuild: clears old children, recreates sprite + collision + textures.
## Called on _ready and whenever tree_type changes in the Inspector.
func _rebuild() -> void:
	# Remove old sprite and collision if they exist
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
		_sprite = null
	if _body and is_instance_valid(_body):
		_body.queue_free()
		_body = null
	_textures.clear()
	_bloom_texture = null

	# Create the sprite child
	_sprite = Sprite2D.new()
	_sprite.name = "TreeSprite"
	_sprite.centered = false
	_sprite.flip_h = flip
	add_child(_sprite)

	# Create trunk collision (StaticBody2D at base)
	_body = StaticBody2D.new()
	_body.name = "TrunkCollision"
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(trunk_collision_width, trunk_collision_height)
	col_shape.shape = rect
	col_shape.position = Vector2(0.0, -trunk_collision_height * 0.5)
	_body.add_child(col_shape)
	add_child(_body)

	# Load textures and apply initial appearance
	_load_textures()

	# In the editor, show the spring texture as the default preview
	if Engine.is_editor_hint():
		if _textures.has("Spring"):
			_sprite.texture = _textures["Spring"]
		_update_sprite_offset()


## Rebuild just the collision shape when dimensions change in Inspector.
func _rebuild_collision() -> void:
	if _body and is_instance_valid(_body):
		var col: CollisionShape2D = _body.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(trunk_collision_width, trunk_collision_height)
			col.position = Vector2(0.0, -trunk_collision_height * 0.5)


## Apply default forage values based on tree species.
func _apply_forage_defaults() -> void:
	if TREE_FORAGE_DATA.has(tree_type):
		var data: Dictionary = TREE_FORAGE_DATA[tree_type]
		nectar_nu = data["nectar"]
		pollen_pu = data["pollen"]
		forage_month_start = data["month_start"]
		forage_month_end = data["month_end"]


## Load seasonal textures from disk, plus optional bloom texture.
func _load_textures() -> void:
	var seasons: PackedStringArray = ["spring", "summer", "fall", "winter"]
	var season_keys: PackedStringArray = ["Spring", "Summer", "Fall", "Winter"]
	for i in range(4):
		var path: String = TREE_PATH + tree_type + "_" + seasons[i] + ".png"
		if ResourceLoader.exists(path):
			_textures[season_keys[i]] = load(path)
		elif not Engine.is_editor_hint():
			push_warning("SeasonalTree: missing texture %s" % path)

	var bloom_path: String = TREE_PATH + tree_type + "_bloom.png"
	if ResourceLoader.exists(bloom_path):
		_bloom_texture = load(bloom_path)


## Apply the season texture, checking for bloom override first.
func _apply_season(season_name: String) -> void:
	_current_season = season_name
	if not _sprite:
		return
	if _bloom_texture and bloom_start > 0 and bloom_end > 0:
		if not Engine.is_editor_hint() and TimeManager:
			var day: int = TimeManager.current_day
			if day >= bloom_start and day <= bloom_end:
				_sprite.texture = _bloom_texture
				_update_sprite_offset()
				return
	if _textures.has(season_name):
		_sprite.texture = _textures[season_name]
	_update_sprite_offset()


## Update sprite offset to center the texture horizontally and anchor at bottom.
func _update_sprite_offset() -> void:
	if _sprite and _sprite.texture:
		var tex_w: float = _sprite.texture.get_width()
		var tex_h: float = _sprite.texture.get_height()
		_sprite.offset = Vector2(-tex_w * 0.5, -tex_h)


# -- Public Forage API -------------------------------------------------------

## Returns this tree's current nectar/pollen contribution for the given month.
## Called by ForageManager when summing tree forage.
func get_forage_contribution(month_index: int) -> Dictionary:
	if month_index >= forage_month_start and month_index <= forage_month_end:
		return { "nectar": nectar_nu, "pollen": pollen_pu }
	return { "nectar": 0.0, "pollen": 0.0 }


## Whether this tree is currently producing forage.
func is_in_bloom() -> bool:
	if Engine.is_editor_hint():
		return false
	if not TimeManager:
		return false
	var month: int = TimeManager.current_month_index()
	return month >= forage_month_start and month <= forage_month_end


# -- Debug Drawing -----------------------------------------------------------

## Create high-z overlay node for collision debug so it renders on top of everything.
func _create_debug_overlay() -> void:
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "CollisionDebugOverlay"
	_debug_overlay.z_index = 100
	_debug_overlay.z_as_relative = false
	_debug_overlay.set_script(load("res://scripts/debug/collision_debug_draw.gd"))
	_debug_overlay.set_meta("rects", [])
	_update_debug_rects()
	add_child(_debug_overlay)
	_debug_overlay.visible = GameData.dev_labels_visible


## Update the collision rectangles stored on the debug overlay.
func _update_debug_rects() -> void:
	if _debug_overlay == null:
		return
	var hw: float = trunk_collision_width * 0.5
	var hh: float = trunk_collision_height
	var rect := Rect2(-hw, -hh, trunk_collision_width, trunk_collision_height)
	_debug_overlay.set_meta("rects", [rect])
	_debug_overlay.queue_redraw()


## Toggle debug overlay visibility when dev labels toggle.
func _on_dev_labels_toggled(vis: bool) -> void:
	if _debug_overlay:
		_debug_overlay.visible = vis
		_debug_overlay.queue_redraw()


# -- Signal Handlers ---------------------------------------------------------

## Handle TimeManager season change signal.
func _on_season_changed(season_name: String) -> void:
	_apply_season(season_name)


## Handle TimeManager day advance signal to check for bloom transition.
func _on_day_advanced(_new_day: int) -> void:
	if _bloom_texture and bloom_start > 0 and bloom_end > 0:
		_apply_season(_current_season)


## Disconnect signals when leaving the scene tree.
func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if GameData and GameData.dev_labels_toggled.is_connected(_on_dev_labels_toggled):
		GameData.dev_labels_toggled.disconnect(_on_dev_labels_toggled)
	if TimeManager:
		if TimeManager.season_changed.is_connected(_on_season_changed):
			TimeManager.season_changed.disconnect(_on_season_changed)
		if TimeManager.day_advanced.is_connected(_on_day_advanced):
			TimeManager.day_advanced.disconnect(_on_day_advanced)
