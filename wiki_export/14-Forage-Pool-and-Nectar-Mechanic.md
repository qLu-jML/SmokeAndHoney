[< Map Locations](13-Map-Locations) | [Home](Home) | [Core Simulation Scripts >](15-Core-Simulation-Architecture)

---

# Forage Pool & Nectar Mechanic


This section defines the core system governing how flowers, plants, and trees generate nectar and pollen, how hives access that forage, and how overcrowding degrades production. This is a critical design system — it must feel real without requiring the player to manage spreadsheets.

### 14.1 Design Recommendation: The Forage Pool Model

The recommended approach is a Forage Pool per location — a shared resource bucket that all hives at that location draw from simultaneously. This avoids simulating individual bee flight paths while still producing realistic crowding pressure and location-based decision-making.

Each location has a Forage Pool that refreshes weekly. The pool size is determined by the plants present, their bloom status, and any environmental modifiers (weather, crop rotation). Hives at that location each draw a share of the pool. If total demand exceeds supply, each hive gets a proportionally reduced share, directly reducing honey production and over time degrading worker health.

Why This Model Works

It is simple to communicate visually — a location can show 'Forage: Abundant / Adequate / Stressed / Depleted'

It produces natural crowding pressure without complex pathfinding or individual forager simulation

It makes plant investment meaningful — adding a linden tree genuinely increases the pool and benefits all hives at that location

It creates the real-world dynamic where apiaries more than 1–2 miles apart don't compete, while adjacent apiaries do

It scales gracefully — small locations cap out sooner; rich locations support more hives

### 14.2 Forage Pool Calculation

The Forage Pool at a location in a given week is calculated as follows:


| Step 1: Plant Inventory | Sum the Nectar Units (NU) of every blooming plant at the location this week. A plant only contributes when it is in active bloom. |
| --- | --- |
| Step 2: Weather Modifier | Apply a weekly weather multiplier. Warm, sunny, and humid = 1.0–1.2x. Cool and rainy = 0.5–0.7x. Drought = 0.3–0.5x. |
| Step 3: Crop Modifier | Apply any regional modifier from nearby agricultural land (corn year vs. soybean year vs. cover crop). |
| Step 4: Total Pool | Forage Pool (NU) = (Sum of plant NUs) x Weather Modifier x Crop Modifier |
| Step 5: Per-Hive Draw | Each hive draws up to its Demand value (based on worker population). If total demand > pool, each hive gets: (its demand / total demand) x total pool. |
| Step 6: Honey Output | Hive honey production for the week = (actual forage received / hive demand) x base production rate x queen modifier. |


*Design Note: The player never sees the raw NU numbers. They see qualitative signals: a forage status indicator per location ('Abundant', 'Adequate', 'Stressed'), and hive-level signals (reduced honey frame filling, increased bee agitation, robbing behavior) when the pool is stretched.*

### 14.2.1 Flower Lifecycle Phase System

All wildflowers in the game progress through five discrete visual phases. Each phase has its own sprite — there is no fading or alpha blending.

#### Phase Progression (per tile)


| Phase | Visual | Produces NU? | Duration | Notes |
| --- | --- | --- | --- | --- |
| SEED | Dirt mound with visible seed | No | 2–4 days | Tile occupied but contributes nothing |
| SPROUT | Tiny green cotyledon shoot | No | 2–5 days | Visible growth each day |
| GROWING | Taller stem with closed bud | No | 3–7 days | Species-specific bud shape |
| MATURE | Full bloom (species-specific) | Yes | Bulk of bloom window | Only phase that produces nectar and pollen |
| WITHERED | Drooping brown dried flower | No | 4–6 days | Occupies tile, prevents spread, then removed |


#### Key Mechanics

Only MATURE-phase plants produce Nectar Units and pollen (protein). Seeds, sprouts, growing buds, and withered plants contribute zero forage.

WITHERED plants occupy their tile for 4–6 days after the mature phase ends. This prevents runaway spread by blocking new seeds from claiming that space.

Spread only occurs FROM mature tiles. New tiles always begin as SEED, creating a natural growth delay.

Phase durations scale proportionally to each species' bloom window. Short-lived species (dandelion, 45 days total) progress through early phases in ~8 days. Long-lived species (clover, 110 days) take ~16 days to reach maturity.

After a species' bloom window ends, all remaining tiles force-wither and eventually clean themselves up.

#### NU and PU Scaling

Per-tile nectar and pollen values use a whole-number point scale (1–5). These are converted to GDD-scale units via the same formula:

`Zone NU (Nectar Units) = sum(mature_tiles × species_nectar_points) / NU_SCALE`

`Zone PU (Protein Units) = sum(mature_tiles × species_pollen_points) / NU_SCALE`

Where `NU_SCALE = 250` for both. Nectar Units represent honey-producing forage; Protein Units represent pollen availability critical for brood rearing. A healthy colony requires both — nectar alone produces honey but cannot sustain brood development without adequate protein (pollen).

At B-rank, the starting zone produces ~35–43 NU and ~25–35 PU at peak summer (High-Sun). The pollen peak arrives slightly earlier than nectar peak because spring species (dandelion, coneflower) are pollen-heavy, while the dominant nectar producer (clover) has lower pollen output. This mirrors real-world Iowa conditions where spring pollen is abundant but fall pollen declines faster than nectar.

Player investment in planted gardens and trees is required to reach the 80–100 NU "fully developed home property" target.

#### Per-Tile Point Values


| Species | Nectar pts | Pollen pts | Role |
| --- | --- | --- | --- |
| Dandelion | 2 | 3 | First spring forage, critical pollen |
| White Clover | 4 | 2 | Backbone nectar producer, longest bloom |
| Wild Bergamot | 3 | 2 | Summer prairie nectar |
| Purple Coneflower | 2 | 3 | Summer pollen powerhouse |
| Sunflower | 2 | 4 | Massive pollen, moderate nectar |
| Goldenrod | 3 | 1 | Dominant fall nectar |
| Aster | 2 | 2 | Fall companion, balanced |


