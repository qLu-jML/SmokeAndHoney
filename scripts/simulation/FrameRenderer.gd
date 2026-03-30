# FrameRenderer.gd
# -----------------------------------------------------------------------------
# Pipeline Step 10 -- On-Demand Frame Renderer
#
# Stamps 3,500 cell sprites from the cell atlas onto an ImageTexture.
# Call render_frame(frame) to get back an ImageTexture ready for a TextureRect.
#
# Cell atlas layout:
#   390 x 20 px -- 15 states in one horizontal row, 26 x 20 px each.
#   State N occupies atlas column (N * 26), row 0.
#
# Rendered frame size: 70 x 26  by  50 x 20  =  1820 x 1000 px
#
# Dirty-flag optimization: if the caller passes a frame whose cell array
# has not changed since last render (same PackedByteArray contents), the
# cached ImageTexture is returned immediately.
#
# LOD mode: at zoom < 50% a solid-colour flat view is drawn instead --
# one pixel per cell, colour-coded by state.  Call with lod=true.
#
# USAGE:
#   # Instantiate once per inspection overlay.
#   var renderer := FrameRenderer.new()
#   var tex      := renderer.render_frame(hive_frame)
#   $TextureRect.texture = tex
# -----------------------------------------------------------------------------
extends RefCounted
class_name FrameRenderer

# -- Cell / Atlas Geometry -----------------------------------------------------
const CELL_W    := 26          # atlas cell width  (px)
const CELL_H    := 20          # atlas cell height (px)
const FRAME_COLS := 70
const FRAME_ROWS := 50
const FRAME_PX_W := FRAME_COLS * CELL_W   # 1820
const FRAME_PX_H := FRAME_ROWS * CELL_H   # 1000
const STATE_COUNT := 15

# Path to the cell atlas PNG (relative to res://)
const ATLAS_PATH := "res://assets/sprites/generated/cells/cell_atlas.png"

# -- LOD Palette -- one colour per state ----------------------------------------
# Indexed by CellStateTransition state constants (0-14).
const LOD_PALETTE := [
	Color(0.07, 0.06, 0.05),   #  0 S_EMPTY_FOUNDATION  -- black plastic backing
	Color(0.82, 0.72, 0.44),   #  1 S_DRAWN_EMPTY        -- pale wax
	Color(0.98, 0.95, 0.78),   #  2 S_EGG                -- near-white
	Color(0.62, 0.88, 0.55),   #  3 S_OPEN_LARVA         -- light green
	Color(0.80, 0.65, 0.30),   #  4 S_CAPPED_BROOD       -- tan cap
	Color(0.60, 0.50, 0.28),   #  5 S_CAPPED_DRONE       -- darker tan
	Color(0.95, 0.85, 0.30),   #  6 S_NECTAR             -- bright yellow
	Color(0.90, 0.72, 0.20),   #  7 S_CURING_HONEY       -- amber-yellow
	Color(0.85, 0.55, 0.08),   #  8 S_CAPPED_HONEY       -- rich amber
	Color(0.72, 0.40, 0.04),   #  9 S_PREMIUM_HONEY      -- deep amber
	Color(0.70, 0.20, 0.20),   # 10 S_VARROA             -- dark red
	Color(0.30, 0.12, 0.08),   # 11 S_AFB                -- very dark brown
	Color(0.90, 0.75, 0.90),   # 12 S_QUEEN_CELL         -- lavender
	Color(0.40, 0.35, 0.30),   # 13 S_VACATED            -- grey-brown
	Color(0.82, 0.59, 0.22),   # 14 S_BEE_BREAD          -- warm amber-orange
]

# -- Honeycomb hex-grid layout ------------------------------------------------
# Pointy-top hex offset layout (matches real beehive cell orientation).
# Odd rows shift right by half a cell width.  Row spacing is compressed
# to 3/4 of cell height so rows overlap slightly, eliminating black gaps.
const HEX_COL_STEP  := CELL_W             # 26 px horizontal per column
const HEX_ROW_STEP  := 15                 # 3/4 of CELL_H (20) -- tight vertical packing
const HEX_ODD_SHIFT := CELL_W / 2         # 13 px right-shift for odd rows
const HONEY_PX_W    := FRAME_COLS * HEX_COL_STEP + HEX_ODD_SHIFT  # 1833
const HONEY_PX_H    := FRAME_ROWS * HEX_ROW_STEP + (CELL_H - HEX_ROW_STEP)  # 755

