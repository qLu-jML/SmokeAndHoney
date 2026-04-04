# hud.gd - Smoke & Honey In-Game HUD
# Registered as an autoload singleton so it persists across all scenes.
# Builds its own child nodes in _ready(). Legacy scene-placed nodes are hidden.
extends CanvasLayer

# -- Scene-placed node stubs (kept for backward compat, visually hidden) --
@onready var day_label: Label = get_node_or_null("DayLabel")
@onready var time_label: Label = get_node_or_null("TimeLabel")
@onready var resource_label: Label = get_node_or_null("ResourceLabel")
@onready var next_day_button: Button = get_node_or_null("NextDayButton")
@onready var inventory_menu: ColorRect = get_node_or_null("InventoryMenu")
@onready var inventory_label: Label = get_node_or_null("InventoryMenu/PlayerInventoryLabel")
@onready var inventory_grid: GridContainer = get_node_or_null("InventoryMenu/GridContainer")

# -- HUD-built refs --
var _top_bar: ColorRect = null
var _bot_bar: ColorRect = null
var _season_icon: TextureRect = null
var _month_lbl: Label = null
var _day_lbl2: Label = null
var _time_lbl2: Label = null
var _honey_lbl: Label = null
var _money_lbl: Label = null
var _energy_fill: TextureRect = null
var _level_lbl: Label = null
var _xp_fill: TextureRect = null
var _xp_lbl: Label = null
var _standing_lbl: Label = null  # Community standing display
var _smoker_lbl: Label = null    # Smoker status indicator
var _slots: Array = []
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _menu_open: bool = false
var _summary_overlay: ColorRect = null
var _cached_standing: String = ""  # Cache for polling updates
var _cached_smoker_active: bool = false  # Cache for polling updates

# -- Tab-toggle info panel --
var _info_panel: ColorRect = null
var _info_visible: bool = false
var _info_month_lbl: Label = null
var _info_day_lbl: Label = null
var _info_time_lbl: Label = null
var _info_weather_lbl: Label = null
var _info_money_lbl: Label = null
var _info_honey_lbl: Label = null
var _info_level_lbl: Label = null
var _info_xp_fill: TextureRect = null
var _info_xp_lbl: Label = null
var _info_season_icon: TextureRect = null
var _info_energy_lbl: Label = null

# -- Honey energy bar (always visible, upper-left) --
var _honey_energy_bar: Control = null
var _honey_energy_fill: ColorRect = null
var _honey_energy_drip: ColorRect = null
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _honey_energy_pct_lbl: Label = null

# -- Hotbar --
var _hotbar_bar: ColorRect = null
var _hotbar_slots: Array = []
var _active_slot_idx: int = 0
var _active_item_lbl: Label = null
var _slot_icons: Array = []
var _item_textures: Dictionary = {}
var _weather_lbl: Label = null
var _last_time_text: String = ""
var _last_season: String = ""
var _last_weather: String = ""
var _season_textures: Dictionary = {}

# Dev-mode weather labels
var _dev_weather_lbl: Label = null
var _dev_weather_prob_lbl: Label = null

# Dev-mode widget refs
var _dev_panel: ColorRect = null
var _dev_day_btn: Button = null
var _dev_adv_panel: Control = null  # Control container for dev buttons
var _dev_month_advancing: bool = false
var _dev_month_days_left: int = 0
var _dev_month_start_day: int = 0
var _dev_month_start_month: String = ""
var _dev_month_btn: Button = null
var _dev_level_lbl: Label = null
var _dev_day_lbl: Label = null
var _dev_season_lbl: Label = null
var _dev_hives_lbl: Label = null
var _dev_nectar_lbl: Label = null
var _dev_pollen_lbl: Label = null
var _dev_grade_lbl: Label = null
var _dev_roll_lbl: Label = null

# -- Season transition banner --
var _season_banner: Control = null

# -- Layout constants --
const VP_W: int = 320
const VP_H: int = 180
const TOP_H: int = 16
const BOT_H: int = 16
const BOT_Y: int = VP_H - BOT_H
const HOTBAR_H: int = 20
const HOTBAR_Y: int = VP_H - HOTBAR_H
const SLOT_W: int = 16
const SLOT_H: int = 16
const SLOT_GAP: int = 2
const EBAR_W: int = 42
const EBAR_H: int = 5
const XBAR_W: int = 50
const XBAR_H: int = 3

# -- Colors --
const C_TEXT: Color = Color(0.90, 0.85, 0.70, 1.0)
const C_MUTED: Color = Color(0.55, 0.50, 0.40, 1.0)
const C_ACCENT: Color = Color(0.95, 0.78, 0.32, 1.0)
const C_HONEY: Color = Color(0.87, 0.60, 0.10, 1.0)
const C_GOOD: Color = Color(0.55, 0.85, 0.50, 1.0)
const C_DANGER: Color = Color(0.90, 0.35, 0.25, 1.0)

# =============================================================================
# Lifecycle
# =============================================================================

## Initializes the HUD UI and connects to GameData signals.
func _ready() -> void:
	print("HUD _ready() starting")
	# Render above minigame overlays (default layer 1) so toolbar stays visible
	layer = 10
	_load_season_textures()
	_load_item_textures()
	_build_top_bar()
	# Hide top bar by default -- Tab key toggles the info panel instead
	if _top_bar:
		_top_bar.visible = false
	_build_honey_energy_bar()
	_build_info_panel()
	_build_dev_level_widget()

	TimeManager.day_advanced.connect(_on_day_advanced)
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.midnight_reached.connect(_on_midnight_reached)
	TimeManager.season_changed.connect(_on_season_changed)
	GameData.money_changed.connect(_on_money_changed)
	GameData.energy_changed.connect(_on_energy_changed)
	GameData.xp_gained.connect(_on_xp_changed)
	GameData.level_up.connect(_on_level_up)
	GameData.dev_labels_toggled.connect(_on_dev_toggled)
	if WeatherManager:
		WeatherManager.weather_changed.connect(_on_weather_changed)

	if next_day_button:
		next_day_button.pressed.connect(_on_next_day_button_pressed)
		next_day_button.focus_mode = Control.FOCUS_NONE

	_build_hotbar()
	_refresh_all()
	_hide_legacy_nodes()
	print("HUD _ready() completed successfully")

## Updates frame-per-frame animations and state.
## Disconnects all signals when the node is removed from the scene tree.
func _exit_tree() -> void:
	if GameData.money_changed.is_connected(_on_money_changed):
		GameData.money_changed.disconnect(_on_money_changed)
	if GameData.energy_changed.is_connected(_on_energy_changed):
		GameData.energy_changed.disconnect(_on_energy_changed)
	if GameData.xp_gained.is_connected(_on_xp_changed):
		GameData.xp_gained.disconnect(_on_xp_changed)
	if TimeManager.day_advanced.is_connected(_on_day_advanced):
		TimeManager.day_advanced.disconnect(_on_day_advanced)
	if TimeManager.hour_changed.is_connected(_on_hour_changed):
		TimeManager.hour_changed.disconnect(_on_hour_changed)
	if TimeManager.season_changed.is_connected(_on_season_changed):
		TimeManager.season_changed.disconnect(_on_season_changed)
	if WeatherManager and WeatherManager.weather_changed.is_connected(_on_weather_changed):
		WeatherManager.weather_changed.disconnect(_on_weather_changed)
	if GameData.level_up.is_connected(_on_level_up):
		GameData.level_up.disconnect(_on_level_up)
	if TimeManager.midnight_reached.is_connected(_on_midnight_reached):
		TimeManager.midnight_reached.disconnect(_on_midnight_reached)
	if GameData.dev_labels_toggled.is_connected(_on_dev_toggled):
		GameData.dev_labels_toggled.disconnect(_on_dev_toggled)

func _process(_delta: float) -> void:
	# Poll for standing and smoker status updates (called every frame)
	_update_standing()
	_update_smoker_status()

# =============================================================================
# Build HUD bars
# =============================================================================

