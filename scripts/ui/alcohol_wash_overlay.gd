# alcohol_wash_overlay.gd -- Alcohol wash mite monitoring mini-game
# -------------------------------------------------------------------------
# 5-step mini-game: Select brood frame -> Check for queen -> Scoop bees ->
# Shake wash -> Count mites. First-time tutorial has a scripted queen catch.
# Opened from InspectionOverlay when player has ITEM_WASH_KIT in inventory.
# -------------------------------------------------------------------------
extends CanvasLayer

signal wash_complete(mites_per_100: float)
signal wash_cancelled

# -- Layout (320x180 viewport) -------------------------------------------
const VP_W := 320
const VP_H := 180

# -- Steps ----------------------------------------------------------------
enum Step { SELECT_FRAME, QUEEN_CHECK, SCOOP, SHAKE, COUNT }
var _step: int = Step.SELECT_FRAME

# -- State ----------------------------------------------------------------
var _hive_sim = null             # HiveSimulation reference
var _is_first_wash: bool = false # triggers tutorial queen catch
var _queen_found: bool = false   # player confirmed queen absent
var _scoop_gauge: float = 0.0    # 0-1 fill gauge for scooping
var _shake_progress: float = 0.0 # 0-1 progress for shaking
var _shake_gauge: float = 0.0    # current shake speed gauge
var _mite_dots: Array = []       # positions of mite dots for counting
var _player_count: int = 0       # how many mites the player has clicked
var _actual_mites: int = 0       # true sample mite count
var _sample_size: int = 300
var _finished: bool = false
var _tutorial_queen_warning: bool = false  # showing the mentor warning

# -- Shake tuning (matches extractor feel) --------------------------------
const SHAKE_DURATION := 5.0
const SHAKE_DECAY := 0.55
const SHAKE_PER_TAP := 0.20
const SHAKE_THRESHOLD := 0.35

# -- UI Elements ----------------------------------------------------------
var _bg: ColorRect = null
var _title_label: Label = null
var _instruction_label: Label = null
var _status_label: Label = null
var _gauge_bg: ColorRect = null
var _gauge_fill: ColorRect = null
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null
var _count_panel: ColorRect = null
var _count_label: Label = null
var _result_label: Label = null
var _mentor_panel: ColorRect = null
var _mentor_text: Label = null

# =========================================================================
# PUBLIC
# =========================================================================

## Open the wash overlay for a given hive simulation.
func open(hive_simulation, first_wash: bool = false) -> void:
	_hive_sim = hive_simulation
	_is_first_wash = first_wash
	_step = Step.SELECT_FRAME
	_finished = false
	_queen_found = false
	_scoop_gauge = 0.0
	_shake_progress = 0.0
	_shake_gauge = 0.0
	_player_count = 0
	_mite_dots.clear()
	_tutorial_queen_warning = false

# =========================================================================
# LIFECYCLE
# =========================================================================

func _ready() -> void:
	layer = 11
	_build_ui()
	_update_step_display()

func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.03, 0.02, 0.95)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_title_label.position = Vector2(90, 4)
	_title_label.text = "Alcohol Wash"
	add_child(_title_label)

	# Instruction
	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 6)
	_instruction_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80))
	_instruction_label.position = Vector2(20, 20)
	_instruction_label.custom_minimum_size = Vector2(280, 30)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_instruction_label)

	# Status (step counter)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	_status_label.position = Vector2(250, 4)
	add_child(_status_label)

	# Gauge bar (used for scoop + shake)
	_gauge_bg = ColorRect.new()
	_gauge_bg.color = Color(0.15, 0.12, 0.08)
	_gauge_bg.position = Vector2(250, 50)
	_gauge_bg.size = Vector2(16, 80)
	_gauge_bg.visible = false
	add_child(_gauge_bg)

	_gauge_fill = ColorRect.new()
	_gauge_fill.color = Color(0.85, 0.65, 0.20)
	_gauge_fill.position = Vector2(251, 50)
	_gauge_fill.size = Vector2(14, 0)
	_gauge_fill.visible = false
	add_child(_gauge_fill)

	# Progress bar (used for shake step)
	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.15, 0.12, 0.08)
	_progress_bg.position = Vector2(40, 155)
	_progress_bg.size = Vector2(200, 8)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.40, 0.75, 0.30)
	_progress_fill.position = Vector2(40, 155)
	_progress_fill.size = Vector2(0, 8)
	_progress_fill.visible = false
	add_child(_progress_fill)

	# Count panel (white background for mite dots)
	_count_panel = ColorRect.new()
	_count_panel.color = Color(0.95, 0.93, 0.90)
	_count_panel.position = Vector2(40, 45)
	_count_panel.size = Vector2(200, 100)
	_count_panel.visible = false
	add_child(_count_panel)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 6)
	_count_label.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))
	_count_label.position = Vector2(42, 148)
	_count_label.text = "Counted: 0"
	_count_label.visible = false
	add_child(_count_label)

	# Result label (shown after counting)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 7)
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.60))
	_result_label.position = Vector2(20, 60)
	_result_label.custom_minimum_size = Vector2(280, 80)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_result_label.visible = false
	add_child(_result_label)

	# Mentor dialogue panel (for tutorial)
	_mentor_panel = ColorRect.new()
	_mentor_panel.color = Color(0.12, 0.18, 0.12, 0.95)
	_mentor_panel.position = Vector2(20, 55)
	_mentor_panel.size = Vector2(280, 70)
	_mentor_panel.visible = false
	add_child(_mentor_panel)

	_mentor_text = Label.new()
	_mentor_text.add_theme_font_size_override("font_size", 6)
	_mentor_text.add_theme_color_override("font_color", Color(0.85, 0.95, 0.80))
	_mentor_text.position = Vector2(25, 58)
	_mentor_text.custom_minimum_size = Vector2(270, 60)
	_mentor_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_mentor_text.visible = false
	add_child(_mentor_text)

