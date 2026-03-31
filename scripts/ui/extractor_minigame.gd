# extractor_minigame.gd -- Honey extractor button-mash minigame overlay.
# Player taps E continuously for ~20 seconds to extract honey.
# A speed gauge tracks tap frequency -- must stay above 60% to make progress.
# -------------------------------------------------------------------------
extends CanvasLayer

signal extraction_complete
signal extraction_cancelled

# -- Tuning constants -----------------------------------------------------
# Target feel: ~3 taps/sec to maintain threshold, ~10 seconds to complete.
# Old decay 1.8 + tap 0.15 required 12 taps/sec -- impossible to sustain.
# New: decay 0.65, tap 0.22 => need 0.65/0.22 = ~3 taps/sec to hold 40%+.
const EXTRACT_DURATION := 10.0       # Seconds of sustained effort needed
const GAUGE_DECAY_RATE := 0.65       # Gauge drops per second (0-1 range)
const GAUGE_PER_TAP := 0.22          # Each E tap adds this to gauge
const GAUGE_MAX := 1.0
const PROGRESS_THRESHOLD := 0.40     # Gauge must be above this to gain progress
const PROGRESS_RATE := 0.10          # Progress gained per second when above threshold

# -- State ----------------------------------------------------------------
var _gauge: float = 0.0              # Current speed gauge (0.0 to 1.0)
var _progress: float = 0.0           # Extraction progress (0.0 to 1.0)
var _finished: bool = false
var _elapsed: float = 0.0

# -- UI Elements ----------------------------------------------------------
var _bg: ColorRect = null
var _gauge_bg: ColorRect = null
var _gauge_fill: ColorRect = null
var _gauge_threshold_line: ColorRect = null
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null
var _title_label: Label = null
var _gauge_label: Label = null
var _progress_label: Label = null
var _instruction_label: Label = null
var _status_label: Label = null

# Extractor visual
var _extractor_circle: ColorRect = null

# -- Layout (320x180 viewport) -------------------------------------------
const GAUGE_X := 240
const GAUGE_Y := 30
const GAUGE_W := 20
const GAUGE_H := 100

const PROG_X := 40
const PROG_Y := 155
const PROG_W := 200
const PROG_H := 10

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "Honey Extractor"
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_title_label.position = Vector2(100, 5)
	add_child(_title_label)

	# Extractor visual (simple circle in center)
	var ext_visual := ColorRect.new()
	ext_visual.color = Color(0.50, 0.52, 0.54, 1.0)
	ext_visual.size = Vector2(80, 80)
	ext_visual.position = Vector2(120, 40)
	add_child(ext_visual)

	# Inner circle label
	var ext_label := Label.new()
	ext_label.text = "SPIN"
	ext_label.add_theme_font_size_override("font_size", 7)
	ext_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	ext_label.position = Vector2(143, 70)
	add_child(ext_label)

	# Speed Gauge (vertical bar on right)
	_gauge_label = Label.new()
	_gauge_label.text = "Speed"
	_gauge_label.add_theme_font_size_override("font_size", 5)
	_gauge_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	_gauge_label.position = Vector2(GAUGE_X - 2, GAUGE_Y - 12)
	add_child(_gauge_label)

	_gauge_bg = ColorRect.new()
	_gauge_bg.color = Color(0.15, 0.15, 0.15, 1.0)
	_gauge_bg.size = Vector2(GAUGE_W, GAUGE_H)
	_gauge_bg.position = Vector2(GAUGE_X, GAUGE_Y)
	add_child(_gauge_bg)

	_gauge_fill = ColorRect.new()
	_gauge_fill.color = Color(0.30, 0.70, 0.30, 1.0)  # Green when OK
	_gauge_fill.size = Vector2(GAUGE_W - 4, 0)
	_gauge_fill.position = Vector2(GAUGE_X + 2, GAUGE_Y + GAUGE_H)
	add_child(_gauge_fill)

	# 60% threshold line
	_gauge_threshold_line = ColorRect.new()
	_gauge_threshold_line.color = Color(0.95, 0.40, 0.30, 1.0)
	var threshold_y: float = float(GAUGE_Y) + float(GAUGE_H) * (1.0 - PROGRESS_THRESHOLD)
	_gauge_threshold_line.size = Vector2(GAUGE_W + 8, 1)
	_gauge_threshold_line.position = Vector2(float(GAUGE_X) - 4.0, threshold_y)
	add_child(_gauge_threshold_line)

	# 40% label
	var thresh_label := Label.new()
	thresh_label.text = "40%"
	thresh_label.add_theme_font_size_override("font_size", 4)
	thresh_label.add_theme_color_override("font_color", Color(0.95, 0.40, 0.30))
	thresh_label.position = Vector2(float(GAUGE_X) + float(GAUGE_W) + 4.0, threshold_y - 4.0)
	add_child(thresh_label)

	# Progress bar (bottom)
	_progress_label = Label.new()
	_progress_label.text = "Extraction: 0%"
	_progress_label.add_theme_font_size_override("font_size", 5)
	_progress_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
	_progress_label.position = Vector2(PROG_X, PROG_Y - 12)
	add_child(_progress_label)

	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.15, 0.15, 0.15, 1.0)
	_progress_bg.size = Vector2(PROG_W, PROG_H)
	_progress_bg.position = Vector2(PROG_X, PROG_Y)
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.95, 0.78, 0.25, 1.0)
	_progress_fill.size = Vector2(0, PROG_H - 2)
	_progress_fill.position = Vector2(PROG_X + 1, PROG_Y + 1)
	add_child(_progress_fill)

	# Instructions
	_instruction_label = Label.new()
	_instruction_label.text = "Tap [E] fast! Keep gauge above red line. | ESC to cancel"
	_instruction_label.add_theme_font_size_override("font_size", 4)
	_instruction_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_instruction_label.position = Vector2(30, 170)
	add_child(_instruction_label)

	# Status feedback
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_status_label.position = Vector2(120, 125)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status_label)