func _build_top_bar() -> void:
	_top_bar = ColorRect.new()
	_top_bar.name = "TopBar"
	_top_bar.size = Vector2(VP_W, TOP_H)
	_top_bar.position = Vector2.ZERO
	_top_bar.color = Color(0.10, 0.07, 0.03, 0.93)
	_top_bar.z_index = 1
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar)

	var sep = ColorRect.new()
	sep.color = Color(0.80, 0.53, 0.10, 0.55)
	sep.size = Vector2(VP_W, 1)
	sep.position = Vector2(0, TOP_H - 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(sep)

	_season_icon = TextureRect.new()
	_season_icon.size = Vector2(12, 12)
	_season_icon.position = Vector2(2, 2)
	_season_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_season_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(_season_icon)

	_month_lbl = _make_lbl("Quickening", 6, Vector2(16, 4), Vector2(60, 8), C_TEXT)
	_top_bar.add_child(_month_lbl)

	_day_lbl2 = _make_lbl("Day 1", 6, Vector2(78, 4), Vector2(28, 8), C_MUTED)
	_top_bar.add_child(_day_lbl2)

	_top_bar.add_child(_make_lbl(".", 6, Vector2(107, 4), Vector2(6, 8), C_MUTED))

	_time_lbl2 = _make_lbl("6:00 AM", 6, Vector2(114, 4), Vector2(50, 8), C_MUTED)
	_top_bar.add_child(_time_lbl2)

	# Weather indicator (short text, between time and map hint)
	var weather_text: String = "Sunny"
	if WeatherManager:
		weather_text = WeatherManager.get_weather_icon_text()
	_weather_lbl = _make_lbl(weather_text, 5, Vector2(168, 5), Vector2(60, 7), _weather_color())
	_top_bar.add_child(_weather_lbl)

	_top_bar.add_child(_make_lbl("[M] Map", 5, Vector2(VP_W - 34, 5), Vector2(32, 7), C_MUTED))


# =============================================================================
# Honey-Themed Energy Bar (always visible, upper-left)
# =============================================================================

func _build_honey_energy_bar() -> void:
	# Container for the entire energy bar widget
	_honey_energy_bar = Control.new()
	_honey_energy_bar.name = "HoneyEnergyBar"
	_honey_energy_bar.position = Vector2(3, 3)
	_honey_energy_bar.size = Vector2(52, 10)
	_honey_energy_bar.z_index = 5
	_honey_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_honey_energy_bar)

	# Outer border -- dark honey comb edge
	var border = ColorRect.new()
	border.size = Vector2(52, 10)
	border.position = Vector2.ZERO
	border.color = Color(0.40, 0.25, 0.05, 0.95)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_honey_energy_bar.add_child(border)

	# Inner background -- dark honeycomb cell
	var bg = ColorRect.new()
	bg.size = Vector2(50, 8)
	bg.position = Vector2(1, 1)
	bg.color = Color(0.12, 0.08, 0.02, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(bg)

	# Honey fill -- golden amber gradient feel
	_honey_energy_fill = ColorRect.new()
	_honey_energy_fill.size = Vector2(50, 8)
	_honey_energy_fill.position = Vector2(1, 1)
	_honey_energy_fill.color = Color(0.92, 0.65, 0.08, 1.0)
	_honey_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(_honey_energy_fill)

	# Honey highlight stripe (top reflection)
	var highlight = ColorRect.new()
	highlight.size = Vector2(48, 2)
	highlight.position = Vector2(2, 2)
	highlight.color = Color(1.0, 0.88, 0.35, 0.30)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_honey_energy_fill.add_child(highlight)

	# Honey drip at right edge of fill -- tiny 2x3 drip
	_honey_energy_drip = ColorRect.new()
	_honey_energy_drip.size = Vector2(2, 3)
	_honey_energy_drip.position = Vector2(49, 8)
	_honey_energy_drip.color = Color(0.85, 0.55, 0.05, 0.85)
	_honey_energy_drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(_honey_energy_drip)

	# Decorative hex caps on left/right ends (1px wide accents)
	var cap_l = ColorRect.new()
	cap_l.size = Vector2(1, 6)
	cap_l.position = Vector2(1, 2)
	cap_l.color = Color(0.70, 0.45, 0.08, 0.50)
	cap_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(cap_l)

	var cap_r = ColorRect.new()
	cap_r.size = Vector2(1, 6)
	cap_r.position = Vector2(50, 2)
	cap_r.color = Color(0.70, 0.45, 0.08, 0.50)
	cap_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(cap_r)

	# "[Tab]" hint label below the bar
	var tab_hint = _make_lbl("[Tab]", 4, Vector2(0, 11), Vector2(52, 6), Color(0.55, 0.45, 0.25, 0.60))
	tab_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_honey_energy_bar.add_child(tab_hint)

	_refresh_honey_energy()


func _refresh_honey_energy() -> void:
	if not _honey_energy_fill:
		return
	var pct = clampf(GameData.energy / GameData.max_energy, 0.0, 1.0)
	var max_w: float = 50.0
	_honey_energy_fill.size.x = pct * max_w

	# Color shifts: full=golden, mid=amber, low=dark reddish honey
	if pct < 0.20:
		_honey_energy_fill.color = Color(0.65, 0.25, 0.05, 1.0)  # dark burnt honey
	elif pct < 0.45:
		_honey_energy_fill.color = Color(0.80, 0.45, 0.06, 1.0)  # deep amber
	else:
		_honey_energy_fill.color = Color(0.92, 0.65, 0.08, 1.0)  # bright golden honey

	# Position drip at right edge of fill
	if _honey_energy_drip:
		_honey_energy_drip.position.x = 1.0 + pct * max_w - 1.0
		_honey_energy_drip.visible = pct > 0.05 and pct < 0.95


# =============================================================================
# Tab-Toggle Info Panel (time, date, money, etc.)
# =============================================================================

func _build_info_panel() -> void:
	_info_panel = ColorRect.new()
	_info_panel.name = "InfoPanel"
	_info_panel.size = Vector2(140, 62)
	_info_panel.position = Vector2(3, 18)
	_info_panel.color = Color(0.08, 0.06, 0.03, 0.92)
	_info_panel.z_index = 4
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.visible = false
	add_child(_info_panel)

	# Gold border
	var brd_style = StyleBoxFlat.new()
	brd_style.bg_color = Color(0, 0, 0, 0)
	brd_style.draw_center = false
	brd_style.border_color = Color(0.75, 0.50, 0.10, 0.70)
	brd_style.set_border_width_all(1)
	var brd = Panel.new()
	brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brd.add_theme_stylebox_override("panel", brd_style)
	_info_panel.add_child(brd)

	# Row 1: Season icon + Month + Day
	_info_season_icon = TextureRect.new()
	_info_season_icon.size = Vector2(10, 10)
	_info_season_icon.position = Vector2(4, 4)
	_info_season_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info_season_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(_info_season_icon)

	_info_month_lbl = _make_lbl("Quickening", 6, Vector2(16, 4), Vector2(60, 8), C_TEXT)
	_info_panel.add_child(_info_month_lbl)

	_info_day_lbl = _make_lbl("Day 1", 6, Vector2(78, 4), Vector2(30, 8), C_MUTED)
	_info_panel.add_child(_info_day_lbl)

	# Row 2: Time + Weather
	_info_time_lbl = _make_lbl("6:00 AM", 6, Vector2(4, 15), Vector2(55, 8), C_MUTED)
	_info_panel.add_child(_info_time_lbl)

	var w_text: String = "Sunny"
	if WeatherManager:
		w_text = WeatherManager.get_weather_icon_text()
	_info_weather_lbl = _make_lbl(w_text, 5, Vector2(62, 16), Vector2(74, 7), _weather_color())
	_info_panel.add_child(_info_weather_lbl)

	# Divider
	var div = ColorRect.new()
	div.color = Color(0.75, 0.50, 0.10, 0.35)
	div.size = Vector2(132, 1)
	div.position = Vector2(4, 26)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(div)

	# Row 3: Money + Honey
	_info_money_lbl = _make_lbl("$0", 6, Vector2(4, 30), Vector2(40, 8), C_TEXT)
	_info_panel.add_child(_info_money_lbl)

	_info_honey_lbl = _make_lbl("0 lbs honey", 6, Vector2(48, 30), Vector2(60, 8), C_HONEY)
	_info_panel.add_child(_info_honey_lbl)

	# Row 4: Energy text + Level + XP
	_info_energy_lbl = _make_lbl("Energy: 100%", 5, Vector2(4, 41), Vector2(60, 7), C_ACCENT)
	_info_panel.add_child(_info_energy_lbl)

	_info_level_lbl = _make_lbl("Lvl 1", 5, Vector2(68, 41), Vector2(30, 7), C_ACCENT)
	_info_panel.add_child(_info_level_lbl)

	# XP bar in info panel
	var xbg = ColorRect.new()
	xbg.size = Vector2(36, 3)
	xbg.position = Vector2(100, 43)
	xbg.color = Color(0.20, 0.14, 0.05, 0.9)
	xbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(xbg)

	_info_xp_fill = TextureRect.new()
	_info_xp_fill.size = Vector2(0, 3)
	_info_xp_fill.position = Vector2(100, 43)
	_info_xp_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_info_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xfill_path = "res://assets/sprites/ui/xp_bar_fill.png"
	if ResourceLoader.exists(xfill_path):
		_info_xp_fill.texture = load(xfill_path)
	_info_panel.add_child(_info_xp_fill)

	_info_xp_lbl = _make_lbl("", 4, Vector2(100, 47), Vector2(36, 6), C_MUTED)
	_info_panel.add_child(_info_xp_lbl)

	# Hint at bottom
	var hint = _make_lbl("[Tab] to close  |  [M] Map  |  [Z] Sleep", 4, Vector2(4, 54), Vector2(132, 6), Color(0.50, 0.45, 0.35, 0.60))
	_info_panel.add_child(hint)


func _toggle_info_panel() -> void:
	_info_visible = not _info_visible
	if _info_panel:
		_info_panel.visible = _info_visible
	if _info_visible:
		_refresh_info_panel()


func _refresh_info_panel() -> void:
	if not _info_panel or not _info_panel.visible:
		return
	if _info_month_lbl:
		_info_month_lbl.text = TimeManager.current_month_name()
	if _info_day_lbl:
		_info_day_lbl.text = "Day %d" % TimeManager.current_day_of_month()
	if _info_time_lbl:
		_info_time_lbl.text = "%s  %s" % [TimeManager.format_time(), TimeManager.time_of_day_name()]
	if _info_weather_lbl and WeatherManager:
		_info_weather_lbl.text = WeatherManager.get_weather_description()
		_info_weather_lbl.add_theme_color_override("font_color", _weather_color())
	if _info_money_lbl:
		var m = GameData.money
		if m < 1000.0:
			_info_money_lbl.text = "$%.0f" % m
		else:
			_info_money_lbl.text = "$%.1fk" % (m / 1000.0)
	if _info_honey_lbl:
		var player = get_tree().get_first_node_in_group("player") if get_tree() else null
		var cnt = 0
		if player and player.has_method("get_item_count"):
			cnt += player.get_item_count(GameData.ITEM_RAW_HONEY)
			cnt += player.get_item_count(GameData.ITEM_HONEY_JAR)
		_info_honey_lbl.text = "%d lbs honey" % cnt
	if _info_energy_lbl:
		var pct_val = int(clampf(GameData.energy / GameData.max_energy, 0.0, 1.0) * 100.0)
		_info_energy_lbl.text = "Energy: %d%%" % pct_val
	if _info_level_lbl:
		_info_level_lbl.text = "Lvl %d %s" % [GameData.player_level, GameData.get_level_title()]
	if _info_xp_fill:
		var threshold = 0
		if GameData.player_level <= GameData.XP_THRESHOLDS.size():
			threshold = GameData.XP_THRESHOLDS[GameData.player_level - 1]
		var pct = clampf(float(GameData.xp) / float(maxi(threshold, 1)), 0.0, 1.0)
		_info_xp_fill.size.x = pct * 36.0
	if _info_xp_lbl:
		var threshold = 0
		if GameData.player_level <= GameData.XP_THRESHOLDS.size():
			threshold = GameData.XP_THRESHOLDS[GameData.player_level - 1]
		if threshold > 0:
			_info_xp_lbl.text = "%d/%d XP" % [GameData.xp, threshold]
		else:
			_info_xp_lbl.text = "MAX"
	# Season icon
	if _info_season_icon:
		var s = TimeManager.current_season_name().to_lower()
		if _season_textures.has(s):
			_info_season_icon.texture = _season_textures[s]


func _build_bottom_bar() -> void:
	_bot_bar = ColorRect.new()
	_bot_bar.name = "BottomBar"
	_bot_bar.size = Vector2(VP_W, BOT_H)
	_bot_bar.position = Vector2(0, BOT_Y)
	_bot_bar.color = Color(0.10, 0.07, 0.03, 0.93)
	_bot_bar.z_index = 1
	_bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bot_bar)

	var sep = ColorRect.new()
	sep.color = Color(0.80, 0.53, 0.10, 0.55)
	sep.size = Vector2(VP_W, 1)
	sep.position = Vector2(0, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_bar.add_child(sep)

	# Honey icon + count
	_bot_bar.add_child(_make_icon("icon_honey_jar.png", Vector2(2, 1), Vector2(13, 13)))
	_honey_lbl = _make_lbl("0 lbs", 6, Vector2(16, 4), Vector2(28, 8), C_HONEY)
	_bot_bar.add_child(_honey_lbl)

	# Money
	_bot_bar.add_child(_make_lbl("|", 6, Vector2(46, 3), Vector2(5, 10), C_MUTED))
	_bot_bar.add_child(_make_icon("icon_money.png", Vector2(52, 1), Vector2(13, 13)))
	_money_lbl = _make_lbl("$0", 6, Vector2(66, 4), Vector2(32, 8), C_TEXT)
	_bot_bar.add_child(_money_lbl)

	# Energy
	_bot_bar.add_child(_make_lbl("|", 6, Vector2(100, 3), Vector2(5, 10), C_MUTED))
	_bot_bar.add_child(_make_icon("icon_energy.png", Vector2(106, 1), Vector2(13, 13)))

	# Energy bar bg
	var ebg = TextureRect.new()
	ebg.position = Vector2(120, 5)
	ebg.size = Vector2(EBAR_W, EBAR_H)
	ebg.stretch_mode = TextureRect.STRETCH_SCALE
	ebg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ebg_path = "res://assets/sprites/ui/energy_bar_bg.png"
	if ResourceLoader.exists(ebg_path):
		ebg.texture = load(ebg_path)
	else:
		var c = ColorRect.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.color = Color(0.20, 0.14, 0.05, 0.9)
		ebg.add_child(c)
	_bot_bar.add_child(ebg)

	# Energy fill
	_energy_fill = TextureRect.new()
	_energy_fill.position = Vector2(120, 5)
	_energy_fill.size = Vector2(EBAR_W, EBAR_H)
	_energy_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var efill = "res://assets/sprites/ui/energy_bar_fill.png"
	if ResourceLoader.exists(efill):
		_energy_fill.texture = load(efill)
	_bot_bar.add_child(_energy_fill)

	# Level badge + XP
	_bot_bar.add_child(_make_lbl("|", 6, Vector2(165, 3), Vector2(5, 10), C_MUTED))
	_bot_bar.add_child(_make_icon("level_badge.png", Vector2(172, 1), Vector2(13, 13)))
	_level_lbl = _make_lbl("1", 6, Vector2(172, 4), Vector2(13, 8), C_ACCENT)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bot_bar.add_child(_level_lbl)

	# XP bar bg
	var xbg = TextureRect.new()
	xbg.position = Vector2(187, 6)
	xbg.size = Vector2(XBAR_W, XBAR_H)
	xbg.stretch_mode = TextureRect.STRETCH_SCALE
	xbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xbg_path = "res://assets/sprites/ui/xp_bar_bg.png"
	if ResourceLoader.exists(xbg_path):
		xbg.texture = load(xbg_path)
	_bot_bar.add_child(xbg)

	_xp_fill = TextureRect.new()
	_xp_fill.position = Vector2(187, 6)
	_xp_fill.size = Vector2(0, XBAR_H)
	_xp_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xfill = "res://assets/sprites/ui/xp_bar_fill.png"
	if ResourceLoader.exists(xfill):
		_xp_fill.texture = load(xfill)
	_bot_bar.add_child(_xp_fill)

	_xp_lbl = _make_lbl("", 5, Vector2(187, 10), Vector2(XBAR_W, 5), C_MUTED)
	_bot_bar.add_child(_xp_lbl)

	# Standing display
	_standing_lbl = _make_lbl("Standing: Neighbor", 5, Vector2(228, 5), Vector2(50, 6), Color(1.0, 0.85, 0.30, 1.0))
	_bot_bar.add_child(_standing_lbl)

	# Smoker status indicator
	_smoker_lbl = _make_lbl("", 5, Vector2(228, 10), Vector2(50, 6), Color(1.0, 0.65, 0.20, 1.0))
	_smoker_lbl.visible = false
	_bot_bar.add_child(_smoker_lbl)

	# Right-side key hints
	_bot_bar.add_child(_make_lbl("[Z] Sleep", 5, Vector2(283, 5), Vector2(35, 6), C_MUTED))

# =============================================================================
# Dev-Mode Level Widget
# =============================================================================

## Create a small fixed-size Button that won't auto-expand inside CanvasLayer.
## We force size by overriding ALL stylebox states with zero-margin StyleBoxFlats.
func _create_dev_button(label: String, pos: Vector2, sz: Vector2,
		border_col: Color, bg_col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 5)
	btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	btn.add_theme_color_override("font_hover_color", border_col)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	# Override every stylebox state so the default theme can't inflate size
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg_col if state != "hover" else bg_col.lightened(0.15)
		if state == "pressed":
			sb.bg_color = bg_col.lightened(0.3)
		if state == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = border_col
		sb.set_border_width_all(1)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, sb)
	btn.z_index = 20
	# Pin the button to an absolute rect via offsets (no anchor stretching)
	btn.anchor_left = 0
	btn.anchor_top = 0
	btn.anchor_right = 0
	btn.anchor_bottom = 0
	btn.offset_left = pos.x
	btn.offset_top = pos.y
	btn.offset_right = pos.x + sz.x
	btn.offset_bottom = pos.y + sz.y
	return btn

