# InspectionOverlay.gd
# -----------------------------------------------------------------------------
# Full-screen CanvasLayer that shows the interior of a placed Hive node.
# Renders all 10 frames of the brood box using FrameRenderer's honeycomb mode.
#
# Inspection Knowledge Tiers (GDD S6.1.1):
#   Level 1 -- Hobbyist:       Eyes only. No tooltip, no stats sidebar.
#   Level 2 -- Apprentice:     Mouseover tooltip shows cell state name.
#   Level 3 -- Beekeeper:      Qualitative sidebar ("Solid brood", "Heavy honey").
#   Level 4 -- Journeyman:     Approximate counts & ranges + cell age in tooltip.
#   Level 5 -- Master:         Exact stats (current full stats panel).
#   Dev Mode -- overrides to Level 5 display regardless of player level.
#
# Layout at 320x180 viewport:
#   Header  18px -- hive name, frame counter, A/D nav hint
#   Grid   150px -- 70x50 honeycomb image scaled into Langstroth frame bars
#   Stats   40px -- right column, visibility gated by tier
#   Footer  12px -- ESC close, energy cost, harvest hint
#
# USAGE:
#   var ov := preload("res://scenes/inspection/InspectionOverlay.tscn").instantiate()
#   ov.open(hive_node)
#   get_tree().current_scene.add_child(ov)
# -----------------------------------------------------------------------------
extends CanvasLayer
class_name InspectionOverlay

# -- Signals -------------------------------------------------------------------
signal closed

# -- Layout constants -----------------------------------------------------------
const VP_W        := 320
const VP_H        := 180
const HEADER_H    := 18
const FOOTER_H    := 12
const STATS_W     := 40
const GRID_W      := VP_W - STATS_W           # 280
const GRID_H      := VP_H - HEADER_H - FOOTER_H  # 150
const GRID_ORIGIN := Vector2(0, HEADER_H)

# -- Cell/frame geometry (mirrors CellStateTransition constants) ----------------
const FRAME_COLS  := 70
const FRAME_ROWS  := 50
const TOTAL_CELLS := FRAME_COLS * FRAME_ROWS   # 3500

# -- Langstroth frame bar dimensions (scaled to 320x180 viewport) --------------
const FRAME_BAR_T  := 8    # top bar height  (px)
const FRAME_BAR_B  := 5    # bottom bar height (px)
const FRAME_BAR_L  := 4    # left side bar width (px)
const FRAME_BAR_R  := 4    # right side bar width (px)
const CELL_AREA_W  := GRID_W - FRAME_BAR_L - FRAME_BAR_R   # 272 px
const CELL_AREA_H  := GRID_H - FRAME_BAR_T - FRAME_BAR_B   # 137 px

# -- Colour palette -------------------------------------------------------------
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
const C_DANGER     := Color(0.90, 0.35, 0.25, 1.0)
const C_GOOD       := Color(0.45, 0.82, 0.45, 1.0)
const C_HARVEST_MK := Color(1.00, 0.85, 0.20, 0.60)  # gold overlay for marked frames
const C_CAP_GREEN  := Color(0.30, 0.80, 0.30, 1.0)    # >=80% capped
const C_CAP_YELLOW := Color(0.90, 0.80, 0.20, 1.0)    # 60-79% capped
const C_CAP_RED    := Color(0.90, 0.30, 0.25, 1.0)    # <60% capped

# -- Energy cost (GDD S2.1) ------------------------------------------------------
const ENERGY_COST := 10.0

# -- Queen Finder Phase 2 (GDD S6.1 + Queen Finder Sub-GDD) ----------------------
# Replaced probability-based sighting with click-based visual search.
# Queen spawn chance (80%) and difficulty rank are rolled once per inspection.
# XP scales with difficulty: Easy=10, Medium=15, Hard=25.

# -- Internal refs ----------------------------------------------------------------
var _hive:          Node          = null
var _sim:           HiveSimulation = null
var _renderer:      FrameRenderer = null
var _box_idx:       int           = 0
var _frame_idx:     int           = 0
var _current_side:  int           = 0
var _queen_seen:    bool          = false

# -- Queen Finder Phase 2 (bee overlay) ----------------------------------------
var _bee_overlay: BeeOverlay = null
var _bee_rect:    TextureRect = null   # displays the bee sprite overlay

# UI nodes
var _header_name:   Label  = null
var _header_frame:  Label  = null
var _cell_rect:     TextureRect = null
var _tooltip:       Label  = null
var _tooltip_panel: PanelContainer = null
var _stats_labels:  Array  = []
var _footer_label:  Label  = null
var _stats_bg_rect: ColorRect = null   # so we can show/hide it per tier
var _stats_div:     ColorRect = null

# -- Harvest marking UI ---------------------------------------------------
var _harvest_mark_rect: ColorRect = null   # gold overlay when frame is marked
var _harvest_label:     Label     = null   # "MARKED" / capping % indicator
var _ferment_dialog:    Control   = null   # low capping warning popup

# -- Dynamic frame resizing for deep vs super frames -------------------------
var _foundation_rect:  ColorRect = null
var _bar_top_rect:     ColorRect = null
var _bar_top_hi_rect:  ColorRect = null
var _bar_top_sh_rect:  ColorRect = null
var _bar_bot_rect:     ColorRect = null
var _bar_bot_hi_rect:  ColorRect = null
var _bar_left_rect:    ColorRect = null
var _bar_left_hi_rect: ColorRect = null
var _bar_right_rect:   ColorRect = null
var _bar_right_sh_rect: ColorRect = null
var _lug_rects:        Array     = []   # [lug, lug_hi] pairs
var _wire_rects:       Array     = []
var _is_super_display: bool      = false   # tracks current display mode

# -- Dev advance buttons (visible only in dev mode) ----------------------------
var _dev_day_btn:   Button = null
var _dev_month_btn: Button = null
var _dev_month_advancing: bool = false
var _dev_month_days_left: int  = 0

# -- Effective inspection tier ----------------------------------------------------
# Resolved once in open(). Dev mode forces tier 5.
var _tier: int = 1

# -- Progressive accumulation -------------------------------------------------
# Tracks which frame+side combos have been examined. Stats build as you inspect.
var _viewed_sides:     Dictionary = {}   # "frame:side" -> true
var _accum_counts:     Dictionary = {}   # cell_state -> accumulated count
var _total_cells_seen: int        = 0    # total cells examined so far

# ------------------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------------------

## Opens the inspection overlay for a hive node, initializing display and state.
func open(hive_node: Node) -> void:
	_hive = hive_node
	_sim  = hive_node.get_node_or_null("HiveSimulation") as HiveSimulation

	GameData.deduct_energy(ENERGY_COST)

	# Resolve inspection tier: dev mode -> 5, otherwise player level
	if GameData.dev_labels_visible:
		_tier = 5
	else:
		_tier = clampi(GameData.player_level, 1, 5)

	_box_idx    = 0
	_frame_idx  = 0
	_queen_seen = false
	_renderer   = FrameRenderer.new()

	# Reset progressive accumulators -- each inspection starts from scratch
	_viewed_sides.clear()
	_accum_counts.clear()
	_total_cells_seen = 0

	# -- Queen Finder Phase 2: initialize bee overlay session -------------------
	if _sim != null:
		_bee_overlay = BeeOverlay.new()
		# Roll difficulty rank: flat 33/33/34
		var diff_roll: int = randi() % 3
		# Roll queen visibility: 80% chance
		var queen_vis: bool = _sim.queen.get("present", false) and randf() < 0.80
		_bee_overlay.init_session(_sim, diff_roll, queen_vis)

	# Listen for dev mode toggle so we can refresh mid-inspection
	if not GameData.dev_labels_toggled.is_connected(_on_dev_toggled):
		GameData.dev_labels_toggled.connect(_on_dev_toggled)

	# Apply tier visibility
	_apply_tier_visibility()

	_refresh_frame()
	_record_current_side()
	_refresh_stats()
	_populate_bees()
	_refresh_harvest_overlay()

	# Notify quest system that an inspection was opened
	QuestManager.notify_event("inspection_opened", {"hive": hive_node})

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

