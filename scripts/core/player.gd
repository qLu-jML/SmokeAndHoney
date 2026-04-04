extends CharacterBody2D

enum Mode { NORMAL = 0, TILL = 1, PLANT = 2, HIVE = 3 }
var current_mode: Mode = Mode.NORMAL
var mode_label: Label = null

var facing_direction: Vector2 = Vector2.DOWN
var facing_dir_8: Vector2i = Vector2i(0, 1)  # full 8-way, used for tile targeting

# -- Carried item display ------------------------------------------------------
var _carried_super_sprite:   Sprite2D = null   # floating super visual when carrying
var _carried_bucket_sprite:  Sprite2D = null   # floating honey bucket when carrying

# -- Inventory -----------------------------------------------------------------
const INVENTORY_SIZE = 10
var inventory: Array = []
var active_slot: int = 0

# -- Smoker State (for bee calming during inspection) -------------------------
var _smoker_active: bool = false      # True when hive has been smoked this inspection
var _smoker_puffs: int = 0            # Remaining puffs (0-3, higher = more calmed)

func get_max_stack(item_name: String) -> int:
	match item_name:
		GameData.ITEM_RAW_HONEY:  return 999
		GameData.ITEM_HONEY_JAR:  return 20
		GameData.ITEM_BEESWAX:    return 99
		GameData.ITEM_BEEHIVE:    return 5     # up to 5 complete hives per slot
		GameData.ITEM_HIVE_STAND: return 5
		GameData.ITEM_DEEP_BODY:  return 5
		GameData.ITEM_LID:        return 5
		GameData.ITEM_SUPER_BOX:  return 5
		GameData.ITEM_FRAMES:     return 20
		GameData.ITEM_HIVE_TOOL:  return 1
		GameData.ITEM_PACKAGE_BEES: return 5
		GameData.ITEM_QUEEN_EXCLUDER: return 5
		GameData.ITEM_FULL_SUPER:     return 1  # heavy! carry limit: 1 super at a time
		GameData.ITEM_SCRAPED_SUPER:  return 1  # uncapped super ready for extractor
		GameData.ITEM_DEEP_BOX:   return 5
		GameData.ITEM_JAR:        return 20
		GameData.ITEM_HONEY_BULK: return 20
		GameData.ITEM_FERMENTED_HONEY: return 20
		GameData.ITEM_CHEST:      return 5
		GameData.ITEM_LOGS:       return 40
		GameData.ITEM_LUMBER:     return 20
		GameData.ITEM_AXE:          return 1
		GameData.ITEM_HAMMER:       return 1
		GameData.ITEM_SMOKER:       return 1
		GameData.ITEM_BEE_SUIT:     return 1
		GameData.ITEM_PROPOLIS:     return 99
		GameData.ITEM_BUCKET_GRIP:  return 1    # One grip tool per slot
		GameData.ITEM_HONEY_BUCKET: return 1    # One full bucket -- it's heavy
		_:                          return 20

# -- Initialisation & Lifecycle -------------------------------------------------

## Initialize player: inventory, spritesheet, signals, HUD.
func _ready():
	inventory.resize(INVENTORY_SIZE)
	inventory.fill(null)
	# Restore inventory from GameData if a previous player synced it (scene change).
	# Otherwise use starting defaults (brand-new game).
	if GameData.player_inventory_valid and GameData.player_inventory.size() > 0:
		for i in range(mini(GameData.player_inventory.size(), INVENTORY_SIZE)):
			inventory[i] = GameData.player_inventory[i]
	else:
		# New game: start with empty inventory -- all tools are in the chest.
		# Player learns to open chest and grab items via Uncle Bob's onboarding.
		sync_inventory_to_gamedata()
	# Deferred: stock the storage chest with remaining items after scene loads
	call_deferred("_stock_starting_chest")
	add_to_group("player")
	# Sync grid overlay when dev mode toggles (G key handled by GameData globally)
	GameData.dev_labels_toggled.connect(_on_dev_labels_toggled)
	# Load beekeeper spritesheet at runtime (bypasses import pipeline)
	_load_spritesheet()
	call_deferred("_grab_window_focus")
	# Push starting inventory to HUD after all _ready() calls complete
	call_deferred("update_hud_inventory")
	# Carried item display sprite (setup deferred so node tree is ready)
	call_deferred("_setup_carry_sprite")

## Disconnect signals on scene tree exit to prevent memory leaks.
func _exit_tree() -> void:
	if GameData.dev_labels_toggled.is_connected(_on_dev_labels_toggled):
		GameData.dev_labels_toggled.disconnect(_on_dev_labels_toggled)

## Load player beekeeper spritesheet from disk at runtime.
func _load_spritesheet() -> void:
	var path := "res://assets/sprites/npc/The_Beekeeper/beekeeper_spritesheet.png"
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		push_error("Player: failed to load spritesheet from %s" % abs_path)
		return
	var tex := ImageTexture.create_from_image(img)
	player_sprite.texture = tex
	player_sprite.hframes = _SHEET_COLS
	player_sprite.vframes = 24
	player_sprite.frame = 0

## Grab window focus and set up the mode label.
func _grab_window_focus() -> void:
	get_window().grab_focus()

	mode_label = Label.new()
	mode_label.name = "ModeLabel"
	mode_label.add_theme_font_size_override("font_size", 8)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.custom_minimum_size = Vector2(64, 10)
	mode_label.position = Vector2(-32, -28)
	mode_label.z_index = 10
	add_child(mode_label)
	_update_mode_label()

