# scraping_minigame.gd -- Interactive honeycomb de-capping minigame overlay.
# Player clicks and drags a scraper/uncapping knife across the comb to uncap cells.
# Cells are drawn as pointy-top hexagons matching the inspection overlay look.
# The mouse cursor is replaced with a pixel-art uncapping fork during the minigame.
# -------------------------------------------------------------------------
extends CanvasLayer

signal scraping_complete
signal scraping_cancelled

# -- Grid layout ----------------------------------------------------------
const GRID_COLS := 24
const GRID_ROWS := 14
const TOTAL_CELLS: int = GRID_COLS * GRID_ROWS  # 336 per side

# -- Probabilities --------------------------------------------------------
const UNCAP_CHANCE_NORMAL := 0.95
const UNCAP_CHANCE_LATE := 0.80
const LATE_THRESHOLD := 0.90   # Switch to late chance after 90% uncapped

# -- Brush width ----------------------------------------------------------
# 7 cells wide = ~49px native = a wide uncapping sweep
const BRUSH_HALF := 3    # cells to each side of cursor column

# -- Hex hit detection constants (must match scraping_hex_grid.gd) ---------
const HEX_COL_STEP   := 7.0
const HEX_ROW_STEP   := 6.0
const HEX_MARGIN_X   := 12.0
const HEX_MARGIN_Y   := 8.0
const HEX_ODD_COL_OFFS := 3.0

# -- Frame layout ---------------------------------------------------------
const FRAME_X := 28
const FRAME_Y := 22
const FRAME_W : int = GRID_COLS * 8   # 192 px wide frame interior
const FRAME_H : int = GRID_ROWS * 8   # 112 px tall frame interior
const BORDER_T := 6   # Wood border thickness (px)

# -- Frame state ----------------------------------------------------------
var _current_side: int = 0     # 0 = Side A, 1 = Side B
var _cells: Array = []         # Array of bool (true = uncapped)
var _cells_uncapped: int = 0
var _side_complete: bool = false
var _frame_complete: bool = false

# -- Scraper state --------------------------------------------------------
var _scraping: bool = false    # Mouse button held
var _scraper_pos: Vector2 = Vector2.ZERO

# -- Visual elements ------------------------------------------------------
# Wood frame border elements
var _bg: ColorRect = null
var _side_label: Label = null
var _progress_label: Label = null
var _instruction_label: Label = null

# Hex grid drawing node (Node2D child with _draw() for honeycomb cells)
const HexGridScript = preload("res://scripts/ui/scraping_hex_grid.gd")
var _hex_grid: Node2D = null

# -- Colors (wood frame, info panel) ------------------------------------
const C_WOOD_RAIL  : Color = Color(0.32, 0.20, 0.07, 1.0)
const C_WOOD_STILE : Color = Color(0.44, 0.28, 0.10, 1.0)
const C_COMB_BG    : Color = Color(0.22, 0.12, 0.04, 1.0)

# -- Cursor ---------------------------------------------------------------
const CURSOR_PATH := "res://assets/sprites/ui/cursors/uncapping_fork_cursor.png"
# Hotspot: tip of the tines at bottom-center of the 32x64 sprite
const CURSOR_HOTSPOT : Vector2 = Vector2(16, 60)
var _cursor_tex: Texture2D = null

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	_build_ui()
	_init_side(0)
	_apply_cursor()

