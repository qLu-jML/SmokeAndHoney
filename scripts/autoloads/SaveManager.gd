# SaveManager.gd -- Singleton that handles all save / load operations.
# ------------------------------------------------------------------------------
# Autoloaded as "SaveManager" in project.godot (after all other autoloads).
#
# SAVE FILE
#   Path : user://smoke_and_honey_save.json   (Godot's platform-safe user dir)
#   Format: pretty-printed JSON
#   Binary cell data (PackedByteArray) is base64-encoded via Marshalls helpers.
#
# SCHEMA  (bump SAVE_VERSION on any backward-incompatible change)
# {
#   "version"          : int,
#   "time"             : { current_day, current_hour },
#   "game_data"        : { money, player_level, xp, reputation, energy,
#                          max_energy, expense_log, meals_eaten,
#                          coffee_until_hour, xp_buff_until_day,
#                          pending_deliveries },
#   "player"           : { position_x, position_y, inventory[] },
#   "hives"            : [ { position_x, position_y, tile_x?, tile_y?,
#                            sim: { days_elapsed, nurse_count, house_count,
#                                   forager_count, drone_count, honey_stores,
#                                   pollen_stores, mite_count, disease_flags[],
#                                   congestion_state, consecutive_congestion,
#                                   queen:{}, boxes:[ {is_super, frames:[
#                                     {cells_b64, cell_age_b64} ]} ] } } ],
#   "flowers"          : [ { position_x, position_y,
#                            current_day, is_seeding } ],
#   "forage_manager"   : { dandelion_outcome, dandelion_density, dandelion_nu,
#                          goldenrod_was_good },
#   "dandelion_spawner": { current_year, current_outcome, current_density,
#                          bloom_day, bloomed, prior_goldenrod_good },
#   "quest_manager"    : { active_quests{}, completed_quests[], quest_notes{} },
#   "npc_flags"        : { uncle_bob_hint_index },
#   "player_data"      : { player_name, pronoun_they, pronoun_them,
#                          pronoun_their, pronoun_theirs, pronoun_themself,
#                          backstory_tag, character_created }
# }
# ------------------------------------------------------------------------------
extends Node

# -- Constants -----------------------------------------------------------------

## Path to the save file.  user:// resolves to a platform-appropriate location
## (%APPDATA%\Godot on Windows, ~/.local/share/godot on Linux, etc.).
const SAVE_PATH    := "user://smoke_and_honey_save.json"

## Integer version.  Bump this when the schema changes in a way that would
## cause an old save to produce incorrect data.  The loader discards saves
## whose version doesn't match and starts a fresh game instead of crashing.
const SAVE_VERSION := 1

# -- Preloaded scenes ----------------------------------------------------------
# Kept here so apply_to_scene() can instantiate hive and flower nodes without
# needing a reference back to the scene root script.
const HIVE_SCENE   := preload("res://scenes/hive.tscn")
const FLOWER_SCENE := preload("res://scenes/flowers/flowers.tscn")

# -- Signals -------------------------------------------------------------------
signal save_completed()
signal load_completed()
signal load_failed(reason: String)

# -- Internal state ------------------------------------------------------------

## Raw Dictionary read from disk during load_from_disk().
## Consumed (and cleared) by apply_to_scene().
var _pending_data:    Dictionary = {}

## True when _pending_data contains valid, version-matched save data that has
## not yet been applied.  home_property.gd checks this flag in _ready().
var has_pending_load: bool = false


# ==============================================================================
# PUBLIC API
# ==============================================================================

## Returns true if a save file already exists on disk.
func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func has_save() -> bool:
	return save_exists()

func save_game() -> bool:
	return save()