# -- Pre-stock the storage chest with overflow starting items ------------------
## Stock the storage chest with hive components for testing.
func _stock_starting_chest() -> void:
	var chest: Node = get_tree().get_first_node_in_group("chest")
	if chest == null or not chest.has_method("add_item"):
		return
	# Only stock on a fresh game (no prior inventory synced)
	if GameData.chest_stocked:
		print("[Player] Storage chest already stocked, skipping.")
		return
	# -- Essential tools (player grabs these from the chest via onboarding) --
	chest.add_item(GameData.ITEM_HIVE_TOOL,       1)
	chest.add_item(GameData.ITEM_SMOKER,          1)
	chest.add_item(GameData.ITEM_GLOVES,          1)
	chest.add_item(GameData.ITEM_AXE,             1)
	chest.add_item(GameData.ITEM_HAMMER,          1)
	# -- Harvest tools (needed for first_pull quest) --
	chest.add_item(GameData.ITEM_BUCKET_GRIP,     1)
	chest.add_item(GameData.ITEM_COMB_SCRAPER,    1)
	# -- Mite monitoring (needed for battening_down quest) --
	chest.add_item(GameData.ITEM_WASH_KIT,        1)
	# -- Hive components --
	chest.add_item(GameData.ITEM_DEEP_BODY,       5)
	chest.add_item(GameData.ITEM_SUPER_BOX,       5)
	chest.add_item(GameData.ITEM_FRAMES,         20)
	chest.add_item(GameData.ITEM_QUEEN_EXCLUDER,  1)
	GameData.chest_stocked = true
	print("[Player] Storage chest stocked with tools and hive components.")

# -- Modes ----------------------------------------------------------------------

## Toggle to a new mode (TILL, PLANT, HIVE) or reset to NORMAL if already active.
func _set_mode(new_mode: Mode) -> void:
	current_mode = Mode.NORMAL if current_mode == new_mode else new_mode
	_update_mode_label()
	# Grid overlay follows active item, not mode directly
	_sync_grid_overlay()

## Update the on-screen mode label to reflect current_mode.
func _update_mode_label() -> void:
	if not mode_label:
		return
	var labels: Array = ["Normal", "Till", "Plant", "Hive"]
	mode_label.text = "[%s]" % labels[current_mode]
	mode_label.visible = (current_mode != Mode.NORMAL)

# -- Active Slot ----------------------------------------------------------------

## Switch active hotbar slot and notify HUD.
func _set_active_slot(idx: int) -> void:
	active_slot = clampi(idx, 0, INVENTORY_SIZE - 1)
	_sync_grid_overlay()
	if HUD and HUD.has_method("set_active_slot"):
		HUD.set_active_slot(active_slot)

## Returns the item name in the active slot, or "" if empty.
func get_active_item_name() -> String:
	if active_slot < inventory.size() and inventory[active_slot] != null:
		return inventory[active_slot]["item"]
	return ""

## Show the grid overlay when a placeable item is in the active slot.
## Show grid overlay when a placeable item is in the active slot.
func _sync_grid_overlay() -> void:
	if not grid_overlay:
		grid_overlay = get_node_or_null("../GridOverlay")
	if grid_overlay and "show_grid" in grid_overlay:
		var item := get_active_item_name()
		var is_placeable := (item == GameData.ITEM_HIVE_STAND or item == GameData.ITEM_BEEHIVE)
		grid_overlay.show_grid = is_placeable

# -- HUD Bridge ----------------------------------------------------------------

## Update HUD inventory display and carried item visuals.
func update_hud_inventory() -> void:
	if HUD and HUD.has_method("update_player_inventory"):
		HUD.update_player_inventory(inventory)
	_update_carry_visual()

# -- Carried item visual -------------------------------------------------------

## Set up carry sprites for super box and honey bucket visuals.
func _setup_carry_sprite() -> void:
	# -- Honey super carry sprite --
	_carried_super_sprite = Sprite2D.new()
	_carried_super_sprite.name = "CarriedSuperSprite"
	var path: String = "res://assets/sprites/hive/hive_super.png"
	var abs_path: String = ProjectSettings.globalize_path(path)
	var img: Image = Image.load_from_file(abs_path)
	if img != null:
		_carried_super_sprite.texture = ImageTexture.create_from_image(img)
	_carried_super_sprite.z_index = 3
	_carried_super_sprite.visible = false
	add_child(_carried_super_sprite)

	# -- Honey bucket carry sprite --
	_carried_bucket_sprite = Sprite2D.new()
	_carried_bucket_sprite.name = "CarriedBucketSprite"
	var bkt_path: String = "res://assets/sprites/objects/honey_bucket.png"
	var bkt_abs: String = ProjectSettings.globalize_path(bkt_path)
	var bkt_img: Image = Image.load_from_file(bkt_abs)
	if bkt_img != null:
		_carried_bucket_sprite.texture = ImageTexture.create_from_image(bkt_img)
	_carried_bucket_sprite.z_index = 3
	_carried_bucket_sprite.visible = false
	add_child(_carried_bucket_sprite)

## Update visibility and position of carried item sprites based on inventory.
func _update_carry_visual() -> void:
	# -- Super box --
	if is_instance_valid(_carried_super_sprite):
		var carrying_super: bool = (count_item(GameData.ITEM_FULL_SUPER) > 0
			or count_item(GameData.ITEM_SCRAPED_SUPER) > 0)
		_carried_super_sprite.visible = carrying_super
		if carrying_super:
			_carried_super_sprite.position = facing_direction * 10.0

	# -- Honey bucket --
	if is_instance_valid(_carried_bucket_sprite):
		var carrying_bucket: bool = count_item(GameData.ITEM_HONEY_BUCKET) > 0
		_carried_bucket_sprite.visible = carrying_bucket
		if carrying_bucket:
			# Float slightly lower and to the side of the player (it's heavy)
			_carried_bucket_sprite.position = facing_direction * 10.0 + Vector2(4.0, 4.0)

# -- Inventory -----------------------------------------------------------------

## Add amount of item_name to inventory (fills stacks, then new slots).
## Returns remaining items that did not fit.
func add_item(item_name: String, amount: int) -> int:
	var stack_max := get_max_stack(item_name)
	# Fill existing stacks first.
	for i in range(INVENTORY_SIZE):
		if inventory[i] != null and inventory[i]["item"] == item_name:
			var space: int = stack_max - inventory[i]["count"]
			if space > 0:
				var add: int = mini(space, amount)
				inventory[i]["count"] += add
				amount -= add
				if amount <= 0:
					break
	# Open new slots for any remainder.
	if amount > 0:
		for i in range(INVENTORY_SIZE):
			if inventory[i] == null:
				var add: int = mini(stack_max, amount)
				inventory[i] = {"item": item_name, "count": add}
				amount -= add
				if amount <= 0:
					break
	# Single HUD refresh after all slots are updated.
	update_hud_inventory()
	sync_inventory_to_gamedata()
	return amount