func _build_dev_level_widget() -> void:
	# LEFT PANEL: +Day (top) and +Month (below) buttons
	# Use a bare Node container so CanvasLayer layout does not auto-expand it.
	var btn_w: int = 52
	var btn_h: int = 14
	var gap: int = 3
	var base_y: int = 20  # just below energy bar

	_dev_adv_panel = Control.new()
	_dev_adv_panel.name = "DevAdvPanel"
	_dev_adv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev_adv_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dev_adv_panel)

	# Helper: create a fixed-size dev button as a ColorRect + Label combo
	# (avoids Button auto-sizing issues inside CanvasLayer)
	_dev_day_btn = _create_dev_button("+ Day", Vector2(2, base_y),
		Vector2(btn_w, btn_h), C_ACCENT, Color(0.15, 0.10, 0.05, 0.95))
	_dev_day_btn.pressed.connect(_on_dev_advance_day)
	_dev_adv_panel.add_child(_dev_day_btn)

	_dev_month_btn = _create_dev_button("+ Month", Vector2(2, base_y + btn_h + gap),
		Vector2(btn_w, btn_h), Color(0.95, 0.65, 0.20), Color(0.18, 0.10, 0.02, 0.95))
	_dev_month_btn.pressed.connect(_on_dev_advance_month)
	_dev_adv_panel.add_child(_dev_month_btn)

	# Sync visibility
	_dev_day_btn.visible = GameData.dev_labels_visible
	_dev_month_btn.visible = GameData.dev_labels_visible

	# RIGHT PANEL: stat box (expanded for weather info)
	var panel_w = 78
	var panel_h = 116
	_dev_panel = ColorRect.new()
	_dev_panel.color = Color(0.15, 0.10, 0.05, 0.92)
	_dev_panel.size = Vector2(panel_w, panel_h)
	_dev_panel.position = Vector2(VP_W - panel_w - 2, TOP_H + 2)
	_dev_panel.z_index = 20
	_dev_panel.visible = GameData.dev_labels_visible
	_dev_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dev_panel)

	# Border
	var border = ColorRect.new()
	border.color = C_ACCENT
	border.size = Vector2(panel_w, panel_h)
	border.position = Vector2.ZERO
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev_panel.add_child(border)

	var inner = ColorRect.new()
	inner.color = Color(0.15, 0.10, 0.05, 0.95)
	inner.size = Vector2(panel_w - 2, panel_h - 2)
	inner.position = Vector2(1, 1)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(inner)

	# Row 1: Level controls
	var prefix = _make_lbl("Lvl", 5, Vector2(3, 2), Vector2(14, 10), C_MUTED)
	inner.add_child(prefix)

	_dev_level_lbl = _make_lbl(str(GameData.player_level), 6, Vector2(18, 1), Vector2(14, 10), C_ACCENT)
	_dev_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_dev_level_lbl)

	var title_lbl = _make_lbl(GameData.get_level_title(), 4, Vector2(32, 3), Vector2(44, 8), C_TEXT)
	title_lbl.name = "DevTitleLbl"
	inner.add_child(title_lbl)

	var btn_down = Button.new()
	btn_down.text = "-"
	btn_down.position = Vector2(1, 1)
	btn_down.size = Vector2(10, 10)
	btn_down.add_theme_font_size_override("font_size", 6)
	btn_down.focus_mode = Control.FOCUS_NONE
	btn_down.flat = true
	btn_down.pressed.connect(_on_dev_level_down)
	inner.add_child(btn_down)

	var btn_up = Button.new()
	btn_up.text = "+"
	btn_up.position = Vector2(panel_w - 14, 1)
	btn_up.size = Vector2(10, 10)
	btn_up.add_theme_font_size_override("font_size", 6)
	btn_up.focus_mode = Control.FOCUS_NONE
	btn_up.flat = true
	btn_up.pressed.connect(_on_dev_level_up)
	inner.add_child(btn_up)

	# Divider 1
	var div1 = ColorRect.new()
	div1.color = C_ACCENT
	div1.size = Vector2(panel_w - 6, 1)
	div1.position = Vector2(2, 13)
	div1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(div1)

	# Row 2: Day + Season
	_dev_day_lbl = _make_lbl("Day %d" % TimeManager.current_day, 5, Vector2(3, 15), Vector2(34, 10), C_MUTED)
	_dev_day_lbl.name = "DevDayLbl"
	inner.add_child(_dev_day_lbl)

	_dev_season_lbl = _make_lbl(TimeManager.current_season_name(), 4, Vector2(3, 25), Vector2(panel_w - 6, 8), C_TEXT)
	_dev_season_lbl.name = "DevSeasonLbl"
	inner.add_child(_dev_season_lbl)

	# Divider 2
	var div2 = ColorRect.new()
	div2.color = C_ACCENT
	div2.size = Vector2(panel_w - 6, 1)
	div2.position = Vector2(2, 35)
	div2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(div2)

	# Row 3: Zone stats
	var hive_count: int = get_tree().get_nodes_in_group("hive").size()
	_dev_hives_lbl = _make_lbl("Hives: %d" % hive_count, 4, Vector2(3, 37), Vector2(panel_w - 6, 8), C_MUTED)
	_dev_hives_lbl.name = "DevHivesLbl"
	inner.add_child(_dev_hives_lbl)

	var nu_val: int = _get_zone_nectar_units()
	_dev_nectar_lbl = _make_lbl("NU: %d" % nu_val, 4, Vector2(3, 47), Vector2(panel_w - 6, 8), C_MUTED)
	_dev_nectar_lbl.name = "DevNectarLbl"
	inner.add_child(_dev_nectar_lbl)

	var pu_val: int = _get_zone_pollen_units()
	_dev_pollen_lbl = _make_lbl("PU: %d" % pu_val, 4, Vector2(3, 57), Vector2(panel_w - 6, 8), C_MUTED)
	_dev_pollen_lbl.name = "DevPollenLbl"
	inner.add_child(_dev_pollen_lbl)

	var month_grade: String = _get_month_grade()
	_dev_grade_lbl = _make_lbl("Month: %s" % month_grade, 4, Vector2(3, 67), Vector2(panel_w - 6, 8), _grade_color(month_grade))
	_dev_grade_lbl.name = "DevGradeLbl"
	inner.add_child(_dev_grade_lbl)

	var roll_grade: String = _get_season_roll()
	_dev_roll_lbl = _make_lbl("Season: %s" % roll_grade, 4, Vector2(3, 77), Vector2(panel_w - 6, 8), _grade_color(roll_grade))
	_dev_roll_lbl.name = "DevRollLbl"
	inner.add_child(_dev_roll_lbl)

	# Divider 3 (weather section)
	var div3 = ColorRect.new()
	div3.color = C_ACCENT
	div3.size = Vector2(panel_w - 6, 1)
	div3.position = Vector2(2, 87)
	div3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(div3)

	# Weather state + tomorrow's probabilities
	var w_text: String = "W: Sunny"
	if WeatherManager:
		w_text = "W: %s" % WeatherManager.current_weather
	_dev_weather_lbl = _make_lbl(w_text, 4, Vector2(3, 89), Vector2(panel_w - 6, 8), Color(0.50, 0.65, 0.85))
	_dev_weather_lbl.name = "DevWeatherLbl"
	inner.add_child(_dev_weather_lbl)

	var prob_text: String = _get_weather_probability_text()
	_dev_weather_prob_lbl = _make_lbl(prob_text, 3, Vector2(3, 99), Vector2(panel_w - 6, 14), C_MUTED)
	_dev_weather_prob_lbl.name = "DevWeatherProbLbl"
	_dev_weather_prob_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner.add_child(_dev_weather_prob_lbl)


