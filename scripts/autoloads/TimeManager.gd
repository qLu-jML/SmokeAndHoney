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
