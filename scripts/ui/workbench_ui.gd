# workbench_ui.gd -- Shed workbench crafting menu overlay.
# Lets the player convert logs -> lumber and lumber -> equipment (frames, boxes).
# Recipes are defined in GameData.WORKBENCH_RECIPES.
# -------------------------------------------------------------------------
extends CanvasLayer

signal workbench_closed

# -- Conversion rate: logs to lumber ------------------------------------------
const LOGS_PER_LUMBER := 1        # 1 log = 1 lumber (simple and clean)
const LUMBER_CONVERT_ENERGY := 5.0  # Energy to convert a batch of logs

# -- UI state -----------------------------------------------------------------
var _selected_index: int = 0
var _recipe_labels: Array = []    # Array of Label nodes for each recipe row
var _cursor_rect: ColorRect = null

# -- Layout (320x180 viewport) -----------------------------------------------
const PANEL_X := 20
const PANEL_Y := 10
const PANEL_W := 280
const PANEL_H := 160
const ROW_H := 18
const RECIPE_START_Y := 52
const LEFT_COL_X := 30       # Recipe name column
const COST_COL_X := 170      # Cost column
const RESULT_COL_X := 230    # Result count column

# -- Node refs ----------------------------------------------------------------
var _bg: ColorRect = null
var _panel: ColorRect = null
var _title_label: Label = null
var _lumber_label: Label = null
var _logs_label: Label = null
var _instruction_label: Label = null
var _convert_label: Label = null
var _feedback_label: Label = null

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	_build_ui()
	_update_resource_display()
	_update_selection()

func _build_ui() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.82)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Panel background (wood-toned)
	_panel = ColorRect.new()
	_panel.color = Color(0.28, 0.22, 0.14, 0.95)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	add_child(_panel)

	# Panel border
	var border := ColorRect.new()
	border.color = Color(0.50, 0.38, 0.20, 1.0)
	border.position = Vector2(PANEL_X - 2, PANEL_Y - 2)
	border.size = Vector2(PANEL_W + 4, PANEL_H + 4)
	border.z_index = -1
	add_child(border)

	# Title
	_title_label = Label.new()
	_title_label.text = "-- Shed Workbench --"
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	_title_label.position = Vector2(PANEL_X + 70, PANEL_Y + 4)
	add_child(_title_label)

	# Resource display: logs and lumber counts
	_logs_label = Label.new()
	_logs_label.add_theme_font_size_override("font_size", 6)
	_logs_label.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	_logs_label.position = Vector2(LEFT_COL_X, PANEL_Y + 20)
	add_child(_logs_label)

	_lumber_label = Label.new()
	_lumber_label.add_theme_font_size_override("font_size", 6)
	_lumber_label.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	_lumber_label.position = Vector2(LEFT_COL_X + 100, PANEL_Y + 20)
	add_child(_lumber_label)

	# Convert logs button hint
	_convert_label = Label.new()
	_convert_label.text = "[C] Convert Logs -> Lumber"
	_convert_label.add_theme_font_size_override("font_size", 5)
	_convert_label.add_theme_color_override("font_color", Color(0.65, 0.80, 0.55))
	_convert_label.position = Vector2(LEFT_COL_X, PANEL_Y + 34)
	add_child(_convert_label)

	# Column headers
	var hdr_name := Label.new()
	hdr_name.text = "Recipe"
	hdr_name.add_theme_font_size_override("font_size", 5)
	hdr_name.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	hdr_name.position = Vector2(LEFT_COL_X, RECIPE_START_Y - 10)
	add_child(hdr_name)

	var hdr_cost := Label.new()
	hdr_cost.text = "Lumber"
	hdr_cost.add_theme_font_size_override("font_size", 5)
	hdr_cost.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	hdr_cost.position = Vector2(COST_COL_X, RECIPE_START_Y - 10)
	add_child(hdr_cost)

	var hdr_result := Label.new()
	hdr_result.text = "Makes"
	hdr_result.add_theme_font_size_override("font_size", 5)
	hdr_result.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50))
	hdr_result.position = Vector2(RESULT_COL_X, RECIPE_START_Y - 10)
	add_child(hdr_result)

	# Selection cursor
	_cursor_rect = ColorRect.new()
	_cursor_rect.color = Color(0.95, 0.85, 0.40, 0.20)
	_cursor_rect.size = Vector2(PANEL_W - 20, ROW_H)
	add_child(_cursor_rect)

	# Recipe rows
	_recipe_labels.clear()
	var recipes: Array = GameData.WORKBENCH_RECIPES
	for i in range(recipes.size()):
		var r: Dictionary = recipes[i]
		var y_pos: float = RECIPE_START_Y + i * ROW_H

		# Recipe name
		var name_lbl := Label.new()
		name_lbl.text = r["label"]
		name_lbl.add_theme_font_size_override("font_size", 6)
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
		name_lbl.position = Vector2(LEFT_COL_X + 4, y_pos)
		add_child(name_lbl)

		# Lumber cost
		var cost_lbl := Label.new()
		cost_lbl.text = str(r["lumber_cost"])
		cost_lbl.add_theme_font_size_override("font_size", 6)
		cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.50))
		cost_lbl.position = Vector2(COST_COL_X + 12, y_pos)
		add_child(cost_lbl)

		# Result count
		var result_lbl := Label.new()
		result_lbl.text = "x%d" % r["result_count"]
		result_lbl.add_theme_font_size_override("font_size", 6)
		result_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.50))
		result_lbl.position = Vector2(RESULT_COL_X + 8, y_pos)
		add_child(result_lbl)

		_recipe_labels.append(name_lbl)

	# Feedback label (bottom)
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.add_theme_font_size_override("font_size", 6)
	_feedback_label.add_theme_color_override("font_color", Color(0.40, 0.90, 0.40))
	_feedback_label.position = Vector2(LEFT_COL_X, PANEL_Y + PANEL_H - 24)
	add_child(_feedback_label)

	# Instructions
	_instruction_label = Label.new()
	_instruction_label.text = "UP/DOWN to select | ENTER to craft | ESC to close"
	_instruction_label.add_theme_font_size_override("font_size", 5)
	_instruction_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	_instruction_label.position = Vector2(LEFT_COL_X, PANEL_Y + PANEL_H - 10)
	add_child(_instruction_label)