## Initializes the inspection overlay UI and constructs all visual elements.
func _ready() -> void:
	layer = 10
	add_to_group("inspection_overlay")

	# -- Root background --------------------------------------------------------
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# -- Header bar ------------------------------------------------------------
	var header_bar := ColorRect.new()
	header_bar.color    = C_HEADER_BG
	header_bar.size     = Vector2(VP_W, HEADER_H)
	header_bar.position = Vector2.ZERO
	bg.add_child(header_bar)

	_header_name = _lbl("", 7, Vector2(4, 2), Vector2(180, 10), C_ACCENT)
	header_bar.add_child(_header_name)

	_header_frame = _lbl("Frame 1/10", 6, Vector2(190, 2), Vector2(80, 10), C_MUTED)
	_header_frame.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_bar.add_child(_header_frame)

	var nav_hint := _lbl("[A] ?  ? [D]  [F] Flip", 5, Vector2(0, 10), Vector2(VP_W, 8), C_MUTED)
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_bar.add_child(nav_hint)

	var h_div := ColorRect.new()
	h_div.color    = C_BORDER
	h_div.size     = Vector2(VP_W, 1)
	h_div.position = Vector2(0, HEADER_H - 1)
	bg.add_child(h_div)

	# -- Stats panel (right column) -- built always, visibility toggled per tier -
	_stats_bg_rect = ColorRect.new()
	_stats_bg_rect.color    = C_STATS_BG
	_stats_bg_rect.size     = Vector2(STATS_W, GRID_H)
	_stats_bg_rect.position = Vector2(GRID_W, HEADER_H)
	bg.add_child(_stats_bg_rect)

	_stats_div = ColorRect.new()
	_stats_div.color    = C_BORDER
	_stats_div.size     = Vector2(1, GRID_H)
	_stats_div.position = Vector2(GRID_W, HEADER_H)
	bg.add_child(_stats_div)

	var stat_y := HEADER_H + 1
	# 21 labels: 15 for current stats + divider + 5 forecast (dev mode uses all)
	for _i in 21:
		var lbl := _lbl("", 4, Vector2(GRID_W + 2, stat_y), Vector2(STATS_W - 4, 8), C_TEXT)
		lbl.clip_text = true
		bg.add_child(lbl)
		_stats_labels.append(lbl)
		stat_y += 8

	# -- Langstroth frame background --------------------------------------------
	var cell_x := FRAME_BAR_L
	var cell_y := HEADER_H + FRAME_BAR_T

	_foundation_rect = ColorRect.new()
	_foundation_rect.color    = C_FOUNDATION
	_foundation_rect.size     = Vector2(CELL_AREA_W, CELL_AREA_H)
	_foundation_rect.position = Vector2(cell_x, cell_y)
	bg.add_child(_foundation_rect)

	_wire_rects.clear()
	for wi in 3:
		var wy := cell_y + int((wi + 1) * CELL_AREA_H / 4)
		var wire := ColorRect.new()
		wire.color    = C_WIRE
		wire.size     = Vector2(CELL_AREA_W, 1)
		wire.position = Vector2(cell_x, wy)
		bg.add_child(wire)
		_wire_rects.append(wire)

	# Top bar
	_bar_top_rect = ColorRect.new()
	_bar_top_rect.color    = C_WOOD
	_bar_top_rect.size     = Vector2(GRID_W, FRAME_BAR_T)
	_bar_top_rect.position = Vector2(0, HEADER_H)
	bg.add_child(_bar_top_rect)

	_bar_top_hi_rect = ColorRect.new()
	_bar_top_hi_rect.color    = C_WOOD_HI
	_bar_top_hi_rect.size     = Vector2(GRID_W, 1)
	_bar_top_hi_rect.position = Vector2(0, HEADER_H)
	bg.add_child(_bar_top_hi_rect)

	_bar_top_sh_rect = ColorRect.new()
	_bar_top_sh_rect.color    = C_WOOD_SH
	_bar_top_sh_rect.size     = Vector2(GRID_W, 1)
	_bar_top_sh_rect.position = Vector2(0, cell_y - 1)
	bg.add_child(_bar_top_sh_rect)

	_lug_rects.clear()
	for lug_x in [0, GRID_W - 14]:
		var lug := ColorRect.new()
		lug.color    = C_WOOD_LUG
		lug.size     = Vector2(14, FRAME_BAR_T)
		lug.position = Vector2(lug_x, HEADER_H)
		bg.add_child(lug)
		var lug_hi := ColorRect.new()
		lug_hi.color    = C_WOOD_HI
		lug_hi.size     = Vector2(14, 1)
		lug_hi.position = Vector2(lug_x, HEADER_H)
		bg.add_child(lug_hi)
		_lug_rects.append([lug, lug_hi])

	# Bottom bar
	_bar_bot_rect = ColorRect.new()
	_bar_bot_rect.color    = C_WOOD
	_bar_bot_rect.size     = Vector2(GRID_W, FRAME_BAR_B)
	_bar_bot_rect.position = Vector2(0, HEADER_H + GRID_H - FRAME_BAR_B)
	bg.add_child(_bar_bot_rect)

	_bar_bot_hi_rect = ColorRect.new()
	_bar_bot_hi_rect.color    = C_WOOD_HI
	_bar_bot_hi_rect.size     = Vector2(GRID_W, 1)
	_bar_bot_hi_rect.position = Vector2(0, HEADER_H + GRID_H - FRAME_BAR_B)
	bg.add_child(_bar_bot_hi_rect)

	# Left side bar
	_bar_left_rect = ColorRect.new()
	_bar_left_rect.color    = C_WOOD
	_bar_left_rect.size     = Vector2(FRAME_BAR_L, CELL_AREA_H)
	_bar_left_rect.position = Vector2(0, cell_y)
	bg.add_child(_bar_left_rect)

	_bar_left_hi_rect = ColorRect.new()
	_bar_left_hi_rect.color    = C_WOOD_HI
	_bar_left_hi_rect.size     = Vector2(1, CELL_AREA_H)
	_bar_left_hi_rect.position = Vector2(FRAME_BAR_L - 1, cell_y)
	bg.add_child(_bar_left_hi_rect)

	# Right side bar
	_bar_right_rect = ColorRect.new()
	_bar_right_rect.color    = C_WOOD
	_bar_right_rect.size     = Vector2(FRAME_BAR_R, CELL_AREA_H)
	_bar_right_rect.position = Vector2(GRID_W - FRAME_BAR_R, cell_y)
	bg.add_child(_bar_right_rect)

	_bar_right_sh_rect = ColorRect.new()
	_bar_right_sh_rect.color    = C_WOOD_SH
	_bar_right_sh_rect.size     = Vector2(1, CELL_AREA_H)
	_bar_right_sh_rect.position = Vector2(GRID_W - FRAME_BAR_R, cell_y)
	bg.add_child(_bar_right_sh_rect)

	# -- Cell grid (TextureRect) -----------------------------------------------
	_cell_rect = TextureRect.new()
	_cell_rect.position          = Vector2(cell_x, cell_y)
	_cell_rect.size              = Vector2(CELL_AREA_W, CELL_AREA_H)
	_cell_rect.expand_mode       = TextureRect.EXPAND_IGNORE_SIZE
	_cell_rect.stretch_mode      = TextureRect.STRETCH_SCALE
	_cell_rect.texture_filter    = CanvasItem.TEXTURE_FILTER_NEAREST
	_cell_rect.mouse_filter      = Control.MOUSE_FILTER_PASS
	_cell_rect.mouse_entered.connect(_on_grid_mouse_entered)
	_cell_rect.mouse_exited.connect(_on_grid_mouse_exited)
	bg.add_child(_cell_rect)

	# -- Bee overlay (Phase 2 queen finder sprites) ----------------------------
	_bee_rect = TextureRect.new()
	_bee_rect.position          = Vector2(cell_x, cell_y)
	_bee_rect.size              = Vector2(CELL_AREA_W, CELL_AREA_H)
	_bee_rect.expand_mode       = TextureRect.EXPAND_IGNORE_SIZE
	_bee_rect.stretch_mode      = TextureRect.STRETCH_SCALE
	_bee_rect.texture_filter    = CanvasItem.TEXTURE_FILTER_NEAREST
	_bee_rect.mouse_filter      = Control.MOUSE_FILTER_PASS
	_bee_rect.z_index           = 1   # Above cell grid
	bg.add_child(_bee_rect)

	# -- Harvest mark overlay (gold tint when frame is marked) ----------------
	_harvest_mark_rect = ColorRect.new()
	_harvest_mark_rect.color    = C_HARVEST_MK
	_harvest_mark_rect.position = Vector2(cell_x, cell_y)
	_harvest_mark_rect.size     = Vector2(CELL_AREA_W, CELL_AREA_H)
	_harvest_mark_rect.visible  = false
	_harvest_mark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_harvest_mark_rect.z_index  = 2
	bg.add_child(_harvest_mark_rect)

	# -- Harvest status label (top-left of frame: "MARKED" + capping %) ------
	_harvest_label = _lbl("", 5, Vector2(cell_x + 2, cell_y + 2),
		Vector2(CELL_AREA_W - 4, 8), C_ACCENT)
	_harvest_label.z_index = 3
	_harvest_label.visible = false
	bg.add_child(_harvest_label)

	# -- Tooltip (black box with orange border, follows mouse) -----------------
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 20
	var tt_sb := StyleBoxFlat.new()
	tt_sb.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	tt_sb.border_color = C_ACCENT  # orange
	tt_sb.set_border_width_all(1)
	tt_sb.set_content_margin_all(3)
	tt_sb.set_corner_radius_all(0)
	_tooltip_panel.add_theme_stylebox_override("panel", tt_sb)
	bg.add_child(_tooltip_panel)

	_tooltip = Label.new()
	_tooltip.add_theme_font_size_override("font_size", 5)
	_tooltip.add_theme_color_override("font_color", C_ACCENT)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip)

	# -- Footer bar ------------------------------------------------------------
	var footer_div := ColorRect.new()
	footer_div.color    = C_BORDER
	footer_div.size     = Vector2(VP_W, 1)
	footer_div.position = Vector2(0, VP_H - FOOTER_H)
	bg.add_child(footer_div)

	var footer_bg := ColorRect.new()
	footer_bg.color    = C_HEADER_BG
	footer_bg.size     = Vector2(VP_W, FOOTER_H)
	footer_bg.position = Vector2(0, VP_H - FOOTER_H)
	bg.add_child(footer_bg)

	_footer_label = _lbl("[A/D] Frame  [F] Flip  [W/S] Box  [H] Mark  [Click] Queen  [ESC] Close",
		5, Vector2(2, VP_H - FOOTER_H + 2), Vector2(VP_W - 4, 8), C_MUTED)
	bg.add_child(_footer_label)

	# -- Dev mode advance buttons (top-right of stats panel) -------------------
	_build_dev_advance_buttons(bg)

	# Sync all visibility (tier, tooltip, dev buttons) now that UI is fully built.
	# open() is called before add_child() so _apply_tier_visibility() was a no-op
	# there. This call guarantees the correct initial state.
	_apply_tier_visibility()