func _process(delta: float) -> void:
	if _finished:
		return
	if _step == Step.SHAKE:
		_process_shake(delta)

# =========================================================================
# INPUT
# =========================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Mentor warning active -- only accept E to dismiss
	if _tutorial_queen_warning:
		if event.keycode == KEY_E:
			_dismiss_mentor_warning()
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_ESCAPE:
			if _step == Step.COUNT and _player_count > 0:
				# Finish counting early -- use player's count
				_finish_count()
			else:
				wash_cancelled.emit()
				queue_free()
		KEY_E:
			_handle_action()
		KEY_SPACE:
			_handle_action()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _step != Step.COUNT or _finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mite_click(event.position)
		get_viewport().set_input_as_handled()

# =========================================================================
# STEP LOGIC
# =========================================================================

func _handle_action() -> void:
	match _step:
		Step.SELECT_FRAME:
			_advance_to_queen_check()
		Step.QUEEN_CHECK:
			_advance_to_scoop()
		Step.SCOOP:
			_do_scoop_tap()
		Step.SHAKE:
			_do_shake_tap()

## Step 1 -> 2: Player selects a brood frame.
func _advance_to_queen_check() -> void:
	if _is_first_wash and not _tutorial_queen_warning:
		# Tutorial: queen is on this frame! Mentor stops you.
		_tutorial_queen_warning = true
		_mentor_panel.visible = true
		_mentor_text.visible = true
		_mentor_text.text = "Ellen: \"Hold on! See that bee with the painted dot? That's your queen. You almost killed her. ALWAYS check for the queen before you scoop.\""
		_instruction_label.text = "[E] to continue..."
		return
	_step = Step.QUEEN_CHECK
	_update_step_display()

func _dismiss_mentor_warning() -> void:
	_tutorial_queen_warning = false
	_mentor_panel.visible = false
	_mentor_text.visible = false
	# Now the player knows -- proceed to queen check step
	_step = Step.QUEEN_CHECK
	_update_step_display()

## Step 2 -> 3: Player confirms queen is not on this frame.
func _advance_to_scoop() -> void:
	_queen_found = true
	_step = Step.SCOOP
	_scoop_gauge = 0.0
	_gauge_bg.visible = true
	_gauge_fill.visible = true
	_update_step_display()

## Step 3: Each tap fills the scoop gauge.
func _do_scoop_tap() -> void:
	if _step != Step.SCOOP:
		return
	_scoop_gauge = minf(_scoop_gauge + 0.15, 1.0)
	_update_gauge(_scoop_gauge)
	if _scoop_gauge >= 1.0:
		_step = Step.SHAKE
		_shake_progress = 0.0
		_shake_gauge = 0.0
		_gauge_bg.visible = true
		_gauge_fill.visible = true
		_progress_bg.visible = true
		_progress_fill.visible = true
		_update_step_display()

## Step 4: Shake processing (called from _process).
func _process_shake(delta: float) -> void:
	_shake_gauge = maxf(0.0, _shake_gauge - SHAKE_DECAY * delta)
	_update_gauge(_shake_gauge)
	if _shake_gauge >= SHAKE_THRESHOLD:
		_shake_progress = minf(_shake_progress + (delta / SHAKE_DURATION), 1.0)
		_progress_fill.size.x = _progress_bg.size.x * _shake_progress
	if _shake_progress >= 1.0:
		_advance_to_count()

func _do_shake_tap() -> void:
	if _step != Step.SHAKE:
		return
	_shake_gauge = minf(_shake_gauge + SHAKE_PER_TAP, 1.0)
	_update_gauge(_shake_gauge)