## Serialise all game state to user://smoke_and_honey_save.json.
## Returns true on success; false if the file could not be written.
## Called automatically when the player sleeps (hooked in hud.gd).
func save() -> bool:
	var data: Dictionary = {}

	# -- Version header --------------------------------------------------------
	# Written first so a future loader can detect schema mismatches immediately
	# without having to parse the rest of the file.
	data["version"] = SAVE_VERSION

	# -- Time ------------------------------------------------------------------
	# current_day + current_hour is enough to reconstruct the full calendar
	# (month, season, year are all derived from current_day in TimeManager).
	data["time"] = {
		"current_day":  TimeManager.current_day,
		"current_hour": TimeManager.current_hour,
	}

	# -- Player economy, XP, energy, buffs, and pending deliveries -------------
	data["game_data"] = {
		"money":              GameData.money,
		"player_level":       GameData.player_level,
		"xp":                 GameData.xp,
		"reputation":         GameData.reputation,
		"energy":             GameData.energy,
		"max_energy":         GameData.max_energy,
		"expense_log":        GameData.expense_log.duplicate(true),
		"meals_eaten":        GameData.meals_eaten.duplicate(),
		"coffee_until_hour":  GameData.coffee_until_hour,
		"xp_buff_until_day":  GameData.xp_buff_until_day,
		"pending_deliveries": GameData.pending_deliveries.duplicate(true),
	}

	# -- Player node (world position + inventory slots) ------------------------
	var player := _find_player()
	data["player"] = _collect_player(player) if player else {}

	# -- All placed hive nodes -------------------------------------------------
	# Each entry contains the world position, optional tile_coords meta (used
	# for placement-spacing checks), and the full HiveSimulation state:
	# population cohorts, queen data, honey/pollen stores, and the raw
	# PackedByteArray cell/age grids for every frame in every box.
	data["hives"] = _collect_hives()

	# -- All placed flower patches ---------------------------------------------
	# Position plus the flower's own growth counters (current_day, is_seeding)
	# so growth progress is not lost on reload.
	data["flowers"] = _collect_flowers()

	# -- ForageManager -- dandelion annual roll + goldenrod carry-over ----------
	data["forage_manager"] = {
		"dandelion_outcome":  ForageManager.get_dandelion_outcome(),
		"dandelion_density":  ForageManager.get_dandelion_density(),
		"dandelion_nu":       ForageManager._dandelion_nu,
		"goldenrod_was_good": ForageManager._goldenrod_was_good,
	}

	# -- DandelionSpawner (scene node -- may not exist in every scene) ----------
	var spawner := _find_dandelion_spawner()
	if spawner:
		data["dandelion_spawner"] = _collect_dandelion_spawner(spawner)

	# -- Quest state -----------------------------------------------------------
	data["quest_manager"] = {
		"active_quests":    QuestManager.active_quests.duplicate(),
		"completed_quests": QuestManager.completed_quests.duplicate(),
		"quest_notes":      QuestManager.quest_notes.duplicate(),
	}

	# -- NPC flags -------------------------------------------------------------
	# Uncle Bob's hint-rotation index so he doesn't repeat tips after a reload.
	data["npc_flags"] = _collect_npc_flags()

	# -- Weather state ---------------------------------------------------------
	if WeatherManager and WeatherManager.has_method("collect_save_data"):
		data["weather"] = WeatherManager.collect_save_data()

	# -- Player identity (name, pronouns, backstory) --------------------------
	if PlayerData and PlayerData.has_method("collect_save_data"):
		data["player_data"] = PlayerData.collect_save_data()

	# -- Write to disk ---------------------------------------------------------
	var json_text: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open '%s' for writing (error %d)" % [
			SAVE_PATH, FileAccess.get_open_error()])
		return false

	file.store_string(json_text)
	file.close()

	print("Saved -- Day %d  |  %d hive(s)  |  %s" % [
		TimeManager.current_day,
		data["hives"].size(),
		SAVE_PATH,
	])
	save_completed.emit()
	return true


## Phase 1 of loading.  Reads and validates the save file; stores the result in
## _pending_data so apply_to_scene() can consume it once the scene is ready.
##
## Returns true on success.  On any error (missing file, bad JSON, wrong schema
## version) it returns false -- callers should start a fresh game.
## All failures are logged but never crash the game.
func load_from_disk() -> bool:
	has_pending_load = false
	_pending_data    = {}

	if not FileAccess.file_exists(SAVE_PATH):
		return false   # no save yet -- normal for a first run

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Could not open save file for reading.")
		load_failed.emit("file_open_error")
		return false

	var raw: String = file.get_as_text()
	file.close()

	# Parse JSON -- any corruption here falls back to fresh game.
	var json   := JSON.new()
	var result := json.parse(raw)
	if result != OK:
		push_error("SaveManager: JSON parse error at line %d -- %s" % [
			json.get_error_line(), json.get_error_message()])
		load_failed.emit("json_parse_error")
		return false

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: Save root is not a Dictionary.")
		load_failed.emit("schema_error")
		return false

	# Version gate.  If the stored version doesn't match SAVE_VERSION we
	# discard the save rather than applying potentially-wrong data.
	var stored_ver: int = int(data.get("version", 0))
	if stored_ver != SAVE_VERSION:
		push_warning("SaveManager: Version mismatch (save=%d, engine=%d) -- starting fresh." % [
			stored_ver, SAVE_VERSION])
		load_failed.emit("version_mismatch")
		return false

	_pending_data    = data
	has_pending_load = true
	print("Save file read OK -- Day %d" % [
		_pending_data.get("time", {}).get("current_day", 0)
	])
	return true


