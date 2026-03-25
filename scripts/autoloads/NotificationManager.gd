# NotificationManager.gd
# -----------------------------------------------------------------------------
# Autoloaded singleton -- global animated toast notifications.
#
# Usage from anywhere:
#   NotificationManager.notify("? Queen confirmed! +15 XP", NotificationManager.T_XP)
#   NotificationManager.notify("? Varroa levels rising!", NotificationManager.T_WARN)
#   NotificationManager.notify("? Harvested 24 lbs honey", NotificationManager.T_HONEY)
#
# Notifications stack vertically (newest at top) and fade out.
# Max 5 visible at once; older ones are dismissed when the stack overflows.
# -----------------------------------------------------------------------------
extends CanvasLayer

# -- Notification types (color themes) ----------------------------------------
const T_DEFAULT := "default"   # amber/neutral
const T_XP      := "xp"        # golden yellow
const T_HONEY   := "honey"     # warm amber
const T_WARN    := "warn"      # muted orange-red
const T_GOOD    := "good"      # muted green
const T_INFO    := "info"      # cool muted blue

# -- Layout constants ----------------------------------------------------------
const VP_W        := 320
const VP_H        := 180
const NOTIF_W     := 160
const NOTIF_H     := 14
const NOTIF_PAD   := 2        # vertical gap between stacked notes
const NOTIF_X     := VP_W - NOTIF_W - 2    # right-aligned with 2px margin
const NOTIF_TOP   := 18       # below HUD top bar
const MAX_VISIBLE := 5

# -- Timing --------------------------------------------------------------------
const SLIDE_IN_TIME  := 0.18  # seconds to slide in from right
const HOLD_TIME      := 2.8   # seconds to remain visible
const FADE_OUT_TIME  := 0.55  # seconds to fade out

# -- Color palette -------------------------------------------------------------
const COLORS := {
	T_DEFAULT: { "bg": Color(0.18, 0.13, 0.05, 0.95), "border": Color(0.82, 0.53, 0.10, 1.0), "text": Color(0.92, 0.87, 0.72, 1.0) },
	T_XP:      { "bg": Color(0.20, 0.16, 0.04, 0.95), "border": Color(0.95, 0.78, 0.18, 1.0), "text": Color(1.00, 0.92, 0.50, 1.0) },
	T_HONEY:   { "bg": Color(0.22, 0.14, 0.04, 0.95), "border": Color(0.87, 0.60, 0.10, 1.0), "text": Color(0.95, 0.80, 0.45, 1.0) },
	T_WARN:    { "bg": Color(0.22, 0.08, 0.04, 0.95), "border": Color(0.85, 0.30, 0.15, 1.0), "text": Color(1.00, 0.70, 0.60, 1.0) },
	T_GOOD:    { "bg": Color(0.06, 0.16, 0.06, 0.95), "border": Color(0.35, 0.72, 0.30, 1.0), "text": Color(0.65, 0.95, 0.60, 1.0) },
	T_INFO:    { "bg": Color(0.06, 0.12, 0.20, 0.95), "border": Color(0.35, 0.60, 0.85, 1.0), "text": Color(0.70, 0.85, 1.00, 1.0) },
}

# -- Active notification tracking ----------------------------------------------
var _active: Array = []   # Array of { panel, tween, slot }

# -- Signals -------------------------------------------------------------------
signal notification_shown(message: String, type: String)

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	layer = 50   # always on top -- above InspectionOverlay (10), PauseMenu (30)
	# Connect to GameData signals so we auto-notify level-ups
	if GameData:
		GameData.level_up.connect(_on_level_up)
		GameData.xp_gained.connect(_on_xp_gained)
	if TimeManager:
		TimeManager.season_changed.connect(_on_season_changed)
		TimeManager.month_changed.connect(_on_month_changed)

# -- Public API ----------------------------------------------------------------

## Show a toast notification.
## @param message  Display text (emoji supported).
## @param type     One of the T_* constants (default: T_DEFAULT).
## @param duration Override hold duration in seconds (0 = use default).
func notify(message: String, type: String = T_DEFAULT, duration: float = 0.0) -> void:
	notification_shown.emit(message, type)

	# Enforce max visible -- dismiss the oldest if needed
	while _active.size() >= MAX_VISIBLE:
		_dismiss_oldest()

	var slot := _active.size()
	var panel := _build_panel(message, type, slot)
	add_child(panel)

	var entry := { "panel": panel, "slot": slot, "done": false }
	_active.append(entry)

	var hold: float = duration if duration > 0.0 else HOLD_TIME
	_animate_in_then_out(entry, hold)

