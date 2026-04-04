# uncle_bob.gd -- Uncle Bob NPC
# -----------------------------------------------------------------------------
# GDD S9: Uncle Bob -- the player's experienced beekeeper uncle.
#   He lives next door, gives tutorials, and gently nudges the player toward
#   good beekeeping practice.
#
# First visit: narrative onboarding -- thanks player for coming, explains the
#   winter, teaches controls, sends them to inspect the hive.
# Subsequent visits: quest-aware debriefs and briefings, then seasonal rotation.
#
# Dialogue priority:
#   1. First visit onboarding (bob_intro quest)
#   2. Post-quest debrief (return_to_bob prompt)
#   3. Quest-aware briefing (active quest advice)
#   4. Seasonal rotation
#   5. Fallback static lines
# -----------------------------------------------------------------------------
extends Node2D

# Interaction radius (pixels)
const INTERACT_RADIUS := 40.0

# -- First-visit onboarding (bob_intro quest) ----------------------------------
# Narrative arrival: player has come to Cedar Bend to help Bob after his
# hospital stay. 11 of 12 hives died over winter. One survived.
const ONBOARDING_LINES: Array = [
	"Hey -- you made it. I was starting to think you'd change your mind.",
	"I appreciate you coming out here. Cedar Bend isn't much, but it's home.",
	"I had a rough winter. Spent three weeks in the hospital in Albion -- liver trouble.",
	"While I was gone, eleven of my twelve hives died. Cold got them.",
	"But one made it. One hive, out of twelve. She's a tough old girl.",
	"See all those dandelions out there? Yellow fields as far as you can see.",
	"That's the most important thing happening right now. The dandelion flow.",
	"It's what's keeping her alive -- natural nectar coming in, feeding the colony.",
	"Your job is to learn this hive. Learn what she needs. Keep her going.",
	"First: see that storage chest? Walk over and press E to open it.",
	"Drag items from the chest to your toolbar at the bottom of the screen.",
	"Grab the smoker and the hive tool -- you need both every time you inspect.",
	"Use the mouse wheel to scroll through your toolbar, or press 1 through 9.",
	"Always smoke the hive first. Select the smoker, walk to the hive, press E.",
	"Then switch to the hive tool and press E to open it up. Skip the smoke and you'll get stung.",
	"Inside: W and S move between boxes, A and D flip through frames, F flips a frame over.",
	"Press J for your Knowledge Journal. TAB for stats. ESC for the pause menu.",
	"Now go smoke that hive and take a look inside. I want to know what she's doing in there.",
]

# -- Post-quest debrief lines (shown when player returns after completing) -----
# Keyed by the quest that was JUST completed (return_to_bob).
const DEBRIEF_LINES: Dictionary = {
	"first_light": [
		"Well? What did you see in there?",
		"The brood pattern's thin, but it's there. That means the queen survived the winter.",
		"See those dandelions out the window? That nectar is what's fueling her right now.",
		"Without the dandelion flow, she'd starve before summer. That's how close it was.",
		"Next thing I need you to do -- go back in and do a full inspection.",
		"Every frame, both sides. I want to know what the whole box looks like.",
		"Look for the brood pattern -- a tight oval of capped cells means the queen is laying well.",
		"Look for honey stores arching above the brood. Look for anything unusual.",
	],
	"reading_the_room": [
		"Good. Now you're starting to see what I see.",
		"A healthy brood nest looks like a tight oval -- capped cells in the center, honey arching above.",
		"The dandelion flow is building her up fast. Population is climbing every day.",
		"Pretty soon she'll run out of room in that brood box. When she does, they'll swarm.",
		"Swarming means half your bees leave. Just fly off. You don't want that.",
		"There are honey supers in the storage chest. Grab one and add it to the hive.",
		"That gives them room to store nectar up top instead of getting crowded below.",
		"Open the hive with your tool and use the Hive Management buttons to add the super on top.",
	],
	"girls_are_building": [
		"Good -- you gave them room just in time.",
		"Now we wait. The dandelions will fade, but the clover is coming.",
		"Wide-Clover month is when the real nectar flows. That's when the supers fill up.",
		"When you see frames that are 80% capped or more, that's ripe honey ready to pull.",
		"But don't rush it. Green honey ferments. Let the bees tell you when it's ready.",
		"Get some rest. Check on them every few days. The clover will do the rest.",
		"When summer comes and those supers are heavy, come find me. We'll talk about harvest.",
	],
	"first_pull": [
		"Your first harvest. How does it feel?",
		"Everyone thinks this is the point -- the honey, the jars, the money.",
		"But the honey isn't the point. The honey is proof the bees are doing well.",
		"Now listen. Summer gave you something. Fall is going to ask for it back.",
		"You took honey out of that hive. The bees need 60 pounds to survive winter.",
		"If they're short after harvest, that's on you to make up. We'll deal with that in fall.",
		"For now, enjoy it. You earned those jars.",
	],
	"battening_down": [
		"You did it. She's ready for winter.",
		"Sixty pounds of stores. Mites under control. That's all you can do.",
		"Now we wait. Don't open the hive in winter -- you'll break the cluster and they'll freeze.",
		"Check the weight from outside. If it feels light, put fondant on top of the frames.",
		"And come spring -- listen to me -- if the dandelions are late, you feed.",
		"One-to-one sugar to water. Thin syrup. It mimics a nectar flow and gets the queen laying.",
		"You'll know they need it if the dandelions haven't opened by mid-Quickening.",
		"But that's next year's problem. Right now, you've done good work.",
	],
}

