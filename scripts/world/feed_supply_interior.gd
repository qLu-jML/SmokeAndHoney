# feed_supply_interior.gd -- Tanner's Feed & Supply interior.
# GDD S13.3: Shop with seasonal stock, bulletin board, Carl Tanner NPC.
# Sells bee packages, frames, supers, treatments, and equipment.
# Seasonal stock: Spring = packages/seeds/feeders, Summer = treatments/supers,
#   Fall = winter prep supplies, Winter = reduced stock.
extends Node2D

# -- Shop Catalog --------------------------------------------------------------
# Each item: key, label, cost, seasons (empty = always), item_constant, count
const ALL_ITEMS: Array = [
	# Core equipment -- always in stock
	{
		"key": "frames",
		"label": "Frames (set of 10)",
		"cost": 24.0,
		"item": "frames",
		"qty": 10,
		"seasons": [],
		"desc": "Standard Langstroth deep frames.",
	},
	{
		"key": "super_box",
		"label": "Honey Super (empty)",
		"cost": 35.0,
		"item": "super_box",
		"qty": 1,
		"seasons": [],
		"desc": "Medium super box, 10-frame.",
	},
	{
		"key": "repair_kit",
		"label": "Repair Kit",
		"cost": 25.0,
		"item": "",
		"qty": 0,
		"seasons": [],
		"desc": "+20 hive condition. Restores worn equipment.",
		"special": "repair_kit",
	},
	{
		"key": "jars",
		"label": "Honey Jars (case of 12)",
		"cost": 14.0,
		"item": "jar",
		"qty": 12,
		"seasons": [],
		"desc": "Half-pint glass jars for bottling.",
	},
	# Spring stock
	{
		"key": "bee_package",
		"label": "Bee Package (3 lb + queen)",
		"cost": 185.0,
		"item": "queen_cage",
		"qty": 1,
		"seasons": ["Spring"],
		"desc": "Local stock, better queen grades.",
	},
	{
		"key": "nucleus",
		"label": "Nucleus Colony (5-frame nuc)",
		"cost": 245.0,
		"item": "beehive",
		"qty": 1,
		"seasons": ["Spring"],
		"desc": "Established colony. Faster start.",
	},
	{
		"key": "syrup_feeder",
		"label": "Hive-Top Feeder",
		"cost": 12.0,
		"item": "syrup_feeder",
		"qty": 1,
		"seasons": ["Spring", "Fall"],
		"desc": "For sugar syrup stimulative feeding.",
	},
	{
		"key": "swarm_trap",
		"label": "Swarm Trap",
		"cost": 28.0,
		"item": "swarm_trap",
		"qty": 1,
		"seasons": ["Spring", "Summer"],
		"desc": "Catch swarms. Set in trees near apiary.",
	},
	# Summer / treatment stock
	{
		"key": "oxalic",
		"label": "Oxalic Acid Treatment",
		"cost": 18.0,
		"item": "treatment_oxalic",
		"qty": 1,
		"seasons": ["Summer", "Fall", "Winter"],
		"desc": "High-efficacy mite treatment. Broodless periods.",
	},
	{
		"key": "formic",
		"label": "Formic Acid Pads",
		"cost": 22.0,
		"item": "treatment_formic",
		"qty": 1,
		"seasons": ["Summer", "Fall"],
		"desc": "Penetrates capped brood. Temperature-dependent.",
	},
	# Fall / winter prep
	{
		"key": "queen_cage",
		"label": "Mated Queen",
		"cost": 38.0,
		"item": "queen_cage",
		"qty": 1,
		"seasons": ["Spring", "Summer"],
		"desc": "Candy-plug cage. 3-5 day acceptance.",
	},
]

const INTERACT_RADIUS := 52.0
const BULLETIN_RADIUS := 48.0

@onready var carl_npc:       Node2D = $World/NPCs/CarlTanner
@onready var bulletin_board: Node2D = $World/Props/BulletinBoard
@onready var shop_ui:        CanvasLayer = $ShopUI
@onready var bulletin_ui:    CanvasLayer = $BulletinUI
@onready var shop_hint:      Label  = $World/NPCs/CarlTanner/InteractHint
@onready var board_hint:     Label  = $World/Props/BulletinBoard/InteractHint