func _on_dev_level_down() -> void:
	var new_lvl = maxi(GameData.player_level - 1, 1)
	GameData.set_level_debug(new_lvl)
	_refresh_dev_widget()
	_refresh_level(new_lvl)
	_refresh_xp()


func _on_dev_level_up() -> void:
	var new_lvl = mini(GameData.player_level + 1, 5)
	GameData.set_level_debug(new_lvl)
	_refresh_dev_widget()
	_refresh_level(new_lvl)
	_refresh_xp()


func _on_dev_advance_day() -> void:
	# NOTE: Intentionally does NOT save.  Dev mode day-advance is for rapid
	# testing only -- saving here would overwrite the player's real save state.
	_dev_sim_one_day()
	_refresh_all()
	_refresh_dev_widget()


func _on_dev_advance_month() -> void:
	# Advance 28 days (one full in-game month) with full simulation each day.
	# Uses a Timer node to spread days across real frames so all signal handlers
	# (weather, flowers, hive ticks, notifications) can process cleanly.
	# Does NOT save -- dev testing only.
	if _dev_month_advancing:
		return  # already in progress
	_dev_month_advancing = true
	_dev_month_days_left = 28
	_dev_month_start_day = TimeManager.current_day
	_dev_month_start_month = TimeManager.current_month_name()
	if _dev_month_btn:
		_dev_month_btn.text = "28..."
		_dev_month_btn.disabled = true
	# Create a one-shot Timer that fires every 0.05s (total ~1.4s for 28 days)
	var timer = Timer.new()
	timer.name = "DevMonthTimer"
	timer.wait_time = 0.05
	timer.one_shot = false
	timer.timeout.connect(_dev_month_tick.bind(timer))
	add_child(timer)
	timer.start()


