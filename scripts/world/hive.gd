# hive.gd -- Visual wrapper for a placed beehive.
# All simulation data lives in the HiveSimulation child node.
# This script handles: modular sprite stacking, health tinting, stat label,
# click interaction, the component build-state machine, box management
# (add deep, add super, queen excluder), and harvest super collection.
extends Node2D
class_name Hive

# -- Build State ---------------------------------------------------------------
enum BuildState {
	STAND_PLACED,    # Bare hive stand placed; needs a deep body
	BODY_ADDED,      # Deep body placed on stand; needs frames and/or lid
	FRAMES_PARTIAL,  # 1-9 frames inside; can add more frames or lid
	COMPLETE,        # Lid placed; simulation active, inspection allowed
}

var build_state: BuildState = BuildState.STAND_PLACED
var frame_count: int = 0
var has_lid: bool = false
var colony_installed: bool = false
var colony_install_day: int = -1
const COLONY_LOCKOUT_DAYS: int = 7

# -- Node references -----------------------------------------------------------
@onready var simulation: HiveSimulation = $HiveSimulation
@onready var stat_label: Label          = $Label

# -- Modular sprite textures (loaded at runtime to bypass import pipeline) ------
var _tex_base:     Texture2D = null
var _tex_deep:     Texture2D = null
var _tex_super:    Texture2D = null
var _tex_excluder: Texture2D = null
var _tex_lid:      Texture2D = null
var _tex_stand:      Texture2D = null
var _tex_deep_empty: Texture2D = null
# Fallback legacy sprite (has .import file so preload works)
var _tex_legacy:   Texture2D = preload("res://assets/sprites/hive/overworld_hive.png")

func _load_runtime_tex(res_path: String) -> Texture2D:
	# Try Godot resource loader first (works after import pipeline runs)
	var tex = load(res_path)
	if tex is Texture2D:
		return tex as Texture2D
	# If load() returned an Image instead of Texture2D, convert it
	if tex is Image and not (tex as Image).is_empty():
		return ImageTexture.create_from_image(tex as Image)
	# Fallback 1: load raw PNG via globalized absolute path
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = Image.load_from_file(abs_path)
	if img != null and not img.is_empty():
		return ImageTexture.create_from_image(img)
	# Fallback 2: try Image.new().load() in case load_from_file fails
	img = Image.new()
	var err: int = img.load(abs_path)
	if err == OK and not img.is_empty():
		return ImageTexture.create_from_image(img)
	push_error("Hive: cannot load texture '%s' abs='%s' (err=%d)" % [res_path, abs_path, err])
	return null

# Container node that holds the stacked Sprite2D children
var _sprite_stack: Node2D = null
# Single legacy sprite used during build phase
var _legacy_sprite: Sprite2D = null

# -- Health tint thresholds ---------------------------------------------------
const TINT_HEALTHY = Color(1.00, 1.00, 1.00)
const TINT_WARNING = Color(1.00, 0.92, 0.72)
const TINT_POOR    = Color(1.00, 0.78, 0.78)

# -- Super honey fill tint gradient ------------------------------------------
# Empty super: pale/desaturated.  Full capped super: rich warm amber.
# These tints are multiplied ON TOP of the health tint so both show.
const SUPER_TINT_EMPTY    = Color(0.85, 0.85, 0.80)  # slightly grey -- no honey
const SUPER_TINT_NECTAR   = Color(1.00, 0.95, 0.60)  # pale yellow -- nectar arriving
const SUPER_TINT_FILLING  = Color(1.00, 0.88, 0.45)  # warm gold -- honey curing
const SUPER_TINT_FULL     = Color(1.00, 0.80, 0.30)  # rich amber -- mostly capped
const SUPER_TINT_CAPPED   = Color(1.00, 0.75, 0.20)  # deep amber -- fully capped, ready

# Track which sprite indices in the stack are super sprites (for per-super tinting)
var _super_sprite_indices: Array = []  # [[sprite_child_index, super_data_index], ...]

# -- Winter reserve warning tints --------------------------------------------

# -- Bee swarm cloud (visual activity indicator) ------------------------------
var _swarm_cloud: BeeSwarmCloud = null

# -- Prompt label -------------------------------------------------------------
var _prompt_label: Label = null
const PROMPT_RADIUS := 64.0