var _shop_open:     bool = false
var _bulletin_open: bool = false
var _shop_btns:     Array = []

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	TimeManager.current_scene_id = "feed_supply_interior"
	if get_node_or_null("/root/SceneManager"):
		SceneManager.current_zone_name = "Tanner's Feed & Supply"
		SceneManager.show_zone_name()
		SceneManager.clear_scene_markers()
		SceneManager.set_scene_bounds(Rect2(-160, -90, 320, 180))
		SceneManager.register_scene_poi(Vector2(0, -30), "Shop Counter", Color(0.7, 0.5, 0.3))
		SceneManager.register_scene_poi(Vector2(0, 80), "Door", Color(0.7, 0.4, 0.2))
		SceneManager.register_scene_exit("bottom", "Cedar Bend")
	_build_shop_ui()
	_build_bulletin_ui()
	_update_seasonal_shelves()
	TimeManager.day_advanced.connect(_on_day_advanced)
	print("Tanner's Feed & Supply interior loaded.")

func _on_day_advanced(_day: int) -> void:
	_update_seasonal_shelves()

# -- Seasonal Shelves ----------------------------------------------------------

func _update_seasonal_shelves() -> void:
	var season: String = TimeManager.current_season_name()
	# The shelves sprite is swapped to reflect seasonal stock via modulate
	var shelves: Sprite2D = get_node_or_null("World/Furniture/Shelves") as Sprite2D
	if not shelves:
		return
	match season:
		"Spring":
			shelves.modulate = Color(0.88, 0.98, 0.82, 1)  # Fresh green tint (seed/package stock)
		"Summer":
			shelves.modulate = Color(1.0, 0.97, 0.88, 1)   # Warm summer
		"Fall":
			shelves.modulate = Color(0.98, 0.92, 0.78, 1)  # Amber fall
		"Winter":
			shelves.modulate = Color(0.90, 0.92, 0.96, 1)  # Cooler, reduced stock

# -- Interaction ---------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_hints()

func _update_hints() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	if carl_npc and shop_hint:
		var d_shop: float = player.global_position.distance_to(carl_npc.global_position)
		shop_hint.visible = (d_shop <= INTERACT_RADIUS) and not _shop_open and not _bulletin_open
	if bulletin_board and board_hint:
		var d_board: float = player.global_position.distance_to(bulletin_board.global_position)
		board_hint.visible = (d_board <= BULLETIN_RADIUS) and not _shop_open and not _bulletin_open

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if not _shop_open and not _bulletin_open:
					_try_interact()
			KEY_ESCAPE, KEY_X:
				if _shop_open:
					_close_shop()
				elif _bulletin_open:
					_close_bulletin()
			KEY_BACKSPACE:
				_exit_supply()

func _try_interact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	# Carl (shop counter) takes priority
	if carl_npc:
		var d_carl: float = player.global_position.distance_to(carl_npc.global_position)
		if d_carl <= INTERACT_RADIUS:
			_open_shop()
			return

	# Bulletin board
	if bulletin_board:
		var d_board: float = player.global_position.distance_to(bulletin_board.global_position)
		if d_board <= BULLETIN_RADIUS:
			_open_bulletin()
			return

# -- Shop UI -------------------------------------------------------------------

func _build_shop_ui() -> void:
	if not shop_ui:
		return

	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(15)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = 2
	shop_ui.add_child(overlay)

	var panel: ColorRect = ColorRect.new()
	panel.name = "Panel"
	panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -175)
	panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  175)
	panel.set_anchor_and_offset(SIDE_TOP,    0.5, -160)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  160)
	panel.color = Color(0.22, 0.16, 0.08, 0.97)
	shop_ui.add_child(panel)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Tanner's Feed & Supply"
	title.set_anchor_and_offset(SIDE_LEFT,   0.5, -170)
	title.set_anchor_and_offset(SIDE_RIGHT,  0.5,  170)
	title.set_anchor_and_offset(SIDE_TOP,    0.5, -152)
	title.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -132)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1))
	title.add_theme_font_size_override("font_size", 12)
	shop_ui.add_child(title)

	var money_lbl: Label = Label.new()
	money_lbl.name = "MoneyLabel"
	money_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -170)
	money_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  170)
	money_lbl.set_anchor_and_offset(SIDE_TOP,    0.5, -132)
	money_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -116)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.55, 1))
	money_lbl.add_theme_font_size_override("font_size", 7)
	shop_ui.add_child(money_lbl)

	# Build item buttons
	var season: String = TimeManager.current_season_name()
	var row_idx: int = 0
	for item in ALL_ITEMS:
		var btn: Button = Button.new()
		btn.name = "ShopBtn_" + item["key"]
		btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -168)
		btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  168)
		var ry: int = -112 + row_idx * 30
		btn.set_anchor_and_offset(SIDE_TOP,    0.5,  ry)
		btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  ry + 26)
		btn.add_theme_font_size_override("font_size", 7)
		var key: String = item["key"]
		btn.pressed.connect(_on_buy.bind(key))
		_shop_btns.append(btn)
		shop_ui.add_child(btn)
		row_idx += 1

	# -- Sell Honey button -------------------------------------------------
	var sell_btn: Button = Button.new()
	sell_btn.name = "SellHoneyBtn"
	var sell_ry: int = -112 + row_idx * 30
	sell_btn.set_anchor_and_offset(SIDE_LEFT,   0.5, -168)
	sell_btn.set_anchor_and_offset(SIDE_RIGHT,  0.5,  168)
	sell_btn.set_anchor_and_offset(SIDE_TOP,    0.5,  sell_ry)
	sell_btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  sell_ry + 26)
	sell_btn.add_theme_font_size_override("font_size", 7)
	sell_btn.text = ">> SELL HONEY TO CARL  --  $8 / jar <<"
	sell_btn.add_theme_color_override("font_color", Color(0.40, 0.85, 0.40, 1))
	sell_btn.pressed.connect(_on_sell_honey)
	shop_ui.add_child(sell_btn)

	var close_lbl: Label = Label.new()
	close_lbl.name = "CloseHint"
	close_lbl.text = "[X] or [ESC] to close"
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -170)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  170)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,  138)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  155)
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.32, 1))
	close_lbl.add_theme_font_size_override("font_size", 6)
	shop_ui.add_child(close_lbl)

	shop_ui.visible = false

