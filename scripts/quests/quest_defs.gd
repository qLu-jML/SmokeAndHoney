# quest_defs.gd -- Static quest definition data for Smoke & Honey.
# Each quest is a Dictionary with: title, hint, season, xp_reward,
# completion_event (the notify_event id that completes it),
# next_quest (id of the quest to auto-start on completion),
# and optional start_conditions checked on day_advanced.
extends RefCounted
class_name QuestDefs

# -- Year 1 Quest Chain --------------------------------------------------------
# These five quests form the spine of the first playable year.
# They teach core mechanics in sequence: inspect -> feed -> expand -> harvest
# -> winterize.  Each quest auto-starts the next on completion.

const QUESTS: Dictionary = {
	"first_light": {
		"title": "First Light",
		"hint": "Open your hive and inspect the frames.",
		"description": "Uncle Bob says it is time to look inside. Smoke the hive, pull a frame, and see what the bees have been up to.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "inspection_opened",
		"next_quest": "sugar_water_days",
		"start_conditions": {},
	},
	"sugar_water_days": {
		"title": "Sugar Water Days",
		"hint": "Place a feeder bucket and fill it with sugar syrup.",
		"description": "Your colony is weak after winter. Set out a feeder bucket near the hives and fill it with sugar syrup to help them build up.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "feeder_placed",
		"next_quest": "girls_are_building",
		"start_conditions": {},
	},
	"girls_are_building": {
		"title": "The Girls Are Building",
		"hint": "Add a honey super to give the colony room to grow.",
		"description": "The colony is booming. If you do not add space, they will swarm and you will lose half your workforce. Add a honey super.",
		"season": "Spring",
		"xp_reward": 30,
		"completion_event": "super_added",
		"next_quest": "first_pull",
		"start_conditions": {},
	},
	"first_pull": {
		"title": "First Pull",
		"hint": "Harvest honey from a capped super.",
		"description": "The clover is flowing and your supers are heavy. Time to pull your first honey -- uncap, extract, grade, and bottle it.",
		"season": "Summer",
		"xp_reward": 50,
		"completion_event": "harvest_complete",
		"next_quest": "battening_down",
		"start_conditions": {
			"min_month": 2,
		},
	},
	"battening_down": {
		"title": "Battening Down",
		"hint": "Prepare for winter: 60+ lbs honey and mites under control.",
		"description": "Winter is coming. Your hive needs at least 60 lbs of honey stores and a clean mite wash before the cold sets in.",
		"season": "Fall",
		"xp_reward": 75,
		"completion_event": "winter_ready",
		"next_quest": "",
		"start_conditions": {
			"min_month": 5,
		},
	},
}

# -- Helpers -------------------------------------------------------------------

## Returns true if a quest's start_conditions are met right now.
static func check_start_conditions(quest_id: String) -> bool:
	if not QUESTS.has(quest_id):
		return false
	var conds: Dictionary = QUESTS[quest_id].get("start_conditions", {})
	if conds.is_empty():
		return true
	if conds.has("min_month"):
		if TimeManager.current_month_index() < conds["min_month"]:
			return false
	return true

## Returns the ordered list of quest ids in Year 1 chain order.
static func year_1_chain() -> Array:
	return [
		"first_light",
		"sugar_water_days",
		"girls_are_building",
		"first_pull",
		"battening_down",
	]