# -- Buzz audio ---------------------------------------------------------------
var _buzz_player: AudioStreamPlayer = null
# Distance (px) at which buzz is completely silent; ~20 "feet" in game units.
# At 32px/tile this is roughly 10 tiles away -- tweak to taste.
const BUZZ_MAX_DIST := 320.0
# Distance at which buzz is at full volume (right on top of the hive).
const BUZZ_MIN_DIST := 16.0
# Exponential curve steepness (higher = sharper ramp near the hive).
const BUZZ_CURVE_EXP := 3.0
# Volume range in dB
const BUZZ_VOL_MAX_DB := -6.0
const BUZZ_VOL_MIN_DB := -80.0

# Cached player node
var _player_cache: Node2D = null

# -- Lifecycle -----------------------------------------------------------------
func _ready() -> void:
	add_to_group("hive")

	# Load modular textures at runtime (bypass import pipeline)
	if _tex_base == null:
		_tex_base     = _load_runtime_tex("res://assets/sprites/hive/hive_base.png")
		_tex_deep     = _load_runtime_tex("res://assets/sprites/hive/hive_deep.png")
		_tex_super    = _load_runtime_tex("res://assets/sprites/hive/hive_super.png")
		_tex_excluder = _load_runtime_tex("res://assets/sprites/hive/hive_excluder.png")
		_tex_lid      = _load_runtime_tex("res://assets/sprites/hive/hive_lid.png")
		_tex_stand      = _load_runtime_tex("res://assets/sprites/hive/hive_stand.png")
		_tex_deep_empty = _load_runtime_tex("res://assets/sprites/hive/hive_deep_empty.png")

	# Create the modular sprite stack container
	_sprite_stack = Node2D.new()
	_sprite_stack.name = "SpriteStack"
	add_child(_sprite_stack)

	# Legacy sprite for build-phase display
	_legacy_sprite = Sprite2D.new()
	_legacy_sprite.name = "LegacySprite"
	_legacy_sprite.texture = _tex_legacy
	_legacy_sprite.position = Vector2(0, -18)
	add_child(_legacy_sprite)

	if stat_label:
		stat_label.add_theme_font_size_override("font_size", 4)
		stat_label.position = Vector2(-16, -42)
		stat_label.custom_minimum_size = Vector2(32, 0)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stat_label.z_index = 5
		stat_label.add_to_group("dev_label")
		stat_label.visible = GameData.dev_labels_visible

	# Context prompt
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 5)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(80, 8)
	_prompt_label.position = Vector2(-40, -52)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Bee buzz audio -- looping hum audible near the hive
	_buzz_player = AudioStreamPlayer.new()
	_buzz_player.name = "BuzzPlayer"
	_buzz_player.bus = "SFX"
	_buzz_player.volume_db = BUZZ_VOL_MIN_DB
	var buzz_path: String = "res://assets/audio/sfx/bee_buzz_loop.wav"
	if ResourceLoader.exists(buzz_path):
		var buzz_stream: Resource = load(buzz_path)
		if buzz_stream is AudioStreamWAV:
			var wav: AudioStreamWAV = buzz_stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_buzz_player.stream = wav
		elif buzz_stream is AudioStream:
			_buzz_player.stream = buzz_stream as AudioStream
	_buzz_player.finished.connect(_on_buzz_finished)
	add_child(_buzz_player)

	if build_state == BuildState.COMPLETE and colony_installed:
		HiveManager.all_hives_ticked.connect(_on_ticked)
		update_label()
		_ensure_swarm_cloud()
		_start_buzz()

	_rebuild_sprite_stack()
	_update_prompt_text()

# -- Duck-typing helpers -------------------------------------------------------
func is_build_complete() -> bool:
	return build_state == BuildState.COMPLETE

func is_stand_only() -> bool:
	return build_state == BuildState.STAND_PLACED

var _is_nuc_hive: bool = false

func place_as_complete() -> void:
	build_state = BuildState.COMPLETE
	frame_count = 10
	has_lid = true
	colony_installed = true
	_is_nuc_hive = true
	colony_install_day = 0
	if simulation:
		simulation.init_as_nuc()
	activate_simulation()

