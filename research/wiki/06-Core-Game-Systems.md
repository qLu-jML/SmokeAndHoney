[< Time & Calendar System](05-Time-and-Calendar-System) | [Home](Home) | [Progression & Unlocks >](07-Progression-and-Unlocks)

---

# Core Game Systems


### 6.0 Hotbar & Active Item System

The player's 10-item inventory is always visible as a horizontal hotbar at the bottom of the screen, just above the resource bar. There is no separate bag screen — what the player is carrying is always in view. The active (selected) slot is highlighted with an amber border, and the item's full name appears in a small label floating above it.

**Controls:** Mouse wheel scrolls through slots. Number keys 1–9 jump directly to slots 1–9. The E key uses the active item in context.

**Context-first interaction:** When the player presses E, the game first checks for nearby interactables in priority order — merchant, hive, Uncle Bob NPC, flowers — before falling back to the active item's placement action. This means being near a complete hive always opens inspection regardless of what is in the active slot.

**Inventory size:** 10 slots. Each slot holds one item type; stack sizes vary by item. This constraint encourages deliberate loadout planning before heading out to the apiary.

#### Active Item Actions


| Active Item | E Key Action (no nearby interactable) |
| --- | --- |
| Hive Stand | Place a bare hive stand at the targeted grid tile (green placement box shown). Starts the hive build sequence. |
| Deep Body | No empty-ground placement. Used automatically when near a STAND_PLACED hive. |
| Frames | No empty-ground placement. Used automatically when near a hive in BODY_ADDED or FRAMES_PARTIAL state — fills the box to capacity or exhausts inventory. |
| Hive Lid | No empty-ground placement. Completes the hive when used near a body (with or without frames), starting the colony simulation. |
| Complete Hive (legacy) | Place a fully assembled, immediately operational hive (stand + 10 frames + lid). Green placement box shown. |
| Seeds | Plant on tilled dirt (requires PLANT mode active via F key). |


### 6.1 Hive Inspection System

The weekly hive inspection is the primary gameplay interaction. It is where the player gathers data, makes observations, and decides on interventions.

Inspection Flow


| Step 1: Approach | Player selects a hive and chooses to inspect. The game checks weather, time of day, and player skill. A warning is shown if conditions are poor. |
| --- | --- |
| Step 2: Smoke | Player applies smoke. Amount affects how calm the bees are. Over-smoking or under-smoking affects inspection quality and bee stress. |
| Step 3: Open Hive | Player removes the cover and navigates a frame-by-frame view of the hive interior. |
| Step 4: Observe | Each frame shows visual evidence: brood pattern, honey/pollen stores, bees, queen sighting probability. Player can annotate. |
| Step 5: Note & Act | After inspection, the player logs observations and can take immediate actions (add a frame, mark queen, apply treatment). |
| Step 6: Close | Hive is closed. A brief summary shows what was found. New Knowledge Log entries may be added. |


Inspection Quality Factors


| Weather | Sunny, calm days: best. Overcast: acceptable. Rainy, cold, windy: poor. Poor weather = fewer observable frames. |
| --- | --- |
| Time of Day | Mid-morning to early afternoon is optimal (most foragers are out). Evening inspections risk stinging. |
| Player Experience | Higher experience level increases queen sighting probability and disease detection accuracy. |
| Hive Temperament | Defensive colonies produce chaotic inspections. More smoke and experience required. |
| Frequency | Inspecting too often (more than once a week) adds stress to the colony and risks damaging frames. |


#### Sting Probability Model

Each inspection step (opening the hive, pulling frames, observing) carries a chance of being stung. The base sting probability per step varies with hive temperament and conditions. Protective equipment and smoke multiplicatively reduce this chance.


| Base sting chance per step | 10–25% depending on hive temperament (calm colonies: 10%, defensive colonies: 25%). |
| --- | --- |
| Bee suit modifier | ×0.20 (80% reduction). Wearing a full bee suit is the primary defense against stings. |
| Smoker modifier | ×0.85 (15% reduction). Smoking the hive before inspection calms the bees, reducing sting probability. Stacks multiplicatively with the bee suit. |
| Combined (suit + smoke) | Base × 0.20 × 0.85 = 95% total reduction. Example: a defensive colony (25% base) with suit and smoke = 25% × 0.20 × 0.85 ≈ 4.25% per step. |
| Time of day modifier | Evening inspections (after 15:00): base chance ×1.25. Foragers returning to the hive increase defensive behavior. |
| Energy penalty per sting | 5–8 energy lost per sting event. See §5.4 Bee Stings — Energy Loss Hazard. |


#### Queen Sighting — Visual Search (Phase 2)

**Phase 2 (implemented):** The probability-based sighting model has been replaced by an interactive visual search minigame. When the player inspects a hive, animated bee sprites walk on each frame. The queen must be found by clicking on her among the workers. See the *Queen Finder Sub-GDD* (`research/queenFinder/_Queen_Finder_GDD.html`) for the full specification.


| Queen visibility | 80% chance, rolled once at inspection start. If pass: queen entity + attendants spawned on her assigned frame. If fail: no queen visible this inspection. |
| --- | --- |
| Difficulty rank | Rolled once per inspection: Easy (33%), Medium (33%), Hard (34%). Controls bee density (0.33/0.67/1.0 multiplier), spacing (28/17/12 px), and clustering (0.28/0.20/0.16 Gaussian spread). |
| XP reward | Scales with difficulty: Easy +10 XP, Medium +15 XP, Hard +25 XP. Awarded when player clicks the queen entity. |
| Visual tells | Queen has longer abdomen (~45% elongated), shorter wings (expose abdomen), fewer fuzz dots (shinier), wider leg splay. Breed color affects difficulty (Italian easiest, Russian hardest). |
| Attendant circle | Queen is surrounded by orbiting attendant bees (count scales with grade: S=11, B=7, F=0). Attendants scale inversely with difficulty (Easy x1.5, Hard x0.5). |
| Wrong click penalty | None. Brief red flash on clicked worker. No click limit. Player can keep trying. |
| Implementation | BeeOverlay.gdmanages bee entities, movement, rendering, and click detection.InspectionOverlay.gdintegrates the overlay and handles XP/notification on queen found. |


**Phase 1 (legacy):** The original probability-based model (60% base + 1%/level, capped 80%) remains in InspectionOverlay.gd as fallback code but is no longer called during normal gameplay.

#### 6.1.1 Inspection Knowledge Tiers

The information available during hive inspection is gated by the player's experience level. This models how a real beekeeper's observational skills develop over time — a hobbyist sees wax and bees, while a master beekeeper reads the frame like a diagnostic report. Developer Mode overrides to full Level 5 display for testing.


