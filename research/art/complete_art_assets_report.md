# Smoke & Honey - Complete Art Asset Inventory

**Date:** 2026-03-31
**Compiled from:** GDD (Smoke_and_Honey_GDD.html) + Art Assets Spreadsheet (bddzfrb4s.txt)
**Status Summary:** 170 DONE (97.7%) | 4 NEEDED (2.3%) | 174 TOTAL

---

## ASSET OVERVIEW BY CATEGORY

### 1. PLAYER CHARACTER
**Asset Name:** Player sprite sheet — beekeeper
- **Category:** Character
- **Sub-Category:** Player
- **Size:** 16×32px × 12 frames (960×2880px full sheet)
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Recraft.ai / pixellabs.ai
- **Path:** res://assets/sprites/player/player_beekeeper.png
- **Notes:** 8 directions, 3 frames each walk cycle. White suit, mesh veil helmet. Top-down RPG style. Stardew Valley inspired palette, no black outlines.

**Asset Name:** Player idle sprite — beekeeper
- **Category:** Character
- **Sub-Category:** Player
- **Size:** 16×32px
- **Phase:** 1.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Recraft.ai / pixellabs.ai
- **Path:** res://assets/sprites/player/player_beekeeper_idle.png
- **Notes:** Standing still, facing down. Matches walk cycle style.

---

### 2. NPC CHARACTERS — OVERWORLD SPRITES

**Asset Name:** Uncle Bob NPC — overworld sprite
- **Size:** 16×32px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Recraft.ai / pixellabs.ai
- **Path:** res://assets/sprites/npc/uncle_bob.png
- **Notes:** Older man (60s), denim overalls, plaid flannel, gray hair. Warm earthy tones. Friendly round face. No black outlines.

**Asset Name:** Frank Fischbach — overworld sprite
- **Size:** 16×32px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Recraft.ai / pixellabs.ai
- **Path:** res://assets/sprites/npc/frank_fischbach.png
- **Notes:** Market vendor, middle-aged, apron, friendly. Warm tones. Saturday Market scene.

**Asset Name:** Dr. Ellen Harwick — overworld sprite
- **Size:** 16×32px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Recraft.ai / pixellabs.ai
- **Path:** res://assets/sprites/npc/dr_harwick.png
- **Notes:** Extension agent, professional, clipboard, smart casual clothing.

**Asset Name:** Walt Harmon — overworld sprite
- **Size:** 16×32px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Recraft.ai / Claude (AI Generated)
- **Path:** res://assets/sprites/npc/walt_harmon.png
- **Notes:** Corn/soybean farmer. Worn work clothes, cap. Reserved posture in Year 1, opens up in later years.

**Asset Name:** Kacey Harmon — overworld sprite
- **Size:** 16×32px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Recraft.ai / Claude (AI Generated)
- **Path:** res://assets/sprites/npc/kacey_harmon.png
- **Notes:** Younger farmer, sustainability-minded, casual work clothes.

**Asset Name:** Carl Tanner — overworld sprite
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/npc/carl_tanner.png
- **Notes:** Supply store owner.

**Asset Name:** June Postmaster — overworld sprite
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/npc/june_postmaster.png
- **Notes:** Post office NPC.

**Asset Name:** Rose — Waitress overworld sprite
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/npc/rose_waitress.png
- **Notes:** Diner waitress.

**Asset Name:** Pedestrian A — generic overworld NPC
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Notes:** Ambient townsperson.

**Asset Name:** Pedestrian B — generic overworld NPC
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Notes:** Ambient townsperson.

**Asset Name:** Pedestrian C — generic overworld NPC
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Notes:** Ambient townsperson.

**Asset Name:** Darlene Kowalski — overworld sprite
- **Size:** 120×120px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** NEEDED
- **Method:** pixellabs.ai
- **Path:** res://assets/sprites/npc/Darlene_Kowalski/darlene_spritesheet.png
- **Notes:** Retired master beekeeper (60s+), warm and practical. 8-direction spritesheet format. Adjacent property NPC; Year 1 teacher.

---