## Remove amount of item_name from inventory. Returns true if successful, false if insufficient.
func consume_item(item_name: String, amount: int) -> bool:
	var total = 0
	for i in range(INVENTORY_SIZE):
		if inventory[i] != null and inventory[i]["item"] == item_name:
			total += inventory[i]["count"]
	if total < amount:
		return false
	for i in range(INVENTORY_SIZE):
		if inventory[i] != null and inventory[i]["item"] == item_name:
			if inventory[i]["count"] >= amount:
				inventory[i]["count"] -= amount
				if inventory[i]["count"] == 0:
					inventory[i] = null
				amount = 0
				break
			else:
				amount -= inventory[i]["count"]
				inventory[i] = null
	update_hud_inventory()
	sync_inventory_to_gamedata()
	return true

func get_item_count(item_name: String) -> int:
	return count_item(item_name)

## Count total number of item_name in inventory across all slots.
func count_item(item_name: String) -> int:
	var total := 0
	for slot in inventory:
		if slot != null and slot["item"] == item_name:
			total += slot["count"]
	return total

## Copy the current inventory array into GameData so it persists across scenes.
func sync_inventory_to_gamedata() -> void:
	GameData.player_inventory = inventory.duplicate(true)
	GameData.player_inventory_valid = true

# -- Movement ------------------------------------------------------------------

@export var base_speed: float = 120.0
@export var base_run_speed: float = 210.0
# Winter Workshop S3: Effective speed is modulated by fatigue.
var speed: float = 120.0
var run_speed: float = 210.0
@onready var animated_sprite = $PlayerAnimatedSprite
@onready var player_sprite: Sprite2D = $PlayerSprite

# Sprite sheet layout: 8 cols x 24 rows of 120x120 frames
# Rows 0-7:  idle (south, SE, E, NE, N, NW, W, SW) -- 1 frame each in col 0
# Rows 8-15: walk (same dir order) -- 8 frames per direction
# Rows 16-23: run (same dir order) -- 8 frames per direction
const _DIR_TO_ROW := {
	"south": 0, "south_east": 1, "east": 2, "north_east": 3,
	"north": 4, "north_west": 5, "west": 6, "south_west": 7,
}
var _anim_frame_timer: float = 0.0
var _anim_frame_index: int = 0
const _WALK_FPS := 8.0
const _RUN_FPS := 10.0
const _SHEET_COLS := 8
var _current_dir_name: String = "south"
var _is_moving: bool = false
var _is_running: bool = false

# -- Fatigue System (Winter Workshop S3) --------------------------------------
# Tracks idle time for fatigue idle animations (stretch, yawn, sit).
var _idle_timer: float = 0.0
var _fatigue_idle_played: bool = false  # True if a fatigue idle has fired this idle period

## Updates walk/run speed based on current energy level.
## Called each physics frame -- cheap branch, no allocation.
func _update_fatigue_speed() -> void:
	var pct: float = GameData.energy / GameData.max_energy
	var modifier: float = 1.0
	if pct < 0.10:
		modifier = 0.0  # Cannot perform active tasks; can still walk slowly
		speed = base_speed * 0.5
		run_speed = base_speed * 0.5  # no running when exhausted
		return
	elif pct < 0.25:
		modifier = 0.70  # -30% speed
	elif pct < 0.50:
		modifier = 0.80  # -20% speed
	elif pct < 0.70:
		modifier = 0.90  # -10% speed
	else:
		modifier = 1.0
	speed = base_speed * modifier
	run_speed = base_run_speed * modifier

const HIVE_SCENE   = preload("res://scenes/hive.tscn")
const FLOWER_SCENE = preload("res://scenes/flowers/flowers.tscn")
var _chest_script: GDScript = null

@onready var tilemap:      TileMap = get_node_or_null("../TileMap")
@onready var grid_overlay          = get_node_or_null("../GridOverlay")

## Signal handler: resync grid overlay when dev labels toggle.
func _on_dev_labels_toggled(_visible: bool) -> void:
	_sync_grid_overlay()

# -- Input ---------------------------------------------------------------------

## Returns true if a blocking overlay (inspection, shop, pause, etc.) is active.
## Return true if a blocking overlay (inspection, shop, pause) is open.
func _is_ui_blocking() -> bool:
	if get_tree().paused:
		return true
	if get_tree().get_first_node_in_group("inspection_overlay"):
		return true
	return false

func _input(event: InputEvent) -> void:
	# -- Mouse wheel: cycle active hotbar slot ----------------------------------
	if event is InputEventMouseButton and event.pressed:
		if _is_ui_blocking():
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_active_slot((active_slot - 1 + INVENTORY_SIZE) % INVENTORY_SIZE)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_active_slot((active_slot + 1) % INVENTORY_SIZE)
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Journal (J) works even during inspection -- overlay renders above it
	if event.keycode == KEY_J:
		_open_journal()
		return
	if _is_ui_blocking():
		return
	match event.keycode:
		KEY_T: _set_mode(Mode.TILL)
		KEY_F: _set_mode(Mode.PLANT)
		KEY_0:
			current_mode = Mode.NORMAL
			_update_mode_label()
		KEY_E: _perform_action()
		KEY_R: _action_rotate_boxes()
		KEY_Z: _action_sleep()
		# Number keys 1-9 and 0->slot 10 for direct hotbar access
		KEY_1: _set_active_slot(0)
		KEY_2: _set_active_slot(1)
		KEY_3: _set_active_slot(2)
		KEY_4: _set_active_slot(3)
		KEY_5: _set_active_slot(4)
		KEY_6: _set_active_slot(5)
		KEY_7: _set_active_slot(6)
		KEY_8: _set_active_slot(7)
		KEY_9: _set_active_slot(8)

# -- Journal -------------------------------------------------------------------

## Called when the inspection overlay closes. Resets smoker state.
func _on_inspection_closed() -> void:
	_smoker_active = false
	_smoker_puffs = 0