func _open_shop() -> void:
	_shop_open = true
	shop_ui.visible = true
	_refresh_shop()

func _close_shop() -> void:
	_shop_open = false
	shop_ui.visible = false

func _refresh_shop() -> void:
	var season: String = TimeManager.current_season_name()
	var money_lbl: Label = shop_ui.get_node_or_null("MoneyLabel") as Label
	if money_lbl:
		money_lbl.text = "Your money: $%.0f" % GameData.money

	for btn in _shop_btns:
		if not is_instance_valid(btn):
			continue
		var key_str: String = btn.name.replace("ShopBtn_", "")
		var item_data: Dictionary = {}
		for it in ALL_ITEMS:
			if it["key"] == key_str:
				item_data = it
				break
		if item_data.is_empty():
			continue

		# Check season availability
		var s: Array = item_data.get("seasons", [])
		var in_season: bool = s.is_empty() or s.has(season)
		var affordable: bool = GameData.money >= item_data["cost"]

		var label_text: String = ""
		if in_season:
			label_text = "%s  --  $%.0f   %s" % [item_data["label"], item_data["cost"], item_data["desc"]]
		else:
			label_text = "%s  --  [out of season]" % item_data["label"]

		btn.text = label_text
		btn.disabled = not (in_season and affordable)
		var col: Color = Color(0.88, 0.80, 0.60, 1)
		if not in_season:
			col = Color(0.45, 0.42, 0.35, 0.5)
		elif not affordable:
			col = Color(0.75, 0.45, 0.35, 0.8)
		btn.add_theme_color_override("font_color", col)

func _on_buy(key: String) -> void:
	var item_data: Dictionary = {}
	for it in ALL_ITEMS:
		if it["key"] == key:
			item_data = it
			break
	if item_data.is_empty():
		return

	var cost: float = item_data["cost"]
	if not GameData.spend_money(cost, "Supply", item_data["label"]):
		print("[Supply] Not enough money for %s" % item_data["label"])
		return

	# Deliver to pending_deliveries (most items arrive via mailbox)
	var item_id: String = item_data.get("item", "")
	var qty: int = item_data.get("qty", 1)
	if item_id != "":
		GameData.pending_deliveries.append({"item": item_id, "count": qty})
		print("[Supply] Ordered %d x %s -- arrives at mailbox." % [qty, item_data["label"]])
	else:
		# Special handling (e.g., repair kit -- no item, adds to notes)
		print("[Supply] Bought %s" % item_data["label"])

	# Refresh the shop display with updated money
	_refresh_shop()

# -- Sell Honey ----------------------------------------------------------------

func _on_sell_honey() -> void:
	_close_shop()
	var scene: PackedScene = load("res://scenes/ui/sell_screen.tscn") as PackedScene
	if scene == null:
		push_error("[Supply] Failed to load sell_screen.tscn")
		return
	var sell_ui: Node = scene.instantiate()
	sell_ui.price_per_jar = 8
	sell_ui.buyer_name = "Carl"
	get_tree().root.add_child(sell_ui)
	sell_ui.closed.connect(_on_sell_closed)

func _on_sell_closed() -> void:
	# Re-open the shop after selling is done
	_open_shop()

# -- Bulletin Board UI ---------------------------------------------------------

