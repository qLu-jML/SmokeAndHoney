# scraping_minigame.gd -- Interactive honeycomb de-capping minigame overlay.
# Player clicks and drags a scraper tool across the comb to uncap cells.
# Each cell has a 95% chance of being uncapped when the scraper passes over,
# dropping to 80% once the frame side is 90% done.
# Both sides of the frame must be scraped to complete.
# -------------------------------------------------------------------------
extends CanvasLayer

signal scraping_complete
signal scraping_cancelled

# -- Grid layout ----------------------------------------------------------
const GRID_COLS := 24
const GRID_ROWS := 14
const CELL_SIZE := 8       # pixels per cell
const TOTAL_CELLS: int = GRID_COLS * GRID_ROWS  # 336 per side

# -- Probabilities --------------------------------------------------------
const UNCAP_CHANCE_NORMAL := 0.95
const UNCAP_CHANCE_LATE := 0.80
const LATE_THRESHOLD := 0.90   # Switch to late chance after 90% uncapped

# -- Frame state ----------------------------------------------------------
var _current_side: int = 0     # 0 = Side A, 1 = Side B
var _cells: Array = []         # Array of bool (true = uncapped)
var _cells_uncapped: int = 0
var _side_complete: bool = false
var _frame_complete: bool = false

# -- Scraper state --------------------------------------------------------
var _scraping: bool = false    # Mouse button held
var _scraper_pos: Vector2 = Vector2.ZERO
var _last_scrape_cell: Vector2i = Vector2i(-1, -1)

# -- Visual elements ------------------------------------------------------
var _bg: ColorRect = null
var _frame_panel: Control = null
var _side_label: Label = null
var _progress_label: Label = null
var _instruction_label: Label = null
var _cell_rects: Array = []    # Array of ColorRect for each cell

# -- Layout constants (viewport is 320x180) -------------------------------
const FRAME_X := 28
const FRAME_Y := 20
const FRAME_W: int = GRID_COLS * CELL_SIZE  # 192
const FRAME_H: int = GRID_ROWS * CELL_SIZE  # 112

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	_build_ui()
	_init_side(0)

func _build_ui() -> void:
	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Frame panel background (honeycomb area)
	_frame_panel = Control.new()
	_frame_panel.position = Vector2(FRAME_X, FRAME_Y)
	_frame_panel.size = Vector2(FRAME_W, FRAME_H)
	add_child(_frame_panel)

	# Frame border
	var border := ColorRect.new()
	border.color = Color(0.40, 0.28, 0.12, 1.0)
	border.position = Vector2(FRAME_X - 2, FRAME_Y - 2)
	border.size = Vector2(FRAME_W + 4, FRAME_H + 4)
	border.z_index = -1
	add_child(border)

	# Cell grid
	_cell_rects.clear()
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell := ColorRect.new()
			cell.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			cell.position = Vector2(
				FRAME_X + col * CELL_SIZE,
				FRAME_Y + row * CELL_SIZE)
			cell.color = Color(0.72, 0.58, 0.28, 1.0)  # Capped: golden wax
			add_child(cell)
			_cell_rects.append(cell)

	# Side label
	_side_label = Label.new()
	_side_label.text = "Side A"
	_side_label.add_theme_font_size_override("font_size", 7)
	_side_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_side_label.position = Vector2(FRAME_X + FRAME_W + 10, FRAME_Y)
	add_child(_side_label)

	# Progress label
	_progress_label = Label.new()
	_progress_label.text = "0%"
	_progress_label.add_theme_font_size_override("font_size", 6)
	_progress_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
	_progress_label.position = Vector2(FRAME_X + FRAME_W + 10, FRAME_Y + 16)
	add_child(_progress_label)

	# Instructions
	_instruction_label = Label.new()
	_instruction_label.text = "Click + drag to scrape | ESC to cancel"
	_instruction_label.add_theme_font_size_override("font_size", 5)
	_instruction_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_instruction_label.position = Vector2(FRAME_X, FRAME_Y + FRAME_H + 8)
	add_child(_instruction_label)