## Disconnects all signals when the node is removed from the scene tree.
func _exit_tree() -> void:
	if GameData.dev_labels_toggled.is_connected(_on_dev_toggled):
		GameData.dev_labels_toggled.disconnect(_on_dev_toggled)
	if _cell_rect and _cell_rect.mouse_entered.is_connected(_on_grid_mouse_entered):
		_cell_rect.mouse_entered.disconnect(_on_grid_mouse_entered)
	if _cell_rect and _cell_rect.mouse_exited.is_connected(_on_grid_mouse_exited):
		_cell_rect.mouse_exited.disconnect(_on_grid_mouse_exited)
	if _dev_day_btn and _dev_day_btn.pressed.is_connected(_on_dev_advance_day_inspection):
		_dev_day_btn.pressed.disconnect(_on_dev_advance_day_inspection)
	if _dev_month_btn and _dev_month_btn.pressed.is_connected(_on_dev_advance_month_inspection):
		_dev_month_btn.pressed.disconnect(_on_dev_advance_month_inspection)

## Builds the development mode day/month advance buttons.
func _build_dev_advance_buttons(bg: Control) -> void:
	var btn_w: int = 36
	var btn_h: int = 11
	var gap: int = 2
	# Place buttons in the footer. The "DEV" label sits left of the buttons.
	var by: int   = VP_H - FOOTER_H + 1
	var bx_month: int = GRID_W - btn_w - 2
	var bx_day: int   = bx_month - btn_w - gap

	# "DEV:" marker label -- added to dev_label group so G key auto-shows it
	var dev_lbl: Label = Label.new()
	dev_lbl.text = "DEV:"
	dev_lbl.add_theme_font_size_override("font_size", 5)
	dev_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15, 1.0))
	dev_lbl.position = Vector2(bx_day - 30, by + 1)
	dev_lbl.size     = Vector2(28, 9)
	dev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dev_lbl.add_to_group("dev_label")
	bg.add_child(dev_lbl)

	_dev_day_btn = _make_dev_btn("+ Day", bx_day, by, btn_w, btn_h, C_ACCENT)
	_dev_day_btn.pressed.connect(_on_dev_advance_day_inspection)
	_dev_day_btn.add_to_group("dev_label")
	bg.add_child(_dev_day_btn)

	_dev_month_btn = _make_dev_btn("+ Month", bx_month, by, btn_w, btn_h,
		Color(0.95, 0.65, 0.20))
	_dev_month_btn.pressed.connect(_on_dev_advance_month_inspection)
	_dev_month_btn.add_to_group("dev_label")
	bg.add_child(_dev_month_btn)

	# Set initial visibility -- also handled by G-key group toggle and _apply_tier_visibility
	var vis: bool = GameData.dev_labels_visible
	dev_lbl.visible        = vis
	_dev_day_btn.visible   = vis
	_dev_month_btn.visible = vis

## Creates a styled development button.
func _make_dev_btn(label: String, x: int, y: int, w: int, h: int, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 5)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		if state == "hover":
			sb.bg_color = Color(0.62, 0.44, 0.12, 0.98)
		elif state == "pressed":
			sb.bg_color = Color(0.75, 0.55, 0.15, 0.98)
		elif state == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		elif state == "disabled":
			sb.bg_color = Color(0.30, 0.22, 0.08, 0.80)
		else:
			# Bright amber -- high contrast against footer bg Color(0.12,0.10,0.07)
			sb.bg_color = Color(0.50, 0.34, 0.09, 0.98)
		sb.border_color = col
		sb.set_border_width_all(1)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.z_index = 25
	return btn

# -- Dev advance: run one simulation day and refresh the inspection view -------
## Advances simulation by one day during inspection.
func _on_dev_advance_day_inspection() -> void:
	_dev_sim_one_day()
	_refresh_frame()
	_refresh_stats()
	_populate_bees()
	_refresh_harvest_overlay()

## Begins advancing simulation by one month.
func _on_dev_advance_month_inspection() -> void:
	if _dev_month_advancing:
		return
	_dev_month_advancing = true
	_dev_month_days_left = 28
	if _dev_month_btn:
		_dev_month_btn.text = "28..."
		_dev_month_btn.disabled = true
	var timer := Timer.new()
	timer.name = "DevMonthTimer"
	timer.wait_time = 0.05
	timer.one_shot = false
	timer.timeout.connect(_dev_month_tick_inspection.bind(timer))
	add_child(timer)
	timer.start()

## Ticks one day during month advancement.
func _dev_month_tick_inspection(timer: Timer) -> void:
	if _dev_month_days_left <= 0:
		timer.stop()
		timer.queue_free()
		_dev_month_finish_inspection()
		return
	_dev_sim_one_day()
	_dev_month_days_left -= 1
	# Live-refresh the frame view each day so you can watch changes
	_refresh_frame()
	_refresh_stats()
	if _dev_month_btn:
		_dev_month_btn.text = "%d..." % _dev_month_days_left
	if _dev_month_days_left <= 0:
		timer.stop()
		timer.queue_free()
		_dev_month_finish_inspection()

## Completes the month advancement sequence.
func _dev_month_finish_inspection() -> void:
	_dev_month_advancing = false
	if _dev_month_btn:
		_dev_month_btn.text = "+ Month"
		_dev_month_btn.disabled = false
	_refresh_frame()
	_refresh_stats()
	_populate_bees()
	_refresh_harvest_overlay()

## Shared day-advance logic (same as HUD _dev_sim_one_day).
func _dev_sim_one_day() -> void:
	for h in get_tree().get_nodes_in_group("hive"):
		if h.has_method("advance_day"):
			h.advance_day()
	for fl in get_tree().get_nodes_in_group("flowers"):
		if fl.has_method("advance_day_with_global"):
			fl.advance_day_with_global(TimeManager.current_day + 1)
	TimeManager.start_new_day()
	GameData.full_restore_energy()

## Handles keyboard input for navigation and actions.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# If fermentation warning dialog is open, only accept Y/N/Escape
	if _ferment_dialog and _ferment_dialog.visible:
		match event.keycode:
			KEY_Y:
				_confirm_mark_despite_fermentation()
			KEY_N, KEY_ESCAPE:
				_dismiss_fermentation_warning()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_ESCAPE:
			closed.emit()
			queue_free()
		KEY_A:
			_navigate(-1)
		KEY_D:
			_navigate(+1)
		KEY_W:
			_switch_box(-1)
		KEY_S:
			_switch_box(+1)
		KEY_F:
			_flip_side()
		KEY_H:
			if event.shift_pressed:
				_mark_entire_super()
			else:
				_toggle_frame_harvest_mark()
		KEY_E:
			_harvest_from_overlay()
		KEY_G:
			# Forward G to GameData so dev mode toggles while overlay is open.
			# Without this explicit case the unconditional set_input_as_handled()
			# below would consume G before the player/GameData ever sees it.
			GameData.toggle_dev_labels()
	get_viewport().set_input_as_handled()

## Handles mouse click input for queen finder.
func _unhandled_input(event: InputEvent) -> void:
	# Queen Finder Phase 2: click detection on bee overlay
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _bee_overlay == null or _bee_rect == null or _queen_seen:
			return
		# Convert viewport mouse position to bee overlay canvas coordinates
		var canvas_pos: Vector2 = _viewport_to_canvas(event.position)
		if canvas_pos.x < 0.0:
			return  # click outside the cell area
		var result: Dictionary = _bee_overlay.hit_test(canvas_pos)
		if result.get("is_queen", false):
			_queen_seen = true
			var xp_amount: int = result.get("xp", 15)
			GameData.add_xp(xp_amount)
			_show_queen_notification_phase2(xp_amount)
			get_viewport().set_input_as_handled()
		elif result.get("hit", false):
			# Wrong bee -- feedback handled by BeeOverlay flash_timer
			get_viewport().set_input_as_handled()

