# scraping_minigame.gd -- Honey-frame de-capping overlay.
#
# Visual layout is an EXACT replica of the hive InspectionOverlay (same
# viewport constants, same Langstroth frame bars, same wood colours, same
# FrameRenderer honeycomb texture).  The only difference is purpose: the
# player drag-scrapes to uncap cells (S_CAPPED_HONEY -> S_CURING_HONEY)
# rather than just inspecting them.
#
# Setup before add_child():
#   overlay.frame       = ScrapeFrame instance (or any FrameRenderer-compatible)
#   overlay.frame_index = 1-based frame number (shown in header)
#   overlay.frame_total = total frames in batch (shown in header)
#
# Signals:
#   scraping_complete  -- frame done (95%+ of side A uncapped)
#   scraping_cancelled -- player pressed ESC
#
# After scraping_complete, read result_cells_scraped for wax calculation.
# -----------------------------------------------------------------------------
extends CanvasLayer

signal scraping_complete
signal scraping_cancelled

# -- FrameRenderer (same class used by InspectionOverlay) --------------------
var _renderer: FrameRenderer = null

# -- Frame reference ----------------------------------------------------------
# Set BEFORE add_child so _ready() sees it.
var frame: Object = null       # ScrapeFrame or any FrameRenderer-compatible object
var frame_index: int = 1
var frame_total: int = 10
var result_cells_scraped: int = 0  # total cells uncapped (A+B combined)

# -- Layout constants (exact mirror of InspectionOverlay) ---------------------
const VP_W        := 320
const VP_H        := 180
const HEADER_H    := 18
const FOOTER_H    := 12
const STATS_W     := 40
const GRID_W      := VP_W - STATS_W        # 280
const GRID_H      := VP_H - HEADER_H - FOOTER_H  # 150
const FRAME_BAR_T := 8
const FRAME_BAR_B := 5
const FRAME_BAR_L := 4
const FRAME_BAR_R := 4
const CELL_AREA_W := GRID_W - FRAME_BAR_L - FRAME_BAR_R  # 272
const CELL_AREA_H := GRID_H - FRAME_BAR_T - FRAME_BAR_B  # 137

# Super frame: 70 cols x 35 rows.
# Effective height mirrors InspectionOverlay: int(137 * 35 / 50) = 95 px
const F_COLS     := 70
const F_ROWS     := 35
const EFF_CELL_H := 95  # int(CELL_AREA_H * F_ROWS / 50)

# FrameRenderer honeycomb canvas size for a 70x35 frame:
#   HEX_COL_STEP=26, HEX_ODD_SHIFT=13, HEX_ROW_STEP=15, CELL_H=20
const HONEY_W := 1833   # 70 * 26 + 13
const HONEY_H := 530    # 35 * 15 + (20 - 15)

# FrameRenderer geometry constants (duplicated for hit-detection; must stay in sync)
const HEX_COL_STEP  := 26
const HEX_ROW_STEP  := 15
const HEX_ODD_SHIFT := 13

# -- Colour palette (exact match with InspectionOverlay) ---------------------
const C_BG         := Color(0.06, 0.05, 0.04, 0.96)
const C_HEADER_BG  := Color(0.12, 0.10, 0.07, 1.0)
const C_STATS_BG   := Color(0.09, 0.07, 0.05, 1.0)
const C_BORDER     := Color(0.70, 0.55, 0.22, 1.0)
const C_WOOD       := Color(0.52, 0.36, 0.16, 1.0)
const C_WOOD_HI    := Color(0.68, 0.50, 0.26, 1.0)
const C_WOOD_SH    := Color(0.36, 0.24, 0.10, 1.0)
const C_WOOD_LUG   := Color(0.42, 0.28, 0.12, 1.0)
const C_FOUNDATION := Color(0.18, 0.14, 0.08, 1.0)
const C_WIRE       := Color(0.55, 0.48, 0.30, 0.35)
const C_TEXT       := Color(0.90, 0.85, 0.70, 1.0)
const C_MUTED      := Color(0.55, 0.50, 0.42, 1.0)
const C_ACCENT     := Color(0.95, 0.78, 0.32, 1.0)
# Scraper knife highlight -- warm honey gold, semi-transparent
const C_BRUSH      := Color(0.95, 0.85, 0.30, 0.22)
const C_BRUSH_EDGE := Color(0.95, 0.78, 0.32, 0.55)
const C_HANDLE     := Color(0.45, 0.30, 0.12, 0.92)   # dark wood handle below blade
const C_HANDLE_HI  := Color(0.62, 0.44, 0.20, 0.85)   # handle highlight edge
const HANDLE_W     := 8    # handle width in px
const HANDLE_H     := 20   # handle height below cell area in px

