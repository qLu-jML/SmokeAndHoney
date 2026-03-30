# WeatherManager.gd -- Global weather state and generation for Smoke & Honey
# ============================================================================
# Realistic Iowa-based weather generation system. Rolled once per day at wake.
# Uses season-weighted probability tables calibrated to central Iowa climate
# data (Des Moines / Ames area -- NOAA normals 1991-2020).
#
# Weather states: Sunny, Overcast, Rainy, Windy, Cold, HeatWave, Drought, Foggy
# Catastrophic events (tornadoes, severe blizzards) excluded per design.
#
# Temperature model: sinusoidal seasonal curve + daily variance, calibrated
# to Iowa monthly average highs/lows.
#
# Autoloaded as "WeatherManager" in project.godot.
# ============================================================================
extends Node

# -- Signals -----------------------------------------------------------------
signal weather_changed(new_weather: String)
signal temperature_changed(temp_f: float)

# -- Weather State Enum (string-based for readability in save files) ---------
# "Sunny"     -- clear skies, optimal foraging
# "Overcast"  -- cloudy, reduced but possible foraging
# "Rainy"     -- rain, bees stay in hive, no foraging, no inspections
# "Windy"     -- strong wind (>15 mph), reduced foraging, defensive bees
# "Cold"      -- cold snap (<50F), bees cluster, no foraging
# "HeatWave"  -- extreme heat (>95F), bees beard, water demand spikes
# "Drought"   -- dry spell, nectar dearth, high robbing risk
# "Foggy"     -- morning fog, delayed foraging start

var current_weather: String = "Sunny"
var current_temp_f: float = 65.0      # Fahrenheit for display
var current_wind_mph: float = 8.0     # Wind speed for display/mechanics
var current_humidity: float = 0.55    # 0-1 relative humidity

# Multi-day tracking for drought and weather streaks
var _consecutive_dry_days: int = 0
var _rain_days_this_month: int = 0
var _last_rain_day: int = 0

# -- Iowa Monthly Climate Data (NOAA Normals, Des Moines 1991-2020) ----------
# Mapped to the 8-month calendar:
#   Quickening (Spring M1) ~ April        High 62F, Low 40F, Rain 12 days
#   Greening   (Spring M2) ~ May          High 73F, Low 52F, Rain 13 days
#   Wide-Clover (Summer M1) ~ June        High 83F, Low 62F, Rain 11 days
#   High-Sun   (Summer M2) ~ July         High 86F, Low 66F, Rain 10 days
#   Full-Earth (Fall M1)   ~ September    High 77F, Low 55F, Rain 9 days
#   Reaping    (Fall M2)   ~ October      High 63F, Low 42F, Rain 8 days
#   Deepcold   (Winter M1) ~ December     High 33F, Low 17F, Rain/Snow 8 days
#   Kindlemonth (Winter M2) ~ January     High 29F, Low 12F, Rain/Snow 7 days

# [avg_high_f, avg_low_f, rain_chance_pct, wind_avg_mph, humidity_avg]
const MONTHLY_CLIMATE: Array = [
	[62.0, 40.0, 43.0, 12.0, 0.62],  # Quickening (April)
	[73.0, 52.0, 46.0, 11.0, 0.65],  # Greening (May)
	[83.0, 62.0, 39.0, 9.0,  0.68],  # Wide-Clover (June)
	[86.0, 66.0, 36.0, 8.5,  0.70],  # High-Sun (July)
	[77.0, 55.0, 32.0, 9.5,  0.65],  # Full-Earth (September)
	[63.0, 42.0, 29.0, 11.0, 0.60],  # Reaping (October)
	[33.0, 17.0, 29.0, 11.5, 0.72],  # Deepcold (December)
	[29.0, 12.0, 25.0, 11.0, 0.70],  # Kindlemonth (January)
]

