extends Node

const FADE_DURATION := 0.25   # seconds for each fade leg
const HOLD_DURATION := 0.15   # seconds of solid black between fades

@onready var overlay: ColorRect = $CanvasLayer/Overlay

func _ready() -> void:
	# Arrive fully black, then kick off: hold -> load destination
	overlay.modulate.a = 1.0
	await get_tree().create_timer(HOLD_DURATION).timeout
	_go_to_next()

func _go_to_next() -> void:
	var dest: String = TimeManager.next_scene
	if dest == "":
		push_error("LoadingScreen: TimeManager.next_scene is empty!")
		return

	# Use threaded loader so the scene is genuinely loaded before we switch
	ResourceLoader.load_threaded_request(dest)

	# Poll until the resource is ready (yields back each frame)
	while ResourceLoader.load_threaded_get_status(dest) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed = ResourceLoader.load_threaded_get(dest)
	if packed == null:
		push_error("LoadingScreen: failed to load '%s'" % dest)
		return

	# Fade out the black overlay before revealing the new scene
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

	get_tree().change_scene_to_packed(packed)