### 3. NPC DIALOGUE PORTRAITS

**Asset Name:** Uncle Bob NPC — dialogue portrait
- **Size:** 64×64px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/npc/uncle_bob_portrait.png
- **Notes:** Bust shot, warm smile. Slightly higher detail than overworld sprite. Used in dialogue box UI.

**Asset Name:** Frank Fischbach — dialogue portrait
- **Size:** 64×64px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/npc/frank_portrait.png
- **Notes:** Bust shot, apron, friendly smile.

**Asset Name:** Darlene Kowalski — dialogue portrait
- **Size:** 64×64px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** NEEDED
- **Method:** pixellabs.ai
- **Path:** res://assets/sprites/npc/darlene_portrait.png
- **Notes:** Bust shot, warm smile, gray hair. Practical look. Matches overworld character. Used in dialogue box UI.

---

### 4. HIVE INSPECTION — CORE LOOP

**Asset Name:** Overworld hive sprite
- **Size:** 26×36px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Procedural / Python
- **Path:** res://assets/sprites/hive/overworld_hive.png
- **Notes:** 3-super Langstroth + stand + cover. Off-white warm paint, dark entrance slot. Connected to hive.tscn.

**Asset Name:** Overworld hive — shadow layer
- **Size:** 26×36px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Procedural / Python
- **Path:** res://assets/sprites/hive/overworld_hive_shadow.png
- **Notes:** Soft dark drop shadow offset SE. RGBA(0,0,0,80). Renders below hive sprite.

**Asset Name:** Overworld hive — health tint states
- **Phase:** 1.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Code (modulate)
- **Notes:** Applied via sprite.modulate in hive.gd. No separate art file. White=healthy, amber=warning, pink=poor.

**Asset Name:** Frame border — inspection view
- **Size:** 1920×1080px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Procedural / Python
- **Path:** res://assets/sprites/generated/frame/frame_border_1920x1080.png
- **Notes:** Warm wood grain. Top bar 60px (finger notches), sides 50px, bottom 20px. Interior transparent. Cell grid rendered on top by FrameRenderer.gd.

---

### 5. CELL STATE SPRITES (Hive Inspection)

All 26×20px cells. 14 states procedurally generated:

