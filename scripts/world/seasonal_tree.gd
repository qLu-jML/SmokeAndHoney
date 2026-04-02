# seasonal_tree.gd -- Node2D tree with seasonal sprites, collision, and forage
# ---------------------------------------------------------------------------
# Drop SeasonalTree.tscn into any world scene under a y_sort_enabled parent.
# The node position = trunk base. The sprite draws upward from there.
# Player walks behind the canopy when above the tree, in front when below.
#
# Forage: Each tree contributes nectar (NU) and pollen (PU) to ForageManager
# during its bloom window (forage_month_start..forage_month_end). Trees add
# themselves to the "trees" group so ForageManager can query all instances.
#
# GDD S14 tree NU values (total NU, split into nectar + pollen):
#   Willow:        8 NU -- pollen-heavy (nectar 2, pollen 6)
#   Silver Maple:  6 NU -- pollen-heavy (nectar 1, pollen 5)
#   Wild Plum:     5 NU -- balanced    (nectar 2, pollen 3)
#   Apple Tree:    7 NU -- balanced    (nectar 3, pollen 4)
#   Cherry Tree:   7 NU -- balanced    (nectar 3, pollen 4)
#   Pear Tree:     7 NU -- balanced    (nectar 3, pollen 4)
#   Linden:       18 NU -- nectar-heavy (nectar 14, pollen 4)
#   Cottonwood:    3 NU -- pollen-only (nectar 0, pollen 3)
#   Sycamore:      2 NU -- pollen-only (nectar 0, pollen 2)
#   Elm (dead):    0 NU -- no forage
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
@export var tree_type: String = "willow"

## If true, the sprite flips horizontally for visual variety.
@export var flip: bool = false

## Optional: day-of-year range when bloom texture replaces spring texture.
@export var bloom_start: int = 0
@export var bloom_end: int = 0

## Width of the trunk collision box in pixels.
@export var trunk_collision_width: float = 16.0

## Height of the trunk collision box in pixels.
@export var trunk_collision_height: float = 12.0

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
const TREE_FORAGE_DATA: Dictionary = {
	# Willow: earliest spring bloomer, catkins loaded with pollen, light nectar.
	# A mature willow is a lifeline for overwintered colonies.
	"willow": {
		"nectar": 15.0, "pollen": 25.0,
		"month_start": 0, "month_end": 0,
	},
	# Silver maple: very early spring, heavy pollen from catkins, minimal nectar.
	"silver_maple": {
		"nectar": 8.0, "pollen": 20.0,
		"month_start": 0, "month_end": 0,
	},
	# Wild plum: early bloomer, good nectar + pollen, spans Quickening-Greening.
	"wild_plum": {
		"nectar": 12.0, "pollen": 10.0,
		"month_start": 0, "month_end": 1,
	},
	# Fruit trees: classic spring nectar sources. Bloom in Greening only.
	"apple_tree": {
		"nectar": 20.0, "pollen": 15.0,
		"month_start": 1, "month_end": 1,
	},
	"cherry_tree": {
		"nectar": 18.0, "pollen": 15.0,
		"month_start": 1, "month_end": 1,
	},
	"pear_tree": {
		"nectar": 18.0, "pollen": 15.0,
		"month_start": 1, "month_end": 1,
	},
	# Basswood/linden: the PREMIUM summer nectar tree. Legendary honey yield.
	"basswood_linden": {
		"nectar": 60.0, "pollen": 15.0,
		"month_start": 2, "month_end": 3,
	},
	# Cottonwood: wind-pollinated, no nectar, moderate pollen and propolis resin.
	"cottonwood": {
		"nectar": 0.0, "pollen": 12.0,
		"month_start": 0, "month_end": 1,
	},
	# Sycamore: minor pollen only, mainly shade/structure.
	"sycamore": {
		"nectar": 0.0, "pollen": 8.0,
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

const TREE_PATH := "res://assets/sprites/environment/trees/"

# -- Lifecycle ---------------------------------------------------------------

## Initialize the seasonal tree: sprite, collision, textures, and forage.
func _ready() -> void:
	# Match player z_index so y-sort actually determines draw order
	z_index = 1

	# Apply species-specific forage defaults if tree_type is known
	_apply_forage_defaults()

	# Register in "trees" group so ForageManager can find us
	add_to_group("trees")

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

	# Load textures and apply initial season
	_load_textures()
	if TimeManager:
		TimeManager.season_changed.connect(_on_season_changed)
		TimeManager.day_advanced.connect(_on_day_advanced)
		_apply_season(TimeManager.current_season_name())


## Apply default forage values based on tree species.
func _apply_forage_defaults() -> void:
	# Only apply defaults if the exports still match the class defaults
	# (i.e., user hasn't customized them in the Inspector)
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
		else:
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
		if TimeManager:
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
	if not TimeManager:
		return false
	var month: int = TimeManager.current_month_index()
	return month >= forage_month_start and month <= forage_month_end


# -- Signal Handlers ---------------------------------------------------------

## Handle TimeManager season change signal.
func _on_season_changed(season_name: String) -> void:
	_apply_season(season_name)


## Handle TimeManager day advance signal to check for bloom transition.
func _on_day_advanced(_new_day: int) -> void:
	if _bloom_texture and bloom_start > 0 and bloom_end > 0:
		_apply_season(_current_season)


## Disconnect TimeManager signals when leaving the scene tree.
func _exit_tree() -> void:
	if TimeManager:
		TimeManager.season_changed.disconnect(_on_season_changed)
		TimeManager.day_advanced.disconnect(_on_day_advanced)