## Updates frame per-frame (tooltip positioning, etc).
func _process(delta: float) -> void:
	_refresh_tooltip()
	# Queen Finder Phase 2: update bee animations and render overlay
	if _bee_overlay != null:
		_bee_overlay.update(delta)
		if _bee_rect != null:
			_bee_rect.texture = _bee_overlay.get_texture()

# ------------------------------------------------------------------------------
# Tier Visibility -- called once from open() after _tier is resolved
# ------------------------------------------------------------------------------

## Shows or hides UI elements based on inspection tier.
func _apply_tier_visibility() -> void:
	# Stats sidebar: hidden at tier 1-2, visible at tier 3+
	var show_stats: bool = _tier >= 3
	if _stats_bg_rect:
		_stats_bg_rect.visible = show_stats
	if _stats_div:
		_stats_div.visible = show_stats
	for lbl in _stats_labels:
		(lbl as Label).visible = show_stats

	# Tooltip: enabled at tier 2+. Also force-show when dev mode toggled
	# mid-inspection (mouse may already be over grid, so entered() won't re-fire).
	if _tooltip_panel:
		_tooltip_panel.visible = _tier >= 2

	# Dev advance buttons: visible only in dev mode
	var show_dev: bool = GameData.dev_labels_visible
	if _dev_day_btn:
		_dev_day_btn.visible = show_dev
	if _dev_month_btn:
		_dev_month_btn.visible = show_dev

## React to dev mode being toggled while the inspection overlay is open.
func _on_dev_toggled(_visible: bool) -> void:
	if GameData.dev_labels_visible:
		_tier = 5
	else:
		_tier = clampi(GameData.player_level, 1, 5)
	_apply_tier_visibility()
	_refresh_frame()
	_refresh_stats()

# ------------------------------------------------------------------------------
# Frame Navigation
# ------------------------------------------------------------------------------

## Navigates to adjacent frames.
func _navigate(dir: int) -> void:
	if _sim == null:
		return
	var box: Variant = _current_box()
	if box == null:
		return
	var frame_count: int = box.frames.size()
	_frame_idx = (_frame_idx + dir + frame_count) % frame_count
	_current_side = 0
	_refresh_frame()
	_record_current_side()
	_refresh_stats()
	_populate_bees()
	_refresh_harvest_overlay()

## Switches between brood box and super box.
func _switch_box(dir: int) -> void:
	if _sim == null or _sim.boxes.size() <= 1:
		return
	_box_idx = (_box_idx + dir + _sim.boxes.size()) % _sim.boxes.size()
	_frame_idx = 0
	_current_side = 0
	_refresh_frame()
	_record_current_side()
	_refresh_stats()
	_populate_bees()
	_refresh_harvest_overlay()

## Flips between front and back sides of the current frame.
func _flip_side() -> void:
	_current_side = 1 - _current_side
	_refresh_frame()
	_record_current_side()
	_refresh_stats()

## Total number of inspectable sides across ALL boxes (frames * 2 per box).
func _total_inspectable_sides() -> int:
	if _sim == null or _sim.boxes.is_empty():
		return 0
	var total := 0
	for b in _sim.boxes:
		total += b.frames.size() * 2
	return total

## Helper: return the currently selected box, or null.
func _current_box() -> Variant:
	if _sim == null or _sim.boxes.is_empty():
		return null
	if _box_idx >= _sim.boxes.size():
		_box_idx = 0
	return _sim.boxes[_box_idx]

# ------------------------------------------------------------------------------
# Rendering
# ------------------------------------------------------------------------------

## Resize all frame display elements to fit super (35-row) or deep (50-row) frames.
## Super frames are shorter; the wooden frame + cell area shrink to match, centered
## vertically in the available GRID_H space so there is no black gap.
func _resize_for_frame_type(is_super: bool) -> void:
	if is_super == _is_super_display:
		return   # already sized correctly
	_is_super_display = is_super

	var rows: int = 35 if is_super else 50
	var effective_cell_h: int = int(CELL_AREA_H * rows / 50)
	var effective_grid_h: int = FRAME_BAR_T + effective_cell_h + FRAME_BAR_B
	# Center the shorter frame vertically in the available GRID_H space
	var y_offset: int = HEADER_H + (GRID_H - effective_grid_h) / 2
	var cell_x: int = FRAME_BAR_L
	var cell_y: int = y_offset + FRAME_BAR_T

	# Top bar
	if _bar_top_rect:
		_bar_top_rect.position    = Vector2(0, y_offset)
		_bar_top_hi_rect.position = Vector2(0, y_offset)
		_bar_top_sh_rect.position = Vector2(0, cell_y - 1)
	for lug_pair in _lug_rects:
		lug_pair[0].position.y = y_offset
		lug_pair[1].position.y = y_offset

	# Foundation background
	if _foundation_rect:
		_foundation_rect.position = Vector2(cell_x, cell_y)
		_foundation_rect.size     = Vector2(CELL_AREA_W, effective_cell_h)

	# Wires (evenly spaced within cell area)
	for wi in _wire_rects.size():
		var wy: int = cell_y + int((wi + 1) * effective_cell_h / 4)
		_wire_rects[wi].position = Vector2(cell_x, wy)

	# Bottom bar
	if _bar_bot_rect:
		_bar_bot_rect.position    = Vector2(0, cell_y + effective_cell_h)
		_bar_bot_hi_rect.position = Vector2(0, cell_y + effective_cell_h)

	# Side bars
	if _bar_left_rect:
		_bar_left_rect.position    = Vector2(0, cell_y)
		_bar_left_rect.size        = Vector2(FRAME_BAR_L, effective_cell_h)
		_bar_left_hi_rect.position = Vector2(FRAME_BAR_L - 1, cell_y)
		_bar_left_hi_rect.size     = Vector2(1, effective_cell_h)

	if _bar_right_rect:
		_bar_right_rect.position    = Vector2(GRID_W - FRAME_BAR_R, cell_y)
		_bar_right_rect.size        = Vector2(FRAME_BAR_R, effective_cell_h)
		_bar_right_sh_rect.position = Vector2(GRID_W - FRAME_BAR_R, cell_y)
		_bar_right_sh_rect.size     = Vector2(1, effective_cell_h)

	# Cell display, bee overlay, harvest overlay
	if _cell_rect:
		_cell_rect.position = Vector2(cell_x, cell_y)
		_cell_rect.size     = Vector2(CELL_AREA_W, effective_cell_h)
	if _bee_rect:
		_bee_rect.position = Vector2(cell_x, cell_y)
		_bee_rect.size     = Vector2(CELL_AREA_W, effective_cell_h)
	if _harvest_mark_rect:
		_harvest_mark_rect.position = Vector2(cell_x, cell_y)
		_harvest_mark_rect.size     = Vector2(CELL_AREA_W, effective_cell_h)
	if _harvest_label:
		_harvest_label.position = Vector2(cell_x + 2, cell_y + 2)

## Re-renders the current frame based on simulation state.
func _refresh_frame() -> void:
	if _sim == null or _renderer == null:
		return
	var box: Variant = _current_box()
	if box == null or _frame_idx >= box.frames.size():
		return
	# Resize frame display if switching between deep and super
	_resize_for_frame_type(box.is_super)
	var frame: Variant = box.frames[_frame_idx]
	_cell_rect.texture = _renderer.render_honeycomb(frame, _current_side)
	var frame_count: int = box.frames.size()
	var side_label: String = "A" if _current_side == 0 else "B"
	# Show box info in header: "Deep 1" or "Super 2" etc.
	var box_type: String = "Super" if box.is_super else "Deep"
	var box_num: int = 1
	for i in range(_box_idx):
		if _sim.boxes[i].is_super == box.is_super:
			box_num += 1
	var box_label: String = "%s %d" % [box_type, box_num]
	if _sim.boxes.size() > 1:
		_header_frame.text = "[%s]  Frame %d/%d  Side %s  [W/S switch box]" % [box_label, _frame_idx + 1, frame_count, side_label]
	else:
		_header_frame.text = "Frame %d / %d  Side %s" % [_frame_idx + 1, frame_count, side_label]
	if _header_name and _hive:
		var snap: Dictionary = _sim.last_snapshot
		var species: String = snap.get("queen_species", "?")
		_header_name.text = "Hive -- %s colony" % species

# ------------------------------------------------------------------------------
# Progressive Accumulation -- stats build as you inspect each frame side
# ------------------------------------------------------------------------------

## Called each time the player views a frame side. If this side hasn't been
## seen yet, its cell counts are added to the running accumulators.
func _record_current_side() -> void:
	if _sim == null:
		return
	if _current_box() == null or _frame_idx >= _current_box().frames.size():
		return

	var key: String = "%d:%d:%d" % [_box_idx, _frame_idx, _current_side]
	if _viewed_sides.has(key):
		return   # already counted this side

	_viewed_sides[key] = true
	var frame: Variant = _current_box().frames[_frame_idx]
	var side_counts: Dictionary = CellStateTransition.full_count_side(frame, _current_side)

	for state_id in side_counts:
		var prev: int = _accum_counts.get(state_id, 0)
		_accum_counts[state_id] = prev + int(side_counts[state_id])

	_total_cells_seen += TOTAL_CELLS

