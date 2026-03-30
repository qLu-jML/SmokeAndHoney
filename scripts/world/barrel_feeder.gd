# barrel_feeder.gd -- Placeable sugar syrup barrel feeder
# --------------------------------------------------------------------------
# Place near hives to supply 100 NU per day for 10 days.
# Connects to TimeManager.day_advanced to tick daily.
# NU is injected directly into the nearest hive's honey_stores.
# After 10 days the feeder is empty and can be picked up (returns item).
# --------------------------------------------------------------------------
extends Node2D

const FEED_NU_PER_DAY := 100
const FEED_DURATION_DAYS := 10
# 1 NU = approximately 0.01 lbs honey equivalent for store conversion
const NU_TO_LBS := 0.01
# How close (px) a hive must be to receive feed
const FEED_RADIUS := 128.0

var days_remaining: int = FEED_DURATION_DAYS
var _prompt_label: Label = null
var _sprite: Sprite2D = null
var _player_cache: Node2D = null

const PROMPT_RADIUS := 64.0

func _ready() -> void:
	add_to_group("barrel_feeder")
	z_index = 1

	# Visual sprite
	_sprite = Sprite2D.new()
	_sprite.name = "FeederSprite"
	var tex: Texture2D = null
	var tex_path := "res://assets/sprites/items/barrel_feeder.png"
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	if tex:
		_sprite.texture = tex
	else:
		# Placeholder: brown rectangle
		var img := Image.create(24, 28, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.55, 0.35, 0.15, 1.0))
		_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.position = Vector2(0, -14)
	add_child(_sprite)

	# Prompt label
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 5)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(80, 8)
	_prompt_label.position = Vector2(-40, -36)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Connect day advance
	if TimeManager.has_signal("day_advanced"):
		TimeManager.day_advanced.connect(_on_day_advanced)

	_update_prompt_text()

func _on_day_advanced(_new_day: int) -> void:
	if days_remaining <= 0:
		return

	# Find all hives in range and distribute NU evenly
	var hives_in_range: Array = []
	for hive in get_tree().get_nodes_in_group("hive"):
		if not hive is Node2D:
			continue
		var dist: float = global_position.distance_to((hive as Node2D).global_position)
		if dist <= FEED_RADIUS:
			hives_in_range.append(hive)

	if hives_in_range.size() > 0:
		var nu_per_hive: int = FEED_NU_PER_DAY / hives_in_range.size()
		var lbs_per_hive: float = float(nu_per_hive) * NU_TO_LBS
		for hive in hives_in_range:
			if hive.has_method("get") and hive.get("simulation"):
				var sim = hive.simulation
				if sim != null and "honey_stores" in sim:
					sim.honey_stores += lbs_per_hive
	else:
		# No hives nearby -- NU is wasted (syrup evaporates)
		pass

	days_remaining -= 1
	_update_prompt_text()

	if days_remaining <= 0:
		print("Barrel feeder empty at %s" % str(global_position))
		# Visual indication: darken sprite
		if _sprite:
			_sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)

func _update_prompt_text() -> void:
	if not _prompt_label:
		return
	if days_remaining > 0:
		_prompt_label.text = "Feeder: %d days left" % days_remaining
	else:
		_prompt_label.text = "[E] Pick Up (empty)"

func _process(_delta: float) -> void:
	if not _prompt_label:
		return
	# Show prompt when player is nearby
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as Node2D
	if _player_cache:
		var dist: float = global_position.distance_to(_player_cache.global_position)
		_prompt_label.visible = dist < PROMPT_RADIUS
	else:
		_prompt_label.visible = false

## Called by the player interaction system to pick up an empty feeder.
func try_pickup() -> bool:
	if days_remaining > 0:
		return false  # still has syrup
	return true

## Remove from world after pickup.
func remove_feeder() -> void:
	if TimeManager.has_signal("day_advanced"):
		TimeManager.day_advanced.disconnect(_on_day_advanced)
	queue_free()

## Save state for SaveManager.
func collect_save_data() -> Dictionary:
	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"days_remaining": days_remaining,
	}

## Restore state from SaveManager.
func apply_save_data(data: Dictionary) -> void:
	global_position = Vector2(
		float(data.get("pos_x", 0.0)),
		float(data.get("pos_y", 0.0))
	)
	days_remaining = int(data.get("days_remaining", FEED_DURATION_DAYS))
	_update_prompt_text()
	if days_remaining <= 0 and _sprite:
		_sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)
