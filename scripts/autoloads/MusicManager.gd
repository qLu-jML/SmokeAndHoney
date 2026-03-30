# MusicManager.gd -- Plays seasonal background music on loop.
# Listens to TimeManager.month_changed to swap tracks.
# Autoloaded as "MusicManager" in project.godot.
extends Node

# -- Audio players (two for crossfade) ----------------------------------------
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer

# -- Crossfade settings -------------------------------------------------------
const FADE_DURATION: float = 2.0
var _fading: bool = false
var _fade_elapsed: float = 0.0
var _fade_from: AudioStreamPlayer
var _fade_to: AudioStreamPlayer

# -- Volume (linear) ----------------------------------------------------------
const DEFAULT_VOLUME_DB: float = -6.0

# -- Track mapping (month index 0-7 -> resource path) -------------------------
const MONTH_TRACKS: Array = [
	"res://assets/audio/seasonalMusic/1_Quickening_theme.mp3",
	"res://assets/audio/seasonalMusic/2_Greening_Theme.mp3",
	"res://assets/audio/seasonalMusic/3_Wide-Clover_Theme.mp3",
	"res://assets/audio/seasonalMusic/4_High-Sun_Theme.mp3",
	"res://assets/audio/seasonalMusic/5_Full-Earth_theme.mp3",
	"res://assets/audio/seasonalMusic/6_Reaping_Theme.mp3",
	"res://assets/audio/seasonalMusic/7_Deepcold_Theme.mp3",
	"res://assets/audio/seasonalMusic/8_Kindlemonth_Theme.mp3",
]

var _current_month_index: int = -1

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	# Keep music playing even when the scene tree is paused (chest, shop, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create two AudioStreamPlayers for crossfading
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_player_a.volume_db = DEFAULT_VOLUME_DB
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_player_b.volume_db = -80.0
	add_child(_player_b)

	_active_player = _player_a

	# Connect finished signal so tracks loop
	_player_a.finished.connect(_on_track_finished.bind(_player_a))
	_player_b.finished.connect(_on_track_finished.bind(_player_b))

	# Listen for month changes
	if TimeManager:
		TimeManager.month_changed.connect(_on_month_changed)
		# Play the track for the current month right away
		_play_month_track(TimeManager.current_month_index())


func _process(delta: float) -> void:
	if not _fading:
		return
	_fade_elapsed += delta
	var t: float = clampf(_fade_elapsed / FADE_DURATION, 0.0, 1.0)
	# Fade out the old, fade in the new
	_fade_from.volume_db = lerpf(DEFAULT_VOLUME_DB, -80.0, t)
	_fade_to.volume_db = lerpf(-80.0, DEFAULT_VOLUME_DB, t)
	if t >= 1.0:
		_fading = false
		_fade_from.stop()
		_fade_from.volume_db = -80.0
		_active_player = _fade_to

# -- Track management ----------------------------------------------------------

func _play_month_track(month_idx: int) -> void:
	if month_idx == _current_month_index:
		return
	_current_month_index = month_idx
	var path: String = MONTH_TRACKS[month_idx]
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("MusicManager: Could not load track: " + path)
		return

	# Determine which player is inactive
	var next_player: AudioStreamPlayer
	if _active_player == _player_a:
		next_player = _player_b
	else:
		next_player = _player_a

	next_player.stream = stream
	next_player.volume_db = -80.0
	next_player.play()

	# If something is already playing, crossfade; otherwise just start
	if _active_player.playing:
		_fading = true
		_fade_elapsed = 0.0
		_fade_from = _active_player
		_fade_to = next_player
	else:
		next_player.volume_db = DEFAULT_VOLUME_DB
		_active_player = next_player


func _on_month_changed(_month_name: String) -> void:
	if TimeManager:
		_play_month_track(TimeManager.current_month_index())


func _on_track_finished(player: AudioStreamPlayer) -> void:
	# Loop: restart from the beginning
	if player == _active_player and player.stream != null:
		player.play()
