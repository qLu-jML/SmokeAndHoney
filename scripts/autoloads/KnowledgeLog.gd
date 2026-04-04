# KnowledgeLog.gd -- Two-tab knowledge journal autoload.
# Tab 1: "Beekeeper's Notebook" -- skills & knowledge entries unlocked by play
# Tab 2: "Hive Records" -- per-hive management log with player observations
# Autoloaded as "KnowledgeLog" in project.godot.
extends Node

# -- Notebook Entries (Tab 1) --------------------------------------------------
# Each entry: {id, title, body, category, unlocked}
# Categories: "basics", "disease", "harvest", "seasonal", "advanced"
var notebook_entries: Array = []

# -- Hive Records (Tab 2) -----------------------------------------------------
# Dictionary keyed by hive node path or custom name.
# Each value: Array of record entries:
#   {day, month, action, details, player_note}
var hive_records: Dictionary = {}

# -- Observation tracking for "Keen Observer" reward ---------------------------
var total_inspections: int = 0
var inspections_with_notes: int = 0

# -- Signals -------------------------------------------------------------------
signal entry_unlocked(entry_id: String)
signal record_added(hive_key: String)

# =========================================================================
# NOTEBOOK (TAB 1)
# =========================================================================

func _ready() -> void:
	_init_notebook_entries()

## Initialize all possible notebook entries (locked by default).
func _init_notebook_entries() -> void:
	notebook_entries = [
		{"id": "bee_biology", "title": "Bee Biology Basics", "body": "A honey bee colony has three castes: queen (one, lays eggs), workers (thousands, do everything), and drones (males, for mating). Workers live 4-6 weeks in summer, months in winter.", "category": "basics", "unlocked": false},
		{"id": "hive_components", "title": "Langstroth Hive Parts", "body": "Bottom board (floor), deep bodies (brood chamber), queen excluder (keeps queen in deeps), honey supers (harvest boxes), inner cover, outer cover. Each box holds 10 frames.", "category": "basics", "unlocked": false},
		{"id": "frame_reading", "title": "Reading a Frame", "body": "A healthy brood frame shows a solid pattern: capped brood in the center, open larva around it, eggs at the edges, pollen and honey arcing above. Scattered brood = trouble.", "category": "basics", "unlocked": false},
		{"id": "seasonal_cycle", "title": "The Beekeeping Year", "body": "Quickening: colony builds up. Greening-High Sun: nectar flow, add supers. Full Earth-Reaping: harvest, treat mites, prepare for winter. Deepcold-Kindlemonth: minimal intervention, monitor stores.", "category": "seasonal", "unlocked": false},
		{"id": "the_mite_problem", "title": "The Mite Problem", "body": "Varroa destructor is a parasitic mite that feeds on bee fat bodies and spreads viruses. Every colony has mites. Monitoring and treatment are essential -- not optional. Untreated colonies collapse within 1-2 years.", "category": "disease", "unlocked": false},
		{"id": "alcohol_wash", "title": "The Alcohol Wash", "body": "Scoop ~300 nurse bees from a brood frame into a jar with rubbing alcohol. Shake for 2 minutes. Strain: count mites on white surface. Under 1/100 = low, 1-3/100 = monitor, over 3/100 = treat now.", "category": "disease", "unlocked": false},
		{"id": "treatment_options", "title": "Mite Treatments", "body": "Oxalic acid: 90% effective, best when colony is broodless (winter). Formic acid: 70% effective, penetrates capped brood, temperature-dependent (50-85F). Always re-test 2-3 weeks after treating.", "category": "disease", "unlocked": false},
		{"id": "afb_awareness", "title": "American Foulbrood", "body": "AFB is caused by Paenibacillus larvae spores. Symptoms: sunken/perforated cappings, ropy larval remains (matchstick test), foul smell. There is no cure -- infected equipment must be burned to prevent spread.", "category": "disease", "unlocked": false},
		{"id": "honey_harvest", "title": "Harvesting Honey", "body": "Harvest when supers are 80%+ capped. Remove supers, uncap frames with knife or scratcher, spin in extractor, strain into bucket, bottle. Never harvest brood frames or frames with feed-honey.", "category": "harvest", "unlocked": false},
		{"id": "comb_honey", "title": "Comb vs Extracted Honey", "body": "Extracted honey: frames are uncapped, spun, and returned to the hive. Cut comb: entire sections of honeycomb sold as-is -- premium product. Both have their market.", "category": "harvest", "unlocked": false},
		{"id": "feeding_bees", "title": "Sugar Syrup Feeding", "body": "Feed 1:1 sugar syrup in spring to stimulate buildup. Feed 2:1 in fall to boost winter stores. Feed stores are NOT sellable honey -- frames with feed must be flagged.", "category": "basics", "unlocked": false},
		{"id": "queen_spotting", "title": "Finding the Queen", "body": "The queen is larger, with a longer abdomen and shorter wings relative to body. She moves deliberately. Look for the 'court' -- workers facing inward around her. Mark queens with year-color dots.", "category": "basics", "unlocked": false},
		{"id": "winter_prep", "title": "Winter Preparation", "body": "Colony needs 60+ lbs honey, low mite load (under 3/100), and a healthy queen. Reduce entrance to mouse guard width. Remove empty supers. Check weight monthly through winter.", "category": "seasonal", "unlocked": false},
		{"id": "spring_buildup", "title": "Spring Management", "body": "As days lengthen, queen increases laying. Monitor food stores -- spring starvation is common. Feed if stores drop below 15 lbs. Add supers before nectar flow starts.", "category": "seasonal", "unlocked": false},
		{"id": "swarm_prevention", "title": "Swarm Instinct", "body": "Congested hives build queen cells and swarm -- half the colony leaves. Add space (supers), rotate brood boxes, and ensure good ventilation. Swarm traps can catch departing swarms.", "category": "advanced", "unlocked": false},
		{"id": "queen_rearing", "title": "Queen Rearing Basics", "body": "Emergency queens are raised when a colony loses its queen. Grafting and cell-builder methods let beekeepers raise queens intentionally. Quality queens are the foundation of healthy colonies.", "category": "advanced", "unlocked": false},
	]

