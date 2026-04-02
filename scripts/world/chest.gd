# chest.gd -- Placeable world storage chest (10 col x 5 row = 50 slots)
# Placed by the player from inventory. Stores items in a persistent
# 50-slot grid. Interaction (E key) opens the ChestStorage overlay.
extends Node2D

const CHEST_SLOTS: int = 50
const SPRITE_PATH: String = "res://assets/sprites/objects/chest.png"

# Persistent inventory: Array of {item: String, count: int} or null.
var storage: Array = []

# Node refs
var _sprite: Sprite2D
var _area: Area2D
var _prompt_label: Label

## Initialize the chest: sprite, interaction area, and prompt label.
func _ready() -> void:
	add_to_group("chest")
	z_index = 0
	y_sort_enabled = true

	# Initialise empty storage
	storage.resize(CHEST_SLOTS)
	storage.fill(null)

	# Sprite (loaded at runtime to bypass import pipeline)
	_sprite = Sprite2D.new()
	_sprite.name = "ChestSprite"
	var abs_path: String = ProjectSettings.globalize_path(SPRITE_PATH)
	var img: Image = Image.load_from_file(abs_path)
	if img:
		_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.offset = Vector2(0, -9)
	add_child(_sprite)

	# Interaction area
	_area = Area2D.new()
	_area.name = "InteractArea"
	_area.collision_layer = 0
	_area.collision_mask  = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(28, 22)
	shape.shape = rect
	shape.position = Vector2(0, -9)
	_area.add_child(shape)
	add_child(_area)

	# Prompt label (shown when nearby player)
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Storage"
	_prompt_label.add_theme_font_size_override("font_size", 7)
	_prompt_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(60, 10)
	_prompt_label.position = Vector2(-30, -24)
	_prompt_label.visible = false
	add_child(_prompt_label)

## Update prompt visibility based on player proximity each frame.
func _process(_delta: float) -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var d: float = (players[0] as Node2D).global_position.distance_to(global_position)
		_prompt_label.visible = d <= 64.0
	else:
		_prompt_label.visible = false

# -- Public API ---------------------------------------------------------------

## Open the chest storage overlay. Called by player.gd on interaction.
func open_storage() -> void:
	if get_tree().get_first_node_in_group("chest_storage_overlay"):
		return
	var scene: PackedScene = load("res://scenes/ui/chest_storage.tscn")
	if scene == null:
		push_error("Chest: failed to load chest_storage.tscn")
		return
	var overlay: Node = scene.instantiate()
	overlay.chest_ref = self
	get_tree().root.add_child(overlay)

# -- Inventory helpers (mirror player.gd API) ---------------------------------

## Get the maximum stack size for an item from the player.
func get_max_stack(item_name: String) -> int:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_method("get_max_stack"):
		return players[0].get_max_stack(item_name)
	return 20

## Add items to storage and return overflow amount.
func add_item(item_name: String, amount: int) -> int:
	var stack_max: int = get_max_stack(item_name)
	for i in range(CHEST_SLOTS):
		if storage[i] != null and storage[i]["item"] == item_name:
			var space: int = stack_max - storage[i]["count"]
			if space > 0:
				var add: int = mini(space, amount)
				storage[i]["count"] += add
				amount -= add
				if amount <= 0:
					return 0
	for i in range(CHEST_SLOTS):
		if storage[i] == null:
			var add: int = mini(stack_max, amount)
			storage[i] = {"item": item_name, "count": add}
			amount -= add
			if amount <= 0:
				return 0
	return amount

## Remove items from a storage slot.
func remove_slot(slot_idx: int, amount: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= CHEST_SLOTS or storage[slot_idx] == null:
		return {}
	var slot: Dictionary = storage[slot_idx]
	var take: int = mini(amount, slot["count"])
	var result: Dictionary = {"item": slot["item"], "count": take}
	slot["count"] -= take
	if slot["count"] <= 0:
		storage[slot_idx] = null
	return result

## Count total items of a given type in storage.
func count_item(item_name: String) -> int:
	var total: int = 0
	for slot in storage:
		if slot != null and slot["item"] == item_name:
			total += slot["count"]
	return total