# ------------------------------------------------------------------------------
# Stats Panel -- tiered display (GDD S6.1.1)
# ------------------------------------------------------------------------------

## Updates the stats panel with current tier data.
func _refresh_stats() -> void:
	# Tiers 1-2: no stats panel shown (labels are hidden via _apply_tier_visibility)
	if _tier < 3:
		return
	if _sim == null:
		return
	if _current_box() == null or _frame_idx >= _current_box().frames.size():
		return

	var snap: Dictionary = _sim.last_snapshot
	var rows: Array = []

	# Dev mode: bypass accumulation, show full accurate stats for entire hive
	if GameData.dev_labels_visible:
		var full_counts: Dictionary = _get_full_hive_counts()
		rows = _build_dev_rows(full_counts, snap)
	else:
		# Normal play: use accumulated counts from inspected frame sides
		var counts: Dictionary = _accum_counts
		var cells_seen: int    = _total_cells_seen

		if _tier == 3:
			rows = _build_qualitative_rows(counts, snap, cells_seen)
		elif _tier == 4:
			rows = _build_approximate_rows(counts, snap, cells_seen)
		else:
			rows = _build_exact_rows(counts, snap, cells_seen)

	for i in _stats_labels.size():
		if i < rows.size():
			var row: Array = rows[i]
			if row.size() >= 3:
				# [label, value, color]
				if row[1] != "":
					_stats_labels[i].text = "%s %s" % [row[0], row[1]]
				else:
					_stats_labels[i].text = str(row[0]).replace("\n", " ")
				_stats_labels[i].add_theme_color_override("font_color", row[2])
			elif row.size() == 2 and row[1] != "":
				_stats_labels[i].text = "%s %s" % [row[0], row[1]]
				_stats_labels[i].add_theme_color_override("font_color", C_TEXT)
			elif row.size() >= 1:
				_stats_labels[i].text = str(row[0]).replace("\n", " ")
				_stats_labels[i].add_theme_color_override("font_color", C_TEXT)
		else:
			_stats_labels[i].text = ""

# -- Tier 3: Qualitative natural-language descriptions -------------------------

## Builds tier 3 qualitative stat rows.
func _build_qualitative_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	var denom: float = maxf(float(cells_seen), 1.0)
	var brood: int = counts.get(CellStateTransition.S_EGG, 0) \
				+ counts.get(CellStateTransition.S_OPEN_LARVA, 0) \
				+ counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var nectar: int = counts.get(CellStateTransition.S_NECTAR, 0) \
				   + counts.get(CellStateTransition.S_CURING_HONEY, 0)
	var honey: int = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
				   + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
	var bee_bread: int = counts.get(CellStateTransition.S_BEE_BREAD, 0)
	var hp: float  = snap.get("health_score", 100.0)

	# Brood pattern assessment
	var brood_desc: String
	var brood_color: Color = C_TEXT
	var brood_pct: float = float(brood) / denom
	if brood_pct > 0.50:
		brood_desc = "Solid brood"
		brood_color = C_GOOD
	elif brood_pct > 0.25:
		brood_desc = "OK brood"
	elif brood_pct > 0.05:
		brood_desc = "Spotty"
		brood_color = C_ACCENT
	elif brood > 0:
		brood_desc = "Sparse"
		brood_color = C_DANGER
	else:
		brood_desc = "No brood"
		brood_color = C_MUTED

	# Honey stores
	var honey_desc: String
	var honey_color: Color = C_TEXT
	var honey_pct: float = float(honey) / denom
	if honey_pct > 0.30:
		honey_desc = "Heavy honey"
		honey_color = C_GOOD
	elif honey_pct > 0.10:
		honey_desc = "Good honey"
	elif honey_pct > 0.02:
		honey_desc = "Low honey"
		honey_color = C_ACCENT
	else:
		honey_desc = "No honey"
		honey_color = C_DANGER

	# Health
	var hp_desc: String
	var hp_color: Color
	if hp >= 70.0:
		hp_desc = "Healthy"
		hp_color = C_GOOD
	elif hp >= 40.0:
		hp_desc = "Concerns"
		hp_color = C_ACCENT
	else:
		hp_desc = "Struggling"
		hp_color = C_DANGER

	# Queen laying assessment
	var eggs: int = counts.get(CellStateTransition.S_EGG, 0)
	var queen_desc: String
	var queen_color: Color = C_TEXT
	if eggs > 200:
		queen_desc = "Laying well"
		queen_color = C_GOOD
	elif eggs > 50:
		queen_desc = "Queen OK"
	elif eggs > 0:
		queen_desc = "Sparse lay"
		queen_color = C_ACCENT
	else:
		queen_desc = "No eggs"
		queen_color = C_MUTED

	# Sides examined indicator
	var examined: String = "%d/%d" % [_viewed_sides.size(), _total_inspectable_sides()]

	# Nectar flow (incoming nectar + curing)
	var nectar_desc: String
	var nectar_color: Color = C_TEXT
	var nectar_pct: float = float(nectar) / denom
	if nectar_pct > 0.15:
		nectar_desc = "Flow on"
		nectar_color = Color(0.70, 0.85, 0.40)
	elif nectar_pct > 0.03:
		nectar_desc = "Some nectar"
		nectar_color = Color(0.70, 0.85, 0.40)
	elif nectar > 0:
		nectar_desc = "Trickle"
		nectar_color = C_MUTED
	else:
		nectar_desc = "No nectar"
		nectar_color = C_MUTED

	# Bee bread stores
	var bread_desc: String
	var bread_color: Color = C_TEXT
	var bread_pct: float = float(bee_bread) / denom
	if bread_pct > 0.10:
		bread_desc = "Good pollen"
		bread_color = Color(0.85, 0.60, 0.20)
	elif bread_pct > 0.03:
		bread_desc = "Some pollen"
		bread_color = Color(0.85, 0.60, 0.20)
	elif bee_bread > 0:
		bread_desc = "Low pollen"
		bread_color = C_ACCENT
	else:
		bread_desc = "No pollen"
		bread_color = C_MUTED

	return [
		[brood_desc, "", brood_color],
		[nectar_desc, "", nectar_color],
		[honey_desc, "", honey_color],
		[bread_desc, "", bread_color],
		[hp_desc, "", hp_color],
		[queen_desc, "", queen_color],
		[""],
		["Seen", examined, C_MUTED],
	]

# -- Tier 4: Approximate counts with ranges ------------------------------------

## Builds tier 4 approximate stat rows.
func _build_approximate_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	var denom: float = maxf(float(cells_seen), 1.0)
	var eggs: int    = counts.get(CellStateTransition.S_EGG, 0)
	var larvae: int  = counts.get(CellStateTransition.S_OPEN_LARVA, 0)
	var brood: int   = counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var drones: int  = counts.get(CellStateTransition.S_CAPPED_DRONE, 0)
	var nectar: int  = counts.get(CellStateTransition.S_NECTAR, 0) \
					 + counts.get(CellStateTransition.S_CURING_HONEY, 0)
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
	var bee_bread: int = counts.get(CellStateTransition.S_BEE_BREAD, 0)
	var hp: float    = snap.get("health_score", 100.0)
	var adults: int  = snap.get("total_adults", 0)

	# Brood assessment (percentage of cells seen so far)
	var total_brood := eggs + larvae + brood
	var brood_pct: float = float(total_brood) / denom * 100.0
	var brood_qual: String
	var brood_color: Color = C_TEXT
	if brood_pct > 50.0:
		brood_qual = "good"
		brood_color = C_GOOD
	elif brood_pct > 25.0:
		brood_qual = "fair"
	elif brood_pct > 5.0:
		brood_qual = "sparse"
		brood_color = C_ACCENT
	else:
		brood_qual = "low"
		brood_color = C_DANGER

	# Honey percentage
	var honey_pct: float = float(honey) / denom * 100.0

	# HP range (round to nearest 10)
	var hp_lo: int = int(hp / 10.0) * 10
	var hp_hi: int = hp_lo + 10
	var hp_color: Color
	if hp >= 70.0:
		hp_color = C_GOOD
	elif hp >= 40.0:
		hp_color = C_ACCENT
	else:
		hp_color = C_DANGER

	# Queen grade hint
	var grade: String = snap.get("queen_grade", "?")
	var queen_hint: String
	if grade in ["S", "A"]:
		queen_hint = "Strong gene"
	elif grade in ["B", "C"]:
		queen_hint = "Avg gene"
	else:
		queen_hint = "Weak gene"

	# Sides examined indicator
	var examined: String = "%d/%d" % [_viewed_sides.size(), _total_inspectable_sides()]

	# Nectar assessment (nectar + curing combined)
	var nectar_pct: float = float(nectar) / denom * 100.0
	var nectar_desc: String
	var nectar_color: Color
	if nectar_pct > 15.0:
		nectar_desc = "Heavy"
		nectar_color = Color(0.70, 0.85, 0.40)
	elif nectar_pct > 5.0:
		nectar_desc = "Some"
		nectar_color = Color(0.70, 0.85, 0.40)
	elif nectar_pct > 0.0:
		nectar_desc = "Light"
		nectar_color = C_MUTED
	else:
		nectar_desc = "None"
		nectar_color = C_MUTED

	# Bee bread assessment
	var bread_pct: float = float(bee_bread) / denom * 100.0
	var bread_desc: String
	var bread_color: Color
	if bread_pct > 10.0:
		bread_desc = "Good"
		bread_color = Color(0.85, 0.60, 0.20)
	elif bread_pct > 3.0:
		bread_desc = "Some"
		bread_color = Color(0.85, 0.60, 0.20)
	elif bread_pct > 0.0:
		bread_desc = "Low"
		bread_color = C_ACCENT
	else:
		bread_desc = "None"
		bread_color = C_MUTED

	return [
		["Brood", "~%s (%s)" % [_approx_count(total_brood), brood_qual], brood_color],
		["Drones", "~%s" % _approx_count(drones)],
		["Nectar", nectar_desc, nectar_color],
		["Honey", "~%d%%" % roundi(honey_pct)],
		["Bread", bread_desc, bread_color],
		["Adults", "~%s" % _approx_k(adults)],
		["HP", "%d-%d%%" % [hp_lo, hp_hi], hp_color],
		[queen_hint, "", C_TEXT],
		["Seen", examined, C_MUTED],
	]

