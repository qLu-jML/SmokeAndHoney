# TimeManager.gd -- Global day/time handler for Smoke & Honey
# Uses the GDD 8-month calendar: 28 days/month, 224 days/year.
# Time-of-day: 1 real-time minute = 1 in-game hour (24-min full day).
# Autoloaded as "TimeManager" in project.godot.
extends Node

# -- Signals -------------------------------------------------------------------
signal day_advanced(new_day: int)
signal month_changed(month_name: String)
signal season_changed(season_name: String)
signal hour_changed(hour: float)     # fires every frame while time passes
signal midnight_reached()            # fires once when clock crosses 24:00

# -- Calendar Constants --------------------------------------------------------
const YEAR_LENGTH:   int = 224
const MONTH_LENGTH:  int = 28
const SEASON_LENGTH: int = 56

const MONTH_NAMES: Array = [
	"Quickening",   # Spring M1 (days 1-28)
	"Greening",     # Spring M2 (days 29-56)
	"Wide-Clover",  # Summer M1 (days 57-84)
	"High-Sun",     # Summer M2 (days 85-112)
	"Full-Earth",   # Fall M1   (days 113-140)
	"Reaping",      # Fall M2   (days 141-168)
	"Deepcold",     # Winter M1 (days 169-196)
	"Kindlemonth",  # Winter M2 (days 197-224)
]

const SEASON_NAMES: Array = ["Spring", "Summer", "Fall", "Winter"]

# -- Holidays ------------------------------------------------------------------
# GDD S5.1: Four seasonal holidays, one per peak month.
# Each entry: { "month_index": int, "day": int, "name": String, "desc": String }
# Names inspired by Stephen King's Dark Tower series with real-world echoes.
const HOLIDAYS: Array = [
	{
		"month_index": 1,  # Greening (Spring peak)
		"day": 12,
		"name": "The Quickening Morn",
		"desc": "A spring celebration of renewal. The whole town gathers at sunrise for a communal meal in the square -- welcoming the return of life to the fields after the long dark."
	},
	{
		"month_index": 3,  # High-Sun (Summer peak)
		"day": 19,
		"name": "Founder's Beam",
		"desc": "Cedar Bend's midsummer festival of heritage and civic pride. Named for the founding pillar of the community. Fireworks at dusk, pie contests at the diner, flags on every porch."
	},
	{
		"month_index": 4,  # Full-Earth (Fall peak)
		"day": 7,
		"name": "The Reaping Fire",
		"desc": "The harvest bonfire night. Families stack a great pyre in the town square and burn corn-husk effigies to mark the turning of the season. Children carry lanterns; elders tell stories until the embers die."
	},
	{
		"month_index": 6,  # Deepcold (Winter peak)
		"day": 21,
		"name": "The Long Table",
		"desc": "The longest night of winter. Families gather for a candlelit feast at one long communal table. Gifts are exchanged, debts forgiven, and a single lantern is hung in every window to guide the lost home."
	},
]

signal holiday_started(holiday_name: String)

# -- State ---------------------------------------------------------------------
var current_day:  int   = 1
var current_hour: float = 6.0   # 0.0-24.0, starts at 6 AM

# Prevents midnight_reached from firing more than once per crossing.
var _midnight_pending: bool = false

# -- Scene-transition state ----------------------------------------------------
var came_from_interior: bool = false
var player_return_pos:  Vector2 = Vector2.ZERO
var exterior_hives:     Array   = []
var exterior_flowers:   Array   = []
var next_scene:         String  = ""
var previous_scene:     String  = ""
var current_scene_id:   String  = "home"   # used by zone minimap

# -- Month Skip (X key, non-dev mode) -----------------------------------------

## When dev mode is OFF and no UI overlay is open, pressing X skips to the
## first day of the next month.  Uses _input (not _unhandled_input) because
## focused HUD Controls can absorb key events before _unhandled_input fires.
## Overlay scenes that also bind X (hive management, interiors) are checked
## first so we don't steal their close action.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_X:
		return
	if GameData.dev_labels_visible:
		return
	# Don't steal X from UI overlays that use it to close
	if _is_overlay_open():
		return
	skip_to_next_month()
	get_viewport().set_input_as_handled()

## Returns true if a UI overlay or interior scene that uses X-to-close is open.
## The inspection overlay is NOT blocked -- X is free there for month skip.
func _is_overlay_open() -> bool:
	if get_tree().paused:
		return true
	if get_tree().get_first_node_in_group("hive_management_overlay"):
		return true
	if get_tree().get_first_node_in_group("chest_storage_overlay"):
		return true
	# Interior scenes use X to close menus/exit
	if current_scene_id.ends_with("_interior"):
		return true
	return false

## Advances current_day to the first day of the next month and fires all
## relevant day/month/season signals along the way.
func skip_to_next_month() -> void:
	var day_in_year: int = (current_day - 1) % YEAR_LENGTH
	@warning_ignore("INTEGER_DIVISION")
	var current_month_idx: int = day_in_year / MONTH_LENGTH
	var next_month_start: int = (current_month_idx + 1) * MONTH_LENGTH
	# How many days to jump
	var days_to_skip: int
	if next_month_start >= YEAR_LENGTH:
		# Wrap to day 1 of next year's Quickening
		days_to_skip = YEAR_LENGTH - day_in_year
	else:
		days_to_skip = next_month_start - day_in_year
	# Advance day-by-day so all signals (day, month, season, holiday) fire
	for i in range(days_to_skip):
		advance_day()
	# Reset clock to morning
	current_hour = 6.0
	_midnight_pending = false
	# Roll weather for the new day
	if WeatherManager and WeatherManager.has_method("roll_daily_weather"):
		WeatherManager.roll_daily_weather()
	print(">> Month skipped! Now day %d -- %s, %s (Year %d)" % [
		current_day, current_month_name(), current_season_name(), current_year()])