## Phase 2 of loading.  Applies _pending_data to the live scene tree.
##
## IMPORTANT: call this AFTER the scene's _ready() has finished so that the
## World node, player, and DandelionSpawner are all present in the tree.
##
## scene_root -- the HomeProperty Node2D (or the equivalent scene root).
func apply_to_scene(scene_root: Node) -> void:
	if not has_pending_load or _pending_data.is_empty():
		push_warning("SaveManager.apply_to_scene(): no pending data.")
		return

	var d: Dictionary = _pending_data

	# -- TimeManager -----------------------------------------------------------
	if d.has("time"):
		var t: Dictionary = d["time"]
		TimeManager.current_day       = int(t.get("current_day",  1))
		TimeManager.current_hour      = float(t.get("current_hour", 6.0))
		TimeManager._midnight_pending = false

	# -- GameData --------------------------------------------------------------
	if d.has("game_data"):
		_apply_game_data(d["game_data"])

	# Resolve the World node -- dynamic objects (hives, flowers, player) live here.
	var world := scene_root.get_node_or_null("World")
	if world == null:
		push_warning("SaveManager: 'World' node not found -- hives and flowers not restored.")

	# -- Hives -----------------------------------------------------------------
	if world and d.has("hives"):
		_apply_hives(d["hives"], world)

	# -- Flowers ---------------------------------------------------------------
	if world and d.has("flowers"):
		_apply_flowers(d["flowers"], world)

	# -- Player position + inventory -------------------------------------------
	if d.has("player") and not (d["player"] as Dictionary).is_empty():
		var player := scene_root.get_node_or_null("World/player")
		if player == null:
			player = scene_root.get_tree().get_first_node_in_group("player")
		if player:
			_apply_player(d["player"], player)

	# -- ForageManager ---------------------------------------------------------
	# Applied before DandelionSpawner in case the spawner needs to call back
	# into ForageManager (e.g. set_dandelion_bloom).
	if d.has("forage_manager"):
		_apply_forage_manager(d["forage_manager"])

	# -- DandelionSpawner ------------------------------------------------------
	if d.has("dandelion_spawner"):
		var spawner := _find_dandelion_spawner()
		if spawner:
			_apply_dandelion_spawner(d["dandelion_spawner"], spawner)

	# -- QuestManager ----------------------------------------------------------
	if d.has("quest_manager"):
		_apply_quest_manager(d["quest_manager"])

	# -- NPC flags -------------------------------------------------------------
	if d.has("npc_flags"):
		_apply_npc_flags(d["npc_flags"])

	# -- Weather state ---------------------------------------------------------
	if d.has("weather") and WeatherManager and WeatherManager.has_method("apply_save_data"):
		WeatherManager.apply_save_data(d["weather"])
	elif WeatherManager and WeatherManager.has_method("roll_daily_weather"):
		# No saved weather -- roll fresh for this day
		WeatherManager.roll_daily_weather()

	# -- Player identity (name, pronouns, backstory) --------------------------
	if d.has("player_data") and PlayerData and PlayerData.has_method("apply_save_data"):
		PlayerData.apply_save_data(d["player_data"])

	# Clear pending state so a second call is a no-op.
	has_pending_load = false
	_pending_data    = {}

	print("Save applied -- Day %d, Hour %.1f, %d hive(s)" % [
		TimeManager.current_day,
		TimeManager.current_hour,
		get_tree().get_nodes_in_group("hive").size(),
	])
	load_completed.emit()


# ==============================================================================
# COLLECTION HELPERS  (save-side)
# ==============================================================================

func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _find_dandelion_spawner() -> Node:
	return get_tree().get_first_node_in_group("dandelion_spawner")