# -- Scraping state -----------------------------------------------------------
var _current_side: int = 0     # 0 = Side A, 1 = Side B
var _scraping: bool = false
var _done: bool = false
var _total_cappable: int = 1   # init to 1 to avoid div/0
var _scraped_this_side: int = 0

# -- Brush width (columns left/right of hit column) --------------------------
const BRUSH_HALF := 3

# -- UI nodes -----------------------------------------------------------------
var _bg:           Control  = null   # root control parent (matches InspectionOverlay bg)
var _cell_rect:    TextureRect = null
var _brush_rect:   ColorRect  = null  # scraper knife blade (over cell area)
var _brush_edge_l: ColorRect  = null  # left blade edge highlight
var _brush_edge_r: ColorRect  = null  # right blade edge highlight
var _brush_handle: ColorRect  = null  # handle stub below frame bottom bar
var _brush_hnd_hi: ColorRect  = null  # handle left highlight stripe
var _header_lbl:   Label      = null
var _side_lbl:     Label      = null
var _progress_lbl: Label      = null
var _status_lbl:   Label      = null

# -- Cursor -------------------------------------------------------------------
const CURSOR_PATH    := "res://assets/sprites/ui/cursors/uncapping_fork_cursor.png"
const CURSOR_HOTSPOT := Vector2(16, 60)

# =========================================================================
# LIFECYCLE
# =========================================================================
func _ready() -> void:
	layer = 20
	_renderer = FrameRenderer.new()
	_build_ui()
	# Safety: if no frame was injected, or the frame has no honey cells,
	# create/fill one so the minigame always shows the correct honeycomb.
	if frame == null:
		var sf: ScrapeFrame = ScrapeFrame.new()
		sf.fill_for_harvest(85.0)
		frame = sf
	elif frame.has_method("count_capped"):
		var capped: int = int(frame.call("count_capped", 0))
		if capped == 0 and frame.has_method("fill_for_harvest"):
			frame.call("fill_for_harvest", 85.0)
	_count_cappable()
	# Render directly -- same approach as InspectionOverlay._refresh_frame()
	# which assigns texture synchronously without any deferred call.
	_render()

func _apply_cursor() -> void:
	if ResourceLoader.exists(CURSOR_PATH):
		var tex: Texture2D = load(CURSOR_PATH) as Texture2D
		if tex:
			Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, CURSOR_HOTSPOT)

func _restore_cursor() -> void:
	Input.set_custom_mouse_cursor(null)

