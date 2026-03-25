# DialogueUI.gd
# -----------------------------------------------------------------------------
# Reusable NPC dialogue/speech system for Smoke & Honey.
#
# Supports two display modes:
#   MODE_BUBBLE  -- floating speech bubble anchored above the NPC (world-space)
#   MODE_BOX     -- full bottom dialogue panel (screen-space CanvasLayer)
#
# Usage:
#   # Speech bubble (world-space, auto-dismiss):
#   DialogueUI.show_bubble(uncle_bob_node, "Text here", 4.0)
#
#   # Dialogue box (screen-space, player must advance):
#   DialogueUI.show_dialogue("Uncle Bob", lines_array, portrait_key)
#   await DialogueUI.dialogue_finished
# -----------------------------------------------------------------------------
extends CanvasLayer
# NOTE: Do NOT add class_name here -- this script is an autoload singleton
# named "DialogueUI" in project.godot. Adding class_name would conflict
# with the autoload name and cause a parse error in Godot 4.x.

# -- Modes ---------------------------------------------------------------------
const MODE_BUBBLE := "bubble"
const MODE_BOX    := "box"

# -- Layout (screen-space dialogue box, 320x180 viewport) ---------------------
const VP_W       := 320
const VP_H       := 180
const BOX_H      := 50        # height of the bottom dialogue panel
const BOX_Y      := VP_H - BOX_H - 2
const BOX_X      := 2
const BOX_W      := VP_W - 4
const PORTRAIT_S := 40        # portrait square size
const TEXT_X     := BOX_X + PORTRAIT_S + 6
const TEXT_W     := BOX_W - PORTRAIT_S - 10
const TEXT_H     := BOX_H - 10

# -- Colors --------------------------------------------------------------------
const C_BG       := Color(0.09, 0.07, 0.04, 0.97)
const C_BORDER   := Color(0.80, 0.53, 0.10, 1.0)
const C_BORDER_D := Color(0.47, 0.28, 0.05, 1.0)
const C_NAME     := Color(0.95, 0.78, 0.32, 1.0)
const C_TEXT     := Color(0.90, 0.85, 0.70, 1.0)
const C_HINT     := Color(0.55, 0.50, 0.40, 1.0)
const C_CREAM    := Color(0.98, 0.96, 0.89, 1.0)
const C_BUBBLE_BG:= Color(0.96, 0.93, 0.85, 0.97)
const C_BUBBLE_BD:= Color(0.60, 0.40, 0.08, 1.0)
const C_BUBBLE_TX:= Color(0.22, 0.14, 0.05, 1.0)

# -- Signals -------------------------------------------------------------------
signal dialogue_finished
signal dialogue_advanced(line_index: int)

# -- State ---------------------------------------------------------------------
var _mode: String = ""
var _open: bool = false

# Box-mode state
var _lines: Array   = []
var _line_idx: int  = 0
var _speaker: String = ""
var _box_root: Control = null
var _name_label: Label = null
var _text_label: Label = null
var _hint_label: Label = null
var _portrait_rect: ColorRect = null

# Bubble tracking (multiple simultaneous bubbles allowed)
var _bubbles: Array = []

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	layer = 40   # above HUD, below notifications

func _unhandled_key_input(event: InputEvent) -> void:
	if not _open or _mode != MODE_BOX:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			if event.keycode == KEY_ESCAPE:
				_close_box()
			else:
				_advance_line()
			get_viewport().set_input_as_handled()

# -- Public: Speech Bubble (world-space) ---------------------------------------

## Show a floating speech bubble above `npc_node`.
## The bubble tracks the NPC's screen position each frame.
## Auto-dismisses after `duration` seconds.
func show_bubble(npc_node: Node2D, text: String, duration: float = 4.0) -> void:
	var bubble := _build_bubble(text)
	add_child(bubble)

	var entry := { "bubble": bubble, "npc": npc_node, "done": false }
	_bubbles.append(entry)
	_update_bubble_pos(entry)

	# Auto-dismiss
	await get_tree().create_timer(duration).timeout
	_remove_bubble(entry)

## Remove all active bubbles for a given NPC.
func clear_bubbles(npc_node: Node2D) -> void:
	for entry in _bubbles.duplicate():
		if entry["npc"] == npc_node:
			_remove_bubble(entry)

