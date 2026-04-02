# county_road.gd -- The transitional corridor between home property and town.
# GDD S13.2: The county road connects the player's home to Cedar Bend (town).
#
# All objects (trees, props, exits) are placed in the .tscn via the editor.
# This script handles runtime wiring, tree chopping, and map overlay.
extends Node2D

# -- Scene bounds (3200 x 2400, centered) -----------------------------------
const SCENE_BOUNDS: Rect2 = Rect2(-1600, -1200, 3200, 2400)

# -- Node References --------------------------------------------------------
@onready var map_overlay: CanvasLayer = $MapOverlay

# -- State ------------------------------------------------------------------
var _map_open: bool = false
var _active_chopping_minigame: CanvasLayer = null

# -- Lifecycle ---------------------------------------------------------------

## Initialize the county road: set scene ID, register map markers, position player.
func _ready() -> void:
	TimeManager.current_scene_id = "county_road"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "County Road"
		SceneManager.show_zone_name()
		_register_map_markers()
	ExitHelper.position_player_from_spawn_side(self, SCENE_BOUNDS)
	print("County Road scene loaded.")

## Register map markers for the scene.
func _register_map_markers() -> void:
	SceneManager.clear_scene_markers()
	SceneManager.set_scene_bounds(SCENE_BOUNDS)
	SceneManager.register_scene_exit("left", "Home")
	SceneManager.register_scene_exit("right", "Cedar Bend")

# -- Input ------------------------------------------------------------------

## Handle input events for interactions and map toggle.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_try_interact()
			KEY_M:
				_toggle_map()

# -- Interaction -------------------------------------------------------------

## Attempt to interact with the nearest choppable tree.
func _try_interact() -> void:
	if _active_chopping_minigame:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	_try_chop_nearest_tree(player)

# -- Tree Chopping -----------------------------------------------------------

## Update tree hints every frame and check for chopping minigame.
func _process(_delta: float) -> void:
	if _active_chopping_minigame:
		return
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	for tree in get_tree().get_nodes_in_group("harvestable_trees"):
		if tree.has_method("update_hint_visibility"):
			tree.update_hint_visibility(player.global_position)

## Find and start chopping the nearest interactable tree.
func _try_chop_nearest_tree(player: Node2D) -> void:
	# Check axe
	if player.has_method("get_item_count"):
		if player.get_item_count(GameData.ITEM_AXE) <= 0:
			print("[County Road] You need an axe to chop trees.")
			return
	# Check energy
	if GameData.energy < 15.0:
		print("[County Road] Too tired to chop trees.")
		return
	# Find nearest choppable tree in range
	var best_tree: Node2D = null
	var best_dist: float = 9999.0
	for tree in get_tree().get_nodes_in_group("harvestable_trees"):
		if not tree.has_method("is_choppable") or not tree.is_choppable():
			continue
		if not tree.is_player_in_range(player.global_position):
			continue
		var d: float = player.global_position.distance_to(tree.global_position)
		if d < best_dist:
			best_dist = d
			best_tree = tree
	if best_tree == null:
		return
	_start_chopping(best_tree)

## Initialize and start a chopping minigame for the given tree.
func _start_chopping(tree_node: Node2D) -> void:
	var mg_script: GDScript = load("res://scripts/ui/chopping_minigame.gd")
	_active_chopping_minigame = CanvasLayer.new()
	_active_chopping_minigame.set_script(mg_script)
	add_child(_active_chopping_minigame)
	_active_chopping_minigame.chopping_complete.connect(
		func(logs: int) -> void:
			_on_chopping_complete(tree_node, logs))
	_active_chopping_minigame.chopping_cancelled.connect(_on_chopping_cancelled)

## Handle completion of the chopping minigame.
func _on_chopping_complete(tree_node: Node2D, logs: int) -> void:
	if tree_node and tree_node.has_method("mark_chopped"):
		tree_node.mark_chopped()
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("add_item"):
		var leftover: int = player.add_item(GameData.ITEM_LOGS, logs)
		if leftover > 0:
			print("[County Road] Inventory full! %d logs lost." % leftover)
	print("[County Road] Chopped tree -- earned %d logs." % logs)
	_cleanup_chopping_minigame()

## Handle cancellation of the chopping minigame.
func _on_chopping_cancelled() -> void:
	print("[County Road] Chopping cancelled.")
	_cleanup_chopping_minigame()

## Clean up the active chopping minigame.
func _cleanup_chopping_minigame() -> void:
	if _active_chopping_minigame:
		_active_chopping_minigame.queue_free()
		_active_chopping_minigame = null

# -- Map Overlay -------------------------------------------------------------

## Toggle the map open/closed.
func _toggle_map() -> void:
	if _map_open:
		_close_map()
	else:
		_open_map()

## Open the map overlay.
func _open_map() -> void:
	if not map_overlay:
		return
	_map_open = true
	map_overlay.open()

## Close the map overlay.
func _close_map() -> void:
	_map_open = false
	if map_overlay:
		map_overlay.close()