func _apply_cursor() -> void:
	if ResourceLoader.exists(CURSOR_PATH):
		_cursor_tex = load(CURSOR_PATH) as Texture2D
		if _cursor_tex:
			Input.set_custom_mouse_cursor(_cursor_tex, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _restore_cursor() -> void:
	Input.set_custom_mouse_cursor(null)

func _build_ui() -> void:
	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Title
	var title_lbl: Label = Label.new()
	title_lbl.text = "Honey Frame  --  De-capping"
	title_lbl.add_theme_font_size_override("font_size", 7)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	title_lbl.position = Vector2(FRAME_X - BORDER_T, 5)
	add_child(title_lbl)

	# ---- Wood frame borders ----
	var top_rail: ColorRect = ColorRect.new()
	top_rail.color = C_WOOD_RAIL
	top_rail.position = Vector2(FRAME_X - BORDER_T, FRAME_Y - BORDER_T)
	top_rail.size = Vector2(FRAME_W + BORDER_T * 2, BORDER_T)
	add_child(top_rail)

	var bot_rail: ColorRect = ColorRect.new()
	bot_rail.color = C_WOOD_RAIL
	bot_rail.position = Vector2(FRAME_X - BORDER_T, FRAME_Y + FRAME_H)
	bot_rail.size = Vector2(FRAME_W + BORDER_T * 2, BORDER_T)
	add_child(bot_rail)

	var left_stile: ColorRect = ColorRect.new()
	left_stile.color = C_WOOD_STILE
	left_stile.position = Vector2(FRAME_X - BORDER_T, FRAME_Y)
	left_stile.size = Vector2(BORDER_T, FRAME_H)
	add_child(left_stile)

	var right_stile: ColorRect = ColorRect.new()
	right_stile.color = C_WOOD_STILE
	right_stile.position = Vector2(FRAME_X + FRAME_W, FRAME_Y)
	right_stile.size = Vector2(BORDER_T, FRAME_H)
	add_child(right_stile)

	# Corner caps
	var corner_offsets: Array = [
		Vector2(FRAME_X - BORDER_T, FRAME_Y - BORDER_T),
		Vector2(FRAME_X + FRAME_W, FRAME_Y - BORDER_T),
		Vector2(FRAME_X - BORDER_T, FRAME_Y + FRAME_H),
		Vector2(FRAME_X + FRAME_W, FRAME_Y + FRAME_H),
	]
	for cpos in corner_offsets:
		var corner: ColorRect = ColorRect.new()
		corner.color = C_WOOD_RAIL
		corner.position = cpos
		corner.size = Vector2(BORDER_T, BORDER_T)
		add_child(corner)

	# Middle top-bar (horizontal Langstroth divider)
	var mid_bar: ColorRect = ColorRect.new()
	mid_bar.color = C_WOOD_STILE
	mid_bar.position = Vector2(FRAME_X, FRAME_Y + (FRAME_H / 2) - 1)
	mid_bar.size = Vector2(FRAME_W, 2)
	add_child(mid_bar)

	# ---- Hex grid node (draws the actual honeycomb cells) ----
	_hex_grid = HexGridScript.new()
	_hex_grid.position = Vector2(FRAME_X, FRAME_Y)
	add_child(_hex_grid)

	# ---- Right-side info panel ----
	var info_x: int = FRAME_X + FRAME_W + BORDER_T + 6

	_side_label = Label.new()
	_side_label.text = "Side A"
	_side_label.add_theme_font_size_override("font_size", 7)
	_side_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_side_label.position = Vector2(info_x, FRAME_Y)
	add_child(_side_label)

	_progress_label = Label.new()
	_progress_label.text = "0%"
	_progress_label.add_theme_font_size_override("font_size", 6)
	_progress_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
	_progress_label.position = Vector2(info_x, FRAME_Y + 16)
	add_child(_progress_label)

	# Color legend
	var legend_capped: ColorRect = ColorRect.new()
	legend_capped.color = Color(0.80, 0.66, 0.30, 1.0)
	legend_capped.position = Vector2(info_x, FRAME_Y + 38)
	legend_capped.size = Vector2(7, 7)
	add_child(legend_capped)

	var lbl_capped: Label = Label.new()
	lbl_capped.text = "Capped"
	lbl_capped.add_theme_font_size_override("font_size", 4)
	lbl_capped.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40))
	lbl_capped.position = Vector2(info_x + 9, FRAME_Y + 35)
	add_child(lbl_capped)

	var legend_open: ColorRect = ColorRect.new()
	legend_open.color = Color(0.97, 0.83, 0.30, 1.0)
	legend_open.position = Vector2(info_x, FRAME_Y + 50)
	legend_open.size = Vector2(7, 7)
	add_child(legend_open)

	var lbl_open: Label = Label.new()
	lbl_open.text = "Open"
	lbl_open.add_theme_font_size_override("font_size", 4)
	lbl_open.add_theme_color_override("font_color", Color(0.70, 0.60, 0.40))
	lbl_open.position = Vector2(info_x + 9, FRAME_Y + 47)
	add_child(lbl_open)

	# Instructions (below frame)
	_instruction_label = Label.new()
	_instruction_label.text = "Click + drag to scrape | ESC to cancel"
	_instruction_label.add_theme_font_size_override("font_size", 5)
	_instruction_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_instruction_label.position = Vector2(FRAME_X - BORDER_T, FRAME_Y + FRAME_H + BORDER_T + 4)
	add_child(_instruction_label)

