# bottling_minigame.gd - Honey jar filling minigame overlay.
# Player presses E to open the honey gate. Honey fills the jar visually.
# When the jar is full, it auto-stops and places the jar on the table.
# Jars stack in groups of 10. Player fills up to 40 jars per session.
# -------------------------------------------------------------------------
extends CanvasLayer

signal bottling_complete(jars_filled: int)
signal bottling_cancelled(jars_filled: int, jars_unused: int)

# -- Tuning ---------------------------------------------------------------
const FILL_RATE := 0.6               # Jar fills per second (0 to 1) when gate open
const JAR_CAPACITY := 1.0            # 1 lb per jar
const MAX_JARS_PER_SESSION := 40

# -- State ----------------------------------------------------------------
var _honey_available: float = 0.0     # lbs of honey in bucket
var _jars_available: int = 0          # Empty jars from inventory
var _jars_filled: int = 0             # Jars completed this session
var _current_fill: float = 0.0        # Current jar fill level (0 to 1)
var _gate_open: bool = false          # Is the honey gate open
@warning_ignore("unused_private_class_variable")
var _jar_complete: bool = false       # Current jar just finished
var _session_done: bool = false       # All jars done or honey empty
var _placing_jar: bool = false        # Brief pause while placing jar on table

# -- UI Elements ----------------------------------------------------------
var _bg: ColorRect = null
var _jar_bg: ColorRect = null         # Jar outline
var _jar_fill: ColorRect = null       # Honey in jar (grows upward)
var _gate_indicator: ColorRect = null  # Shows gate open/closed
var _table_panel: ColorRect = null    # Table showing filled jars
var _title_label: Label = null
var _status_label: Label = null
var _count_label: Label = null
var _instruction_label: Label = null
var _honey_label: Label = null

# -- Layout (320x180 viewport) -------------------------------------------
const JAR_X := 130
const JAR_Y := 30
const JAR_W := 30
const JAR_H := 70

const TABLE_X := 200
const TABLE_Y := 40
const TABLE_W := 100
const TABLE_H := 100

# =========================================================================
# LIFECYCLE
# =========================================================================
## Initialize the bottling minigame UI and load metadata.
func _ready() -> void:
	# Read meta data passed from harvest_yard
	_honey_available = get_meta("honey_available", 0.0) as float
	_jars_available = get_meta("jars_available", 0) as int
	_build_ui()