func _build_bulletin_ui() -> void:
	if not bulletin_ui:
		return

	var overlay: ColorRect = ColorRect.new()
	overlay.set_anchors_preset(15)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = 2
	bulletin_ui.add_child(overlay)

	var panel: ColorRect = ColorRect.new()
	panel.set_anchor_and_offset(SIDE_LEFT,   0.5, -160)
	panel.set_anchor_and_offset(SIDE_RIGHT,  0.5,  160)
	panel.set_anchor_and_offset(SIDE_TOP,    0.5, -120)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  120)
	panel.color = Color(0.28, 0.20, 0.10, 0.97)
	bulletin_ui.add_child(panel)

	var title: Label = Label.new()
	title.text = "Community Bulletin Board"
	title.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	title.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	title.set_anchor_and_offset(SIDE_TOP,    0.5, -113)
	title.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  -93)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1))
	title.add_theme_font_size_override("font_size", 11)
	bulletin_ui.add_child(title)

	var content: Label = Label.new()
	content.name = "BulletinContent"
	content.set_anchor_and_offset(SIDE_LEFT,   0.5, -152)
	content.set_anchor_and_offset(SIDE_RIGHT,  0.5,  152)
	content.set_anchor_and_offset(SIDE_TOP,    0.5,  -92)
	content.set_anchor_and_offset(SIDE_BOTTOM, 0.5,   95)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", Color(0.82, 0.75, 0.58, 1))
	content.add_theme_font_size_override("font_size", 7)
	bulletin_ui.add_child(content)

	var close_lbl: Label = Label.new()
	close_lbl.text = "[X] or [ESC] to close"
	close_lbl.set_anchor_and_offset(SIDE_LEFT,   0.5, -155)
	close_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.5,  155)
	close_lbl.set_anchor_and_offset(SIDE_TOP,    0.5,  100)
	close_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  116)
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.add_theme_color_override("font_color", Color(0.50, 0.45, 0.32, 1))
	close_lbl.add_theme_font_size_override("font_size", 6)
	bulletin_ui.add_child(close_lbl)

	bulletin_ui.visible = false

func _open_bulletin() -> void:
	_bulletin_open = true
	bulletin_ui.visible = true
	_refresh_bulletin()

func _close_bulletin() -> void:
	_bulletin_open = false
	bulletin_ui.visible = false

func _refresh_bulletin() -> void:
	var content: Label = bulletin_ui.get_node_or_null("BulletinContent") as Label
	if not content:
		return
	var season: String = TimeManager.current_season_name()
	var day: int = TimeManager.current_day_of_month()
	var notices: String = _generate_bulletin_notices(season, day)
	content.text = notices

func _generate_bulletin_notices(season: String, day: int) -> String:
	var lines: Array = []

	# Grange Hall meeting notice
	if day <= 13:
		lines.append("?  Cedar Valley Grange Meeting -- %s 14, 6:00 PM\n       All members welcome. Agenda: upcoming fair schedule." % season)
	elif day == 14 or day == 15:
		lines.append("?  TONIGHT: Grange Hall Meeting -- 6:00 PM\n       Cedar Valley Grange Hall. Bring your questions!")
	else:
		lines.append("?  Next Grange Meeting -- Month %d, Day 14" % (TimeManager.current_day / 30 + 2))

	lines.append("")  # Spacer

	# Seasonal notices
	match season:
		"Spring":
			lines.append("?  Bee packages now in stock -- limited supply.\n       Call ahead or stop in. First come, first served.")
			lines.append("")
			lines.append("?  Cedar Bend Community Garden -- volunteer days\n       Saturdays 8 AM, east lot behind the post office.")
		"Summer":
			lines.append("?  Saturday Market -- every Saturday through Fall.\n       Vendors: Frank Fischbach (honey), Harmon Farm (produce).")
			lines.append("")
			lines.append("??  Mite Treatment Reminder\n       Treatment window opens late summer. Check your counts.")
		"Fall":
			lines.append("?  Fall County Fair -- Date TBD (see fairground sign)\n       Honey competition registration open now.")
			lines.append("")
			lines.append("??  Winter prep supplies in stock.\n       Syrup feeders, mouse guards, entrance reducers.")
		"Winter":
			lines.append("?  Reduced hours through Winter.\n       Open Tue-Sat 9 AM-4 PM.")
			lines.append("")
			lines.append("??  Spring package pre-orders open.\n       Reserve your bees now -- quantities limited.")

	return "\n".join(lines)

# -- Exit ---------------------------------------------------------------------

func _exit_supply() -> void:
	print("[Supply] Leaving -- returning to Cedar Bend.")
	TimeManager.previous_scene = "res://scenes/world/feed_supply_interior.tscn"
	TimeManager.next_scene     = "res://scenes/world/cedar_bend.tscn"
	get_tree().change_scene_to_file("res://scenes/loading/loading_screen.tscn")