func _init_side(side: int) -> void:
	_current_side = side
	_cells.clear()
	_cells.resize(TOTAL_CELLS)
	for i in range(TOTAL_CELLS):
		_cells[i] = false
	_cells_uncapped = 0
	_side_complete = false

	# Push state to hex grid and redraw
	if _hex_grid:
		_hex_grid.cells = _cells
		_hex_grid.queue_redraw()

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
		_restore_cursor()
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
	# Convert screen pos to frame-interior coords, accounting for hex margins
	var local_x: float = screen_pos.x - float(FRAME_X) - HEX_MARGIN_X
	var local_y: float = screen_pos.y - float(FRAME_Y) - HEX_MARGIN_Y

	if local_x < 0.0 or local_y < 0.0:
		return
	if local_x >= float(FRAME_W) or local_y >= float(FRAME_H):
		return

	# Determine column from x
	var col: int = int(local_x / HEX_COL_STEP)
	if col < 0 or col >= GRID_COLS:
		return

	# Adjust y for odd-column stagger, then determine row
	var adj_y: float = local_y
	if col % 2 == 1:
		adj_y -= HEX_ODD_COL_OFFS
	if adj_y < 0.0:
		return

	var row: int = int(adj_y / HEX_ROW_STEP)
	if row < 0 or row >= GRID_ROWS:
		return

	# Wide brush: BRUSH_HALF cells to each side
	for dc in range(-BRUSH_HALF, BRUSH_HALF + 1):
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

	# Determine uncap probability
	var pct_done: float = float(_cells_uncapped) / float(TOTAL_CELLS)
	var chance: float = UNCAP_CHANCE_NORMAL if pct_done < LATE_THRESHOLD else UNCAP_CHANCE_LATE

	if randf() <= chance:
		_cells[idx] = true
		_cells_uncapped += 1

		# Notify hex grid to redraw
		if _hex_grid:
			_hex_grid.cells = _cells
			_hex_grid.queue_redraw()

		_update_progress()
		_check_side_complete()

func _update_progress() -> void:
	if _progress_label:
		var pct: int = int(float(_cells_uncapped) / float(TOTAL_CELLS) * 100.0)
		_progress_label.text = "%d%%" % pct

func _check_side_complete() -> void:
	var pct_done: float = float(_cells_uncapped) / float(TOTAL_CELLS)
	if pct_done >= 0.95:
		_side_complete = true
		_frame_complete = true
		if _instruction_label:
			_instruction_label.text = "Frame de-capped!"
		var timer: SceneTreeTimer = get_tree().create_timer(0.8)
		timer.timeout.connect(_finish)

func _flip_to_side_b() -> void:
	_init_side(1)
	if _instruction_label:
		_instruction_label.text = "Click + drag to scrape Side B | ESC to cancel"

func _finish() -> void:
	_restore_cursor()
	scraping_complete.emit()