func _dev_sim_one_day() -> void:
	# Run one full day of simulation -- shared by +Day and +Month buttons.
	for h in get_tree().get_nodes_in_group("hive"):
		if h.has_method("advance_day"):
			h.advance_day()
	for fl in get_tree().get_nodes_in_group("flowers"):
		if fl.has_method("advance_day_with_global"):
			fl.advance_day_with_global(TimeManager.current_day + 1)
	if _summary_overlay and is_instance_valid(_summary_overlay):
		_summary_overlay.queue_free()
		_summary_overlay = null
	TimeManager.start_new_day()
	GameData.full_restore_energy()


func _dev_month_tick(timer: Timer) -> void:
	# Process one day per timer tick. Gives the engine a real frame between days.
	if _dev_month_days_left <= 0:
		timer.stop()
		timer.queue_free()
		_dev_month_finish()
		return
	_dev_sim_one_day()
	_dev_month_days_left -= 1
	if _dev_month_btn:
		_dev_month_btn.text = "%d..." % _dev_month_days_left
	_refresh_dev_widget()
	if _dev_month_days_left <= 0:
		timer.stop()
		timer.queue_free()
		_dev_month_finish()


func _dev_month_finish() -> void:
	_dev_month_advancing = false
	if _dev_month_btn:
		_dev_month_btn.text = "+ Month"
		_dev_month_btn.disabled = false
	_refresh_all()
	_refresh_dev_widget()
	var end_month: String = TimeManager.current_month_name()
	var end_day: int = TimeManager.current_day
	print("[DEV] Advanced 28 days: Day %d (%s) -> Day %d (%s)" % [
		_dev_month_start_day, _dev_month_start_month, end_day, end_month])
	if NotificationManager:
		NotificationManager.notify(
			"Dev: +28 days -> Day %d (%s)" % [end_day, end_month])


## Refreshes visibility when dev mode is toggled.
func _on_dev_toggled(panel_visible: bool) -> void:
	if _dev_panel:
		_dev_panel.visible = panel_visible
	if _dev_day_btn:
		_dev_day_btn.visible = panel_visible
	if _dev_month_btn:
		_dev_month_btn.visible = panel_visible
	# NOTE: next_day_button (scene "NextDayButton") is a legacy test button.
	# Keep it hidden -- the programmatic +Day / +Month buttons replace it.
	if next_day_button:
		next_day_button.visible = false
	_refresh_dev_widget()


func _refresh_dev_widget() -> void:
	if _dev_level_lbl:
		_dev_level_lbl.text = str(GameData.player_level)
	if _dev_day_lbl:
		_dev_day_lbl.text = "Day %d" % TimeManager.current_day
	if _dev_season_lbl:
		_dev_season_lbl.text = "%s - %s" % [TimeManager.current_month_name(), TimeManager.current_season_name()]
	if _dev_panel:
		var title_node = _dev_panel.get_node_or_null("ColorRect/ColorRect/DevTitleLbl")
		if title_node and title_node is Label:
			(title_node as Label).text = GameData.get_level_title()
	if _dev_hives_lbl:
		var hive_count: int = get_tree().get_nodes_in_group("hive").size()
		_dev_hives_lbl.text = "Hives: %d" % hive_count
	if _dev_nectar_lbl:
		var nu_val: int = _get_zone_nectar_units()
		_dev_nectar_lbl.text = "NU: %d" % nu_val
	if _dev_pollen_lbl:
		var pu_val: int = _get_zone_pollen_units()
		_dev_pollen_lbl.text = "PU: %d" % pu_val
	if _dev_grade_lbl:
		var month_grade: String = _get_month_grade()
		_dev_grade_lbl.text = "Month: %s" % month_grade
		_dev_grade_lbl.add_theme_color_override("font_color", _grade_color(month_grade))
	if _dev_roll_lbl:
		var roll_grade: String = _get_season_roll()
		_dev_roll_lbl.text = "Season: %s" % roll_grade
		_dev_roll_lbl.add_theme_color_override("font_color", _grade_color(roll_grade))
	if _dev_weather_lbl and WeatherManager:
		_dev_weather_lbl.text = "W: %s %.0fF" % [WeatherManager.current_weather, WeatherManager.current_temp_f]
	if _dev_weather_prob_lbl:
		_dev_weather_prob_lbl.text = _get_weather_probability_text()

# =============================================================================
# Helpers
# =============================================================================

func _get_month_grade() -> String:
	# Per-month nectar grade based on TimeManager season_factor (0.0-1.0).
	var sf: float = TimeManager.season_factor() if TimeManager.has_method("season_factor") else 0.5
	if sf >= 0.95:
		return "S"
	elif sf >= 0.75:
		return "A"
	elif sf >= 0.55:
		return "B"
	elif sf >= 0.30:
		return "C"
	elif sf >= 0.10:
		return "D"
	return "F"


func _get_season_roll() -> String:
	# Seasonal quality roll from flower_lifecycle_manager (random per-year).
	var flm = get_tree().get_first_node_in_group("flower_lifecycle_manager") if get_tree() else null
	if flm and flm.has_method("get_current_rank"):
		var rank: String = flm.get_current_rank()
		if rank != "" and rank != "?":
			return rank
	return "--"


func _grade_color(grade: String) -> Color:
	var g: String = grade.left(1) if grade.length() > 0 else "?"
	match g:
		"S": return Color(1.00, 0.85, 0.20, 1.0)   # Gold
		"A": return Color(0.55, 0.85, 0.50, 1.0)   # Green
		"B": return Color(0.80, 0.75, 0.60, 1.0)   # Warm neutral
		"C": return Color(0.85, 0.60, 0.25, 1.0)   # Orange
		"D": return Color(0.85, 0.40, 0.25, 1.0)   # Red-orange
		"F": return Color(0.75, 0.25, 0.20, 1.0)   # Red
	return C_MUTED


func _get_weather_probability_text() -> String:
	if not WeatherManager:
		return "No weather data"
	var mi: int = TimeManager.current_month_index()
	if mi < 0 or mi >= WeatherManager.WEATHER_WEIGHTS.size():
		return "?"
	var weights: Array = WeatherManager.WEATHER_WEIGHTS[mi]
	# Collect top 3 most likely weather states
	var pairs: Array = []
	for i in range(mini(weights.size(), WeatherManager.WEATHER_NAMES.size())):
		if float(weights[i]) > 0.01:
			pairs.append([WeatherManager.WEATHER_NAMES[i], float(weights[i]) * 100.0])
	# Sort descending by percentage (index 1)
	pairs.sort_custom(_sort_weather_pairs)
	var result: String = ""
	for j in range(mini(3, pairs.size())):
		if result.length() > 0:
			result += " "
		result += "%s:%d%%" % [str(pairs[j][0]).left(3), int(pairs[j][1])]
	return result


func _sort_weather_pairs(a: Array, b: Array) -> bool:
	return a[1] > b[1]


func _get_zone_nectar_units() -> int:
	var managers = get_tree().get_nodes_in_group("flower_lifecycle_manager")
	var total = 0
	for mgr in managers:
		if mgr.has_method("get_total_zone_nectar"):
			total += mgr.get_total_zone_nectar()
	return total


func _get_zone_pollen_units() -> int:
	var managers = get_tree().get_nodes_in_group("flower_lifecycle_manager")
	var total = 0
	for mgr in managers:
		if mgr.has_method("get_total_zone_pollen"):
			total += mgr.get_total_zone_pollen()
	return total


