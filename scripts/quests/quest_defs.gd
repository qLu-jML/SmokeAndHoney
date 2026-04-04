# quest_defs.gd -- Static quest definition data for Smoke & Honey.
# Each quest is a Dictionary with: title, hint, season, xp_reward,
# completion_event (the notify_event id that completes it),
# next_quest (id of the quest to auto-start on completion),
# return_to_bob (if true, prompt player to talk to Bob after completing),
# chain (which NPC chain this belongs to),
# and optional start_conditions checked on day_advanced.
#
# Year 1 Chains:
#   Bob:     bob_intro -> first_light -> reading_the_room -> girls_are_building
#            -> first_pull -> battening_down
#   Darlene: darlene_over_the_fence -> darlene_marked_queen
#   Frank:   frank_first_jar -> frank_saturday_regulars
#   Silas:   silas_old_honey_house -> silas_gathering_materials -> silas_raising_the_roof
#   Ellen:   ellen_first_hive -> ellen_colony_dynamics -> ellen_health_monitoring
#   Carl:    carl_new_customer -> carl_bulletin_board
#   Rose:    rose_honey_in_coffee
#   June:    june_buzzing_box
#   CVBA:    cvba_the_new_kid
#
# Player arrives mid-Greening (day 43) when dandelions are blooming.
# No spring feeding needed -- feeding is taught in Fall (battening_down).
extends RefCounted
class_name QuestDefs

# -- All Year 1 Quest Definitions -----------------------------------------------

