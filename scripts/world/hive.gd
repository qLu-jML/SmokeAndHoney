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
var hive_name: String = ""   # Custom name (default: "Hive #N")
var frame_count: int = 0
var has_lid: bool = false
var colony_installed: bool = false
var colony_install_day: int = -1
const COLONY_LOCKOUT_DAYS: int = 7

# -- Winterization State (Winter Workshop S4) ----------------------------------
# Tracks which winterization components have been applied this year.
# Reset each spring (Quickening Day 1) by HiveManager.
var winterization: Dictionary = {
	"entrance_reducer": false,
	"mouse_guard": false,
	"moisture_quilt": false,
	"hive_wrap": false,
	"top_insulation": false,
	"candy_board": false,
	"vent_shim": false,
}

# Spring damage flags -- set by HiveManager spring check, cleared after display
var spring_damage: Array[String] = []

## Returns winterization survival bonus as a float (0.0 to 0.28).
func get_winterization_bonus() -> float:
	var bonus: float = 0.0
	if winterization.get("entrance_reducer", false):
		bonus += 0.05
	if winterization.get("mouse_guard", false):
		bonus += 0.05
	if winterization.get("top_insulation", false):
		bonus += 0.05
	if winterization.get("moisture_quilt", false):
		bonus += 0.08
	if winterization.get("vent_shim", false):
		bonus += 0.02
	if winterization.get("hive_wrap", false):
		bonus += 0.08
	# Candy board does not add survival %, it prevents starvation directly
	return bonus

## Returns the winterization tier name for display.
func get_winterization_tier() -> String:
	var count: int = 0
	for key in winterization:
		if winterization[key]:
			count += 1
	if count == 0:
		return "None"
	elif count <= 2:
		return "Bare minimum"
	elif count <= 4:
		return "Basic"
	elif count <= 5:
		return "Standard"
	else:
		return "Full protection"

## Resets winterization state for a new year (called at spring start).
func reset_winterization() -> void:
	for key in winterization:
		winterization[key] = false
	spring_damage.clear()

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
# New draft sprites (open-top boxes showing interior cavity)
var _tex_deep_draft:  Texture2D = null   # 48x60 deep body with open hole (legacy, unused now)
var _tex_bottom_deep: Texture2D = null   # 48x60 bottom deep (has hive entrance)
var _tex_top_mid_deep: Texture2D = null  # 48x60 top/middle deep (no entrance)
var _tex_super_draft: Texture2D = null   # 48x41 super with open hole
var _tex_super_full:  Texture2D = null   # 48x28 full/closed super
# Frame overlay textures (44x20 each, sit inside the cavity of draft sprites)
var _tex_frames: Array = []  # Index 0 = one_frame, 1 = two_frames, ... 9 = ten_frames
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
# Track which sprite children are frame overlay sprites for supers (for tick updates)
var _super_overlay_children: Array = []  # [[overlay_child_index, super_data_index], ...]

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
## Ready.
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
		# New draft sprites
		_tex_deep_draft  = _load_runtime_tex("res://assets/sprites/hive/deep_empty_draft.png")
		_tex_bottom_deep = _load_runtime_tex("res://assets/sprites/hive/bottom_deep_empty_draft.png")
		_tex_top_mid_deep = _load_runtime_tex("res://assets/sprites/hive/top_and_middle_deep_empty_draft.png")
		_tex_super_draft = _load_runtime_tex("res://assets/sprites/hive/super_empty_draft.png")
		_tex_super_full  = _load_runtime_tex("res://assets/sprites/hive/super_full_draft.png")
		# Frame overlay textures (1-10 frames)
		var frame_names: Array = [
			"one_frame", "two_frames", "three_frames", "four_frames",
			"five_frames", "sixFrames", "seven_frames", "eight_frames",
			"nine_frames", "ten_frames"
		]
		_tex_frames.clear()
		for fname in frame_names:
			var ftex: Texture2D = _load_runtime_tex("res://assets/sprites/hive/%s.png" % fname)
			_tex_frames.append(ftex)

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

## Disconnect signals when exiting tree.
func _exit_tree() -> void:
	pass  # Signal cleanup handled by node references
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
## On buzz finished.
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
## Process.
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

## On ticked.
func _on_ticked() -> void:
	update_label()
	_update_health_tint()
	_update_super_fill_tint()
	_update_super_frame_overlays()
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
	if before >= 3:
		print("[Hive] try_add_deep FAILED: already at max 3 deeps")
		return false
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