# -- Tier 5: Master -- dynamic %s per frame, queen rank, qualitative pops ------

## Builds tier 5 exact stat rows.
func _build_exact_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	# Accumulated percentages (grow as the player inspects more frame sides)
	var denom: float = maxf(float(cells_seen), 1.0)
	var eggs: int    = counts.get(CellStateTransition.S_EGG, 0)
	var larvae: int  = counts.get(CellStateTransition.S_OPEN_LARVA, 0)
	var capped: int  = counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var nectar: int  = counts.get(CellStateTransition.S_NECTAR, 0)
	var curing: int  = counts.get(CellStateTransition.S_CURING_HONEY, 0)
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
	var bee_bread: int = counts.get(CellStateTransition.S_BEE_BREAD, 0)

	var egg_pct: String   = "%.1f%%" % (float(eggs)   / denom * 100.0)
	var larva_pct: String = "%.1f%%" % (float(larvae)  / denom * 100.0)
	var cap_pct: String   = "%.1f%%" % (float(capped)  / denom * 100.0)
	var nectar_pct: String = "%.1f%%" % (float(nectar) / denom * 100.0)
	var curing_pct: String = "%.1f%%" % (float(curing) / denom * 100.0)
	var honey_pct: String = "%.1f%%" % (float(honey)   / denom * 100.0)
	var bread_pct: String = "%.1f%%" % (float(bee_bread) / denom * 100.0)

	# Queen ranking
	var grade: String   = snap.get("queen_grade", "?")
	var species: String = snap.get("queen_species", "?")
	var queen_str: String = "Q: %s/%s" % [grade, species.substr(0, 3)]

	# Population data for qualitative assessments
	var nurses: int   = snap.get("nurse_count", 0)
	var workers: int  = snap.get("house_count", 0) + snap.get("forager_count", 0)
	var drones: int   = snap.get("drone_count", 0)
	var hp: float     = snap.get("health_score", 100.0)

	# Nurse assessment (relative to brood needs)
	var brood_total: int = eggs + larvae + capped
	var nurse_desc: String
	var nurse_color: Color
	if brood_total == 0 or nurses > brood_total:
		nurse_desc = "Nurses: Good"
		nurse_color = C_GOOD
	elif float(nurses) / maxf(float(brood_total), 1.0) > 0.5:
		nurse_desc = "Nurses: OK"
		nurse_color = C_TEXT
	elif nurses > 0:
		nurse_desc = "Nurses: Low"
		nurse_color = C_ACCENT
	else:
		nurse_desc = "Nurses: None"
		nurse_color = C_DANGER

	# Worker assessment (house bees + foragers)
	var worker_desc: String
	var worker_color: Color
	if workers > 15000:
		worker_desc = "Workers: Strong"
		worker_color = C_GOOD
	elif workers > 5000:
		worker_desc = "Workers: OK"
		worker_color = C_TEXT
	elif workers > 1000:
		worker_desc = "Workers: Low"
		worker_color = C_ACCENT
	else:
		worker_desc = "Workers: Weak"
		worker_color = C_DANGER

	# Drone assessment
	var drone_desc: String
	var drone_color: Color
	if drones > 500:
		drone_desc = "Drones: Many"
		drone_color = C_TEXT
	elif drones > 100:
		drone_desc = "Drones: OK"
		drone_color = C_GOOD
	elif drones > 0:
		drone_desc = "Drones: Few"
		drone_color = C_MUTED
	else:
		drone_desc = "Drones: None"
		drone_color = C_MUTED

	# Health color
	var hp_color: Color
	if hp >= 70.0:
		hp_color = C_GOOD
	elif hp >= 40.0:
		hp_color = C_ACCENT
	else:
		hp_color = C_DANGER

	# Sides examined indicator
	var examined: String = "%d/%d" % [_viewed_sides.size(), _total_inspectable_sides()]

	return [
		["Eggs", egg_pct, C_TEXT],
		["Larvae", larva_pct, C_TEXT],
		["Capped", cap_pct, C_TEXT],
		["Nectar", nectar_pct, Color(0.70, 0.85, 0.40)],
		["Curing", curing_pct, Color(0.90, 0.75, 0.30)],
		["Honey", honey_pct, C_TEXT],
		["Bread", bread_pct, Color(0.85, 0.60, 0.20)],
		["HP", "%.0f%%" % hp, hp_color],
		[nurse_desc, "", nurse_color],
		[worker_desc, "", worker_color],
		[drone_desc, "", drone_color],
		[queen_str, "", C_ACCENT],
		["Seen", examined, C_MUTED],
	]

# -- Dev Mode: full accurate stats, no progressive accumulation needed ---------

## Count every cell across all frames and both sides for the entire hive.
func _get_full_hive_counts() -> Dictionary:
	var totals: Dictionary = {}
	if _sim == null or _sim.boxes.is_empty():
		return totals
	for frame in _current_box().frames:
		for side in [0, 1]:
			var sc: Dictionary = CellStateTransition.full_count_side(frame, side)
			for state_id in sc:
				var prev: int = totals.get(state_id, 0)
				totals[state_id] = prev + int(sc[state_id])
	return totals

## Build the dev-mode stat rows: raw counts, exact percentages, mite count, etc.
func _build_dev_rows(counts: Dictionary, snap: Dictionary) -> Array:
	var frame_count: int = _current_box().frames.size() if _current_box() != null else 0
	var total: float = float(TOTAL_CELLS * frame_count * 2)  # all frames x both sides

	var eggs: int    = counts.get(CellStateTransition.S_EGG, 0)
	var larvae: int  = counts.get(CellStateTransition.S_OPEN_LARVA, 0)
	var capped: int  = counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var nectar: int  = counts.get(CellStateTransition.S_NECTAR, 0)
	var curing: int  = counts.get(CellStateTransition.S_CURING_HONEY, 0)
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
	var bee_bread: int = counts.get(CellStateTransition.S_BEE_BREAD, 0)
	var varroa: int  = counts.get(CellStateTransition.S_VARROA, 0)
	var hp: float    = snap.get("health_score", 100.0)
	var mites: float = snap.get("mite_count", 0.0)

	var hp_color: Color
	if hp >= 70.0:
		hp_color = C_GOOD
	elif hp >= 40.0:
		hp_color = C_ACCENT
	else:
		hp_color = C_DANGER

	var mite_color: Color = C_DANGER if varroa > 50 else C_TEXT

	var grade: String   = snap.get("queen_grade", "?")
	var species: String = snap.get("queen_species", "?")

	# -- Tomorrow forecast (dev only) --
	var forecast: Dictionary = _sim.forecast_tomorrow()
	var f_wax: int      = forecast.get("wax_cells", 0)
	var f_bb: int       = forecast.get("bee_bread_cells", 0)
	var f_honey: int    = forecast.get("honey_cells", 0)
	var f_eggs: int     = forecast.get("eggs_laid", 0)

	var bb_color: Color = C_GOOD if f_bb > 0 else (C_DANGER if f_bb < 0 else C_MUTED)
	var honey_fc: Color = C_GOOD if f_honey > 0 else C_MUTED

	return [
		["Eggs", "%d (%.1f%%)" % [eggs, float(eggs) / total * 100.0], C_TEXT],
		["Larvae", "%d (%.1f%%)" % [larvae, float(larvae) / total * 100.0], C_TEXT],
		["Capped", "%d (%.1f%%)" % [capped, float(capped) / total * 100.0], C_TEXT],
		["Nectar", "%d (%.1f%%)" % [nectar, float(nectar) / total * 100.0], Color(0.70, 0.85, 0.40)],
		["Curing", "%d (%.1f%%)" % [curing, float(curing) / total * 100.0], Color(0.90, 0.75, 0.30)],
		["Honey", "%d (%.1f%%)" % [honey, float(honey) / total * 100.0], C_TEXT],
		["Bread", "%d (%.1f%%)" % [bee_bread, float(bee_bread) / total * 100.0], Color(0.85, 0.60, 0.20)],
		["Varroa", str(varroa), mite_color],
		["Mites", "%.0f" % mites, mite_color],
		["HP", "%.0f%%" % hp, hp_color],
		["Adults", _fmt_k(snap.get("total_adults", 0)), C_TEXT],
		["Nurses", _fmt_k(snap.get("nurse_count", 0)), C_TEXT],
		["Workers", _fmt_k(snap.get("house_count", 0) + snap.get("forager_count", 0)), C_TEXT],
		["Drones", _fmt_k(snap.get("drone_count", 0)), C_TEXT],
		["Q: %s/%s" % [grade, species.substr(0, 3)], "", C_ACCENT],
		["-- TOMORROW --", "", C_ACCENT],
		["+Wax", str(f_wax), C_GOOD if f_wax > 0 else C_MUTED],
		["+Bread", "%+d" % f_bb, bb_color],
		["+Honey", str(f_honey), honey_fc],
		["+Eggs", str(f_eggs), C_GOOD if f_eggs > 0 else C_MUTED],
	]