# =========================================================================
# DISPLAY UPDATES
# =========================================================================
func _update_resource_display() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var log_count: int = 0
	var lumber_count: int = 0
	var has_hammer: bool = false
	if player and player.has_method("get_item_count"):
		log_count = player.get_item_count(GameData.ITEM_LOGS)
		lumber_count = player.get_item_count(GameData.ITEM_LUMBER)
		has_hammer = player.get_item_count(GameData.ITEM_HAMMER) > 0
	if _logs_label:
		_logs_label.text = "Logs: %d" % log_count
	if _lumber_label:
		var hammer_tag: String = " [Hammer OK]" if has_hammer else " [No Hammer!]"
		_lumber_label.text = "Lumber: %d%s" % [lumber_count, hammer_tag]

func _update_selection() -> void:
	if not _cursor_rect:
		return
	var y_pos: float = RECIPE_START_Y + _selected_index * ROW_H - 1
	_cursor_rect.position = Vector2(LEFT_COL_X - 2, y_pos)

	# Highlight affordable vs not
	var recipes: Array = GameData.WORKBENCH_RECIPES
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var lumber_count: int = 0
	var has_hammer: bool = false
	if player and player.has_method("get_item_count"):
		lumber_count = player.get_item_count(GameData.ITEM_LUMBER)
		has_hammer = player.get_item_count(GameData.ITEM_HAMMER) > 0
	for i in range(recipes.size()):
		if i >= _recipe_labels.size():
			break
		var can_afford: bool = lumber_count >= recipes[i]["lumber_cost"]
		var has_energy: bool = GameData.energy >= recipes[i]["energy_cost"]
		if can_afford and has_energy and has_hammer:
			_recipe_labels[i].add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
		else:
			_recipe_labels[i].add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))