func _collect_player(player: Node) -> Dictionary:
	var pos: Vector2 = (player as Node2D).global_position
	# inventory is an Array[20] of slots -- each is null or {item:str, count:int}.
	var inv: Array = []
	if "inventory" in player:
		inv = (player.inventory as Array).duplicate(true)
	return {
		"position_x": pos.x,
		"position_y": pos.y,
		"inventory":  inv,
	}


func _collect_hives() -> Array:
	var out: Array = []
	for hive_node in get_tree().get_nodes_in_group("hive"):
		var sim: HiveSimulation = hive_node.get_node_or_null("HiveSimulation")
		if sim == null:
			continue
		var pos: Vector2 = (hive_node as Node2D).global_position
		var entry: Dictionary = {
			"position_x": pos.x,
			"position_y": pos.y,
			"sim": _collect_sim(sim),
		}
		# tile_coords is set by player.gd on hives placed via HIVE mode.
		# It's needed for the 5x5 spacing check when the player places new hives.
		if hive_node.has_meta("tile_coords"):
			var tc: Vector2i = hive_node.get_meta("tile_coords")
			entry["tile_x"] = tc.x
			entry["tile_y"] = tc.y
		out.append(entry)
	return out


func _collect_sim(sim: HiveSimulation) -> Dictionary:
	return {
		# -- Age / lifecycle ---------------------------------------------------
		"days_elapsed":           sim.days_elapsed,
		# -- Adult population cohorts ------------------------------------------
		"nurse_count":            sim.nurse_count,
		"house_count":            sim.house_count,
		"forager_count":          sim.forager_count,
		"drone_count":            sim.drone_count,
		# -- Colony stores -----------------------------------------------------
		"honey_stores":           sim.honey_stores,
		"pollen_stores":          sim.pollen_stores,
		# -- Health / disease --------------------------------------------------
		"mite_count":             sim.mite_count,
		"disease_flags":          sim.disease_flags.duplicate(),
		# -- Congestion --------------------------------------------------------
		"congestion_state":       int(sim.congestion_state),
		"consecutive_congestion": sim.consecutive_congestion,
		# -- Queen (species, grade, age_days, laying_rate, etc.) ---------------
		"queen":                  sim.queen.duplicate(),
		# -- Physical frame cell data ------------------------------------------
		# PackedByteArrays are base64-encoded to survive JSON round-trips.
		# A single brood box has 10 frames x 3,500 cells = ~47 KB of data;
		# each frame is stored as two base64 strings (cells + cell_age).
		"boxes":                  _collect_boxes(sim.boxes),
	}


func _collect_boxes(boxes: Array) -> Array:
	var out: Array = []
	for box in boxes:
		out.append(_collect_box(box as HiveSimulation.HiveBox))
	return out


func _collect_box(box: HiveSimulation.HiveBox) -> Dictionary:
	var frames_out: Array = []
	for frame in box.frames:
		var f: HiveSimulation.HiveFrame = frame as HiveSimulation.HiveFrame
		frames_out.append({
			# Marshalls.raw_to_base64() encodes PackedByteArray -> base64 String.
			"cells_b64":    Marshalls.raw_to_base64(f.cells),
			"cell_age_b64": Marshalls.raw_to_base64(f.cell_age),
		})
	return {
		"is_super": box.is_super,
		"frames":   frames_out,
	}


func _collect_flowers() -> Array:
	var out: Array = []
	for flower in get_tree().get_nodes_in_group("flowers"):
		var fp: Vector2 = (flower as Node2D).global_position
		out.append({
			"position_x": fp.x,
			"position_y": fp.y,
			# Preserve growth state so the plant resumes at the correct stage.
			"current_day": flower.current_day if "current_day" in flower else 0,
			"is_seeding":  flower.is_seeding  if "is_seeding"  in flower else false,
		})
	return out


func _collect_dandelion_spawner(spawner: Node) -> Dictionary:
	return {
		"current_year":          spawner.current_year,
		"current_outcome":       spawner.current_outcome,
		"current_density":       spawner.current_density,
		"bloom_day":             spawner.bloom_day,
		"bloomed":               spawner._bloomed,
		"prior_goldenrod_good":  spawner._prior_goldenrod_good,
	}


func _collect_npc_flags() -> Dictionary:
	var flags: Dictionary = {}
	var bob := get_tree().get_first_node_in_group("uncle_bob")
	if bob and "_hint_index" in bob:
		flags["uncle_bob_hint_index"] = bob._hint_index
	return flags