## Place a hive with an overwintered colony entering spring.
## species/grade let the caller control the queen genetics (defaults to
## Carniolan S, which is the benchmark test colony).
func place_as_overwintered(p_species: String = "Carniolan", p_grade: String = "S") -> void:
	build_state = BuildState.COMPLETE
	frame_count = 10
	has_lid = true
	colony_installed = true
	_is_nuc_hive = true       # bypass lockout -- established colony
	colony_install_day = 0
	if simulation:
		simulation.init_as_overwintered(p_species, p_grade)
	activate_simulation()

## Place a hive with a strong fall colony that has just filled two honey supers.
## Used by the "Start in Fall | 2 Full Supers" new-game mode (day 113).
## The visual sprite stack is rebuilt to show two super boxes on top of the
## brood body so the player can see the full hive immediately.
func place_as_fall_harvest(p_species: String = "Carniolan",
		p_grade: String = "A") -> void:
	build_state = BuildState.COMPLETE
	frame_count = 10
	has_lid = true
	colony_installed = true
	_is_nuc_hive = true       # bypass lockout -- established colony
	colony_install_day = 0
	if simulation:
		simulation.init_as_fall_harvest(p_species, p_grade)
	activate_simulation()

func activate_simulation() -> void:
	if build_state == BuildState.COMPLETE and colony_installed:
		if not HiveManager.all_hives_ticked.is_connected(_on_ticked):
			HiveManager.all_hives_ticked.connect(_on_ticked)
		update_label()
		_rebuild_sprite_stack()
		_ensure_swarm_cloud()
		_start_buzz()

func has_colony() -> bool:
	return colony_installed

func days_since_install() -> int:
	if colony_install_day < 0:
		return -1
	return TimeManager.current_day - colony_install_day

func can_inspect() -> bool:
	if not colony_installed:
		return false
	if _is_nuc_hive:
		return true
	return days_since_install() >= COLONY_LOCKOUT_DAYS

func install_colony() -> bool:
	if build_state != BuildState.COMPLETE:
		return false
	if colony_installed:
		return false
	colony_installed = true
	colony_install_day = TimeManager.current_day
	if simulation:
		simulation.init_as_package()
	activate_simulation()
	_update_prompt_text()
	return true

# -- Buzz helpers --------------------------------------------------------------
func _on_buzz_finished() -> void:
	# Safety fallback: restart if colony is alive and loop mode failed to engage
	if colony_installed and _buzz_player != null:
		_buzz_player.play()

func _start_buzz() -> void:
	if _buzz_player != null and _buzz_player.stream != null and not _buzz_player.playing:
		_buzz_player.play()

func _stop_buzz() -> void:
	if _buzz_player != null and _buzz_player.playing:
		_buzz_player.stop()

func _update_buzz_volume(dist: float) -> void:
	if _buzz_player == null or not _buzz_player.playing:
		return
	if dist >= BUZZ_MAX_DIST:
		_buzz_player.volume_db = BUZZ_VOL_MIN_DB
		return
	if dist <= BUZZ_MIN_DIST:
		_buzz_player.volume_db = BUZZ_VOL_MAX_DB
		return
	# Normalize distance: 1.0 at hive, 0.0 at max range
	var t: float = 1.0 - ((dist - BUZZ_MIN_DIST) / (BUZZ_MAX_DIST - BUZZ_MIN_DIST))
	# Apply exponential curve -- ramps up sharply near the hive
	var curved: float = pow(t, BUZZ_CURVE_EXP)
	# Map to dB range
	_buzz_player.volume_db = lerpf(BUZZ_VOL_MIN_DB, BUZZ_VOL_MAX_DB, curved)

# -- Per-frame update ----------------------------------------------------------
func _process(_delta: float) -> void:
	# Prompt visibility and buzz volume both need player distance
	if _prompt_label != null or (_buzz_player != null and _buzz_player.playing):
		if not is_instance_valid(_player_cache):
			var found: Node = get_tree().get_first_node_in_group("player")
			if found is Node2D:
				_player_cache = found as Node2D
			else:
				_player_cache = null
		if _player_cache != null:
			var dist: float = _player_cache.global_position.distance_to(global_position)
			# Prompt label
			if _prompt_label != null:
				var in_range: bool = dist <= PROMPT_RADIUS
				_prompt_label.visible = in_range
				if in_range:
					_update_prompt_text()
			# Buzz volume
			_update_buzz_volume(dist)
		else:
			if _prompt_label != null:
				_prompt_label.visible = false