# -- Quest-aware briefing lines (active quest advice) --------------------------
const QUEST_LINES: Dictionary = {
	"first_light": [
		"Time to look inside that hive for the first time.",
		"Grab the smoker and hive tool from the chest if you haven't already.",
		"Smoke the hive first -- select the smoker, walk to the hive, press E.",
		"Then switch to the hive tool and press E to open up. Look at least 3 frames.",
	],
	"reading_the_room": [
		"I need you to do a thorough inspection this time. Every frame, both sides.",
		"The brood pattern tells you everything about the queen's health.",
		"A tight oval of capped cells is good. Gaps and holes mean trouble.",
		"Take your time. Look at every frame. Then come tell me what you see.",
	],
	"girls_are_building": [
		"The colony is growing fast on the dandelion flow. They need more room.",
		"Grab a honey super from the storage chest. Drag it to your toolbar.",
		"Open the hive and use the Hive Management screen to add the super on top.",
		"That gives them space to store nectar instead of running out of room.",
	],
	"first_pull": [
		"Those supers should be getting heavy. Time for your first harvest.",
		"Open the hive with your hive tool and check the frames.",
		"You want at least 80% capped. Green honey ferments -- don't pull it early.",
		"Use Hive Management to pull a full super, then take it to the Harvest Yard.",
	],
	"battening_down": [
		"Winter's coming. Your one job now is making sure they survive it.",
		"First: grab the wash kit from Tanner's and do an alcohol wash. Under 3 mites per hundred.",
		"If the count is high, treat with oxalic acid. Don't wait.",
		"Then check the stores. If they're below 60 pounds, buy sugar and install a feeder bucket.",
		"Mix 2:1 -- two parts sugar, one part water. Thick syrup for fall. That's their lifeline.",
		"You'll spend some of your harvest money on feed. That's the cost of keeping bees alive.",
	],
}

# -- Holiday dialogue (between quest-aware and seasonal) -----------------------
const HOLIDAY_LINES: Dictionary = {
	"quickening_morn": [
		"Quickening Morn. My favorite day of the year.",
		"I bring the first comb every year. Been doing it since '94.",
		"Your aunt started that tradition. I just kept it going.",
		"Someday you will be the one carrying the comb to that table.",
	],
	"founders_beam": [
		"Founder's Beam. Whole town goes a little crazy.",
		"Go sell at the market today. Frank doubles his prices and people pay it.",
		"Rose and Darlene are at it again with the pies. Put your money on Rose.",
	],
	"reaping_fire": [
		"The Reaping Fire tonight. You should go.",
		"Lloyd will tell the '94 storm story. Silas will say it was '95.",
		"It was '94. I was there. But let them argue. It is the tradition.",
		"Check your stores tomorrow. After the fire, winter prep starts for real.",
	],
	"long_table": [
		"Help me with the table, would you?",
		"Just the two of us this year. That is fine. Two is enough.",
		"Your aunt would have had twenty people at this table.",
		"She would be glad you are here.",
	],
}

