# Level 1 Harvest Loop - Implementation Task List
**Created:** 2026-03-28
**Status:** Planning Phase

---

## Overview

The Level 1 harvest loop takes the player through a physical, station-based honey extraction pipeline inside the Honey House. The flow is:

**Hive** (mark + remove super) -> **Super Prep Area** (break into frames) -> **Frame Holder** (staging) -> **Uncapping Station** (de-cap both sides) -> **Honey Spinner** (batch extract, 10 frames) -> **White Bucket** (intermediate) -> **Canning Table** (fill jars)

All Level 1 honey is Standard grade (no moisture grading yet). Grading unlocks at a later level.

---

## PHASE A: Frame Marking & Super Collection (Hive Side)

### A1. Add Frame Harvest Marking to InspectionOverlay
**File:** scripts/ui/InspectionOverlay.gd
- Add [H] key binding to mark/unmark current super frame for harvest
- Add [Shift+H] to mark/unmark all frames in current super
- Only allow marking on super frames (not brood deep frames)
- Show visual indicator on marked frames (gold border or checkmark)
- Show per-frame capping % in stats sidebar with readiness icons:
  - Green honeycomb: >=80% capped ("Ready to harvest")
  - Yellow warning: 60-79% ("Needs more time")
  - Red warning: <60% ("Not ready - high fermentation risk")
- Show fermentation warning dialog if marking a frame <80% capped
- Wire up `frame.marked_for_harvest = true` (field exists but is never set)
**Dependencies:** None (builds on existing InspectionOverlay)

### A2. Super Removal from Hive
**File:** scripts/world/hive.gd, scripts/core/player.gd
- The `has_marked_super()` and `remove_marked_super()` methods already exist
- The player.gd interaction code already checks for marked supers and adds ITEM_FULL_SUPER
- Verify this flow works end-to-end once marking is implemented
- Update notification text: "Super removed -- take it to the Honey House!"
- Carry speed penalty: -15% movement per ITEM_FULL_SUPER (max 2)
**Dependencies:** A1

---

## PHASE B: Honey House Station Setup

### B1. Redesign Honey House Interior Layout
**File:** scenes/world/honey_house.tscn
- Replace current placeholder stations (Extractor, UncappingStation, BottlingStation, HoneyShelf)
- New layout with 5 stations in logical flow order:
  1. **Super Prep Area** (entrance area, first stop)
  2. **Frame Holder** (rack/shelf next to prep area)
  3. **Uncapping Station** (workbench with knife)
  4. **Honey Spinner** (large barrel/drum, center of room)
  5. **Canning Table** (counter with jars, near exit/shelf)
- Each station needs: collision area, interaction zone, prompt label, visual sprite
- May need to expand room dimensions for 5 stations (currently 10x8 tiles)
**Dependencies:** B5 (art assets)

### B2. Create Honey House Controller Script
**File:** scripts/world/honey_house.gd (new, replaces generic_interior.gd usage)
- Dedicated script managing the harvest pipeline state machine
- Track current pipeline state: IDLE, PREPPING, UNCAPPING, SPINNING, CANNING
- Track frames in each station (array of frame data dicts)
- Track bucket honey amount (lbs)
- Handle station-to-station frame/honey movement
- Save/load pipeline state (partially processed harvest persists across days)
**Dependencies:** B1

### B3. Define New Items in GameData
**File:** scripts/autoloads/GameData.gd, resources/data/item_registry.json
- ITEM_COMB_SCRAPER (de-capping tool, $12, tool category)
- ITEM_HONEY_BUCKET (white bucket, intermediate container, not sold)
- Verify ITEM_JAR already exists (it does, $0.50 each)
- Verify ITEM_HONEY_JAR already exists with standard grade
- Add ITEM_HONEY_JAR metadata: grade field, weight (1 lb)
**Dependencies:** None

---

## PHASE C: Station Mechanics (The Gameplay)