# -- Internal state -------------------------------------------------------------
var _atlas_image:   Image          = null   # source sprite sheet
var _frame_image:   Image          = null   # reused canvas (size depends on frame type)
var _frame_texture: ImageTexture   = null   # GPU texture
var _lod_image:     Image          = null   # LOD canvas (cols x rows)
var _lod_texture:   ImageTexture   = null
var _honey_image:   Image          = null   # honeycomb canvas
var _honey_texture: ImageTexture   = null
var _last_hash:     int            = -1     # PackedByteArray hash for dirty check
var _honey_hash:    int            = -1     # separate dirty flag for honeycomb
# Tracked frame dimensions -- forces canvas recreation when switching deep/super
var _cached_cols:   int            = 0
var _cached_rows:   int            = 0

# ------------------------------------------------------------------------------
# render_frame(frame) -> ImageTexture (1820 x 1000)
#
# Returns a fully rendered ImageTexture for the given HiveFrame.
# Cached: if frame.cells has not changed since last call, the same texture
# is returned without re-blitting.
# ------------------------------------------------------------------------------
func render_frame(frame, side: int = 0) -> ImageTexture:
	_ensure_atlas()
	var f_cols: int = frame.grid_cols if frame.has_method("get_cell") else FRAME_COLS
	var f_rows: int = frame.grid_rows if frame.has_method("get_cell") else FRAME_ROWS
	var f_size: int = frame.grid_size if frame.has_method("get_cell") else (f_cols * f_rows)
	_ensure_canvas_for(f_cols, f_rows)

	var side_cells = frame.cells if side == 0 else frame.cells_b

	var h: int = hash(side_cells)
	if h == _last_hash and _frame_texture != null:
		return _frame_texture
	_last_hash = h

	for i in f_size:
		var state: int = int(side_cells[i])
		state = clampi(state, 0, STATE_COUNT - 1)

		var col := i % f_cols
		@warning_ignore("INTEGER_DIVISION")
		var row := i / f_cols

		var src := Rect2i(state * CELL_W, 0, CELL_W, CELL_H)
		var dst := Vector2i(col * CELL_W, row * CELL_H)

		_frame_image.blit_rect(_atlas_image, src, dst)

	_frame_texture.update(_frame_image)
	return _frame_texture

# ------------------------------------------------------------------------------
# render_lod(frame) -> ImageTexture (70 x 50)
#
# Fast colour-coded overview: one pixel per cell.  Suitable for zoom < 50%.
# ------------------------------------------------------------------------------
func render_lod(frame, side: int = 0) -> ImageTexture:
	var f_cols: int = frame.grid_cols if frame.has_method("get_cell") else FRAME_COLS
	var f_rows: int = frame.grid_rows if frame.has_method("get_cell") else FRAME_ROWS
	var f_size: int = frame.grid_size if frame.has_method("get_cell") else (f_cols * f_rows)

	if _lod_image == null or _lod_image.get_width() != f_cols or _lod_image.get_height() != f_rows:
		_lod_image   = Image.create(f_cols, f_rows, false, Image.FORMAT_RGBA8)
		_lod_texture = ImageTexture.create_from_image(_lod_image)

	var side_cells = frame.cells if side == 0 else frame.cells_b

	for i in f_size:
		var state: int = clampi(int(side_cells[i]), 0, STATE_COUNT - 1)
		var col := i % f_cols
		@warning_ignore("INTEGER_DIVISION")
		var row := i / f_cols
		_lod_image.set_pixel(col, row, LOD_PALETTE[state])

	_lod_texture.update(_lod_image)
	return _lod_texture