func _make_icon(fname: String, pos: Vector2, sz: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.position = pos
	icon.size = sz
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = "res://assets/sprites/ui/" + fname
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	return icon


func _make_lbl(text: String, font_size: int, pos: Vector2, sz: Vector2, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _load_season_textures() -> void:
	for s in ["spring", "summer", "fall", "winter"]:
		var p = "res://assets/sprites/ui/icon_season_%s.png" % s
		if ResourceLoader.exists(p):
			_season_textures[s] = load(p)


func _load_item_textures() -> void:
	var ITEM_SPRITE_MAP: Dictionary = {
		GameData.ITEM_RAW_HONEY: "raw_honey.png",
		GameData.ITEM_HONEY_JAR: "honey_jar_standard.png",
		GameData.ITEM_BEESWAX: "beeswax.png",
		GameData.ITEM_POLLEN: "pollen.png",
		GameData.ITEM_SEEDS: "seeds.png",
		GameData.ITEM_FRAMES: "frames.png",
		GameData.ITEM_SUPER_BOX: "super_box.png",
		GameData.ITEM_BEEHIVE: "beehive.png",
		GameData.ITEM_HIVE_STAND: "hive_stand.png",
		GameData.ITEM_DEEP_BODY: "deep_body.png",
		GameData.ITEM_LID: "hive_lid.png",
		GameData.ITEM_TREATMENT_OXALIC: "treatment_oxalic.png",
		GameData.ITEM_TREATMENT_FORMIC: "treatment_formic.png",
		GameData.ITEM_SYRUP_FEEDER: "syrup_feeder.png",
		GameData.ITEM_QUEEN_CAGE: "queen_cage.png",
		GameData.ITEM_HIVE_TOOL: "hive_tool.png",
		GameData.ITEM_PACKAGE_BEES: "package_bees.png",
		GameData.ITEM_DEEP_BOX: "deep_box.png",
		GameData.ITEM_QUEEN_EXCLUDER: "queen_excluder.png",
		GameData.ITEM_FULL_SUPER: "full_super.png",
		GameData.ITEM_JAR: "jar.png",
		GameData.ITEM_HONEY_BULK: "honey_bulk.png",
		GameData.ITEM_FERMENTED_HONEY: "fermented_honey.png",
		GameData.ITEM_CHEST: "chest.png",
		GameData.ITEM_SUGAR_SYRUP: "sugar_syrup.png",
		GameData.ITEM_GLOVES: "gloves.png",
		GameData.ITEM_BUCKET_GRIP: "bucket_grip.png",
		GameData.ITEM_HONEY_BUCKET: "honey_bucket.png",
		GameData.ITEM_COMB_SCRAPER: "uncapping_knife.png",
		GameData.ITEM_SMOKER: "smoker.png",
		GameData.ITEM_SWARM_TRAP: "swarm_trap.png",
		GameData.ITEM_SCRAPED_SUPER: "scraped_super.png",
		GameData.ITEM_FEEDER_BUCKET: "barrel_feeder.png",
		GameData.ITEM_LOGS: "logs.png",
		GameData.ITEM_LUMBER: "lumber.png",
		GameData.ITEM_AXE: "axe.png",
		GameData.ITEM_HAMMER: "hammer.png",
		GameData.ITEM_BEE_SUIT: "bee_suit.png",
		GameData.ITEM_PROPOLIS: "propolis.png",
		GameData.ITEM_WASH_KIT: "wash_kit.png",
	}
	for item_id in ITEM_SPRITE_MAP:
		var p = "res://assets/sprites/items/%s" % ITEM_SPRITE_MAP[item_id]
		if ResourceLoader.exists(p):
			_item_textures[item_id] = load(p)


func _hide_legacy_nodes() -> void:
	if day_label:
		day_label.visible = false
	if time_label:
		time_label.visible = false
	if resource_label:
		resource_label.visible = false
	if next_day_button:
		next_day_button.visible = false

# =============================================================================
# Signal handlers
# =============================================================================

## Updates time display when hour changes.
func _on_hour_changed(_h: float) -> void:
	_refresh_time()
	_refresh_info_panel()

## Updates day/season display when day advances.
func _on_day_advanced(_d: int) -> void:
	_refresh_date()
	_refresh_info_panel()

## Handles midnight event.
func _on_midnight_reached() -> void:
	if GameData.dev_labels_visible:
		_on_dev_advance_day()
	else:
		_show_daily_summary()

## Updates season display when season changes.
func _on_season_changed(s: String) -> void:
	_refresh_season_icon()
	_show_season_banner(s)

## Updates money display when GameData money changes.
func _on_money_changed(_a: float) -> void:
	_refresh_money()
	_refresh_info_panel()

## Updates energy bar when GameData energy changes.
func _on_energy_changed(_a: float) -> void:
	_refresh_energy()

func _on_xp_changed(_a: int, _t: int) -> void:
	_refresh_xp()

## Shows level-up notification.
func _on_level_up(l: int) -> void:
	_refresh_level(l)

## Updates weather display when weather changes.
func _on_weather_changed(_w: String) -> void:
	_refresh_weather()
	_refresh_info_panel()

# =============================================================================
# Refresh
# =============================================================================

func _refresh_all() -> void:
	_refresh_date()
	_refresh_time()
	_refresh_season_icon()
	_refresh_weather()
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player.has_method("update_hud_inventory"):
		player.update_hud_inventory()


func _refresh_date() -> void:
	if _month_lbl:
		_month_lbl.text = TimeManager.current_month_name()
	if _day_lbl2:
		_day_lbl2.text = "Day %d" % TimeManager.current_day_of_month()
	if day_label:
		var date_text: String = "Day %d  %s  Y%d" % [TimeManager.current_day_of_month(), TimeManager.current_month_name(), TimeManager.current_year()]
		var holiday: String = TimeManager.get_holiday_name()
		if holiday != "":
			date_text += "  -- %s --" % holiday
		day_label.text = date_text


func _refresh_time() -> void:
	var t = "%s  %s" % [TimeManager.format_time(), TimeManager.time_of_day_name()]
	if t == _last_time_text:
		return
	_last_time_text = t
	if _time_lbl2:
		_time_lbl2.text = t
	if time_label:
		time_label.text = t


func _refresh_season_icon() -> void:
	var s = TimeManager.current_season_name().to_lower()
	if s == _last_season:
		return
	_last_season = s
	if _season_icon and _season_textures.has(s):
		_season_icon.texture = _season_textures[s]


func _show_season_banner(season_name: String) -> void:
	# Clean up any existing banner before showing a new one
	if is_instance_valid(_season_banner):
		_season_banner.queue_free()

	# Pick season-themed colors
	var banner_color: Color = Color(0.10, 0.08, 0.05, 0.88)
	var text_color: Color = Color(0.92, 0.87, 0.72, 1.0)
	match season_name:
		"Spring":
			banner_color = Color(0.10, 0.22, 0.12, 0.88)
			text_color   = Color(0.70, 0.95, 0.60, 1.0)
		"Summer":
			banner_color = Color(0.20, 0.16, 0.04, 0.88)
			text_color   = Color(1.00, 0.90, 0.40, 1.0)
		"Fall":
			banner_color = Color(0.20, 0.10, 0.02, 0.88)
			text_color   = Color(0.95, 0.65, 0.30, 1.0)
		"Winter":
			banner_color = Color(0.08, 0.10, 0.18, 0.88)
			text_color   = Color(0.75, 0.88, 1.00, 1.0)

	const BW: int = 200
	const BH: int = 28
	var bx: float = float(VP_W - BW) / 2.0
	var by: float = float(VP_H) / 2.0 - 14.0

	var panel := Control.new()
	panel.size     = Vector2(BW, BH)
	panel.position = Vector2(bx, by)
	panel.modulate.a = 0.0
	panel.z_index = 90
	add_child(panel)
	_season_banner = panel

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = banner_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.0, 0.0, 0.0, 0.0)
	style.draw_center  = false
	style.border_color = text_color
	style.set_border_width_all(1)
	border.add_theme_stylebox_override("panel", style)
	panel.add_child(border)

	var lbl := Label.new()
	lbl.text = season_name
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	# Fade in, hold, fade out, then free
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.8)
	tw.tween_callback(panel.queue_free)


func _refresh_weather() -> void:
	if not WeatherManager:
		return
	var w: String = WeatherManager.current_weather
	if w == _last_weather:
		return
	_last_weather = w
	if _weather_lbl:
		_weather_lbl.text = WeatherManager.get_weather_description()
		_weather_lbl.add_theme_color_override("font_color", _weather_color())


func _weather_color() -> Color:
	if not WeatherManager:
		return C_MUTED
	match WeatherManager.current_weather:
		"Sunny":    return Color(0.95, 0.85, 0.40, 1.0)  # warm gold
		"Overcast": return Color(0.70, 0.72, 0.75, 1.0)  # gray
		"Rainy":    return Color(0.50, 0.60, 0.78, 1.0)  # blue-gray
		"Windy":    return Color(0.65, 0.80, 0.65, 1.0)  # green-gray
		"Cold":     return Color(0.60, 0.75, 0.90, 1.0)  # icy blue
		"HeatWave": return Color(0.95, 0.60, 0.30, 1.0)  # orange
		"Drought":  return Color(0.85, 0.70, 0.35, 1.0)  # dusty gold
		"Foggy":    return Color(0.75, 0.75, 0.78, 1.0)  # pale gray
	return C_MUTED


func _refresh_honey() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	var cnt = 0
	if player and player.has_method("get_item_count"):
		cnt += player.get_item_count(GameData.ITEM_RAW_HONEY)
		cnt += player.get_item_count(GameData.ITEM_HONEY_JAR)
	if _honey_lbl:
		_honey_lbl.text = "%d lbs" % cnt


func _refresh_money() -> void:
	if _money_lbl:
		var m = GameData.money
		if m < 1000.0:
			_money_lbl.text = "$%.0f" % m
		else:
			_money_lbl.text = "$%.1fk" % (m / 1000.0)
	if resource_label:
		resource_label.text = "$%.2f  E%d%%" % [GameData.money, int(GameData.energy)]


func _refresh_energy() -> void:
	var pct = clampf(GameData.energy / GameData.max_energy, 0.0, 1.0)
	if _energy_fill:
		_energy_fill.size.x = pct * EBAR_W
		if pct < 0.25:
			_energy_fill.modulate = C_DANGER
		elif pct < 0.50:
			_energy_fill.modulate = Color(0.85, 0.45, 0.10, 1.0)
		else:
			_energy_fill.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_refresh_honey_energy()
	_refresh_info_panel()


func _refresh_xp() -> void:
	if not _xp_fill:
		return
	var threshold = 0
	if GameData.player_level <= GameData.XP_THRESHOLDS.size():
		threshold = GameData.XP_THRESHOLDS[GameData.player_level - 1]
	var pct = clampf(float(GameData.xp) / float(maxi(threshold, 1)), 0.0, 1.0)
	_xp_fill.size.x = pct * XBAR_W
	if _xp_lbl:
		if threshold > 0:
			_xp_lbl.text = "%d/%d" % [GameData.xp, threshold]
		else:
			_xp_lbl.text = "MAX"