## Open the knowledge log journal overlay.
func _open_journal() -> void:
	# Don't open if already open
	var existing: Array = get_tree().get_nodes_in_group("knowledge_log_overlay")
	if existing.size() > 0:
		return
	var script: GDScript = load("res://scripts/ui/knowledge_log_overlay.gd") as GDScript
	if script == null:
		return
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.set_script(script)
	overlay.add_to_group("knowledge_log_overlay")
	get_tree().current_scene.add_child(overlay)
	# Consume the event so the overlay's _unhandled_key_input doesn't
	# immediately see this same J press and queue_free() itself.
	get_viewport().set_input_as_handled()

# -- Actions -------------------------------------------------------------------
#
# Context-first design: nearby interactables always take priority over the
# current placement mode or active item.
#
# Priority order:
#   0. Harvest Yard stations (outdoor processing)
#   1. Merchant   (within INTERACT_RADIUS)
#   2. Hive       (within INTERACT_RADIUS) -> inspect (complete) or build (incomplete)
#   3. Uncle Bob  (within INTERACT_RADIUS) -> tutorial hints
#   4. Flower     (within INTERACT_RADIUS) -> harvest seeds
#   5. Active item / mode action (nothing nearby)
# -----------------------------------------------------------------------------

const INTERACT_RADIUS := 64.0