## Returns current colony honey stores in lbs from simulation snapshot.
func get_honey_stores() -> float:
	if not simulation or not simulation.has_method("last_snapshot"):
		return 0.0
	var snap: Dictionary = simulation.last_snapshot
	return snap.get("honey_stores", 0.0)

# -- Modular Sprite Stacking --------------------------------------------------

## Get the frame overlay texture for a super based on its honey fill level.
## Returns the appropriate N-frame overlay (1-10) or null if empty.
## super_data_idx is the index into the snapshot's super_visuals array.
func _get_super_frame_overlay(super_data_idx: int) -> Texture2D:
	if not simulation or _tex_frames.is_empty():
		return null
	var snap: Dictionary = simulation.last_snapshot
	if snap.is_empty():
		return null
	var super_data: Array = snap.get("super_visuals", [])
	if super_data_idx >= super_data.size():
		return null
	var sd: Dictionary = super_data[super_data_idx]
	var fill: float = sd.get("fill_pct", 0.0)
	# Map fill percentage to frame count (1-10)
	# 0% fill = no overlay, 10% = 1 frame, 20% = 2, ... 100% = 10
	if fill < 0.05:
		return null
	var frame_n: int = clampi(int(ceil(fill * 10.0)), 1, 10)
	var idx: int = frame_n - 1
	if idx < _tex_frames.size():
		return _tex_frames[idx]
	return null