func _refresh_level(level: int) -> void:
	if _level_lbl:
		_level_lbl.text = str(level)

func _update_standing() -> void:
	var standing_tier: String = GameData.get_community_standing_tier() if GameData and GameData.has_method("get_community_standing_tier") else "Neighbor"
	if _standing_lbl and _cached_standing != standing_tier:
		_standing_lbl.text = "Standing: %s" % standing_tier
		_cached_standing = standing_tier

func _update_smoker_status() -> void:
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	var smoker_active: bool = false
	if player and "_smoker_active" in player:
		smoker_active = player._smoker_active
	if _smoker_lbl and _cached_smoker_active != smoker_active:
		_smoker_lbl.visible = smoker_active
		if smoker_active:
			_smoker_lbl.text = "SMOKED"
		_cached_smoker_active = smoker_active

# =============================================================================
# Input
# =============================================================================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_P, KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_Z:
			_on_next_day_button_pressed()
		KEY_TAB:
			_toggle_info_panel()


func _on_next_day_button_pressed() -> void:
	_show_daily_summary()


func _toggle_pause() -> void:
	var pause = get_tree().get_first_node_in_group("pause_menu")
	if pause and pause.has_method("toggle"):
		pause.toggle()
	else:
		var pm_path = "res://scenes/ui/PauseMenu.tscn"
		if ResourceLoader.exists(pm_path):
			var pm: Node = load(pm_path).instantiate()
			get_tree().current_scene.add_child(pm)

# =============================================================================
# Daily Summary
# =============================================================================

func _show_daily_summary() -> void:
	if _summary_overlay and is_instance_valid(_summary_overlay):
		return

	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_summary_overlay = overlay

	var panel = ColorRect.new()
	panel.color = Color(0.09, 0.07, 0.04, 0.97)
	panel.size = Vector2(180, 130)
	panel.position = Vector2(70, 25)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var ptex = "res://assets/sprites/ui/menu_panel.png"
	if ResourceLoader.exists(ptex):
		var tex = TextureRect.new()
		tex.texture = load(ptex)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex)

	var bsty = StyleBoxFlat.new()
	bsty.bg_color = Color(0, 0, 0, 0)
	bsty.draw_center = false
	bsty.border_color = Color(0.75, 0.60, 0.25, 1.0)
	bsty.set_border_width_all(1)
	var brd = Panel.new()
	brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brd.add_theme_stylebox_override("panel", bsty)
	panel.add_child(brd)

	var title = _make_lbl("*  Day %d Complete  *" % TimeManager.current_day, 8, Vector2(10, 8), Vector2(160, 14), Color(0.95, 0.80, 0.35, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var date_lbl = _make_lbl("%s %d, Year %d - %s" % [TimeManager.current_month_name(), TimeManager.current_day_of_month(), TimeManager.current_year(), TimeManager.current_season_name()], 6, Vector2(10, 22), Vector2(160, 10), Color(0.70, 0.65, 0.55, 1.0))
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(date_lbl)

	# Holiday banner (if today is a holiday)
	var holiday_name: String = TimeManager.get_holiday_name()
	var _holiday_y_offset: int = 0
	if holiday_name != "":
		var h_lbl = _make_lbl("-- %s --" % holiday_name, 7, Vector2(10, 33), Vector2(160, 12), Color(0.95, 0.70, 0.20, 1.0))
		h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(h_lbl)
		_holiday_y_offset = 14

	var div = ColorRect.new()
	div.color = Color(0.75, 0.60, 0.25, 0.40)
	div.size = Vector2(160, 1)
	div.position = Vector2(10, 35 + _holiday_y_offset)
	panel.add_child(div)

	var hive_nodes = get_tree().get_nodes_in_group("hive")
	var hive_count = hive_nodes.size()
	var avg_health = 0.0
	for h in hive_nodes:
		if h.has_node("HiveSimulation"):
			avg_health += h.get_node("HiveSimulation").last_snapshot.get("health_score", 0.0)
	if hive_count > 0:
		avg_health /= float(hive_count)

	var player = get_tree().get_first_node_in_group("player")
	var honey_cnt = 0
	if player and player.has_method("get_item_count"):
		honey_cnt = player.get_item_count(GameData.ITEM_RAW_HONEY) + player.get_item_count(GameData.ITEM_HONEY_JAR)

	var stats = [
		["Balance", "$%.2f" % GameData.money],
		["Energy", "%d / %d" % [int(GameData.energy), int(GameData.max_energy)]],
		["Honey", "%d lbs" % honey_cnt],
		["Hives", str(hive_count)],
	]
	if hive_count > 0:
		stats.append(["Avg HP", "%.0f%%" % avg_health])

	var sy = 42
	for pair in stats:
		var row = _make_lbl("%-12s  %s" % [pair[0], pair[1]], 6, Vector2(16, sy), Vector2(148, 10), Color(0.85, 0.82, 0.75, 1.0))
		panel.add_child(row)
		sy += 12

	@warning_ignore("INTEGER_DIVISION")
	var nm_idx = ((TimeManager.current_day) % TimeManager.YEAR_LENGTH) / TimeManager.MONTH_LENGTH
	var prev = _make_lbl("Tomorrow: Day %d  (%s)" % [TimeManager.current_day + 1, TimeManager.MONTH_NAMES[nm_idx]], 6, Vector2(10, sy + 2), Vector2(160, 10), Color(0.55, 0.65, 0.50, 1.0))
	prev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(prev)

	var btn = Button.new()
	btn.text = "Begin Day %d" % (TimeManager.current_day + 1)
	btn.size = Vector2(100, 16)
	btn.position = Vector2(40, 110)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 7)
	panel.add_child(btn)
	btn.pressed.connect(_on_summary_accepted.bind(overlay))


func _on_summary_accepted(overlay: ColorRect) -> void:
	# Save the game BEFORE advancing -- captures end-of-day state.
	# Dev mode advance_day (G-key / HUD button) intentionally skips saving.
	var ok := SaveManager.save_game()
	if ok:
		print("[HUD] Game saved (bed sleep) -- Day %d" % TimeManager.current_day)
	else:
		push_warning("[HUD] Save failed before day advance!")

	for h in get_tree().get_nodes_in_group("hive"):
		if h.has_method("advance_day"):
			h.advance_day()
	for fl in get_tree().get_nodes_in_group("flowers"):
		if fl.has_method("advance_day_with_global"):
			fl.advance_day_with_global(TimeManager.current_day + 1)
	overlay.queue_free()
	_summary_overlay = null
	TimeManager.start_new_day()
	GameData.full_restore_energy()
	_refresh_all()

# =============================================================================
# Inventory / Hotbar
# =============================================================================

func toggle_menu() -> void:
	pass


func _build_hotbar() -> void:
	_hotbar_bar = ColorRect.new()
	_hotbar_bar.name = "HotbarBar"
	_hotbar_bar.size = Vector2(VP_W, HOTBAR_H)
	_hotbar_bar.position = Vector2(0, HOTBAR_Y)
	_hotbar_bar.color = Color(0.08, 0.06, 0.03, 0.90)
	_hotbar_bar.z_index = 1
	_hotbar_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar_bar)

	var sep = ColorRect.new()
	sep.color = Color(0.80, 0.53, 0.10, 0.40)
	sep.size = Vector2(VP_W, 1)
	sep.position = Vector2(0, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_bar.add_child(sep)

	var total_w = 10 * SLOT_W + 9 * SLOT_GAP
	@warning_ignore("integer_division")
	var start_x = (VP_W - total_w) / 2
	var slot_y = 2

	for i in range(10):
		var sx = start_x + i * (SLOT_W + SLOT_GAP)
		var slot = ColorRect.new()
		slot.size = Vector2(SLOT_W, SLOT_H)
		slot.position = Vector2(sx, slot_y)
		slot.color = Color(0.18, 0.13, 0.05, 1.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var brd = Panel.new()
		brd.set_anchors_preset(Control.PRESET_FULL_RECT)
		brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0, 0, 0, 0)
		sty.draw_center = false
		sty.border_color = Color(0.60, 0.42, 0.12, 1.0)
		sty.set_border_width_all(1)
		brd.add_theme_stylebox_override("panel", sty)
		slot.add_child(brd)

		var icon = TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)

		var cnt_lbl = Label.new()
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cnt_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cnt_lbl.add_theme_font_size_override("font_size", 4)
		cnt_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 1.0))
		cnt_lbl.z_index = 1
		slot.add_child(cnt_lbl)

		_hotbar_bar.add_child(slot)
		_hotbar_slots.append(slot)
		_slot_icons.append(icon)
		_slots.append(slot)

	for i in range(10):
		var sx = start_x + i * (SLOT_W + SLOT_GAP)
		var num = _make_lbl(str((i + 1) % 10), 4, Vector2(sx, slot_y + SLOT_H + 1), Vector2(SLOT_W, 5), C_MUTED)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hotbar_bar.add_child(num)

	# Selected-item label in the empty lower-left corner
	_active_item_lbl = Label.new()
	_active_item_lbl.add_theme_font_size_override("font_size", 5)
	_active_item_lbl.add_theme_color_override("font_color", C_ACCENT)
	_active_item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_active_item_lbl.size = Vector2(68, 10)
	_active_item_lbl.position = Vector2(2, HOTBAR_Y + 5)
	_active_item_lbl.z_index = 2
	_active_item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_active_item_lbl)

	_highlight_active_slot(0)


