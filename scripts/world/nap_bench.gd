# nap_bench.gd -- Outdoor bench that lets the player take a nap.
# Restores 50% max energy and advances time by 2 hours.
# Does NOT advance to the next day or trigger a save (unlike sleeping in bed).
# GDD S5.3 / S5.4: Nap is a partial-rest action for mid-day recovery.
extends Node2D

const NAP_HOURS := 2.0       # In-game hours the nap costs
const ENERGY_PERCENT := 0.50  # Fraction of max_energy restored

const INTERACT_RADIUS := 48.0  # Distance in pixels for prompt to appear
const FADE_DURATION := 0.4     # Seconds for fade-to-black and fade-back

var _prompt_label: Label = null
var _napping := false          # Prevents double-trigger

# -- Setup ---------------------------------------------------------------------

func _ready() -> void:
	_build_sprite()
	_build_collision()
	_build_interact_area()
	_build_prompt_label()

func _build_sprite() -> void:
	var spr := Sprite2D.new()
	spr.name = "BenchSprite"
	# Load at runtime to avoid import-pipeline issues
	var path := "res://assets/sprites/world/props/bench.png"
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		push_error("nap_bench: failed to load bench sprite from %s" % abs_path)
		return
	var tex := ImageTexture.create_from_image(img)
	spr.texture = tex
	spr.z_index = 0
	add_child(spr)

func _build_collision() -> void:
	# Small static body so the player cannot walk through the bench
	var body := StaticBody2D.new()
	body.name = "BenchBody"
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(42, 14)
	cs.shape = rect
	cs.position = Vector2(0, 4)  # Slightly below centre (seat area)
	body.add_child(cs)
	add_child(body)

func _build_interact_area() -> void:
	# Larger Area2D around the bench so we can detect player proximity
	var area := Area2D.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1  # Detect player (physics layer 1)
	area.monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	cs.shape = circle
	area.add_child(cs)
	add_child(area)

func _build_prompt_label() -> void:
	_prompt_label = Label.new()
	_prompt_label.name = "NapPrompt"
	_prompt_label.text = "[E] Nap"
	_prompt_label.add_theme_font_size_override("font_size", 10)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-24, -28)
	_prompt_label.size = Vector2(48, 14)
	_prompt_label.z_index = 20
	_prompt_label.visible = false
	add_child(_prompt_label)

# -- Proximity check -----------------------------------------------------------

func _is_player_near() -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return false
	var player: Node2D = players[0] as Node2D
	return player.global_position.distance_to(global_position) <= INTERACT_RADIUS

# -- Frame update: show/hide prompt -------------------------------------------

func _process(_delta: float) -> void:
	if _napping:
		return
	if _prompt_label:
		_prompt_label.visible = _is_player_near()

# -- Input: nap on E ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _napping:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E and _is_player_near():
		_do_nap()
		get_viewport().set_input_as_handled()

# -- Nap sequence: fade out -> advance time -> restore energy -> fade in ------

func _do_nap() -> void:
	_napping = true
	if _prompt_label:
		_prompt_label.visible = false
	print("[Bench] Player napping -- +%.0f%% energy, +%d hours" % [
		ENERGY_PERCENT * 100.0, int(NAP_HOURS)])

	# Create a full-screen black overlay on a high CanvasLayer
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)  # Start transparent
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)

	# -- Phase 1: Fade to black ------------------------------------------------
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, FADE_DURATION)

	# -- Phase 2: Hold black, apply effects ------------------------------------
	tween.tween_callback(_apply_nap_effects)
	tween.tween_interval(0.6)  # Brief hold so it feels like time passed

	# -- Phase 3: Fade back in ------------------------------------------------
	tween.tween_property(overlay, "color:a", 0.0, FADE_DURATION)

	# -- Cleanup ---------------------------------------------------------------
	tween.tween_callback(canvas.queue_free)
	tween.tween_callback(_finish_nap)

func _apply_nap_effects() -> void:
	# Restore 50% of max energy
	var restore_amount: float = GameData.max_energy * ENERGY_PERCENT
	GameData.restore_energy(restore_amount)

	# Advance time by 2 hours (do NOT advance to next day)
	TimeManager.current_hour += NAP_HOURS
	# If the nap pushes past midnight, clamp to 23.5 to avoid
	# accidentally triggering midnight logic mid-nap.
	if TimeManager.current_hour >= 24.0:
		TimeManager.current_hour = 23.5
	TimeManager.hour_changed.emit(TimeManager.current_hour)

	print("[Bench] Nap complete -- energy now %.0f / %.0f, hour now %.1f" % [
		GameData.energy, GameData.max_energy, TimeManager.current_hour])

func _finish_nap() -> void:
	_napping = false