func _process(_delta: float) -> void:
	for entry in _bubbles:
		if is_instance_valid(entry["npc"]) and is_instance_valid(entry["bubble"]):
			_update_bubble_pos(entry)

func _update_bubble_pos(entry: Dictionary) -> void:
	var npc: Node2D = entry["npc"]
	var bubble: Control = entry["bubble"]
	if not is_instance_valid(npc) or not is_instance_valid(bubble):
		return
	# Convert NPC world position to screen coords
	var cam := get_viewport().get_camera_2d()
	var screen_pos: Vector2
	if cam:
		screen_pos = npc.get_global_transform().origin - cam.get_global_transform().origin
		screen_pos += Vector2(VP_W / 2.0, VP_H / 2.0)
		# Apply camera zoom
		var zoom := cam.zoom
		screen_pos = (npc.global_position - cam.global_position) * zoom + Vector2(VP_W / 2.0, VP_H / 2.0)
	else:
		screen_pos = npc.global_position
	# Position bubble centered above NPC, offset up by sprite height
	var bw: float = bubble.size.x
	var bh: float = bubble.size.y
	bubble.position = Vector2(
		clampf(screen_pos.x - bw / 2.0, 2.0, VP_W - bw - 2.0),
		clampf(screen_pos.y - bh - 20.0, 2.0, VP_H - bh - 2.0)
	)

func _build_bubble(text: String) -> Control:
	var bw := 100
	var bh := 28

	var root := Control.new()
	root.size = Vector2(bw, bh)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 25

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BUBBLE_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Border
	var brd := Panel.new()
	brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0,0,0,0)
	sty.draw_center = false
	sty.border_color = C_BUBBLE_BD
	sty.set_border_width_all(1)
	brd.add_theme_stylebox_override("panel", sty)
	root.add_child(brd)

	# Text
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(4, 3)
	lbl.size = Vector2(bw - 8, bh - 6)
	lbl.add_theme_font_size_override("font_size", 5)
	lbl.add_theme_color_override("font_color", C_BUBBLE_TX)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

	# Tail triangle (drawn as tiny ColorRect pixels)
	var tail := ColorRect.new()
	tail.size = Vector2(4, 4)
	tail.position = Vector2(bw / 2.0 - 2, bh - 1)
	tail.color = C_BUBBLE_BD
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tail)

	return root

func _remove_bubble(entry: Dictionary) -> void:
	_bubbles.erase(entry)
	var b: Control = entry["bubble"]
	if is_instance_valid(b):
		b.queue_free()

# -- Public: Dialogue Box (screen-space) ---------------------------------------

## Show a multi-line screen-space dialogue box.
## @param speaker_name  Displayed name (e.g. "Uncle Bob").
## @param lines         Array[String] -- lines to cycle through.
## @param portrait_key  Optional key for portrait lookup (future use).
func show_dialogue(speaker_name: String, lines: Array,
		portrait_key: String = "") -> void:
	if _open:
		_close_box()
	_lines    = lines
	_line_idx = 0
	_speaker  = speaker_name
	_open     = true
	_mode     = MODE_BOX
	_build_box(portrait_key)
	_show_line(0)

## Programmatically close the dialogue box (e.g. from calling script).
func close() -> void:
	if _open:
		_close_box()

func is_open() -> bool:
	return _open

# -- Box Builder ---------------------------------------------------------------