func _init_side(side: int) -> void:
	_current_side = side
	_cells.clear()
	_cells.resize(TOTAL_CELLS)
	for i in range(TOTAL_CELLS):
		_cells[i] = false  # false = capped
	_cells_uncapped = 0
	_side_complete = false
	_last_scrape_cell = Vector2i(-1, -1)

	# Reset cell colors
	for i in range(_cell_rects.size()):
		_cell_rects[i].color = Color(0.72, 0.58, 0.28, 1.0)

	if _side_label:
		_side_label.text = "Side A" if side == 0 else "Side B"
	_update_progress()

# =========================================================================
# INPUT
# =========================================================================
func _input(event: InputEvent) -> void:
	if _frame_complete:
		return

	# ESC to cancel
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		scraping_cancelled.emit()
		get_viewport().set_input_as_handled()
		return

	# Mouse button for scraping
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_scraping = event.pressed
			if _scraping:
				_scraper_pos = event.position
				_try_scrape_at(_scraper_pos)
			get_viewport().set_input_as_handled()
			return

	# Mouse motion while scraping
	if event is InputEventMouseMotion and _scraping:
		_scraper_pos = event.position
		_try_scrape_at(_scraper_pos)
		get_viewport().set_input_as_handled()
		return

# =========================================================================
# SCRAPING LOGIC
# =========================================================================
func _try_scrape_at(screen_pos: Vector2) -> void:
	# Convert screen position to cell coordinates
	var local_x: float = screen_pos.x - float(FRAME_X)
	var local_y: float = screen_pos.y - float(FRAME_Y)

	if local_x < 0 or local_y < 0:
		return
	if local_x >= float(FRAME_W) or local_y >= float(FRAME_H):
		return

	var col: int = int(local_x / float(CELL_SIZE))
	var row: int = int(local_y / float(CELL_SIZE))

	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return

	# Scrape a 3-cell-wide brush (the scraper covers some width)
	for dc in range(-1, 2):
		var c: int = col + dc
		if c < 0 or c >= GRID_COLS:
			continue
		_uncap_cell(row, c)

func _uncap_cell(row: int, col: int) -> void:
	var idx: int = row * GRID_COLS + col
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	if _cells[idx]:
		return  # Already uncapped

	# Determine probability
	var pct_done: float = float(_cells_uncapped) / float(TOTAL_CELLS)
	var chance: float = UNCAP_CHANCE_NORMAL if pct_done < LATE_THRESHOLD else UNCAP_CHANCE_LATE

	# Roll the dice
	if randf() <= chance:
		_cells[idx] = true
		_cells_uncapped += 1

		# Update visual
		if idx < _cell_rects.size():
			# Uncapped: lighter honey color
			_cell_rects[idx].color = Color(0.92, 0.82, 0.45, 1.0)

		_update_progress()
		_check_side_complete()

func _update_progress() -> void:
	if _progress_label:
		var pct: int = int(float(_cells_uncapped) / float(TOTAL_CELLS) * 100.0)
		_progress_label.text = "%d%%" % pct

func _check_side_complete() -> void:
	var pct_done: float = float(_cells_uncapped) / float(TOTAL_CELLS)
	# Side is complete when 95%+ cells are uncapped (allowing some stubborn ones)
	if pct_done >= 0.95:
		_side_complete = true
		if _current_side == 0:
			# Flip to side B
			_instruction_label.text = "Side A done! Flipping to Side B..."
			# Small delay before flipping
			var timer: SceneTreeTimer = get_tree().create_timer(0.8)
			timer.timeout.connect(_flip_to_side_b)
		else:
			# Frame complete!
			_frame_complete = true
			_instruction_label.text = "Frame complete! De-capping done."
			# Small delay before closing
			var timer: SceneTreeTimer = get_tree().create_timer(1.0)
			timer.timeout.connect(_finish)

func _flip_to_side_b() -> void:
	_init_side(1)
	_instruction_label.text = "Click + drag to scrape Side B | ESC to cancel"

func _finish() -> void:
	scraping_complete.emit()