| Player Level | Title | Tooltip (Mouseover) | Stats Sidebar | Design Rationale |
| --- | --- | --- | --- | --- |
| 1 | Hobbyist | Hidden. No tooltip. | Hidden. No sidebar. | Pure visual observation. The player must learn to read the honeycomb by sight alone — distinguishing brood patterns from honey stores, spotting eggs, noticing gaps. This is the "I just got my first hive" experience. |
| 2 | Apprentice | Cell state name only (e.g. "Egg", "Capped brood", "Nectar"). No coordinates, no age. | Hidden. No sidebar. | The beekeeper starts recognizing individual cell contents. Hovering confirms what the eye suspects. This bridges "what am I looking at?" to "oh, THAT'S what an egg looks like." The player still builds a mental model without numbers. |
| 3 | Beekeeper | Cell state name (same as Level 2). | Qualitative descriptions: "Solid brood pattern", "Heavy honey stores", "Healthy", "Queen laying well". Natural language that mirrors how a working beekeeper talks about frames. Mite/varroa data is not shown in normal play — handled by a dedicated future mite detection system. | The trained eye. A beekeeper with a few seasons' experience doesn't count cells — they glance at a frame and read the story. The sidebar confirms and articulates what the visual already shows. No exact numbers. |
| 4 | Journeyman | Cell state name only (e.g. "Capped brood"). Same as Tiers 2–3. Cell age has been removed from normal play tooltips. | Approximate counts with ranges and qualitative assessments: "Brood: ~1,200 (good)", "Honey: ~30%", "HP: 70–80%", "Strong genetics". Numbers are rounded to human-friendly estimates. Mite data is not shown — handled by a dedicated future mite detection system. | The experienced beekeeper's eye. Corresponds to the "Beekeeper's Eye" knowledge unlock (§7.3). Can estimate quantities at a glance and makes management decisions from observation. |
| 5 | Master Beekeeper | Cell state name only (same as Tiers 2–4). Coordinates and age are dev mode only — shown when G key is active, not during normal Tier 5 play. | Dynamic percentages per frame side viewed: Eggs X.X%, Larvae X.X%, Capped X.X%, Honey X.X% — update progressively as frames are flipped. Population shown qualitatively: Nurses (Good/OK/Low/None), Workers (Strong/OK/Low/Weak), Drones (Many/OK/Few/None). Queen ranking: "Q: A/Ita" format. HP as color-coded percentage. Varroa raw count (color-coded). Exact cell counts and full mite data are dev mode only. | The master beekeeper's eye — reads the frame as a dynamic picture, not a spreadsheet. Percentages update in real time as you examine frame sides, rewarding thoroughness. Full exact data is reserved for dev mode so the normal play experience remains interpretive rather than purely numerical. |


**Developer Mode Override:** When Developer Mode is active (G key), the inspection overlay always displays at Level 5 regardless of the player's actual experience level. A clickable level switcher widget appears in the HUD allowing the developer to change the player level on the fly to test each tier.

**Implementation:** `InspectionOverlay.gd` resolves the effective tier in `open()` by checking `GameData.dev_labels_visible` (dev mode flag) and `GameData.player_level`. Tier-specific rendering is handled by three builder functions: `_build_qualitative_rows()` (tier 3), `_build_approximate_rows()` (tier 4), and `_build_exact_rows()` (tier 5). Tooltip content and visibility are gated per tier in `_refresh_tooltip()`.

**Progressive Accumulation:** Stats build incrementally as the player views frame sides. Each side viewed calls `_record_current_side()`, which adds that side's cell counts to a running total for the current inspection session. The stat percentages and qualitative assessments use cells-seen-so-far as the denominator, giving a partial picture early in the inspection and a complete picture after all 20 sides (10 frames × 2 sides) have been examined. A "Seen X/20" indicator in the sidebar shows how many sides have been viewed. Each new inspection resets the counter to zero. Dev mode bypasses accumulation entirely via `_get_full_hive_counts()`, showing full accurate stats for the entire hive immediately upon opening.

### 6.2 Forage & Flower System

Forage is the foundation of honey production. The quality and diversity of forage available to each apiary determines honey yield, flavor profile, and bee health.

Forage Sources


| Plant Type | Characteristics | Game Unlock |
| --- | --- | --- |
| Wildflowers (general) | Fast-growing, bloom spring through fall, produce mild honey. | Available from start |
| Clover (white/red) | High nectar producer, season-long bloom, classic honey profile. | Available from start |
| Wild Bergamot | Iowa prairie native, excellent nectar, summer bloom (Monarda fistulosa). | Available from start |
| Sunflowers | Summer bloomer, high pollen producer, supports worker health. | Year 1 purchase |
| Purple Coneflower | Iowa prairie native, high pollen, moderate nectar, long bloom (Echinacea purpurea). | Year 1 purchase |
| Fruit Trees (apple, cherry, plum) | Early spring bloom, medium honey, long maturation time. | Year 1 plant; Year 3 bloom |
| Linden / Basswood | Prime summer flow, produces premium honey, large mature tree. | Year 1 plant; Year 4 bloom |
| Willow | Very early spring pollen, critical for first brood cycle of the year. | Year 1 plant; Year 3 contribution |
| Goldenrod | Late summer / fall, strong secondary flow, supports winter prep stores. | Year 2 unlock |


Forage Radius & Apiary Location

Each apiary has a forage radius — the area from which its bees can practically collect nectar and pollen. Overlapping apiaries compete for the same forage.


| Forage Radius | Approximately 1–2 miles in-game. Represented visually as an overlay when placing a new apiary. |
| --- | --- |
| Forage Score | Calculated from the diversity and quantity of blooming plants within the radius at any given time. |
| Competition | Two apiaries in overlapping zones share the forage pool. Overcrowding an area reduces production for all hives. |
| Surrounding Land | Farmland with monocrops (corn, soybeans) is low-value forage. Working with the neighboring farmer NPC can influence their planting choices. |
| Water Source | Bees need accessible water. Apiaries without a nearby water source suffer small but persistent health penalties. |


### 6.3 Bee Acquisition System

Players acquire new bees in three ways, each with distinct trade-offs in cost, timing, and initial quality.


| Method | Description | Trade-offs |
| --- | --- | --- |
| Package Bees | 3 lb box of mixed bees with a caged, mated queen. Ordered in winter/early spring, delivered in spring. | Lowest cost. Slowest start (bees must build from nothing). Queen may take 1–2 weeks to be accepted. Grade varies by supplier. |
| Nucleus Colony (Nuc) | 4–5 frame established colony with a laying queen, brood, and stores. Transferred directly into a hive body. | Higher cost. Faster establishment. Queen already laying. Best for beginners or replacing a lost hive. |
| Full Hive Purchase | An established colony on a full set of equipment, purchased from another beekeeper. | Highest cost. Immediate full production capability. Risk of purchasing with unknown disease or pest load — requires thorough inspection on arrival. |
| Swarm Catch | A wild swarm is captured and installed in a prepared hive. | Free bees. Uncertain genetics and health. High reward if the swarm is large and healthy. Requires a swarm trap or fast response to a swarm call. |
| Split (from own hives) | Dividing an existing strong colony to create a new one. | No cost in money. Costs colony strength temporarily. Requires raising or purchasing a new queen for one half. |


