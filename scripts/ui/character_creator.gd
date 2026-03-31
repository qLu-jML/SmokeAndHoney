# character_creator.gd -- New-game character setup screen.
# GDD S3.0a: Name, pronouns, backstory selection before first play.
# Presented after MainMenu "New Game" click, before home_property loads.
extends CanvasLayer

signal creator_finished

# -- Layout constants ----------------------------------------------------------
const PANEL_W   := 260
const PANEL_H   := 156
const PANEL_X   := 30     # (320-260)/2
const PANEL_Y   := 12     # (180-156)/2
const FONT_SM   := 7
const FONT_MD   := 8
const FONT_LG   := 9

# -- Pronoun presets -----------------------------------------------------------
const PRONOUN_PRESETS: Array = ["they/them", "she/her", "he/him"]
var _pronoun_idx: int = 0    # Index into PRONOUN_PRESETS

# -- Backstory options --------------------------------------------------------
const BACKSTORY_OPTIONS: Array = ["Newcomer", "Hobbyist", "Farmer"]
const BACKSTORY_TAGS: Array    = ["newcomer", "hobbyist", "farmer"]
const BACKSTORY_DESCS: Array   = [
    "City dweller starting fresh in Cedar Bend.",
    "Long-time hobbyist beekeeper going full-time.",
    "Farm background -- comfortable with the land.",
]
var _backstory_idx: int = 0

# -- Name input ----------------------------------------------------------------
const NAME_MAX := 18
var _player_name: String = ""
var _name_cursor_blink: float = 0.0
var _name_cursor_visible: bool = true

# -- Focus section (0=name, 1=pronouns, 2=backstory, 3=confirm) ---------------
var _focus: int = 0

# -- UI refs -------------------------------------------------------------------
var _name_lbl:      Label = null
var _pronoun_lbl:   Label = null
var _backstory_lbl: Label = null
var _desc_lbl:      Label = null
var _confirm_lbl:   Label = null
var _err_lbl:       Label = null
var _err_timer:     float = 0.0

# -- Section highlight rects ---------------------------------------------------
var _section_bgs: Array = []   # 4 ColorRects (name, pronouns, backstory, confirm)

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
    layer = 20
    get_tree().paused = true
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()
    _refresh()

func _process(delta: float) -> void:
    _name_cursor_blink += delta
    if _name_cursor_blink >= 0.5:
        _name_cursor_blink = 0.0
        _name_cursor_visible = not _name_cursor_visible
        if _focus == 0:
            _refresh_name()
    if _err_timer > 0.0:
        _err_timer -= delta
        if _err_timer <= 0.0 and _err_lbl:
            _err_lbl.text = ""

# -- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        get_viewport().set_input_as_handled()
        _handle_key(event)

func _handle_key(event: InputEventKey) -> void:
    match _focus:
        0:  # Name entry
            _handle_name_input(event)
        1:  # Pronouns
            _handle_choice_input(event, "pronoun")
        2:  # Backstory
            _handle_choice_input(event, "backstory")
        3:  # Confirm
            if event.keycode == KEY_E or event.keycode == KEY_ENTER:
                _try_confirm()

    # Tab / W / S to move between sections
    if event.keycode == KEY_TAB or event.keycode == KEY_S:
        if not (event.shift_pressed):
            _focus = (_focus + 1) % 4
            _refresh()
    if event.keycode == KEY_W:
        _focus = (_focus - 1 + 4) % 4
        _refresh()

func _handle_name_input(event: InputEventKey) -> void:
    if event.keycode == KEY_BACKSPACE:
        if _player_name.length() > 0:
            _player_name = _player_name.substr(0, _player_name.length() - 1)
        _refresh_name()
        return
    if event.keycode == KEY_ENTER or event.keycode == KEY_E:
        _focus = 1
        _refresh()
        return
    # Accept printable characters
    var ch: String = event.as_text_keycode()
    if ch.length() == 1 and _player_name.length() < NAME_MAX:
        _player_name += ch
        _refresh_name()

func _handle_choice_input(event: InputEventKey, section: String) -> void:
    if event.keycode == KEY_A or event.keycode == KEY_LEFT:
        if section == "pronoun":
            _pronoun_idx = (_pronoun_idx - 1 + PRONOUN_PRESETS.size()) % PRONOUN_PRESETS.size()
        else:
            _backstory_idx = (_backstory_idx - 1 + BACKSTORY_OPTIONS.size()) % BACKSTORY_OPTIONS.size()
        _refresh()
    elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
        if section == "pronoun":
            _pronoun_idx = (_pronoun_idx + 1) % PRONOUN_PRESETS.size()
        else:
            _backstory_idx = (_backstory_idx + 1) % BACKSTORY_OPTIONS.size()
        _refresh()
    elif event.keycode == KEY_E or event.keycode == KEY_ENTER:
        _focus = 2 if section == "pronoun" else 3
        _refresh()