### 14.3 Nectar Units (NU) — Plant Reference

Nectar Units are the internal currency of the forage system. They are calibrated to represent the nectar available from plants at the scale of a home garden or small apiary planting — not square miles of natural forage. One NU represents the nectar contribution of a single mature planting unit (one flower bed, one mature tree, one 10-foot row of a crop flower).

A single healthy hive at full summer population has a weekly Demand of approximately 20 NU. This is the baseline for all calibration below.


| Plant / Tree | NU per Planting Unit (at peak bloom) | Bloom Window (Millhaven County) |
| --- | --- | --- |
| Willow (mature tree) | 8 NU — pollen-heavy, limited nectar | Quickening (early spring) |
| Silver Maple (mature tree) | 6 NU — early, critical pollen source | Quickening (mid-spring) |
| Wild Plum Thicket (row) | 5 NU | Quickening – Greening |
| Dandelion (wild, lawn/field) | 1–14 NU — VARIABLE. Annual roll determines density. POOR year: 1–2 NU. AVERAGE: 3–5 NU. GOOD: 6–9 NU. EXCEPTIONAL: 10–14 NU. See Section 14.8.1. | Quickening – early Greening (Day 5–50). Bloom date varies ±1–2 weeks with spring temperature. |
| Apple / Cherry / Pear Tree | 7 NU — excellent spring flow | Greening (late spring) |
| White Clover (bed/row) | 10 NU — primary summer forage, long season | Greening through Full-Earth (Day 30–140) |
| Wild Bergamot (native prairie) | 7 NU — excellent nectar, Iowa prairie native | Wide-Clover – High-Sun (Day 55–105) |
| Purple Coneflower (native prairie) | 6 NU — high pollen, moderate nectar | Wide-Clover – Full-Earth (Day 60–130) |
| Sunflower (bed/row) | 5 NU — high pollen, moderate nectar | High-Sun – Full-Earth (Day 80–130) |
| Linden / Basswood (mature) | 18 NU — peak summer, premium honey | Wide-Clover to High-Sun (3–4 wk window) |
| Goldenrod (wild, field edges) | 2–20 NU — VARIABLE. Annual roll determines density. POOR year: 2–4 NU. AVERAGE: 6–9 NU. GOOD: 10–14 NU. EXCEPTIONAL: 15–20 NU. Frost can terminate early. See Section 14.8.2. | Full-Earth – Reaping (Day 110–165). Ends at first hard frost. |
| Native Asters (bed/row) | 7 NU — fall closer, supports winter bees | Full-Earth – Reaping (Day 120–165) |
| Soybean field (adjacent) | 3 NU — modest contribution in bloom period | High-Sun |
| Cover Crop Mix (Harmon Farm) | 12 NU — large area, diverse mix, fall bonus | Full-Earth – Reaping (when planted post-harvest) |
| Native Wildflower Meadow | 15 NU — river bottom meadow, diverse species | Wide-Clover through Reaping |


*Design Note: These values are intentionally modest per unit because the player is managing a garden-scale planting, not a landscape. A full home garden with 4 flower beds of white clover, wild bergamot, coneflower, and goldenrod gives about 33 NU at peak — enough to support 1–2 hives well, but not 5. Planting trees and developing additional apiary locations is the route to supporting more hives. This mirrors real-world beekeeping economics.*

### 14.4 Hive Carrying Capacity & Overcrowding

Each location has a soft and hard hive cap based on its maximum forage pool potential.


| Optimal Load | Total hive demand at the location equals 80% or less of the peak forage pool. All hives receive full forage. Production is at maximum. |
| --- | --- |
| Adequate Load | Demand is 80–110% of pool. Hives receive 90–100% of demand. Minor production reduction. No health effect. |
| Stressed Load | Demand is 110–150% of pool. Hives receive 67–90% of demand. Honey production noticeably reduced. Robbing risk increases. Worker health begins slow decline after 2+ consecutive stressed weeks. |
| Depleted Load | Demand exceeds 150% of pool. Hives receive less than 67% of demand. Significant production loss. Robbing events likely. Worker health declines measurably. Bees begin foraging farther afield with diminishing returns. |


Per-Location Capacity Reference


| Location | Peak Forage Pool (developed) | Optimal Hive Count |
| --- | --- | --- |
| Home Property (fully planted) | ~80–100 NU (garden + back field + maturing trees) | 4–5 hives |
| Timber / Woodlot (natural + planted) | ~100–120 NU (basswood dominant, natural flora) | 5–6 hives |
| Harmon Orchard (orchard + cover crop) | ~60–80 NU (fruit trees + cover crop when unlocked) | 3–4 hives |
| River Bottom (natural meadow) | ~140–160 NU (wildflower meadow + willows + asters) | 7–8 hives |
| Town Garden (small plot) | ~30–40 NU (municipal plantings, modest) | 1–2 hives |


*Design Note: These numbers are tuning targets, not hard values. Playtesting will determine whether the curve feels rewarding. The key design principle: a fully developed home property should comfortably support its 5-hive cap, requiring the player to have meaningfully invested in planting. An undeveloped home property with no flowers supports maybe 2 hives comfortably. The investment matters.*

### 14.5 Pollen vs. Nectar

Not all forage is equal. The forage pool tracks both nectar (converted to honey) and pollen (critical for brood nutrition). Some plants are primarily pollen sources; others are primarily nectar sources. A healthy hive needs both.


| Plant | Nectar Value | Pollen Value |
| --- | --- | --- |
| White Clover | Very High | Moderate |
| Willow | Low | Very High — early season critical |
| Sunflower | Moderate | Very High |
| Wild Bergamot | High | Moderate |
| Purple Coneflower | Moderate | High |
| Linden | Very High | Low |
| Goldenrod | High | High — both essential for fall |
| Native Wildflowers | High | High — diverse spectrum |
| Corn (adjacent) | None | Moderate — nutritionally poor |