## Unlock a notebook entry by ID. Returns true if newly unlocked.
func unlock_entry(entry_id: String) -> bool:
	for entry in notebook_entries:
		if entry["id"] == entry_id and not entry["unlocked"]:
			entry["unlocked"] = true
			entry_unlocked.emit(entry_id)
			return true
	return false

## Get all unlocked notebook entries.
func get_unlocked_entries() -> Array:
	var result: Array = []
	for entry in notebook_entries:
		if entry["unlocked"]:
			result.append(entry)
	return result

## Check if a specific entry is unlocked.
func is_unlocked(entry_id: String) -> bool:
	for entry in notebook_entries:
		if entry["id"] == entry_id:
			return entry["unlocked"]
	return false

# =========================================================================
# HIVE RECORDS (TAB 2)
# =========================================================================

## Add a record entry for a specific hive.
func add_hive_record(hive_key: String, action: String, details: String) -> void:
	if not hive_records.has(hive_key):
		hive_records[hive_key] = []
	var record: Dictionary = {
		"day": TimeManager.current_day if TimeManager else 0,
		"month": TimeManager.current_month_index() if TimeManager and TimeManager.has_method("current_month_index") else 0,
		"action": action,
		"details": details,
		"player_note": "",
	}
	hive_records[hive_key].append(record)
	record_added.emit(hive_key)

## Get all records for a specific hive.
func get_hive_records(hive_key: String) -> Array:
	return hive_records.get(hive_key, [])

## Set player note on the most recent record for a hive.
func set_last_note(hive_key: String, note: String) -> void:
	if not hive_records.has(hive_key):
		return
	var records: Array = hive_records[hive_key]
	if records.size() > 0:
		records[records.size() - 1]["player_note"] = note

## Track inspection observation for Keen Observer reward.
func track_inspection(has_note: bool) -> void:
	total_inspections += 1
	if has_note:
		inspections_with_notes += 1

## Check if player qualifies for Keen Observer bonus (80%+ notes on inspections).
func is_keen_observer() -> bool:
	if total_inspections < 5:
		return false
	return float(inspections_with_notes) / float(total_inspections) >= 0.8

# =========================================================================
# SAVE / LOAD
# =========================================================================

func collect_save_data() -> Dictionary:
	var unlocked_ids: Array = []
	for entry in notebook_entries:
		if entry["unlocked"]:
			unlocked_ids.append(entry["id"])
	return {
		"unlocked_ids": unlocked_ids,
		"hive_records": hive_records.duplicate(true),
		"total_inspections": total_inspections,
		"inspections_with_notes": inspections_with_notes,
	}

func apply_save_data(data: Dictionary) -> void:
	var ids: Array = data.get("unlocked_ids", [])
	for entry in notebook_entries:
		entry["unlocked"] = entry["id"] in ids
	hive_records = data.get("hive_records", {}).duplicate(true)
	total_inspections = int(data.get("total_inspections", 0))
	inspections_with_notes = int(data.get("inspections_with_notes", 0))
