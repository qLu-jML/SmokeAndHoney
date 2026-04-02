# chopping_minigame.gd - Tree chopping minigame overlay.
# Player times axe swings by pressing space when a moving power marker hits
# the green "sweet spot" zone on a swing meter. Good timing = deeper cut.
# Requires 6-8 good hits to fell a tree, yielding 3-5 logs.
# Follows the same CanvasLayer pattern as scraping_minigame.gd.
# -------------------------------------------------------------------------
extends CanvasLayer

signal chopping_complete(logs_earned: int)
signal chopping_cancelled

# -- Tuning ---------------------------------------------------------------
const HITS_TO_FELL := 7           # Total good hits needed to fell the tree
const ENERGY_COST := 15.0         # Energy consumed per tree
const LOGS_MIN := 3               # Min logs earned
const LOGS_MAX := 5               # Max logs earned
const SWEET_SPOT_WIDTH := 0.15    # Fraction of meter that is "sweet spot"
const OK_SPOT_WIDTH := 0.25       # Fraction that is "ok" zone (half damage)
const METER_SPEED_BASE := 1.8     # Oscillation speed (cycles/sec)
const METER_SPEED_RAMP := 0.15    # Speed increase per successful hit

# -- Meter state ----------------------------------------------------------
var _meter_pos: float = 0.0       # 0.0 to 1.0 oscillating
var _meter_dir: float = 1.0       # +1 going right, -1 going left
var _sweet_center: float = 0.5    # Where the sweet spot is (shifts each swing)
var _current_speed: float = METER_SPEED_BASE

# -- Progress -------------------------------------------------------------
var _good_hits: int = 0           # Accumulated "good hit" points
var _total_swings: int = 0
var _is_complete: bool = false
var _waiting_for_swing: bool = true  # Accept clicks
var _swing_cooldown: float = 0.0

# -- Visual elements ------------------------------------------------------
var _bg: ColorRect = null
var _trunk_rect: ColorRect = null
var _meter_bg: ColorRect = null
var _sweet_rect: ColorRect = null
var _ok_left_rect: ColorRect = null
var _ok_right_rect: ColorRect = null
var _indicator: ColorRect = null
var _progress_label: Label = null
var _feedback_label: Label = null
var _instruction_label: Label = null
var _title_label: Label = null
var _cut_marks: Array = []        # Visual notch marks on the trunk

# -- Layout (320x180 viewport) -------------------------------------------
const TRUNK_X := 110
const TRUNK_Y := 20
const TRUNK_W := 100
const TRUNK_H := 90

const METER_X := 40
const METER_Y := 130
const METER_W := 240
const METER_H := 14

# =========================================================================
# LIFECYCLE
# =========================================================================
## Initialize the chopping minigame UI.
func _ready() -> void:
	_build_ui()
	_randomize_sweet_spot()