# Season-weighted weather probability tables.
# Each row: [Sunny, Overcast, Rainy, Windy, Cold, HeatWave, Drought, Foggy]
# Must sum to ~1.0 per row. Calibrated from Iowa climate data.
const WEATHER_WEIGHTS: Array = [
	# Quickening (Spring M1) -- volatile spring weather, frequent rain
	[0.30, 0.25, 0.22, 0.12, 0.06, 0.00, 0.00, 0.05],
	# Greening (Spring M2) -- warming up, still rainy, thunderstorm season
	[0.28, 0.22, 0.25, 0.10, 0.02, 0.00, 0.00, 0.13],
	# Wide-Clover (Summer M1) -- warm, less rain, occasional heat
	[0.38, 0.20, 0.18, 0.06, 0.00, 0.08, 0.04, 0.06],
	# High-Sun (Summer M2) -- hottest month, drought risk peaks
	[0.35, 0.18, 0.15, 0.05, 0.00, 0.12, 0.08, 0.07],
	# Full-Earth (Fall M1) -- cooling, pleasant, less rain
	[0.40, 0.25, 0.14, 0.08, 0.03, 0.02, 0.02, 0.06],
	# Reaping (Fall M2) -- crisp fall, cold snaps begin
	[0.35, 0.22, 0.13, 0.12, 0.10, 0.00, 0.00, 0.08],
	# Deepcold (Winter M1) -- cold dominates, snow/sleet instead of rain
	[0.20, 0.22, 0.18, 0.12, 0.25, 0.00, 0.00, 0.03],
	# Kindlemonth (Winter M2) -- coldest month
	[0.18, 0.20, 0.15, 0.14, 0.30, 0.00, 0.00, 0.03],
]

const WEATHER_NAMES: Array = [
	"Sunny", "Overcast", "Rainy", "Windy",
	"Cold", "HeatWave", "Drought", "Foggy"
]

# -- Foraging multipliers per weather state (GDD S6.9) -----------------------
# Validated by Karpathy Phase 6: Iowa climate weather effects on foraging.
const FORAGE_MULTIPLIER: Dictionary = {
	"Sunny":    1.0,   # Clear skies, full foraging
	"Overcast": 0.7,   # Reduced but bees still fly
	"Rainy":    0.0,   # No flight in rain
	"Windy":    0.4,   # Strong wind limits flight range
	"Cold":     0.0,   # Too cold for flight (<50F)
	"HeatWave": 0.6,   # Bees fan hive instead of foraging
	"Drought":  0.3,   # Flowers drying up, minimal nectar
	"Foggy":    0.4,   # Reduced visibility limits foraging (Phase 6: 0.40)
}

# -- Inspection modifiers ----------------------------------------------------
# "allowed": can the player open hives?
# "sting_mult": sting chance multiplier
const INSPECTION_RULES: Dictionary = {
	"Sunny":    {"allowed": true,  "sting_mult": 1.0},
	"Overcast": {"allowed": true,  "sting_mult": 1.05},
	"Rainy":    {"allowed": false, "sting_mult": 1.0},
	"Windy":    {"allowed": true,  "sting_mult": 1.15},
	"Cold":     {"allowed": false, "sting_mult": 1.0},
	"HeatWave": {"allowed": true,  "sting_mult": 1.10},
	"Drought":  {"allowed": true,  "sting_mult": 1.20},
	"Foggy":    {"allowed": true,  "sting_mult": 1.0},
}

# -- Visual tint colors for the overlay layer --------------------------------
# Each weather state maps to a CanvasModulate color and overlay alpha.
# These create the atmospheric mood without requiring unique art per weather.
const WEATHER_TINTS: Dictionary = {
	"Sunny":    {"color": Color(1.0, 0.98, 0.95, 1.0),   "overlay_alpha": 0.0},
	"Overcast": {"color": Color(0.82, 0.84, 0.88, 1.0),  "overlay_alpha": 0.15},
	"Rainy":    {"color": Color(0.68, 0.72, 0.78, 1.0),  "overlay_alpha": 0.25},
	"Windy":    {"color": Color(0.92, 0.93, 0.90, 1.0),  "overlay_alpha": 0.05},
	"Cold":     {"color": Color(0.78, 0.85, 0.92, 1.0),  "overlay_alpha": 0.20},
	"HeatWave": {"color": Color(1.0, 0.92, 0.82, 1.0),   "overlay_alpha": 0.10},
	"Drought":  {"color": Color(0.95, 0.90, 0.78, 1.0),  "overlay_alpha": 0.12},
	"Foggy":    {"color": Color(0.88, 0.88, 0.90, 1.0),  "overlay_alpha": 0.30},
}

