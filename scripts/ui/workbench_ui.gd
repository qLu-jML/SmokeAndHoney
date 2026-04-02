# workbench_ui.gd - Shed workbench crafting menu overlay (clickable UI).
# Lets the player convert logs -> lumber and lumber -> equipment (frames, boxes).
# Recipes are defined in GameData.WORKBENCH_RECIPES.
# -------------------------------------------------------------------------
extends CanvasLayer

signal workbench_closed

# - Conversion rate: logs to lumber ------------------------------------------
const LOGS_PER_LUMBER := 1
const LUMBER_CONVERT_ENERGY := 5.0

# - Layout (320x180 viewport) -----------------------------------------------
const PANEL_X := 8
const PANEL_Y := 1
const PANEL_W := 304
const PANEL_H := 178
const ROW_H := 22
const RECIPE_START_Y := 62
const LEFT_COL_X := 16
const BTN_W := 36
const BTN_H := 12

# - Node refs ----------------------------------------------------------------
var _bg: ColorRect = null
var _panel: ColorRect = null
var _title_label: Label = null
var _lumber_label: Label = null
var _logs_label: Label = null
var _convert_btn: Button = null
var _feedback_label: Label = null
var _close_btn: Button = null
var _recipe_buttons: Array = []

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	layer = 15
	_build_ui()
	_update_resource_display()

