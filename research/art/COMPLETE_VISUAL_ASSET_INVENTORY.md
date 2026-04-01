# Smoke & Honey: Complete Visual Asset Inventory

**Document Version:** 1.0
**Date:** 2026-03-31
**Purpose:** Comprehensive specification of ALL visual and art content required for Smoke & Honey pixel art development

This document is the authoritative source for what a pixel artist needs to create. Every section below represents assets that must be drawn, animated, or rendered at the specified dimensions and style.

---

## CRITICAL STYLE RULES

These rules apply to EVERY asset created. Non-compliance breaks visual cohesion.

1. **No pure black (#000000) outlines.** All edges use the darkest shade of the local hue. This is the single most important rule.
2. **No bright saturated colors.** Everything is muted and earthy.
3. **2–3 shade depth per color family.** Highlight, mid, shadow. Not flat, not over-rendered.
4. **Soft drop shadows as separate layer.** Never baked into sprites. Allows shadow toggling.
5. **Top-down perspective with ~15° north-tilt.** SNES/GBC RPG view. Roof is dominant; front wall peeks below.
6. **No pure white backgrounds.** Always transparent PNG.
7. **No fantasy/medieval theming.** Rural Iowa aesthetic only.
8. **Heavy dithering on ground tiles only.** Never on characters or buildings.
9. **Match Cainos Village asset pack style exactly.** Reference: Cainos Pixel Art Top Down – Village (v1.0.7)

---

## SECTION 1: GAME LOGO & BRANDING

### 10.0 Game Logo

**Asset:** Smoke & Honey Logo Mark
- **Dimensions:** 1200×1200 px (source), scalable down
- **Composition:** Horizontal split
  - LEFT (40%): Bee smoker — squat wide silver cylinder body
  - RIGHT (60%): Game title stacked text
- **Smoker Design Details:**
  - Silver-gray barrel cylinder body (main body)
  - Flat rectangular rigid leather board bellows panels (left face, stacked like closed book boards)
  - Copper rivets holding bellows boards
  - Wide dome/cone lid narrowing to cylindrical tube at apex
  - Small side spout nozzle on right face emitting thin wispy smoke curls (upward)
  - Smoke comes ONLY from side spout, NOT from top opening
- **Typography:**
  - "Smoke" on top line
  - Large stylized "&" (ampersand) in center
  - "Honey" on bottom line
  - Font: Ornate amber-orange calligraphic script
  - Highlights: Cream/off-white
  - Outline/shadow: Warm brown
  - Decorative swash flourish beneath "Honey"
- **Background:**
  - Deep warm amber-brown radial gradient (darker edges, lighter behind smoker)
  - Range: #3a1800 to #6a3000
  - No hex drip motifs
  - No border frames
- **Color Palette:**
  - Smoker body: Silver-gray
  - Smoker bellows: Copper-brown
  - Rivets: Dark copper
  - Text fill: Amber-gold
  - Text highlights: Cream
  - Text shadow: Dark brown
- **Usage:** Title screen, Steam capsule art, itch.io header, Kickstarter banner, press kit
- **Source:** Leonardo AI (Lucid Origin model)

---

## SECTION 2: PLAYER CHARACTER

### Player Beekeeper Sprite

**Asset:** beekeeper_spritesheet.png
- **Dimensions:** 960×2880 px total spritesheet (8 columns × 24 rows)
- **Per-Frame:** 120×120 px per animation frame
- **Perspective:** Top-down with north-tilt
- **Appearance:**
  - Off-white beekeeper suit (with warm cream cast, not pure white)
  - Mesh veil attached to head
  - Visible hands and boots
  - Warm earth-tone color family overall
  - Distinct silhouette vs. NPCs
- **Animation States (per direction):**
  - Idle: 1 frame per direction (8 total frames)
  - Walk cycle: 8 frames per direction (64 total frames)
  - Run cycle: 8 frames per direction (64 total frames)
- **Directions:** 8-directional movement (N, NE, E, SE, S, SW, W, NW)
- **Layout in Spritesheet:**
  - Column 0-7: Frame index within animation
  - Row 0-2: Direction N (idle, walk, run frames)
  - Row 3-5: Direction NE
  - Row 6-8: Direction E
  - Row 9-11: Direction SE
  - Row 12-14: Direction S
  - Row 15-17: Direction SW
  - Row 18-20: Direction W
  - Row 21-23: Direction NW
- **Special Notes:**
  - Runtime-loaded via Image.load_from_file() (no Godot import pipeline dependency)
  - Used for all overworld navigation
  - Veil and suit details must be readable at 120px without looking cartoonish

---

## SECTION 3: NPC CHARACTERS

### Uncle Bob (Home Property NPC)

**Asset:** uncle_bob_spritesheet.png
- **Dimensions:** 960×2880 px (8 cols × 24 rows)
- **Per-Frame:** 120×120 px
- **Perspective:** Top-down with north-tilt (matching player sprite)
- **Appearance:**
  - Older man (late 60s–70s)
  - Denim overalls (worn, muted denim blue)
  - Plaid flannel shirt (warm browns and muted reds)
  - Gray hair
  - Warm earth-tone color family
  - Distinct silhouette from player and other NPCs
- **Animation States:**
  - Idle: 1 frame per direction
  - Walk cycle: 8 frames per direction
  - Run cycle: 8 frames per direction (8 directions total)
- **Layout:** Same as player spritesheet (rows 0-23, columns 0-7)
- **Special Notes:**
  - Stands at position (380, 140) on home property
  - Appears at Crossroads Diner on Tuesday mornings
  - Visible at start, tutorial anchor
  - Body language should read as experienced, practical
  - Runtime-loaded via Image.load_from_file()

### NPC Character Template (Other NPCs)

The following NPCs require 120×120 px spritesheets in the same format:

- **Darlene Kowalski** (Retired master beekeeper, late 60s)
  - Clothing: Practical work wear, perhaps a denim jacket
  - Color family: Warm, lived-in
  - Silhouette: Distinct from Uncle Bob

- **Frank Fischbach** (Market vendor)
  - Clothing: Market-casual, functional
  - Color family: Warm earth tones
  - Silhouette: Distinct, memorable

- **Dr. Ellen Harwick** (Extension agent)
  - Clothing: Professional but approachable (field expert style)
  - Color family: Cool/professional tones mixed with warm accents
  - Silhouette: Distinct

- **Walt Harmon & Kacey** (Harmon Farm family)
  - Walt: Farmer overalls/work wear, weathered
  - Kacey: Modern practical work clothes
  - Silhouettes: Distinct from each other

- **Silas Crenshaw** (Carpenter)
  - Clothing: Work clothes, tool apron
  - Color family: Warm wood/leather tones
  - Silhouette: Distinct, craftsman bearing

All NPCs follow the same 120×120 px, 8-direction, multi-frame animation structure.

---

## SECTION 4: BUILDINGS & STRUCTURES (OVERWORLD)

### Home Property Main House

**Asset:** house_exterior_sprite.png
- **Dimensions:** ~160–200 px wide × 120–140 px tall
- **Perspective:** Top-down north-tilt (shows roof dominant, front face below)
- **Building Type:** Single-story white clapboard farmhouse
- **Details:**
  - Front porch with two steps
  - Screen door (visible, interactive entry point)
  - One visible window with curtains
  - Flower box under window
  - Modest but well-kept appearance
  - World space: ~12m wide × 6m tall
- **Seasonal Variants:**
  - Summer: Open windows, lighter appearance
  - Winter: Smoke from chimney, snow on roof
  - Spring: Mud on steps
  - All variants use same base sprite with optional layer overlays
- **Shadow:** Separate sprite layer

### Honey House / Extraction Facility

**Asset:** honey_house_sprite.png
- **Dimensions:** ~160–180 px wide × 140–160 px tall
- **Perspective:** Top-down north-tilt
- **Building Type:** Uncle Bob's old extraction facility (dilapidated at start, restored through Carpenter quest chain)
- **Initial State:** Weathered, needs repair
  - Broken windows (visible cracks)
  - Worn exterior
  - Roof in disrepair
- **Restored State:** Fully functional
  - Fixed windows
  - Fresh paint/repairs
  - Sound roof
  - Clean appearance
- **Interior Layout:** Contains:
  - Scraping Station (with Super Pallet)
  - Honey Extractor (batch extractor equipment)
  - Bottling Table
  - Storage areas
- **Shadow:** Separate sprite layer

### Apiary Shed

**Asset:** shed_sprite.png
- **Dimensions:** ~120–140 px wide × 100–120 px tall
- **Perspective:** Top-down north-tilt
- **Building Type:** Small wooden shed/storage building
- **Details:**
  - Weathered wood exterior
  - Simple door
  - Windows optional (may be covered)
  - Houses equipment and supplies
- **Shadow:** Separate sprite layer

### Cedar Bend Town Buildings

#### Cedar Bend Feed & Supply

**Asset:** feed_supply_building.png
- **Dimensions:** ~80–96 px wide × 60–80 px tall
- **Perspective:** Top-down north-tilt
- **Details:**
  - Tan clapboard siding
  - Wooden porch
  - Barrels outside (decoration/props)
  - Must match Cainos building style exactly
  - Storefront feel
- **Shadow:** Separate sprite layer

#### Cedar Bend Diner (Crossroads Diner)

**Asset:** diner_building.png
- **Dimensions:** ~80–96 px wide × 60–80 px tall
- **Perspective:** Top-down north-tilt
- **Details:**
  - Cream plaster walls
  - Red-and-white striped awning
  - Glass front door
  - Windows showing interior warmth
  - Welcoming appearance
- **Shadow:** Separate sprite layer

#### Market Stall (Saturday Market)

**Asset:** market_stall_sprite.png
- **Dimensions:** 32×48 px
- **Details:**
  - Tan/green striped awning
  - Wooden counter
  - Honey jars displayed
  - Frank Fischbach's vendor location
- **Shadow:** Separate sprite layer

### Miscellaneous Town Buildings

The following structures appear in Cedar Bend and surrounding areas:
- Grange Hall (meeting location)
- General stores
- Town offices
- Other rural structures

All must match Cainos Village building style (muted palette, top-down view, no pure black outlines).

---

## SECTION 5: HIVE & APIARY EQUIPMENT

### Modular Overworld Hive Sprites

These sprites are stacked vertically to show hive growth as the player adds boxes.

**Asset Collection:**

| Sprite | Dimensions | Description |
|--------|-----------|-------------|
| hive_base.png | 24×6 px | Bottom board + landing strip (white with shadow) |
| hive_deep.png | 24×14 px | Deep body (darker wood tone, ~9.6" in real size) |
| hive_super.png | 24×10 px | Medium honey super (lighter wood tone, ~6.6" in real size) |
| hive_excluder.png | 24×2 px | Queen excluder (thin metal-grey strip) |
| hive_lid.png | 24×6 px | Telescoping outer cover (always on top) |

**Color Reference:**
- Deep body: Darker, richer wood brown
- Super: Lighter, warmer wood tone
- Excluder: Metal grey (not pure gray)
- Base/Lid: White-painted wood with warm shadows

**Assembly Examples:**
- Single deep: base + deep + lid = 26 px tall
- Deep + super: base + deep + excluder + super + lid = 38 px tall
- 2 deeps + 2 supers: base + deep + deep + excluder + super + super + lid = 62 px tall

**Shadow:** Separate sprite layer beneath entire stack

### Hive Stands

**Asset:** hive_stand_sprites.png (×5 variants)
- **Dimensions:** ~40 px tall × 16 px wide
- **Details:**
  - Simple wooden two-post stand
  - Weathered brown wood tone
  - Supports bottom board + hive body + super stack
  - Different visual styles (5 variants) for aesthetic variety
  - Can show aging/weathering progression

**Usage:** One hive stand under each hive. Visible in home property and other apiary locations.

### Bee Swarm / Flying Bee Particle

**Asset:** bee_particle_sprite.png
- **Dimensions:** 8×8 px
- **Details:**
  - Single bee sprite for particle system
  - Warm golden-yellow body
  - Black stripe (thorax/wing stripe)
  - Visible at hive entrance when bees are foraging
  - Density driven by forager population
  - Used in swarm animations

---

## SECTION 6: INVENTORY ITEMS & ICONS

### Hotbar Item Sprites (32×32 px)

All hotbar items display as 32×32 px pixel art in inventory slots.

**Complete Item List with Icons:**

1. **raw_honey** — Raw honey comb, amber/golden appearance
2. **pollen** — Bright golden/orange pollen ball
3. **seeds** — Small seed packet or individual seeds
4. **frames** — Wooden hive frame with foundation
5. **super_box** — Honey super box (flat view)
6. **beehive** — Small complete hive representation
7. **hive_stand** — Wooden stand for hive
8. **deep_body** — Deep brood body box
9. **hive_lid** — Outer cover/lid
10. **treatment_oxalic** — Oxalic acid treatment bottle/container
11. **treatment_formic** — Formic acid treatment container
12. **syrup_feeder** — Syrup feeder device
13. **queen_cage** — Queen introduction cage
14. **deep_box** — Deep body (duplicate/alternate icon)
15. **queen_excluder** — Metal grid excluder
16. **full_super** — Loaded honey super
17. **jar** — Empty glass jar
18. **honey_bulk** — Bulk honey container
19. **fermented_honey** — Spoiled honey (darker, sour appearance)
20. **chest** — Storage chest icon
21. **beeswax** — Beeswax lump (pale tan/cream)
22. **hive_tool** — Metal hive tool (pry bar shape)
23. **honey_jar_standard** — Filled honey jar (amber glass with golden lid)
24. **package_bees** — Package of bees (shipping box with breathing holes)
25. **sugar_syrup** — Syrup container/bucket
26. **gloves** — Beekeeper gloves
27. **smoker** — Bee smoker (tin cylinder with bellows)
28. **comb_scraper** — Flat-bladed scraping tool

**Visual Style Notes:**
- Simple, readable at 32×32
- Warm earth tones for most items
- Equipment metallic where appropriate (no pure silver)
- Use 2–3 shade depth per item
- Dark hue outlines only

---

## SECTION 7: TILESET ELEMENTS

### Ground Tiles (16×16 px)

The foundation tileset comes from **Cainos Pixel Art Top Down – Village** asset pack.

**Core Tile Types:**

| Tile Type | Color Palette | Variants |
|-----------|---------------|----------|
| Grass (unmowed) | Muted olive-yellow-green | 4–6 variants (slight color shifts) |
| Grass (mowed) | Slightly more tan, less green | Distinct from unmowed |
| Dirt path | Warm sandy tan with slight orange cast | 4–6 variants with directional marks |
| Stone/gravel | Warm gray stone tone | Rough texture |
| Water | Muted teal (river/stream) | Flowing effect, soft edges |
| Wood platform/boardwalk | Tan-to-medium brown | Weathered appearance |

**Special Overlays (16×16 px):**

| Overlay | Purpose |
|---------|---------|
| Wildflower forage tile | Clover/dandelion pixels over grass (seasonal) |
| Flower bed markers | Planted area indicators |
| Seasonal tint layers | Applied per-season (spring green, summer amber, fall orange, winter blue-gray) |

### Trees & Vegetation

**Tree Canopy Sprites:**
- **Dimensions:** Variable (typically 24–48 px wide × 32–64 px tall)
- **Color Palette:**
  - Dark forest green (shadow)
  - Muted olive green (mid)
  - Bright highlight dot (light leaf)
  - No pure green
- **Variants:** Apple tree, oak tree, pine tree, decorative shrubs
- **Seasonal Change:** Leaves darken in fall, appear snow-covered in winter, light green in spring

**Wildflower Patches:**
- Small 16×16 px overlays for seasonal flowers
- Dandelions (yellow dots on green)
- Clover (small purple/white tufts)
- Goldenrod (golden clusters)
- Appear during nectar flow seasons

### Fences & Barriers

**Wooden Fence Sprites:**
- Post-and-rail style fence
- Muted brown wood tone
- 16×16 px or 32×16 px sections
- No bright white or black

**Neighbor Property Fence:**
- Marks boundary between home property and Darlene's land
- Weathered, established appearance
- Clear visual boundary without being stark

---

## SECTION 8: UI ELEMENTS (LANGSTROTH FRAME DESIGN SYSTEM)

All UI uses the **Langstroth Frame Aesthetic** — wood borders and honeycomb cell interiors.

### Panel & Menu Backgrounds

**Asset:** menu_panel.png, dialogue_panel.png, panel_wood.png
- **Dimensions:** Variable (typically 320×240 px base, scaled as needed)
- **Design Elements:**
  - Thick wooden border (4 px, multi-tone brown)
  - Interior: Wax-cream background with subtle honeycomb cell overlay
  - Top header band: Solid wood with grain lines
  - Color palette: Warm amber/beeswax tones
- **Variations:**
  - Standard panel (neutral)
  - Dialogue panel (with portrait inset area in separate wooden sub-frame)
  - Inventory panel (for hotbar items)

### Buttons & Interactive Elements

**Asset Collection:** btn_normal.png, btn_hover.png, btn_pressed.png
- **Base Dimensions:** 64×32 px (scalable)
- **Visual Style:**
  - Individual honeycomb cell or small wooden frame segment
  - Normal state: Wax-cream interior with honeycomb dot pattern
  - Hover state: Amber-washed interior, brightened
  - Pressed/Active state: Inverted shadow (sunken), darker amber fill (like a capped cell)
  - No sharp edges — rounded slightly
- **Typography:** Simple, readable font in dark brown

### Fill Bars (Experience, Energy, Honey)

**Asset Collection:** xp_bar.png, energy_bar_fill.png, energy_bar_bg.png, honey_bar.png, etc.
- **Dimensions:** 160×16 px (adjustable width)
- **Design:**
  - Row of honeycomb cells set into a wooden rail frame
  - Cells fill left-to-right with warm amber honey color
  - Divider lines every cell-width (visible grid)
  - Background cells: Empty-comb cream color
  - Filled cells: Amber gold with subtle highlight
  - No gradients — discrete cell fills only
- **Animation:** On level-up or full fill, brief pulse animation flashes each cell in sequence left-to-right (AMBER_LIGHT pulse, 3 frames)

### Toast Notifications

**Asset:** notification_bg.png
- **Dimensions:** 240×64 px (variable height)
- **Design:**
  - Sticky note pinned to a frame
  - Warm cream parchment body
  - Amber top "tape" strip (looks like it's pinning the note)
  - Torn left edge suggesting note is peeled from frame
  - Stack vertically from top-right corner of screen
- **Text:** Dark brown on cream background

### Dialogue Boxes & Speech Bubbles

**Asset:** dialogue_panel.png, speech_bubble.png
- **Dialogue Panel:**
  - Thick wooden outer frame border (4 px multi-tone)
  - Solid wood top header bar with grain lines
  - Warm wax-paper interior with faint ruled lines
  - Portrait area inset on left with separate wooden sub-frame
  - Character name in header
  - Dialogue text below
- **Speech Bubble:**
  - Wooden-framed box with triangular wooden tail pointing to speaker
  - Interior: Wax-paper white with very faint honeycomb overlay
  - Thin header bar at top
  - For brief character quips during exploration
  - No character portrait in bubble (just text)

---

## SECTION 9: FRAME INSPECTION UI (CLOSE-UP SCENE)

### Hive Frame Rendering

**Scene Perspective:** Front-facing portrait view (NOT top-down)

**Asset:** hive_frame_ui.png
- **Dimensions:** ~320×192 px (approximately)
- **Cell Grid Detail:**
  - Individual hexagonal cells visible (3–4 px per cell)
  - Deep body frames: 70×50 = 3,500 cells per side
  - Medium super frames: 70×35 = 2,450 cells per side
- **Cell States (color-coded):**
  - Empty comb: Pale yellow (#F5E6B3 range)
  - Capped honey: Golden amber (#C8860A range)
  - Capped brood: Tan/cappuccino (#A89068 range)
  - Larva: White/cream with small details
  - Eggs: Tiny white dots in cell centers
  - Pollen: Bright but muted gold/orange (#D4A76A range)
  - Uncapped nectar: Pale amber/honey tone
- **Visual Polish:**
  - Honeycomb cells have subtle depth (slight shading)
  - Bees not anthropomorphized, but have character
  - Readable and distinct even when zoomed
  - Uses warm amber/tan palette (matches overworld)

### Frame Border & Inspection UI Frame

**Asset:** frame_inspection_border.png
- **Design:** Wooden frame border around inspection view
- **Header:** Shows box navigation info ("Box: Brood 1 of 2")
- **Color Coding:**
  - Brood box frames: Warm brown border
  - Super frames: Golden/amber border
- **Navigation Indicators:**
  - W/S key labels (navigate between boxes)
  - A/D key labels (navigate between frames)
  - F key label (flip frame side)

---

## SECTION 10: MINIGAME ASSETS

### Queen Finder Minigame

**Type:** Visual search interactive scene

**Component Assets:**
- Frame background with animated bee sprites
- Queen bee sprite (distinct from worker bees)
- Worker bee sprites (multiple animation frames)
- Interaction feedback (click indicator, successful find animation)
- Full specification in: `research/queenFinder/_Queen_Finder_GDD.html`

**Visual Requirements:**
- Bees animated walking on frame surface
- Queen must be visually distinct without being cartoonish
- Worker bees: 8×8 px or 16×16 px
- Animated idle/walk cycles
- Clear hitbox feedback on click

### Uncapping Swipe Minigame

**Type:** Precision interaction swipe

**Component Assets:**
- Frame surface with cappings ready to uncap
- Uncapping knife tool cursor/indicator
- Honey progress feedback (cells converting to uncapped)
- Tool progression visual states

**Visual Requirements:**
- Shows capped cells that need uncapping
- Visual feedback as cells are uncapped
- Tool wear/damage states as game progresses
- Clear completion feedback

### Grafting Minigame

**Type:** Precision magnified interaction

**Component Assets:**
- Magnified larva/cell view
- Grafting tool cursor
- Larva sprites (tiny, detailed at magnification)
- Acceptance rate visual feedback
- Success/failure animation

**Visual Requirements:**
- Shows individual larvae in cells
- Tool interaction feedback
- Graft acceptance indicator
- Clean, readable magnified view

### Mating Minigame

**Type:** Environmental management

**Component Assets:**
- Mating nuc visual
- Virgin queen sprite
- Drone flight visual elements
- Weather condition indicators
- Mating flight success animation

**Visual Requirements:**
- Shows mating nuc condition
- Weather visual feedback (clear sky, clouds, rain)
- Successful mating celebration animation

### Scraping Minigame (Uncapping)

**Type:** Click-and-drag interaction

**Component Assets:**
- Frame with capped cells
- Scraper tool cursor/feedback
- De-capped cell state progression
- Tool damage/wear states

**Visual Requirements:**
- Shows cells being uncapped by drag action
- Clear visual change as cells are scraped
- Both frame sides interactive
- Completion feedback per frame

### Extractor Minigame (Tap-E Gauge)

**Type:** Speed/timing gauge

**Component Assets:**
- Honey extractor machine sprite
- Rpm/speed gauge (visual)
- Honey output visual feedback
- Success/failure states

**Visual Requirements:**
- Shows extractor spinning
- Gauge animation (needle/fill bar moving)
- Honey draining visual
- Clear completion state

### Bottling Minigame (Jar Filling)

**Type:** Gate-control interaction

**Component Assets:**
- Honey tap/spout sprite
- Jars filling animation
- Overflow feedback
- Completed jar stack visual

**Visual Requirements:**
- Shows honey flowing into jar
- Jar fill level visual
- Stacking multiple jars
- Clear completion when jar full

---

## SECTION 11: ENVIRONMENTAL & SEASONAL EFFECTS

### Seasonal Tint Layers

Applied as screen-level overlays on base sprites (one sprite sheet serves all seasons).

**Spring Tint:** Soft green + cream overlay
**Summer Tint:** Deep green + amber overlay
**Fall Tint:** Burnt orange + burgundy overlay
**Winter Tint:** Muted blue-gray + warm interior light overlay

**Transition Animation:** Animated fade between tints over ~2–3 seconds when advancing seasons

### Particle Effects

**Bee Swarm Particles:**
- Individual bee sprites (8×8 px) emitted at hive entrance
- Density driven by active forager population
- Flow patterns (incoming/outgoing from hive)
- Used for visual feedback during active periods

**Smoke Particles:**
- Thin curling smoke wisps
- Used in smoker visual effect and title logo
- Warm gray/white color family
- Drifting animation

**Pollen/Dust Effects:**
- Fine particles during flower interactions
- Subtle, not distracting
- Warm golden tone

**Water Particles:**
- Splashing when crossing water
- Subtle, not cartoony

### Weather Visual Effects

**Sunlight Rays:**
- Volumetric god rays effect (subtle, optional)
- Used during peak summer days

**Rain/Snow:**
- Rain falling animation layer
- Snow accumulation (visual only, no gameplay impact)
- Winter season appearance

**Fog/Mist:**
- Morning/evening mist overlay
- Subtle depth effect

---

## SECTION 12: LOCATION-SPECIFIC ASSET COLLECTIONS

### Home Property Assets

**Landscape Features:**
- House exterior (see Buildings section)
- Honey house/extraction facility (see Buildings section)
- Apiary shed (see Buildings section)
- Hive stands with modular hive stacks (see Hive section)
- Fence sections (Darlene's property line)
- Wildflower patches (seasonal overlays)
- Trees (mature apple, oak, decorative)
- Walkways/paths (dirt, maintained)
- Mailbox (small decorative prop)
- Wood storage/lumber pile (visual prop)
- Water trough or rain barrel (visual prop)
- Compost bin (visual prop)

**Interior Assets (House):**
- Kitchen counter and appliances
- Living area furniture (basic, modest)
- Bedroom furniture (if accessible)
- Door frames
- Windows with curtains
- Fireplace/hearth (winter smoke effect)
- Storage shelves
- Craft/work table

**Extraction Facility Interior (Honey House):**
- Scraping station with pallet
- Honey extractor machine
- Bottling table with jar storage
- Tool racks/wall storage
- Honey buckets and containers
- Shelving for supplies
- Workbench area

### Cedar Bend Town Assets

**Town Square/Market Area:**
- Market stall structures (Frank's honey stall)
- Other vendor stalls (food, supplies)
- Town bulletin board
- Gazebo or market shelter
- Decorative planters
- Street lamp posts
- Benches/seating

**Town Buildings:** (See Buildings section)
- Feed & Supply store
- Diner (Crossroads)
- Grange Hall
- Hardware store
- General building interiors
- Porch elements

**Town Surroundings:**
- Sidewalks/streets
- Grassy areas
- Decorative trees
- Fence sections
- Road markers

### County Road & Highway Areas

**Road Features:**
- Paved/gravel road surface
- Road signs
- Fence posts along route
- Mile markers
- Mailboxes (farmstead entrances)
- Ditch areas with grass/water

**Scenic Elements:**
- Distant hills
- Field views
- Tree stands
- Sky/cloud variations
- Horizon parallax layers

### Timber & Woodlot

**Forest Assets:**
- Dense tree canopy
- Tree trunks (various sizes)
- Fallen logs
- Brush/undergrowth
- Rocky outcrops
- Stream/water features
- Clearing areas
- Light shafts through canopy

**Resource Elements:**
- Cut wood piles
- Logging area (if active)
- Forest floor detail

### Harmon Farm

**Farm Assets:**
- Farm buildings (barn, grain storage)
- Farm equipment (tractors, plows - visual only)
- Crop fields (corn, soybean visual variants)
- Fence posts and farm fencing
- Farm gates
- Drainage ditches
- Farm vehicles (parked)

**Seasonal Variants:**
- Spring: Tilled soil, early growth
- Summer: Tall crops, green
- Fall: Golden/brown crops, harvest
- Winter: Bare fields, brown

### River Bottom

**River Assets:**
- River/stream water feature
- Rocks and boulders in water
- Bank features (reeds, grass)
- Trees along riverbank
- Fallen branches/natural debris
- Wildlife habitats (visual prop)
- Flood plain areas

**Seasonal Features:**
- Water level variations
- Vegetation density changes

---

## SECTION 13: CHARACTER ANIMATION STATES

### General Animation Framework

**All characters use 8-directional movement with the following states:**

| State | Frames | Purpose |
|-------|--------|---------|
| Idle | 1 per direction | Standing still, default |
| Walk | 8 per direction | Normal movement speed |
| Run | 8 per direction | Fast movement speed |

**Optional Advanced States** (if time allows):
- Interact (single frame per direction) - reaching/bending
- Carry (8 per direction) - carrying items with different posture
- Emotional reactions (4–8 frames) - happiness, surprise, etc.

### Player-Specific Animations

**Holding Items:**
- Different pose when holding smoker vs. honey jar
- Adjusted arm/hand position
- Visible item in hand sprite

**Fatigue State:**
- Hunched posture when low energy
- Slower walk cycle (visual only, not speed change)
- More frequent "tired" idle animations

---

## SECTION 14: TITLE SCREEN & MAIN MENU

### Title Screen Assets

**Background:**
- Pastoral Iowa homestead scene (top-down view)
- Hives, house, honey house visible
- Dawn/sunset lighting
- Peaceful mood
- Logo placement (see Section 1)

**Menu Buttons:**
- New Game
- Load Game
- Settings
- Quit
- All use Langstroth Frame UI theme

**Music Visualizer** (optional):
- Subtle animated bee flight patterns
- Particle system representing game content

### Pause Menu Assets

**Background:**
- Blurred/dimmed version of current scene
- Langstroth frame panel overlay

**Menu Items:**
- Resume Game
- Save Game
- Settings
- Main Menu
- Quit to Desktop

---

## SECTION 15: NPC DIALOGUE & INTERACTION VISUALS

### Dialogue Portrait Frames

**Asset:** npc_portrait_frame.png
- **Dimensions:** 80×96 px (character portrait area)
- **Design:**
  - Separate wooden sub-frame within dialogue panel
  - Dark border, interior background for NPC sprite
  - Portrait inset on left side of dialogue panel

**Character Portraits (Close-up Busts):**
Each NPC should have a portrait sprite (80×96 px):
- Uncle Bob portrait
- Darlene portrait
- Frank portrait
- Dr. Ellen portrait
- Walt portrait
- Kacey portrait
- Silas portrait

These can be simplified character artwork (head/shoulders only, not full sprite).

### Speech Bubbles

**Asset:** speech_bubble_variants.png
- **Sizes:** 160×64 px (small), 240×96 px (medium), 320×128 px (large)
- **Design:** Wooden-framed box with tail pointing to speaker
- **Tail Positions:** Pointing left, right, up, down variants

---

## SECTION 16: QUEST & PROGRESSION VISUAL INDICATORS

### Quest Markers

**Assets:**
- Quest available marker (golden bee icon)
- Quest in progress marker (pulsing icon)
- Quest complete marker (checkmark)
- Objective marker (golden star)

**Dimensions:** 16×16 px icons

### Knowledge Log Icons

Small 16×16 px icons for each knowledge entry category:
- Plant icons (dandelion, clover, goldenrod, etc.)
- Disease/pest icons (varroa, AFB, etc.)
- Technique icons (requeening, swarm management, etc.)
- Equipment icons (smoker, hive tool, etc.)

### Level-Up Visual

**Asset:** level_up_popup.png
- **Dimensions:** 160×80 px
- **Design:** Celebration animation (rising golden sparkles, text pulse)
- **Color:** Golden amber tones on Langstroth frame background

---

## SECTION 17: MISCELLANEOUS PROPS & DETAILS

### Crafting Output Items

Visual representations of all crafted goods:
- Honey jars (multiple fill levels)
- Propolis tincture (small bottle)
- Beeswax candles (stacked)
- Pollen patties (square blocks)
- Sugar syrup bottles (containers)

**Dimensions:** 32×32 px (inventory view)

### Container & Storage Sprites

- Honey buckets (various sizes)
- Syrup feeders (multiple types)
- Queen cages (small box)
- Package bee boxes (with breathing holes)
- Storage chest/cabinet

**Dimensions:** 32×32 px to 64×64 px depending on context

### Tool & Equipment Props

- Hive tool (metal pry bar)
- Smoker (detailed if visible on scene)
- Refractometer (small measuring device)
- Queen marker supplies
- Gloves (if worn visibly)
- Veil/hat (if worn visibly)

---

## SECTION 18: COLOR PALETTE REFERENCE

### Core Palette (Muted, Earthy)

**Grass/Plant Tones:**
- Muted Olive Green: #5A6B47
- Highlight Green: #7A8B67
- Dark Forest: #3A4B27

**Dirt/Path Tones:**
- Sandy Tan: #A89068
- Warm Brown: #8B6F47
- Dark Brown: #5C4A2F

**Stone/Building Tones:**
- Cool Gray Stone: #7B8A99
- Warm Plaster: #D9CCC3
- Dark Slate: #3C3C3C (no pure black)

**Honey/Amber Tones:**
- Warm Amber Gold: #C8860A
- Light Honey: #E8B85A
- Dark Honey: #A66F0E

**Wood Tones:**
- Light Frame Wood: #D4A373
- Medium Frame Wood: #A89068
- Dark Frame Wood: #6B5D47

**Water Tones:**
- Muted Teal: #5B8C9C
- Shallow Water: #7BA9B8

**Off-White/Cream (for UI, beekeeper suit):**
- Off-White: #F5EFE5
- Wax-Paper Cream: #FBF7ED
- Light Tan: #EDD9B5

---

## SECTION 19: ASSET IMPLEMENTATION CHECKLIST

For the pixel artist to track completion:

### Phase 1: Core Assets (Critical Path)
- [ ] Player beekeeper spritesheet (120×120, 8-dir, 3 animations)
- [ ] Uncle Bob NPC spritesheet
- [ ] House exterior building sprite
- [ ] Honey house building sprite
- [ ] Modular hive sprites (base, deep, super, excluder, lid)
- [ ] Hive stand sprites (×5 variants)
- [ ] Game logo (1200×1200)
- [ ] Hotbar item icons (all 25 items, 32×32)
- [ ] Langstroth UI panels, buttons, bars
- [ ] Hive frame inspection view (320×192)

### Phase 2: Secondary NPCs & Buildings
- [ ] Darlene NPC spritesheet
- [ ] Frank NPC spritesheet
- [ ] Dr. Ellen NPC spritesheet
- [ ] Feed & Supply building
- [ ] Diner building
- [ ] Apiary shed
- [ ] Market stall
- [ ] NPC portrait frames (×7 characters)

### Phase 3: Environmental & Props
- [ ] Tree canopy variants (apple, oak, pine, shrubs)
- [ ] Wildflower overlays (dandelion, clover, goldenrod)
- [ ] Fence sections
- [ ] Water features
- [ ] Particle effects (bees, smoke, pollen)
- [ ] Interior furniture (house, honey house)
- [ ] Miscellaneous props (mailbox, storage, tools)

### Phase 4: Minigame & Polish Assets
- [ ] Queen Finder bee sprites and animations
- [ ] Uncapping/scraping tool and effects
- [ ] Extractor minigame visuals
- [ ] Bottling minigame visuals
- [ ] Seasonal tint overlays
- [ ] Weather effects (rain, snow, fog)
- [ ] Title screen background
- [ ] Quest/progression icons

### Phase 5: Additional NPCs & Locations
- [ ] Walt & Kacey Harmon sprites
- [ ] Silas Crenshaw sprite
- [ ] Additional town buildings
- [ ] Forest/timber assets
- [ ] Farm assets and variants
- [ ] River/water location assets
- [ ] Advanced animations (carry states, emotional reactions)

---

## SECTION 20: REFERENCE MATERIALS & DOCUMENTATION

**Primary Style Reference:**
- Cainos Pixel Art Top Down – Village (v1.0.7) - Foundation asset pack
- Stardew Valley - World scale, character charm, perspective
- Early Harvest Moon GBA - Palette mood

**Leonardo AI Generation Notes:**
- All custom assets generated using Leonardo AI (Lucid Origin model)
- Master prompt block in CLAUDE.md
- Use "Smoke and Honey" collection for consistency
- Reference GDD Section 10.1.3 for detailed prompt guidelines

**Asset Storage Locations:**
- Game sprites: `assets/sprites/` (paid/ and custom/ subdirs)
- UI elements: `assets/sprites/ui/`
- Research/iterations: `research/art/`
- Logo files: `research/art/logos/`

**Quality Assurance:**
- After every asset created: compare against Cainos style
- "Does it look like it belongs in Cainos Village? If yes, ship it. If no, regenerate."
- No pure black (#000000) in any outline
- 2–3 shade depth verification
- Shadow as separate layer verification

---

## FINAL NOTES

This inventory represents the complete visual scope of Smoke & Honey as of March 31, 2026. Not all assets need to be created simultaneously—prioritize by the phase checklist above. The goal is a cohesive, warm, painterly pixel art aesthetic that feels like rural Iowa as seen through warm afternoon sunlight, never bright or oversaturated.

Every asset created should feel like it was made by the same hand, using the same palette, with the same care for detail. The Cainos Village reference is the visual north star. When in doubt, that style is correct.

For questions or clarifications, refer to:
1. Smoke_and_Honey_GDD.html (Section 10: Art Direction & Audio)
2. CLAUDE.md (Absolute Rules & Art Asset Creation)
3. Leonardo AI workflow documentation

**Document prepared for:** Pixel artist development
**Ready for:** Asset creation & iteration