**States 0-13:**
- 00_empty_foundation: Pale ivory hex outline, wall #A89858, interior #E8DFB8
- 01_drawn_empty: Cream wax with shadow bottom, highlight top
- 02_egg: Near-white vertical stroke (2×4px) at center
- 03_larva_open: White C-shaped curled grub in lower cell
- 04_capped_brood: Flat tan/brown wax cap with highlights
- 05_capped_drone: Slightly more domed than worker brood
- 06_nectar_uncured: Pale watery gold, shimmer highlights
- 07_curing_honey: Medium amber, glossy shimmer
- 08_capped_honey: Domed amber cap, highlight arc
- 09_premium_honey: Deep amber, domed cap + bright sheen dot
- 10_varroa: Brood cap + 2×2 red mite dot upper-right (#C03020)
- 11_afb: Sunken dark irregular cap, concave centre (#584020)
- 12_queen_cell: Vertical peanut/acorn shape, ridged texture
- 13_vacated: Darkened used cell with faint silk remnant lines

**Asset Name:** Cell atlas (all 14 states)
- **Size:** 364×20px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Procedural / Python
- **Path:** res://assets/sprites/generated/cells/cell_atlas.png
- **Notes:** All cells in a row for sprite sheet import in Godot.

---

### 6. BUILDINGS — EXTERIOR SPRITES

**Asset Name:** Cedar Bend Feed & Supply — building
- **Size:** ~80×64px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Recraft.ai / Scenario
- **Path:** res://assets/sprites/world/buildings/feed_supply.png
- **Notes:** Tan clapboard siding, wooden porch with barrels, hand-painted sign. Cainos style. Main supply shop.

**Asset Name:** Cedar Bend Diner — building
- **Size:** ~80×64px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Recraft.ai / Scenario
- **Path:** res://assets/sprites/world/buildings/diner.png
- **Notes:** Cream plaster walls, red-and-white striped awning, glass front door. Darlene's social hub.

**Asset Name:** Cedar Bend Grange Hall
- **Size:** ~96×72px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Recraft.ai / Scenario
- **Path:** res://assets/sprites/world/buildings/grange_hall.png
- **Notes:** Rural community hall, modest, wood siding. Cedar Valley Beekeepers Assoc. location.

**Asset Name:** Post Office building
- **Size:** ~80×64px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/buildings/post_office.png

**Asset Name:** Crossroads Diner — exterior
- **Size:** ~96×80px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/buildings/crossroads_diner.png

---

### 7. WORLD PROPS & ENVIRONMENT

**Asset Name:** Saturday Market stall
- **Size:** 32×48px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Recraft.ai
- **Path:** res://assets/sprites/world/props/market_stall.png
- **Notes:** Wooden counter, tan/green striped canvas awning, honey jars on counter. Frank Fischbach's stall.

**Asset Name:** Truck / farm vehicle (overworld prop)
- **Size:** ~32×16px
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/props/truck.png

**Asset Name:** Mailbox — flag down
- **Size:** ~8×12px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/props/mailbox_down.png

**Asset Name:** Mailbox — flag up
- **Size:** ~8×12px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/props/mailbox_up.png

**Asset Name:** Road gravel tile
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/tiles/road_gravel.png

**Asset Name:** Road center line stripe
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/props/road_center_line.png

**Asset Name:** Ditch grass tile
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/tiles/ditch_grass.png

**Asset Name:** Hive spot marker (placement indicator)
- **Size:** 16×16px
- **Phase:** 1.0 | **Priority:** P1
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/environment/hive_spot_marker.png

**Asset Name:** Garden bed / planting plot
- **Size:** 32×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/props/garden_bed.png

**Asset Name:** Background strip / scene edge
- **Size:** Tileable
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/tiles/background_strip.png

**Asset Name:** Willow tree (overworld)
- **Size:** ~24×32px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Claude (AI Generated)
- **Path:** res://assets/sprites/world/forage/willow_tree.png

---

### 8. INTERIOR SPRITES

**Asset Name:** Diner booth seating
- **Size:** 32×24px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_booth.png

**Asset Name:** Diner counter
- **Size:** ~128×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_counter.png

**Asset Name:** Diner stool
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_stool.png

**Asset Name:** Diner floor tile
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_floor.png

**Asset Name:** Diner television
- **Size:** ~24×20px
- **Phase:** 2.0 | **Priority:** P3
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_tv.png

**Asset Name:** Diner pie case
- **Size:** ~24×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_pie_case.png

**Asset Name:** Diner chalkboard menu
- **Size:** ~32×24px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/diner_chalkboard.png

**Asset Name:** Supply store shelves
- **Size:** ~48×32px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/supply_shelves.png

**Asset Name:** Post office counter
- **Size:** ~64×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/post_office_counter.png

**Asset Name:** Post office pigeonholes
- **Size:** ~48×32px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/post_office_pigeonholes.png

**Asset Name:** Community bulletin board
- **Size:** ~32×24px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Path:** res://assets/sprites/interiors/bulletin_board.png

---

### 9. INVENTORY ITEM ICONS

All 16×16px initially, upgraded to 32x32px (Phase 2.0):

**Honey Grades:**
- honey_jar_standard: Rounded amber glass jar, gold lid, warm amber #C8860A
- honey_jar_premium: Deeper amber, extra sheen highlight, star/ribbon indicator. ≤17% moisture
- honey_jar_economy: Lighter/cloudy amber, less polished than standard. >18.6% moisture

**Tools:**
- smoker: Tin cylinder body, brown leather bellows, smoke wisp
- hive_tool: J-shaped steel scraper/pry tool, gray metal, warm brown handle
- veil: Mesh veil + hat, off-white with dark mesh detail
- uncapping_knife: Long-bladed knife, warm wood handle, golden wax sheen
- refractometer: Small cylindrical optical instrument, blue/gray metal. Unlocks Level 2

**Ingredients & Supplies:**
- sugar_syrup: Clear/pale glass jar, slightly cloudy white liquid
- beeswax: Pale yellow wax block, warm honey-yellow tone

**Status:** All DONE ✓ | Method: Recraft.ai or Procedural | Phase: 1.0-2.0

---

### 10. WILDFLOWER OVERLAYS & FORAGE

**Asset Name:** Wildflower overlay — clover
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Notes:** White/pink clover flowers over olive green grass. Key summer forage — white clover

**Asset Name:** Wildflower overlay — dandelion
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Notes:** Yellow dandelion dots over grass. Spring forage indicator

**Asset Name:** Wildflower overlay — goldenrod
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Notes:** Tall golden-yellow flower cluster. Fall forage

**Asset Name:** Wildflower overlay — linden
- **Size:** 16×16px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Notes:** Small cream-white flowers. Unlocked with Petersen Farm access. Premium linden honey source

**Asset Name:** Wildflower tile (generic overlay)
- **Size:** 16×16px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓

---

### 11. FORAGE FLOWER LIFECYCLE STAGES

**5 lifecycle stages per flower x 7 flower types = 35 assets**
All 16×16px, Claude (AI Generated), Phase 3.0, Status DONE ✓

Stages: Seed (dormant), Sprout (emerging), Growing (bud), Mature (blooming), Withered (end of lifecycle)

**Flowers:**
- Clover (5 sprites + 1 alternate tile = 6 total)
- Dandelion (5 + 1 alternate = 6)
- Goldenrod (5 sprites)
- Aster (5 sprites)
- Bergamot (Wild) (5 sprites)
- Coneflower (5 sprites)
- Lavender (5 sprites)
- Phacelia (5 sprites)
- Sunflower (5 sprites)

---

### 12. UI ELEMENTS — LANGSTROTH FRAME SYSTEM

**Button States:**
- Button — normal state: ~32×16px
- Button — hover state: ~32×16px
- Button — pressed state: ~32×16px
Status: All DONE ✓ | Phase: 2.0 | Priority: P1

**Panels & Dialogue:**
- Dialogue panel: Tileable
- Menu panel: Tileable
- Speech bubble: Tileable
- Title plate: ~128×32px
- Interact prompt background: ~48×16px
Status: All DONE ✓ | Phase: 2.0 | Priority: P1-P2

**Bars:**
- Energy bar background: Tileable
- Energy bar fill: Tileable
- XP bar background: Tileable
- XP bar fill: Tileable
- XP bar texture: Tileable
Status: All DONE ✓ | Phase: 2.0-3.0 | Priority: P1-P3

**HUD Bars:**
- HUD top bar: 1920×20px
- HUD bottom bar: 1920×20px
Status: Both DONE ✓ | Phase: 2.0 | Priority: P1

**Slots & Inventory:**
- Inventory slot background: 18×18px
- Inventory slot — new item variant: 18×18px
Status: Both DONE ✓ | Phase: 2.0 | Priority: P2

**Notifications:**
- Notification background: Tileable, Phase 2.0, Priority P2

---

### 13. HUD ICONS

All 16×16px, Claude (AI Generated), Phase 2.0, Status DONE ✓

- HUD icon — bee
- HUD icon — energy
- HUD icon — honey jar
- HUD icon — money/cash
- HUD icon — season (Spring)
- HUD icon — season (Summer)
- HUD icon — season (Fall)
- HUD icon — season (Winter)
- HUD icon — XP star

---

### 14. MAP & NAVIGATION

**Asset Name:** Map background
- **Size:** Tileable
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓

**Map Pins** (all 8×12px, Phase 2.0, Priority P1-P2):
- Map pin — home
- Map pin — locked location
- Map pin — road/travel
- Map pin — town

**Asset Name:** Map travel cursor
- **Size:** 16×16px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓

**Asset Name:** Weather icon sheet
- **Size:** 16×16px each
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓

---

### 15. UI CHROME & VISUAL ELEMENTS

**Asset Name:** UI frame / panel texture
- **Size:** Tileable
- **Phase:** 4.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Cainos pack / custom

**Asset Name:** Knowledge Log page texture
- **Size:** Tileable
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Custom
- **Notes:** Aged paper texture. Warm cream with subtle grain.

**Asset Name:** Level badge
- **Size:** ~20×20px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓

**Asset Name:** Overlay dim
- **Size:** 1920×1080px
- **Phase:** 2.0 | **Priority:** P1
- **Status:** DONE ✓
- **Notes:** Screen overlay for menu dimming

**Asset Name:** Season transition overlay
- **Size:** 1920×1080px
- **Phase:** 4.0 | **Priority:** P3
- **Status:** NEEDED
- **Method:** Code (shader/tween)
- **Notes:** Animated transition screen between seasons

---

### 16. VISUAL EFFECTS (FX)

**Asset Name:** Bee swarm particle — single bee
- **Size:** 8×8px
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Recraft.ai or Procedural
- **Notes:** Warm golden-yellow body, black stripe, tiny wings. Generate at 256×256, scale down. Used in CPUParticles2D

**Asset Name:** Forager bee returning (overworld)
- **Size:** 6×6px
- **Phase:** 3.0 | **Priority:** P3
- **Status:** DONE ✓
- **Method:** Procedural
- **Notes:** Same bee, slightly larger pollen basket (yellow blob on legs)

**Asset Name:** Smoke puff FX
- **Size:** 16×16px × 4 frames
- **Phase:** 2.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Cainos pack / Procedural

---

### 17. QUEEN IDENTIFICATION

**Asset Name:** Queen marker — white (years 1/6)
- **Size:** 8×8px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓
- **Method:** Procedural

**Asset Name:** Queen marker — yellow (years 2/7)
- **Size:** 8×8px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓

**Asset Name:** Queen marker — red (years 3/8)
- **Size:** 8×8px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓

**Asset Name:** Queen marker — green (years 4/9)
- **Size:** 8×8px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓

**Asset Name:** Queen marker — blue (years 5/0)
- **Size:** 8×8px
- **Phase:** 3.0 | **Priority:** P2
- **Status:** DONE ✓
- **Notes:** International color-year system for queen marking

---

### 18. BRANDING & LOGO

**Asset Name:** Smoke & Honey game logo
- **Size:** 1200×1200px
- **Phase:** 4.0
- **Status:** DONE ✓
- **Method:** Leonardo AI (Lucid Origin)
- **Path:** assets/ui/logo/game_logo.png
- **Notes:** Horizontal layout: bee smoker (40% width) + game title (60% width). Silver-gray smoker body, copper-brown bellows, cream/amber text. Used for title screen, Steam capsule, itch.io, Kickstarter, press kit. No drop shadows on dark backgrounds.

---

## NEEDED ASSETS (4 ITEMS — 2.3%)

1. **Darlene Kowalski — overworld sprite**
   - Size: 120×120px
   - Method: pixellabs.ai
   - Path: res://assets/sprites/npc/Darlene_Kowalski/darlene_spritesheet.png
   - Notes: Retired master beekeeper. 8-dir spritesheet. Year 1 teacher NPC.

2. **Darlene Kowalski — dialogue portrait**
   - Size: 64×64px
   - Method: pixellabs.ai
   - Path: res://assets/sprites/npc/darlene_portrait.png
   - Notes: Bust shot, gray hair, warm smile. Dialogue UI.

3. **Uncle Bob NPC — dialogue portrait**
   - Size: 64×64px
   - Status: Already marked DONE in spreadsheet but confirm in-game
   - Notes: May be listed as DONE but worth verifying

4. **Season transition overlay**
   - Size: 1920×1080px
   - Phase: 4.0 (Polish)
   - Method: Code (shader/tween)
   - Notes: Animated fade between seasonal palette shifts

---

## ASSET STATISTICS

**Total Assets:** 174

**By Status:**
- DONE: 170 (97.7%)
- NEEDED: 4 (2.3%)
- IN PROGRESS: 0
- PLACEHOLDER: 0

**By Phase:**
- Phase 1.0: 26 assets (Core loop)
- Phase 2.0: 83 assets (Gameplay loop)
- Phase 3.0: 63 assets (Depth/forage)
- Phase 4.0: 2 assets (Polish)

**By Priority:**
- P1 (Blocking): 55 assets
- P2 (Soon): 102 assets
- P3 (Later): 17 assets

**By Category:**
- UI Elements: ~50 assets
- Characters (NPC + Player): 15 assets
- Hive/Cells: 16 assets
- World Props/Buildings: 20+ assets
- Forage/Flowers: 35+ assets (lifecycle stages)
- Effects: 3 assets
- Branding: 1 asset
- Miscellaneous (markers, tiles, interiors): 30+ assets

---

## VISUAL STYLE GUIDE (FROM GDD)

**Overall Aesthetic:** Warm, muted, cozy top-down pixel art. Illustrated field guide meets Stardew Valley — pastoral, nostalgic, grounded. Lit by soft afternoon Iowa sunlight.

**Color Palette:**
- Base: Muted olive-green grass, sandy tan dirt, warm gray stone, dark slate roofs, warm brown timber
- Spring tint: Soft green + cream
- Summer: Deep green + amber
- Fall: Burnt orange + burgundy
- Winter: Muted blue-gray + warm interior light
- No pure saturated primaries

**Technical Specs:**
- Grid: 32×32 tiles primary, 16×16 for details
- Sprite depths: 2-3 tones per color (mid → light highlight → dark shadow)
- Dithering: Ground textures only, not characters/buildings
- Shadows: Separate layer, soft drop shadow offset SE, never baked into sprite
- References: Cainos asset pack (foundation), Stardew Valley (world scale), Harvest Moon GBA (mood)

**Hive Inspection (separate scene):**
- Front-facing view (not top-down), higher detail than overworld
- Readable hexagonal cell grid, color-coded states
- Same warm amber/tan palette family
- Field guide illustration style, cozy aesthetic

---

## NOTES FOR ART GENERATION

1. **Leonardo AI Workflow:** All new art should reference the "Smoke and Honey" collection in Leonardo for style cohesion
2. **GDD Master Prompt:** Use GDD §10.1 style guide as base template
3. **Perspective:** Front-facing view with camera directly in front; no isometric, no side walls; roof extends away (top of image) showing shingle texture; front facade is flat strip at bottom
4. **Frame of Reference:** "Does it look like it belongs in the Cainos Village scene?" — if yes, ship it; if no, regenerate
5. **Approval Required:** Every generated asset shown to Nathan before adding to project or collection
6. **ASCII Only:** All .gd script files must contain only ASCII (0-127 bytes); no Unicode characters
7. **Color Tags for Frames:** Brood box frames have warm brown border; super frames have golden/amber border

---

## KEY ASSET PATHS

```
res://assets/sprites/hive/               - Hive sprites, shadows, markers
res://assets/sprites/generated/cells/    - 14 cell state sprites (procedural)
res://assets/sprites/generated/frame/    - Frame inspection border (procedural)
res://assets/sprites/player/             - Player character sprites
res://assets/sprites/npc/                - NPC overworld & portrait sprites
res://assets/sprites/items/              - Inventory item icons (32×32)
res://assets/sprites/world/forage/       - Wildflower overlays & lifecycle stages
res://assets/sprites/world/buildings/    - Building exteriors
res://assets/sprites/world/props/        - Market stalls, trucks, mailboxes
res://assets/sprites/interiors/          - Diner, post office, supply store furniture
res://assets/sprites/fx/                 - Particles (bees, smoke)
res://assets/sprites/ui/                 - All UI elements (Langstroth frame system)
res://assets/ui/logo/                    - Game logo
```

---

**Report Generated:** 2026-03-31
**File Locations Referenced:**
- GDD: /sessions/gracious-optimistic-cerf/mnt/SmokeAndHoney/Smoke_and_Honey_GDD.html
- Spreadsheet: /sessions/gracious-optimistic-cerf/mnt/.claude/projects/-sessions-gracious-optimistic-cerf/d0bbb10c-7622-4a82-9ac6-676dd630d984/tool-results/bddzfrb4s.txt
