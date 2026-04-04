# harvestable_tree.gd -- An interactable tree that can be chopped for logs.
# Placed in scenes like county_road where resource gathering happens.
# Tracks regrowth via GameData.chopped_trees dictionary.
# -------------------------------------------------------------------------
# If tree_texture is set (in the editor), the tree uses a Sprite2D.
# Otherwise it falls back to ColorRect placeholder visuals.
# -------------------------------------------------------------------------
@tool
extends Node2D

@warning_ignore("unused_signal")
signal tree_interact(tree_node: Node2D)

# -- Configuration --------------------------------------------------------
@export var tree_id: String = "county_tree_1"   # Unique ID for regrowth tracking
@export var tree_label: String = "Oak"          # Display name
@export var tree_texture: Texture2D = null      # Pixel art tree sprite (optional)

# -- Visual state ---------------------------------------------------------
var _is_chopped: bool = false
var _trunk_sprite: ColorRect = null
var _canopy_sprite: ColorRect = null
var _tree_sprite: Sprite2D = null
var _stump_sprite: ColorRect = null
var _hint_label: Label = null
var _name_label: Label = null
var _collision: StaticBody2D = null

# -- Layout ---------------------------------------------------------------
const TRUNK_W := 12
const TRUNK_H := 20
const CANOPY_W := 36
const CANOPY_H := 28
const INTERACT_RADIUS := 48.0

# =========================================================================
# TOOL -- show the texture in the editor so trees are visible when placing
# =========================================================================
## Initialize the harvestable tree: visuals, state checking, and signal connections.
func _ready() -> void:
	if Engine.is_editor_hint():
		_build_editor_preview()
		return
	add_to_group("harvestable_trees")
	_build_visuals()
	_check_chopped_state()
	if TimeManager:
		TimeManager.day_advanced.connect(_on_day_advanced)

## Build editor preview showing the tree texture for positioning.
func _build_editor_preview() -> void:
	# Show the tree texture in the editor for positioning
	if tree_texture:
		var preview: Sprite2D = Sprite2D.new()
		preview.texture = tree_texture
		preview.offset = Vector2(0, -tree_texture.get_height() * 0.5)
		add_child(preview)

# =========================================================================
# RUNTIME VISUALS
# =========================================================================
## Build the tree visuals (sprite or colored rectangles) and UI labels.
func _build_visuals() -> void:
	if tree_texture:
		_build_sprite_visuals()
	else:
		_build_colorrect_visuals()
	_build_shared_ui()

## Build visuals using the pixel art texture.
func _build_sprite_visuals() -> void:
	# Use the pixel art texture
	_tree_sprite = Sprite2D.new()
	_tree_sprite.texture = tree_texture
	# Anchor at bottom center so position = base of trunk
	_tree_sprite.offset = Vector2(0, -tree_texture.get_height() * 0.5)
	add_child(_tree_sprite)

	# Stump (shown when chopped)
	_stump_sprite = ColorRect.new()
	_stump_sprite.color = Color(0.50, 0.35, 0.18, 1.0)
	_stump_sprite.size = Vector2(TRUNK_W + 4, 6)
	_stump_sprite.position = Vector2(-(TRUNK_W + 4) / 2, -6)
	_stump_sprite.visible = false
	add_child(_stump_sprite)

	# Collision body so player walks around the trunk
	_collision = StaticBody2D.new()
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(TRUNK_W + 4, TRUNK_H)
	col_shape.shape = shape
	col_shape.position = Vector2(0, -TRUNK_H / 2)
	_collision.add_child(col_shape)
	add_child(_collision)