*Design Note: Supplier reputation matters. Cheaper suppliers deliver more variable queen grades. Established suppliers cost more but reliably deliver A/B grade queens. This is a progression-relevant choice — early players may not be able to afford premium stock.*

#### Supplier Tiers — Price and Quality Reference

Three suppliers are available in-game. Quality affects queen grade probabilities. Supplier unlock is progression-gated.


| Supplier | Package Price | Nuc Price | Queen Grade Distribution | Unlock |
| --- | --- | --- | --- | --- |
| River Valley Bee Supply (mail order) | $155 | $195 | D 10% / C 35% / B 45% / A 10% / S 0%. 5% chance queen DOA or not accepted. | Year 1 (available from start) |
| Cedar Bend Feed & Supply (local) | $185 | $245 | D 0% / C 10% / B 50% / A 35% / S 5% | Year 1 (Cedar Bend unlocked) |
| Hartley's Apiary (specialty breeder) | $215 | $285 | C 0% / B 15% / A 55% / S 30%. Also sells mated queens individually at $50 each. | Level 2 + Darlene friendship (she provides the introduction) |


*Design Note: The cheapest option isn't always a mistake — a budget B-grade Italian queen in a new beekeepers's first hive is perfectly workable. But a D-grade queen arriving in a package the player paid $155 for is a hard lesson. The lesson is real: cheaper suppliers exist because they don't cull as aggressively. Experienced beekeepers pay more to remove the variance.*

#### 6.3.1 Colony Installation Mechanic (Implemented)

Hives placed in the world start structurally complete but biologically empty. The player must install bees to start the simulation. This creates a deliberate two-phase setup: build the hive, then populate it.


| Item | ITEM_PACKAGE_BEES |
| --- | --- |
| Flow | Player selects Package Bees from hotbar, walks to empty complete hive, presses [E] to "[E] Install Colony". One Package Bees consumed. colony_installed flag set to true. Simulation begins ticking. |
| Empty Hive Prompt | Shows "Needs Package Bees" when wrong item held, "[E] Install Colony" when Package Bees selected. |
| Colony Installed Prompt | Shows "Equip Hive Tool" when wrong item held, "[E] Inspect Hive" when Hive Tool selected. |


#### 6.3.2 Package Bee Colony Establishment (Implemented)

Package colonies differ fundamentally from nucleus colonies. They start from scratch and require time to establish.


| Parameter | Package Colony | Nuc Colony |
| --- | --- | --- |
| Starting frames | All 10 frames empty foundation | Center 5 drawn with brood, outer 5 foundation |
| Starting bees | ~8,000 loose bees | ~10,200 bees |
| Starting stores | 2.0 lbs honey, 0.3 lbs pollen | 8.0 lbs honey, 1.5 lbs pollen |
| Starting mites | 15 (very low) | Standard load |
| Queen laying | 4-6 day random delay (cage release + acclimation) | Laying immediately |
| Inspection lockout | 7 days from installation (shows "Establishing... Xd" countdown) | No lockout (nuc hives inspectable immediately) |
| Comb drawing | Progressive, center-out, forage-dependent | 5 frames already drawn |


#### 6.3.3 Comb Drawing System (Implemented)

Bees must draw wax comb on foundation frames before the queen can lay or honey can be stored. The comb drawing system uses 3D ellipsoid geometry to simulate realistic build patterns.


| 3D Ellipsoid Model | Both comb drawing and queen laying use _cell_3d_dist() to compute normalized distance from the 3D center of the hive (frame 4.5, column 35, row 15). Configurable ellipsoid radii: RZ=5 frames, RX=38 cols, RY=42 rows. Middle frames fill before outer frames; center of each frame before edges. |
| --- | --- |
| Forage-Dependent Rate | Comb drawing rate scales with nectar availability from FlowerLifecycleManager. forage_mult ranges from 0.05 (dearth/F rank) to 1.0 (full flow/S rank). Good months = ~800-1,200 cells/day; poor months = ~50-200 cells/day. |
| Honey Cost | 0.0004 lbs honey consumed per cell drawn. Drawing stops below 1.0 lbs stores (was 3.0). Three-tier system: 1-3 lbs (slow startup), 3-8 lbs (moderate), 8+ lbs (full rate). |
| Walled-In Constraint | Queen can only lay eggs in drawn-empty cells where all 6 hex neighbours (pointy-top offset grid) are also drawn comb. Edge cells always return false. Prevents queen from laying on the frontier of drawn comb. |


#### 6.3.4 Hive Tool & Gloves — Equipment Items (Implemented)


| Hive Tool (ITEM_HIVE_TOOL) | Required for inspection. Player must have it selected in hotbar to see "[E] Inspect Hive" prompt. Without it, shows "Equip Hive Tool". |
| --- | --- |
| Gloves (ITEM_GLOVES) | Required for hive management operations. When Gloves selected and [E] pressed near colonized hive, opens HiveManagementUI overlay with actions: Add Deep Body (max 2), Add Honey Super (max 10), Add Queen Excluder, Rotate Deeps. Each action consumes items from player inventory. |
| Box Rotation (R key) | With Hive Tool selected near a hive with 2+ deeps, press [R] to move bottom deep body to top of deep section. Real beekeeping technique to encourage brood expansion upward. |


#### 6.3.5 Storage Chest System (Implemented)


| Item | ITEM_CHEST — Placeable world object with 50-slot persistent storage. |
| --- | --- |
| Interaction | Press [E] near chest to open. Modal UI: 10x5 chest grid + player hotbar row. WASD navigation, [E]/[Shift+E] transfer items, [Q] to switch focus between chest and hotbar. |
| Starting Chest | Pre-placed in TestEnvironment at (200, 220). Auto-stocked with overflow starting items on first scene load. |


#### 6.3.6 Starting Inventory (Implemented)

Player starts with minimal inventory. Overflow items are auto-stocked into the pre-placed storage chest.


| Player Hotbar | 1 Hive Stand, 2 Deep Bodies, 4 Supers, 1 Package Bees, 1 Gloves, 1 Hive Tool |
| --- | --- |
| Storage Chest | 4 Hive Stands, 3 Deep Bodies, 50 Frames, 5 Lids, 5 Beehives (complete nuc hives), 5 Seeds, 4 Package Bees, 5 Queen Excluders, 1 Super, 3 Deep Boxes, 20 Jars |