func _try_confirm() -> void:
    var name_trimmed: String = _player_name.strip_edges()
    if name_trimmed.length() < 2:
        _show_err("Please enter a name (at least 2 characters).")
        _focus = 0
        _refresh()
        return
    # Apply to PlayerData
    PlayerData.player_name = name_trimmed
    PlayerData.backstory_tag = BACKSTORY_TAGS[_backstory_idx]
    PlayerData.character_created = true
    match _pronoun_idx:
        0: PlayerData.set_pronouns_they_them()
        1: PlayerData.set_pronouns_she_her()
        2: PlayerData.set_pronouns_he_him()
    get_tree().paused = false
    creator_finished.emit()
    queue_free()

func _show_err(msg: String) -> void:
    if _err_lbl:
        _err_lbl.text = msg
        _err_timer = 3.0

# -- Refresh -------------------------------------------------------------------

func _refresh() -> void:
    _refresh_name()
    _refresh_pronouns()
    _refresh_backstory()
    _refresh_sections()

func _refresh_name() -> void:
    if _name_lbl == null:
        return
    var cursor: String = "|" if (_focus == 0 and _name_cursor_visible) else ""
    var display: String = _player_name if _player_name.length() > 0 else ""
    _name_lbl.text = "Name: %s%s" % [display, cursor]

func _refresh_pronouns() -> void:
    if _pronoun_lbl == null:
        return
    var l: String = "< " if _pronoun_idx > 0 else "  "
    var r: String = " >" if _pronoun_idx < PRONOUN_PRESETS.size() - 1 else "  "
    _pronoun_lbl.text = "Pronouns: %s%s%s" % [l, PRONOUN_PRESETS[_pronoun_idx], r]

func _refresh_backstory() -> void:
    if _backstory_lbl == null or _desc_lbl == null:
        return
    var l: String = "< " if _backstory_idx > 0 else "  "
    var r: String = " >" if _backstory_idx < BACKSTORY_OPTIONS.size() - 1 else "  "
    _backstory_lbl.text = "Story: %s%s%s" % [l, BACKSTORY_OPTIONS[_backstory_idx], r]
    _desc_lbl.text = BACKSTORY_DESCS[_backstory_idx]

func _refresh_sections() -> void:
    for i in _section_bgs.size():
        var bg: ColorRect = _section_bgs[i]
        if is_instance_valid(bg):
            bg.color = Color(0.25, 0.22, 0.10, 1.0) if i == _focus else Color(0.12, 0.12, 0.12, 1.0)
    if is_instance_valid(_confirm_lbl):
        _confirm_lbl.modulate = Color(0.4, 0.9, 0.4, 1.0) if _focus == 3 else Color(0.8, 0.75, 0.55, 1.0)

# -- UI construction -----------------------------------------------------------

