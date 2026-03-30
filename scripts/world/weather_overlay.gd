# weather_overlay.gd -- Visual weather effects layer
# ============================================================================
# Add this as a child of any exterior scene's CanvasLayer (or as a standalone
# CanvasLayer). It creates:
#   1. A CanvasModulate node that tints the entire scene (darker for rain, etc.)
#   2. A ColorRect overlay for atmospheric haze/fog
#   3. Smooth transitions when weather changes
#
# Does NOT handle particles (rain/snow) -- see WeatherParticles for that.
# ============================================================================
extends CanvasLayer

var _canvas_mod: CanvasModulate = null
var _haze_overlay: ColorRect = null

# Transition state
var _target_color: Color = Color.WHITE
var _target_alpha: float = 0.0
var _transition_speed: float = 2.0  # seconds to blend

const VP_W: int = 320
const VP_H: int = 180

func _ready() -> void:
	# This layer renders above the game world but below UI
	layer = 5

	# -- CanvasModulate: tints all sprites/tiles below this layer --------
	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = Color.WHITE
	add_child(_canvas_mod)

	# -- Haze overlay: semi-transparent screen fill for fog/rain ---------
	_haze_overlay = ColorRect.new()
	_haze_overlay.size = Vector2(VP_W, VP_H)
	_haze_overlay.position = Vector2.ZERO
	_haze_overlay.color = Color(0.5, 0.55, 0.65, 0.0)
	_haze_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_haze_overlay)

	# Connect to weather changes
	if WeatherManager:
		WeatherManager.weather_changed.connect(_on_weather_changed)
		# Apply current weather immediately
		_apply_weather_instant(WeatherManager.current_weather)

func _process(delta: float) -> void:
	# Smoothly blend the canvas modulate color
	if _canvas_mod:
		_canvas_mod.color = _canvas_mod.color.lerp(_target_color, delta * _transition_speed)

	# Smoothly blend the haze overlay alpha
	if _haze_overlay:
		var current_a: float = _haze_overlay.color.a
		var new_a: float = lerpf(current_a, _target_alpha, delta * _transition_speed)
		_haze_overlay.color.a = new_a

func _on_weather_changed(new_weather: String) -> void:
	var tint_data: Dictionary = WeatherManager.WEATHER_TINTS.get(
		new_weather, WeatherManager.WEATHER_TINTS["Sunny"])
	_target_color = tint_data["color"]
	_target_alpha = tint_data["overlay_alpha"]

	# Set haze color based on weather type (alpha handled by transition)
	match new_weather:
		"Rainy":
			if WeatherManager.is_snowing():
				_haze_overlay.color = Color(0.85, 0.88, 0.92, _haze_overlay.color.a)
			else:
				_haze_overlay.color = Color(0.45, 0.50, 0.58, _haze_overlay.color.a)
		"Foggy":
			_haze_overlay.color = Color(0.82, 0.82, 0.85, _haze_overlay.color.a)
		"Cold":
			_haze_overlay.color = Color(0.70, 0.78, 0.88, _haze_overlay.color.a)
		"HeatWave":
			_haze_overlay.color = Color(0.90, 0.78, 0.55, _haze_overlay.color.a)
		"Drought":
			_haze_overlay.color = Color(0.88, 0.80, 0.60, _haze_overlay.color.a)
		_:
			_haze_overlay.color = Color(0.5, 0.55, 0.65, _haze_overlay.color.a)

func _apply_weather_instant(weather: String) -> void:
	var tint_data: Dictionary = WeatherManager.WEATHER_TINTS.get(
		weather, WeatherManager.WEATHER_TINTS["Sunny"])
	_target_color = tint_data["color"]
	_target_alpha = tint_data["overlay_alpha"]
	if _canvas_mod:
		_canvas_mod.color = _target_color
	if _haze_overlay:
		_haze_overlay.color.a = _target_alpha