# ============================================================================
# PUBLIC API
# ============================================================================

## Roll new weather for the day. Called by TimeManager.start_new_day() or
## on game start if no saved weather exists.
func roll_daily_weather() -> void:
	var month_idx: int = TimeManager.current_month_index()

	# -- Temperature generation ------------------------------------------------
	var climate: Array = MONTHLY_CLIMATE[month_idx]
	var avg_high: float = climate[0]
	var avg_low: float = climate[1]
	var avg_wind: float = climate[3]
	var avg_humidity: float = climate[4]

	# Daily temp: random between low and high with slight normal distribution
	# (average of two uniform rolls approximates a triangle distribution)
	var r1: float = randf_range(avg_low, avg_high)
	var r2: float = randf_range(avg_low, avg_high)
	current_temp_f = (r1 + r2) / 2.0

	# Add day-to-day variance (+/- 8F, Iowa is volatile)
	current_temp_f += randf_range(-8.0, 8.0)
	current_temp_f = clampf(current_temp_f, avg_low - 15.0, avg_high + 15.0)

	# Wind: log-normal-ish distribution around monthly average
	current_wind_mph = avg_wind * randf_range(0.3, 2.2)
	current_wind_mph = clampf(current_wind_mph, 0.0, 35.0)

	# Humidity
	current_humidity = clampf(avg_humidity + randf_range(-0.15, 0.15), 0.2, 0.95)

	# -- Weather state selection -----------------------------------------------
	var weights: Array = WEATHER_WEIGHTS[month_idx]
	var chosen: String = _weighted_random_pick(weights)

	# -- Post-roll adjustments based on actual conditions ----------------------
	# If temp rolled below 50F in a non-winter month, override to Cold
	if current_temp_f < 50.0 and chosen == "Sunny":
		chosen = "Cold"

	# If temp rolled above 95F in summer, consider HeatWave
	if current_temp_f > 95.0 and month_idx >= 2 and month_idx <= 3:
		if randf() < 0.6:
			chosen = "HeatWave"

	# Drought tracking: 5+ consecutive dry days in summer = Drought
	if chosen in ["Sunny", "Overcast", "Windy", "HeatWave"]:
		_consecutive_dry_days += 1
	else:
		_consecutive_dry_days = 0

	if _consecutive_dry_days >= 5 and month_idx >= 2 and month_idx <= 4:
		if randf() < 0.4:
			chosen = "Drought"

	# Rain tracking for monthly totals
	if chosen == "Rainy":
		_rain_days_this_month += 1
		_last_rain_day = TimeManager.current_day
		_consecutive_dry_days = 0

	# Iowa spring: if it hasn't rained in 4+ days during spring, force rain
	if month_idx <= 1 and _consecutive_dry_days >= 4:
		if randf() < 0.5:
			chosen = "Rainy"
			_consecutive_dry_days = 0

	# Adjust wind for Windy weather state
	if chosen == "Windy":
		current_wind_mph = maxf(current_wind_mph, 16.0)

	# Set state
	current_weather = chosen

	# Emit signals
	weather_changed.emit(current_weather)
	temperature_changed.emit(current_temp_f)

	print("[Weather] Day %d: %s, %.0fF, Wind %.0f mph, Humidity %.0f%%" % [
		TimeManager.current_day, current_weather, current_temp_f,
		current_wind_mph, current_humidity * 100.0])

## Reset monthly rain counter (called on month change).
func _on_month_changed(_month_name: String) -> void:
	_rain_days_this_month = 0

