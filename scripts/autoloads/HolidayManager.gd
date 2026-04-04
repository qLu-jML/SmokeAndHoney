# HolidayManager.gd -- Coordinates seasonal holiday events in Cedar Bend.
# Autoloaded as "HolidayManager" in project.godot.
#
# Listens for TimeManager.holiday_started and manages:
#   - Holiday attendance tracking (counters in QuestManager)
#   - Holiday event triggering when player enters town on a holiday
#   - Standing rewards for participation
#   - Year-specific holiday experiences (Y1 = introductory, Y2+ = quest-driven)
#
# The four holidays of Cedar Bend:
#   Quickening Morn  (Greening 12)  -- spring renewal, communal breakfast
#   Founder's Beam   (High-Sun 19)  -- midsummer festival, pie contest, fireworks
#   The Reaping Fire  (Full-Earth 7) -- harvest bonfire, stories, deadfall gathering
#   The Long Table   (Deepcold 21)  -- winter feast, one long table, lanterns
extends Node

# -- Signals -------------------------------------------------------------------
signal holiday_event_ready(holiday_key: String)
signal holiday_event_complete(holiday_key: String)

# -- State ---------------------------------------------------------------------
var today_holiday_key: String = ""      # "" if not a holiday
var holiday_triggered: bool = false     # true once the event has played today
var _dialogue_ui: Node = null

# -- Holiday key mapping (month_index -> key) ----------------------------------
const HOLIDAY_KEYS: Dictionary = {
	1: "quickening_morn",
	3: "founders_beam",
	4: "reaping_fire",
	6: "long_table",
}

# -- Year 1 Holiday Dialogue ---------------------------------------------------
# Each holiday has a multi-beat dialogue sequence for Y1 (the player's first year).
# These are experiential -- the player attends and witnesses Cedar Bend's traditions.

const QUICKENING_MORN_Y1: Array = [
	"The town square is alive at dawn. Tables draped in white cloth, wildflower garlands on every post.",
	"Rose Delacroix is behind a folding table, serving plates of eggs, biscuits, and honeycomb.",
	"She sees you and sets down a plate before you can ask. 'Sit. Eat. You look thin.'",
	"Darlene finds you at the table. 'Good. You came. This is how we start the season.'",
	"She introduces you to the crowd. 'This is Bob's kid. They keep bees now.'",
	"People nod. A few shake your hand. Lloyd tips his cap. Ellen waves from across the square.",
	"Uncle Bob is at the end of the table. He looks tired, but he is smiling.",
	"He lifts a piece of comb -- golden, dripping, from his hive. The first honey of the year.",
	"'This is the tradition,' he says. 'The beekeeper brings the comb. Someday that will be you.'",
	"The sun clears the treeline. The bees are flying. Spring is here.",
]

const FOUNDERS_BEAM_Y1: Array = [
	"Main Street is unrecognizable. Bunting on every rail, flags on every porch, music from a bad PA system.",
	"The Saturday Market is running a special all-day session. Frank is behind his table, grinning.",
	"'Best sales day of the year,' he says. 'Double foot traffic. Triple if the weather holds.'",
	"At the diner, Rose and Darlene are setting up for the pie contest. The rivalry is legendary.",
	"Rose enters honey pie. Darlene enters sour cream raisin -- her grandmother's recipe from 1928.",
	"Carl gives a speech about the founding of Cedar Bend. He tears up at the same part he always does.",
	"Silas stands in the back with his arms crossed. He built the stage they are standing on.",
	"At dusk, fireworks crack over the fairgrounds. The whole town watches from the square.",
	"Uncle Bob watches from a lawn chair. 'Best one yet,' he says. He says that every year.",
	"You realize you are not watching the fireworks. You are watching the town watch the fireworks.",
]

const REAPING_FIRE_Y1: Array = [
	"The town square is stacked with deadfall and dried corn stalks, ten feet high.",
	"Children carry lanterns carved from gourds. The light catches their faces -- wide-eyed, grinning.",
	"Lloyd Petersen is directing the pyre construction. 'Little more on the left. No -- my left.'",
	"At dusk, corn-husk effigies are placed on top. The crowd goes quiet.",
	"Silas strikes the match. The fire catches slow, then roars. Sparks spiral into the dark.",
	"The heat pushes everyone back a step. Then they settle in. Folding chairs, blankets, thermoses.",
	"Lloyd starts talking. The 1994 storm. The roof that came off the grange hall.",
	"Silas interrupts at the same point he always does. 'That was '95, Lloyd.' 'It was '94.'",
	"The argument is the tradition. Nobody settles it. Nobody wants to.",
	"Rose hands you a cup of something warm. 'Cider. My recipe. Do not ask what is in it.'",
	"You sit by the fire until the embers dim. The hives are quiet behind you in the dark.",
	"Tomorrow you will check their stores. Tonight, you just watch the fire die.",
]