# =========================================================================
# UI BUILD -- exact InspectionOverlay layout
# =========================================================================
func _build_ui() -> void:
	# -- Root background (Control parent -- all children go here, matching
	#    InspectionOverlay's bg-child architecture so TextureRect renders) --
	_bg = ColorRect.new()
	(_bg as ColorRect).color = C_BG
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# -- Header bar --
	var hdr_bg := ColorRect.new()
	hdr_bg.color    = C_HEADER_BG
	hdr_bg.size     = Vector2(VP_W, HEADER_H)
	hdr_bg.position = Vector2.ZERO
	_bg.add_child(hdr_bg)

	# Left label: mode
	var hdr_left := Label.new()
	hdr_left.text = "De-capping"
	hdr_left.add_theme_font_size_override("font_size", 6)
	hdr_left.add_theme_color_override("font_color", C_ACCENT)
	hdr_left.position = Vector2(4, 4)
	_bg.add_child(hdr_left)

	# Right label: "Frame N / total  Side A"
	_header_lbl = Label.new()
	_header_lbl.text = _header_text()
	_header_lbl.add_theme_font_size_override("font_size", 6)
	_header_lbl.add_theme_color_override("font_color", C_TEXT)
	_header_lbl.position = Vector2(130, 4)
	_header_lbl.size = Vector2(170, 12)
	_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bg.add_child(_header_lbl)

	# Header divider (same as InspectionOverlay h_div)
	var h_div := ColorRect.new()
	h_div.color    = C_BORDER
	h_div.size     = Vector2(VP_W, 1)
	h_div.position = Vector2(0, HEADER_H - 1)
	_bg.add_child(h_div)

	# -- Stats panel (right 40 px, same as InspectionOverlay) --
	var stats_bg := ColorRect.new()
	stats_bg.color    = C_STATS_BG
	stats_bg.size     = Vector2(STATS_W, GRID_H)
	stats_bg.position = Vector2(GRID_W, HEADER_H)
	_bg.add_child(stats_bg)

	var stats_div := ColorRect.new()
	stats_div.color    = C_BORDER
	stats_div.size     = Vector2(1, GRID_H)
	stats_div.position = Vector2(GRID_W, HEADER_H)
	_bg.add_child(stats_div)

	# Stats content
	var sy: int = HEADER_H + 3
	_side_lbl = _stat_lbl("Side A", sy)
	sy += 9
	_progress_lbl = _stat_lbl("0%", sy)
	sy += 9
	_stat_lbl("Drag to", sy, C_MUTED)
	sy += 7
	_stat_lbl("uncap", sy, C_MUTED)
	sy += 9
	_stat_lbl("[F] flip", sy, C_MUTED)

	# -- Frame bars (same dimensions/colours as InspectionOverlay) --
	var y_off: int = HEADER_H
	var cell_x: int = FRAME_BAR_L
	var cell_y: int = y_off + FRAME_BAR_T

	# Top bar
	_crect(C_WOOD,    0, y_off, GRID_W, FRAME_BAR_T)
	_crect(C_WOOD_HI, 0, y_off, GRID_W, 1)           # highlight top edge
	_crect(C_WOOD_SH, 0, cell_y - 1, GRID_W, 1)      # shadow bottom edge

	# Lug knobs (same positions as InspectionOverlay)
	for lug_x in [0, GRID_W - 14]:
		_crect(C_WOOD_LUG, lug_x, y_off, 14, FRAME_BAR_T)
		_crect(C_WOOD_HI,  lug_x, y_off, 14, 1)

	# Bottom bar
	var bot_y: int = cell_y + EFF_CELL_H
	_crect(C_WOOD,    0, bot_y, GRID_W, FRAME_BAR_B)
	_crect(C_WOOD_HI, 0, bot_y, GRID_W, 1)

	# Left side bar
	_crect(C_WOOD,         0,            cell_y, FRAME_BAR_L, EFF_CELL_H)
	_crect(C_WOOD_HI, FRAME_BAR_L - 1, cell_y, 1, EFF_CELL_H)

	# Right side bar
	_crect(C_WOOD,    GRID_W - FRAME_BAR_R, cell_y, FRAME_BAR_R, EFF_CELL_H)
	_crect(C_WOOD_SH, GRID_W - FRAME_BAR_R, cell_y, 1, EFF_CELL_H)

	# Foundation fill (shows through before renderer has run)
	_crect(C_FOUNDATION, cell_x, cell_y, CELL_AREA_W, EFF_CELL_H)

	# Wire support guides (decorative horizontal lines, same as InspectionOverlay)
	for wi in range(3):
		var wy: int = cell_y + int((wi + 1) * EFF_CELL_H / 4)
		_crect(C_WIRE, cell_x, wy, CELL_AREA_W, 1)

	# -- Cell TextureRect (child of _bg -- MUST be a Control grandchild of the
	#    CanvasLayer, not a direct child, so TextureRect texture renders) --
	_cell_rect = TextureRect.new()
	_cell_rect.position       = Vector2(cell_x, cell_y)
	_cell_rect.size           = Vector2(CELL_AREA_W, EFF_CELL_H)
	_cell_rect.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	_cell_rect.stretch_mode   = TextureRect.STRETCH_SCALE
	_cell_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cell_rect.mouse_filter   = Control.MOUSE_FILTER_PASS
	_bg.add_child(_cell_rect)

	# -- Scraper knife brush overlay --
	# Width = (BRUSH_HALF*2+1) columns scaled to display pixels.
	# Height = full frame height. Shown while mouse is over the cell area.
	var brush_col_w: float = float(CELL_AREA_W) / float(F_COLS)
	var brush_px_w: float  = float(BRUSH_HALF * 2 + 1) * brush_col_w

	_brush_rect = ColorRect.new()
	_brush_rect.color    = C_BRUSH
	_brush_rect.size     = Vector2(brush_px_w, EFF_CELL_H)
	_brush_rect.position = Vector2(cell_x, cell_y)
	_brush_rect.visible  = false
	_brush_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_brush_rect)

	# Narrow left/right edge lines to suggest the knife blade edge
	_brush_edge_l = ColorRect.new()
	_brush_edge_l.color    = C_BRUSH_EDGE
	_brush_edge_l.size     = Vector2(1, EFF_CELL_H)
	_brush_edge_l.position = Vector2(cell_x, cell_y)
	_brush_edge_l.visible  = false
	_brush_edge_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_brush_edge_l)

	_brush_edge_r = ColorRect.new()
	_brush_edge_r.color    = C_BRUSH_EDGE
	_brush_edge_r.size     = Vector2(1, EFF_CELL_H)
	_brush_edge_r.position = Vector2(cell_x + brush_px_w - 1, cell_y)
	_brush_edge_r.visible  = false
	_brush_edge_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_brush_edge_r)

	# -- Scraper handle (below the frame bottom bar, centered on blade) --
	# Appears below the cell area to suggest a physical uncapping knife held
	# from below. Width = HANDLE_W, height = HANDLE_H, dark wood colour.
	var hand_y: float = float(cell_y + EFF_CELL_H)
	var hand_x: float = float(cell_x) + float(CELL_AREA_W) / 2.0 - float(HANDLE_W) / 2.0
	_brush_handle = ColorRect.new()
	_brush_handle.color    = C_HANDLE
	_brush_handle.size     = Vector2(HANDLE_W, HANDLE_H)
	_brush_handle.position = Vector2(hand_x, hand_y)
	_brush_handle.visible  = false
	_brush_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_brush_handle)

	# Handle left highlight stripe (1 px, lighter wood)
	_brush_hnd_hi = ColorRect.new()
	_brush_hnd_hi.color    = C_HANDLE_HI
	_brush_hnd_hi.size     = Vector2(1, HANDLE_H)
	_brush_hnd_hi.position = Vector2(hand_x, hand_y)
	_brush_hnd_hi.visible  = false
	_brush_hnd_hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_brush_hnd_hi)

	# -- Footer --
	_crect(C_BORDER,    0, VP_H - FOOTER_H, VP_W, 1)
	_crect(C_HEADER_BG, 0, VP_H - FOOTER_H, VP_W, FOOTER_H)

	_status_lbl = Label.new()
	_status_lbl.text = "[Drag] Scrape  [F] Flip  [ESC] Cancel"
	_status_lbl.add_theme_font_size_override("font_size", 5)
	_status_lbl.add_theme_color_override("font_color", C_MUTED)
	_status_lbl.position = Vector2(2, VP_H - FOOTER_H + 2)
	_status_lbl.size     = Vector2(VP_W - 4, 8)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg.add_child(_status_lbl)

	_apply_cursor()