## Execute action in the direction the player is facing (E key).
func _perform_action() -> void:
	# -- 0. Harvest Yard removed (Winter Workshop S2) --------------------------
	# All extraction now happens inside the Honey House interior scene.

	# -- 1. Merchant -----------------------------------------------------------
	var nearby_merchant := _closest_in_group("merchant", INTERACT_RADIUS)
	if nearby_merchant and nearby_merchant.has_method("open_shop"):
		nearby_merchant.open_shop()
		return

	# -- 1b. Storage Chest -----------------------------------------------------
	var nearby_chest := _closest_in_group("chest", INTERACT_RADIUS)
	if nearby_chest and nearby_chest.has_method("open_storage"):
		nearby_chest.open_storage()
		return

	# -- 1c. Place chest from inventory ----------------------------------------
	if get_active_item_name() == GameData.ITEM_CHEST and nearby_chest == null:
		_action_place_chest()
		return

	# -- 1d. Pick up empty feeder bucket or place new one ---------------------
	var nearby_feeder := _closest_in_group("feeder_bucket", INTERACT_RADIUS)
	if nearby_feeder and nearby_feeder.has_method("try_pickup") and nearby_feeder.try_pickup():
		# Try refill first if player has sugar syrup
		if count_item(GameData.ITEM_SUGAR_SYRUP) > 0 and nearby_feeder.has_method("try_refill"):
			nearby_feeder.try_refill(self)
			return
		add_item(GameData.ITEM_FEEDER_BUCKET, 1)
		nearby_feeder.remove_feeder()
		update_hud_inventory()
		var nm_f = get_tree().root.get_node_or_null("NotificationManager")
		if nm_f and nm_f.has_method("notify"):
			nm_f.notify("Picked up empty barrel feeder.")
		return
	if get_active_item_name() == GameData.ITEM_FEEDER_BUCKET:
		_action_place_barrel_feeder()
		return

	# -- 2. Hive -- inspect complete, or continue building incomplete ----------
	var nearby_hive := _closest_in_group("hive", INTERACT_RADIUS)
	if nearby_hive and nearby_hive.has_method("open_inspection"):
		# is_build_complete() is present on build-system hives; legacy hives lack it -> treat as complete
		var complete: bool = (not nearby_hive.has_method("is_build_complete")) or nearby_hive.is_build_complete()
		if complete:
			var held := get_active_item_name()
			var has_colony: bool = (not nearby_hive.has_method("has_colony")) or nearby_hive.has_colony()

			# Gloves and box management work on any completed hive (empty or full)
			print("[Player] E near hive: held='%s' GLOVES='%s' match=%s" % [held, GameData.ITEM_GLOVES, held == GameData.ITEM_GLOVES])
			if held == GameData.ITEM_GLOVES:
				print("[Player] Opening hive management overlay...")
				_open_hive_management(nearby_hive)
				return
			# Accept either deep_body or deep_box for adding a second deep
			var is_deep_item: bool = (held == GameData.ITEM_DEEP_BOX or held == GameData.ITEM_DEEP_BODY)
			print("[Player] held='%s' is_deep=%s has_try_add_deep=%s" % [held, is_deep_item, nearby_hive.has_method("try_add_deep")])
			if is_deep_item and nearby_hive.has_method("try_add_deep"):
				if consume_item(held, 1):
					var result: bool = nearby_hive.try_add_deep()
					print("[Player] try_add_deep returned: %s" % result)
					update_hud_inventory()
					var nm = get_tree().root.get_node_or_null("NotificationManager")
					if nm and nm.has_method("notify"):
						nm.notify("Second deep body added -- more room for brood!")
				else:
					print("No deep body in inventory!")
				return
			# Super box works on any completed hive too
			if held == GameData.ITEM_SUPER_BOX and nearby_hive.has_method("try_add_super"):
				if consume_item(GameData.ITEM_SUPER_BOX, 1):
					nearby_hive.try_add_super()
					update_hud_inventory()
					var nm = get_tree().root.get_node_or_null("NotificationManager")
					if nm and nm.has_method("notify"):
						nm.notify("Honey super added -- bees will fill it with nectar!")
				else:
					print("No honey super in inventory!")
				return
			# Queen excluder works on any completed hive
			if held == GameData.ITEM_QUEEN_EXCLUDER and nearby_hive.has_method("try_add_excluder"):
				if consume_item(GameData.ITEM_QUEEN_EXCLUDER, 1):
					nearby_hive.try_add_excluder()
					update_hud_inventory()
					var nm = get_tree().root.get_node_or_null("NotificationManager")
					if nm and nm.has_method("notify"):
						nm.notify("Queen excluder placed -- queen confined to brood boxes")
				else:
					print("No queen excluder in inventory!")
				return

			# Winterization during Deepcold (Winter Workshop S4)
			# Any winterization item held near a colonized hive opens the UI
			var _winter_items := [
				GameData.ITEM_ENTRANCE_REDUCER, GameData.ITEM_MOUSE_GUARD,
				GameData.ITEM_MOISTURE_QUILT, GameData.ITEM_HIVE_WRAP,
				GameData.ITEM_TOP_INSULATION, GameData.ITEM_CANDY_BOARD,
				GameData.ITEM_VENT_SHIM]
			if has_colony and held in _winter_items:
				if TimeManager and TimeManager.current_season_name() == "Winter":
					_open_winterization(nearby_hive)
				else:
					var nm_wz = get_tree().root.get_node_or_null("NotificationManager")
					if nm_wz and nm_wz.has_method("notify"):
						nm_wz.notify("Winterization is done during Deepcold or Kindlemonth.")
				return

			# Install colony if no bees yet
			if not has_colony:
				if held == GameData.ITEM_PACKAGE_BEES:
					if consume_item(GameData.ITEM_PACKAGE_BEES, 1):
						nearby_hive.install_colony()
						update_hud_inventory()
						QuestManager.notify_event("colony_installed", {"hive": nearby_hive})
						if KnowledgeLog and KnowledgeLog.has_method("unlock_entry"):
							KnowledgeLog.unlock_entry("bee_biology")
							KnowledgeLog.unlock_entry("hive_components")
						var nm_c = get_tree().root.get_node_or_null("NotificationManager")
						if nm_c and nm_c.has_method("notify"):
							nm_c.notify("Colony installed! Bees are now active in this hive.")
					else:
						var nm_c2 = get_tree().root.get_node_or_null("NotificationManager")
						if nm_c2 and nm_c2.has_method("notify"):
							nm_c2.notify("No Package Bees in inventory!")
				else:
					var nm_c3 = get_tree().root.get_node_or_null("NotificationManager")
					if nm_c3 and nm_c3.has_method("notify"):
						nm_c3.notify("Select Package Bees to install a colony!")
				return
			# Check 7-day establishment lockout for inspection actions
			var can_inspect: bool = (not nearby_hive.has_method("can_inspect")) or nearby_hive.can_inspect()
			if not can_inspect:
				var nm0 = get_tree().root.get_node_or_null("NotificationManager")
				if nm0 and nm0.has_method("notify"):
					nm0.notify("Colony is still establishing -- give them a few more days!")
				else:
					print("Colony is still establishing -- give them a few more days!")
				return
			# Check weather -- some conditions prevent hive inspection (GDD S6.9 / task 2.8)
			if WeatherManager and not WeatherManager.can_inspect():
				var weather_msg: String = "Can't open hives right now!"
				match WeatherManager.current_weather:
					"Rainy": weather_msg = "Too wet to open hives -- wait for dry weather!"
					"Cold":  weather_msg = "Too cold to inspect -- bees are clustered!"
				var nm_w = get_tree().root.get_node_or_null("NotificationManager")
				if nm_w and nm_w.has_method("notify"):
					nm_w.notify(weather_msg, "warn")
				else:
					print(weather_msg)
				return
			# Remove a fully-marked super for harvest transport
			if nearby_hive.has_method("has_marked_super") and nearby_hive.has_marked_super():
				# Winter reserve check (GDD S5.3.3): warn if removing super in fall might leave
				# colony short for winter. Minimum safe winter stores: ~60 lbs (or ~30 lbs as
				# a lean-winter minimum).
				var current_season: String = TimeManager.current_season_name()
				if current_season == "Fall":
					# Check colony honey_stores in the hive simulation
					var colony_stores: float = 0.0
					if nearby_hive.has_method("get_honey_stores"):
						colony_stores = nearby_hive.get_honey_stores()
					elif "honey_stores" in nearby_hive:
						colony_stores = nearby_hive.honey_stores
					var MIN_WINTER_STORES: float = 60.0
					if colony_stores < MIN_WINTER_STORES:
						var nm_warn = get_tree().root.get_node_or_null("NotificationManager")
						if nm_warn and nm_warn.has_method("notify"):
							nm_warn.notify("Warning: colony only has %.0f lbs honey -- 60 lbs needed for winter!" % colony_stores, "warn")
				var removed = nearby_hive.remove_marked_super()
				if removed != null:
					# Store actual frame cell data for honey house / harvest yard
					GameData.harvested_super_frames.clear()
					if "frames" in removed:
						for fr in removed.frames:
							GameData.harvested_super_frames.append({
								"cells_a": fr.cells.duplicate(),
								"cells_b": fr.cells_b.duplicate(),
								"cols": fr.grid_cols,
								"rows": fr.grid_rows,
							})
					add_item(GameData.ITEM_FULL_SUPER, 1)
					update_hud_inventory()
					var nm = get_tree().root.get_node_or_null("NotificationManager")
					if nm and nm.has_method("notify"):
						nm.notify("Super removed -- take it to the Honey House!")
				return
			# -- Smoker: smoke the hive before opening (pre-inspection action) --
			if held == GameData.ITEM_SMOKER:
				if _smoker_active:
					var nm_already = get_tree().root.get_node_or_null("NotificationManager")
					if nm_already and nm_already.has_method("notify"):
						nm_already.notify("Hive already smoked. Select the Hive Tool to inspect.")
				else:
					_smoker_active = true
					_smoker_puffs = 3
					var nm_s = get_tree().root.get_node_or_null("NotificationManager")
					if nm_s and nm_s.has_method("notify"):
						nm_s.notify("Hive smoked -- bees calmed! Now use the Hive Tool to inspect.")
				return
			# -- Hive tool: open inspection --
			if held != GameData.ITEM_HIVE_TOOL:
				var nm1 = get_tree().root.get_node_or_null("NotificationManager")
				if nm1 and nm1.has_method("notify"):
					nm1.notify("Select the Hive Tool (or Smoker) in your toolbar!")
				else:
					print("Select the Hive Tool (or Smoker) in your toolbar!")
				return
			if GameData.energy >= 10.0:
				nearby_hive.open_inspection()
				# Connect inspection overlay's closed signal to reset smoker state
				var overlay = get_tree().get_first_node_in_group("inspection_overlay")
				if overlay and overlay.has_signal("closed"):
					if not overlay.closed.is_connected(_on_inspection_closed):
						overlay.closed.connect(_on_inspection_closed)
				# Pass smoker state to the inspection overlay for sting calculations
				if overlay and overlay.has_method("set_smoker_state"):
					overlay.set_smoker_state(_smoker_active)
			else:
				var nm2 = get_tree().root.get_node_or_null("NotificationManager")
				if nm2 and nm2.has_method("notify"):
					nm2.notify("Too tired to inspect -- need 10 energy!")
				else:
					push_warning("Too tired to inspect -- energy: %d" % int(GameData.energy))
		else:
			_try_build_hive(nearby_hive)
		return

	# -- 3a. Honey House ruin examination --------------------------------------
	var nearby_ruin := _closest_in_group("honey_house_ruin", INTERACT_RADIUS)
	if nearby_ruin and nearby_ruin.has_method("interact"):
		nearby_ruin.interact()
		return

	# -- 3. NPCs (talk / quest interaction) ------------------------------------
	var nearby_npc: Node = null
	for npc_group in [
		"uncle_bob", "darlene_kowalski", "silas_crenshaw",
		"carl_tanner", "rose_delacroix", "june_wellman",
		"ellen_harwick", "frank_fischbach",
	]:
		var candidate := _closest_in_group(npc_group, INTERACT_RADIUS)
		if candidate and candidate.has_method("interact"):
			if nearby_npc == null:
				nearby_npc = candidate
			else:
				# Pick the closer one
				var d_new: float = (candidate as Node2D).global_position.distance_to(global_position)
				var d_old: float = (nearby_npc as Node2D).global_position.distance_to(global_position)
				if d_new < d_old:
					nearby_npc = candidate
	if nearby_npc:
		nearby_npc.interact()
		return

	# -- 4. Flower (harvest seeds) ---------------------------------------------
	var nearby_flower := _closest_in_group("flowers", INTERACT_RADIUS)
	if nearby_flower and nearby_flower.has_method("harvest_seeds"):
		var seeds: int = nearby_flower.harvest_seeds()
		if seeds > 0:
			add_item(GameData.ITEM_SEEDS, seeds)
		return

	# -- 5. Active item placement or mode action -------------------------------
	var active_item := get_active_item_name()
	match active_item:
		GameData.ITEM_HIVE_STAND:
			_action_place_stand()
		GameData.ITEM_BEEHIVE:
			_action_place_hive()
		GameData.ITEM_DEEP_BODY, GameData.ITEM_FRAMES, GameData.ITEM_LID:
			print("No incomplete hive nearby! Approach a hive stand or body first.")
		_:
			# Legacy mode actions (till, plant)
			match current_mode:
				Mode.TILL:  _action_till()
				Mode.PLANT: _action_plant()
				_: pass