## Build all UI elements for the bottling minigame.
func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "Bottling Table"
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_title_label.position = Vector2(110, 5)
	add_child(_title_label)

	# Honey gate area (above jar)
	var gate_label: Label = Label.new()
	gate_label.text = "Honey Gate"
	gate_label.add_theme_font_size_override("font_size", 4)
	gate_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	gate_label.position = Vector2(JAR_X - 5, JAR_Y - 18)
	add_child(gate_label)

	_gate_indicator = ColorRect.new()
	_gate_indicator.size = Vector2(JAR_W, 6)
	_gate_indicator.position = Vector2(JAR_X, JAR_Y - 8)
	_gate_indicator.color = Color(0.50, 0.35, 0.20, 1.0)  # Closed: brown
	add_child(_gate_indicator)

	# Jar outline
	_jar_bg = ColorRect.new()
	_jar_bg.color = Color(0.85, 0.90, 0.92, 0.4)  # Glass-like
	_jar_bg.size = Vector2(JAR_W, JAR_H)
	_jar_bg.position = Vector2(JAR_X, JAR_Y)
	add_child(_jar_bg)

	# Jar border
	var jar_border: ColorRect = ColorRect.new()
	jar_border.color = Color(0.5, 0.55, 0.58, 0.8)
	jar_border.size = Vector2(JAR_W + 4, JAR_H + 4)
	jar_border.position = Vector2(JAR_X - 2, JAR_Y - 2)
	jar_border.z_index = -1
	add_child(jar_border)

	# Honey fill (starts empty, grows from bottom)
	_jar_fill = ColorRect.new()
	_jar_fill.color = Color(0.92, 0.75, 0.20, 0.9)  # Honey amber
	_jar_fill.size = Vector2(JAR_W - 4, 0)
	_jar_fill.position = Vector2(JAR_X + 2, JAR_Y + JAR_H)
	add_child(_jar_fill)

	# Table for filled jars
	_table_panel = ColorRect.new()
	_table_panel.color = Color(0.55, 0.40, 0.22, 1.0)
	_table_panel.size = Vector2(TABLE_W, TABLE_H)
	_table_panel.position = Vector2(TABLE_X, TABLE_Y)
	add_child(_table_panel)

	var table_label: Label = Label.new()
	table_label.text = "Filled Jars"
	table_label.add_theme_font_size_override("font_size", 4)
	table_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	table_label.position = Vector2(TABLE_X + 4, TABLE_Y - 10)
	add_child(table_label)

	# Count label
	_count_label = Label.new()
	_count_label.text = "0 / %d jars" % _jars_available
	_count_label.add_theme_font_size_override("font_size", 5)
	_count_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
	_count_label.position = Vector2(TABLE_X + 4, TABLE_Y + TABLE_H + 4)
	add_child(_count_label)

	# Honey remaining
	_honey_label = Label.new()
	_honey_label.text = "Honey: %.1f lbs" % _honey_available
	_honey_label.add_theme_font_size_override("font_size", 4)
	_honey_label.add_theme_color_override("font_color", Color(0.8, 0.72, 0.45))
	_honey_label.position = Vector2(20, JAR_Y + JAR_H + 10)
	add_child(_honey_label)

	# Status
	_status_label = Label.new()
	_status_label.text = "Press [E] to open honey gate"
	_status_label.add_theme_font_size_override("font_size", 5)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_status_label.position = Vector2(30, JAR_Y + JAR_H + 25)
	add_child(_status_label)

	# Instructions
	_instruction_label = Label.new()
	_instruction_label.text = "[E] Open/Close gate | [ESC] Finish"
	_instruction_label.add_theme_font_size_override("font_size", 4)
	_instruction_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_instruction_label.position = Vector2(60, 170)
	add_child(_instruction_label)

# =========================================================================
# INPUT
# =========================================================================
## Handle input events: E to toggle gate, ESC to finish.
func _input(event: InputEvent) -> void:
	if _session_done:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_ESCAPE:
		_finish_session(true)
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_E:
		if _placing_jar:
			get_viewport().set_input_as_handled()
			return
		_gate_open = not _gate_open
		_update_gate_visual()
		if _gate_open:
			_status_label.text = "Gate open - honey flowing..."
		else:
			_status_label.text = "Gate closed. Press [E] to open."
		get_viewport().set_input_as_handled()
		return

# =========================================================================
# PROCESS
# =========================================================================
## Update jar filling and check for session completion.
func _process(delta: float) -> void:
	if _session_done or _placing_jar:
		return

	if _gate_open and _honey_available > 0.0:
		# Fill the jar
		var fill_amount: float = FILL_RATE * delta
		_current_fill = clampf(_current_fill + fill_amount, 0.0, 1.0)
		_honey_available = maxf(0.0, _honey_available - fill_amount * JAR_CAPACITY)
		_update_jar_visual()
		_update_honey_label()

		# Check if jar is full
		if _current_fill >= 1.0:
			_gate_open = false
			_update_gate_visual()
			_place_jar()

	if _honey_available <= 0.01 and not _gate_open:
		if _jars_filled > 0 or _current_fill > 0:
			_finish_session(false)