# -- Helpers -----------------------------------------------------------------
func _crect(col: Color, x: int, y: int, w: int, h: int) -> ColorRect:
	var r := ColorRect.new()
	r.color    = col
	r.position = Vector2(x, y)
	r.size     = Vector2(w, h)
	_bg.add_child(r)
	return r

func _stat_lbl(text: String, y: int, col: Color = C_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 4)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = Vector2(GRID_W + 2, y)
	lbl.size     = Vector2(STATS_W - 4, 8)
	_bg.add_child(lbl)
	return lbl

func _header_text() -> String:
	var side_str: String = "Side A" if _current_side == 0 else "Side B"
	return "Frame %d / %d  %s" % [frame_index, frame_total, side_str]

# =========================================================================
# BRUSH VISUAL -- update position/visibility based on mouse position
# =========================================================================
func _update_brush(screen_pos: Vector2, col: int) -> void:
	if _done or _brush_rect == null:
		return
	var cell_x: float   = float(FRAME_BAR_L)
	var cell_y: float   = float(HEADER_H + FRAME_BAR_T)
	var tr_x: float     = cell_x
	var tr_y: float     = cell_y
	var tr_w: float     = float(CELL_AREA_W)
	var tr_h: float     = float(EFF_CELL_H)

	var lx: float = screen_pos.x - tr_x
	var ly: float = screen_pos.y - tr_y
	var inside: bool = lx >= 0.0 and lx < tr_w and ly >= 0.0 and ly < tr_h

	_brush_rect.visible   = inside
	_brush_edge_l.visible = inside
	_brush_edge_r.visible = inside

	if not inside:
		return

	var brush_col_w: float = tr_w / float(F_COLS)
	var brush_px_w: float  = float(BRUSH_HALF * 2 + 1) * brush_col_w

	# Clamp so brush never extends past the frame edges
	var left_col: int   = maxi(0, col - BRUSH_HALF)
	var right_col: int  = mini(F_COLS - 1, col + BRUSH_HALF)
	var bx: float       = cell_x + float(left_col) * brush_col_w
	var bw: float       = float(right_col - left_col + 1) * brush_col_w

	_brush_rect.position   = Vector2(bx, cell_y)
	_brush_rect.size       = Vector2(bw, float(EFF_CELL_H))
	_brush_edge_l.position = Vector2(bx, cell_y)
	_brush_edge_r.position = Vector2(bx + bw - 1.0, cell_y)

	# Handle: centered below blade
	var blade_cx: float = bx + bw / 2.0
	var hand_y: float   = cell_y + float(EFF_CELL_H)
	var hand_x: float   = blade_cx - float(HANDLE_W) / 2.0
	if _brush_handle:
		_brush_handle.position = Vector2(hand_x, hand_y)
		_brush_handle.visible  = inside
	if _brush_hnd_hi:
		_brush_hnd_hi.position = Vector2(hand_x, hand_y)
		_brush_hnd_hi.visible  = inside