func _on_ticked() -> void:
	update_label()
	_update_health_tint()
	_update_super_fill_tint()
	_update_swarm_cloud()

# -- Build Methods -------------------------------------------------------------
func try_add_body() -> bool:
	if build_state != BuildState.STAND_PLACED:
		return false
	build_state = BuildState.BODY_ADDED
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

func try_add_frames(available: int) -> int:
	if build_state != BuildState.BODY_ADDED and build_state != BuildState.FRAMES_PARTIAL:
		return 0
	var space := 10 - frame_count
	var to_place := mini(available, space)
	frame_count += to_place
	build_state = BuildState.FRAMES_PARTIAL
	_rebuild_sprite_stack()
	_update_prompt_text()
	return to_place

func try_add_lid() -> bool:
	if build_state != BuildState.BODY_ADDED and build_state != BuildState.FRAMES_PARTIAL:
		return false
	if frame_count < 10:
		return false
	has_lid = true
	build_state = BuildState.COMPLETE
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

# -- Box Management (post-complete) -------------------------------------------

## Add a second deep brood body. Returns true on success.
func try_add_deep() -> bool:
	if build_state != BuildState.COMPLETE:
		print("[Hive] try_add_deep FAILED: build_state is not COMPLETE (%d)" % build_state)
		return false
	if not simulation:
		print("[Hive] try_add_deep FAILED: simulation is null")
		return false
	var before: int = simulation.deep_count()
	if not simulation.add_deep():
		print("[Hive] try_add_deep FAILED: simulation.add_deep() returned false (deeps=%d)" % before)
		return false
	print("[Hive] Deep added! Deeps: %d -> %d, total boxes: %d" % [before, simulation.deep_count(), simulation.boxes.size()])
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

## Place a queen excluder. Returns true on success.
func try_add_excluder() -> bool:
	if build_state != BuildState.COMPLETE:
		return false
	if not simulation:
		return false
	if simulation.has_excluder:
		return false   # already has one
	simulation.has_excluder = true
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

## Add a honey super on top. Returns true on success.
func try_add_super() -> bool:
	if build_state != BuildState.COMPLETE:
		return false
	if not simulation:
		return false
	if not simulation.add_super():
		return false
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

## Remove the topmost honey super (for manual harvest transport via gloves UI).
## Removes regardless of mark state -- player takes it to the Honey House.
## Returns the removed HiveBox or null if no supers are present.
func try_remove_top_super() -> Object:
	if not simulation:
		return null
	# Find the topmost super (last super in the boxes array)
	var top_idx: int = -1
	for b_idx in simulation.boxes.size():
		if simulation.boxes[b_idx].is_super:
			top_idx = b_idx
	if top_idx < 0:
		return null
	var removed: Object = simulation.remove_super(top_idx)
	if removed != null:
		_rebuild_sprite_stack()
		_update_prompt_text()
	return removed

## Return true if the topmost super has any honey/nectar/curing cells.
## Returns false if there is no top super or it is completely empty.
func top_super_has_honey() -> bool:
	if not simulation:
		return false
	# Find the topmost super index
	var top_idx: int = -1
	for b_idx in simulation.boxes.size():
		if simulation.boxes[b_idx].is_super:
			top_idx = b_idx
	if top_idx < 0:
		return false
	var box = simulation.boxes[top_idx]
	# Honey states: S_NECTAR, S_CURING_HONEY, S_CAPPED_HONEY, S_PREMIUM_HONEY
	var honey_states: Array = [
		simulation.S_NECTAR,
		simulation.S_CURING_HONEY,
		simulation.S_CAPPED_HONEY,
		simulation.S_PREMIUM_HONEY,
	]
	for frame in box.frames:
		for cell in frame.cells:
			if cell in honey_states:
				return true
		for cell in frame.cells_b:
			if cell in honey_states:
				return true
	return false

## Remove a fully-marked super for harvest transport. Returns the HiveBox or null.
func remove_marked_super() -> Object:
	if not simulation:
		return null
	# Find the first super that is fully marked
	for b_idx in simulation.boxes.size():
		if simulation.is_super_fully_marked(b_idx):
			var removed = simulation.remove_super(b_idx)
			if removed != null:
				_rebuild_sprite_stack()
				_update_prompt_text()
			return removed
	return null

