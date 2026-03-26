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

	# Apply tier visibility
	_apply_tier_visibility()

	_refresh_frame()
	_record_current_side()
	_refresh_stats()
	_populate_bees()

# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	layer = 10

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

	var stat_y := HEADER_H + 2
	for _i in 12:
		var lbl := _lbl("", 5, Vector2(GRID_W + 2, stat_y), Vector2(STATS_W - 4, 12), C_TEXT)
		lbl.clip_text = true
		bg.add_child(lbl)
		_stats_labels.append(lbl)
		stat_y += 12

	# -- Langstroth frame background --------------------------------------------
	var cell_x := FRAME_BAR_L
	var cell_y := HEADER_H + FRAME_BAR_T

	var foundation := ColorRect.new()
	foundation.color    = C_FOUNDATION
	foundation.size     = Vector2(CELL_AREA_W, CELL_AREA_H)
	foundation.position = Vector2(cell_x, cell_y)
	bg.add_child(foundation)

	for wi in 3:
		var wy := cell_y + int((wi + 1) * CELL_AREA_H / 4)
		var wire := ColorRect.new()
		wire.color    = C_WIRE
		wire.size     = Vector2(CELL_AREA_W, 1)
		wire.position = Vector2(cell_x, wy)
		bg.add_child(wire)

	# Top bar
	var bar_top := ColorRect.new()
	bar_top.color    = C_WOOD
	bar_top.size     = Vector2(GRID_W, FRAME_BAR_T)
	bar_top.position = Vector2(0, HEADER_H)
	bg.add_child(bar_top)

	var bar_top_hi := ColorRect.new()
	bar_top_hi.color    = C_WOOD_HI
	bar_top_hi.size     = Vector2(GRID_W, 1)
	bar_top_hi.position = Vector2(0, HEADER_H)
	bg.add_child(bar_top_hi)

	var bar_top_sh := ColorRect.new()
	bar_top_sh.color    = C_WOOD_SH
	bar_top_sh.size     = Vector2(GRID_W, 1)
	bar_top_sh.position = Vector2(0, cell_y - 1)
	bg.add_child(bar_top_sh)

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

	# Bottom bar
	var bar_bot := ColorRect.new()
	bar_bot.color    = C_WOOD
	bar_bot.size     = Vector2(GRID_W, FRAME_BAR_B)
	bar_bot.position = Vector2(0, HEADER_H + GRID_H - FRAME_BAR_B)
	bg.add_child(bar_bot)

	var bar_bot_hi := ColorRect.new()
	bar_bot_hi.color    = C_WOOD_HI
	bar_bot_hi.size     = Vector2(GRID_W, 1)
	bar_bot_hi.position = Vector2(0, HEADER_H + GRID_H - FRAME_BAR_B)
	bg.add_child(bar_bot_hi)

	# Left side bar
	var bar_left := ColorRect.new()
	bar_left.color    = C_WOOD
	bar_left.size     = Vector2(FRAME_BAR_L, CELL_AREA_H)
	bar_left.position = Vector2(0, cell_y)
	bg.add_child(bar_left)

	var bar_left_hi := ColorRect.new()
	bar_left_hi.color    = C_WOOD_HI
	bar_left_hi.size     = Vector2(1, CELL_AREA_H)
	bar_left_hi.position = Vector2(FRAME_BAR_L - 1, cell_y)
	bg.add_child(bar_left_hi)

	# Right side bar
	var bar_right := ColorRect.new()
	bar_right.color    = C_WOOD
	bar_right.size     = Vector2(FRAME_BAR_R, CELL_AREA_H)
	bar_right.position = Vector2(GRID_W - FRAME_BAR_R, cell_y)
	bg.add_child(bar_right)

	var bar_right_sh := ColorRect.new()
	bar_right_sh.color    = C_WOOD_SH
	bar_right_sh.size     = Vector2(1, CELL_AREA_H)
	bar_right_sh.position = Vector2(GRID_W - FRAME_BAR_R, cell_y)
	bg.add_child(bar_right_sh)

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

	_footer_label = _lbl("[A/D] Frame  [F] Flip  [W/S] Box  [Click] Find Queen  [ESC] Close",
		5, Vector2(2, VP_H - FOOTER_H + 2), Vector2(VP_W - 4, 8), C_MUTED)
	bg.add_child(_footer_label)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
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
		KEY_E:
			_harvest_from_overlay()
	get_viewport().set_input_as_handled()

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