# =========================================================================
# INPUT
# =========================================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var recipes: Array = GameData.WORKBENCH_RECIPES
	match event.keycode:
		KEY_ESCAPE:
			workbench_closed.emit()
			get_viewport().set_input_as_handled()
		KEY_UP:
			_selected_index = maxi(0, _selected_index - 1)
			_update_selection()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_selected_index = mini(recipes.size() - 1, _selected_index + 1)
			_update_selection()
			get_viewport().set_input_as_handled()
		KEY_ENTER:
			_try_craft()
			get_viewport().set_input_as_handled()
		KEY_C:
			_try_convert_logs()
			get_viewport().set_input_as_handled()

# =========================================================================
# CRAFTING
# =========================================================================
func _try_craft() -> void:
	var recipes: Array = GameData.WORKBENCH_RECIPES
	if _selected_index < 0 or _selected_index >= recipes.size():
		return
	var recipe: Dictionary = recipes[_selected_index]
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not player.has_method("get_item_count"):
		return

	# Check hammer in inventory
	if player.get_item_count(GameData.ITEM_HAMMER) <= 0:
		_show_feedback("Need a hammer! Buy one at the shop.", Color(0.90, 0.35, 0.30))
		return

	var lumber_count: int = player.get_item_count(GameData.ITEM_LUMBER)
	var cost: int = recipe["lumber_cost"]
	var energy_cost: float = recipe["energy_cost"]

	# Check lumber
	if lumber_count < cost:
		_show_feedback("Not enough lumber! Need %d" % cost, Color(0.90, 0.35, 0.30))
		return

	# Check energy
	if GameData.energy < energy_cost:
		_show_feedback("Too tired to craft!", Color(0.90, 0.35, 0.30))
		return

	# Consume lumber
	player.consume_item(GameData.ITEM_LUMBER, cost)

	# Deduct energy
	GameData.deduct_energy(energy_cost)

	# Award result item
	var leftover: int = player.add_item(recipe["result"], recipe["result_count"])
	if leftover > 0:
		_show_feedback("Crafted! (%d couldn't fit)" % leftover, Color(0.90, 0.80, 0.30))
	else:
		_show_feedback("Crafted %s!" % recipe["label"], Color(0.40, 0.90, 0.40))

	# Award XP
	GameData.add_xp(GameData.XP_EQUIPMENT_CRAFTED_MIN)

	_update_resource_display()
	_update_selection()

func _try_convert_logs() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player or not player.has_method("get_item_count"):
		return
	var log_count: int = player.get_item_count(GameData.ITEM_LOGS)
	if log_count <= 0:
		_show_feedback("No logs to convert!", Color(0.90, 0.35, 0.30))
		return
	if GameData.energy < LUMBER_CONVERT_ENERGY:
		_show_feedback("Too tired!", Color(0.90, 0.35, 0.30))
		return

	# Convert ALL logs at once
	var lumber_out: int = log_count * LOGS_PER_LUMBER
	player.consume_item(GameData.ITEM_LOGS, log_count)
	GameData.deduct_energy(LUMBER_CONVERT_ENERGY)
	var leftover: int = player.add_item(GameData.ITEM_LUMBER, lumber_out)
	if leftover > 0:
		_show_feedback("Converted! (%d lumber lost - full)" % leftover, Color(0.90, 0.80, 0.30))
	else:
		_show_feedback("Converted %d logs -> %d lumber" % [log_count, lumber_out], Color(0.40, 0.90, 0.40))

	_update_resource_display()
	_update_selection()

func _show_feedback(text: String, color: Color) -> void:
	if _feedback_label:
		_feedback_label.text = text
		_feedback_label.add_theme_color_override("font_color", color)
	# Auto-clear after 2 seconds
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if _feedback_label:
			_feedback_label.text = "")