## Check if any super has all frames marked for harvest.
func has_marked_super() -> bool:
	if not simulation:
		return false
	for b_idx in simulation.boxes.size():
		if simulation.is_super_fully_marked(b_idx):
			return true
	return false

## Rotate deep bodies: move bottom deep to top. This gives the queen
## new laying space above. Real beekeepers do this to encourage brood
## expansion when the bottom box has mostly empty frames.
func try_rotate_deeps() -> bool:
	if build_state != BuildState.COMPLETE or not colony_installed:
		return false
	if not simulation:
		return false
	if not simulation.has_method("rotate_deep_bodies"):
		return false
	if not simulation.rotate_deep_bodies():
		return false
	_rebuild_sprite_stack()
	_update_prompt_text()
	return true

## Returns the number of deep bodies in this hive.
func deep_count() -> int:
	if not simulation:
		return 1
	return simulation.deep_count()

## Can we rotate? Need at least 2 deeps.
func can_rotate_deeps() -> bool:
	if not simulation:
		return false
	return simulation.deep_count() >= 2

# -- Modular Sprite Stacking --------------------------------------------------

## Rebuilds the visual sprite stack from current hive configuration.
## Called whenever boxes change (add deep, add super, remove super, etc.)
func _rebuild_sprite_stack() -> void:
	# Clear existing stack sprites immediately (not queue_free) so rebuilds
	# within the same frame do not accumulate stale children.
	var children := _sprite_stack.get_children()
	for child in children:
		_sprite_stack.remove_child(child)
		child.free()

	# Always hide legacy sprite -- we use modular stack for all states now
	_legacy_sprite.visible = false
	_sprite_stack.visible = true

	# -- Build component list BOTTOM to TOP (stand first, lid last) --------
	# Each entry is just [texture]. We stack them with a fixed gap between
	# each piece (GAP_PX) so you can see each component.
	# The lid sits flush on top, fully covering the box below.
	var layers: Array = []
	const _GAP_PX := 1  # 1px gap between stacked components
	# Track which layer indices are super sprites (for honey fill tinting)
	_super_sprite_indices = []
	var super_data_idx: int = 0  # index into snapshot super_visuals array

	if build_state == BuildState.STAND_PLACED:
		layers.append(_tex_stand)

	elif build_state == BuildState.BODY_ADDED:
		layers.append(_tex_stand)
		layers.append(_tex_base)
		layers.append(_tex_deep_empty)

	elif build_state == BuildState.FRAMES_PARTIAL:
		layers.append(_tex_stand)
		layers.append(_tex_base)
		layers.append(_tex_deep)

	else:
		# COMPLETE: full Langstroth stack
		layers.append(_tex_stand)
		layers.append(_tex_base)

		if simulation:
			var deep_n: int = 0
			var super_n: int = 0
			for i in range(simulation.boxes.size()):
				if not simulation.boxes[i].is_super:
					layers.append(_tex_deep)
					deep_n += 1

			if simulation.has_excluder:
				layers.append(_tex_excluder)

			for i in range(simulation.boxes.size()):
				if simulation.boxes[i].is_super:
					# Record that this layer index maps to this super's data index
					_super_sprite_indices.append([layers.size(), super_data_idx])
					layers.append(_tex_super)
					super_n += 1
					super_data_idx += 1
			print("[Hive] Sprite stack: %d deeps, %d supers, %d total boxes" % [deep_n, super_n, simulation.boxes.size()])
		else:
			layers.append(_tex_deep)

		# Lid on top -- no gap, sits flush to cover the box below
		layers.append(_tex_lid)

	# -- Filter out nulls --------------------------------------------------
	var valid: Array = []
	for tex in layers:
		if tex != null:
			valid.append(tex)
	layers = valid

	if layers.is_empty():
		_legacy_sprite.visible = true
		_sprite_stack.visible = false
		return

	# -- Stack sprites from bottom up -------------------------------------
	# Each box sprite has an open interior top (frame bars visible from above)
	# and a solid body wall at the bottom. When stacking, the piece above must
	# overlap enough to cover the open frame-tops of the piece below.
	#
	# Sprite anatomy (from pixel analysis):
	#   Deep  (24x18): rows 0-10 open interior (11px), rows 11-17 solid wall (7px)
	#   Super (24x14): rows 0-7  open interior (8px),  rows 8-13  solid wall (6px)
	#   Lid   (28x13): rows 0-8  metal top (9px),      rows 9-12  wooden rim (4px)
	#
	# The overlap INTO a piece below = that piece's open-top height, so the
	# solid bottom of the upper piece lands right at the box wall of the lower.
	# "open_top" is how many pixels of open interior the piece has at its top.
	#
	# Stand, base, excluder have no open top -- pieces sit flush on them.

	var y_cursor: float = 0.0
	var z_order: int = 0

	for i in range(layers.size()):
		var tex: Texture2D = layers[i]
		var tex_h: float = float(tex.get_height())
		var tex_w: float = float(tex.get_width())

		if i == 0:
			y_cursor = -tex_h
		else:
			# Overlap is determined by the open-top of the piece BELOW
			var prev_tex: Texture2D = layers[i - 1]
			var overlap: int = 0
			if prev_tex == _tex_deep or prev_tex == _tex_deep_empty:
				overlap = 11   # deep has 11px open top (rows 0-10)
			elif prev_tex == _tex_super:
				overlap = 8    # super has 8px open top (rows 0-7)
			# stand, base, excluder = 0 overlap (sit flush)
			y_cursor -= (tex_h - float(overlap))

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.position = Vector2(-tex_w / 2.0, y_cursor)
		spr.z_index = z_order
		_sprite_stack.add_child(spr)
		z_order += 1

	var total_height: int = int(abs(y_cursor))

	# Update collision shapes to match new height
	_update_collision_for_height(total_height)

	# Position labels above the hive
	if stat_label:
		stat_label.position = Vector2(-16, y_cursor - 8.0)
	if _prompt_label:
		_prompt_label.position = Vector2(-40, y_cursor - 12.0)

	# Reposition swarm cloud to match new stack extents
	# entrance_y = near bottom (ground level), top_y = top of lid
	if _swarm_cloud != null:
		_swarm_cloud.set_hive_extents(-4.0, y_cursor)