## Rebuilds the visual sprite stack from current hive configuration.
## Called whenever boxes change (add deep, add super, remove super, etc.)
##
## STACKING MODEL (Nathan's sprite art, front-facing view):
##   1. Stand (24x12) sits on the ground at the node origin (y=0 = ground).
##   2. First box (bottom_deep) centered on stand, offset 4 display-px
##      forward (toward camera = down = +y) so the stand lip peeks out.
##   3. Additional boxes/supers/lid stack FLUSH on top: bottom of upper
##      sprite aligns with top of lower sprite. No overlap, no gap.
##   4. Stand renders at the player's z-level; all boxes/lid/overlays
##      render ABOVE the player (z_index = 5) for walk-behind illusion.
##
## Draft sprites (48px wide) are scaled 0.5 -> 24px display width.
## Lid (54px) and base textures are also scaled 0.5 -> 27px display.
## Stand (24px) and excluder (24px) use scale 1.0.
func _rebuild_sprite_stack() -> void:
	# Clear existing stack sprites
	var old_children := _sprite_stack.get_children()
	for child in old_children:
		_sprite_stack.remove_child(child)
		child.free()

	_legacy_sprite.visible = false
	_sprite_stack.visible = true

	_super_sprite_indices = []
	_super_overlay_children = []

	const DRAFT_SCALE := 0.5
	# Boxes render above the player for walk-behind depth illusion.
	# Stand stays at z=0 (same level as player, participates in y-sort).
	const Z_GROUND := 0
	const Z_BOXES  := 5
	# The lid overlaps downward into the top box to cover the open cavity
	# (dark interior area drawn in the top ~20 source px of draft sprites).
	const LID_OVERLAP := 12.0  # display px -- covers full 22-row cavity + margin
	# Both deep and super open-top sprites share the same cavity structure:
	# 2 bright rim rows + 20 dark interior rows = 22 source rows = 11 display px.
	# When a box stacks on an open-cavity box, it overlaps into the cavity
	# so the dark interior is hidden and there is no visible gap.
	const BOX_CAVITY := 11.0  # display px -- 22 source rows * 0.5 scale

	# Forward offset: how far the first box extends past the stand front (px)
	const BOX_FRONT_OFFSET := 4.0

	# -- Collect layers: [texture, overlay_tex_or_null, is_draft, is_above_player]
	var layers: Array = []
	var super_data_idx: int = 0

	if build_state == BuildState.STAND_PLACED:
		layers.append([_tex_base, null, true, false])

	elif build_state == BuildState.BODY_ADDED:
		layers.append([_tex_base, null, true, false])
		var deep_tex: Texture2D = _tex_bottom_deep if _tex_bottom_deep != null else _tex_deep_draft
		if deep_tex != null:
			layers.append([deep_tex, null, true, true])
		else:
			layers.append([_tex_deep_empty, null, false, true])

	elif build_state == BuildState.FRAMES_PARTIAL:
		layers.append([_tex_base, null, true, false])
		var deep_tex: Texture2D = _tex_bottom_deep if _tex_bottom_deep != null else _tex_deep_draft
		if deep_tex != null and frame_count > 0 and frame_count <= _tex_frames.size():
			layers.append([deep_tex, _tex_frames[frame_count - 1], true, true])
		elif deep_tex != null:
			layers.append([deep_tex, null, true, true])
		else:
			layers.append([_tex_deep, null, false, true])

	else:
		# COMPLETE hive
		layers.append([_tex_base, null, true, false])

		if simulation:
			var deep_n: int = 0
			for i in range(simulation.boxes.size()):
				if not simulation.boxes[i].is_super:
					var dtex: Texture2D = null
					if deep_n == 0:
						dtex = _tex_bottom_deep if _tex_bottom_deep != null else _tex_deep_draft
					else:
						dtex = _tex_top_mid_deep if _tex_top_mid_deep != null else _tex_deep_draft
					if dtex != null and _tex_frames.size() >= 10:
						layers.append([dtex, _tex_frames[9], true, true])
					elif dtex != null:
						layers.append([dtex, null, true, true])
					else:
						layers.append([_tex_deep, null, false, true])
					deep_n += 1

			# Queen excluder is data-only (no visual layer in the sprite stack).
			# Its on/off state is shown in the hive inspection UI instead.

			var super_n: int = 0
			for i in range(simulation.boxes.size()):
				if simulation.boxes[i].is_super:
					_super_sprite_indices.append([layers.size(), super_data_idx])
					if _tex_super_draft != null:
						var frame_overlay: Texture2D = _get_super_frame_overlay(super_data_idx)
						layers.append([_tex_super_draft, frame_overlay, true, true])
					elif _tex_super_full != null:
						layers.append([_tex_super_full, null, true, true])
					else:
						layers.append([_tex_super, null, false, true])
					super_n += 1
					super_data_idx += 1
			print("[Hive] Sprite stack: %d deeps, %d supers, %d total boxes" % [deep_n, super_n, simulation.boxes.size()])
		else:
			var dtex: Texture2D = _tex_bottom_deep if _tex_bottom_deep != null else _tex_deep_draft
			if dtex != null and _tex_frames.size() >= 10:
				layers.append([dtex, _tex_frames[9], true, true])
			elif dtex != null:
				layers.append([dtex, null, true, true])
			else:
				layers.append([_tex_deep, null, false, true])

		layers.append([_tex_lid, null, true, true])

	# -- Filter out null textures ------------------------------------------
	var valid: Array = []
	for entry in layers:
		if entry[0] != null:
			valid.append(entry)
	layers = valid
	if layers.is_empty():
		_legacy_sprite.visible = true
		_sprite_stack.visible = false
		return

	# -- Position sprites from bottom up (flush stacking) ------------------
	# y = 0 is ground level (bottom of stand). Negative y = upward.
	# Stand sits at ground: bottom at y=0, top at y=-stand_h.
	# First box sits on stand with 4px forward offset: its bottom is at
	# y = -(stand_h - BOX_FRONT_OFFSET). This makes the stand lip peek out
	# in front of the box (the landing board).
	# Every subsequent box/lid stacks flush: bottom = previous top.

	var y_cursor: float = 0.0
	var is_first_box: bool = true   # first non-stand layer
	var prev_cavity: float = 0.0    # cavity depth (display px) of previous layer
	var layer_to_child: Dictionary = {}
	var child_idx: int = 0

	for i in range(layers.size()):
		var tex: Texture2D = layers[i][0]
		var overlay_tex: Texture2D = layers[i][1] if layers[i][1] != null else null
		var is_draft: bool = layers[i][2]
		var is_above: bool = layers[i][3]
		var scale_factor: float = DRAFT_SCALE if is_draft else 1.0
		var tex_h: float = float(tex.get_height()) * scale_factor
		var tex_w: float = float(tex.get_width()) * scale_factor

		if tex == _tex_stand or tex == _tex_base:
			# Base/stand: bottom at y=0 (ground), sprite extends upward
			y_cursor = -tex_h
			prev_cavity = 0.0
		elif is_first_box:
			# First box on stand: offset forward by BOX_FRONT_OFFSET px.
			# This makes the stand bottom edge extend past the box by 4px
			# (landing board visible below the box front face).
			y_cursor = y_cursor + BOX_FRONT_OFFSET - tex_h
			is_first_box = false
		else:
			# Flush stack: bottom of this sprite = top of previous.
			# If the layer below had an open cavity, overlap into it so
			# there is no visible gap between stacked boxes.
			if tex == _tex_lid:
				# Lid overlaps into the box below to cover the open cavity
				y_cursor -= (tex_h - LID_OVERLAP)
			elif prev_cavity > 0.0:
				# Box-on-box: overlap into the cavity of the box below
				y_cursor -= (tex_h - prev_cavity)
			else:
				y_cursor -= tex_h

		# Track this layer's cavity depth for the next iteration.
		# All open-top box sprites (deep and super drafts) share the same
		# 22-row cavity structure, so they all use BOX_CAVITY.
		if tex == _tex_super_draft or tex == _tex_bottom_deep or tex == _tex_top_mid_deep or tex == _tex_deep_draft:
			prev_cavity = BOX_CAVITY
		else:
			prev_cavity = 0.0

		# DEBUG: trace stacking positions (remove after verifying)
		var _dbg_name: String = "?"
		if tex == _tex_base: _dbg_name = "base"
		elif tex == _tex_stand: _dbg_name = "stand"
		elif tex == _tex_bottom_deep: _dbg_name = "bottom_deep"
		elif tex == _tex_top_mid_deep: _dbg_name = "top_mid_deep"
		elif tex == _tex_deep_draft: _dbg_name = "deep_draft"
		elif tex == _tex_super_draft: _dbg_name = "super_draft"
		elif tex == _tex_super_full: _dbg_name = "super_full"
		elif tex == _tex_lid: _dbg_name = "lid"
		print("[Hive] Layer %d: %s  tex_h=%.1f  y=%.1f  bottom=%.1f  prev_cav=%.1f" % [i, _dbg_name, tex_h, y_cursor, y_cursor + tex_h, prev_cavity])

		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		if is_draft:
			spr.scale = Vector2(DRAFT_SCALE, DRAFT_SCALE)
		spr.position = Vector2(-tex_w / 2.0, y_cursor)
		# Lid renders above boxes (it overlaps the top box cavity).
		# Boxes/excluder render above the player; stand at ground level.
		if tex == _tex_lid:
			spr.z_index = Z_BOXES + 2
		elif is_above:
			spr.z_index = Z_BOXES
		else:
			spr.z_index = Z_GROUND
		spr.z_as_relative = false
		_sprite_stack.add_child(spr)
		layer_to_child[i] = child_idx
		child_idx += 1

		# -- Frame overlay sprite (inside the box cavity) ------------------
		var is_super_layer: bool = (tex == _tex_super_draft or tex == _tex_super_full)
		if (overlay_tex != null or is_super_layer) and is_draft:
			var ov_spr := Sprite2D.new()
			ov_spr.centered = false
			ov_spr.scale = Vector2(DRAFT_SCALE, DRAFT_SCALE)
			if overlay_tex != null:
				ov_spr.texture = overlay_tex
				ov_spr.visible = true
			else:
				ov_spr.visible = false
			# Center the 44px-wide overlay inside the box sprite
			var ov_ref_w: float = 44.0 * DRAFT_SCALE
			var ov_x: float = -tex_w / 2.0 + (tex_w - ov_ref_w) / 2.0
			var ov_y: float = y_cursor + 1.0 * DRAFT_SCALE
			ov_spr.position = Vector2(ov_x, ov_y)
			# Same z as boxes: child insertion order ensures later boxes
			# (supers) draw over earlier overlays (deep frames).
			ov_spr.z_index = Z_BOXES
			ov_spr.z_as_relative = false
			_sprite_stack.add_child(ov_spr)
			if is_super_layer:
				_super_overlay_children.append([child_idx, _super_overlay_children.size()])
			child_idx += 1

	# Remap _super_sprite_indices from layer indices to child indices
	var remapped: Array = []
	for pair in _super_sprite_indices:
		var layer_idx: int = int(pair[0])
		var data_idx: int = int(pair[1])
		if layer_to_child.has(layer_idx):
			remapped.append([layer_to_child[layer_idx], data_idx])
	_super_sprite_indices = remapped

	var top_y: float = y_cursor
	var total_height: int = int(abs(top_y))

	# Update collision shapes
	_update_collision_for_height(total_height, top_y)

	# Position labels above the stack
	if stat_label:
		stat_label.position = Vector2(-16, top_y - 8.0)
	if _prompt_label:
		_prompt_label.position = Vector2(-40, top_y - 12.0)

	# Reposition swarm cloud
	if _swarm_cloud != null:
		_swarm_cloud.set_hive_extents(-4.0, top_y)