# ==============================================================================
# APPLY HELPERS  (load-side)
# ==============================================================================

func _apply_game_data(gd: Dictionary) -> void:
	GameData.money             = float(gd.get("money",             500.0))
	GameData.player_level      = int(gd.get("player_level",        1))
	GameData.xp                = int(gd.get("xp",                  0))
	GameData.reputation        = float(gd.get("reputation",        0.0))
	GameData.energy            = float(gd.get("energy",            100.0))
	GameData.max_energy        = float(gd.get("max_energy",        100.0))
	GameData.coffee_until_hour = float(gd.get("coffee_until_hour", -1.0))
	GameData.xp_buff_until_day = int(gd.get("xp_buff_until_day",   -1))

	if gd.has("expense_log"):
		GameData.expense_log = (gd["expense_log"] as Array).duplicate(true)
	if gd.has("meals_eaten"):
		GameData.meals_eaten = (gd["meals_eaten"] as Dictionary).duplicate()
	if gd.has("pending_deliveries"):
		GameData.pending_deliveries = (gd["pending_deliveries"] as Array).duplicate(true)

	# Fire signals so the HUD and any other connected UI refresh immediately.
	GameData.money_changed.emit(GameData.money)
	GameData.energy_changed.emit(GameData.energy)


func _apply_hives(hive_data: Array, world: Node) -> void:
	for entry in hive_data:
		# Instantiate the Hive scene.  Because World is already in the scene
		# tree, add_child() triggers HiveSimulation._ready() synchronously:
		# boxes are freshly initialised first, then we overwrite them below.
		var hive_node: Node2D = HIVE_SCENE.instantiate()
		world.add_child(hive_node)
		hive_node.global_position = Vector2(
			float(entry.get("position_x", 0.0)),
			float(entry.get("position_y", 0.0))
		)
		if entry.has("tile_x") and entry.has("tile_y"):
			hive_node.set_meta("tile_coords", Vector2i(
				int(entry["tile_x"]), int(entry["tile_y"])
			))
		if entry.has("sim"):
			var sim: HiveSimulation = hive_node.get_node_or_null("HiveSimulation")
			if sim:
				_apply_sim(entry["sim"], sim)


func _apply_sim(sd: Dictionary, sim: HiveSimulation) -> void:
	# -- Scalar population / store fields -------------------------------------
	sim.days_elapsed           = int(sd.get("days_elapsed",           0))
	sim.nurse_count            = int(sd.get("nurse_count",            3000))
	sim.house_count            = int(sd.get("house_count",            4000))
	sim.forager_count          = int(sd.get("forager_count",          5000))
	sim.drone_count            = int(sd.get("drone_count",            100))
	sim.honey_stores           = float(sd.get("honey_stores",         20.0))
	sim.pollen_stores          = float(sd.get("pollen_stores",        5.0))
	sim.mite_count             = float(sd.get("mite_count",           150.0))
	sim.consecutive_congestion = int(sd.get("consecutive_congestion", 0))
	sim.congestion_state       = int(sd.get("congestion_state", 0)) as HiveSimulation.CongestionState
	sim.disease_flags          = (sd.get("disease_flags", []) as Array).duplicate()

	# -- Queen dictionary ------------------------------------------------------
	if sd.has("queen"):
		sim.queen = (sd["queen"] as Dictionary).duplicate()

	# -- Physical frame data (boxes -> frames -> PackedByteArrays) --------------
	if sd.has("boxes"):
		_apply_boxes(sd["boxes"], sim)

	# Rebuild the read-only snapshot so hive labels and health tints reflect
	# the loaded state immediately without waiting for the next daily tick.
	sim.last_snapshot = SnapshotWriter.write(sim, sim._calculate_health_score())


func _apply_boxes(boxes_data: Array, sim: HiveSimulation) -> void:
	sim.boxes = []
	for box_data in boxes_data:
		var is_super: bool = bool(box_data.get("is_super", false))
		var box := HiveSimulation.HiveBox.new(is_super)
		sim.boxes.append(box)

		var frames_data: Array = box_data.get("frames", [])
		# HiveBox._init() already populated 10 HiveFrame objects; grow only if
		# the saved box somehow had more (future-proofing for extra-wide supers).
		while box.frames.size() < frames_data.size():
			box.frames.append(HiveSimulation.HiveFrame.new())

		for i in range(mini(box.frames.size(), frames_data.size())):
			var fd: Dictionary              = frames_data[i]
			var frame: HiveSimulation.HiveFrame = box.frames[i]
			if fd.has("cells_b64"):
				# Marshalls.base64_to_raw() returns a PackedByteArray.
				frame.cells    = Marshalls.base64_to_raw(fd["cells_b64"])
			if fd.has("cell_age_b64"):
				frame.cell_age = Marshalls.base64_to_raw(fd["cell_age_b64"])