#### 6.3.7 Hotbar Item Sprites (Implemented)

All 25 inventory items now display 32x32 pixel art sprites in hotbar slots (was 16x16 flat color fills). TextureRect icon layer in each slot with dark background. Color fallback for unmapped items. Includes: raw\_honey, pollen, seeds, frames, super\_box, beehive, hive\_stand, deep\_body, hive\_lid, treatment\_oxalic, treatment\_formic, syrup\_feeder, queen\_cage, deep\_box, queen\_excluder, full\_super, jar, honey\_bulk, fermented\_honey, chest, beeswax, hive\_tool, honey\_jar\_standard, package\_bees, sugar\_syrup, gloves.

### 6.4 Queen Management System

Queen management is among the most complex and rewarding skill areas in the game. Players who master it can dramatically improve colony performance.

Queen Events


| Laying Queen (Normal) | Active, laying well. No intervention required. |
| --- | --- |
| Aging Queen | Production beginning to decline. Player may preemptively requeen for better performance. |
| Failing Queen | Spotty pattern, reduced laying. Replacement strongly advised before colony declines too far. |
| Missing Queen | No eggs visible. Could be: recently swarmed, supersedure in progress, or queenless emergency. Requires follow-up inspection in 1 week. |
| Queen Cell Present | Emergency (worker-built from existing larva) or supersedure (built beside failing queen). Player must decide to allow or remove. |
| Virgin Queen | Newly hatched, not yet mated. Hive will be non-productive for 2–3 weeks while she mates and begins laying. |
| Drone Layer | A queen laying only unfertilized (drone) eggs. Colony will collapse. Requires immediate requeening or merging. |
| Laying Worker | In a queenless hive, workers begin laying unfertilized eggs. Very difficult to correct. Usually requires combining with a queenright colony. |


Requeening Process

Replacing a queen is a multi-step process that takes real in-game time.


| Step 1: Confirm Queenlessness | Inspect and verify no eggs or young larvae (under 3 days old). Wait 1 week if uncertain. |
| --- | --- |
| Step 2: Acquire New Queen | Purchase a mated queen (immediate, costs money and requires supply) or raise one from a queen cell (takes 2–3 weeks, requires larvae under 3 days old). |
| Step 3: Introduction | New queen is placed in a candy-plug introduction cage. Workers eat through the candy over 3–5 days, allowing gradual acceptance. |
| Step 4: Check Acceptance | Inspect after 7 days. If the queen is released and laying — success. If she has been killed — requeen attempt failed; repeat. |
| Acceptance Risk Factors | Older hive with deep pheromone memory of previous queen, introduction during a dearth, or colony stress all reduce acceptance probability. |


### 6.5 Swarm Management System

Swarming is the honeybee colony's natural reproductive process. For the beekeeper it represents both a threat (losing half the workforce) and an opportunity (free bees, apiary expansion).


| Swarm Triggers | Overcrowding (insufficient space), strong colony genetics (Carniolan in particular), warm spring weather, lack of ventilation. |
| --- | --- |
| Early Warning Signs | Queen cells on the bottom of frames, increased drone population, bees festooning in clusters outside the hive entrance (bearding). |
| Swarm Event | If unaddressed, a swarm will issue. The old queen leaves with 40–60% of the bees. A new queen emerges from a cell left behind. Honey production drops significantly. |
| Prevention | Add space (supers or another hive body), perform a split, clip the queen's wing (prevents flight, allows time to intervene), remove queen cells. |
| Swarm Catch | If the player has a swarm trap set in range, a caught swarm becomes a free hive install. Swarms can also arrive from wild colonies. |
| Post-Swarm Recovery | The remaining colony with a new virgin queen takes 3–5 weeks to return to full production while the new queen mates and begins laying. |


### 6.6 Harvest System

Honey harvest is the primary payoff moment of the game year. Every decision the player made — hive placement, inspection timing, mite treatment, forage management — converges into this one question: how much honey did we make, and how good is it? The harvest pipeline is physical, tactile, and educational. The player transports supers to the extraction facility, uncaps each frame by hand, spins them in an extractor, reads the moisture grade, and chooses how to bottle. Each step teaches real beekeeping while creating meaningful decisions.

**Core Design Tension:** Harvest too early = uncapped honey, high moisture, low grade. Harvest too late = bees consume stores, less to sell. Harvest too much = colony starves over winter. Harvest just right = Premium grade, maximum yield, healthy winter colony.

#### 6.6.1 Super & Box Management

Before harvest can occur, the player must expand their hive with honey supers — dedicated boxes placed above the brood area specifically for honey storage. This system governs how the hive grows physically and how the player manages that growth.

#### Langstroth Box Dimensions


| Component | Height | Weight (full) | Cell Grid (game) | Lbs per Full Frame |
| --- | --- | --- | --- | --- |
| Deep Body (brood) | 9⅝" | ~80–90 lbs | 70 × 50 = 3,500 cells/side | 5.0 lbs |
| Medium Super (honey) | 6⅝" | ~50–60 lbs | 70 × 35 = 2,450 cells/side | 3.5 lbs |


The game uses **medium supers** as the standard honey super. They hold a good amount of honey (~50 lbs full) without being backbreakingly heavy. The height ratio for overworld sprites is approximately 2:3 (super : deep).

#### Modular Overworld Hive Sprites

The overworld hive is rendered as a vertical stack of modular sprite components. As the player adds boxes, the hive visually grows taller.


| Sprite | Size (px) | Description |
| --- | --- | --- |
| hive_base.png | 24 × 6 | Bottom board + landing strip |
| hive_deep.png | 24 × 14 | Deep body. Darker wood tone. |
| hive_super.png | 24 × 10 | Medium honey super. Lighter wood tone. |
| hive_excluder.png | 24 × 2 | Queen excluder. Thin metal-grey strip. |
| hive_lid.png | 24 × 6 | Telescoping outer cover. Always on top. |


**Stacking examples:** 1 deep only = base+deep+lid (26px tall). 1 deep + 1 super = base+deep+excluder+super+lid (38px). 2 deeps + 2 supers = base+deep+deep+excluder+super+super+lid (62px).

#### Adding a Second Deep (Brood Expansion)


| When | Colony is thriving — brood box is 75%+ full of drawn comb and brood. The queen needs more laying room or she will get congestion signals and swarm. |
| --- | --- |
| Trigger | During inspection, if brood box fill > 75%, notification: "This colony is running out of room. Consider adding a second deep body for brood expansion." |
| Player Action | Select ITEM_DEEP_BOX from inventory, walk to hive, press [E] → "Add Second Deep Body" |
| Mechanic | New deep box added ON TOP of existing deep (boxes[1], is_super=false). Contains 10 empty foundation frames. Queen moves freely between both deeps. Bees draw comb upward naturally. |
| Risk | If colony is weak, adding space they cannot defend invites pests (small hive beetle, wax moths in empty comb). Player learns this through consequences. |