## Update collision shapes.
## Area2D (interaction): covers the full visual height for click detection.
## StaticBody2D (physical blocker): covers only the stand/base footprint
##   so the player cannot walk through the hive base, but CAN walk behind
##   (north of) the upper boxes which render on top of the player sprite.
func _update_collision_for_height(total_height: int, top_y: float) -> void:
	# -- Area2D: interaction zone covers the full visual height ---------------
	var area := get_node_or_null("Area2D")
	if area:
		var col := area.get_node_or_null("CollisionShape2D")
		if col and col.shape is RectangleShape2D:
			col.shape.size = Vector2(28, total_height)
			col.position = Vector2(0, top_y + float(total_height) / 2.0)

	# -- StaticBody2D: physical blocker covers the bottom portion ------------
	# In a top-down game the body collision represents the ground footprint.
	# We size it to the full visual width and roughly half the stack height
	# StaticBody2D: only the stand/base footprint blocks the player.
	# The boxes render above the player (z_index=5) for the walk-behind
	# illusion, so the player can walk behind (north of) the hive and
	# appear to be behind the boxes. The stand physically blocks overlap.
	var body := get_node_or_null("StaticBody2D")
	if body:
		var bcol := body.get_node_or_null("CollisionShape2D")
		if bcol and bcol.shape is RectangleShape2D:
			# Stand is 24x12 at scale 1.0. Block a footprint slightly
			# larger than the stand (28x16) centered at ground level.
			bcol.shape.size = Vector2(28, 16)
			bcol.position = Vector2(0, -8)

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