func _build_ui() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.82)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Panel border (behind panel)
	var border: ColorRect = ColorRect.new()
	border.color = Color(0.50, 0.38, 0.20, 1.0)
	border.position = Vector2(PANEL_X - 2, PANEL_Y - 2)
	border.size = Vector2(PANEL_W + 4, PANEL_H + 4)
	border.z_index = -1
	add_child(border)

	# Panel background (wood-toned)
	_panel = ColorRect.new()
	_panel.color = Color(0.28, 0.22, 0.14, 0.95)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.size = Vector2(PANEL_W, PANEL_H)
	add_child(_panel)

	# Title - centered in panel
	_title_label = Label.new()
	_title_label.text = "-- Shed Workbench --"
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(PANEL_X, PANEL_Y + 2)
	_title_label.size = Vector2(PANEL_W, 12)
	add_child(_title_label)

	# Close button (top-right X)
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2.ZERO
	_style_button(_close_btn, Color(0.70, 0.30, 0.25), 5)
	_close_btn.pressed.connect(_on_close_pressed)
	add_child(_close_btn)
	_close_btn.position = Vector2(PANEL_X + PANEL_W - 14, PANEL_Y + 2)
	_close_btn.set_deferred("size", Vector2(12, 10))

	# - Resource display row --
	_logs_label = Label.new()
	_logs_label.add_theme_font_size_override("font_size", 6)
	_logs_label.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	_logs_label.position = Vector2(LEFT_COL_X, PANEL_Y + 16)
	add_child(_logs_label)

	_lumber_label = Label.new()
	_lumber_label.add_theme_font_size_override("font_size", 6)
	_lumber_label.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	_lumber_label.position = Vector2(LEFT_COL_X + 80, PANEL_Y + 16)
	add_child(_lumber_label)

	# - Convert Logs button (centered, reasonable width) --
	var convert_w: int = 160
	var convert_x: int = PANEL_X + (PANEL_W - convert_w) / 2
	_convert_btn = Button.new()
	_convert_btn.text = "Convert Logs -> Lumber (5 nrg)"
	_convert_btn.custom_minimum_size = Vector2.ZERO
	_style_button(_convert_btn, Color(0.30, 0.45, 0.25), 5)
	_convert_btn.pressed.connect(_try_convert_logs)
	add_child(_convert_btn)
	_convert_btn.position = Vector2(convert_x, PANEL_Y + 30)
	_convert_btn.set_deferred("size", Vector2(convert_w, 12))

	# Divider line below convert button
	var divider: ColorRect = ColorRect.new()
	divider.color = Color(0.50, 0.38, 0.20, 0.5)
	divider.position = Vector2(LEFT_COL_X, PANEL_Y + 46)
	divider.size = Vector2(PANEL_W - LEFT_COL_X * 2 + PANEL_X, 1)
	add_child(divider)

	# - Column headers --
	var hdr_y: int = RECIPE_START_Y - 12
	var hdr_recipe: Label = Label.new()
	hdr_recipe.text = "Recipe"
	hdr_recipe.add_theme_font_size_override("font_size", 5)
	hdr_recipe.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42))
	hdr_recipe.position = Vector2(LEFT_COL_X + 4, hdr_y)
	add_child(hdr_recipe)

	var hdr_cost: Label = Label.new()
	hdr_cost.text = "Cost"
	hdr_cost.add_theme_font_size_override("font_size", 5)
	hdr_cost.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42))
	hdr_cost.position = Vector2(LEFT_COL_X + 110, hdr_y)
	add_child(hdr_cost)

	var hdr_makes: Label = Label.new()
	hdr_makes.text = "Makes"
	hdr_makes.add_theme_font_size_override("font_size", 5)
	hdr_makes.add_theme_color_override("font_color", Color(0.65, 0.58, 0.42))
	hdr_makes.position = Vector2(LEFT_COL_X + 170, hdr_y)
	add_child(hdr_makes)

	# - Recipe rows with Craft buttons --
	var recipes: Array = GameData.WORKBENCH_RECIPES
	_recipe_buttons.clear()
	for i in range(recipes.size()):
		var r: Dictionary = recipes[i]
		var y_pos: float = RECIPE_START_Y + i * ROW_H

		# Subtle alternating row background for readability
		if i % 2 == 0:
			var row_bg: ColorRect = ColorRect.new()
			row_bg.color = Color(1.0, 1.0, 1.0, 0.03)
			row_bg.position = Vector2(LEFT_COL_X, y_pos)
			row_bg.size = Vector2(PANEL_W - LEFT_COL_X * 2 + PANEL_X, ROW_H)
			add_child(row_bg)

		# Recipe name
		var name_lbl: Label = Label.new()
		name_lbl.text = r["label"]
		name_lbl.add_theme_font_size_override("font_size", 6)
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
		name_lbl.position = Vector2(LEFT_COL_X + 4, y_pos + 5)
		add_child(name_lbl)

		# Cost display
		var cost_lbl := Label.new()
		cost_lbl.text = "%d lbr, %d nrg" % [r["lumber_cost"], int(r["energy_cost"])]
		cost_lbl.add_theme_font_size_override("font_size", 5)
		cost_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
		cost_lbl.position = Vector2(LEFT_COL_X + 110, y_pos + 6)
		add_child(cost_lbl)

		# Makes display
		var makes_lbl := Label.new()
		makes_lbl.text = "x%d" % r["result_count"]
		makes_lbl.add_theme_font_size_override("font_size", 5)
		makes_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
		makes_lbl.position = Vector2(LEFT_COL_X + 174, y_pos + 6)
		add_child(makes_lbl)

		# Craft button - use custom_minimum_size of ZERO so Godot
		# cannot inflate the button beyond our intended dimensions.
		var craft_btn := Button.new()
		craft_btn.text = "Craft"
		craft_btn.custom_minimum_size = Vector2.ZERO
		_style_button(craft_btn, Color(0.35, 0.35, 0.20), 5)
		craft_btn.pressed.connect(_try_craft.bind(i))
		add_child(craft_btn)
		# Position and size AFTER add_child so tree is ready
		craft_btn.position = Vector2(LEFT_COL_X + 210, y_pos + 3)
		craft_btn.set_deferred("size", Vector2(BTN_W, BTN_H))
		craft_btn.set_deferred("custom_minimum_size", Vector2(BTN_W, BTN_H))

		_recipe_buttons.append({"btn": craft_btn, "name_lbl": name_lbl, "cost_lbl": cost_lbl})

	# - Feedback label (bottom) --
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.add_theme_font_size_override("font_size", 5)
	_feedback_label.add_theme_color_override("font_color", Color(0.40, 0.90, 0.40))
	_feedback_label.position = Vector2(LEFT_COL_X, PANEL_Y + PANEL_H - 16)
	add_child(_feedback_label)

	# Hint at bottom
	var hint := Label.new()
	hint.text = "ESC to close  |  Hammer required for crafting"
	hint.add_theme_font_size_override("font_size", 4)
	hint.add_theme_color_override("font_color", Color(0.50, 0.45, 0.38))
	hint.position = Vector2(LEFT_COL_X, PANEL_Y + PANEL_H - 6)
	add_child(hint)