# -- Auto-notifications from signals ------------------------------------------

func _on_level_up(new_level: int) -> void:
	var title := GameData.get_level_title()
	notify("? Level %d -- %s!" % [new_level, title], T_XP, 4.0)

func _on_xp_gained(amount: int, _total: int) -> void:
	# Only show XP toasts for significant gains (?10) to avoid spam
	if amount >= 10:
		notify("+%d XP" % amount, T_XP)

func _on_season_changed(season_name: String) -> void:
	var emoji := { "Spring": "?", "Summer": "??", "Fall": "?", "Winter": "??" }
	notify("%s %s begins" % [emoji.get(season_name, ""), season_name], T_INFO, 4.0)

func _on_month_changed(month_name: String) -> void:
	notify("?  %s" % month_name, T_DEFAULT)

## Show a "Queen confirmed" sighting notification (used by InspectionOverlay).
func show_queen_sighting(xp_amount: int) -> void:
	notify("? Queen confirmed!  +%d XP" % xp_amount, T_XP, 3.5)

## Show a harvest result notification.
func show_harvest(lbs: int) -> void:
	notify("? Harvested %d lbs honey" % lbs, T_HONEY)

## Show a warning (varroa high, colony struggling, etc.)
func show_warning(text: String) -> void:
	notify("?  " + text, T_WARN)

## Show a good-news notification.
func show_success(text: String) -> void:
	notify("?  " + text, T_GOOD)

# -- Panel Builder -------------------------------------------------------------

func _build_panel(message: String, type: String, slot: int) -> Control:
	var theme: Dictionary = COLORS.get(type, COLORS[T_DEFAULT])
	var y_pos := NOTIF_TOP + slot * (NOTIF_H + NOTIF_PAD)

	# Start offscreen to the right, then slide in
	var start_x := float(VP_W) + 4.0

	# Container
	var panel := Control.new()
	panel.name     = "Notif_%d" % Time.get_ticks_msec()
	panel.size     = Vector2(NOTIF_W, NOTIF_H)
	panel.position = Vector2(start_x, y_pos)
	panel.z_index  = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = theme["bg"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	# Border using Panel + StyleBoxFlat
	var border_node := Panel.new()
	border_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color    = Color(0,0,0,0)
	style.draw_center = false
	style.border_color = theme["border"]
	style.set_border_width_all(1)
	border_node.add_theme_stylebox_override("panel", style)
	panel.add_child(border_node)

	# Accent left edge
	var accent := ColorRect.new()
	accent.size = Vector2(2, NOTIF_H)
	accent.position = Vector2(0, 0)
	accent.color = theme["border"]
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	# Text label
	var lbl := Label.new()
	lbl.text = message
	lbl.position = Vector2(5, 2)
	lbl.size = Vector2(NOTIF_W - 7, NOTIF_H - 4)
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", theme["text"])
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_contents = true
	panel.add_child(lbl)

	return panel

# -- Animation -----------------------------------------------------------------

func _animate_in_then_out(entry: Dictionary, hold_time: float) -> void:
	var panel: Control = entry["panel"]
	var slot: int      = entry["slot"]
	var target_x       := float(NOTIF_X)
	var target_y       := float(NOTIF_TOP + slot * (NOTIF_H + NOTIF_PAD))

	# Slide-in tween
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:x", target_x, SLIDE_IN_TIME)
	entry["tween"] = tw

	# Hold then fade-out
	await get_tree().create_timer(SLIDE_IN_TIME + hold_time).timeout
	if not is_instance_valid(panel):
		return
	var fade := create_tween()
	fade.tween_property(panel, "modulate:a", 0.0, FADE_OUT_TIME)
	await fade.finished
	if is_instance_valid(panel):
		panel.queue_free()
	_active.erase(entry)
	_restack()

func _dismiss_oldest() -> void:
	if _active.is_empty():
		return
	var oldest: Dictionary = _active[0]
	var panel: Control = oldest["panel"]
	if is_instance_valid(panel):
		panel.queue_free()
	_active.erase(oldest)

func _restack() -> void:
	# Re-position remaining notifications into their new slots
	for i in _active.size():
		var entry: Dictionary = _active[i]
		entry["slot"] = i
		var panel: Control = entry["panel"]
		if is_instance_valid(panel):
			var target_y := float(NOTIF_TOP + i * (NOTIF_H + NOTIF_PAD))
			var tw := create_tween()
			tw.tween_property(panel, "position:y", target_y, 0.12)