## Try to advance the build state of a nearby incomplete hive using the active item.
## Uses duck typing -- no Hive class reference so player.gd parses cleanly.
func _try_build_hive(h) -> void:
	var active_item := get_active_item_name()
	# is_stand_only() -> STAND_PLACED; otherwise assume BODY_ADDED or FRAMES_PARTIAL
	if h.has_method("is_stand_only") and h.is_stand_only():
		if active_item == GameData.ITEM_DEEP_BODY:
			if consume_item(GameData.ITEM_DEEP_BODY, 1):
				h.try_add_body()
				update_hud_inventory()
			else:
				print("No deep body in inventory!")
		else:
			print("Place a deep body on the stand first! (select Deep Body in hotbar)")
	else:
		# BODY_ADDED or FRAMES_PARTIAL -- needs frames (and then lid once at 10)
		if active_item == GameData.ITEM_FRAMES:
			var available := count_item(GameData.ITEM_FRAMES)
			if available <= 0:
				print("No frames in inventory!")
				return
			var placed: int = h.try_add_frames(available)
			if placed > 0:
				consume_item(GameData.ITEM_FRAMES, placed)
				update_hud_inventory()
				print("Added %d frames (%d/10 total)" % [placed, h.get("frame_count")])
		elif active_item == GameData.ITEM_LID:
			var frames_in_hive: int = h.get("frame_count")
			if frames_in_hive < 10:
				print("Need 10 frames before placing the lid! (%d/10 in)" % frames_in_hive)
				return
			if consume_item(GameData.ITEM_LID, 1):
				h.try_add_lid()
				update_hud_inventory()
				print("Lid placed -- hive is complete and ready for a colony!")
			else:
				print("No lid in inventory!")
		else:
			var frames_in_hive: int = h.get("frame_count")
			if frames_in_hive < 10:
				print("Select Frames in hotbar to fill the box (%d/10 in)" % frames_in_hive)
			else:
				print("10 frames loaded -- select Lid in hotbar to complete the hive")

## Open the Hive Management UI overlay (requires Gloves active).
func _open_hive_management(hive_node: Node) -> void:
	# Prevent opening if already open
	if get_tree().get_first_node_in_group("hive_management_overlay"):
		print("[Player] Hive management already open, skipping")
		return
	var scene: PackedScene = load("res://scenes/ui/hive_management.tscn") as PackedScene
	if scene == null:
		push_error("[Player] Could not load hive_management.tscn!")
		return
	var overlay: Node = scene.instantiate()
	overlay.set("hive_ref", hive_node)
	get_tree().root.add_child(overlay)
	print("[Player] Hive management overlay opened successfully")

## Open the Winterization UI overlay (Winter Workshop S4).
func _open_winterization(hive_node: Node) -> void:
	if get_tree().get_first_node_in_group("winterization_overlay"):
		return
	var wui_script: GDScript = load("res://scripts/ui/winterization_ui.gd") as GDScript
	if wui_script == null:
		push_error("[Player] Could not load winterization_ui.gd!")
		return
	var overlay: Node = CanvasLayer.new()
	overlay.set_script(wui_script)
	overlay.set("target_hive", hive_node)
	overlay.add_to_group("winterization_overlay")
	get_tree().root.add_child(overlay)

## Place a storage chest at the player's facing tile.
func _action_place_chest() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	if not consume_item(GameData.ITEM_CHEST, 1):
		print("No chest in inventory!")
		return
	if _chest_script == null:
		_chest_script = load("res://scripts/world/chest.gd") as GDScript
	if _chest_script == null:
		print("ERROR: Could not load chest.gd!")
		return
	var chest_node := Node2D.new()
	chest_node.set_script(_chest_script)
	get_parent().add_child(chest_node)
	chest_node.global_position = tilemap.to_global(tilemap.map_to_local(map_coords))
	update_hud_inventory()