const LONG_TABLE_Y1: Array = [
	"The shortest day. The longest night. Snow on everything.",
	"Uncle Bob asks you to help him set the table. Just the two of you.",
	"A white cloth. Two plates. Two glasses. A jar of honey in the center.",
	"'Used to fill this table,' he says. 'When your aunt was alive. Twenty people some years.'",
	"He does not say anything for a while. Then: 'Two is enough.'",
	"Rose stops by with pie. 'I brought enough for an army. You two count as an army.'",
	"Darlene knocks on the door with a bottle of mead and sits down without being asked.",
	"'My grandmother made this every winter,' she says. 'The bees did most of the work.'",
	"The candles burn low. Outside, every window on the street has a single lantern.",
	"Bob tells you about your aunt. How she loved the bees. How she hummed to them.",
	"You wash the dishes together. He dries. Neither of you talks.",
	"The hives are silent under the snow. Inside, the world is warm.",
]

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	TimeManager.holiday_started.connect(_on_holiday_started)
	TimeManager.day_advanced.connect(_on_day_advanced)
	# Check if today is already a holiday (scene reload, save load)
	_check_today()

func _on_day_advanced(_new_day: int) -> void:
	holiday_triggered = false
	_check_today()

func _on_holiday_started(holiday_name: String) -> void:
	# This fires on day advance when it is a holiday
	NotificationManager.notify(holiday_name + " -- Cedar Bend celebrates today!", NotificationManager.T_INFO, 6.0)

func _check_today() -> void:
	var mi: int = TimeManager.current_month_index()
	if HOLIDAY_KEYS.has(mi):
		var h: Variant = TimeManager.get_todays_holiday()
		if h != null:
			today_holiday_key = HOLIDAY_KEYS[mi]
			return
	today_holiday_key = ""

# -- Public API ----------------------------------------------------------------

## Called by scene scripts (cedar_bend, home_property) when the player
## enters a location where the holiday event should trigger.
## Returns true if a holiday event was triggered.
func try_trigger_holiday_event() -> bool:
	if today_holiday_key == "" or holiday_triggered:
		return false
	holiday_triggered = true

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")
	if _dialogue_ui == null or not _dialogue_ui.has_method("show_dialogue"):
		return false

	var lines: Array = _get_holiday_lines()
	if lines.is_empty():
		return false

	var holiday_name: String = TimeManager.get_holiday_name()
	_dialogue_ui.show_dialogue(holiday_name, lines, "")

	# Track attendance and award standing
	_record_attendance()

	holiday_event_complete.emit(today_holiday_key)
	return true

## Returns true if today is a holiday and the event has not yet been triggered.
func is_holiday_pending() -> bool:
	return today_holiday_key != "" and not holiday_triggered

## Returns the current holiday key, or "" if none.
func current_holiday_key() -> String:
	return today_holiday_key

# -- Internal ------------------------------------------------------------------

func _get_holiday_lines() -> Array:
	var year: int = TimeManager.current_year()
	# Year 1 uses the introductory experiences
	# Year 2+ would use quest-driven events (future implementation)
	match today_holiday_key:
		"quickening_morn":
			return QUICKENING_MORN_Y1
		"founders_beam":
			return FOUNDERS_BEAM_Y1
		"reaping_fire":
			return REAPING_FIRE_Y1
		"long_table":
			return LONG_TABLE_Y1
	return []

func _record_attendance() -> void:
	# Increment attendance counter
	var counter_key: String = today_holiday_key + "_attended"
	QuestManager.increment_counter(counter_key)

	# Award standing and XP
	var xp: int = 25
	var standing: int = 15
	if today_holiday_key == "long_table":
		xp = 40
		standing = 25
	GameData.add_xp(xp)
	if GameData.has_method("add_community_standing"):
		GameData.add_community_standing(standing)

	# Notify quest system
	QuestManager.notify_event("holiday_attended", {
		"holiday": today_holiday_key,
		"year": TimeManager.current_year(),
	})

	NotificationManager.notify("+%d XP  +%d Standing" % [xp, standing], NotificationManager.T_XP, 4.0)

# -- Save / Load ---------------------------------------------------------------

func collect_save_data() -> Dictionary:
	return {
		"holiday_triggered": holiday_triggered,
	}

func apply_save_data(data: Dictionary) -> void:
	holiday_triggered = data.get("holiday_triggered", false)