A location dominated by nectar-only plants (e.g., pure linden flow with no pollen sources) will have high honey output but risk pollen deficiency, affecting brood development. The player learns to balance nectar and pollen sources in their planting choices — planting willow or coneflower alongside their linden trees makes biological sense and is rewarded in the game.


| Pollen Deficiency Effect | If a hive's pollen intake falls below threshold for 2+ weeks: brood development slows, worker health gradually declines, colony growth stalls. The player sees a 'reduced brood' observation during inspection. |
| --- | --- |
| Mitigation | Pollen substitute feeding, planting pollen-rich species, or accessing a location with more pollen diversity corrects the issue within 2–3 weeks. |


### 14.6 Seasonal Forage Calendar (Millhaven County, Iowa)

This table represents the realistic Cedar Bend nectar and pollen flow calendar that the game's plant NU values are designed around. It serves as the ground truth for when each plant contributes to the forage pool.


| Month (approximate) | Active Forage Sources | Flow Character |
| --- | --- | --- |
| Quickening | Willows, silver maple, early dandelions (if year is AVERAGE or better) | Trickle pollen flow. Critical for first brood. POOR dandelion year: colonies may need supplemental feeding now. No surplus honey expected. |
| Greening | Dandelions (peak bloom in GOOD/EXCEPTIONAL years), fruit trees, wild plum, early clover | Dandelion dilemma: harvest for spring income vs. leave for buildup. If dandelions are POOR and clover is late, starvation gap risk. See Section 14.8.1. |
| Wide-Clover | White clover, wild bergamot, linden (late June), coneflower | Primary spring/early summer flow. First honey surplus. Super timing begins. |
| High-Sun (early) | White clover, bergamot, coneflower, linden (early July), sunflower, soybeans (adjacent) | Peak production. Linden window is short and valuable. Watch for midsummer dearth after linden fades. |
| High-Sun – Full-Earth | Sunflower (ending), goldenrod beginning (AVERAGE+ years, late Aug), coneflower (ending) | CRITICAL WINDOW: Pull premium summer supers before goldenrod contaminates uncapped honey. See Section 14.8.2. Goldenrod flow strength depends on annual roll outcome. |
| Full-Earth – Reaping | Goldenrod (primary flow in GOOD/EXCEPTIONAL years), native asters, cover crops (if Grubers planted) | Goldenrod dilemma: leave all stores for winter vs. careful harvest of surplus in GOOD/EXCEPTIONAL years. POOR year: mandatory fall feeding begins now. Frost watch: early frost ends flow immediately. |
| Reaping (late) | Late asters, final goldenrod (if frost hasn't hit), last dandelion flushes | Flow ending or already ended. First hard frost terminates goldenrod. Emergency feeding window if stores are insufficient. Winter prep final checks. |
| November–February | Nothing | No flow. Bees on stores. Cluster period. |


### 14.7 Visualizing Forage for the Player

The forage pool should be legible to the player without requiring them to track numbers. The following UI and in-world signals communicate forage status.


| Location Forage Indicator | A simple icon on each location in the map view: a full flower (abundant), half flower (adequate), wilting flower (stressed), bare stem (depleted). Updates weekly. |
| --- | --- |
| Hive Entrance Activity | A visually full and busy hive entrance means bees are foraging well. A quiet entrance mid-day in summer is a signal — possible dearth or hive problem. |
| Robbing Behavior | Small animated bees fighting at the entrance. A clear visual signal of forage stress. Appears before the forage indicator drops to depleted. |
| Honey Frame Fill Rate | During inspection, the player sees how full honey frames are compared to last week. Slowing fill rate is the first numerical hint of forage trouble. |
| Bee Foraging Range Overlay | When placing a new hive or scouting a location, a soft circle overlay shows the forage radius — and highlights any overlap with existing apiaries. |
| Darlene's Advice | Early in the game, if the player's forage is stressed, Darlene will comment on it during their next conversation. 'Noticed your girls were working pretty hard yesterday — might want to think about adding some clover out back.' |


### 14.8 Dandelions & Goldenrod — Critical Wild Forage Events

Dandelions and goldenrod occupy a special category in the forage system. Unlike planted flowers, they cannot be controlled or cultivated by the player. They appear spontaneously in the landscape according to seasonal conditions and are modeled as stochastic annual events — their timing, density, and duration vary year to year in ways that force the player to observe and adapt rather than plan ahead.

These two plants bookend the productive beekeeping year in Cedar Bend County. Dandelions determine whether spring colonies survive or starve. Goldenrod determines whether colonies have the stores to survive winter. Both generate honey that presents the player with a market timing decision — and in both cases the right answer is not obvious.

*Design Note: This is the game's primary randomization layer for forage. Planted forage is reliable and player-controlled. Wild forage is nature — it arrives when it wants, as much as it wants, and the beekeeper adapts. This distinction is authentic and creates genuine year-to-year variance in gameplay.*

14.8.1 Dandelions — The Spring Lifeline

Dandelions are the most important wild forage plant in the game. In a good year they bridge the gap between winter's end and the first intentional planted flows, giving colonies the nectar and pollen they need to build spring population without the player having to feed. In a bad year, colonies that were counting on dandelions starve — or require expensive supplemental feeding to survive until the next source blooms.

Dandelion Generation — The Annual Roll

At the start of each spring season, the game performs an annual dandelion assessment. This roll is made once per year, produces a result that persists for the entire spring window, and is never directly shown to the player as a number. Instead it manifests in what the player sees on the ground.


| Inputs to the roll | Previous winter severity (hard winter = less seed survival) Fall conditions from last year (late goldenrod = more seed set = more dandelions next spring) Random variance seed (re-rolled every new year — not predictable) Current spring temperature progression (early warm = early bloom; late cold = delayed bloom) |
| --- | --- |
| Roll outcome categories | POOR: Very sparse dandelions, late bloom, short window. NU contribution: 1–2 NU across most locations. Colonies that relied on dandelions will need supplemental feeding. AVERAGE: Normal density, normal timing. NU contribution: 3–5 NU. Adequate for building colonies; not surplus. GOOD: Dense bloom, on-time. NU contribution: 6–9 NU across grass areas. Colonies thrive without intervention. Dandelion honey surplus is possible. EXCEPTIONAL: Explosive bloom, early and long-lasting. NU contribution: 10–14 NU. Meaningful dandelion honey harvest possible. A 'gift year' — rare. |
| Timing variance | Even within the same outcome category, the bloom start date varies ±1–2 weeks from the long-term average (late Quickening in Cedar Bend County). An early spring (warm March) can push dandelions into late Quickening. A cold spring can delay them to mid-Greening — dangerously late for colonies building toward the main clover flow. |


Dandelion Spatial Generation — The Grass Grid

Dandelions do not appear as planted objects. They emerge procedurally from the grass surfaces of each scene. Every location in the game (home property, road verges, timber clearings, river bottom) has a grass tile grid. At the start of spring, a scatter algorithm populates individual grass tiles with dandelion instances based on the annual roll outcome.


| Grid resolution | Each scene's grass area is divided into a logical grid of tiles — roughly 2m × 2m squares in world space. This is not visible to the player; it is the underlying structure the forage system reads. Example: the home property back field might be a 20×15 grid = 300 grass tiles. |
| --- | --- |
| Scatter algorithm | func generate_dandelions(outcome, grid): base_density = outcome.density_range.pick_random() # e.g. 0.15–0.45 for AVERAGE for each tile in grid: # Edge tiles near paths/fences are more likely — dandelions favor disturbed soil location_modifier = 1.3 if tile.is_edge else 1.0 if randf() < base_density * location_modifier: tile.plant = DANDELION tile.bloom_day = outcome.bloom_start + randi_range(-3, 3) # per-tile jitter tile.bloom_duration = outcome.duration + randi_range(-2, 2) |
| NU contribution | Each blooming dandelion tile contributes a fractional NU to its location's forage pool for the week it is in bloom. The sum of all blooming dandelion tiles is the location's dandelion NU for that week. This means a GOOD year with many tiles blooming simultaneously produces a genuine flow; a POOR year with sparse scattered tiles is barely a trickle. |
| Visual representation | Blooming dandelion tiles show yellow dots scattered across the grass surface of the scene. Dense bloom years visibly cover the lawn; poor years show only occasional flowers. The player reads the visual before any forage data updates — an early, intuitive signal of what kind of spring they're dealing with. |
| Mowing interaction | If the player mows their lawn (an available action on the home property), dandelions in that area are removed for 2–3 weeks before regrowth. A realistic trade-off: a tidy lawn vs. spring forage. New players who mow habitually discover the cost when spring forage is thin. |


Dandelion Honey — The Spring Market Dilemma

A GOOD or EXCEPTIONAL dandelion year creates the game's first significant harvest decision. Dandelion honey is distinctive — bright yellow, strongly flavored, granulates quickly — and it sells well at the spring market. But harvesting it comes at a cost.


| Scenario | Harvest the Dandelion Honey | Leave It for the Colony |
| --- | --- | --- |
| GOOD or EXCEPTIONAL dandelion year | Dandelion honey commands a spring premium — it is rare and distinctive. Uncle Bob's market customers pay above base price for it. Early-season income is valuable for purchasing equipment and bees. Risk: if the next 2–3 weeks are cold or rainy and the clover flow is delayed, the colonies that had their dandelion honey removed may face a starvation gap. The player must watch the forecast carefully. | Colonies use dandelion stores to fuel explosive spring buildup. More bees going into the clover flow = more honey in summer = higher total season yield. The mathematical reality: a frame of dandelion honey left in the hive produces more total honey value through amplified summer production than that frame's direct sale price in most scenarios. But it requires patience and faith in the summer. |
| AVERAGE dandelion year | Modest harvest is possible if stores are already adequate (colonies came out of winter strong). Risky if winter stores are low. Darlene's advice: 'I'd leave it this year. Not enough to spare.' | The correct default in an average year. Colonies need the stores for spring buildup. No surplus exists. |
| POOR dandelion year | No harvest — there is nothing to take. Player must monitor stores and be ready to feed. This is the year supplemental feeding becomes critical. | Even leaving everything is not enough. Player must supplement with sugar syrup and/or pollen substitute to prevent starvation until the clover flow begins. Cost: real money from the player's balance. Failure to feed in a POOR dandelion year is the most common cause of spring colony loss for new players. |


*Design Note: The dandelion dilemma is the game's first major test of the player's ability to think ahead rather than react. Taking the dandelion honey feels like a win in the moment. Losing a colony three weeks later because the clover was late is a lesson the player remembers for every subsequent spring. This is exactly the kind of consequential learning the game is designed around.*

Starvation Gap Detection & Supplemental Feeding

When dandelions are poor or absent and the next forage source hasn't bloomed yet, the simulation enters a starvation gap window. The game tracks this and surfaces it to the player before it becomes critical.


| Starvation gap trigger | When all of the following are true simultaneously: location.forage_pool_this_week < (total_hive_demand × 0.3) AND average_honey_frame_fill < 2.0 frames per hive AND current_week is within spring window (weeks 1–6 of spring) → starvation_risk_flag = true for affected hives |
| --- | --- |
| Player warning | Hive status icon changes to a 'low stores' indicator. Darlene, if spoken to, says something like: 'You might want to check your stores — it's been cold and the flowers are behind this year. I'd think about putting some syrup on.' |
| Supplemental feeding options | 1:1 Sugar Syrup (spring formula) — stimulates foraging behavior, mimics nectar flow. Cheap, available from feed store. 2:1 Sugar Syrup (heavier) — pure energy storage, not stimulative. Used when stores are critically low. Pollen Substitute Patty — addresses the protein gap if natural pollen is unavailable. Critical for nurse bees and larval development. Fondant / Hard Candy — emergency winter/late-spring feeding when temperatures are too cold for syrup to be taken down. |
| Feeding mechanic | Player selects a hive, chooses 'Feed,' picks a product and quantity. Feed is consumed over the following days at a rate proportional to colony population and temperature. The simulation registers the incoming sugar as a substitute nectar input — it does not produce harvestable honey (marked as non-harvestable stores internally) but does sustain the population simulation's nutritional inputs. |
| Feeding honey quality flag | If a colony is fed sugar syrup and the player harvests honey from that hive too soon after feeding, the honey may contain sugar syrup residue — a quality defect. The game tracks a feeding_residue_days counter per hive. Harvesting before this clears to zero downgrades the honey quality grade. This is a real-world concern and creates an authentic timing constraint. |


*Phase System Note: Dandelion tiles take ~8 days to reach MATURE phase (2 seed + 2 sprout + 4 growing). In a POOR year with late bloom, colonies face a critical gap before any dandelion nectar is available. Supplemental feeding may be essential. See §14.2.1 for full phase system details.*

14.8.2 Goldenrod — The Fall Closer

Goldenrod is the final nectar flow of the Cedar Bend beekeeping year. It runs from late High-Sun through September and into early Reaping, tapering off with the first hard frost. It is the colony's last major opportunity to build winter stores — and the beekeeper's last opportunity to harvest honey before winter preparations begin. These two goals are directly in conflict.

Goldenrod honey is distinctive and polarizing. It is strongly flavored, dark amber, and granulates very quickly — sometimes in the comb before the beekeeper can extract it. At the farmers market, it sells poorly compared to the light spring clover honey or the premium linden varietal. Most customers don't want it. Most beekeepers don't harvest it. But it is what keeps colonies alive through Cedar Bend winters.

Goldenrod Generation — The Annual Roll

Like dandelions, goldenrod undergoes an annual assessment at the start of fall. The roll is performed when the seasonal calendar transitions to fall week 1.


| Inputs to the roll | Summer drought severity (drought weakens goldenrod root systems, reduces bloom) Summer mowing/disturbance of field edges (mowed goldenrod = no bloom that fall) Previous year's seed set (a good goldenrod year usually follows a moderate one) Fall temperature progression (early frost cuts the flow short; warm fall extends it) Random variance seed (re-rolled every year) |
| --- | --- |
| Roll outcome categories | POOR: Sparse bloom, early frost cuts it short. NU contribution: 2–4 NU. Colonies will not fill winter stores from goldenrod alone — supplemental fall feeding is essential. AVERAGE: Normal density, normal timing. NU contribution: 6–9 NU. Adequate for store building. Typical Millhaven County fall. GOOD: Dense bloom, long season into October. NU contribution: 10–14 NU. Strong store building. Modest goldenrod honey harvestable without endangering winter survival. EXCEPTIONAL: Exceptional bloom, warm fall. NU contribution: 15–20 NU. Colonies fill their winter stores and produce surplus. A true goldenrod harvest year — uncommon. |
| Frost interaction | Each fall week, the weather system runs a frost probability check that increases as the season progresses. When a hard frost fires, goldenrod bloom ends immediately — all blooming goldenrod tiles are marked dormant. A late frost year extends the flow; an early frost year cuts it brutally short regardless of the annual roll outcome. This creates a secondary layer of variance: even a GOOD goldenrod year can be ruined by an early frost. |


Goldenrod Spatial Generation

Goldenrod grows in field edges, ditch lines, fence rows, and untended areas. Its spatial generation within the FlowerLifecycleManager uses an edge bias — tiles near the borders of the grass zone receive +50% spawn probability.


| Spatial bias | Goldenrod strongly favors edge tiles: fence lines, tree lines, road ditches, field margins. The scatter algorithm weights edge tiles 2–3× higher than open field tiles. The road ditch along the county road scene generates goldenrod automatically each fall — ambient forage the player cannot influence but can observe. The Harmon farm field edges generate goldenrod when NOT mowed — another incentive to maintain a good relationship with Walt and Kacey (they can be asked to leave field edges unmowed as part of the cover crop quest line). |
| --- | --- |
| Scatter algorithm | func generate_goldenrod(outcome, grid): base_density = outcome.density_range.pick_random() for each tile in grid: edge_weight = 2.5 if tile.is_field_edge else 0.8 if tile.is_open_field else 1.0 if randf() < base_density * edge_weight: tile.plant = GOLDENROD tile.bloom_day = outcome.bloom_start + randi_range(-4, 4) tile.bloom_duration = outcome.base_duration # Frost will terminate duration early if it fires before natural end |
| Visual representation | Blooming goldenrod tiles show bright yellow-gold plumes along fence lines and field edges. In an EXCEPTIONAL year the entire field margin blazes yellow-gold — a visually striking and atmospherically appropriate fall scene. In a POOR year, scattered thin plumes suggest the lean winter ahead. |


The Goldenrod Market Dilemma

Goldenrod creates the fall counterpart to the dandelion dilemma — but with reversed economics. Dandelion honey is worth harvesting if you can spare it. Goldenrod honey is generally not worth harvesting, but the temptation is there.


| Scenario | Harvest the Goldenrod Honey | Leave It for the Colony |
| --- | --- | --- |
| EXCEPTIONAL goldenrod year | A surplus genuinely exists. If colonies have already met their winter store threshold (verified by frame inspection), the surplus frames can be harvested. Goldenrod honey sells poorly at the market — 30–40% below base honey price. Uncle Bob will take it for bulk blending but won't display it on his premium shelf. Best strategy: blend it with light summer honey before bottling to improve flavor profile and marketability (a crafting action). Or hold it as emergency winter feed. | Colonies are maximally prepared for winter. Overwinter survival probability reaches its peak. The investment in not harvesting pays dividends in a strong spring colony that doesn't need emergency feeding. |
| GOOD goldenrod year | Possible if stores are already full and the player is confident about winter. The risk calculation tightens significantly compared to EXCEPTIONAL. Darlene's advice: 'Your stores look solid. You might get a frame or two without hurting them — but I'd be careful.' | The safe default. Winter stores are reinforced. No risk. No immediate income. |
| AVERAGE goldenrod year | Do not harvest. Colonies need every frame for winter. Harvesting goldenrod in an average year is the second most common cause of spring starvation loss (after poor dandelion year mismanagement). | Colonies enter winter with adequate stores. Normal overwinter survival probability. Standard outcome. |
| POOR goldenrod year | No harvest — nothing to take. Supplemental fall feeding with 2:1 syrup is necessary. This is the year the player must make hard decisions: feed all hives or prioritize the strongest ones? | Even leaving everything is not enough. Fall feeding is mandatory. Cost: money and time. Failure to feed creates winter losses that are discovered the following spring. |


*Design Note: The goldenrod dilemma is the mirror image of the dandelion dilemma — but with a slower-burning consequence. Dandelion mistakes kill colonies in 2–3 weeks. Goldenrod mistakes kill colonies 3–4 months later, in January or February, when the player opens a hive for a warm-day check and finds a dead cluster surrounded by empty frames. The delayed consequence makes it harder to learn from, which makes it more important to design clear signals around.*

*Phase System Note: Goldenrod tiles take ~11 days to reach MATURE phase (3 seed + 3 sprout + 5 growing). The fall flow ramps up slower than the calendar bloom date suggests, reflecting real-world conditions where goldenrod fields take time to fully open. See §14.2.1 for full phase system details.*

Harvest Timing — The Critical Pre-Goldenrod Window

One of the most important practical lessons the game teaches is this: harvest your good honey before goldenrod starts. Once the goldenrod flow begins, any honey the bees are curing in the super will be contaminated with goldenrod nectar — it darkens the color, changes the flavor, and reduces the market value. The player must pull their premium summer supers before the goldenrod flow begins.


| The contamination mechanic | When goldenrod bloom begins at a location, all supers at that location that contain uncapped or partially cured honey begin receiving goldenrod nectar mixed in. A contamination_pct counter tracks the proportion of goldenrod nectar in the current super's uncapped stores. Once capped, those frames are locked at their contamination percentage. Honey graded at >15% goldenrod contamination is classified as a goldenrod blend — lower price tier. Honey already fully capped before goldenrod bloom is unaffected — the contamination only applies to in-progress nectar. |
| --- | --- |
| The harvest window | The game provides a 1–3 week warning before goldenrod bloom based on the forage calendar and weather. Darlene will mention it: 'Goldenrod's going to be showing up soon. If you want to pull your good honey, now's the time.' The player has a limited window to harvest summer supers before the quality lock-in occurs. This window varies by year — an early frost might eliminate it entirely; a warm September extends it comfortably. |
| Super management strategy | Experienced players learn to pull their premium summer supers in late High-Sun, leaving only empty drawn comb or fresh supers for the goldenrod flow. The fresh supers fill with goldenrod honey designated as winter stores or bulk sale. Premium honey is protected. |
| The empty super question | If the player pulls all supers before goldenrod, the bees will attempt to store goldenrod nectar in the brood box, potentially creating a honey-bound condition during the fall flow. The player must leave or add a dedicated 'goldenrod super' — a cheap drawn comb super with low-quality frames that can fill up, be left for winter stores, or harvested as bulk. |


14.8.3 Annual Event Summary — Both Plants

The following table summarizes how dandelions and goldenrod function as paired annual events that bracket the beekeeping year. They are the game's primary source of year-to-year variance and the forcing function behind the game's most consequential player decisions.


| Attribute | Dandelions (Spring) | Goldenrod (Fall) |
| --- | --- | --- |
| Role in the hive year | Spring lifeline — bridges winter's end to the first planted flows. Make-or-break for colony survival. | Fall closer — last chance to build winter stores. Make-or-break for overwinter survival. |
| Annual roll timing | Performed at spring week 1. Result reflects previous winter severity, fall seed set, and current spring temperature progression. | Performed at fall week 1. Result reflects summer drought, field management, previous year seed set, and fall temperature forecast. |
| Outcome range | POOR (1–2 NU), AVERAGE (3–5 NU), GOOD (6–9 NU), EXCEPTIONAL (10–14 NU) | POOR (2–4 NU), AVERAGE (6–9 NU), GOOD (10–14 NU), EXCEPTIONAL (15–20 NU) |
| Spatial generation | Scatter across all grass tiles. Edge tiles slightly favored. Density reflects annual roll. Bloom date has ±1–2 week variance. | Strongly biased to field edges, fence lines, ditch rows. Road ditches auto-generate. Frost can terminate early. |
| Visual signal | Yellow dots scattered across lawn and field grass. Dense bloom = yellow lawn. Sparse bloom = occasional flowers. | Bright gold plumes along fence lines and field margins. Dense bloom = blazing autumn border. Sparse = thin scattered plumes. |
| Honey flavor/market | Bright yellow, strongly flavored, quick to granulate. Sells ABOVE base price. Spring premium. Rare specialty. | Dark amber, strongly flavored, granulates very fast, sometimes in the comb. Sells BELOW base price. Poor market value. Bulk or blend only. |
| Primary decision | Harvest dandelion honey for spring income vs. leave for colony buildup. Risk: starvation gap if clover is late. | Harvest before goldenrod to protect premium summer honey quality. Risk: honey-bound brood box if no super is left for goldenrod stores. |
| Failure consequence | Spring starvation. Colony population crashes 2–4 weeks after the dandelion window closes if stores were pulled and no clover follows. | Winter starvation. Colony dies in January–February. Discovered at spring inspection as a dead cluster surrounded by empty frames. |
| Player mitigation | Supplemental feeding: 1:1 syrup + pollen patties. Activated when starvation_risk_flag fires. | Supplemental fall feeding: 2:1 syrup. Fondant for late-season when temperatures drop. Prioritize strongest colonies if budget is limited. |
| Darlene's signal | 'It's been cold — dandelions are running late this year. I'd think about putting some syrup on until things open up.' | 'Goldenrod's going to show up soon. If you want to keep your good honey clean, now's the time to pull those supers.' |


*Design Note: These two events together are the year's primary emotional arc. Spring opens with hope and uncertainty — will the dandelions come through? Fall closes with urgency and restraint — take the good honey, leave enough to survive. A player who manages both well across multiple seasons has genuinely internalized the rhythm of the Cedar Bend beekeeping year.*

### 14.8.4 FlowerLifecycleManager — Unified Wildflower System

The FlowerLifecycleManager replaces the old DandelionSpawner and handles all 7 wildflower species through a unified tile-based system. Each species is subject to season-ranked density (S/A/B/C/D/F), per-tile phase progression (SEED → SPROUT → GROWING → MATURE → WITHERED), and mature-only spread mechanics. See §14.2.1 for the complete phase system specification.

Iowa-native (or naturalized) species in the system:


| Species | Scientific Name | Bloom Window |
| --- | --- | --- |
| Dandelion | Taraxacum officinale | Day 5–50 |
| White Clover | Trifolium repens | Day 30–140 |
| Wild Bergamot | Monarda fistulosa | Day 55–105 |
| Purple Coneflower | Echinacea purpurea | Day 60–130 |
| Sunflower | Helianthus annuus | Day 80–130 |
| Goldenrod | Solidago spp. | Day 110–165 |
| Aster | Symphyotrichum novae-angliae | Day 120–165 |


### 14.8.5 FlowerLifecycleManager — Unified Seasonal Flower System

The FlowerLifecycleManager replaces garden beds, static wildflower patches, and individual plant spawners (DandelionSpawner, etc.) with a unified system that manages all flower growth, spread, and lifecycle organically across the game world.

#### Season Quality Ranking

Each of the four seasons (Spring, Summer, Fall, Winter) receives an independent quality ranking at season start. Rankings follow a weighted probability distribution:


| Rank | Probability | Initial Density | Daily Spread Chance | Max Coverage | Character |
| --- | --- | --- | --- | --- | --- |
| S | 5% | 30% | 12% | 55% | Exceptional — flowers everywhere, rapid spread |
| A | 15% | 22% | 8% | 42% | Good year — abundant coverage, noticeable spread |
| B | 35% | 16% | 5% | 30% | Average — supports 1–2 hives, moderate spread |
| C | 25% | 10% | 2.5% | 20% | Below average — sparse, limited spread |
| D | 15% | 5% | 0.8% | 10% | Poor — scattered flowers, near-zero spread |
| F | 5% | 2% | 0% | 4% | Failure — total cessation, flowers barely present |


#### Flower Lifecycle & Bloom Windows

Each flower type has a specific bloom window (day-of-year range) with realistic overlap across seasons. Flowers progress through 5 discrete phases per tile (SEED → SPROUT → GROWING → MATURE → WITHERED). Only MATURE tiles produce nectar and pollen. See §14.2.1 for the complete phase system specification.


| Flower | Bloom (Days) | Nectar pts | Pollen pts | Edge Bias |
| --- | --- | --- | --- | --- |
| Dandelion | 5–50 | 2 | 3 | No |
| White Clover | 30–140 | 4 | 2 | No |
| Wild Bergamot | 55–105 | 3 | 2 | No |
| Purple Coneflower | 60–130 | 2 | 3 | No |
| Sunflower | 80–130 | 2 | 4 | No |
| Goldenrod | 110–165 | 3 | 1 | Yes |
| Aster | 120–165 | 2 | 2 | Yes |


Per-tile point values are converted to GDD-scale units via `Zone NU = sum(mature_tiles × nectar_pts) / 250` and `Zone PU = sum(mature_tiles × pollen_pts) / 250`. See §14.2.1 for calibration details.

#### Seasonal Flow Narrative

**Quickening (Days 1–28):** Dandelion seeds appear around day 5, taking ~8 days to reach mature bloom. By mid-Quickening, the first dandelion nectar is available — the only forage source this early. Dandelions are pollen-heavy (3 pts vs 2 nectar), providing critical protein for spring brood rearing. In a POOR year, colonies may need supplemental feeding. Zone: ~7 NU, ~10 PU at B-rank.

**Greening (Days 29–56):** Dandelions continue while clover seeds begin sprouting around day 30. By late Greening, clover tiles are reaching maturity. Clover shifts the balance toward nectar (4 pts) over pollen (2 pts). Zone: ~24 NU, ~15 PU at B-rank.

**Wide-Clover (Days 57–84):** Clover dominates as the nectar backbone. Wild bergamot begins its bloom cycle (day 55), adding moderate nectar (3 pts) and pollen (2 pts). Zone: ~36 NU, ~22 PU at B-rank.

**High-Sun (Days 85–112):** Peak production. Clover + mature bergamot + coneflower + sunflower all producing simultaneously. Sunflower is the pollen powerhouse (4 pts), coneflower adds strong pollen (3 pts). Zone: ~43 NU, ~35 PU at B-rank — the year's peak.

**Full-Earth (Days 113–140):** Clover begins withering. Goldenrod seeds appear at field edges (day 110), taking ~11 days to mature. Goldenrod is nectar-heavy (3 pts) but low pollen (1 pt) — protein availability drops sharply. Zone: ~28 NU, ~14 PU at B-rank.

**Reaping (Days 141–168):** Goldenrod and aster provide the final flow. Aster offers balanced but modest forage (2/2). Protein scarce — late brood rearing suffers. Zone: ~18 NU, ~8 PU at B-rank.

**Deepcold/Kindlemonth (Days 169–224):** No flowers bloom. All withered tiles have been cleaned up. Dearth period — colonies rely on stored honey and pollen reserves (bee bread). Zone: 0 NU, 0 PU.

#### Spread Mechanics

Each day, up to 200 randomly selected tiles of each active flower type attempt to spread to one adjacent tile. Spread probability is determined by the current season's ranking. Flowers at field edges (within 2 tiles of grass zone boundary) have +50% spawn probability for edge-biased types (goldenrod, aster). Non-edge types get slightly reduced (-20%) edge spawning for naturalism.

#### Hive Starting State — Nuc Transfer

When a new hive is placed, it begins as a 5-frame nuc transferred into a 10-frame hive body. The middle 5 frames (indices 2–6) contain drawn comb with active brood (eggs, larvae, capped brood in an elliptical pattern). The outer 5 frames (indices 0, 1, 7, 8, 9) are empty foundation that the colony must draw out and incorporate over time. Starting population is ~10,000 bees with modest honey stores (~8 lbs).

#### Implementation: flower\_lifecycle\_manager.gd


| Attribute | Detail |
| --- | --- |
| Script | scripts/world/flower_lifecycle_manager.gd — extends Node2D, class_name FlowerLifecycleManager |
| Scene integration | Single node in World, replaces GardenBeds + WildflowerPatches + DandelionSpawner |
| Tile grid | 16×16 px tiles across 1600×900 grass zone = 100 cols × 56 rows (5,600 tiles) |
| Ranking roll | Weighted random at each season start; reproducible per-year RNG seed |
| Sprite rendering | Individual Sprite2D per tile, 5 discrete phase sprites per species (seed/sprout/growing/mature/withered). Textures at res://assets/sprites/world/forage/{species}_{phase}.png. Random rotation (±10°), scale (0.8–1.1×), flip for organic look. |
| ForageManager hook | get_forage_at(world_pos) returns { nectar, pollen } dict based on local 5×5 tile density sampling. Only MATURE tiles contribute. Values divided by NU_SCALE (250). |
| Signals | season_ranked(season_name, rank), flowers_updated(total_count) |


#### Glossary Additions — Systems Added After v1.2

The following terms were added in v1.4 to reflect systems developed after the original glossary was written.


| Term | Definition |
| --- | --- |
| Annual Roll | A seasonal determination roll using weighted factors (weather, prior season, random variance) to assign a quality outcome (POOR / AVERAGE / GOOD / EXCEPTIONAL) for key forage events such as dandelion bloom and goldenrod yield. |
| Base Season Humidity | The starting moisture percentage applied to harvested honey before capping fraction and curing adjustments. Varies by season: Spring 17.5%, Summer 16.5%, Fall 18.0%. |
| Brood-Bound | Congestion state in which nurse bees have filled available cells with brood to the point that the queen has insufficient room to lay. A precursor to swarming. |
| Colony Stress Modifier | A composite float (0.0–1.0) applied to the queen's daily egg budget, derived from forage availability (35%), congestion (25%), varroa load (20%), disease presence (15%), and queen quality (5%). See §3.8.A. |
| Community Standing | The in-game display name for the Reputation score (0–1,000). See §1.1. |
| Curing Bonus | A −0.8% moisture reduction applied to harvested honey when the Honey House structure is built, reflecting controlled temperature and airflow during the extraction process. |
| DCA (Drone Congregation Area) | An aerial zone where drones from multiple colonies gather to mate with virgin queens. DCA quality is a hidden property of each apiary location and directly affects queen mating success rates. See §3.4. |
| Feeding Residue Flag | A boolean set when supplemental syrup or fondant has been fed to a hive within the current season. Honey harvested while the flag is active cannot be labeled as varietal or premium. |
| Forage Pool | The shared weekly Nectar Unit resource bucket for a given apiary location. All hives at that location draw from it simultaneously. See §14. |
| Honey-Bound | Congestion state in which workers have filled the brood nest with capped honey, crowding the queen out of laying space. Triggers the colony_stress_modifier congestion penalty. |
| Moisture Content | The water percentage of harvested honey. Below 18.6% is shelf-stable; above causes fermentation over weeks to months. Below 17% is Premium grade. See §6.6. |
| Queen Acceptance | The process by which worker bees accept a newly introduced queen. Failed acceptance results in the queen being balled and killed. Risk is higher for queens introduced without a cage slow-release period. |
| Ropiness Test | A field diagnostic for American Foulbrood: insert a twig or matchstick into a suspect brood cell and withdraw slowly. AFB-infected larvae form a stretchy brown string >1 cm long. A positive result is reportable in many jurisdictions. |
| Supplier Tier | One of three quality/price categories for purchased bees: Budget (River Valley Bee Supply), Standard (Cedar Bend Feed & Supply), and Premium (Hartley's Apiary). See §6.3. |
| Uncapped Cell Fraction | The proportion of honey cells in a frame that are not yet wax-capped at harvest time. Each 10% of uncapped cells adds approximately +0.6% to honey moisture content. |


**PART V**

**Technical Architecture**

*Pseudocode specifications for the core simulation engine. Every mechanic described in Parts I–IV is backed by a script defined here.*

---

[< Map Locations](13-Map-Locations) | [Home](Home) | [Core Simulation Scripts >](15-Core-Simulation-Architecture)