# -- Time Progression ----------------------------------------------------------

## Advances in-game time each frame (1 real minute = 1 in-game hour).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# GDD S5.1: 1 real-time minute = 1 in-game hour
	current_hour += delta / 60.0
	if current_hour >= 24.0 and not _midnight_pending:
		_midnight_pending = true
		current_hour = 0.0
		midnight_reached.emit()
	hour_changed.emit(current_hour)

# -- Called by the daily summary "Accept" button -------------------------------
## Resets the clock to 6 AM and advances the calendar by one day.
## Also triggers the daily weather roll.
func start_new_day() -> void:
	_midnight_pending = false
	current_hour = 6.0
	advance_day()
	# Roll weather for the new day (after advance_day so month/season are current)
	if WeatherManager and WeatherManager.has_method("roll_daily_weather"):
		WeatherManager.roll_daily_weather()

# -- Computed Calendar Properties ---------------------------------------------

## Returns the current month index (0-7) within the 8-month calendar.
func current_month_index() -> int:
	var day_in_year := (current_day - 1) % YEAR_LENGTH
	@warning_ignore("INTEGER_DIVISION")
	return day_in_year / MONTH_LENGTH

## Returns the name of the current month.
func current_month_name() -> String:
	return MONTH_NAMES[current_month_index()]

## Returns the current day within the month (1-28).
func current_day_of_month() -> int:
	var day_in_year := (current_day - 1) % YEAR_LENGTH
	return (day_in_year % MONTH_LENGTH) + 1

## Returns the current in-game year (1-based).
func current_year() -> int:
	@warning_ignore("INTEGER_DIVISION")
	return (current_day - 1) / YEAR_LENGTH + 1

## Returns the name of the current season.
func current_season_name() -> String:
	@warning_ignore("INTEGER_DIVISION")
	return SEASON_NAMES[current_month_index() / 2]

## GDD S5.1 season factor 0.0-1.0 for simulation use.
## Validated by Karpathy research Phase 2+8: drives population and foraging curves.
func season_factor() -> float:
	match current_month_index():
		0: return 0.55   # Quickening (spring rush -- validated lower than 0.65)
		1: return 0.80   # Greening
		2: return 1.00   # Wide-Clover
		3: return 1.00   # High-Sun
		4: return 0.65   # Full-Earth
		5: return 0.35   # Reaping
		6: return 0.08   # Deepcold
		7: return 0.05   # Kindlemonth
	return 0.5

## Returns true if the current month is in winter.
func is_winter() -> bool:
	return current_month_index() >= 6

## Returns true if the current month is in spring.
func is_spring() -> bool:
	return current_month_index() <= 1

# -- Holiday Helpers -----------------------------------------------------------

## Returns the holiday dictionary for today, or null if today is not a holiday.
func get_todays_holiday() -> Variant:
	var mi: int = current_month_index()
	var dom: int = current_day_of_month()
	for h in HOLIDAYS:
		if h["month_index"] == mi and h["day"] == dom:
			return h
	return null

## Returns the holiday name for today, or "" if none.
func get_holiday_name() -> String:
	var h: Variant = get_todays_holiday()
	if h != null:
		return h["name"]
	return ""

## Returns true if today is a holiday.
func is_holiday() -> bool:
	return get_todays_holiday() != null

## Returns true if the current month is in summer.
func is_summer() -> bool:
	var m := current_month_index()
	return m == 2 or m == 3

# -- Time-of-Day Helpers -------------------------------------------------------

## GDD S5.2 period names.
func time_of_day_name() -> String:
	if current_hour >= 21.0 or current_hour < 4.0:
		return "Night"
	elif current_hour < 6.0:
		return "Pre-dawn"
	elif current_hour < 10.0:
		return "Morning"
	elif current_hour < 14.0:
		return "Midday"
	elif current_hour < 18.0:
		return "Afternoon"
	else:
		return "Evening"

## 12-hour clock string, e.g. "6:42 AM".
## Returns a 12-hour clock string representation of the current time (e.g. "6:42 AM").
func format_time() -> String:
	var h := int(current_hour)
	var m := int((current_hour - float(h)) * 60.0)
	var suffix: String = "AM" if h < 12 else "PM"
	var display_h := h % 12
	if display_h == 0:
		display_h = 12
	return "%d:%02d %s" % [display_h, m, suffix]

# -- Day Advancement -----------------------------------------------------------

## Advances the calendar by one day and emits relevant change signals.
func advance_day() -> void:
	var old_month  := current_month_index()
	var old_season := current_season_name()

	current_day += 1

	print("? Day %d -- %s, %s (Year %d)" % [
		current_day,
		current_month_name(),
		current_season_name(),
		current_year()
	])

	day_advanced.emit(current_day)

	if current_month_index() != old_month:
		month_changed.emit(current_month_name())
		print("? New month: %s" % current_month_name())

	if current_season_name() != old_season:
		season_changed.emit(current_season_name())
		print("? New season: %s" % current_season_name())

	# Holiday check
	var holiday_name: String = get_holiday_name()
	if holiday_name != "":
		holiday_started.emit(holiday_name)
		print("** Holiday: %s **" % holiday_name)