## Build all UI elements for the chopping minigame.
func _build_ui() -> void:
	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.80)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "Chop Tree"
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	_title_label.position = Vector2(TRUNK_X + 20, 4)
	add_child(_title_label)

	# Tree trunk cross-section (brown circle-ish rectangle)
	_trunk_rect = ColorRect.new()
	_trunk_rect.color = Color(0.45, 0.30, 0.15, 1.0)  # Dark wood brown
	_trunk_rect.position = Vector2(TRUNK_X, TRUNK_Y)
	_trunk_rect.size = Vector2(TRUNK_W, TRUNK_H)
	add_child(_trunk_rect)

	# Bark ring (slightly darker border)
	var bark: ColorRect = ColorRect.new()
	bark.color = Color(0.30, 0.20, 0.10, 1.0)
	bark.position = Vector2(TRUNK_X - 3, TRUNK_Y - 3)
	bark.size = Vector2(TRUNK_W + 6, TRUNK_H + 6)
	bark.z_index = -1
	add_child(bark)

	# Progress label (shows cuts / needed)
	_progress_label = Label.new()
	_progress_label.text = "Cuts: 0 / %d" % HITS_TO_FELL
	_progress_label.add_theme_font_size_override("font_size", 6)
	_progress_label.add_theme_color_override("font_color", Color(0.90, 0.85, 0.60))
	_progress_label.position = Vector2(TRUNK_X + TRUNK_W + 12, TRUNK_Y + 10)
	add_child(_progress_label)

	# Feedback label (shows "Perfect!" / "OK" / "Miss!")
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.add_theme_font_size_override("font_size", 7)
	_feedback_label.add_theme_color_override("font_color", Color(0.40, 0.90, 0.40))
	_feedback_label.position = Vector2(TRUNK_X + TRUNK_W + 12, TRUNK_Y + 30)
	add_child(_feedback_label)

	# -- Swing meter background (grey bar) --
	_meter_bg = ColorRect.new()
	_meter_bg.color = Color(0.25, 0.25, 0.25, 1.0)
	_meter_bg.position = Vector2(METER_X, METER_Y)
	_meter_bg.size = Vector2(METER_W, METER_H)
	add_child(_meter_bg)

	# OK zones (yellow, drawn first so sweet spot overlays)
	_ok_left_rect = ColorRect.new()
	_ok_left_rect.color = Color(0.85, 0.75, 0.20, 0.7)
	add_child(_ok_left_rect)

	_ok_right_rect = ColorRect.new()
	_ok_right_rect.color = Color(0.85, 0.75, 0.20, 0.7)
	add_child(_ok_right_rect)

	# Sweet spot (green zone on the meter)
	_sweet_rect = ColorRect.new()
	_sweet_rect.color = Color(0.20, 0.80, 0.20, 0.8)
	add_child(_sweet_rect)

	# Moving indicator (white line)
	_indicator = ColorRect.new()
	_indicator.color = Color(1.0, 1.0, 1.0, 0.95)
	_indicator.size = Vector2(3, METER_H + 4)
	add_child(_indicator)

	# Instructions
	_instruction_label = Label.new()
	_instruction_label.text = "Press SPACE to swing | ESC to cancel"
	_instruction_label.add_theme_font_size_override("font_size", 5)
	_instruction_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	_instruction_label.position = Vector2(METER_X, METER_Y + METER_H + 6)
	add_child(_instruction_label)

	_update_sweet_spot_visuals()

## Randomize the sweet spot position for the next swing.
func _randomize_sweet_spot() -> void:
	# Place sweet spot randomly but not too close to edges
	_sweet_center = randf_range(0.2, 0.8)
	_meter_pos = 0.0
	_meter_dir = 1.0
	_update_sweet_spot_visuals()

## Update the visual position of the sweet spot and OK zones.
func _update_sweet_spot_visuals() -> void:
	if not _sweet_rect:
		return
	var half_sweet: float = SWEET_SPOT_WIDTH / 2.0
	var half_ok: float = OK_SPOT_WIDTH / 2.0

	# Sweet spot rect
	var sx: float = METER_X + (_sweet_center - half_sweet) * METER_W
	_sweet_rect.position = Vector2(sx, METER_Y)
	_sweet_rect.size = Vector2(SWEET_SPOT_WIDTH * METER_W, METER_H)

	# OK zones flanking the sweet spot
	var ok_left_start: float = _sweet_center - half_sweet - half_ok
	var ok_right_start: float = _sweet_center + half_sweet
	_ok_left_rect.position = Vector2(METER_X + maxf(0.0, ok_left_start) * METER_W, METER_Y)
	_ok_left_rect.size = Vector2(minf(half_ok, _sweet_center - half_sweet) * METER_W, METER_H)
	_ok_right_rect.position = Vector2(METER_X + ok_right_start * METER_W, METER_Y)
	_ok_right_rect.size = Vector2(minf(half_ok, 1.0 - _sweet_center - half_sweet) * METER_W, METER_H)

# =========================================================================
# FRAME UPDATE
# =========================================================================
## Update meter oscillation and indicator position.
func _process(delta: float) -> void:
	if _is_complete:
		return

	# Swing cooldown
	if _swing_cooldown > 0.0:
		_swing_cooldown -= delta
		if _swing_cooldown <= 0.0:
			_waiting_for_swing = true
			_feedback_label.text = ""

	# Oscillate the indicator back and forth
	if _waiting_for_swing:
		_meter_pos += _meter_dir * _current_speed * delta
		if _meter_pos >= 1.0:
			_meter_pos = 1.0
			_meter_dir = -1.0
		elif _meter_pos <= 0.0:
			_meter_pos = 0.0
			_meter_dir = 1.0

	# Update indicator visual position
	if _indicator:
		_indicator.position = Vector2(
			METER_X + _meter_pos * METER_W - 1,
			METER_Y - 2)