func _apply_tier_visibility() -> void:
	# Stats sidebar: hidden at tier 1-2, visible at tier 3+
	var show_stats: bool = _tier >= 3
	if _stats_bg_rect:
		_stats_bg_rect.visible = show_stats
	if _stats_div:
		_stats_div.visible = show_stats
	for lbl in _stats_labels:
		(lbl as Label).visible = show_stats

	# Tooltip: disabled at tier 1 (handled in _on_grid_mouse_entered)

# ------------------------------------------------------------------------------
# Frame Navigation
# ------------------------------------------------------------------------------

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

func _refresh_frame() -> void:
	if _sim == null or _renderer == null:
		return
	var box: Variant = _current_box()
	if box == null or _frame_idx >= box.frames.size():
		return
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

func _build_qualitative_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	var denom: float = maxf(float(cells_seen), 1.0)
	var brood: int = counts.get(CellStateTransition.S_EGG, 0) \
				+ counts.get(CellStateTransition.S_OPEN_LARVA, 0) \
				+ counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var honey: int = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
				   + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
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

	return [
		[brood_desc, "", brood_color],
		[""],
		[honey_desc, "", honey_color],
		[""],
		[hp_desc, "", hp_color],
		[""],
		[queen_desc, "", queen_color],
		[""],
		["Seen", examined, C_MUTED],
	]

# -- Tier 4: Approximate counts with ranges ------------------------------------

func _build_approximate_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	var denom: float = maxf(float(cells_seen), 1.0)
	var eggs: int    = counts.get(CellStateTransition.S_EGG, 0)
	var larvae: int  = counts.get(CellStateTransition.S_OPEN_LARVA, 0)
	var brood: int   = counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var drones: int  = counts.get(CellStateTransition.S_CAPPED_DRONE, 0)
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
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

	return [
		["Brood", "~%s (%s)" % [_approx_count(total_brood), brood_qual], brood_color],
		["Drones", "~%s" % _approx_count(drones)],
		["Honey", "~%d%%" % roundi(honey_pct)],
		[""],
		["Adults", "~%s" % _approx_k(adults)],
		["HP", "%d-%d%%" % [hp_lo, hp_hi], hp_color],
		[""],
		[queen_hint, "", C_TEXT],
		[""],
		["Seen", examined, C_MUTED],
	]

# -- Tier 5: Master -- dynamic %s per frame, queen rank, qualitative pops ------