## Step 4 -> 5: Generate mite dots for counting.
func _advance_to_count() -> void:
	_step = Step.COUNT
	_gauge_bg.visible = false
	_gauge_fill.visible = false
	_progress_bg.visible = false
	_progress_fill.visible = false
	_count_panel.visible = true
	_count_label.visible = true
	_player_count = 0

	# Get actual mite count from simulation
	if _hive_sim and _hive_sim.has_method("get_sample_mite_count"):
		_actual_mites = _hive_sim.get_sample_mite_count(_sample_size)
	else:
		_actual_mites = 0

	# Generate mite dot positions on the white panel
	_mite_dots.clear()
	var panel_pos: Vector2 = _count_panel.position
	var panel_size: Vector2 = _count_panel.size
	for i in range(_actual_mites):
		var dot_x: float = panel_pos.x + 8.0 + randf() * (panel_size.x - 16.0)
		var dot_y: float = panel_pos.y + 8.0 + randf() * (panel_size.y - 16.0)
		_mite_dots.append({"pos": Vector2(dot_x, dot_y), "clicked": false})

	# Draw mite dots on the panel
	_draw_mite_dots()
	_update_step_display()

## Draw small dark-red circles for each mite on the count panel.
func _draw_mite_dots() -> void:
	# Remove any previous dot nodes
	for child in get_children():
		if child.is_in_group("mite_dot"):
			child.queue_free()
	for dot_data in _mite_dots:
		var dot := ColorRect.new()
		dot.color = Color(0.45, 0.08, 0.05)
		dot.size = Vector2(4, 4)
		dot.position = dot_data["pos"] - Vector2(2, 2)
		dot.add_to_group("mite_dot")
		add_child(dot)

## Handle click on mite dots during count step.
func _handle_mite_click(click_pos: Vector2) -> void:
	# Check if click is near any unclicked mite dot
	var click_radius: float = 8.0
	for dot_data in _mite_dots:
		if dot_data["clicked"]:
			continue
		if click_pos.distance_to(dot_data["pos"]) <= click_radius:
			dot_data["clicked"] = true
			_player_count += 1
			_count_label.text = "Counted: %d" % _player_count
			# Visual feedback: brighten clicked dot
			for child in get_children():
				if child.is_in_group("mite_dot"):
					var center: Vector2 = child.position + Vector2(2, 2)
					if center.distance_to(dot_data["pos"]) < 2.0:
						child.color = Color(0.90, 0.30, 0.15)
			break

	# Check if all mites counted
	var all_clicked: bool = true
	for dot_data in _mite_dots:
		if not dot_data["clicked"]:
			all_clicked = false
			break
	if all_clicked and _actual_mites > 0:
		_finish_count()

## Finish the count step and show results.
func _finish_count() -> void:
	_finished = true
	_count_panel.visible = false
	_count_label.visible = false
	# Hide mite dots
	for child in get_children():
		if child.is_in_group("mite_dot"):
			child.queue_free()

	var mites_per_100: float = float(_player_count) / float(_sample_size) * 100.0
	var threshold_text: String = ""
	var result_color: Color = Color(0.40, 0.85, 0.30)
	if mites_per_100 < 1.0:
		threshold_text = "LOW -- Colony looks healthy."
		result_color = Color(0.40, 0.85, 0.30)
	elif mites_per_100 < 3.0:
		threshold_text = "MODERATE -- Monitor closely."
		result_color = Color(0.90, 0.80, 0.20)
	else:
		threshold_text = "HIGH -- Treatment recommended!"
		result_color = Color(0.90, 0.25, 0.15)

	_result_label.visible = true
	_result_label.add_theme_color_override("font_color", result_color)
	_result_label.text = "%d mites / %d bees = %.1f per 100\n%s\n\n[ESC] to close" % [
		_player_count, _sample_size, mites_per_100, threshold_text]

	_instruction_label.text = ""
	_status_label.text = "Done"

	# Report to quest system
	QuestManager.notify_event("mite_wash_complete", {
		"mites_per_100": mites_per_100,
		"player_count": _player_count,
		"actual_mites": _actual_mites,
		"sample_size": _sample_size
	})

	wash_complete.emit(mites_per_100)

# =========================================================================
# UI HELPERS
# =========================================================================

func _update_gauge(value: float) -> void:
	if _gauge_fill:
		var max_h: float = _gauge_bg.size.y
		_gauge_fill.size.y = max_h * value
		# Fill from bottom up
		_gauge_fill.position.y = _gauge_bg.position.y + max_h - _gauge_fill.size.y

func _update_step_display() -> void:
	var step_names: Array = ["1/5 Select Frame", "2/5 Queen Check", "3/5 Scoop Bees",
							 "4/5 Shake Wash", "5/5 Count Mites"]
	if _step < step_names.size():
		_status_label.text = step_names[_step]

	match _step:
		Step.SELECT_FRAME:
			_instruction_label.text = "Pick a brood frame for sampling.\n[E] Select this frame"
		Step.QUEEN_CHECK:
			_instruction_label.text = "Scan the frame -- is the queen here?\nConfirm she is ABSENT before scooping.\n[E] Queen not present - proceed"
		Step.SCOOP:
			_instruction_label.text = "Scoop ~300 bees into the jar.\nTap [E] to fill the jar."
		Step.SHAKE:
			_instruction_label.text = "Add alcohol and shake! Tap [E] rapidly.\nKeep the gauge above the line."
		Step.COUNT:
			_instruction_label.text = "Click each mite (dark red dot) to count.\n[ESC] when done counting."