func _build_ui() -> void:
    # -- Dim backdrop
    var dim := ColorRect.new()
    dim.anchor_right  = 1.0
    dim.anchor_bottom = 1.0
    dim.color         = Color(0, 0, 0, 0.78)
    dim.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(dim)

    # -- Main panel
    var panel := ColorRect.new()
    panel.position = Vector2(PANEL_X, PANEL_Y)
    panel.size     = Vector2(PANEL_W, PANEL_H)
    panel.color    = Color(0.07, 0.06, 0.05, 0.97)
    add_child(panel)

    # -- Border
    var border := Panel.new()
    border.position = Vector2(PANEL_X, PANEL_Y)
    border.size     = Vector2(PANEL_W, PANEL_H)
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sty := StyleBoxFlat.new()
    sty.bg_color            = Color(0, 0, 0, 0)
    sty.draw_center         = false
    sty.border_color        = Color(0.75, 0.60, 0.20, 1.0)
    sty.border_width_left   = 1
    sty.border_width_right  = 1
    sty.border_width_top    = 1
    sty.border_width_bottom = 1
    border.add_theme_stylebox_override("panel", sty)
    add_child(border)

    # -- Title
    var title: Label = _make_label("-- WHO ARE YOU? --", FONT_LG, Color(0.95, 0.80, 0.30, 1.0))
    title.position             = Vector2(PANEL_X, PANEL_Y + 5)
    title.custom_minimum_size  = Vector2(PANEL_W, 12)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(title)

    # -- Divider
    var div := ColorRect.new()
    div.position = Vector2(PANEL_X + 4, PANEL_Y + 19)
    div.size     = Vector2(PANEL_W - 8, 1)
    div.color    = Color(0.75, 0.60, 0.20, 0.5)
    add_child(div)

    # -- Section backgrounds (highlight active section)
    var section_y: Array = [PANEL_Y + 22, PANEL_Y + 50, PANEL_Y + 78, PANEL_Y + 124]
    var section_h: Array = [26, 26, 44, 18]
    for i in 4:
        var bg := ColorRect.new()
        bg.position = Vector2(PANEL_X + 4, section_y[i])
        bg.size     = Vector2(PANEL_W - 8, section_h[i])
        bg.color    = Color(0.12, 0.12, 0.12, 1.0)
        add_child(bg)
        _section_bgs.append(bg)

    # -- Name section
    _name_lbl = _make_label("Name: |", FONT_MD, Color(0.95, 0.92, 0.85, 1.0))
    _name_lbl.position            = Vector2(PANEL_X + 8, PANEL_Y + 24)
    _name_lbl.custom_minimum_size = Vector2(PANEL_W - 16, 10)
    add_child(_name_lbl)
    var name_hint: Label = _make_label("Type name, then Tab or S to continue", FONT_SM,
                                        Color(0.55, 0.55, 0.55, 1.0))
    name_hint.position            = Vector2(PANEL_X + 8, PANEL_Y + 36)
    name_hint.custom_minimum_size = Vector2(PANEL_W - 16, 9)
    add_child(name_hint)

    # -- Pronouns section
    _pronoun_lbl = _make_label("Pronouns: they/them", FONT_MD, Color(0.95, 0.92, 0.85, 1.0))
    _pronoun_lbl.position            = Vector2(PANEL_X + 8, PANEL_Y + 52)
    _pronoun_lbl.custom_minimum_size = Vector2(PANEL_W - 16, 10)
    add_child(_pronoun_lbl)
    var pron_hint: Label = _make_label("A/D or Left/Right to change", FONT_SM,
                                        Color(0.55, 0.55, 0.55, 1.0))
    pron_hint.position            = Vector2(PANEL_X + 8, PANEL_Y + 64)
    pron_hint.custom_minimum_size = Vector2(PANEL_W - 16, 9)
    add_child(pron_hint)

    # -- Backstory section
    _backstory_lbl = _make_label("Story: Newcomer", FONT_MD, Color(0.95, 0.92, 0.85, 1.0))
    _backstory_lbl.position            = Vector2(PANEL_X + 8, PANEL_Y + 80)
    _backstory_lbl.custom_minimum_size = Vector2(PANEL_W - 16, 10)
    add_child(_backstory_lbl)
    _desc_lbl = _make_label("", FONT_SM, Color(0.75, 0.72, 0.60, 1.0))
    _desc_lbl.position            = Vector2(PANEL_X + 8, PANEL_Y + 92)
    _desc_lbl.custom_minimum_size = Vector2(PANEL_W - 16, 18)
    _desc_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
    add_child(_desc_lbl)

    # -- Divider before confirm
    var div2 := ColorRect.new()
    div2.position = Vector2(PANEL_X + 4, PANEL_Y + 122)
    div2.size     = Vector2(PANEL_W - 8, 1)
    div2.color    = Color(0.75, 0.60, 0.20, 0.5)
    add_child(div2)

    # -- Confirm button
    _confirm_lbl = _make_label("[E] Begin Your Story", FONT_MD, Color(0.8, 0.75, 0.55, 1.0))
    _confirm_lbl.position              = Vector2(PANEL_X, PANEL_Y + 126)
    _confirm_lbl.custom_minimum_size   = Vector2(PANEL_W, 12)
    _confirm_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_confirm_lbl)

    # -- Hint
    var hint: Label = _make_label("W/S Navigate   A/D Select   E/Enter Confirm", FONT_SM,
                                    Color(0.50, 0.50, 0.50, 1.0))
    hint.position              = Vector2(PANEL_X, PANEL_Y + 141)
    hint.custom_minimum_size   = Vector2(PANEL_W, 9)
    hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
    add_child(hint)

    # -- Error label
    _err_lbl = _make_label("", FONT_SM, Color(0.95, 0.50, 0.30, 1.0))
    _err_lbl.position              = Vector2(PANEL_X, PANEL_Y + 148)
    _err_lbl.custom_minimum_size   = Vector2(PANEL_W, 9)
    _err_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_err_lbl)

func _make_label(text_val: String, fsize: int, col: Color) -> Label:
    var l := Label.new()
    l.text = text_val
    l.add_theme_font_size_override("font_size", fsize)
    l.add_theme_color_override("font_color", col)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l