### C1. Super Prep Area
**Interaction:** Player walks to station with ITEM_FULL_SUPER in inventory, presses [E]
- Consume ITEM_FULL_SUPER from inventory
- Play "cracking open" animation/sound
- Display: "Removed 10 frames from super. Frames loaded into Frame Holder."
- Transfer 10 frame data objects (with cell data from the HiveBox) to the Frame Holder
- Empty super box returns to inventory (or is placed nearby for reuse)
**Dependencies:** A2, B2

### C2. Frame Holder (Visual Staging)
- Display rack showing loaded frames (count: X/10)
- Visual only -- frames wait here until player uncaps them
- Player presses [E] at Frame Holder to pick up next frame for uncapping
- Frame moves to Uncapping Station
**Dependencies:** C1, B2

### C3. Uncapping Station (De-capping Mini-game)
**New scene/overlay:** scenes/ui/UncappingOverlay.tscn + scripts/ui/UncappingOverlay.gd
- Full-screen overlay showing the frame (reuse FrameRenderer honeycomb view)
- Capped cells highlighted with golden wax overlay
- Frame divided into 5 horizontal strips
- Player drags uncapping tool across each strip (click-drag from edge to edge)
- Clean swipe = 100% cappings recovered, 0% spillage
- Messy swipe = 70% cappings recovered, 5% honey lost
- [F] key to flip frame (must uncap both sides)
- When both sides done, "Looks Good" button appears
- Clicking button drops frame into spinner queue
- Energy cost: 1 per frame
- Beeswax output tracked: cells_uncapped * 0.00015 lbs
- "Uncap All (Quick)" skip button for players who don't enjoy the mini-game
**Dependencies:** B2, B3

### C4. Honey Spinner (Batch Extraction)
**Interaction:** Spinner shows frame count (X/10)
- Frames accumulate from uncapping station one at a time
- When 10 frames loaded (or player chooses to spin partial batch), enable spin
- Player repeatedly presses [E] for 20 seconds (progress bar fills)
- Button-mash mechanic: each press advances the bar slightly
- Animated spinner rotation during pressing
- Sound: spinning/whirring increases with speed
- On completion: honey drains into white bucket
- Yield calculation: sum of all frame honey lbs (adjusted for uncapping quality)
- All Level 1 honey = Standard grade (no moisture grading)
- Energy cost: 1.5 per frame (15 total for full super)
- Emptied frames return to "drawn comb" state (not foundation)
**Dependencies:** C3, B2

### C5. Canning Table (Jar Filling)
**Interaction:** Player walks to canning table with white bucket + ITEM_JAR in inventory
- Display: "Bucket: XX.X lbs | Jars available: XX"
- Press [E] to fill one 1-lb jar
- Consumes 1 ITEM_JAR + 1 lb from bucket
- Produces 1 ITEM_HONEY_JAR (standard grade)
- Repeat until bucket empty or out of jars
- Running counter: "Filled: X jars | Remaining: X.X lbs"
- Sound: pouring/glass clink per jar
- Remaining honey stays in bucket for next session
**Dependencies:** C4, B2, B3

---

## PHASE D: Art Assets (Leonardo AI)

### D1. NEW Station Sprites (Honey House Interior)
All sprites should match the game's established pixel art style, 32x32 grid, Langstroth/rustic beekeeping aesthetic. Reference the "Smoke and Honey" Leonardo collection.

| Asset | Description | Size |
|-------|-------------|------|
| super_prep_table.png | Wooden workbench/table for breaking open supers | 64x64 or 96x64 |
| frame_holder_rack.png | Wooden rack/shelf holding individual frames upright | 64x64 |
| uncapping_station.png | Workbench with knife/tools for de-capping | 64x64 |
| honey_spinner.png | Large barrel/drum extractor with hand crank | 64x64 or 64x96 |
| canning_table.png | Counter/table with jars and honey gate valve | 64x64 or 96x64 |
| white_bucket.png | White 5-gallon bucket (station prop) | 32x32 |