#### Queen Excluder


| What | A metal grid that worker bees can pass through but the larger queen cannot. Keeps the queen in brood boxes so supers contain ONLY honey (no brood). |
| --- | --- |
| Player Action | Select ITEM_QUEEN_EXCLUDER, walk to hive with ≥1 deep, press [E] → "Place Queen Excluder" |
| Without Excluder | Queen can lay in supers → brood in honey frames = contaminated honey and dead brood during extraction. Strong negative consequence teaches why excluders matter. |
| With Excluder | Queen confined to deeps. Supers are guaranteed honey-only. Small nectar throughput penalty (−5%) as workers are slightly reluctant to pass through the grid. |
| Data | hive.has_excluder: bool flag. Excluder sits between top-most deep body and first super. |


#### Adding Honey Supers


| When | Colony has filled brood boxes and nectar flow is strong. Usually early-to-mid summer (Wide-Clover / High-Sun). |
| --- | --- |
| Trigger | During inspection, if top deep honey stores > 80% full and it is a nectar flow month: "Nectar flow is strong and the bees are running out of storage space. Time to add a honey super!" |
| Player Action | Select ITEM_SUPER_BOX, walk to hive with excluder, press [E] → "Add Honey Super" |
| Without Excluder Warning | "No queen excluder detected. The queen may lay eggs in this super, contaminating the honey. Add excluder first?" [Add Anyway] [Cancel] |
| Super Frame Data | Same HiveFrame class with is_super_frame=true. Cell grid: 70×35 (2,450 cells/side). LBS_PER_FULL_SUPER_FRAME = 3.5. Max practical stack: 3–4 supers per hive. |


#### Simulation Changes for Multi-Box Hives


| Nectar Routing | Incoming nectar preferentially fills supers when brood box top fill > 80%. If no super space available, nectar fills brood box → triggers congestion → eventual swarm signal. |
| --- | --- |
| Queen Behavior (with excluder) | _queen_lay() only considers frames in boxes where is_super==false. Queen confined to deeps. |
| Queen Behavior (no excluder) | Queen can lay in any frame including supers. She prefers brood boxes but will move up if congested. |
| Comb Drawing in Supers | Same _draw_comb() logic but on medium frames (2,450 cells/side). Drawing rate is 60% of brood box rate — bees are reluctant to draw new foundation in supers. |


#### Inspection Overlay — Multi-Box Navigation


| W/S Keys | Navigate between boxes (W = up toward supers, S = down toward brood) |
| --- | --- |
| A/D Keys | Navigate between frames within current box (unchanged) |
| F Key | Flip frame side A/B (unchanged) |
| Box Indicator | Top of overlay shows "Box: Brood 1 of 2" or "Box: Super 1 of 2" |
| Color Coding | Brood box frames have warm brown border. Super frames have golden/amber border. |
| Super Frame Rendering | 70×35 grid rendered shorter than 70×50 deep frames, matching real proportions. |


#### New Items for Box Management


| Item | Price | Source | Notes |
| --- | --- | --- | --- |
| ITEM_DEEP_BOX (Deep Hive Body) | $25.00 | Feed & Supply | Includes 10 foundation frames |
| ITEM_SUPER_BOX (Honey Super) | $20.00 | Feed & Supply | Medium depth, 10 foundation frames |
| ITEM_QUEEN_EXCLUDER (Queen Excluder) | $8.00 | Feed & Supply | Metal grid, reusable |
| ITEM_FULL_SUPER (Full Honey Super) | — | From hive | Not purchasable. Temporary carry item. Player carries max 2 at once. Movement speed −15% per super. |


#### 6.6.2 Harvest Decision & Frame Marking

There is no auto-harvest button. The player inspects their hive, evaluates per-frame capping percentages, and makes a conscious decision about which frames to pull. Marked supers must then be physically transported to the extraction facility.


| When to Harvest | Frames should be at least 80% capped. Uncapped honey has high moisture content and will ferment. A refractometer (unlockable tool) confirms moisture below 18.5%. |
| --- | --- |
| Which Frames | Supers only — never pull frames from the brood box. Leaving adequate stores is critical for winter survival. |
| Minimum Winter Reserve | Temperate: 60–80 lbs of honey in brood boxes. Player receives escalating warnings if stores fall below threshold (see §6.6.7). |


#### Harvest Readiness Indicators (in InspectionOverlay)


| Capping % | Indicator | Label |
| --- | --- | --- |
| ≥80% | Green honeycomb icon | "Ready to harvest" |
| 60–79% | Yellow warning icon | "Needs more time" |
| <60% | Red warning icon | "Not ready — high fermentation risk" |


**Capping % formula:** `(S_CAPPED_HONEY + S_PREMIUM_HONEY) / (S_CAPPED_HONEY + S_PREMIUM_HONEY + S_CURING_HONEY + S_NECTAR)`. Only counts honey-related cells; ignores brood and empty cells.

#### Player Flow

1. Inspect hive with Hive Tool (existing system). 2. InspectionOverlay shows per-frame capping % in stats sidebar with readiness indicator. 3. Press [H] to mark individual frame for harvest, or [Shift+H] to mark entire super. 4. Fermentation warning if <80% capped: "This frame is only XX% capped. Uncapped honey has high moisture and may ferment. Harvest anyway?" [Harvest Anyway] [Wait]. 5. Exit inspection. 6. Walk to hive → prompt: "[E] Remove Marked Super". 7. Super goes into player inventory as ITEM\_FULL\_SUPER. 8. Walk to Extraction Table / Honey House → press [E] to begin extraction pipeline.

#### 6.6.3 Uncapping Mini-Game

Before honey can be extracted, wax cappings must be removed from each frame. This is a hands-on mini-game where the player drags an uncapping tool across the frame surface. Speed and accuracy determine beeswax recovery and honey spillage.

#### Mini-Game: "The Uncapping Swipe"


| Display | The frame fills the center of the screen, showing the honeycomb texture (reuses FrameRenderer output). Capped cells are highlighted with a golden wax overlay. |
| --- | --- |
| Interaction | Player drags the uncapping tool across the frame. The frame is divided into 5 horizontal strips. Each strip requires one clean swipe (click-drag from one edge to the other). |
| Clean Swipe | Smooth, straight path: 100% cappings recovered, 0% honey spillage. |
| Messy Swipe | Jagged or too fast: 70% cappings recovered, 5% honey lost to spillage. |
| Missed Areas | Uncovered strips stay capped → less honey extracted in the next step. |
| Energy Cost | 1 energy per frame uncapped. |
| Skip Option | "Uncap All (Quick)" button: uncaps remaining frames with "messy" quality. Still costs energy. For players who prefer not to play the mini-game. |