func _build_exact_rows(counts: Dictionary, snap: Dictionary, cells_seen: int) -> Array:
	# Accumulated percentages (grow as the player inspects more frame sides)
	var denom: float = maxf(float(cells_seen), 1.0)
	var eggs: int    = counts.get(CellStateTransition.S_EGG, 0)
	var larvae: int  = counts.get(CellStateTransition.S_OPEN_LARVA, 0)
	var capped: int  = counts.get(CellStateTransition.S_CAPPED_BROOD, 0)
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)

	var egg_pct: String   = "%.1f%%" % (float(eggs)   / denom * 100.0)
	var larva_pct: String = "%.1f%%" % (float(larvae)  / denom * 100.0)
	var cap_pct: String   = "%.1f%%" % (float(capped)  / denom * 100.0)
	var honey_pct: String = "%.1f%%" % (float(honey)   / denom * 100.0)

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
		["Honey", honey_pct, C_TEXT],
		["HP", "%.0f%%" % hp, hp_color],
		[""],
		[nurse_desc, "", nurse_color],
		[worker_desc, "", worker_color],
		[drone_desc, "", drone_color],
		[queen_str, "", C_ACCENT],
		[""],
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
	var honey: int   = counts.get(CellStateTransition.S_CAPPED_HONEY, 0) \
					 + counts.get(CellStateTransition.S_PREMIUM_HONEY, 0)
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

	return [
		["Eggs", "%d (%.1f%%)" % [eggs, float(eggs) / total * 100.0], C_TEXT],
		["Larvae", "%d (%.1f%%)" % [larvae, float(larvae) / total * 100.0], C_TEXT],
		["Capped", "%d (%.1f%%)" % [capped, float(capped) / total * 100.0], C_TEXT],
		["Honey", "%d (%.1f%%)" % [honey, float(honey) / total * 100.0], C_TEXT],
		["Varroa", str(varroa), mite_color],
		["Mites", "%.0f" % mites, mite_color],
		["HP", "%.0f%%" % hp, hp_color],
		["Adults", _fmt_k(snap.get("total_adults", 0)), C_TEXT],
		["Nurses", _fmt_k(snap.get("nurse_count", 0)), C_TEXT],
		["Workers", _fmt_k(snap.get("house_count", 0) + snap.get("forager_count", 0)), C_TEXT],
		["Drones", _fmt_k(snap.get("drone_count", 0)), C_TEXT],
		["Q: %s/%s" % [grade, species.substr(0, 3)], "", C_ACCENT],
	]

# ------------------------------------------------------------------------------
# Mouse Tooltip -- tiered display (GDD S6.1.1)
# ------------------------------------------------------------------------------

func _on_grid_mouse_entered() -> void:
	# Tier 1: no tooltip at all
	if _tier < 2:
		return
	if _tooltip_panel:
		_tooltip_panel.visible = true

func _on_grid_mouse_exited() -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = false

func _refresh_tooltip() -> void:
	# Tier 1: tooltip never shown
	if _tier < 2:
		return
	if not _tooltip_panel or not _tooltip_panel.visible or _sim == null:
		return
	if _current_box() == null or _frame_idx >= _current_box().frames.size():
		return

	var mouse_local: Vector2 = _cell_rect.get_local_mouse_position()
	var hx: float = mouse_local.x / float(CELL_AREA_W) * float(FrameRenderer.HONEY_PX_W)
	var hy: float = mouse_local.y / float(CELL_AREA_H) * float(FrameRenderer.HONEY_PX_H)
	var row := clampi(int(hy / float(FrameRenderer.HEX_ROW_STEP)), 0, FRAME_ROWS - 1)
	var x_offset: float = float(FrameRenderer.HEX_ODD_SHIFT) if (row % 2 == 1) else 0.0
	var col := clampi(int((hx - x_offset) / float(FrameRenderer.HEX_COL_STEP)), 0, FRAME_COLS - 1)
	var frame = _current_box().frames[_frame_idx]
	var state: int = frame.get_cell(col, row, _current_side)
	var idx := row * FRAME_COLS + col

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

	# The bee_rect is positioned at (FRAME_BAR_L, HEADER_H + FRAME_BAR_T)
	# and sized CELL_AREA_W x CELL_AREA_H in the viewport.
	# The canvas is CANVAS_W x CANVAS_H (1833 x 755) scaled down to fit.
	var cell_x: float = float(FRAME_BAR_L)
	var cell_y: float = float(HEADER_H + FRAME_BAR_T)

	var local_x: float = viewport_pos.x - cell_x
	var local_y: float = viewport_pos.y - cell_y

	if local_x < 0.0 or local_x >= float(CELL_AREA_W) or local_y < 0.0 or local_y >= float(CELL_AREA_H):
		return Vector2(-1.0, -1.0)

	# Scale from viewport cell area to honeycomb canvas
	var canvas_x: float = local_x / float(CELL_AREA_W) * float(BeeOverlay.CANVAS_W)
	var canvas_y: float = local_y / float(CELL_AREA_H) * float(BeeOverlay.CANVAS_H)
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
# Harvest shortcut from inside the overlay
# ------------------------------------------------------------------------------

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
