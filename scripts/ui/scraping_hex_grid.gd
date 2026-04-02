# scraping_hex_grid.gd - Draws the honeycomb hex cell grid for the scraping minigame.
# Attach as a child Node2D inside scraping_minigame's CanvasLayer.
# Position this node at the top-left corner of the frame interior.
# Set cells[] and call queue_redraw() to update the visual.
extends Node2D

# -- Grid dimensions (must match scraping_minigame constants) ------------------
const GRID_COLS := 24
const GRID_ROWS := 14

# -- Hex geometry (pointy-top hexagons) ---------------------------------------
# Pointy-top means the top vertex points up, flat sides face left/right.
# col_step = sqrt(3) * r ~= 6.93 -> rounded to 7 px
# row_step = 1.5 * r = 6 px
# Odd columns are shifted DOWN by odd_col_offset to create the honeycomb stagger.
const HEX_R: float = 4.0   # radius: center to vertex
const COL_STEP: float = 7.0   # horizontal gap between column centers
const ROW_STEP: float = 6.0   # vertical gap between row centers
const ODD_COL_OFFS: float = 3.0   # extra downward shift for odd columns

# Margins to center the hex grid within the 192x112 frame interior
# 24 cols * 7 = 168 wide; right-edge hex at 165 -> left margin = (192-165)/2 ~= 12
# 14 rows * 6 = 84 tall + odd offset 3 -> height 91; top margin ~ 10
const MARGIN_X: float = 12.0
const MARGIN_Y: float = 8.0

# -- Cell state array ----------------------------------------------------------
# true = uncapped (bright honey), false = capped (pale wax cap)
# Indexed as: cells[row * GRID_COLS + col]
var cells: Array = []

# -- Colors -------------------------------------------------------------------
# Background: dark amber wax (shows in gaps between cells)
const C_BG          : Color = Color(0.22, 0.12, 0.04, 1.0)
# Capped cell: pale wax cap color
const C_CAPPED      : Color = Color(0.80, 0.66, 0.30, 1.0)
# Uncapped cell: bright exposed honey
const C_UNCAPPED    : Color = Color(0.97, 0.83, 0.30, 1.0)
# Highlight dot on uncapped cells (sparkle)
const C_HONEY_HI    : Color = Color(1.00, 0.93, 0.55, 1.0)

# =========================================================================
# DRAWING
# =========================================================================
## Draw the honeycomb hex grid with cell states (capped or uncapped).
func _draw() -> void:
	# Dark wax background fills the full frame interior
	draw_rect(Rect2(0.0, 0.0, 192.0, 112.0), C_BG)

	if cells.size() < GRID_COLS * GRID_ROWS:
		return

	var verts: PackedVector2Array = PackedVector2Array()
	verts.resize(6)

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var is_uncapped: bool = cells[idx]

			# Compute hex center (pointy-top, odd columns shifted down)
			var cx: float = MARGIN_X + float(col) * COL_STEP + HEX_R
			var cy: float = MARGIN_Y + float(row) * ROW_STEP + HEX_R
			if col % 2 == 1:
				cy += ODD_COL_OFFS

			# Build 6-vertex polygon for this hex cell
			for i in range(6):
				var angle: float = deg_to_rad(60.0 * float(i) - 30.0)
				verts[i] = Vector2(cx + HEX_R * cos(angle), cy + HEX_R * sin(angle))

			var cell_color: Color = C_UNCAPPED if is_uncapped else C_CAPPED
			draw_colored_polygon(verts, cell_color)

			# Small highlight dot on uncapped cells to simulate dripping honey
			if is_uncapped:
				draw_circle(Vector2(cx - 0.5, cy - 0.8), 0.7, C_HONEY_HI)