func _hide_brush() -> void:
	if _brush_rect:
		_brush_rect.visible   = false
	if _brush_edge_l:
		_brush_edge_l.visible = false
	if _brush_edge_r:
		_brush_edge_r.visible = false
	if _brush_handle:
		_brush_handle.visible = false
	if _brush_hnd_hi:
		_brush_hnd_hi.visible = false

# =========================================================================
# FRAME RENDERING (FrameRenderer, same pipeline as InspectionOverlay)
# =========================================================================
func _render() -> void:
	if _cell_rect == null or _renderer == null or frame == null:
		return
	_cell_rect.texture = _renderer.render_honeycomb(frame, _current_side)

func _count_cappable() -> void:
	if frame == null:
		_total_cappable = 1
		return
	var arr: PackedByteArray = frame.cells if _current_side == 0 else frame.cells_b
	var n: int = 0
	for i in frame.grid_size:
		var s: int = int(arr[i])
		if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
			n += 1
	_total_cappable = maxi(n, 1)

func _update_progress() -> void:
	var pct: int = mini(int(float(_scraped_this_side) / float(_total_cappable) * 100.0), 100)
	if _progress_lbl:
		_progress_lbl.text = "%d%%" % pct
	if pct >= 95 and not _done:
		_finish_side()

# =========================================================================
# INPUT
# =========================================================================
func _input(event: InputEvent) -> void:
	if _done:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_hide_brush()
				_restore_cursor()
				scraping_cancelled.emit()
				get_viewport().set_input_as_handled()
				return
			KEY_F:
				_flip_side()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_scraping = event.pressed
		if _scraping:
			_try_scrape(event.position)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_try_scrape(event.position)
		if not _scraping:
			# Still update brush on hover even without left-click held
			_update_brush_from_pos(event.position)
		get_viewport().set_input_as_handled()

# =========================================================================
# SCRAPING LOGIC
# Maps screen-space mouse position to FrameRenderer cell indices.
# Same arithmetic as InspectionOverlay tooltip hit-detection.
# =========================================================================
func _update_brush_from_pos(screen_pos: Vector2) -> void:
	var tr_x: float = float(FRAME_BAR_L)
	var tr_y: float = float(HEADER_H + FRAME_BAR_T)
	var tr_w: float = float(CELL_AREA_W)
	var tr_h: float = float(EFF_CELL_H)

	var lx: float = screen_pos.x - tr_x
	var ly: float = screen_pos.y - tr_y
	if lx < 0.0 or lx >= tr_w or ly < 0.0 or ly >= tr_h:
		_hide_brush()
		return

	var hx: float = lx / tr_w * float(HONEY_W)
	var hy: float = ly / tr_h * float(HONEY_H)
	var row: int  = clampi(int(hy / float(HEX_ROW_STEP)), 0, F_ROWS - 1)
	var x_off: float = float(HEX_ODD_SHIFT) if (row % 2 == 1) else 0.0
	var col: int  = clampi(int((hx - x_off) / float(HEX_COL_STEP)), 0, F_COLS - 1)
	_update_brush(screen_pos, col)