# =========================================================================
# INPUT
# =========================================================================
## Handle input events: SPACE to swing, ESC to cancel.
func _input(event: InputEvent) -> void:
	if _is_complete:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_ESCAPE:
			chopping_cancelled.emit()
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			if _waiting_for_swing:
				_do_swing()
				get_viewport().set_input_as_handled()

# =========================================================================
# SWING LOGIC
# =========================================================================
## Process a swing and determine its quality based on meter position.
func _do_swing() -> void:
	_waiting_for_swing = false
	_total_swings += 1

	var half_sweet: float = SWEET_SPOT_WIDTH / 2.0
	var half_ok: float = OK_SPOT_WIDTH / 2.0
	var dist: float = absf(_meter_pos - _sweet_center)

	var hit_quality: int = 0  # 0=miss, 1=ok, 2=perfect

	if dist <= half_sweet:
		hit_quality = 2  # Perfect -- in the green zone
	elif dist <= half_sweet + half_ok:
		hit_quality = 1  # OK -- in the yellow zone
	else:
		hit_quality = 0  # Miss -- in the grey

	match hit_quality:
		2:
			_good_hits += 1
			_feedback_label.add_theme_color_override("font_color", Color(0.30, 0.95, 0.30))
			_feedback_label.text = "Perfect!"
			_add_cut_mark(Color(0.85, 0.70, 0.35))
		1:
			# OK hit counts as half a good hit (need 2 OKs = 1 good)
			# We track in integers, so just add 1 and require more total
			_good_hits += 1
			_feedback_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.25))
			_feedback_label.text = "OK"
			_add_cut_mark(Color(0.70, 0.55, 0.25))
		0:
			_feedback_label.add_theme_color_override("font_color", Color(0.90, 0.30, 0.30))
			_feedback_label.text = "Miss!"

	# Update progress
	_progress_label.text = "Cuts: %d / %d" % [_good_hits, HITS_TO_FELL]

	# Speed up slightly after each swing
	_current_speed += METER_SPEED_RAMP

	# Cooldown before next swing
	_swing_cooldown = 0.4

	# Check completion
	if _good_hits >= HITS_TO_FELL:
		_fell_tree()
	else:
		# Move sweet spot for next swing
		_randomize_sweet_spot()

## Add a visual cut mark on the trunk.
func _add_cut_mark(color: Color) -> void:
	# Add a visual notch on the trunk to show progress
	var mark: ColorRect = ColorRect.new()
	var mark_y: float = TRUNK_Y + 8.0 + _good_hits * 10.0
	if mark_y > TRUNK_Y + TRUNK_H - 8:
		mark_y = TRUNK_Y + TRUNK_H - 8
	mark.position = Vector2(TRUNK_X + 4, mark_y)
	mark.size = Vector2(TRUNK_W - 8, 3)
	mark.color = color
	add_child(mark)
	_cut_marks.append(mark)

## Complete the tree chopping and emit completion signal.
func _fell_tree() -> void:
	_is_complete = true
	_instruction_label.text = "Timber!"
	_feedback_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.40))
	_feedback_label.text = "Tree felled!"

	# Calculate logs earned based on swing accuracy
	var accuracy: float = float(_good_hits) / float(maxi(_total_swings, 1))
	var logs: int = LOGS_MIN
	if accuracy >= 0.85:
		logs = LOGS_MAX
	elif accuracy >= 0.65:
		logs = LOGS_MIN + 1
	else:
		logs = LOGS_MIN

	_progress_label.text = "%d logs!" % logs

	# Deduct energy
	GameData.deduct_energy(ENERGY_COST)

	# Award XP for equipment crafting (simple end)
	GameData.add_xp(GameData.XP_EQUIPMENT_CRAFTED_MIN)

	# Delay then emit completion
	var timer: SceneTreeTimer = get_tree().create_timer(1.2)
	timer.timeout.connect(func(): chopping_complete.emit(logs))