const QUESTS: Dictionary = {
	# =========================================================================
	# UNCLE BOB CHAIN (Y1 spine -- extended tutorial)
	# =========================================================================

	# -- Q0: Meet Uncle Bob (gatekeeper -- blocks all other quests) ----------
	"bob_intro": {
		"title": "Meet Uncle Bob",
		"hint": "Go talk to Uncle Bob -- he is waiting for you.",
		"description": "You just arrived in Cedar Bend. Uncle Bob is out by the hives. Go introduce yourself and find out what he needs help with.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "bob_intro_complete",
		"next_quest": "first_light",
		"return_to_bob": false,
		"chain": "bob",
		"start_conditions": {},
	},
	# -- Q1: First Light (smoke + inspect 3 frames) -------------------------
	"first_light": {
		"title": "First Light",
		"hint": "Smoke the hive and inspect at least 3 frames.",
		"description": "Uncle Bob wants you to see what is happening inside the surviving hive. Smoke it first to calm the bees, then open it with the hive tool and look at 3 or more frames.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "first_inspection_3_frames",
		"next_quest": "reading_the_room",
		"return_to_bob": true,
		"chain": "bob",
		"start_conditions": {},
	},
	# -- Q2: Reading the Room (full 10-frame inspection) --------------------
	"reading_the_room": {
		"title": "Reading the Room",
		"hint": "Do a full inspection -- check all the frames, both sides.",
		"description": "Bob wants to know what you see. Do a thorough inspection of the entire brood box. Check every frame, front and back. Look for the brood pattern, honey stores, and anything unusual.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "full_inspection_complete",
		"next_quest": "girls_are_building",
		"return_to_bob": true,
		"chain": "bob",
		"start_conditions": {},
	},
	# -- Q3: The Girls Are Building (add honey super) -----------------------
	"girls_are_building": {
		"title": "The Girls Are Building",
		"hint": "Add a honey super to give the colony room to grow.",
		"description": "The dandelion flow is filling the brood box. The colony needs more space or they will swarm. Grab a super from the chest and add it to the hive.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "super_added",
		"next_quest": "first_pull",
		"return_to_bob": true,
		"chain": "bob",
		"start_conditions": {},
	},
	# -- Q4: First Pull (harvest honey) -- month-gated to Wide-Clover ------
	"first_pull": {
		"title": "First Pull",
		"hint": "Harvest honey from a capped super.",
		"description": "The clover is flowing and your supers are heavy. Time to pull your first honey -- uncap, extract, and bottle it. Bring a jar to Bob when you are done.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "harvest_complete",
		"next_quest": "battening_down",
		"return_to_bob": true,
		"chain": "bob",
		"start_conditions": {
			"min_month": 2,
		},
	},
	# -- Q5: Battening Down (winterize + feeding education) -- Fall ---------
	"battening_down": {
		"title": "Battening Down",
		"hint": "Prepare for winter: treat mites, check stores, feed if needed.",
		"description": "Winter is coming. Do an alcohol wash to check mite levels. Treat if the count is high. Then weigh the hive -- if stores are below 60 lbs, buy sugar from Tanner's and install a feeder bucket with 2:1 syrup. This is the real work of beekeeping.",
		"season": "Fall",
		"xp_reward": 100,
		"completion_event": "winter_ready",
		"next_quest": "",
		"return_to_bob": true,
		"chain": "bob",
		"start_conditions": {
			"min_month": 4,
		},
	},

	# =========================================================================
	# DARLENE KOWALSKI CHAIN (Y1 -- neighbor, observation, foreshadowing)
	# =========================================================================

	# -- Darlene Q1: Over the Fence ------------------------------------------
	"darlene_over_the_fence": {
		"title": "Over the Fence",
		"hint": "Visit Darlene next door -- she wants to show you something.",
		"description": "Darlene Kowalski keeps six hives on the other side of the fence. She has been watching you work and wants to meet properly. Walk over to her property and see what she has to say.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "darlene_fence_visit",
		"next_quest": "darlene_marked_queen",
		"return_to_bob": false,
		"chain": "darlene",
		"start_conditions": {
			"requires_complete": "reading_the_room",
		},
	},
	# -- Darlene Q2: The Marked Queen ----------------------------------------
	"darlene_marked_queen": {
		"title": "The Marked Queen",
		"hint": "Find the queen in your hive and mark her.",
		"description": "Darlene says a marked queen is easier to track and proves you know your hive. Find Her Majesty during an inspection and mark her using the international color system. You need to do it in one session.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "queen_marked",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "darlene",
		"start_conditions": {
			"min_queen_sightings": 3,
		},
	},

	# =========================================================================
	# FRANK FISCHBACH CHAIN (Y1 -- market economics, presentation)
	# =========================================================================

	# -- Frank Q1: First Jar -------------------------------------------------
	"frank_first_jar": {
		"title": "First Jar",
		"hint": "Bring your honey to Saturday Market and talk to Frank.",
		"description": "You have honey in jars. Frank Fischbach runs the Saturday Market and has a spot for you. Bring at least 3 jars and sell one. Frank will tell you what he thinks of your presentation.",
		"season": "Summer",
		"xp_reward": 50,
		"completion_event": "first_market_sale",
		"next_quest": "frank_saturday_regulars",
		"return_to_bob": false,
		"chain": "frank",
		"start_conditions": {
			"requires_complete": "first_pull",
		},
	},
	# -- Frank Q2: The Saturday Regulars -------------------------------------
	"frank_saturday_regulars": {
		"title": "The Saturday Regulars",
		"hint": "Attend 4 Saturday Markets in a row. Sell 2 products. Earn $50.",
		"description": "Frank says consistency matters more than perfection. Show up four Saturdays in a row, sell at least two different products, and earn $50 total. Prove you are serious about this.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "saturday_regulars_done",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "frank",
		"start_conditions": {},
	},

	# =========================================================================
	# SILAS CRENSHAW CHAIN (Y1 -- Honey House restoration)
	# =========================================================================

	# -- Silas Q1: The Old Honey House ---------------------------------------
	"silas_old_honey_house": {
		"title": "The Old Honey House",
		"hint": "Examine the old Honey House, then visit Silas at his workshop.",
		"description": "There is a dilapidated building behind the property -- the old Honey House. It has not been used in years. Examine it, then find Silas Crenshaw at his workshop behind the hardware store. He built the original. Maybe he can fix it.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "silas_honey_house_assessed",
		"next_quest": "silas_gathering_materials",
		"return_to_bob": false,
		"chain": "silas",
		"start_conditions": {
			"requires_complete": "first_light",
		},
	},
	# -- Silas Q2: Gathering Materials ---------------------------------------
	"silas_gathering_materials": {
		"title": "Gathering Materials",
		"hint": "Collect lumber, nails, roofing felt, and $150 for Silas.",
		"description": "Silas gave you a materials list: 20 boards of lumber, 5 lbs of nails, 2 rolls of roofing felt, and $150 cash for his labor. Gather everything and deliver it to the Honey House site.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "silas_materials_delivered",
		"next_quest": "silas_raising_the_roof",
		"return_to_bob": false,
		"chain": "silas",
		"start_conditions": {},
	},
	# -- Silas Q3: Raising the Roof ------------------------------------------
	"silas_raising_the_roof": {
		"title": "Raising the Roof",
		"hint": "Help Silas with the final day of construction.",
		"description": "Silas has been working on the Honey House for a week. Today is the last day and he needs an extra pair of hands. Help him with three tasks: hold a beam steady, hand up roofing materials, and hang the new door.",
		"season": "Summer",
		"xp_reward": 100,
		"completion_event": "honey_house_restored",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "silas",
		"start_conditions": {
			"days_after_previous": 7,
		},
	},

	# =========================================================================
	# DR. ELLEN HARWICK MILESTONE CHAIN (Y1 -- science track)
	# =========================================================================

	# -- Ellen M1: The First Hive --------------------------------------------
	"ellen_first_hive": {
		"title": "The First Hive",
		"hint": "Visit Dr. Harwick at the extension office.",
		"description": "Dr. Ellen Harwick runs the county extension office. She handles livestock health, bees included. Now that you have a hive of your own, she wants to meet you and talk about proper smoker science.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "ellen_first_visit",
		"next_quest": "ellen_colony_dynamics",
		"return_to_bob": false,
		"chain": "ellen",
		"start_conditions": {
			"requires_complete": "first_light",
		},
	},
	# -- Ellen M2: Colony Dynamics -------------------------------------------
	"ellen_colony_dynamics": {
		"title": "Colony Dynamics",
		"hint": "Inspect both hives in one session, then report to Dr. Harwick.",
		"description": "Dr. Harwick wants you to compare two colonies side by side. Inspect both hives in the same day -- note differences in growth rate, temperament, and foraging behavior. Then visit her with your findings.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "ellen_colony_comparison",
		"next_quest": "ellen_health_monitoring",
		"return_to_bob": false,
		"chain": "ellen",
		"start_conditions": {
			"min_hive_count": 2,
		},
	},
	# -- Ellen M3: Health Monitoring -----------------------------------------
	"ellen_health_monitoring": {
		"title": "Health Monitoring",
		"hint": "Do an alcohol wash on all your hives and report to Dr. Harwick.",
		"description": "Dr. Harwick wants baseline mite data on every colony. Do an alcohol wash on each hive and record whether the count is above or below the 3 mites per 100 threshold. Bring her the results.",
		"season": "Summer",
		"xp_reward": 75,
		"completion_event": "ellen_health_report",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "ellen",
		"start_conditions": {
			"min_hive_count": 3,
		},
	},

	# =========================================================================
	# CARL TANNER CHAIN (Y1 -- supply line, community bulletin)
	# =========================================================================

	# -- Carl Q1: New Customer -----------------------------------------------
	"carl_new_customer": {
		"title": "New Customer",
		"hint": "Visit Tanner's Feed & Supply and talk to Carl.",
		"description": "Carl Tanner runs the feed store on Main Street. His grandfather opened it in 1952. He has a beekeeping section and he already knows your name -- Bob told him you were coming.",
		"season": "Spring",
		"xp_reward": 25,
		"completion_event": "carl_first_visit",
		"next_quest": "carl_bulletin_board",
		"return_to_bob": false,
		"chain": "carl",
		"start_conditions": {
			"requires_complete": "bob_intro",
		},
	},
	# -- Carl Q2: The Bulletin Board -----------------------------------------
	"carl_bulletin_board": {
		"title": "The Bulletin Board",
		"hint": "Post a swarm-removal notice on the bulletin board at Tanner's.",
		"description": "Carl says the bulletin board is how Cedar Bend talks to itself. Post a notice offering swarm removal -- when spring swarms fly, you want the phone to ring. The board will become a regular source of jobs and news.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "bulletin_board_posted",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "carl",
		"start_conditions": {},
	},

	# =========================================================================
	# ROSE DELACROIX (Y1 -- diner, belonging)
	# =========================================================================

	# -- Rose Q1: Honey in the Coffee ----------------------------------------
	"rose_honey_in_coffee": {
		"title": "Honey in the Coffee",
		"hint": "Bring a jar of honey to Rose at the Crossroads Diner.",
		"description": "Rose Delacroix runs the Crossroads Diner six days a week. Bring her a jar of your honey. She will taste it, consider it for the kitchen, and put a plate in front of you without asking what you want. That is how Cedar Bend says you belong.",
		"season": "Summer",
		"xp_reward": 50,
		"completion_event": "rose_honey_tasted",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "rose",
		"start_conditions": {
			"requires_complete": "first_pull",
		},
	},

	# =========================================================================
	# JUNE WELLMAN (Y1 -- post office, bee acquisition)
	# =========================================================================

	# -- June Q1: The Buzzing Box --------------------------------------------
	"june_buzzing_box": {
		"title": "The Buzzing Box",
		"hint": "Pick up your bee package from June at the post office.",
		"description": "Your bee package has arrived at the Cedar Bend post office. June Wellman has been keeping the buzzing box safe behind the counter. Go collect it before the bees get too warm.",
		"season": "Spring",
		"xp_reward": 50,
		"completion_event": "bee_package_collected",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "june",
		"start_conditions": {
			"requires_complete": "girls_are_building",
		},
	},

	# =========================================================================
	# CVBA -- Cedar Valley Beekeepers Association (Y1 -- community)
	# =========================================================================

	# -- CVBA Q1: The New Kid ------------------------------------------------
	"cvba_the_new_kid": {
		"title": "The New Kid",
		"hint": "Attend 3 CVBA meetings at the Grange Hall.",
		"description": "The Cedar Valley Beekeepers Association meets monthly at the Grange Hall. Show up, listen to the speakers, and introduce yourself. By the third meeting, share an observation from your own hive. That is how you stop being the new kid.",
		"season": "Spring",
		"xp_reward": 75,
		"completion_event": "cvba_three_meetings",
		"next_quest": "",
		"return_to_bob": false,
		"chain": "cvba",
		"start_conditions": {
			"requires_complete": "bob_intro",
		},
	},
}