# =========================================================================
# BUTTON STYLING
# =========================================================================
func _style_button(btn: Button, bg_color: Color, font_size: int) -> void:
	# Force exact sizing - zero out all content margins so Godot does not
	# inflate the button beyond the size we set.
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		if state_name == "hover":
			sb.bg_color = bg_color.lightened(0.25)
			sb.border_color = Color(0.75, 0.65, 0.40)
		elif state_name == "pressed":
			sb.bg_color = bg_color.darkened(0.15)
			sb.border_color = Color(0.75, 0.65, 0.40)
		elif state_name == "disabled":
			sb.bg_color = bg_color.darkened(0.35)
			sb.border_color = Color(0.40, 0.35, 0.25)
		elif state_name == "focus":
			sb.bg_color = bg_color
			sb.border_color = Color(0.75, 0.65, 0.40)
		else:
			sb.bg_color = bg_color
			sb.border_color = Color(0.55, 0.45, 0.30)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(1)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		btn.add_theme_stylebox_override(state_name, sb)

	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.55, 0.45))
	btn.clip_text = true
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

# =========================================================================
# DISPLAY UPDATES
# =========================================================================
func _update_resource_display() -> void:
	var player: Node2D = _get_player()
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

	# Update convert button state
	if _convert_btn:
		_convert_btn.disabled = (log_count <= 0 or GameData.energy < LUMBER_CONVERT_ENERGY)

	# Update craft button states (dim unavailable ones)
	var recipes: Array = GameData.WORKBENCH_RECIPES
	for i in range(recipes.size()):
		if i >= _recipe_buttons.size():
			break
		var r: Dictionary = recipes[i]
		var can_craft: bool = (lumber_count >= r["lumber_cost"]
			and GameData.energy >= r["energy_cost"]
			and has_hammer)
		var entry: Dictionary = _recipe_buttons[i]
		entry["btn"].disabled = not can_craft
		if can_craft:
			entry["name_lbl"].add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
		else:
			entry["name_lbl"].add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))

# =========================================================================
# PLAYER HELPER
# =========================================================================
func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

# =========================================================================
# INPUT (ESC to close - keep keyboard shortcut for convenience)
# =========================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

# =========================================================================
# ACTIONS
# =========================================================================
func _on_close_pressed() -> void:
	workbench_closed.emit()

func _try_craft(recipe_index: int) -> void:
	var recipes: Array = GameData.WORKBENCH_RECIPES
	if recipe_index < 0 or recipe_index >= recipes.size():
		return
	var recipe: Dictionary = recipes[recipe_index]
	var player: Node2D = _get_player()
	if not player or not player.has_method("get_item_count"):
		return

	# Check hammer
	if player.get_item_count(GameData.ITEM_HAMMER) <= 0:
		_show_feedback("Need a hammer! Buy one at the shop.", Color(0.90, 0.35, 0.30))
		return

	var lumber_count: int = player.get_item_count(GameData.ITEM_LUMBER)
	var cost: int = recipe["lumber_cost"]
	var energy_cost: float = recipe["energy_cost"]

	# Check lumber
	if lumber_count < cost:
		_show_feedback("Not enough lumber! Need %d (have %d)" % [cost, lumber_count], Color(0.90, 0.35, 0.30))
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

func _try_convert_logs() -> void:
	var player: Node2D = _get_player()
	if not player or not player.has_method("get_item_count"):
		_show_feedback("Error: can't find player!", Color(0.90, 0.35, 0.30))
		return

	var log_count: int = player.get_item_count(GameData.ITEM_LOGS)
	if log_count <= 0:
		_show_feedback("No logs to convert! (Chop trees first)", Color(0.90, 0.35, 0.30))
		return
	if GameData.energy < LUMBER_CONVERT_ENERGY:
		_show_feedback("Too tired! Need %d energy" % int(LUMBER_CONVERT_ENERGY), Color(0.90, 0.35, 0.30))
		return

	# Convert ALL logs at once
	var lumber_out: int = log_count * LOGS_PER_LUMBER
	player.consume_item(GameData.ITEM_LOGS, log_count)
	GameData.deduct_energy(LUMBER_CONVERT_ENERGY)
	var leftover: int = player.add_item(GameData.ITEM_LUMBER, lumber_out)
	if leftover > 0:
		_show_feedback("Converted! (%d lumber lost - inv full)" % leftover, Color(0.90, 0.80, 0.30))
	else:
		_show_feedback("Converted %d logs -> %d lumber!" % [log_count, lumber_out], Color(0.40, 0.90, 0.40))

	_update_resource_display()

func _show_feedback(text: String, color: Color) -> void:
	if _feedback_label:
		_feedback_label.text = text
		_feedback_label.add_theme_color_override("font_color", color)
	# Auto-clear after 3 seconds
	var timer: SceneTreeTimer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if is_instance_valid(_feedback_label):
			_feedback_label.text = "")