# =========================================================================
# INPUT
# =========================================================================
func _input(event: InputEvent) -> void:
	if _finished:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not event.echo:
			extraction_cancelled.emit()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_E:
			_gauge = clampf(_gauge + GAUGE_PER_TAP, 0.0, GAUGE_MAX)
			_update_gauge_visual()
			get_viewport().set_input_as_handled()
			return

# =========================================================================
# PROCESS
# =========================================================================
func _process(delta: float) -> void:
	if _finished:
		return

	_elapsed += delta

	# Decay the gauge
	_gauge = clampf(_gauge - GAUGE_DECAY_RATE * delta, 0.0, GAUGE_MAX)

	# Accumulate progress if gauge is above threshold
	if _gauge >= PROGRESS_THRESHOLD:
		_progress = clampf(_progress + PROGRESS_RATE * delta, 0.0, 1.0)
		_status_label.text = "Extracting..."
		_status_label.add_theme_color_override("font_color", Color(0.40, 0.90, 0.40))
	else:
		_status_label.text = "Tap faster!"
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.40, 0.30))

	_update_gauge_visual()
	_update_progress_visual()

	# Check completion
	if _progress >= 1.0:
		_finished = true
		_status_label.text = "Extraction complete!"
		_status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
		_instruction_label.text = ""
		var timer: SceneTreeTimer = get_tree().create_timer(1.2)
		timer.timeout.connect(_emit_complete)

func _emit_complete() -> void:
	extraction_complete.emit()

# =========================================================================
# VISUAL UPDATES
# =========================================================================
func _update_gauge_visual() -> void:
	if _gauge_fill == null:
		return
	var fill_h: float = float(GAUGE_H - 4) * _gauge
	_gauge_fill.size = Vector2(float(GAUGE_W) - 4.0, fill_h)
	_gauge_fill.position = Vector2(
		float(GAUGE_X) + 2.0,
		float(GAUGE_Y) + float(GAUGE_H) - 2.0 - fill_h)

	# Color based on threshold
	if _gauge >= PROGRESS_THRESHOLD:
		_gauge_fill.color = Color(0.30, 0.80, 0.30, 1.0)  # Green
	else:
		_gauge_fill.color = Color(0.90, 0.35, 0.25, 1.0)  # Red

func _update_progress_visual() -> void:
	if _progress_fill == null:
		return
	_progress_fill.size.x = float(PROG_W - 2) * _progress
	if _progress_label:
		_progress_label.text = "Extraction: %d%%" % int(_progress * 100.0)