#### Tool Progression


| Tool | Unlock | Behavior |
| --- | --- | --- |
| Scratch Roller (starting) | Available from start | Slower swipe required. More forgiving on accuracy. |
| Hot Uncapping Knife | Feed & Supply purchase | Faster swipe allowed. Cleaner cuts. More wax recovered. |
| Electric Uncapping Plane | Year 2 / Honey House upgrade | Auto-uncaps with single click. Maximum recovery. |


#### Output per Frame

`cells_uncapped` (int), `cells_total_capped` (int), `cappings_wax_lbs` (float, cells\_uncapped × 0.00015 lbs), `honey_spillage_pct` (float, 0–5%), `uncap_quality` ("clean" / "messy" / "partial").

#### 6.6.4 Extraction & Grading

After uncapping, frames go into the extractor — a centrifuge that spins honey out of the comb. The extracted honey is then graded by moisture content.

#### Extraction Flow

1. Uncapped frames load into extractor (2 at a time with basic manual extractor, 4 with Honey House). 2. Player presses [Space] Spin — animated extractor spins. 3. Honey drains into settling bucket. 4. After all frames processed, Grading Screen appears.

#### Yield Calculation


```gdscript
per_frame_lbs = (cells_uncapped / FRAME_SIZE_BOTH_SIDES) * LBS_PER_FULL_SUPER_FRAME * (1.0 - honey_spillage_pct)
total_honey_lbs = sum of all extracted frames
```


Where FRAME\_SIZE\_BOTH\_SIDES = 4,900 (2,450 × 2 for medium super), LBS\_PER\_FULL\_SUPER\_FRAME = 3.5, and honey\_spillage\_pct comes from uncapping quality (0% clean, 5% messy).

#### Moisture Calculation


```gdscript
moisture_pct = base_season_humidity
             + (uncapped_cell_fraction * 6.0)
             - curing_bonus
             + (was_fed_recently ? 0.3 : 0.0)
             + (active_rainfall_week ? 0.8 : 0.0)
```


| Season | Base Humidity | Notes |
| --- | --- | --- |
| Spring (Quickening/Greening) | 17.5% | Cool, moist conditions slow evaporation |
| Summer (Wide-Clover / High-Sun) | 16.5% | Heat accelerates curing. Best natural moisture reduction. |
| Fall (Full-Earth / Reaping) | 18.0% | Cooling weather slows curing. Goldenrod nectar has higher initial water content. |


`uncapped_cell_fraction`: proportion of honey cells NOT wax-capped at harvest time. A fully capped frame adds 0; completely uncapped adds +6.0%. `curing_bonus`: −0.8% if Honey House is built (controlled temperature/airflow). `was_fed_recently`: sugar syrup within 30 days adds +0.3% moisture and prevents varietal labeling.

#### Grading Table


| Moisture % | Grade | Price Modifier | Color Tag |
| --- | --- | --- | --- |
| ≤17.0% | Premium | +40% ($14.00/jar) | Gold |
| 17.1–18.6% | Standard | Base ($8.50/jar) | Amber |
| 18.7–20.5% | Economy | −20% ($5.00/jar) | Brown |
| >20.5% | Fermented | Cannot sell as honey | Red |


**Fermented honey** is not wasted — it goes into inventory as ITEM\_FERMENTED\_HONEY, usable for mead crafting (§6.8). **Varietal detection:** if 70%+ of the hive's forager visits in the last 30 days came from one plant type (tracked by ForageManager), honey gets a varietal label (e.g., "Clover Honey"). Varietal + Premium = highest value.

*Design Note: The refractometer tool (unlocked at Level 2) allows the player to see the actual moisture percentage. Before that unlock, the only signal is frame capping percentage and the qualitative grade color. This creates a meaningful progression — beginners learn the 80%-capped rule of thumb, advanced players use data.*

#### 6.6.5 Bottling & Packaging

After extraction and grading, the player chooses how to package their honey. This is a simple but meaningful economic decision.


| Choice | Container | Price | Notes |
| --- | --- | --- | --- |
| Fill Jars | 1 lb glass jar | Grade-based (see grading table) | Requires ITEM_JAR ($0.50 each from Feed & Supply). Click per jar. Higher margin. |
| Fill Bulk Bucket | 5 lb bucket | 60% of jar price per lb | No jar required. Faster. Sells to Frank at wholesale. |
| Store Raw | Settling tank | No immediate sale | Keeps honey available for crafting recipes (Phase 4). |


**Jar labels** show grade + varietal: "Premium Clover Honey" or "Standard Wildflower Honey". Running counter during bottling: "Bottled: 12 jars | Remaining: 6.4 lbs".

#### Honey Jar Metadata

Inventory system extended to track per-stack grade: `{item: "honey_jar", count: 12, grade: "premium", varietal: "clover", moisture: 16.8}`.

#### 6.6.6 Beeswax Collection

Every frame uncapped during harvest produces beeswax cappings as a byproduct. This accumulates automatically during the uncapping step and goes into the player's inventory. Beeswax is the foundation resource for §6.8 Crafting (candles, lip balm, furniture polish, foundation sheets).


| Wax per Cell | 0.00015 lbs (~1 oz per 400 cells) |
| --- | --- |
| Recovery Rate | Clean uncapping: 100%. Messy: 70%. Partial: proportional to coverage. |
| Small Harvest (3–4 frames) | ~0.5–1.0 lbs beeswax |
| Medium Harvest (8–10 frames) | ~2.0–3.5 lbs beeswax |
| Large Harvest (15–20 frames) | ~4.0–7.0 lbs beeswax |
| Sell Price (raw) | $3.25/lb at Feed & Supply. $8–15/lb as crafted candles. |


Wax calculation happens inside the uncapping step. After uncapping completes, total wax is passed through to the extraction screen and added to player inventory as ITEM\_BEESWAX. Fractional amounts tracked in GameData.beeswax\_fractional.

#### 6.6.7 Winter Reserve Warning

The most common beginner mistake in beekeeping is harvesting too much honey, leaving the colony without enough stores to survive winter. This system provides escalating visual warnings on the overworld hive.