# ------------------------------------------------------------------------------
# Mouse Tooltip -- tiered display (GDD S6.1.1)
# ------------------------------------------------------------------------------

## Handles mouse entry into the cell grid.
func _on_grid_mouse_entered() -> void:
	# Tier 1: no tooltip at all
	if _tier < 2:
		return
	if _tooltip_panel:
		_tooltip_panel.visible = true

## Handles mouse exit from the cell grid.
func _on_grid_mouse_exited() -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = false

## Updates the tooltip text based on mouse position.
func _refresh_tooltip() -> void:
	# Tier 1: tooltip never shown
	if _tier < 2:
		return
	if not _tooltip_panel or not _tooltip_panel.visible or _sim == null:
		return
	if _current_box() == null or _frame_idx >= _current_box().frames.size():
		return

	var frame = _current_box().frames[_frame_idx]
	var f_cols: int = frame.grid_cols
	var f_rows: int = frame.grid_rows
	var honey_w: float = float(FrameRenderer.honeycomb_px_w(f_cols))
	var honey_h: float = float(FrameRenderer.honeycomb_px_h(f_rows))
	var cell_h: float = _cell_rect.size.y   # dynamic -- accounts for super/deep

	var mouse_local: Vector2 = _cell_rect.get_local_mouse_position()
	var hx: float = mouse_local.x / float(CELL_AREA_W) * honey_w
	var hy: float = mouse_local.y / cell_h * honey_h
	var row := clampi(int(hy / float(FrameRenderer.HEX_ROW_STEP)), 0, f_rows - 1)
	var x_offset: float = float(FrameRenderer.HEX_ODD_SHIFT) if (row % 2 == 1) else 0.0
	var col := clampi(int((hx - x_offset) / float(FrameRenderer.HEX_COL_STEP)), 0, f_cols - 1)
	var state: int = frame.get_cell(col, row, _current_side)
	var idx := row * f_cols + col

	# Build tooltip text -- players see cell kind only; dev mode gets full debug info
	if GameData.dev_labels_visible:
		var age: int = int(frame.cell_age[idx]) if _current_side == 0 else int(frame.cell_age_b[idx])
		var comb_tag: String = "WAX" if state != 0 else "NO WAX"
		var dist_3d: float = HiveSimulation._cell_3d_dist(_frame_idx, col, row)
		_tooltip.text = "(%d,%d) %s  age %d  [%s]  d3d=%.2f" % [col, row, _state_name(state), age, comb_tag, dist_3d]
	else:
		_tooltip.text = _state_name(state)

	# Position the tooltip panel near the mouse cursor
	var tp := get_viewport().get_mouse_position()
	var tx: float = tp.x + 6
	var ty: float = tp.y - 16
	# Keep within viewport bounds
	if tx + 80 > VP_W:
		tx = tp.x - 80
	ty = clampf(ty, HEADER_H + 2, VP_H - FOOTER_H - 16)
	_tooltip_panel.position = Vector2(tx, ty)

# ------------------------------------------------------------------------------
# Queen Finder Phase 2 -- Bee Overlay Integration
# ------------------------------------------------------------------------------

## Populate bee entities on the current frame. Called on frame/box navigation.
func _populate_bees() -> void:
	if _bee_overlay == null or _sim == null:
		return
	var box: Variant = _current_box()
	if box == null:
		return
	_bee_overlay.populate_frame(_frame_idx, box)

## Convert viewport mouse position to honeycomb canvas coordinates.
## Returns Vector2(-1, -1) if outside the cell display area.
func _viewport_to_canvas(viewport_pos: Vector2) -> Vector2:
	if _bee_rect == null:
		return Vector2(-1.0, -1.0)

	# Use the bee_rect's current position and size (dynamic for deep/super).
	var cell_x: float = _bee_rect.position.x
	var cell_y: float = _bee_rect.position.y
	var cell_w: float = _bee_rect.size.x
	var cell_h: float = _bee_rect.size.y

	var local_x: float = viewport_pos.x - cell_x
	var local_y: float = viewport_pos.y - cell_y

	if local_x < 0.0 or local_x >= cell_w or local_y < 0.0 or local_y >= cell_h:
		return Vector2(-1.0, -1.0)

	# Scale from viewport cell area to honeycomb canvas
	var canvas_x: float = local_x / cell_w * float(BeeOverlay.CANVAS_W)
	var canvas_y: float = local_y / cell_h * float(BeeOverlay.CANVAS_H)
	return Vector2(canvas_x, canvas_y)

## Phase 2 notification: XP scales with difficulty rank.
func _show_queen_notification_phase2(xp_amount: int) -> void:
	# Build tier-appropriate message
	var msg: String = "Queen confirmed!"
	if _tier >= 5:
		var species: String = _sim.last_snapshot.get("queen_species", "?") if _sim != null else "?"
		var grade: String = _sim.last_snapshot.get("queen_grade", "?") if _sim != null else "?"
		msg = "Queen found! %s-grade %s." % [grade, species]
	elif _tier >= 4:
		var grade: String = _sim.last_snapshot.get("queen_grade", "?") if _sim != null else "?"
		if grade in ["S", "A+", "A"]:
			msg = "Queen found! Strong genetics."
		elif grade in ["B", "C"]:
			msg = "Queen found! Average genetics."
		else:
			msg = "Queen found! Weak genetics."
	elif _tier >= 3:
		msg = "Queen found! She looks healthy."
	elif _tier >= 2:
		msg = "Queen found!"

	var nm := get_tree().root.get_node_or_null("NotificationManager")
	if nm and nm.has_method("show_queen_sighting"):
		nm.show_queen_sighting(xp_amount)
		return

	var note := Label.new()
	note.text = "%s +%d XP" % [msg, xp_amount]
	note.add_theme_font_size_override("font_size", 7)
	note.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30, 1.0))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("INTEGER_DIVISION")
	note.position = Vector2(0, VP_H / 2 - 20)
	note.size     = Vector2(VP_W, 14)
	note.z_index  = 30
	var bg := get_child(0)
	bg.add_child(note)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(note.queue_free)

# (Phase 1 queen sighting removed -- replaced by Phase 2 visual search above)

# ------------------------------------------------------------------------------
# Harvest Marking -- [H] marks frames, [Shift+H] marks entire super
# ------------------------------------------------------------------------------

## Calculate capping percentage for the current frame (both sides).
func _calc_frame_capping_pct() -> float:
	var box: Variant = _current_box()
	if box == null or _frame_idx >= box.frames.size():
		return 0.0
	var frame: Variant = box.frames[_frame_idx]
	var capped := 0
	var total_honey := 0
	for side_cells in [frame.cells, frame.cells_b]:
		for i in frame.grid_size:
			var s: int = int(side_cells[i])
			if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
				capped += 1
				total_honey += 1
			elif s == CellStateTransition.S_CURING_HONEY or s == CellStateTransition.S_NECTAR:
				total_honey += 1
	if total_honey == 0:
		return 100.0
	return (float(capped) / float(total_honey)) * 100.0

## Toggle harvest mark on the current frame. Only works on super frames.
func _toggle_frame_harvest_mark() -> void:
	var box: Variant = _current_box()
	if box == null or not box.is_super:
		_show_temp_message("Only super frames can be harvested.")
		return
	if _frame_idx >= box.frames.size():
		return
	var frame: Variant = box.frames[_frame_idx]
	if frame.marked_for_harvest:
		# Unmark
		frame.marked_for_harvest = false
		_show_temp_message("Frame %d unmarked." % (_frame_idx + 1))
	else:
		# Check capping percentage for fermentation warning
		var cap_pct: float = _calc_frame_capping_pct()
		if cap_pct < 80.0:
			_show_fermentation_warning(cap_pct)
			return
		frame.marked_for_harvest = true
		_show_temp_message("Frame %d marked for harvest!" % (_frame_idx + 1))
	_refresh_harvest_overlay()

