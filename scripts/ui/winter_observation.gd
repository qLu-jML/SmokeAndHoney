# winter_observation.gd -- Passive winter hive observation overlay.
# -------------------------------------------------------------------------
# During winter months (Deepcold, Kindlemonth), players cannot open the
# hive for full inspection. Instead they observe from outside:
#   - Weight: Heavy / Medium / Light (mapped from honey_stores)
#   - Sound: Strong hum / Faint buzz / Silence (mapped from population)
#   - Entrance: Cleansing flights / None (warm day check)
# Results are auto-logged to the Knowledge Journal.
# -------------------------------------------------------------------------
extends CanvasLayer

# -- Layout (320x180 viewport) -------------------------------------------
const VP_W := 320
const VP_H := 180

# -- Colours ---------------------------------------------------------------
const C_BG := Color(0.04, 0.04, 0.06, 0.95)
const C_ACCENT := Color(0.70, 0.80, 0.95, 1.0)
const C_TEXT := Color(0.85, 0.85, 0.90, 1.0)
const C_MUTED := Color(0.45, 0.45, 0.55, 1.0)
const C_GOOD := Color(0.40, 0.80, 0.45)
const C_WARN := Color(0.90, 0.75, 0.20)
const C_BAD := Color(0.90, 0.30, 0.25)

# -- State -----------------------------------------------------------------
var _hive_ref: Node = null
var _sim = null

# -- UI refs ---------------------------------------------------------------
var _title_label: Label = null
var _weight_label: Label = null
var _sound_label: Label = null
var _entrance_label: Label = null
var _advice_label: Label = null
var _footer_label: Label = null

# =========================================================================
# PUBLIC
# =========================================================================

func open(hive_node: Node) -> void:
	_hive_ref = hive_node
	if "simulation" in hive_node:
		_sim = hive_node.simulation

# =========================================================================
# LIFECYCLE
# =========================================================================

func _ready() -> void:
	layer = 10
	_build_ui()
	# Defer observation to next frame so open() has been called
	call_deferred("_perform_observation")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", C_ACCENT)
	_title_label.position = Vector2(80, 8)
	_title_label.text = "Winter Observation"
	add_child(_title_label)

	var divider := ColorRect.new()
	divider.color = C_ACCENT
	divider.position = Vector2(20, 22)
	divider.size = Vector2(VP_W - 40, 1)
	add_child(divider)

	_weight_label = _make_obs_label(35)
	_sound_label = _make_obs_label(55)
	_entrance_label = _make_obs_label(75)

	_advice_label = Label.new()
	_advice_label.add_theme_font_size_override("font_size", 6)
	_advice_label.add_theme_color_override("font_color", C_TEXT)
	_advice_label.position = Vector2(20, 100)
	_advice_label.custom_minimum_size = Vector2(VP_W - 40, 50)
	_advice_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_advice_label)

	_footer_label = Label.new()
	_footer_label.add_theme_font_size_override("font_size", 5)
	_footer_label.add_theme_color_override("font_color", C_MUTED)
	_footer_label.text = "[ESC] Close"
	_footer_label.position = Vector2(130, VP_H - 12)
	add_child(_footer_label)

func _make_obs_label(y_pos: int) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", C_TEXT)
	lbl.position = Vector2(30, y_pos)
	lbl.custom_minimum_size = Vector2(VP_W - 60, 14)
	add_child(lbl)
	return lbl

# =========================================================================
# OBSERVATION LOGIC
# =========================================================================

func _perform_observation() -> void:
	if _sim == null:
		_advice_label.text = "No colony data available."
		return

	var hive_name: String = "Hive"
	if _hive_ref and "hive_name" in _hive_ref and _hive_ref.hive_name != "":
		hive_name = _hive_ref.hive_name
	_title_label.text = "%s -- Winter Observation" % hive_name

	# -- Weight assessment ---------------------------------------------------
	var honey: float = _sim.honey_stores + _sim.feed_stores
	var weight_text: String = ""
	var weight_color: Color = C_GOOD
	if honey >= 50.0:
		weight_text = "Weight: HEAVY -- Good stores."
		weight_color = C_GOOD
	elif honey >= 25.0:
		weight_text = "Weight: MEDIUM -- Monitor closely."
		weight_color = C_WARN
	else:
		weight_text = "Weight: LIGHT -- Danger! Consider emergency feeding."
		weight_color = C_BAD
	_weight_label.text = weight_text
	_weight_label.add_theme_color_override("font_color", weight_color)

	# -- Sound assessment ----------------------------------------------------
	var total_adults: int = _sim.nurse_count + _sim.house_count + _sim.forager_count
	var sound_text: String = ""
	var sound_color: Color = C_GOOD
	if total_adults >= 10000:
		sound_text = "Sound: STRONG HUM -- Healthy cluster."
		sound_color = C_GOOD
	elif total_adults >= 3000:
		sound_text = "Sound: FAINT BUZZ -- Colony is small but alive."
		sound_color = C_WARN
	else:
		sound_text = "Sound: SILENCE -- Colony may be dead."
		sound_color = C_BAD
	_sound_label.text = sound_text
	_sound_label.add_theme_color_override("font_color", sound_color)

	# -- Entrance assessment -------------------------------------------------
	var warm_day: bool = false
	if WeatherManager and "current_temp_f" in WeatherManager:
		warm_day = WeatherManager.current_temp_f >= 45.0
	var entrance_text: String = ""
	if warm_day and total_adults >= 3000:
		entrance_text = "Entrance: Cleansing flights spotted. Good sign."
	elif warm_day:
		entrance_text = "Entrance: No activity despite warm weather. Concerning."
	else:
		entrance_text = "Entrance: Too cold for flights. Normal."
	_entrance_label.text = entrance_text

	# -- Advice ---------------------------------------------------------------
	var advice: String = ""
	if honey < 25.0:
		advice = "This colony is dangerously low on stores. Emergency fondant or dry sugar can save them."
	elif total_adults < 3000:
		advice = "Very low population. This colony may not survive winter. There is nothing you can do now but hope."
	elif honey < 40.0:
		advice = "Stores are getting thin. Keep monitoring weight. If it drops more, consider emergency feeding."
	else:
		advice = "Colony looks good for now. Check again in a week. Don't open the hive -- you'll break the cluster."
	_advice_label.text = advice

	# -- Auto-log to journal --------------------------------------------------
	if KnowledgeLog and KnowledgeLog.has_method("add_hive_record"):
		var details: String = "%s | %s | %s" % [
			weight_text.split(" -- ")[0] if " -- " in weight_text else weight_text,
			sound_text.split(" -- ")[0] if " -- " in sound_text else sound_text,
			entrance_text.split(". ")[0] if ". " in entrance_text else entrance_text,
		]
		KnowledgeLog.add_hive_record(hive_name, "Winter Check", details)
	if KnowledgeLog and KnowledgeLog.has_method("unlock_entry"):
		KnowledgeLog.unlock_entry("winter_prep")

# =========================================================================
# INPUT
# =========================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		queue_free()
	get_viewport().set_input_as_handled()