## Build placeholder colored rectangle visuals (fallback when no texture).
func _build_colorrect_visuals() -> void:
	# Fallback: colored rectangles when no texture is assigned
	_canopy_sprite = ColorRect.new()
	_canopy_sprite.color = Color(0.25, 0.55, 0.20, 1.0)
	_canopy_sprite.size = Vector2(CANOPY_W, CANOPY_H)
	_canopy_sprite.position = Vector2(-CANOPY_W / 2, -CANOPY_H - TRUNK_H + 4)
	add_child(_canopy_sprite)

	_trunk_sprite = ColorRect.new()
	_trunk_sprite.color = Color(0.45, 0.30, 0.15, 1.0)
	_trunk_sprite.size = Vector2(TRUNK_W, TRUNK_H)
	_trunk_sprite.position = Vector2(-TRUNK_W / 2, -TRUNK_H)
	add_child(_trunk_sprite)

	_stump_sprite = ColorRect.new()
	_stump_sprite.color = Color(0.50, 0.35, 0.18, 1.0)
	_stump_sprite.size = Vector2(TRUNK_W + 4, 6)
	_stump_sprite.position = Vector2(-(TRUNK_W + 4) / 2, -6)
	_stump_sprite.visible = false
	add_child(_stump_sprite)

	_collision = StaticBody2D.new()
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(TRUNK_W + 4, TRUNK_H)
	col_shape.shape = shape
	col_shape.position = Vector2(0, -TRUNK_H / 2)
	_collision.add_child(col_shape)
	add_child(_collision)

## Build shared UI elements: interaction hint and name label.
func _build_shared_ui() -> void:
	# Interaction hint (hidden until player is near)
	_hint_label = Label.new()
	_hint_label.text = "[E] Chop"
	_hint_label.add_theme_font_size_override("font_size", 5)
	_hint_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.65))
	_hint_label.position = Vector2(-16, -CANOPY_H - TRUNK_H - 8)
	_hint_label.visible = false
	add_child(_hint_label)

	# Name label (shown in dev mode)
	_name_label = Label.new()
	_name_label.text = "%s [%s]" % [tree_label, tree_id]
	_name_label.add_theme_font_size_override("font_size", 4)
	_name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5, 0.6))
	_name_label.position = Vector2(-20, 4)
	_name_label.visible = GameData.dev_labels_visible
	_name_label.add_to_group("dev_label")
	add_child(_name_label)

# =========================================================================
# STATE
# =========================================================================
## Check if the tree has been chopped and update visuals accordingly.
func _check_chopped_state() -> void:
	_is_chopped = GameData.is_tree_chopped(tree_id)
	_update_visuals()

## Update sprite visibility and hint text based on chopped state.
func _update_visuals() -> void:
	if _is_chopped:
		if _tree_sprite:
			_tree_sprite.visible = false
		if _canopy_sprite:
			_canopy_sprite.visible = false
		if _trunk_sprite:
			_trunk_sprite.visible = false
		_stump_sprite.visible = true
		if _hint_label:
			_hint_label.text = "(regrowing)"
	else:
		if _tree_sprite:
			_tree_sprite.visible = true
		if _canopy_sprite:
			_canopy_sprite.visible = true
		if _trunk_sprite:
			_trunk_sprite.visible = true
		_stump_sprite.visible = false
		if _hint_label:
			_hint_label.text = "[E] Chop"

## Handle day advancement to check for tree regrowth.
func _on_day_advanced(_day: int) -> void:
	_check_chopped_state()

## Mark this tree as chopped and update visuals.
func mark_chopped() -> void:
	GameData.chop_tree(tree_id)
	_is_chopped = true
	_update_visuals()

## Check if this tree can still be chopped.
func is_choppable() -> bool:
	return not _is_chopped

# =========================================================================
# PROXIMITY (called by parent scene each frame or on input)
# =========================================================================
## Update hint visibility based on player proximity and inventory.
func update_hint_visibility(player_pos: Vector2) -> void:
	var dist: float = player_pos.distance_to(global_position)
	if _hint_label:
		_hint_label.visible = dist <= INTERACT_RADIUS
		if not _is_chopped and _hint_label.visible:
			var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			if player and player.has_method("get_item_count"):
				if player.get_item_count(GameData.ITEM_AXE) > 0:
					_hint_label.text = "[E] Chop"
				else:
					_hint_label.text = "(Need Axe)"

## Check if the player is within interaction range.
func is_player_in_range(player_pos: Vector2) -> bool:
	return player_pos.distance_to(global_position) <= INTERACT_RADIUS

## Disconnect TimeManager signals when leaving the scene tree.
func _exit_tree() -> void:
	if TimeManager:
		TimeManager.day_advanced.disconnect(_on_day_advanced)