# -- Chain Definitions ---------------------------------------------------------
# Maps chain name -> ordered list of quest IDs for that chain.

const CHAINS: Dictionary = {
	"bob": [
		"bob_intro", "first_light", "reading_the_room",
		"girls_are_building", "first_pull", "battening_down",
	],
	"darlene": ["darlene_over_the_fence", "darlene_marked_queen"],
	"frank": ["frank_first_jar", "frank_saturday_regulars"],
	"silas": ["silas_old_honey_house", "silas_gathering_materials", "silas_raising_the_roof"],
	"ellen": ["ellen_first_hive", "ellen_colony_dynamics", "ellen_health_monitoring"],
	"carl": ["carl_new_customer", "carl_bulletin_board"],
	"rose": ["rose_honey_in_coffee"],
	"june": ["june_buzzing_box"],
	"cvba": ["cvba_the_new_kid"],
}

# -- Helpers -------------------------------------------------------------------

## Returns true if a quest's start_conditions are met right now.
static func check_start_conditions(quest_id: String) -> bool:
	if not QUESTS.has(quest_id):
		return false
	var conds: Dictionary = QUESTS[quest_id].get("start_conditions", {})
	if conds.is_empty():
		return true
	# Month gate
	if conds.has("min_month"):
		if TimeManager.current_month_index() < conds["min_month"]:
			return false
	# Prerequisite quest completion
	if conds.has("requires_complete"):
		var req: String = conds["requires_complete"]
		if not QuestManager.is_complete(req):
			return false
	# Hive count gate (for Ellen milestones)
	if conds.has("min_hive_count"):
		var needed: int = conds["min_hive_count"]
		if HiveManager.hive_count() < needed:
			return false
	# Queen sighting gate (for Darlene marked queen)
	if conds.has("min_queen_sightings"):
		var needed: int = conds["min_queen_sightings"]
		if QuestManager.get_counter("queen_sightings") < needed:
			return false
	return true

## Returns the ordered list of quest ids in Year 1 chain order (Bob only).
static func year_1_chain() -> Array:
	return CHAINS.get("bob", [])

## Returns all quest IDs across all Y1 chains.
static func all_y1_quests() -> Array:
	var result: Array = []
	for chain_name in CHAINS:
		for qid in CHAINS[chain_name]:
			result.append(qid)
	return result

## Returns the chain name for a given quest, or "" if not found.
static func get_chain(quest_id: String) -> String:
	if QUESTS.has(quest_id):
		return QUESTS[quest_id].get("chain", "")
	return ""

## Returns all side-chain quest IDs (everything except Bob's chain).
static func side_chain_first_quests() -> Array:
	var result: Array = []
	for chain_name in CHAINS:
		if chain_name == "bob":
			continue
		var chain_quests: Array = CHAINS[chain_name]
		if chain_quests.size() > 0:
			result.append(chain_quests[0])
	return result