## Get the foraging multiplier for current weather.
func get_forage_multiplier() -> float:
	return FORAGE_MULTIPLIER.get(current_weather, 1.0)

## Can the player inspect hives right now?
func can_inspect() -> bool:
	var rules: Dictionary = INSPECTION_RULES.get(current_weather, {"allowed": true})
	return rules["allowed"]

## Get sting chance multiplier from weather.
func get_sting_multiplier() -> float:
	var rules: Dictionary = INSPECTION_RULES.get(current_weather, {"sting_mult": 1.0})
	return rules["sting_mult"]

## Get the visual tint data for the current weather.
func get_tint_data() -> Dictionary:
	return WEATHER_TINTS.get(current_weather, WEATHER_TINTS["Sunny"])

## Is it currently raining? (Used by rain particle system)
func is_raining() -> bool:
	return current_weather == "Rainy"

## Is it snowing? (Rain in winter months becomes snow visually)
func is_snowing() -> bool:
	return current_weather == "Rainy" and TimeManager.current_month_index() >= 6

## Get a short description for the HUD weather display.
func get_weather_description() -> String:
	match current_weather:
		"Sunny":    return "Sunny, %.0fF" % current_temp_f
		"Overcast": return "Overcast, %.0fF" % current_temp_f
		"Rainy":
			if is_snowing():
				return "Snow, %.0fF" % current_temp_f
			return "Rain, %.0fF" % current_temp_f
		"Windy":    return "Windy %.0f mph, %.0fF" % [current_wind_mph, current_temp_f]
		"Cold":     return "Cold Snap, %.0fF" % current_temp_f
		"HeatWave": return "Heat Wave, %.0fF" % current_temp_f
		"Drought":  return "Drought, %.0fF" % current_temp_f
		"Foggy":    return "Foggy, %.0fF" % current_temp_f
	return "%.0fF" % current_temp_f

## Get weather icon text (placeholder until art assets are ready).
func get_weather_icon_text() -> String:
	match current_weather:
		"Sunny":    return "Sun"
		"Overcast": return "Cloud"
		"Rainy":
			if is_snowing():
				return "Snow"
			return "Rain"
		"Windy":    return "Wind"
		"Cold":     return "Cold"
		"HeatWave": return "Hot"
		"Drought":  return "Dry"
		"Foggy":    return "Fog"
	return "?"

# ============================================================================
# SERIALIZATION (called by SaveManager)
# ============================================================================

func collect_save_data() -> Dictionary:
	return {
		"current_weather":      current_weather,
		"current_temp_f":       current_temp_f,
		"current_wind_mph":     current_wind_mph,
		"current_humidity":     current_humidity,
		"consecutive_dry_days": _consecutive_dry_days,
		"rain_days_this_month": _rain_days_this_month,
		"last_rain_day":        _last_rain_day,
	}

func apply_save_data(data: Dictionary) -> void:
	current_weather      = str(data.get("current_weather", "Sunny"))
	current_temp_f       = float(data.get("current_temp_f", 65.0))
	current_wind_mph     = float(data.get("current_wind_mph", 8.0))
	current_humidity     = float(data.get("current_humidity", 0.55))
	_consecutive_dry_days = int(data.get("consecutive_dry_days", 0))
	_rain_days_this_month = int(data.get("rain_days_this_month", 0))
	_last_rain_day        = int(data.get("last_rain_day", 0))
	weather_changed.emit(current_weather)
	temperature_changed.emit(current_temp_f)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	TimeManager.month_changed.connect(_on_month_changed)

# ============================================================================
# INTERNAL
# ============================================================================

## Weighted random selection from the weather probability table.
func _weighted_random_pick(weights: Array) -> String:
	var total: float = 0.0
	for w in weights:
		total += float(w)

	var roll: float = randf() * total
	var cumulative: float = 0.0
	for i in range(mini(weights.size(), WEATHER_NAMES.size())):
		cumulative += float(weights[i])
		if roll <= cumulative:
			return WEATHER_NAMES[i]

	# Fallback
	return "Sunny"