func _apply_player(pd: Dictionary, player: Node) -> void:
	if pd.has("position_x") and pd.has("position_y"):
		(player as Node2D).global_position = Vector2(
			float(pd["position_x"]), float(pd["position_y"])
		)
	if pd.has("inventory") and "inventory" in player:
		var raw: Array = pd["inventory"]
		player.inventory.resize(player.INVENTORY_SIZE)
		player.inventory.fill(null)
		for i in range(mini(raw.size(), player.INVENTORY_SIZE)):
			# Each slot is JSON null (-> null) or a {item, count} Dictionary.
			player.inventory[i] = raw[i]
		player.update_hud_inventory()
		# Keep GameData in sync so inventory survives future scene changes
		if player.has_method("sync_inventory_to_gamedata"):
			player.sync_inventory_to_gamedata()


func _apply_flowers(flowers_data: Array, world: Node) -> void:
	for fd in flowers_data:
		var flower_node: Node2D = FLOWER_SCENE.instantiate()
		world.add_child(flower_node)
		flower_node.global_position = Vector2(
			float(fd.get("position_x", 0.0)),
			float(fd.get("position_y", 0.0))
		)
		# Restore growth counters and refresh the stage label immediately.
		if "current_day" in flower_node:
			flower_node.current_day = int(fd.get("current_day", 0))
		if "is_seeding" in flower_node:
			flower_node.is_seeding = bool(fd.get("is_seeding", false))
		if flower_node.has_method("update_appearance"):
			flower_node.update_appearance()


func _apply_forage_manager(fm: Dictionary) -> void:
	# Write internal fields directly.  Normally set via set_dandelion_bloom()
	# by DandelionSpawner, but on load we bypass the roll entirely.
	ForageManager._dandelion_outcome  = str(fm.get("dandelion_outcome",  ""))
	ForageManager._dandelion_density  = float(fm.get("dandelion_density", 0.0))
	ForageManager._dandelion_nu       = float(fm.get("dandelion_nu",      0.0))
	ForageManager._goldenrod_was_good = bool(fm.get("goldenrod_was_good", false))


func _apply_dandelion_spawner(ds: Dictionary, spawner: Node) -> void:
	spawner.current_year          = int(ds.get("current_year",         -1))
	spawner.current_outcome       = str(ds.get("current_outcome",      ""))
	spawner.current_density       = float(ds.get("current_density",    0.0))
	spawner.bloom_day             = int(ds.get("bloom_day",            0))
	spawner._prior_goldenrod_good = bool(ds.get("prior_goldenrod_good", false))

	# Re-spawn dandelion sprites if they were visible when the game was saved.
	# _spawn_dandelions() checks `if _bloomed: return`, so we clear the flag
	# first; the method then sets it back to true after spawning.
	var was_bloomed: bool = bool(ds.get("bloomed", false))
	spawner._bloomed = false
	if was_bloomed and not spawner.current_outcome.is_empty():
		if spawner.has_method("_spawn_dandelions"):
			spawner._spawn_dandelions()
	# If not bloomed, _bloomed stays false and the normal day-advance logic
	# will trigger the bloom on the correct in-game day.


func _apply_quest_manager(qm: Dictionary) -> void:
	if qm.has("active_quests"):
		QuestManager.active_quests    = (qm["active_quests"]    as Dictionary).duplicate()
	if qm.has("completed_quests"):
		QuestManager.completed_quests = (qm["completed_quests"] as Dictionary).duplicate()
	if qm.has("quest_notes"):
		QuestManager.quest_notes      = (qm["quest_notes"]      as Dictionary).duplicate()


func _apply_npc_flags(flags: Dictionary) -> void:
	# Uncle Bob: restore hint rotation so he continues from where he left off.
	var bob := get_tree().get_first_node_in_group("uncle_bob")
	if bob and flags.has("uncle_bob_hint_index"):
		bob._hint_index = int(flags["uncle_bob_hint_index"])