## Update both Area2D (interaction) and StaticBody2D (physical blocker)
## collision shapes to match the current sprite stack height.
func _update_collision_for_height(total_height: int) -> void:
	# -- Area2D: interaction zone covers the full visual height ---------------
	var area := get_node_or_null("Area2D")
	if area:
		var col := area.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(24, total_height)
			col.position = Vector2(0, -float(total_height) / 2.0)

	# -- StaticBody2D: physical blocker covers the bottom portion ------------
	# In a top-down game the body collision represents the ground footprint.
	# We size it to the full visual width and roughly half the stack height
	# so the player cannot walk into the sprite from below (south).
	var body := get_node_or_null("StaticBody2D")
	if body:
		var bcol := body.get_node_or_null("CollisionShape2D")
		if bcol and bcol.shape is RectangleShape2D:
			# Cover from ground (y=0) up to 60% of the visual height
			var body_h: float = maxf(float(total_height) * 0.6, 16.0)
			bcol.shape.size = Vector2(28, body_h)
			bcol.position = Vector2(0, -body_h / 2.0)

# -- Health Tint ---------------------------------------------------------------
func _apply_tint_to_stack(tint: Color) -> void:
	for child in _sprite_stack.get_children():
		if child is Sprite2D:
			child.modulate = tint

func _update_health_tint() -> void:
	if not simulation or build_state != BuildState.COMPLETE:
		return
	var snap: Dictionary = simulation.last_snapshot
	if snap.is_empty():
		return
	var health: float = snap.get("health_score", 100.0)
	var tint: Color
	if health >= 70.0:
		tint = TINT_HEALTHY
	elif health >= 40.0:
		var t := (70.0 - health) / 30.0
		tint = TINT_HEALTHY.lerp(TINT_WARNING, t)
	else:
		var t := (40.0 - health) / 40.0
		tint = TINT_WARNING.lerp(TINT_POOR, t)
	_apply_tint_to_stack(tint)

# -- Super Fill Tint -----------------------------------------------------------
## Apply per-super honey fill tinting. Each super sprite gets a golden tint
## that intensifies as honey fills and caps. This runs AFTER health tint,
## overriding just the super sprites (not deeps/base/lid).