| Honey Stores | Level | Visual | Notification |
| --- | --- | --- | --- |
| ≥60 lbs | Safe | Normal hive appearance | None |
| 40–59 lbs | Caution | Orange tint on overworld hive (modulate 1.0, 0.85, 0.5) | "Colony stores are getting low" (first time only) |
| <40 lbs | Danger | Red tint (modulate 1.0, 0.5, 0.5) | "DANGER: Colony may not survive winter at current stores" |
| <20 lbs | Critical | Red pulsing tint (modulate 1.0, 0.3, 0.3) + skull icon | "CRITICAL: Feed immediately or colony will die" |


**Timing:** Warnings activate during Reaping month (month 6, late fall) — the last harvest window. During earlier months, low stores are less alarming because bees are still foraging. If player harvests during Reaping and stores drop below 60 lbs, one-time dialog: "Uncle Bob's voice echoes in your mind: ‘A dead hive makes no honey next year. Leave 'em at least 60 pounds, maybe 80 if it's a cold winter.’"

**Harvest gate:** When player marks frames for harvest and post-harvest stores would drop below 40 lbs, show strong warning (but do not block — player choice is sacred): "Harvesting this frame will leave your colony with only XX lbs of honey. This is below the safe winter minimum of 60 lbs. Continue?"

#### Extraction Facilities

Honey extraction follows a three-tier progression that mirrors the real experience of scaling up a beekeeping operation. The player starts with basic hand tools, graduates to the restored Honey House, and can eventually upgrade it with temperature-controlled curing. Each tier is faster, less energy-intensive, and produces higher-quality results.


| Facility | Unlock | Capacity | Energy Cost | Curing Bonus |
| --- | --- | --- | --- | --- |
| Manual Equipment (Tier 0) | Available from start (purchased from catalogue) | 1 frame at a time. Comb scraper + hand spinner + bottling kit. | 3 energy per frame (scraping: 1, spinning: 1.5, bottling: 0.5) | None (0%). +1.5% moisture penalty (outdoor processing, no climate control) |
| Honey House (Tier 1) | Silas Crenshaw quest chain (mid-summer Y1). Rebuild the dilapidated Honey House. | 2 frames at a time, hand-crank extractor, indoor settling bucket, bottling station. | 2 energy per frame | None (0%) |
| Honey House + Curing Room (Tier 2) | Silas Q4 (Year 2, Level 2, $300 + materials) | 4 frames at a time, upgraded extractor, temperature-controlled curing room, proper bottling line. | 1 energy per frame | -0.8% moisture reduction |


#### Manual Harvest Equipment (Tier 0)

Before the Honey House is restored, the player processes honey by hand using three pieces of equipment purchased individually from the Tanner's Supply catalogue. This is deliberately slow, energy-intensive, and produces slightly lower-grade honey -- it is the motivational pressure that drives the player toward completing Silas's quest chain. The equipment is functional and educational: each piece teaches a real step in the honey extraction process.


| Item | Price | Source | Function |
| --- | --- | --- | --- |
| ITEM_COMB_SCRAPER | $12.00 | Tanner's Supply (catalogue) | A flat-bladed scraping tool used to uncap honeycomb cells before extraction. Replaces the uncapping knife for Tier 0 processing. Slower than the knife -- each frame takes ~50% longer to uncap. Scraper quality is "messy" by default (70% wax recovery, 5% honey spillage) until the player masters the timing. Functions as the uncapping step in the extraction pipeline. |
| ITEM_HAND_SPINNER | $45.00 | Tanner's Supply (catalogue) | A small hand-cranked centrifuge basket that holds 1 frame at a time. The player physically cranks the spinner by holding [Space] -- a circular progress bar fills over ~8 seconds per frame. Uses 1.5 energy per frame (the cranking is hard work). Extraction yield is 85% of the Honey House extractor (some honey stays in the comb due to lower spin speed). The spinner sits on the ground outdoors near the extraction table area. |
| ITEM_BOTTLING_KIT | $18.00 | Tanner's Supply (catalogue) | A basic bucket-and-strainer setup with a honey gate valve. Honey drains from the spinner into the straining bucket, then the player fills jars one at a time by pressing [E] at the valve. No settling time -- honey goes straight from strainer to jar, which means more air bubbles and a slightly cloudy appearance (cosmetic only, no gameplay penalty). Holds up to 15 lbs of honey before needing to be emptied into jars. |


**Manual Processing Flow:** 1. Place uncapped frame on ground near extraction area. 2. Use Comb Scraper on the frame (uncapping mini-game, slower version). 3. Load frame into Hand Spinner. 4. Hold [Space] to crank -- progress bar fills over ~8 seconds. 1.5 energy consumed. 5. Repeat for each frame (1 at a time). 6. Walk to Bottling Kit. Press [E] to fill jars one at a time. 7. Grading happens per-batch after all frames are processed (same grading system, but +1.5% moisture penalty for outdoor processing).

*Design Note: The manual equipment is intentionally tedious. A 10-frame super takes ~15 minutes of real play-time and 30 energy to process manually, versus ~5 minutes and 10 energy in the Tier 1 Honey House. This is not punishment -- it is the authentic experience of a first-year beekeeper extracting honey in their backyard with minimal equipment. The contrast makes the Honey House restoration feel genuinely rewarding, and the manual process teaches every step of extraction before the player automates it.*

### 6.7 Resource & Economy System

The player's financial health is managed across income streams and expense categories. The economy scales with apiary size — early game is tight; late game involves managing significant output.

Income Sources


| Raw Honey (bulk) | Lowest price per unit. Immediate sale. No processing required. |
| --- | --- |
| Jarred Honey | Mid-tier. Requires jars (cost) and labor time. Labeled specialty honey commands premium. |
| Varietal Honey | Premium tier. Single-source honey from a dominant forage (clover, linden, buckwheat). Requires forage management discipline. |
| Beeswax | Sold raw or crafted. Foundation sheets, cosmetics, and candles all carry higher margins. |
| Crafted Goods | Candles, mead, lip balm, body cream. Highest margins. Longest production time. |
| Nucs & Splits for Sale | Selling established nucleus colonies to other beekeepers. High-value seasonal item. |
| Market Events | Seasonal events offer surge pricing windows. Planning around these maximizes revenue. |


Expense Categories


| Bee Acquisition | Packages, nucs, queens. Major spring expense. |
| --- | --- |
| Equipment | Hive bodies, frames, supers, protective gear. One-time and recurring. |
| Treatments | Varroa treatments, disease medications. Cost varies by type and hive count. |
| Feeding | Sugar, pollen substitute, fondant. Significant cost in poor forage years. |
| Crafting Supplies | Jars, labels, wicks, bottles, yeast. Recurring consumable. |
| Land / Structures | New apiary sites, storage sheds, honey house. Major capital expense. |
| Tools & Upgrades | Extractor, refractometer, hive scale, smoker upgrades. |


#### Price Reference Tables

All prices are in-game dollars. These are baseline values; Community Standing tiers apply a price modifier to all honey and crafted product sales.