# ------------------------------------------------------------------------------
# render_honeycomb(frame) -> ImageTexture (1833 x 755)
#
# Realistic honeycomb render: blits cell atlas sprites in a pointy-top hex
# offset grid.  Odd rows shift right by half a cell width, and rows overlap
# vertically (15 px step vs 20 px cell height), producing a tight hexagonal
# pattern with no visible black gaps between cells.
#
# This is heavier than LOD but produces a realistic Langstroth frame view
# when scaled down in the InspectionOverlay's TextureRect.
# ------------------------------------------------------------------------------
func render_honeycomb(frame, side: int = 0) -> ImageTexture:
	_ensure_atlas()

	var side_cells = frame.cells if side == 0 else frame.cells_b

	var f_cols: int = frame.grid_cols if frame.has_method("get_cell") else FRAME_COLS
	var f_rows: int = frame.grid_rows if frame.has_method("get_cell") else FRAME_ROWS
	var f_size: int = frame.grid_size if frame.has_method("get_cell") else (f_cols * f_rows)

	# Compute canvas size dynamically based on actual frame dimensions
	var honey_w: int = f_cols * HEX_COL_STEP + HEX_ODD_SHIFT
	var honey_h: int = f_rows * HEX_ROW_STEP + (CELL_H - HEX_ROW_STEP)

	# Dirty check
	var h: int = hash(side_cells)
	if h == _honey_hash and _honey_texture != null and _honey_image != null and _honey_image.get_width() == honey_w and _honey_image.get_height() == honey_h:
		return _honey_texture

	_honey_hash = h

	# Recreate canvas when dimensions change or on first use
	if _honey_image == null or _honey_image.get_width() != honey_w or _honey_image.get_height() != honey_h:
		_honey_image  = Image.create(honey_w, honey_h, false, Image.FORMAT_RGBA8)
		_honey_texture = ImageTexture.create_from_image(_honey_image)

	# Fill background with dark tone -- hex cell sprites render on top
	_honey_image.fill(Color(0.05, 0.04, 0.03, 1.0))

	# Blend each cell from the atlas in hex-offset positions.
	# blend_rect composites source OVER destination respecting alpha,
	# so the transparent hex-cell corners don't erase overlapping neighbours.
	for i in f_size:
		var state: int = clampi(int(side_cells[i]), 0, STATE_COUNT - 1)

		var col := i % f_cols
		@warning_ignore("INTEGER_DIVISION")
		var row := i / f_cols

		# Hex offset: odd rows shift right by half a cell width
		var x_offset: int = HEX_ODD_SHIFT if (row % 2 == 1) else 0
		var dst := Vector2i(col * HEX_COL_STEP + x_offset, row * HEX_ROW_STEP)
		var src := Rect2i(state * CELL_W, 0, CELL_W, CELL_H)

		_honey_image.blend_rect(_atlas_image, src, dst)

	_honey_texture.update(_honey_image)
	return _honey_texture

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

## Return the honeycomb canvas pixel width for a given column count.
static func honeycomb_px_w(cols: int = FRAME_COLS) -> int:
	return cols * HEX_COL_STEP + HEX_ODD_SHIFT

## Return the honeycomb canvas pixel height for a given row count.
static func honeycomb_px_h(rows: int = FRAME_ROWS) -> int:
	return rows * HEX_ROW_STEP + (CELL_H - HEX_ROW_STEP)

## Load the atlas PNG on first use.
## Uses Image.load_from_file() with the absolute project path so we read
## the actual PNG on disk, bypassing Godot's import cache.  This guarantees
## any external edits to the atlas (e.g. foundation colour changes) are
## picked up immediately without needing a reimport.
func _ensure_atlas() -> void:
	if _atlas_image != null:
		return
	# Build absolute path: ProjectSettings.globalize_path converts res:// to OS path.
	var abs_path: String = ProjectSettings.globalize_path(ATLAS_PATH)
	_atlas_image = Image.new()
	var err := _atlas_image.load(abs_path)
	if err != OK:
		push_error("FrameRenderer: could not load atlas at %s (error %d)" % [abs_path, err])
		# Fallback so the game doesn't crash -- magenta = broken atlas.
		_atlas_image = Image.create(STATE_COUNT * CELL_W, CELL_H, false, Image.FORMAT_RGBA8)
		_atlas_image.fill(Color.MAGENTA)
		return
	# Ensure the image is in a format blit_rect can work with.
	if _atlas_image.get_format() != Image.FORMAT_RGBA8:
		_atlas_image.convert(Image.FORMAT_RGBA8)

## Create (or reset) the 1820x1000 canvas and its GPU texture.
func _ensure_canvas() -> void:
	_ensure_canvas_for(FRAME_COLS, FRAME_ROWS)

func _ensure_canvas_for(cols: int, rows: int) -> void:
	if _frame_image != null and _cached_cols == cols and _cached_rows == rows:
		return
	_cached_cols = cols
	_cached_rows = rows
	var pw := cols * CELL_W
	var ph := rows * CELL_H
	_frame_image   = Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	_frame_texture = ImageTexture.create_from_image(_frame_image)
	_last_hash = -1   # force re-render after resize