func _update_super_fill_tint() -> void:
	if not simulation or build_state != BuildState.COMPLETE:
		return
	if _super_sprite_indices.is_empty():
		return
	var snap: Dictionary = simulation.last_snapshot
	if snap.is_empty():
		return
	var super_data: Array = snap.get("super_visuals", [])
	if super_data.is_empty():
		return

	var stack_children: Array = _sprite_stack.get_children()

	for pair in _super_sprite_indices:
		var sprite_idx: int = int(pair[0])
		var data_idx: int = int(pair[1])
		if sprite_idx >= stack_children.size() or data_idx >= super_data.size():
			continue
		var spr: Sprite2D = stack_children[sprite_idx] as Sprite2D
		if spr == null:
			continue
		var sd: Dictionary = super_data[data_idx]
		var fill: float = sd.get("fill_pct", 0.0)
		var cap: float = sd.get("capping_pct", 0.0)
		var drawn: float = sd.get("drawn_pct", 0.0)

		# Determine the super tint based on fill and capping state.
		# Progression: empty -> nectar arriving -> filling/curing -> full -> capped
		var tint: Color
		if drawn < 0.05:
			# Foundation not even drawn yet -- just empty plastic/wax
			tint = SUPER_TINT_EMPTY
		elif fill < 0.05:
			# Comb drawn but no honey yet
			tint = SUPER_TINT_EMPTY.lerp(SUPER_TINT_NECTAR, drawn)
		elif fill < 0.30:
			# Nectar starting to arrive
			var t: float = fill / 0.30
			tint = SUPER_TINT_NECTAR.lerp(SUPER_TINT_FILLING, t)
		elif fill < 0.70:
			# Filling up, honey curing
			var t: float = (fill - 0.30) / 0.40
			tint = SUPER_TINT_FILLING.lerp(SUPER_TINT_FULL, t)
		else:
			# Nearly full -- blend based on capping percentage
			var t: float = clampf(cap, 0.0, 1.0)
			tint = SUPER_TINT_FULL.lerp(SUPER_TINT_CAPPED, t)

		spr.modulate = tint

# -- Bee Swarm Cloud -----------------------------------------------------------

## Create the swarm cloud node if it does not exist yet.
func _ensure_swarm_cloud() -> void:
	if _swarm_cloud != null:
		return
	_swarm_cloud = BeeSwarmCloud.new()
	_swarm_cloud.name = "BeeSwarmCloud"
	add_child(_swarm_cloud)
	# Give it an initial position estimate; _rebuild_sprite_stack will refine it
	_swarm_cloud.set_hive_extents(-4.0, -40.0)
	# Kick-start with current snapshot so bees appear immediately on Day 1
	# (otherwise they wait for the first day-advance tick)
	_update_swarm_cloud()

## Feed the latest snapshot to the swarm cloud.
func _update_swarm_cloud() -> void:
	if _swarm_cloud == null:
		return
	if not simulation:
		return
	_swarm_cloud.update_from_snapshot(simulation.last_snapshot)