## Place a completed jar on the table and reset or finish.
func _place_jar() -> void:
	_placing_jar = true
	_jars_filled += 1
	_jars_available -= 1
	_current_fill = 0.0

	_status_label.text = "Jar filled! %d done." % _jars_filled
	_update_count_label()
	_draw_filled_jar_on_table()

	# Check if we're done
	if _jars_available <= 0 or _honey_available < 0.5 or _jars_filled >= MAX_JARS_PER_SESSION:
		var done_timer: SceneTreeTimer = get_tree().create_timer(0.8)
		done_timer.timeout.connect(func(): _finish_session(false))
		return

	# Reset jar for next fill after brief pause
	var reset_timer: SceneTreeTimer = get_tree().create_timer(0.5)
	reset_timer.timeout.connect(_reset_jar)

## Reset the jar for another fill cycle.
func _reset_jar() -> void:
	_placing_jar = false
	_current_fill = 0.0
	_update_jar_visual()
	_status_label.text = "Press [E] to fill next jar"

## Finish the session and emit appropriate signal.
func _finish_session(cancelled: bool) -> void:
	_session_done = true
	_gate_open = false
	if cancelled:
		_status_label.text = "Bottling stopped. %d jars filled." % _jars_filled
		var cancel_timer: SceneTreeTimer = get_tree().create_timer(0.8)
		cancel_timer.timeout.connect(func(): bottling_cancelled.emit(_jars_filled, _jars_available))
	else:
		_status_label.text = "Bottling complete! %d jars filled." % _jars_filled
		_instruction_label.text = ""
		var finish_timer: SceneTreeTimer = get_tree().create_timer(1.0)
		finish_timer.timeout.connect(func(): bottling_complete.emit(_jars_filled))

# =========================================================================
# VISUAL UPDATES
# =========================================================================
## Update the jar fill visual based on current fill level.
func _update_jar_visual() -> void:
	if _jar_fill == null:
		return
	var fill_h: float = float(JAR_H - 4) * _current_fill
	_jar_fill.size = Vector2(float(JAR_W) - 4.0, fill_h)
	_jar_fill.position = Vector2(
		float(JAR_X) + 2.0,
		float(JAR_Y) + float(JAR_H) - 2.0 - fill_h)

## Update the honey gate visual based on open/closed state.
func _update_gate_visual() -> void:
	if _gate_indicator == null:
		return
	if _gate_open:
		_gate_indicator.color = Color(0.90, 0.72, 0.20, 1.0)  # Open: honey gold
	else:
		_gate_indicator.color = Color(0.50, 0.35, 0.20, 1.0)  # Closed: brown

## Update the jar count label.
func _update_count_label() -> void:
	if _count_label:
		_count_label.text = "%d / %d jars" % [_jars_filled, _jars_filled + _jars_available]

## Update the honey remaining label.
func _update_honey_label() -> void:
	if _honey_label:
		_honey_label.text = "Honey: %.1f lbs" % _honey_available

## Draw a small jar icon on the table to represent a filled jar.
func _draw_filled_jar_on_table() -> void:
	# Add a small jar icon on the table panel
	var jar_w: int = 6
	var jar_h: int = 10
	var jar_gap: int = 2
	@warning_ignore("integer_division")
	var stack: int = (_jars_filled - 1) / 5
	var in_stack: int = (_jars_filled - 1) % 5
	var jx: float = float(TABLE_X + 6 + stack * (jar_w + 4))
	var jy: float = float(TABLE_Y + TABLE_H - 14 - in_stack * (jar_h + jar_gap))

	var jar_icon: ColorRect = ColorRect.new()
	jar_icon.color = Color(0.92, 0.75, 0.20, 0.9)
	jar_icon.size = Vector2(jar_w, jar_h)
	jar_icon.position = Vector2(jx, jy)
	add_child(jar_icon)

	# Jar lid
	var lid: ColorRect = ColorRect.new()
	lid.color = Color(0.65, 0.55, 0.35, 1.0)
	lid.size = Vector2(jar_w + 2, 2)
	lid.position = Vector2(jx - 1, jy - 2)
	add_child(lid)