## Mark all frames in the current super box for harvest.
func _mark_entire_super() -> void:
	var box: Variant = _current_box()
	if box == null or not box.is_super:
		_show_temp_message("Only super frames can be harvested.")
		return
	# Check if already all marked -- if so, unmark all
	var all_marked := true
	for frame in box.frames:
		if not frame.marked_for_harvest:
			all_marked = false
			break
	if all_marked:
		for frame in box.frames:
			frame.marked_for_harvest = false
		_show_temp_message("All frames in super unmarked.")
	else:
		# Check worst capping in the super
		var worst_cap: float = 100.0
		for f_idx in box.frames.size():
			var f: Variant = box.frames[f_idx]
			var fc := 0
			var ft := 0
			for side_cells in [f.cells, f.cells_b]:
				for i in f.grid_size:
					var s: int = int(side_cells[i])
					if s == CellStateTransition.S_CAPPED_HONEY or s == CellStateTransition.S_PREMIUM_HONEY:
						fc += 1
						ft += 1
					elif s == CellStateTransition.S_CURING_HONEY or s == CellStateTransition.S_NECTAR:
						ft += 1
			var pct: float = 100.0 if ft == 0 else (float(fc) / float(ft)) * 100.0
			if pct < worst_cap:
				worst_cap = pct
		if worst_cap < 80.0:
			_show_fermentation_warning(worst_cap, true)
			return
		for frame in box.frames:
			frame.marked_for_harvest = true
		_show_temp_message("All %d frames marked for harvest!" % box.frames.size())
	_refresh_harvest_overlay()

## Variable to track if marking entire super after fermentation confirm
var _pending_mark_super: bool = false

## Show fermentation warning dialog.
func _show_fermentation_warning(cap_pct: float, is_super: bool = false) -> void:
	_pending_mark_super = is_super
	if _ferment_dialog != null:
		_ferment_dialog.queue_free()
	var bg_node := get_child(0)

	# Dark overlay
	_ferment_dialog = Control.new()
	_ferment_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ferment_dialog.z_index = 50
	_ferment_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ferment_dialog.add_child(dim)

	# Warning panel
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.08, 0.04, 0.95)
	panel.size = Vector2(200, 60)
	@warning_ignore("INTEGER_DIVISION")
	panel.position = Vector2((VP_W - 200) / 2, (VP_H - 60) / 2)
	_ferment_dialog.add_child(panel)

	var border := ColorRect.new()
	border.color = C_DANGER
	border.size = Vector2(200, 1)
	border.position = panel.position
	_ferment_dialog.add_child(border)

	var msg: String = "Only %.0f%% capped! Uncapped honey\nhas high moisture and may ferment.\nHarvest anyway?" % cap_pct
	var warn_lbl := _lbl(msg, 5,
		panel.position + Vector2(6, 6), Vector2(188, 30), C_DANGER)
	_ferment_dialog.add_child(warn_lbl)

	var choice_lbl := _lbl("[Y] Harvest Anyway   [N] Wait", 5,
		panel.position + Vector2(6, 44), Vector2(188, 10), C_MUTED)
	choice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ferment_dialog.add_child(choice_lbl)

	bg_node.add_child(_ferment_dialog)

## Player confirmed marking despite low capping.
func _confirm_mark_despite_fermentation() -> void:
	var box: Variant = _current_box()
	if box == null:
		_dismiss_fermentation_warning()
		return
	if _pending_mark_super:
		for frame in box.frames:
			frame.marked_for_harvest = true
		_show_temp_message("All frames marked (fermentation risk!).")
	else:
		if _frame_idx < box.frames.size():
			box.frames[_frame_idx].marked_for_harvest = true
		_show_temp_message("Frame %d marked (fermentation risk!)." % (_frame_idx + 1))
	_dismiss_fermentation_warning()
	_refresh_harvest_overlay()

## Dismisses the fermentation warning dialog.
func _dismiss_fermentation_warning() -> void:
	if _ferment_dialog:
		_ferment_dialog.queue_free()
		_ferment_dialog = null
	_pending_mark_super = false

## Update the gold overlay and label to reflect current frame's mark state.
func _refresh_harvest_overlay() -> void:
	var box: Variant = _current_box()
	if box == null or _frame_idx >= box.frames.size():
		if _harvest_mark_rect:
			_harvest_mark_rect.visible = false
		if _harvest_label:
			_harvest_label.visible = false
		return

	var frame: Variant = box.frames[_frame_idx]
	var is_super: bool = box.is_super

	if _harvest_mark_rect:
		_harvest_mark_rect.visible = frame.marked_for_harvest

	if _harvest_label and is_super:
		var cap_pct: float = _calc_frame_capping_pct()
		var cap_color: Color
		var cap_icon: String
		if cap_pct >= 80.0:
			cap_color = C_CAP_GREEN
			cap_icon = "Ready"
		elif cap_pct >= 60.0:
			cap_color = C_CAP_YELLOW
			cap_icon = "Wait"
		else:
			cap_color = C_CAP_RED
			cap_icon = "Risk"
		var mark_str: String = " [MARKED]" if frame.marked_for_harvest else ""
		_harvest_label.text = "Cap: %.0f%% %s%s" % [cap_pct, cap_icon, mark_str]
		_harvest_label.add_theme_color_override("font_color", cap_color)
		_harvest_label.visible = true
	elif _harvest_label:
		_harvest_label.visible = false

## Show a temporary notification message on the overlay.
func _show_temp_message(msg: String) -> void:
	var bg_node := get_child(0)
	var note := Label.new()
	note.text = msg
	note.add_theme_font_size_override("font_size", 6)
	note.add_theme_color_override("font_color", C_ACCENT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	@warning_ignore("INTEGER_DIVISION")
	note.position = Vector2(0, VP_H / 2 + 20)
	note.size = Vector2(VP_W, 10)
	note.z_index = 30
	bg_node.add_child(note)
	get_tree().create_timer(2.0).timeout.connect(note.queue_free)

# ------------------------------------------------------------------------------
# Harvest shortcut from inside the overlay
# ------------------------------------------------------------------------------

## Harvests frames marked from the inspection view.
func _harvest_from_overlay() -> void:
	if not _hive or not _hive.has_method("harvest_honey"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var amount: int = roundi(_hive.harvest_honey())
	if amount > 0:
		player.add_item(GameData.ITEM_RAW_HONEY, amount)
		GameData.deduct_energy(5.0)
		_refresh_stats()
		var nm := get_tree().root.get_node_or_null("NotificationManager")
		if nm and nm.has_method("show_harvest"):
			nm.show_harvest(amount)
	else:
		var bg := get_child(0)
		var hint := Label.new()
		hint.text = "No honey ready to harvest yet."
		hint.add_theme_font_size_override("font_size", 6)
		hint.add_theme_color_override("font_color", Color(0.75, 0.60, 0.40, 1.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		@warning_ignore("INTEGER_DIVISION")
		hint.position = Vector2(0, VP_H / 2 + 10)
		hint.size = Vector2(VP_W, 10)
		hint.z_index = 30
		bg.add_child(hint)
		get_tree().create_timer(2.0).timeout.connect(hint.queue_free)

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

static func _state_name(s: int) -> String:
	match s:
		0:  return "Foundation"
		1:  return "Empty"
		2:  return "Egg"
		3:  return "Larva"
		4:  return "Capped brood"
		5:  return "Drone brood"
		6:  return "Nectar"
		7:  return "Curing honey"
		8:  return "Honey"
		9:  return "Premium honey"
		10: return "Varroa"
		11: return "AFB"
		12: return "Queen cell"
		13: return "Vacated"
	return "Unknown"

static func _fmt_k(n: int) -> String:
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)

## Approximate a count to the nearest human-friendly round number for tier 4.
static func _approx_count(n: int) -> String:
	if n >= 1000:
		return "%dk" % roundi(float(n) / 1000.0)
	if n >= 100:
		var rounded := roundi(float(n) / 50.0) * 50
		return str(rounded)
	if n >= 10:
		var rounded := roundi(float(n) / 10.0) * 10
		return str(rounded)
	if n > 0:
		return "<%d" % (10 if n < 10 else n)
	return "0"

## Approximate a large number (adults, etc.) for tier 4.
static func _approx_k(n: int) -> String:
	if n >= 10000:
		return "~%dk" % roundi(float(n) / 1000.0)
	if n >= 1000:
		return "~%.0fk" % (roundf(float(n) / 500.0) * 0.5)
	if n >= 100:
		return "~%d" % (roundi(float(n) / 100.0) * 100)
	return "~%d" % n

func _lbl(text: String, font_size: int, pos: Vector2, sz: Vector2,
		color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