# -- Prompt Text ---------------------------------------------------------------
func _update_prompt_text() -> void:
	if not _prompt_label:
		return
	var held_item: String = ""
	if _player_cache and _player_cache.has_method("get_active_item_name"):
		held_item = _player_cache.get_active_item_name()

	match build_state:
		BuildState.STAND_PLACED:
			if held_item == GameData.ITEM_DEEP_BODY:
				_prompt_label.text = "[E] Add Deep Body"
			else:
				_prompt_label.text = "Needs Deep Body"
		BuildState.BODY_ADDED:
			if held_item == GameData.ITEM_FRAMES:
				_prompt_label.text = "[E] Add Frames (0/10)"
			else:
				_prompt_label.text = "Needs Frames (0/10)"
		BuildState.FRAMES_PARTIAL:
			if frame_count < 10:
				if held_item == GameData.ITEM_FRAMES:
					_prompt_label.text = "[E] Frames %d/10" % frame_count
				else:
					_prompt_label.text = "Needs Frames %d/10" % frame_count
			else:
				if held_item == GameData.ITEM_LID:
					_prompt_label.text = "[E] Add Lid (10/10 ready)"
				else:
					_prompt_label.text = "Needs Lid (10/10 ready)"
		BuildState.COMPLETE:
			# Gloves and box items work regardless of colony status
			if held_item == GameData.ITEM_GLOVES:
				_prompt_label.text = "[E] Hive Management"
			elif held_item == GameData.ITEM_DEEP_BOX or held_item == GameData.ITEM_DEEP_BODY:
				if simulation and simulation.deep_count() < 2:
					_prompt_label.text = "[E] Add Second Deep"
				else:
					_prompt_label.text = "Max Deeps (2)"
			elif held_item == GameData.ITEM_SUPER_BOX:
				if simulation and simulation.super_count() < 10:
					if simulation.has_excluder:
						_prompt_label.text = "[E] Add Honey Super"
					else:
						_prompt_label.text = "[E] Add Super (no excluder!)"
				else:
					_prompt_label.text = "Max Supers (10)"
			elif held_item == GameData.ITEM_QUEEN_EXCLUDER:
				if simulation and not simulation.has_excluder:
					_prompt_label.text = "[E] Place Excluder"
				else:
					_prompt_label.text = "Excluder Placed"
			elif not colony_installed:
				if held_item == GameData.ITEM_PACKAGE_BEES:
					_prompt_label.text = "[E] Install Colony"
				else:
					_prompt_label.text = "Needs Package Bees"
			elif not can_inspect():
				var days_left: int = COLONY_LOCKOUT_DAYS - days_since_install()
				_prompt_label.text = "Establishing... %dd" % days_left
			elif has_marked_super():
				_prompt_label.text = "[E] Remove Marked Super"
			elif held_item == GameData.ITEM_HIVE_TOOL:
				_prompt_label.text = "[E] Inspect Hive"
			else:
				# Default: show hive config summary
				var d: int = simulation.deep_count() if simulation else 1
				var s: int = simulation.super_count() if simulation else 0
				var ex: String = " +QE" if (simulation and simulation.has_excluder) else ""
				_prompt_label.text = "%dD/%dS%s  Equip Tool" % [d, s, ex]

# -- Stat label ----------------------------------------------------------------
func update_label() -> void:
	if not stat_label or not simulation:
		return
	if build_state != BuildState.COMPLETE:
		stat_label.text = "Stand+Body\nFrm:%d/10" % frame_count
		return
	var snap: Dictionary = simulation.last_snapshot
	if snap.is_empty():
		return
	var d := simulation.deep_count()
	var s := simulation.super_count()
	var base_text: String = "Q:%s/%s A:%d\nMit:%.0f H:%.1f\nHP:%.0f%% %dD/%dS" % [
		snap.get("queen_grade", "?"),
		snap.get("queen_species", "?").substr(0, 3),
		snap.get("total_adults", 0),
		snap.get("mite_count", 0.0),
		snap.get("honey_stores", 0.0),
		snap.get("health_score", 0.0),
		d, s
	]
	# Append per-super fill/capping summary if supers exist
	var super_data: Array = snap.get("super_visuals", [])
	if not super_data.is_empty():
		for si in super_data.size():
			var sd: Dictionary = super_data[si]
			var fill_pct: float = sd.get("fill_pct", 0.0) * 100.0
			var cap_pct: float = sd.get("capping_pct", 0.0) * 100.0
			base_text += "\nS%d:%.0f%%f/%.0f%%c" % [si + 1, fill_pct, cap_pct]
	stat_label.text = base_text

# -- Legacy compatibility ------------------------------------------------------
func advance_day() -> void:
	pass

# -- Harvest (legacy -- to be removed when Honey House pipeline is complete) ----
func harvest_honey() -> float:
	if simulation:
		return simulation.harvest_honey()
	return 0.0

# -- Inspection Overlay --------------------------------------------------------
const INSPECTION_SCENE = preload("res://scenes/inspection/InspectionOverlay.tscn")

func open_inspection() -> void:
	if build_state != BuildState.COMPLETE:
		push_warning("Hive.open_inspection: hive not complete")
		return
	if not simulation:
		push_warning("Hive.open_inspection: simulation is null")
		return
	if get_tree().get_first_node_in_group("inspection_overlay"):
		push_warning("Hive.open_inspection: overlay already open")
		return
	var overlay = INSPECTION_SCENE.instantiate()
	overlay.add_to_group("inspection_overlay")
	get_tree().current_scene.add_child(overlay)
	overlay.open(self)

# -- Click interaction ---------------------------------------------------------
func _on_area_2d_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if build_state == BuildState.COMPLETE:
			open_inspection()