func set_active_slot(idx: int) -> void:
	_active_slot_idx = clampi(idx, 0, _hotbar_slots.size() - 1)
	_highlight_active_slot(_active_slot_idx)
	# Refresh inventory display so the selected-item label updates
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player.has_method("update_hud_inventory"):
		player.update_hud_inventory()


func _highlight_active_slot(idx: int) -> void:
	for i in range(_hotbar_slots.size()):
		var slot = _hotbar_slots[i]
		var brd: Panel = slot.get_child(0)
		var sty = StyleBoxFlat.new()
		sty.bg_color = Color(0, 0, 0, 0)
		sty.draw_center = false
		if i == idx:
			sty.border_color = C_ACCENT
			sty.set_border_width_all(2)
		else:
			sty.border_color = Color(0.60, 0.42, 0.12, 1.0)
			sty.set_border_width_all(1)
		brd.add_theme_stylebox_override("panel", sty)

	# No active item label to reposition


func update_player_inventory(inv_array: Array = []) -> void:
	_refresh_honey()

	var SLOT_COLORS = {
		GameData.ITEM_RAW_HONEY: Color(0.78, 0.52, 0.08),
		GameData.ITEM_HONEY_JAR: Color(0.85, 0.62, 0.12),
		GameData.ITEM_BEESWAX: Color(0.88, 0.78, 0.28),
		GameData.ITEM_POLLEN: Color(0.88, 0.75, 0.20),
		GameData.ITEM_SEEDS: Color(0.35, 0.55, 0.28),
		GameData.ITEM_FRAMES: Color(0.58, 0.42, 0.18),
		GameData.ITEM_SUPER_BOX: Color(0.52, 0.36, 0.14),
		GameData.ITEM_BEEHIVE: Color(0.48, 0.32, 0.10),
		GameData.ITEM_HIVE_STAND: Color(0.55, 0.38, 0.18),
		GameData.ITEM_DEEP_BODY: Color(0.50, 0.34, 0.14),
		GameData.ITEM_LID: Color(0.44, 0.30, 0.10),
		GameData.ITEM_TREATMENT_OXALIC: Color(0.22, 0.52, 0.60),
		GameData.ITEM_TREATMENT_FORMIC: Color(0.22, 0.42, 0.72),
		GameData.ITEM_SYRUP_FEEDER: Color(0.30, 0.55, 0.65),
		GameData.ITEM_QUEEN_CAGE: Color(0.65, 0.55, 0.12),
		GameData.ITEM_HIVE_TOOL: Color(0.45, 0.40, 0.32),
		GameData.ITEM_PACKAGE_BEES: Color(0.72, 0.62, 0.18),
		GameData.ITEM_DEEP_BOX: Color(0.50, 0.35, 0.15),
		GameData.ITEM_QUEEN_EXCLUDER: Color(0.55, 0.56, 0.58),
		GameData.ITEM_FULL_SUPER: Color(0.75, 0.58, 0.15),
		GameData.ITEM_JAR: Color(0.60, 0.65, 0.70),
		GameData.ITEM_HONEY_BULK: Color(0.72, 0.50, 0.10),
		GameData.ITEM_FERMENTED_HONEY: Color(0.55, 0.35, 0.15),
		GameData.ITEM_CHEST: Color(0.55, 0.38, 0.22),
		GameData.ITEM_GLOVES: Color(0.85, 0.78, 0.60),
		GameData.ITEM_BUCKET_GRIP: Color(0.80, 0.55, 0.15),
		GameData.ITEM_HONEY_BUCKET: Color(0.90, 0.88, 0.82),
	}

	@warning_ignore("unused_variable")
	var SHORT = {
		GameData.ITEM_RAW_HONEY: "Hnny",
		GameData.ITEM_HONEY_JAR: "Jar",
		GameData.ITEM_BEESWAX: "Wax",
		GameData.ITEM_POLLEN: "Plln",
		GameData.ITEM_SEEDS: "Seed",
		GameData.ITEM_FRAMES: "Frm",
		GameData.ITEM_SUPER_BOX: "Supr",
		GameData.ITEM_BEEHIVE: "Hive",
		GameData.ITEM_HIVE_STAND: "Stnd",
		GameData.ITEM_DEEP_BODY: "Body",
		GameData.ITEM_LID: "Lid",
		GameData.ITEM_TREATMENT_OXALIC: "OA",
		GameData.ITEM_TREATMENT_FORMIC: "FA",
		GameData.ITEM_SYRUP_FEEDER: "Feed",
		GameData.ITEM_QUEEN_CAGE: "Qn",
		GameData.ITEM_HIVE_TOOL: "HTol",
		GameData.ITEM_PACKAGE_BEES: "Bees",
		GameData.ITEM_DEEP_BOX: "Deep",
		GameData.ITEM_QUEEN_EXCLUDER: "Excl",
		GameData.ITEM_FULL_SUPER: "Full",
		GameData.ITEM_JAR: "Jar",
		GameData.ITEM_HONEY_BULK: "Bulk",
		GameData.ITEM_FERMENTED_HONEY: "Ferm",
		GameData.ITEM_CHEST: "Chst",
		GameData.ITEM_GLOVES: "Glvs",
		GameData.ITEM_BUCKET_GRIP: "Grip",
		GameData.ITEM_HONEY_BUCKET: "Bckt",
	}

	var LONG_NAME = {
		GameData.ITEM_RAW_HONEY: "Raw Honey",
		GameData.ITEM_HONEY_JAR: "Honey Jar",
		GameData.ITEM_BEESWAX: "Beeswax",
		GameData.ITEM_POLLEN: "Pollen",
		GameData.ITEM_SEEDS: "Seeds",
		GameData.ITEM_FRAMES: "Frames",
		GameData.ITEM_SUPER_BOX: "Super Box",
		GameData.ITEM_BEEHIVE: "Hive (Complete)",
		GameData.ITEM_HIVE_STAND: "Hive Stand",
		GameData.ITEM_DEEP_BODY: "Deep Body",
		GameData.ITEM_LID: "Hive Lid",
		GameData.ITEM_TREATMENT_OXALIC: "Oxalic Acid",
		GameData.ITEM_TREATMENT_FORMIC: "Formic Acid",
		GameData.ITEM_SYRUP_FEEDER: "Syrup Feeder",
		GameData.ITEM_QUEEN_CAGE: "Queen Cage",
		GameData.ITEM_HIVE_TOOL: "Hive Tool",
		GameData.ITEM_PACKAGE_BEES: "Package Bees",
		GameData.ITEM_DEEP_BOX: "Deep Body (expansion)",
		GameData.ITEM_QUEEN_EXCLUDER: "Queen Excluder",
		GameData.ITEM_FULL_SUPER: "Full Honey Super",
		GameData.ITEM_JAR: "Empty Jar",
		GameData.ITEM_HONEY_BULK: "Bulk Honey (5lb)",
		GameData.ITEM_FERMENTED_HONEY: "Fermented Honey",
		GameData.ITEM_CHEST: "Storage Chest",
		GameData.ITEM_GLOVES: "Beekeeping Gloves",
		GameData.ITEM_BUCKET_GRIP: "Bucket Grip",
		GameData.ITEM_HONEY_BUCKET: "Honey Bucket",
	}

	for i in range(_slots.size()):
		if i < inv_array.size() and inv_array[i] != null:
			var item = inv_array[i]
			_slots[i].get_child(2).text = "x%d" % item["count"]
			# Show sprite icon if available, fall back to color fill
			if i < _slot_icons.size() and _item_textures.has(item["item"]):
				_slot_icons[i].texture = _item_textures[item["item"]]
				_slot_icons[i].visible = true
				_slots[i].color = Color(0.12, 0.09, 0.04, 1.0)
			else:
				if i < _slot_icons.size():
					_slot_icons[i].visible = false
				_slots[i].color = SLOT_COLORS.get(item["item"], Color(0.35, 0.28, 0.12))
		else:
			_slots[i].get_child(2).text = ""
			if i < _slot_icons.size():
				_slot_icons[i].visible = false
				_slot_icons[i].texture = null
			_slots[i].color = Color(0.18, 0.13, 0.05, 1.0)

	if _active_item_lbl:
		var active_inv = inv_array[_active_slot_idx] if _active_slot_idx < inv_array.size() else null
		if active_inv != null:
			_active_item_lbl.text = LONG_NAME.get(active_inv["item"], active_inv["item"].capitalize