func _build_box(portrait_key: String) -> void:
	_box_root = Control.new()
	_box_root.name = "DialogueBox"
	_box_root.size = Vector2(BOX_W, BOX_H)
	_box_root.position = Vector2(BOX_X, BOX_Y)
	_box_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box_root)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_root.add_child(bg)

	# Border (double-line style)
	var outer_brd := Panel.new()
	outer_brd.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_sty := StyleBoxFlat.new()
	outer_sty.bg_color = Color(0,0,0,0)
	outer_sty.draw_center = false
	outer_sty.border_color = C_BORDER
	outer_sty.set_border_width_all(1)
	outer_brd.add_theme_stylebox_override("panel", outer_sty)
	_box_root.add_child(outer_brd)

	# Inner border inset by 2
	var inner_brd := Panel.new()
	inner_brd.position = Vector2(2, 2)
	inner_brd.size = Vector2(BOX_W - 4, BOX_H - 4)
	inner_brd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_sty := StyleBoxFlat.new()
	inner_sty.bg_color = Color(0,0,0,0)
	inner_sty.draw_center = false
	inner_sty.border_color = C_BORDER_D
	inner_sty.set_border_width_all(1)
	inner_brd.add_theme_stylebox_override("panel", inner_sty)
	_box_root.add_child(inner_brd)

	# Portrait area (left side)
	_portrait_rect = ColorRect.new()
	_portrait_rect.size = Vector2(PORTRAIT_S, PORTRAIT_S)
	_portrait_rect.position = Vector2(4, (BOX_H - PORTRAIT_S) / 2.0)
	_portrait_rect.color = Color(0.15, 0.10, 0.04, 1.0)
	_box_root.add_child(_portrait_rect)

	# Portrait border
	var pbrd := Panel.new()
	pbrd.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbrd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psty := StyleBoxFlat.new()
	psty.bg_color = Color(0,0,0,0)
	psty.draw_center = false
	psty.border_color = C_BORDER
	psty.set_border_width_all(1)
	pbrd.add_theme_stylebox_override("panel", psty)
	_portrait_rect.add_child(pbrd)

	# Portrait label (fallback initials if no texture)
	var port_lbl := Label.new()
	port_lbl.text = _speaker.substr(0, 2).to_upper()
	port_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	port_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	port_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	port_lbl.add_theme_font_size_override("font_size", 14)
	port_lbl.add_theme_color_override("font_color", C_BORDER)
	port_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.add_child(port_lbl)

	# Load portrait texture if available
	if portrait_key != "":
		var tex_path := "res://assets/sprites/npc/%s_portrait.png" % portrait_key
		if ResourceLoader.exists(tex_path):
			var tex_rect := TextureRect.new()
			tex_rect.texture = load(tex_path)
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_portrait_rect.add_child(tex_rect)

	# Speaker name
	_name_label = Label.new()
	_name_label.position = Vector2(TEXT_X, 4)
	_name_label.size = Vector2(TEXT_W, 10)
	_name_label.add_theme_font_size_override("font_size", 7)
	_name_label.add_theme_color_override("font_color", C_NAME)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.text = _speaker
	_box_root.add_child(_name_label)

	# Divider under name
	var div := ColorRect.new()
	div.color    = C_BORDER_D
	div.size     = Vector2(TEXT_W, 1)
	div.position = Vector2(TEXT_X, 14)
	_box_root.add_child(div)

	# Dialogue text body
	_text_label = Label.new()
	_text_label.position = Vector2(TEXT_X, 17)
	_text_label.size = Vector2(TEXT_W, TEXT_H - 18)
	_text_label.add_theme_font_size_override("font_size", 6)
	_text_label.add_theme_color_override("font_color", C_TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_root.add_child(_text_label)

	# Advance hint
	_hint_label = Label.new()
	_hint_label.position = Vector2(BOX_W - 60, BOX_H - 10)
	_hint_label.size = Vector2(56, 8)
	_hint_label.add_theme_font_size_override("font_size", 5)
	_hint_label.add_theme_color_override("font_color", C_HINT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_root.add_child(_hint_label)

	# Slide up from below
	_box_root.position.y = float(VP_H)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUART)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_box_root, "position:y", float(BOX_Y), 0.20)

func _show_line(idx: int) -> void:
	if not is_instance_valid(_text_label):
		return
	var text: String = _lines[idx] if idx < _lines.size() else ""
	_text_label.text = text
	var more := idx < _lines.size() - 1
	_hint_label.text = "[E] Continue..." if more else "[E] Close"
	dialogue_advanced.emit(idx)

func _advance_line() -> void:
	_line_idx += 1
	if _line_idx >= _lines.size():
		_close_box()
	else:
		_show_line(_line_idx)

func _close_box() -> void:
	_open = false
	_mode = ""
	if is_instance_valid(_box_root):
		var tw := create_tween()
		tw.tween_property(_box_root, "position:y", float(VP_H), 0.15)
		await tw.finished
		_box_root.queue_free()
		_box_root = null
	dialogue_finished.emit()