func _try_scrape(screen_pos: Vector2) -> void:
	if frame == null:
		return

	# TextureRect occupies: x=[FRAME_BAR_L, FRAME_BAR_L+CELL_AREA_W)
	#                        y=[HEADER_H+FRAME_BAR_T, ...+EFF_CELL_H)
	var tr_x: float = float(FRAME_BAR_L)
	var tr_y: float = float(HEADER_H + FRAME_BAR_T)
	var tr_w: float = float(CELL_AREA_W)   # 272.0
	var tr_h: float = float(EFF_CELL_H)    # 95.0

	var lx: float = screen_pos.x - tr_x
	var ly: float = screen_pos.y - tr_y

	if lx < 0.0 or lx >= tr_w or ly < 0.0 or ly >= tr_h:
		_hide_brush()
		return

	# Scale local pixel coords up to honeycomb image space
	var hx: float = lx / tr_w * float(HONEY_W)
	var hy: float = ly / tr_h * float(HONEY_H)

	# Determine row (same formula as InspectionOverlay tooltip)
	var row: int = clampi(int(hy / float(HEX_ROW_STEP)), 0, F_ROWS - 1)

	# Odd rows shift right by HEX_ODD_SHIFT
	var x_off: float = float(HEX_ODD_SHIFT) if (row % 2 == 1) else 0.0
	var col: int = clampi(int((hx - x_off) / float(HEX_COL_STEP)), 0, F_COLS - 1)

	# Update brush visual
	_update_brush(screen_pos, col)

	# Apply brush: BRUSH_HALF columns either side of cursor, ALL rows.
	# The blade spans the full frame height so one horizontal drag clears
	# the entire column range -- fast and matching the visual.
	if _scraping:
		var any_changed: bool = false
		for dc in range(-BRUSH_HALF, BRUSH_HALF + 1):
			var c: int = col + dc
			if c < 0 or c >= F_COLS:
				continue
			for r in F_ROWS:
				if _uncap_cell_silent(r, c):
					any_changed = true
		# One batched render + progress update per motion event
		if any_changed:
			_render()
			_update_progress()

# Uncap a single cell in-place.  Returns true if the state changed.
# Does NOT call _render() or _update_progress() -- callers batch those.
func _uncap_cell_silent(row: int, col: int) -> bool:
	var idx: int = row * F_COLS + col
	if idx < 0 or idx >= frame.grid_size:
		return false

	var state: int
	if _current_side == 0:
		state = int(frame.cells[idx])
	else:
		state = int(frame.cells_b[idx])

	if state != CellStateTransition.S_CAPPED_HONEY and state != CellStateTransition.S_PREMIUM_HONEY:
		return false

	# Remove the wax cap: expose the liquid honey (S_CURING_HONEY)
	if _current_side == 0:
		frame.cells[idx] = CellStateTransition.S_CURING_HONEY
	else:
		frame.cells_b[idx] = CellStateTransition.S_CURING_HONEY

	_scraped_this_side += 1
	result_cells_scraped += 1
	return true

# Legacy single-cell wrapper used by flip (keeps render+progress in one call)
func _uncap_cell(row: int, col: int) -> void:
	if _uncap_cell_silent(row, col):
		_render()
		_update_progress()

func _flip_side() -> void:
	_current_side = 1 - _current_side
	_scraped_this_side = 0
	_count_cappable()
	if _side_lbl:
		_side_lbl.text = "Side A" if _current_side == 0 else "Side B"
	if _header_lbl:
		_header_lbl.text = _header_text()
	_render()
	_update_progress()

func _finish_side() -> void:
	_done = true
	_hide_brush()
	if _status_lbl:
		_status_lbl.text = "Frame de-capped!"
	if _progress_lbl:
		_progress_lbl.text = "100%"
	var timer: SceneTreeTimer = get_tree().create_timer(0.7)
	timer.timeout.connect(_finish)

func _finish() -> void:
	_restore_cursor()
	scraping_complete.emit()