### D2. NEW Item Sprites (32x32, inventory icons)

| Asset | Description |
|-------|-------------|
| comb_scraper.png | Flat-bladed scraping/de-capping tool |
| honey_bucket.png | White bucket with honey (inventory item) |

### D3. REGENERATE Existing Item Sprites (32x32, Leonardo AI)
All existing item sprites are tiny placeholder PNGs (200-400 bytes each). Regenerate ALL of these through Leonardo to match the project's cohesive art style:

| Current File | Item Name |
|---|---|
| beehive.png | Beehive |
| beeswax.png | Beeswax |
| chest.png | Storage Chest |
| deep_body.png | Deep Hive Body |
| deep_box.png | Deep Box |
| fermented_honey.png | Fermented Honey |
| frames.png | Frames |
| full_super.png | Full Honey Super |
| gloves.png | Beekeeping Gloves |
| hive_lid.png | Hive Lid |
| hive_stand.png | Hive Stand |
| hive_tool.png | Hive Tool |
| honey_bulk.png | Honey Bulk (5 lb) |
| honey_jar_economy.png | Economy Honey Jar |
| honey_jar_premium.png | Premium Honey Jar |
| honey_jar_standard.png | Standard Honey Jar |
| jar.png | Empty Glass Jar |
| package_bees.png | Package Bees |
| pollen.png | Pollen |
| queen_cage.png | Queen Cage |
| queen_excluder.png | Queen Excluder |
| raw_honey.png | Raw Honey |
| refractometer.png | Refractometer |
| seeds.png | Seeds |
| smoker.png | Bee Smoker |
| sugar_syrup.png | Sugar Syrup |
| super_box.png | Honey Super Box |
| syrup_feeder.png | Syrup Feeder |
| treatment_formic.png | Formic Acid Treatment |
| treatment_oxalic.png | Oxalic Acid Treatment |
| uncapping_knife.png | Uncapping Knife |
| veil.png | Bee Veil |

**Total:** 32 existing items to regenerate + 2 new items = 34 item sprites
**Plus:** 6 station sprites for honey house interior

---

## PHASE E: Integration & Polish

### E1. Wire Up Full Pipeline End-to-End
- Test complete flow: mark frames -> remove super -> prep -> uncap -> spin -> can
- Verify inventory changes at each step (items consumed/produced correctly)
- Verify energy costs deducted properly
- Verify beeswax accumulates correctly

### E2. Add Sound Effects
- Super cracking open
- Frame scraping (uncapping)
- Spinner whirring (escalating with E presses)
- Honey pouring
- Glass jar clink

### E3. Add Notifications and Feedback
- Toast notifications at each step completion
- Running counters during uncapping ("Frame 3/10")
- Spinner progress bar with "Keep pressing E!" prompt
- Jar filling counter

### E4. Update Changelog
- Document all harvest loop additions
- Note GDD deviations (batch spinner, no L1 grading, new station names)

---

## Recommended Implementation Order

The most efficient sequence considering dependencies:

1. **B3** - Define new items (no dependencies, quick)
2. **A1** - Frame marking in InspectionOverlay (foundational, unlocks everything)
3. **A2** - Verify super removal works (quick, builds on A1)
4. **D2 + D3** - Leonardo art generation (can run in parallel with code work)
5. **B2** - Honey House controller script (core state machine)
6. **C1** - Super Prep Area mechanic
7. **C2** - Frame Holder
8. **C3** - Uncapping mini-game (biggest single task)
9. **C4** - Honey Spinner mechanic
10. **C5** - Canning Table mechanic
11. **D1** - Station sprites (needed before B1)
12. **B1** - Honey House interior layout (needs art + controller)
13. **E1-E4** - Integration, sound, polish

**Estimated scope:** ~15-20 focused implementation sessions