var _barrel_feeder_script: GDScript = null

func _action_place_barrel_feeder() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	if not consume_item(GameData.ITEM_FEEDER_BUCKET, 1):
		var nm_bf = get_tree().root.get_node_or_null("NotificationManager")
		if nm_bf and nm_bf.has_method("notify"):
			nm_bf.notify("No barrel feeder in inventory!")
		return
	if _barrel_feeder_script == null:
		_barrel_feeder_script = load("res://scripts/world/barrel_feeder.gd") as GDScript
	if _barrel_feeder_script == null:
		print("ERROR: Could not load barrel_feeder.gd!")
		return
	var feeder_node := Node2D.new()
	feeder_node.set_script(_barrel_feeder_script)
	get_parent().add_child(feeder_node)
	feeder_node.global_position = tilemap.to_global(tilemap.map_to_local(map_coords))
	feeder_node.notify_placed()
	update_hud_inventory()
	var nm_bf2 = get_tree().root.get_node_or_null("NotificationManager")
	if nm_bf2 and nm_bf2.has_method("notify"):
		nm_bf2.notify("Barrel feeder placed! 100 NU/day for 10 days.")

## Rotate deep bodies in a nearby hive (R key). Moves bottom deep to top.
## Requires hive tool selected and a hive with 2+ deeps nearby.
func _action_rotate_boxes() -> void:
	var nearby_hive := _closest_in_group("hive", INTERACT_RADIUS)
	if nearby_hive == null:
		return
	if get_active_item_name() != GameData.ITEM_HIVE_TOOL:
		return
	if not nearby_hive.has_method("can_rotate_deeps") or not nearby_hive.can_rotate_deeps():
		return
	if nearby_hive.has_method("try_rotate_deeps") and nearby_hive.try_rotate_deeps():
		var nm = get_tree().root.get_node_or_null("NotificationManager")
		if nm and nm.has_method("notify"):
			nm.notify("Boxes rotated -- bottom deep moved to top!")

func _action_till() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	tilemap.set_cell(1, map_coords, 0, Vector2i(1, 3))
	_set_mode(Mode.NORMAL)

func _action_plant() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	if tilemap.get_cell_source_id(1, map_coords) != -1:
		if consume_item(GameData.ITEM_SEEDS, 1):
			var new_flower = FLOWER_SCENE.instantiate()
			new_flower.global_position = tilemap.to_global(tilemap.map_to_local(map_coords))
			get_parent().add_child(new_flower)
			update_hud_inventory()
			_set_mode(Mode.NORMAL)
		else:
			print("Not enough seeds!")
	else:
		print("You must plant seeds on tilled dirt!")

func _hive_placement_valid(map_coords: Vector2i) -> bool:
	for h in get_tree().get_nodes_in_group("hive"):
		var hive_tile: Vector2i
		if h.has_meta("tile_coords"):
			hive_tile = h.get_meta("tile_coords")
		else:
			hive_tile = tilemap.local_to_map(tilemap.to_local(h.global_position))
		if maxi(absi(map_coords.x - hive_tile.x), absi(map_coords.y - hive_tile.y)) <= 2:
			return false
	return true

## Place a bare hive stand (starts STAND_PLACED build state).
func _action_place_stand() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	if not _hive_placement_valid(map_coords):
		print("Too close to another hive! Hives need a 5x5 space.")
		return
	if not consume_item(GameData.ITEM_HIVE_STAND, 1):
		print("No hive stand in inventory!")
		return
	var new_hive = HIVE_SCENE.instantiate()
	get_parent().add_child(new_hive)
	new_hive.global_position = tilemap.to_global(tilemap.map_to_local(map_coords))
	new_hive.set_meta("tile_coords", map_coords)
	# build_state starts as STAND_PLACED (default in hive.gd)
	update_hud_inventory()
	_sync_grid_overlay()

## Place a complete legacy hive (ITEM_BEEHIVE -- all-in-one, fully operational).
func _action_place_hive() -> void:
	if not tilemap:
		return
	var map_coords = get_target_tile_coords(tilemap)
	if not _hive_placement_valid(map_coords):
		print("Too close to another hive! Hives need a 5x5 space.")
		return
	if not consume_item(GameData.ITEM_BEEHIVE, 1):
		print("No hive bodies in inventory! Pick some up at Cedar Bend Feed & Supply.")
		return
	var new_hive = HIVE_SCENE.instantiate()
	get_parent().add_child(new_hive)
	new_hive.global_position = tilemap.to_global(tilemap.map_to_local(map_coords))
	new_hive.set_meta("tile_coords", map_coords)
	# Legacy hive is a fully operational overwintered colony (Carniolan S benchmark).
	# place_as_overwintered() sets up 4 drawn frames, small spring brood nest,
	# adequate stores, and a 1-year-old queen -- realistic spring Day 1 start.
	if new_hive.has_method("place_as_overwintered"):
		new_hive.place_as_overwintered()
	elif new_hive.has_method("place_as_complete"):
		new_hive.place_as_complete()
	update_hud_inventory()
	_sync_grid_overlay()

# -- Sleep / Advance Day --------------------------------------------------------

func _action_sleep() -> void:
	if get_tree().get_first_node_in_group("inspection_overlay"):
		return
	if HUD and HUD.has_method("_show_daily_summary"):
		HUD._show_daily_summary()
	else:
		TimeManager.start_new_day()
		GameData.full_restore_energy()

func _closest_in_group(group: String, max_dist: float) -> Node:
	var all_nodes := get_tree().get_nodes_in_group(group)
	var best: Node = null
	var best_dist: float = INF
	for node in all_nodes:
		if not (node is Node2D):
			continue
		var d: float = (node as Node2D).global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = node
	if best != null and best_dist <= max_dist:
		return best
	return null

func get_target_tile_coords(map: TileMap) -> Vector2i:
	var player_feet_local = map.to_local(global_position)
	var current_tile = map.local_to_map(player_feet_local)
	return current_tile + facing_dir_8