**Sale Prices — Honey Products**


| Product | Base Price | Notes |
| --- | --- | --- |
| Raw honey (bulk, per lb) | $6.00 | Lowest margin. Instant sale. No equipment required. |
| Jarred honey (1 lb jar) | $12.00 | Requires jar + label. Labor counted as energy cost. |
| Specialty labeled honey (jar) | $16.00 | Labeled with location/season. Requires Level 3 and label supplies. |
| Varietal honey — premium (jar) | $20.00 | Dominant single-source forage. Requires forage management discipline. |
| Fermented honey (mead ingredient only) | $0 as honey | Can be sold as mead at $18/bottle if crafted. |


**Sale Prices — Other Hive Products**


| Product | Base Price |
| --- | --- |
| Beeswax (raw block, per lb) | $10.00 |
| Pollen (raw, per lb) | $18.00 |
| Mead (750ml bottle) | $18.00 |
| Pillar candle | $12.00 |
| Lip balm tube | $6.00 |
| Body cream jar | $15.00 |
| Nuc colony (5-frame, for sale) | $180.00 |


**Purchase Prices — Equipment and Supplies**

*In-game shop prices (Cedar Bend Feed & Supply). Hive components are bought individually to support the component build sequence (§6.0, §13.1).*


| Item | Price |
| --- | --- |
| Hive Stand | $18 |
| Deep Body (Langstroth deep box) | $35 |
| Frames (10-pack) | $18 |
| Hive Lid | $12 |
| Super Box (shallow/medium) | $45 |
| Complete Hive (stand + deep + 10 frames + lid, pre-assembled) | $85 |
| Hive tool | $12 |
| Smoker (basic) | $30 |
| Smoker (quality) | $55 |
| Veil and gloves set | $45 |
| Varroa treatment — oxalic acid (per colony) | $8 |
| Varroa treatment — formic acid pads (per colony) | $15 |
| Varroa treatment — synthetic strips (per colony) | $20 |
| Sugar (10 lb bag, for syrup) | $8 |
| Pollen substitute (per lb) | $12 |
| Glass jars (12-pack) | $18 |
| Labels (50-pack) | $10 |
| Mead bottles + corks (6-pack) | $14 |
| Candle wicks (25-pack) | $8 |


*Design Note: Starting cash is $500. A new player's first spring requires: one package at $185 (if they lose the starting hive), one super at $28, one round of varroa treatment at $8, and a bag of sugar for spring feeding at $8. That leaves plenty of margin for the first harvest investment. The economy is intentionally forgiving in Year 1 and progressively tighter as the player expands.*

### 6.8 Crafting System

Crafting is the primary route to high-margin products. It is concentrated in winter but can be performed year-round if the player has the materials and equipment.


| Product | Inputs | Unlock / Requirements |
| --- | --- | --- |
| Honey Jars (standard) | Raw honey, glass jars, labels | Available from start |
| Varietal Honey Jars | Single-source raw honey (70%+ from one plant type) | Requires forage management + Year 2 |
| Creamed Honey | Raw honey + seed honey, temperature control | Year 2 + Honey House upgrade |
| Beeswax Blocks (raw) | Cappings + rendered wax | Available from start |
| Beeswax Candles | Rendered wax, wicks, molds | Year 1 craft station unlock |
| Lip Balm | Beeswax, carrier oil, optional honey | Year 2 cosmetics recipe |
| Face/Body Cream | Beeswax, shea butter, honey, essential oils | Year 3 cosmetics recipe |
| Mead (traditional) | Honey, water, yeast, time (8–12 weeks) | Year 2 + fermentation vessel |
| Fruit Mead (Melomel) | Honey, water, yeast, seasonal fruit | Year 3 + reputation threshold |
| Pollen Supplement Blend | Collected pollen + soy flour, store for feeding | Year 2 — also sellable |
| Foundation Sheets | Rendered wax, foundation press | Year 3 + equipment unlock |


#### Pesticide Event — Full Definition

The pesticide event is an annual challenge that tests whether the player has managed their relationship with Kacey Harmon and positioned their hives wisely.


| Trigger | Random annual roll during Week 2–3 of Wide-Clover (peak summer). Base probability: 40% per year. Rises to 60% if player has hives at Harmon Farm. Falls to 20% if Kacey Harmon friendship level 3+ is reached (she switches to bee-safe alternatives). |
| --- | --- |
| Player Warning | Without Kacey relationship: no advance warning. Player discovers mass dead bees at entrance next morning. With Kacey relationship (Year 2+): note arrives 3–5 days in advance — "We're spraying the orchard on [day]. You might want to close up your hives." |
| Duration | 3 days of elevated forager mortality |
| Unmitigated effect | Forager field loss multiplier ×8.0 for 3 days. Mass dead bees visible at entrance. Forager population rebuilds over 1–2 weeks. |
| Mitigation: Entrance reducer | Reduces forager exposure to 20% of normal. Reduces mortality multiplier to ×1.6. Costs 1 energy to apply per hive. |
| Mitigation: Move hives | Hives moved away from Harmon Farm (requires cart upgrade, 6 energy, $0 cost) avoid the event entirely for moved hives. |
| Recovery | After event ends, forager mortality returns to normal. Population rebuilds from nurse-to-forager pipeline over ~10–14 days. |


### 6.9 Weather System

Weather is an ever-present constraint that shapes every week of gameplay. Players receive a 3–5 day forecast and must plan their work slots accordingly.


| Condition | Effect on Bees | Effect on Player |
| --- | --- | --- |
| Sunny, 65–85°F / 18–29°C | Optimal foraging. High nectar collection. | Best inspection conditions. All actions available. |
| Overcast, mild | Reduced foraging. Some nectar collection. | Inspections acceptable. Minor efficiency reduction. |
| Rain | Bees stay in hive. No foraging. Irritability increases. | No inspections. Risk of colony stress if prolonged. |
| Wind > 15 mph | Reduced foraging. Bees struggle to fly. | Inspections discouraged — bees are more defensive. |
| Cold snap (< 50°F / 10°C) | Bees cluster. No foraging. Brood at risk if prolonged. | No inspections. Spring cold snaps can chill early brood. |
| Heat wave (> 95°F / 35°C) | Bees beard outside hive. Water demand spikes. | Ensure water source nearby. Add ventilation if possible. |
| Drought | Nectar dearth even when flowers are present. Robbing risk high. | Reduce entrances. Watch for fighting at hive entrances. |
| First frost | Signals end of nectar season. Triggers colony winter mode. | Final harvest window. Begin winter prep sequence. |


---

[< Time & Calendar System](05-Time-and-Calendar-System) | [Home](Home) | [Progression & Unlocks >](07-Progression-and-Unlocks)