# -- Seasonal dialogue pools ---------------------------------------------------
const SEASONAL_LINES: Dictionary = {
	"Spring": [
		["The dandelions are everything right now. Without that flow, the colony starves.", "Watch the foragers coming back. Bright yellow pollen on their legs means the dandelions are producing."],
		["Colony's building up fast. Check every week or so.", "If they're packing in pollen, that means the queen is laying well. Good sign."],
		["Watch for queen cells along the bottom of the frames. That's swarm prep.", "Give them room -- add a super before they feel cramped."],
	],
	"Summer": [
		["Nectar flow is on. The girls are working harder than either of us.", "This is when the supers fill up. Don't pull them too early -- wait for 80% capped."],
		["Summer is when mites breed fastest. Don't skip your monthly wash.", "Three mites per hundred is your treatment threshold. Don't let it slide."],
		["The clover is doing the heavy lifting now. Let it work.", "Check those supers every week. When they're heavy, they're ready."],
	],
	"Fall": [
		["Time to think about winter. How heavy are those hives?", "If they're light after harvest, they need feeding. 2:1 sugar syrup -- thick for fall."],
		["Get your mite treatment done before it gets cold. Oxalic works best broodless.", "Sixty pounds of honey minimum going into winter. That's their lifeline."],
		["Every pound of honey you left them is a pound they don't have to worry about.", "The goldenrod flow helps, but don't count on it. Make up the difference with syrup."],
	],
	"Winter": [
		["Not much to do now except listen. Put your ear to the hive -- hear that hum?", "A strong hum means they're clustered tight. Silence... that's what worries me."],
		["Don't open the hive in winter. You'll break the cluster and they'll freeze.", "Check the weight from outside. If it feels light, feed fondant on top of the frames."],
	],
}

# -- Fallback static lines -----------------------------------------------------
const FALLBACK_LINES: Array = [
	["Glad you're out here. The best beekeepers I know spend more time watching than working."],
	["A healthy brood nest looks like a tight oval -- capped cells in the center, honey arching above.", "Write it in your Knowledge Log. Press J to open it."],
	["The queen lays from the center frame outward. Frame 5 is usually her first choice.", "Spotting her yourself is the real skill. You'll get better at it."],
	["Varroa is the thing that'll keep you up at night. One mite per hundred is your ceiling.", "Check with an alcohol wash once a month in summer."],
	["Come fall, your whole job is making sure they have enough honey to survive winter.", "Sixty pounds minimum. Don't harvest what they need."],
]

# -- State ---------------------------------------------------------------------
var _hint_index:     int  = 0
var _seasonal_index: int  = 0
var _talking:        bool = false
var _prompt_label:   Label = null
var _dialogue_ui:    Node  = null
# Tracks which quest the player last completed (for debrief dialogue)
var _pending_debrief: String = ""
@onready var _bob_sprite: Sprite2D = get_node_or_null("BobSprite")

# -- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
	add_to_group("uncle_bob")
	add_to_group("npc")

	# Load Uncle Bob's spritesheet at runtime (bypasses import pipeline)
	if _bob_sprite:
		var path := "res://assets/sprites/npc/Uncle_Bob/uncle_bob_spritesheet.png"
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_path)
		if img:
			var tex := ImageTexture.create_from_image(img)
			_bob_sprite.texture = tex
			_bob_sprite.hframes = 8
			_bob_sprite.vframes = 24
			_bob_sprite.frame = 0
			print("Uncle Bob: Loaded spritesheet %dx%d" % [img.get_width(), img.get_height()])
		else:
			push_error("Uncle Bob: Failed to load spritesheet from %s" % abs_path)

	_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")

	# "[E] Talk" prompt label
	_prompt_label = Label.new()
	_prompt_label.text = "[E] Talk to Uncle Bob"
	_prompt_label.add_theme_font_size_override("font_size", 7)
	_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.custom_minimum_size = Vector2(120, 12)
	_prompt_label.position = Vector2(-60, -70)
	_prompt_label.z_index = 10
	_prompt_label.visible = false
	add_child(_prompt_label)

	# Listen for quest completions to track pending debriefs
	if QuestManager:
		QuestManager.quest_completed.connect(_on_quest_completed)

func _on_quest_completed(quest_id: String, _xp: int) -> void:
	# If this quest has return_to_bob, queue its debrief
	if QuestDefs.QUESTS.has(quest_id):
		if QuestDefs.QUESTS[quest_id].get("return_to_bob", false):
			_pending_debrief = quest_id