func _physics_process(delta):
	if _is_ui_blocking():
		velocity = Vector2.ZERO
		return

	# Winter Workshop S3: Update speed based on fatigue each frame
	_update_fatigue_speed()

	var input_vector = Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_vector.x -= 1
	if Input.is_key_pressed(KEY_D): input_vector.x += 1
	if Input.is_key_pressed(KEY_W): input_vector.y -= 1
	if Input.is_key_pressed(KEY_S): input_vector.y += 1

	var is_running: bool = Input.is_key_pressed(KEY_SHIFT)
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = input_vector * (run_speed if is_running else speed)
		play_animation(input_vector, is_running)
		_idle_timer = 0.0
		_fatigue_idle_played = false
	else:
		velocity = Vector2.ZERO
		_idle_timer += delta
		# Winter Workshop S3: Fatigue idle behaviors based on energy
		_check_fatigue_idle()
		_play_idle()

	_advance_anim_timer(delta)
	move_and_slide()
	# Keep carried item floating in front as player moves/turns
	_update_carry_visual()

func play_animation(direction: Vector2, running: bool = false) -> void:
	var sx: int = int(sign(direction.x))
	var sy: int = int(sign(direction.y))
	var ax: float = absf(direction.x)
	var ay: float = absf(direction.y)
	if ax > ay * 2.0:
		sy = 0
	elif ay > ax * 2.0:
		sx = 0
	facing_dir_8 = Vector2i(sx, sy)
	facing_direction = Vector2.RIGHT if sx > 0 else (Vector2.LEFT if sx < 0 else (Vector2.DOWN if sy > 0 else Vector2.UP))
	var dir_name := _direction_name_from_signs(sx, sy)
	var was_moving := _is_moving
	var old_dir := _current_dir_name
	var old_running := _is_running
	_current_dir_name = dir_name
	_is_moving = true
	_is_running = running
	if dir_name != old_dir or running != old_running or not was_moving:
		_anim_frame_index = 0
		_anim_frame_timer = 0.0
	_update_sprite_frame()

## Winter Workshop S3: Fatigue idle behavior check.
## Fires stretch/yawn/sit-down animations based on energy + idle time.
## Animation states are placeholders using print() until art is created.
func _check_fatigue_idle() -> void:
	if _fatigue_idle_played:
		return
	var pct: float = GameData.energy / GameData.max_energy
	# 10-24 energy: sit down after 5 seconds idle
	if pct < 0.25 and pct >= 0.10 and _idle_timer >= 5.0:
		_fatigue_idle_played = true
		# TODO: Play sit-down animation when art is ready
		print("[Fatigue] Player sits down (energy %d%%)" % int(pct * 100))
	# 25-49 energy: yawn after 3 seconds idle
	elif pct < 0.50 and pct >= 0.25 and _idle_timer >= 3.0:
		_fatigue_idle_played = true
		# TODO: Play yawning animation when art is ready
		print("[Fatigue] Player yawns (energy %d%%)" % int(pct * 100))
	# 50-69 energy: stretch after 4 seconds idle
	elif pct < 0.70 and pct >= 0.50 and _idle_timer >= 4.0:
		_fatigue_idle_played = true
		# TODO: Play stretch animation when art is ready
		print("[Fatigue] Player stretches (energy %d%%)" % int(pct * 100))
	# 0-9 energy: immediate sit-down
	elif pct < 0.10 and _idle_timer >= 1.0:
		_fatigue_idle_played = true
		print("[Fatigue] Player exhausted -- sits down")

## Winter Workshop S3: Check if the player should be warned before a heavy task.
## Returns true if the task should proceed; false if blocked (energy 0-9).
## For energy 10-24, shows a dialogue prompt but still returns true.
func check_fatigue_for_task(task_name: String, energy_cost: float) -> bool:
	var pct: float = GameData.energy / GameData.max_energy
	if pct < 0.10:
		# Cannot perform active tasks at 0-9 energy
		var dialogue_ui: Node = get_tree().root.get_node_or_null("DialogueUI")
		if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
			dialogue_ui.show_dialogue("", [
				"You're exhausted. Time to rest.",
				"You can still walk around and talk to people, but no heavy work."
			])
		return false
	elif pct < 0.25:
		# Warn but allow
		var dialogue_ui: Node = get_tree().root.get_node_or_null("DialogueUI")
		if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
			dialogue_ui.show_dialogue("", [
				"You're worn out. Maybe call it a day?",
				"(%s will cost %d energy)" % [task_name, int(energy_cost)]
			])
	return true

func _play_idle() -> void:
	_is_moving = false
	_anim_frame_index = 0
	_anim_frame_timer = 0.0
	_update_sprite_frame()

# -- Sprite2D frame helpers ----------------------------------------------------

func _direction_name_from_signs(sx: int, sy: int) -> String:
	var v := ""
	var h := ""
	if sy > 0: v = "south"
	elif sy < 0: v = "north"
	if sx > 0: h = "east"
	elif sx < 0: h = "west"
	if v != "" and h != "":
		return v + "_" + h
	elif v != "":
		return v
	elif h != "":
		return h
	return "south"

func _advance_anim_timer(delta: float) -> void:
	if not _is_moving:
		return
	var fps: float = _RUN_FPS if _is_running else _WALK_FPS
	_anim_frame_timer += delta
	if _anim_frame_timer >= 1.0 / fps:
		_anim_frame_timer -= 1.0 / fps
		_anim_frame_index = (_anim_frame_index + 1) % _SHEET_COLS
		_update_sprite_frame()

func _update_sprite_frame() -> void:
	if not player_sprite:
		return
	var dir_row: int = _DIR_TO_ROW.get(_current_dir_name, 0)
	var row: int
	var col: int
	if not _is_moving:
		row = dir_row
		col = 0
	elif _is_running:
		row = 16 + dir_row
		col = _anim_frame_index
	else:
		row = 8 + dir_row
		col = _anim_frame_index
	player_sprite.frame = row * _SHEET_COLS + col

# -- Sting Mechanics (GDD S6.5) ------------------------------------------------

## Called when