# -- Super Frame Overlay Updates -----------------------------------------------
## Update super frame overlay textures on each tick based on honey fill level.
## This avoids a full sprite stack rebuild when supers gradually fill with honey.
func _update_super_frame_overlays() -> void:
	if not simulation or build_state != BuildState.COMPLETE:
		return
	if _super_overlay_children.is_empty():
		return
	var snap: Dictionary = simulation.last_snapshot
	if snap.is_empty():
		return
	var super_data: Array = snap.get("super_visuals", [])
	if super_data.is_empty():
		return

	var stack_children: Array = _sprite_stack.get_children()
	for pair in _super_overlay_children:
		var ov_child_idx: int = int(pair[0])
		var data_idx: int = int(pair[1])
		if ov_child_idx >= stack_children.size() or data_idx >= super_data.size():
			continue
		var ov_spr: Sprite2D = stack_children[ov_child_idx] as Sprite2D
		if ov_spr == null:
			continue
		var sd: Dictionary = super_data[data_idx]
		var fill: float = sd.get("fill_pct", 0.0)
		if fill < 0.05:
			ov_spr.visible = false
			continue
		var frame_n: int = clampi(int(ceil(fill * 10.0)), 1, 10)
		var idx: int = frame_n - 1
		if idx < _tex_frames.size() and _tex_frames[idx] != null:
			ov_spr.texture = _tex_frames[idx]
			ov_spr.visible = true
		else:
			ov_spr.visible = false

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
				if simulation and simulation.deep_count() < 3:
					_prompt_label.text = "[E] Add Deep Body"
				else:
					_prompt_label.text = "Max Deeps (3)"
			elif held_item == GameData.ITEM_SUPER_BOX:
				if simulation and simulation.super_count() < 5:
					if simulation.has_excluder:
						_prompt_label.text = "[E] Add Honey Super"
					else:
						_prompt_label.text = "[E] Add Super (no excluder!)"
				else:
					_prompt_label.text = "Max Supers (5)"
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

	# Winter: route to passive observation instead of full inspection
	if _is_winter_month():
		_open_winter_observation()
		return

	var overlay = INSPECTION_SCENE.instantiate()
	overlay.add_to_group("inspection_overlay")
	get_tree().current_scene.add_child(overlay)
	overlay.open(self)

## Check if current month is a winter month (Deepcold or Kindlemonth).
func _is_winter_month() -> bool:
	if not TimeManager or not TimeManager.has_method("current_month_index"):
		return false
	return TimeManager.current_month_index() >= 6

## Open the winter observation overlay (passive monitoring).
func _open_winter_observation() -> void:
	var script: GDScript = load("res://scripts/ui/winter_observation.gd") as GDScript
	if script == null:
		push_warning("Hive: could not load winter_observation.gd")
		return
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.set_script(script)
	overlay.add_to_group("inspection_overlay")
	get_tree().current_scene.add_child(overlay)
	overlay.open(self)

# -- Click interaction ---------------------------------------------------------
func _on_area_2d_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if build_state == BuildState.COMPLETE:
			open_inspection()