func _process(_delta: float) -> void:
	if _prompt_label == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var dist: float = (player as Node2D).global_position.distance_to(global_position)
		_prompt_label.visible = dist <= INTERACT_RADIUS and not _talking
	else:
		_prompt_label.visible = false

# -- Public API ----------------------------------------------------------------

## Called by player.gd when E is pressed near Uncle Bob.
func interact() -> void:
	if _talking:
		return
	if _dialogue_ui == null:
		_dialogue_ui = get_tree().root.get_node_or_null("DialogueUI")
	if _dialogue_ui == null:
		return
	_talking = true

	var lines: Array = _pick_lines()
	_dialogue_ui.show_dialogue("Uncle Bob", lines, "uncle_bob")

	# Award small XP for conversation (GDD S7.1)
	if GameData:
		GameData.add_xp(5)

	# Wait for dialogue to close, then unlock talking again
	_wait_for_dialogue_close()

## Pick the best lines for the current game state.
func _pick_lines() -> Array:
	# Priority 1: First visit onboarding (bob_intro quest)
	if not PlayerData.has_flag("uncle_bob_onboarding_done"):
		PlayerData.set_flag("uncle_bob_onboarding_done")
		# Unlock starter journal entries
		if KnowledgeLog:
			KnowledgeLog.unlock_entry("bee_biology")
			KnowledgeLog.unlock_entry("hive_components")
		# Complete the bob_intro quest
		QuestManager.notify_event("bob_intro_complete", {})
		return ONBOARDING_LINES

	# Priority 2: Post-quest debrief (player returned after completing a quest)
	if _pending_debrief != "" and DEBRIEF_LINES.has(_pending_debrief):
		var debrief_id: String = _pending_debrief
		_pending_debrief = ""
		var lines: Array = DEBRIEF_LINES[debrief_id]
		# Unlock relevant journal entries based on completed quest
		_unlock_debrief_entries(debrief_id)
		return lines

	# Priority 3: Quest-aware advice (active quest)
	if QuestManager:
		for quest_id in QUEST_LINES.keys():
			if QuestManager.active_quests.has(quest_id):
				if QuestManager.active_quests[quest_id] == 1:  # QuestState.ACTIVE
					return QUEST_LINES[quest_id]

	# Priority 3.5: Holiday-specific dialogue
	if HolidayManager and HolidayManager.current_holiday_key() != "":
		var hk: String = HolidayManager.current_holiday_key()
		if HOLIDAY_LINES.has(hk):
			return HOLIDAY_LINES[hk]

	# Priority 4: Seasonal rotation
	var season: String = ""
	if TimeManager and TimeManager.has_method("current_season_name"):
		season = TimeManager.current_season_name()
	if SEASONAL_LINES.has(season):
		var pool: Array = SEASONAL_LINES[season]
		if pool.size() > 0:
			_seasonal_index = _seasonal_index % pool.size()
			var lines: Array = pool[_seasonal_index]
			_seasonal_index += 1
			return lines

	# Priority 5: Fallback static lines
	_hint_index = _hint_index % FALLBACK_LINES.size()
	var lines: Array = FALLBACK_LINES[_hint_index]
	_hint_index += 1
	return lines

## Unlock journal entries tied to quest debriefs.
func _unlock_debrief_entries(quest_id: String) -> void:
	if KnowledgeLog == null:
		return
	match quest_id:
		"first_light":
			KnowledgeLog.unlock_entry("frame_reading")
		"reading_the_room":
			KnowledgeLog.unlock_entry("brood_pattern")
		"girls_are_building":
			KnowledgeLog.unlock_entry("when_to_add_space")
		"first_pull":
			KnowledgeLog.unlock_entry("honey_harvest")
		"battening_down":
			KnowledgeLog.unlock_entry("winter_prep")
			KnowledgeLog.unlock_entry("emergency_feeding")

## Wait for DialogueUI to close, then re-enable interaction.
func _wait_for_dialogue_close() -> void:
	# Poll every 0.2s until dialogue closes (avoids signal dependency)
	while _dialogue_ui and _dialogue_ui.has_method("is_open") and _dialogue_ui.is_open():
		await get_tree().create_timer(0.2).timeout
	_talking = false
