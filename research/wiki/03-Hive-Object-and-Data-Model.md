[< Player Tasks by Season](02-Player-Tasks-by-Season) | [Home](Home) | [Game Overview >](04-Game-Overview)

---

# Hive Object & Data Model


Each hive in the apiary is an independent object with its own state, colony, and equipment. No two hives are identical. A hive's output — honey produced, colony growth, overwinter survival — is the emergent result of all its interlocking variables.

### 3.1 Hive-Level Properties


| Hive ID | Unique identifier. Player can assign a custom name or tag color per hive. |
| --- | --- |
| Location | Which apiary the hive belongs to. Forage radius and local flora affect performance. |
| Hive Type | Langstroth (default 8- or 10-frame). Warré and top-bar unlockable. |
| Hive Bodies | Count of deep or medium boxes. Determines total brood space. |
| Supers | Count of shallow honey boxes above the brood nest. |
| Frame Count | Frames per box. Affects comb space and colony expansion rate. |
| Entrance Size | Full, reduced, or mouse-guard. Affects ventilation and pest access. |
| Insulation | None, winter wrap, moisture quilt. Affects overwinter survival probability. |
| Equipment Condition | 0–100. Degrades over time. Below 50 begins affecting colony performance. |
| Overall Health Score | Hidden composite 0–100. Player never sees this number directly. |


#### Equipment Condition — Degradation and Impact

Equipment condition degrades weekly from UV exposure, moisture, propolis accumulation, and physical use. The rate varies based on storage and care.


| Situation | Condition Lost per Week |
| --- | --- |
| Equipment stored in shed, painted and maintained | −1 |
| Equipment in active use, maintained but unsheltered | −2 |
| Equipment without protective paint or treatment | −4 |
| Equipment stored near standing water or high humidity | −3 |
| Equipment in shed passively restores at +1/week (while not in use) | +1 |


| Condition Range | Visual | Colony Impact |
| --- | --- | --- |
| 100–80 | No visible wear | None |
| 79–50 | Weathered, minor paint loss | Cosmetic only — warning indicator appears at 60 |
| 49–30 | Warped wood, gaps visible | −10% honey production; +5% small hive beetle entry risk |
| 29–15 | Significant structural wear | −20% honey production; +10% pest risk; −5% overwinter survival probability |
| 14–0 | Visibly failing | −35% honey production; +20% pest risk; colony_stress_modifier penalty −0.10 |


Repair options: **Basic repair kit** ($25, 3 energy, restores +20 condition). **Full refurbishment** ($60, 8 energy, restores to 75 condition). **Craftable repair pack** (beeswax + wood scraps, Level 3 unlock, free materials cost, 5 energy, restores to 65 condition).

### 3.2 The Queen

The queen is the biological engine of the hive. Every measurable colony outcome traces back to her quality.

Queen Properties


| Species | Determines base temperament, growth pattern, winter behavior, and varroa tolerance. See species table below. |
| --- | --- |
| Grade | S / A / B / C / D / F. Represents overall genetic quality and laying ability. Degrades naturally over 2–3 years. |
| Age | Tracked in seasons. Laying rate begins to decline after Year 2. Player may choose to replace a still-functional but aging queen. |
| Laying Rate | Eggs per day. Derived from species base rate modified by grade, age, season, and colony health. |
| Temperament | Affects how easy inspections are. Defensive colonies require more smoke and experience to inspect safely. |
| Status | Active / Failing / Missing / Virgin / Cell Present. Determined by brood pattern evidence during inspections. |


Queen Species Comparison


| Species | Strengths | Weaknesses |
| --- | --- | --- |
| Italian | High honey production, gentle, excellent brood pattern, great for beginners | Heavy spring buildup can deplete stores early; less varroa-resistant |
| Carniolan | Frugal in winter, explosive spring buildup, very gentle, good comb builders | Prone to swarming if space isn't managed proactively |
| Russian | Strong natural varroa resistance, hardy in cold climates | More defensive, slower spring buildup, harder to source |
| Buckfast | Disease-resistant, calm, consistent honey production | Unlockable mid-game; more expensive |
| Caucasian | Excellent foragers, long tongues reach more flower types | Very slow spring buildup; susceptible to nosema |


Queen Grade Effects


| Grade | Laying Rate Modifier | Effect on Colony |
| --- | --- | --- |
| S | +25% above base | Exceptional brood pattern, fast population growth, high honey yield |
| A | +10% above base | Solid, reliable colony. Ideal working hive. |
| B | Base rate | Average performance. Functional but room for improvement. |
| C | -15% below base | Spotty brood, slower growth, slightly lower honey output. |
| D | -35% below base | Irregular laying, visible brood gaps, colony at risk of decline. |
| F | Failing / None | Queen is failing or has stopped laying. Immediate replacement needed. |


*Design Note: Queen grade is not visible to the player as a letter. It is inferred from brood pattern observations during inspections. A spotty pattern, eggs missing from cells, and declining population are the signals. Players who understand this will grade their own queens intuitively.*

#### Queen Age — Laying Rate Decline by Year

Queen performance follows a biological curve. The player never sees the multiplier directly — they observe its effects through brood pattern changes and declining population counts during inspections.


| Queen Age | Laying Rate Multiplier | Observable Signal |
| --- | --- | --- |
| Year 1 | ×1.00 | Establishing; brood pattern solid but not yet peak |
| Year 2 | ×1.05 (peak) | Peak performance. Most productive season. Brood solid, population at maximum. |
| Year 3 | ×0.85 | Slight decline. Observant players may notice marginally smaller brood arc. |
| Year 4 | ×0.65 | Visible decline. Spotty frames begin appearing. Most beekeepers replace at this stage. |
| Year 5 | ×0.40 | Significant failure visible on inspection. Population decline accelerating. Replacement urgent. |
| Year 6+ | ×0.20 | Queen effectively failing. May stop laying entirely. Emergency status. |


*Design Note: Grade also degrades with age. An S-grade queen degrades to A after 18 months; A degrades to B after 24 months; each subsequent grade drops on a 12-month cycle from Year 3 onward. The age multiplier and grade degradation stack — a Year 4 queen who started at B-grade is now a C with a ×0.65 multiplier, meaning her effective output is significantly below a fresh B.*

### 3.3 Population Simulation

Colony population is simulated at the individual bee level. Every bee in the hive is tracked through its complete biological lifecycle — from egg through death. The total live population at any moment is the emergent sum of every bee currently alive across all lifecycle stages. This is the core algorithm being developed externally and will drive every population-dependent mechanic in the game.

*Design Note: This section documents the lifecycle model the algorithm must implement. The algorithm handles the tick-by-tick math; this GDD defines the stages, durations, transitions, and mortality conditions the algorithm is responsible for.*

### 3.3.1 The Worker Bee Lifecycle

Every fertilized egg laid by the queen enters the pipeline and advances through the following stages. Durations are in real bee biology days, which map to in-game time ticks defined by the time system.


| Stage | Duration (days) | Description |
| --- | --- | --- |
| Egg | 3 days | Laid by the queen into a clean cell, one per cell. Standing upright at the base. Visible only on close inspection — experience level affects player detection probability. No mortality risk during this stage under normal conditions. |
| Open Larva | 6 days | Egg hatches. Larva is fed by nurse bees — first royal jelly, then a mix of pollen and honey (worker jelly). Visible as a curled white grub in an open cell. Larva grows rapidly, roughly doubling in mass each day. Feeding rate is dependent on nurse bee population. |
| Capped Larva | 2 days | Workers cap the cell with beeswax. Larva finishes feeding, spins a cocoon, and prepares for metamorphosis. Cappings are flat to slightly domed and light tan. Darker or sunken caps are an abnormal indicator. |
| Pupa | 10 days | Metamorphosis occurs inside the capped cell. Adult bee develops from larva. Eyes, wings, and body segments form. Total capped duration (capped larva + pupa) = 12 days, which is what the player observes as 'capped brood' during inspection. |
| Newly Hatched | 1–2 days | Adult bee chews through the capping and emerges. Soft, pale, fuzzy. Not yet capable of any specialized task. Immediately begins receiving food from nurse bees while her own glands develop. |
| Nurse Bee | ~12 days | Hypopharyngeal glands mature. The bee's primary role becomes feeding larvae, capping cells, and maintaining the brood nest. Nurse bees do not leave the hive. They are the colony's primary brood-rearing resource. |
| Transition / House Bee | ~9 days | The bee transitions through additional roles: wax secretion and comb building, nectar receiving and processing, propolis collection, guarding the entrance. Each role corresponds to a specific gland or organ maturation stage. |
| Forager | Variable | The bee's final life stage. She leaves the hive to collect nectar, pollen, water, and propolis. Foragers fly 2–5 miles per trip, making multiple trips per day. Forager lifespan is highly variable and is the primary population mortality driver in summer. |
| Death | See below | All bees die. The cause and timing determine how mortality is calculated in the algorithm. |


### 3.3.2 Lifespan & Mortality

Bee lifespan varies dramatically by season and role. The algorithm tracks each bee's age in days and applies mortality probability based on stage, season, and environmental conditions.

Natural Lifespan by Type


| Bee Type | Expected Lifespan | Notes |
| --- | --- | --- |
| Summer Worker (total) | ~35–45 days from egg | Egg (3) + Larva (6) + Capped (12) + Post-emergence adult = ~14–24 days as an adult bee. Forager burnout is the terminal event. |
| Winter Worker (total) | ~140–180 days from egg | Winter bees have enlarged fat bodies (vitellogenin reserves). They do not forage and conserve energy by clustering. Their extended life is what allows the colony to survive winter and raise the first spring brood. |
| Nurse Bee phase | ~12 days in this role | Duration of active brood-feeding before transitioning to house bee roles. |
| Forager phase | ~15–38 days | Highly variable. Ends with death — usually from mechanical wear (wing damage), predation, or failure to return. Forager death is not a discrete event; it is a daily probability that increases with age. |
| Queen | 1–5 years | Tracked separately. See Section 3.2. |
| Drone | ~55 days (spring/summer) | Expelled from the hive in fall and die of starvation/cold. If mating occurs first, the drone dies immediately upon mating. |


Mortality Sources & Risk Rates

The algorithm applies daily mortality probability to each bee based on her current stage and active environmental conditions. These are the inputs the algorithm must consume.


| Mortality Source | Affected Stage(s) | Algorithm Input |
| --- | --- | --- |
| Natural forager senescence | Forager | Probability increases daily after day 10 of forager phase. Starts low (~1% /day), rises to ~8% /day by day 30. Reflects wing wear and metabolic exhaustion. |
| Forager field loss | Forager | A flat daily base risk (~1–2% /day) representing predation, weather, disorientation, and pesticide exposure. Multiplied by the active pesticide event modifier if a pesticide event is firing. |
| Brood chilling | Egg, Open Larva, Capped Larva | Triggered when nurse bee population falls below the ratio needed to maintain brood nest temperature (roughly 1 nurse per 3–4 brood cells). Mortality rate climbs sharply. Also triggered by cold snap weather events if the cluster is small. |
| Varroa damage | Capped Larva, Pupa, Newly Hatched | Mites reproducing in capped cells cause direct larval mortality and adult defects. Algorithm input: current mite count per 100 bees → converts to a per-cell mortality modifier during capping stage. |
| Disease (AFB, EFB, etc.) | Open Larva, Capped Larva | Disease flag on the hive activates a per-cell daily mortality rate specific to each disease. AFB spreads cell-to-cell; algorithm must model contagion between adjacent cells. |
| Starvation | Open Larva, Adult (all) | Triggered when honey stores fall below a minimum threshold. Larvae are abandoned by nurses first. Adults die in order of role — foragers first, then house bees, then nurses, then cluster bees last. |
| Pesticide event | Forager | When a pesticide event fires (Harmon farm), forager field loss multiplier is raised 5–10× for the event duration (1–3 days). Player sees mass dead bees at the entrance. |
| Predation / environment | Forager | Ambient daily risk. Minor. Represents birds, spiders, wasps, and general hazard. Not player-controllable. |
| Winter cluster cold | Adult (all, winter) | If cluster size falls below the minimum thermogenic threshold AND external temperature is below freezing, daily mortality rate increases across the whole cluster. Algorithm input: current total live adult population + insulation modifier + temperature. |


*Design Note: The algorithm is responsible for applying these mortality rates at the correct cadence. The GDD does not prescribe tick rate — that is an implementation decision. What matters is that each bee ages correctly, each mortality source fires under the right conditions, and the population the player observes during inspection is the live output of the simulation, not an abstraction.*

#### Forager Mortality — Exact Formula

The daily mortality probability for a forager of age D days in the forager phase follows a base rate plus an accelerating age penalty. This reflects the biological reality of wing wear and metabolic exhaustion documented in bee research (Visscher & Dukas, 1997).


| Component | Formula |
| --- | --- |
| Base daily mortality | base_p(D) = 0.010 + (0.0025 × max(0, D − 8))² |
| Approximate age 1–8 | ~1.0% / day |
| Approximate age 15 | ~2.4% / day |
| Approximate age 20 | ~6.4% / day |
| Approximate age 25 | ~13.6% / day (colony rarely retains foragers past this age) |


The base rate is multiplied by a season modifier and any active environmental modifiers:


| Modifier | Multiplier |
| --- | --- |
| Quickening (early spring, short flights) | ×0.70 |
| Greening (spring buildup) | ×0.80 |
| Wide-Clover / Full-Earth (summer peak) | ×1.00 (baseline) |
| High-Sun (peak heat, long flights) | ×1.30 |
| Reaping (fall, shorter days) | ×0.90 |
| Rain or cold day — no flying | ×0.00 (no field mortality) |
| Dearth period (long foraging trips) | ×1.50 |
| Pesticide event (Harmon spray days) | ×8.00 |
| Strong local forage within 1 mile | ×0.85 |
| River Bottom location (higher predator pressure) | ×1.10 |


Final daily mortality = base\_p(D) × season\_modifier × environmental\_modifier, clamped to [0.001, 0.95].

### 3.3.3 Role Distribution & Colony Function

The population simulation must track not just total bee count but the distribution of bees across lifecycle stages, because different stages perform different colony functions. A colony with 40,000 bees is very different depending on how many of those are nurses versus foragers versus newly hatched.


| Role | Colony Function | What Happens When Population in This Role Is Low |
| --- | --- | --- |
| Nurse Bees | Feed open larvae royal jelly and worker jelly. Maintain brood nest temperature. Critical for colony growth. | Larvae are underfed or abandoned. Brood starvation event fires. Colony growth slows or reverses even if the queen is laying at full rate. |
| House Bees | Build comb, process nectar into honey, cap cells, make propolis, receive nectar from foragers. | Nectar processing bottleneck. Incoming forage sits unprocessed. Honey production rate drops even if foragers are bringing in full loads. |
| Guard Bees | Defend the entrance from robbers and predators. | Robbing vulnerability increases. During a nectar dearth, a colony with few guards is disproportionately targeted by robbers from other hives. |
| Foragers | Collect nectar, pollen, water, and propolis. The colony's primary input mechanism. | Nectar and pollen input drops. Honey stores decline. Brood pollen deficiency risk increases. Colony enters dearth conditions even if forage is available. |
| Winter Cluster | Form a tight cluster to generate and conserve heat. Consume stores to fuel the cluster. | Heat generation insufficient. Colony death risk in freezing temperatures. Minimum cluster size is a hard threshold — below it, survival probability drops sharply. |


Approximate Role Distribution — Healthy Summer Colony (~50,000 bees)


| Role / Stage | Approximate Count | % of Total |
| --- | --- | --- |
| Eggs (3 days) | ~4,500 | ~9% |
| Open Larvae (6 days) | ~9,000 | ~18% |
| Capped Brood (12 days) | ~18,000 | ~36% |
| Newly Hatched (1–2 days) | ~1,500 | ~3% |
| Nurse Bees (~12 days) | ~7,500 | ~15% |
| House / Transition Bees (~9 days) | ~5,000 | ~10% |
| Foragers (variable) | ~4,500 | ~9% |


Note: capped brood makes up the largest single segment (~36%) at any given time in a healthy summer colony. This is why varroa — which reproduces exclusively in capped brood — is so destructive. It attacks the largest and most vulnerable population segment.

Winter Population Transition

The transition from summer bees to winter bees is not a mode switch — it is a gradual biological shift driven by day length and the queen's laying reduction. The algorithm must model this correctly because the colony that survives winter is a fundamentally different population than the one that harvested honey in August.


| Late Summer (Aug–Sept) | Queen begins laying the special long-lived winter bees. These bees develop with elevated vitellogenin (fat body protein) because they are raised on late-season pollen that is nutritionally richer and because mite loads are lower after treatment. Duration of life for these bees: ~120–180 days vs. ~35 for summer foragers. |
| --- | --- |
| Full-Earth – Reaping | Summer bee population is dying out at its natural rate. Winter bee population is accumulating. If mite treatment was timely, the winter bees are healthy. If mites were high during their capping stage (Aug–Sept), many winter bees are damaged and their lifespan is shortened — the hidden cause of many winter losses. |
| Early Winter | The colony is now almost entirely winter bees. The queen reduces or stops laying. The cluster forms. Population is at its annual minimum: typically 10,000–20,000 bees in a healthy Cedar Bend colony. |
| Late Winter | Stored pollen and honey are being consumed by the cluster. If a pollen source appears (a warm day, some stored pollen), the queen may begin laying early brood. These early broods stress the cluster's food stores but are necessary to build spring population in time for the first flow. |
| Spring | The exponential growth phase begins. Winter bees die as new spring bees hatch. The population curve is the result of queen laying rate vs. winter bee death rate — there is a brief period where the colony is still shrinking even as the queen is laying heavily. This is a vulnerable window. |


### 3.3.4 What the Player Sees

The player never looks at a population spreadsheet. They observe the population simulation's output through the frame inspection view and hive-level behavior signals. The algorithm's job is to produce a realistic population state; the rendering system's job is to make that state legible.


| What the Algorithm Produces | What the Player Observes | What It Means |
| --- | --- | --- |
| Total egg count across frames | Tiny white slivers in cells during inspection. Density reflects laying rate. | Queen health and activity level |
| Total open larva count | White grubs of varying sizes in uncapped cells. Larger = older larva. | Colony growth momentum |
| Total capped brood count + distribution | Tan capped cells forming the brood arc pattern on frames. | Queen grade, pattern quality, health |
| Nurse bee population relative to brood | How attentively bees cover the brood frames. Thin coverage = low nurse ratio. | Brood rearing capacity |
| Forager population | Entrance traffic. Busy entrance with bees returning with pollen = strong forager population. | Forage output, colony strength |
| Total adult population | How many frames of bees are covered. A frame 'of bees' = roughly 2,500–3,000 bees. | Overall colony size at a glance |
| Abnormal mortality (pesticide, starvation, disease) | Dead bees at the entrance. Bees on the ground near the hive. Crawling bees. | Distress signal — requires investigation |
| Winter cluster size | In winter, a brief visual of a tight cluster on frames. Cluster diameter indicates population. | Overwinter survival probability |


*Design Note: The frames-of-bees metric is the player's practical gauge of colony size. A single deep box covered by bees on both sides of every frame is roughly 50,000–60,000 bees — a strong summer colony. Three or four frames of bees in winter is a normal healthy cluster of ~10,000–15,000. New players learn this instinctively through repeated inspections.*

### 3.4 Drones

Drones are male bees raised from unfertilized eggs. They are tracked by the population simulation as a separate cohort within the hive — not mixed into the worker lifecycle pipeline.


| Development | Egg (3 days) → Open Larva (6.5 days) → Capped Pupa (14.5 days) → Adult. Total egg-to-emergence: 24 days. Notably longer than workers (21 days). Drone cells are visibly larger with distinctively domed cappings — the player can identify them on frames. |
| --- | --- |
| Seasonal Presence | The queen begins laying drone eggs in spring as colony population builds. Drone population peaks in late spring/early summer when swarming and queen mating opportunities are highest. In fall, workers expel drones from the hive as a resource conservation measure — they cannot survive winter. |
| Role | Drones do not forage, build comb, or perform hive tasks. Their sole biological purpose is to mate with virgin queens. They leave the hive daily to congregate at Drone Congregation Areas (DCAs) in search of queens. |
| Quality & Effect | Drone genetic quality is affected by the mother queen's grade and pest load. High-quality drones from a healthy hive passively improve the mating quality of any virgin queens raised nearby — relevant for the queen rearing mechanic. |
| Over-drone Signal | If the drone count significantly exceeds the species-normal proportion (~10–15% of adult population in spring), this is a diagnostic indicator. Possible causes: the queen has shifted to laying mostly unfertilized eggs (failing), or a laying worker situation has developed. The player sees this as an unusual number of large-celled, domed-cap brood cells on inspection. |
| Mortality | Drones die when expelled in fall (starvation at hive entrance), immediately after successful mating, or from the same environmental risks as foragers when flying. The algorithm tracks drone count as a separate population cohort with its own aging and mortality. |


#### Drone Congregation Area (DCA) — Game Mechanic

Drone Congregation Areas are invisible aerial zones where drones from many colonies gather to mate with virgin queens. In Smoke & Honey, DCA quality is a hidden property of each apiary location. The player does not see the DCA value directly — they observe it through mating success rates when raising queens.


| Location | DCA Quality | Base Mating Success Rate | Notes |
| --- | --- | --- | --- |
| Home Property | Moderate | 65% | Suburban/agricultural area. Adequate but not ideal. |
| County Road | Poor | 50% | Road traffic and open exposure discourage congregation. |
| Timber & Woodlot | High | 80% | Sheltered valley edges create natural congregation zones. |
| Harmon Farm | Moderate | 65% | Open fields with wind exposure reduce quality. |
| River Bottom | Very High | 85% | River valley thermals and natural shelter create ideal conditions. Best mating location. |


Additional mating success modifiers: placing mating nucs at Timber or River Bottom (+10% if not at home). Good drone population within the apiary (+5% if drone count is healthy). Calm weather forecast day (+5%). Instrumental Insemination (Level 5 unlock) bypasses DCA quality entirely.

### 3.5 Hive Health System

Hive Health is the central hidden variable of the simulation. It is never shown as a number. The player must learn to read the evidence.

Health Indicators & What They Reveal


| Indicator | What the Player Observes | What It Signals |
| --- | --- | --- |
| Queen Egg Production | Eggs visible in cells; consistent vs. patchy | Queen grade, age, and health |
| Brood Pattern | Solid capped brood vs. holes, discoloration, sunken caps | Queen quality, disease presence, chilled brood |
| Brood Color/Smell | Normal: creamy white, mild smell. Diseased: brown, foul | AFB, EFB, sacbrood — each has a distinct signature |
| Population Density | Frame coverage by bees; does population match the season? | Overall colony strength and queen performance |
| Honey Stores | Frame weight, capping percentage | Nutritional status; overwinter readiness |
| Pollen Stores | Multi-colored pollen in cells near brood | Nutritional diversity; nurse bee capacity |
| Bee Behavior | Calm, defensive, fanning, washboarding, robbing | Colony stress, nectar dearth, queen presence |
| Mite Count | Requires sugar roll or sticky board — a deliberate action | Varroa load; treatment threshold |
| Hive Weight | Lifting or scale reading (tool unlock) | Stores level; useful in fall and winter |


*Design Note: The player builds an intuition over time. Early-game inspections surface many observations with no clear meaning. As the player progresses, they start connecting patterns — e.g., spotty brood + declining population + high mite count on the sticky board = varroa damage. This is the core educational loop.*

Health Score Composition (Internal)

For the game engine's internal calculations, the hidden Health Score is derived from the live outputs of the population simulation and other hive state variables. These weights are never shown to the player. All inputs correspond directly to fields in the State Snapshot produced by the daily tick (see Section 3.8.A).


| Queen Quality (30%) | queen.grade_modifier × queen.age_modifier × queen.presence_flag (0 if missing). The single largest factor — a bad queen degrades every downstream metric. |
| --- | --- |
| Nurse-to-Brood Ratio (15%) | nurse_bee_count ÷ open_larva_count from the State Snapshot. Below ~1:4 triggers brood feeding deficiency. A direct daily tick output. |
| Forager Population (10%) | forager_count relative to expected for current season and total adult population. Low forager count reduces honey production regardless of available forage. |
| Total Adult Population vs. Curve (5%) | Actual adult bee count compared to expected population curve for current season and queen laying rate. Colony running significantly below curve is a stress signal. |
| Pest Load (20%) | Varroa mite count per 100 bees, tracheal mite status, other active pest flags. Directly degrades capped brood survival in the tick's mortality check. |
| Disease Status (5%) | Active disease flags and severity. Each disease applies a multiplier to brood mortality in the population simulation. |
| Nutritional Status (10%) | pollen_cell_count relative to open_larva_count (pollen deficiency risk) + honey_cell_count relative to season minimum threshold. |
| Congestion State (5%) | congestion_state enum from State Snapshot. NORMAL = no penalty. BROOD_BOUND = −10% to laying efficiency. HONEY_BOUND = −5%, swarm risk elevated. FULLY_CONGESTED = −20%. See Section 3.8.B. |


*Design Note: The congestion state input closes the feedback loop between the spatial frame simulation and the overall hive health score. A brood-bound hive is genuinely less healthy because the queen's laying rate is suppressed. The cascade is mechanically real: queen quality → laying rate → egg pipeline → nurse population → brood rearing capacity → next generation population.*

### 3.6 Pests & Disease

Pests and disease are the primary ongoing threats to colony survival. Each has distinct detection methods, treatment options, and consequences if untreated.

Varroa Mites

Varroa destructor is the single greatest threat to managed honeybees worldwide. In Smoke & Honey it is the primary ongoing challenge for experienced players.


| Detection | Sugar roll (counts mites per 100 bees), alcohol wash (more accurate, kills sample), sticky board count (passive weekly monitoring) |
| --- | --- |
| Threshold | Treatment recommended above 2–3 mites per 100 bees in summer; lower in fall before winter bees are raised |
| Spread | Mites reproduce in capped brood. High mite load damages developing bees, causes deformed wings, and transmits viruses |
| Treatment Options | Oxalic acid (broodless period, high efficacy), formic acid pads (works on capped brood), synthetic strips (longer treatment window), thymol (temperature-dependent) |
| Treatment Timing | Critical in late summer/early fall to protect the long-lived winter bees. Treating too late is a common cause of winter loss. |
| Resistance Risk | Repeated use of the same treatment type over multiple seasons may reduce efficacy. Players should rotate. |


Other Pests


| Pest | Detection | Management |
| --- | --- | --- |
| Tracheal Mites | Difficult — identified by K-wing (dislocated wings) and unexplained winter loss. Confirmed by microscopy (lab send-off). | Grease patties (vegetable shortening + sugar), some essential oil treatments. |
| Small Hive Beetles | Visual during inspection — small dark beetles run from light, larvae in honey. | Beetle traps, strong colony populations, reducing hiding spaces. |
| Wax Moths | Larvae trails and webbing in comb, especially in weak or dead hives. | Maintaining strong colonies is primary defense. Freeze frames to kill eggs. |
| Ants | Trail observed at hive base. Minor nuisance but can stress colonies. | Stand legs in water/oil traps, cinnamon barrier. |
| Mice | Evidence in winter: gnawed comb, nesting material, droppings. | Mouse guard installed in fall prevents entry. |


Diseases


| Disease | Symptoms | Response |
| --- | --- | --- |
| American Foulbrood (AFB) | Sunken, perforated caps; rope test (string stretches from cell); foul smell. Highly contagious. | Mandatory reporting in many regions. Infected equipment must be destroyed or irradiated. No treatment — prevention via hygiene and inspection. |
| European Foulbrood (EFB) | Twisted, discolored larvae in uncapped cells; sour smell. Less severe than AFB. | Improve nutrition, requeen. Antibiotic treatment in some regions. |
| Chalkbrood | Mummified chalk-white larvae on the landing board or in cells. | Improve ventilation, reduce moisture. Often self-resolves in strong colonies. |
| Sacbrood | Sac-like larvae with fluid under the skin; easily removed from cells. | Usually self-limiting. Requeen if severe or persistent. |
| Nosema | Dysentery at hive entrance, weak spring buildup, crawling bees. | Reduce stress. Fumagillin treatment (where legal). Clean old comb. |
| Deformed Wing Virus (DWV) | Bees with stunted, crumpled wings near hive entrance. | Primarily a symptom of varroa infestation. Control varroa to control DWV. |


#### Disease Contagion — Spread Mechanics

Two diseases have active cell-to-cell or hive-to-hive contagion that must be modeled in the simulation. Others are treated as hive-level flags that affect the colony without spatial spread.


| Disease | Spread Rate | Detection | Timeline |
| --- | --- | --- | --- |
| American Foulbrood (AFB) | 8% chance per day per infected cell spreading to an adjacent cell | Visible to player at 3+ infected cells; detection probability: Level 1 = 40%, Level 3 = 75%, Level 5 = 95% per inspection | Player has ~10–14 game days from first detectable cells before colony becomes unrecoverable (>25% brood infected) |
| European Foulbrood (EFB) | 4% per infected cell per day. 30% chance of natural recovery with strong forage and healthy queen. | Open larvae turning brown/twisted; visible during inspection at Level 2+ | Colony lost threshold: 40% larvae infected. Responds to 5-day antibiotic treatment. |
| Sacbrood Virus | 3% per infected cell per day. Usually self-limiting. | Sac-shaped dead larvae visible on inspection | Colonies typically recover naturally, especially with requeening. Rarely fatal alone. |
| Nosema | No cell-to-cell contagion. Affects individual bees through fecal contact in winter cluster. | Dysentery streaking on the front of the hive (spring sign) | Chronic; reduces spring buildup −15% per infected winter season. Treatable. |


Between-hive spread: AFB can transfer via shared equipment (15% transfer chance if a hive tool used on an AFB hive is used on another without cleaning). Drifting bees contribute a 2% daily transfer risk between adjacent hives in the same apiary. Purchasing a full hive from an unknown source carries a 5% chance of introducing AFB.

*Design Note: AFB destruction is the game's most dramatic consequence event. Burning the equipment is historically accurate and feels appropriately weighty. The decision — burn now and take the equipment loss, or treat with antibiotics (cheaper but doesn't cure spores, makes honey unsalable for 2 weeks, −5 reputation) — is a genuine moral and strategic dilemma. New players will often choose antibiotics. Experienced players will burn.*

### 3.7 Hive Types


| Hive Type | Description | Game Properties |
| --- | --- | --- |
| Langstroth (Standard) | Removable frame hive. Most common worldwide. The default hive type. | Full inspection access. Most equipment compatible. Highest honey yield potential. |
| Langstroth (8-frame) | Narrower version of the standard 10-frame Langstroth. | Lighter boxes for harvesting. Slightly less capacity per super. Easier for solo beekeepers. |
| Warré | Vertical top-bar hive. Managed with minimal intervention philosophy. | Inspections are less detailed. Lower honey yield but lower management burden. Unlocked mid-game. |
| Top-Bar | Horizontal hive with top bars instead of full frames. Natural comb. | Unique honey profile. Comb honey only (no extractor). Unlocked via mentor quest. |


### 3.8 Frame Inspection & Queen Laying Patterns

Frame-by-frame inspection is the core interactive mechanic of Smoke & Honey. This is where the player gets their hands dirty. Rather than reading a status screen, they pull frames one at a time and interpret what they see — just as a real beekeeper does. The queen is evaluated entirely through the evidence she leaves behind: her eggs, her brood, and her pattern across the frames.

Deep Body Langstroth Frame — Cell Count Reference

A standard deep Langstroth frame is the game's fundamental unit of brood space. Understanding its capacity is the mathematical foundation of the entire inspection system.


| Frame Dimensions | Standard deep Langstroth: approximately 19" wide x 9 1/4" tall |
| --- | --- |
| Cells per Side | ~3,500 cells on each drawn comb face |
| Total Cells per Frame | ~7,000 cells (both sides) |
| Frames per Deep Box | 10 frames (standard configuration) |
| Total Cells per Deep Box | ~70,000 cells |
| Practical Brood Area | Not all cells are used for brood simultaneously. The queen lays in an oval or elliptical pattern that typically covers the central 60–80% of frames. Outer cells and frame corners are usually used for honey and pollen storage. |
| Maximum Brood Nest | A fully active queen at peak summer may have brood across 7–8 frames of a 10-frame box, covering roughly 60–70% of available cells on those frames — approximately 29,000–33,000 actively occupied brood cells. |


*Design Note: These numbers ground the inspection visual. When the player pulls a frame and sees a solid capped brood pattern covering ~60% of the face, that is ~2,100 capped cells — a healthy and expected sight on a center frame in summer. The game renders this visually but the design team should have these numbers internalized for calibrating what 'full', 'adequate', and 'sparse' look like on screen.*

The Brood Nest Layout

A healthy colony organizes its brood nest in a predictable way across the 10 frames. Understanding this layout is the first thing the player learns to read.


| Frame Position | Expected Content | What It Means If Different |
| --- | --- | --- |
| Frames 1–2 (outer) | Honey capped, some pollen. Few or no bees. | Brood in outer frames = colony outgrowing the box (add space). No stores in outer frames = starvation risk. |
| Frames 3–4 (transition) | Mixed: honey arch at top, pollen band below honey, brood beginning. | Empty transition frames = small or contracting cluster. |
| Frames 5–7 (core brood) | Dense brood — mostly capped worker brood, eggs and young larvae in center cells, honey/pollen arc at top corners. | Spotty pattern here is the most diagnostic signal for queen problems or disease. |
| Frames 8–9 (transition) | Mirror of frames 3–4. Brood thinning, more honey and pollen. | Brood extending into frame 9 = strong, growing colony. Absence of brood = contracting. |
| Frame 10 (outer) | Primarily honey. Mirror of frame 1. | Same as frame 1. |


*Design Note: The player doesn't need to know they're looking at 'frame 7'. The visual language does the work: center frames look dense and warm (bees clustered, capped brood filling the face), outer frames look golden and crystalline (capped honey). The contrast is immediately readable even to a new player.*

Reading Eggs — The Most Important Skill

Eggs are the real-time readout of queen activity. A worker bee egg takes 3 days to hatch. If the player sees eggs, the queen was present and laying within the last 3 days. If there are no eggs but young larvae exist, she was present within the last week. If only capped brood remains — no eggs, no young larvae — she has been gone for at least a week.


| What Eggs Look Like | Tiny white slivers standing upright in the base of a cell, like a grain of rice. One egg per cell in a healthy hive. Hard to see — new players may miss them. Experience level affects detection probability. |
| --- | --- |
| One Egg Per Cell | Normal. Queen is active and laying fertilized eggs. |
| Multiple Eggs Per Cell | Laying worker. The queen is gone, has been gone long enough for workers to begin laying. Cells may have 2–5 eggs placed on the cell wall rather than the base. This is a serious condition. |
| No Eggs, Young Larvae Present | Queen was laying 3–7 days ago. She may still be present. Not yet an emergency — inspect again in 4–5 days. |
| No Eggs, Capped Brood Only | Queen has not laid in 7–10+ days. Could be: natural swarm, supersedure, or queen loss. Requires follow-up inspection. |
| Eggs in Irregular Pattern | Queen is laying but skipping cells. May indicate early failing, disease disruption, or pest pressure on brood cells. |


The Brood Arc — Understanding the Pattern

A queen does not lay randomly. She moves across the frame in an arc, filling the center first and working outward. This produces the characteristic elliptical brood pattern — the single most important diagnostic picture in the hive.

The brood arc consists of concentric zones from the center outward:

Center zone: freshest eggs and youngest open larvae — the queen was here most recently

Middle zone: older larvae, capped worker brood — 6–12 days old

Outer ring: capped drone brood (larger cells, domed caps) in corners and edges where present

Outermost border: pollen band, then honey arc at the very top corners

The player learns to read this arc intuitively. A compact, dense oval of solid capped brood surrounded by a clean pollen and honey border = a queen performing at her potential. A fragmented, irregular scatter of capped cells with gaps, sunken caps, and missing patches = something is wrong.

Brood Pattern Quality Scale

Brood pattern quality is how the game communicates queen grade and hive health without showing a number. The player evaluates pattern quality visually during inspection. Each level has distinct visual characteristics.


| Pattern Quality | Visual Description | Diagnostic Meaning |
| --- | --- | --- |
| Solid (Exceptional) | Dense, unbroken oval of capped brood. 85–95% cell fill rate across the brood arc. Cappings are uniform, slightly domed, and light tan. Almost no empty cells within the brood zone. | Queen grade S or A. Colony is healthy, well-nourished, low pest load. Ideal. |
| Good (Normal) | Mostly solid oval. 70–85% cell fill. Occasional empty cell scattered within the brood zone — normal for any queen. Cappings uniform in color. | Queen grade A or B. Colony is healthy. No intervention needed. |
| Acceptable (Minor Issues) | 60–70% fill. Noticeable but not alarming gaps within the arc. Some cells may have been recapped (slightly darker than surrounding cells). Pattern is still recognizably oval. | Queen grade B or C. May indicate early aging, minor varroa pressure, or mild nutrition stress. Monitor closely. |
| Spotty (Concerning) | 40–60% fill. Irregular scatter of capped brood with many empty cells interspersed. The oval shape is hard to discern. Some cappings may be sunken or perforated. | Queen grade C or D. Possible causes: failing queen, early disease (chalkbrood, EFB, sacbrood), significant varroa damage, chilled brood from cold snap. Investigation required. |
| Scattered (Serious) | Below 40% fill. No clear pattern. Brood scattered across the frame with little organization. Mix of capped and open cells with no arc structure. May include unusual cappings. | Queen grade D or F. Immediate concern. Possible AFB (check for ropiness), severe disease, queen failure, or laying worker. Player must act. |
| Empty (Critical) | No capped brood. May have eggs or young larvae (queen recently lost) or nothing at all (long-term queenless). Any remaining brood is aging out. | Queenless or drone layer. Immediate action required. Colony will collapse within 4–6 weeks without intervention. |


*Design Note: The game renders pattern quality as a visual — the player sees the frame, not a label. But internally, each pattern state maps to a range of queen grade and hive health values. The label exists in the design for calibration. Darlene's inspection tips in Year 1 use these exact descriptors to teach the player the vocabulary.*

Queen Grade to Laying Behavior Correlation

Each combination of queen species and grade produces a distinct and predictable laying behavior. This table is the master reference for how the engine generates the frame visuals the player sees during inspection.

Base laying rates assume a mid-summer peak with adequate forage, healthy workers, and no pest pressure. All rates are eggs per day. The active brood nest area is expressed as a percentage of the available deep box cell count (~70,000 cells total).


| Queen Grade | Eggs per Day (peak summer) | Active Brood Area (% of deep box) |
| --- | --- | --- |
| S (Exceptional) | 1,800 – 2,000 | 45–50% of box (~31,500–35,000 cells in various brood stages) |
| A (Strong) | 1,500 – 1,800 | 38–45% of box (~26,600–31,500 cells) |
| B (Average) | 1,200 – 1,500 | 30–38% of box (~21,000–26,600 cells) |
| C (Declining) | 800 – 1,200 | 22–30% of box (~15,400–21,000 cells) — pattern becoming irregular |
| D (Failing) | 300 – 800 | 10–22% of box (~7,000–15,400 cells) — scattered, unreliable |
| F (Failed) | 0 – 300 | Under 10% (~under 7,000 cells) — or zero laying |


Because a worker bee takes 21 days from egg to emergence, the total active brood at any time = approximately (eggs per day x 21). A Grade A Italian queen laying 1,600 eggs/day has roughly 33,600 bees in various brood stages across her frames at any moment — a thriving, productive colony.

Species Modifiers on Laying Pattern

Queen species affects not just how many eggs are laid, but when during the season laying peaks, how the brood nest contracts in fall, and the character of the pattern itself.


| Species | Seasonal Laying Behavior | Pattern Character |
| --- | --- | --- |
| Italian | Slow to reduce laying in fall. Maintains large brood nest late into the season — can lead to inadequate honey stores if the player doesn't manage it. Spring ramp-up is steady. | Textbook oval arc. Exceptionally clean and dense at grade A/S. The 'reference standard' new players learn to recognize healthy brood against. |
| Carniolan | Very rapid spring buildup — can double population in 3–4 weeks in good conditions. Sharply reduces brood in fall, very frugal. This mismatch (huge spring + fast fall shutdown) makes swarming the primary management challenge. | Dense and solid like Italian but the brood nest expands and contracts faster. A Carniolan hive in late spring looks 'full' faster than an Italian. Inspections in early summer often show the first queen cells if space isn't added. |
| Russian | Conservative. Slower spring buildup than Italian or Carniolan. Keeps a smaller brood nest year-round proportional to available forage — a natural mite resistance trait (fewer capped brood = fewer mite reproduction sites). | Slightly less dense than Italian at equal grades. The player who doesn't know Russian genetics may mistake a healthy Russian colony for a C-grade Italian. Context and species knowledge matter. |
| Buckfast | Highly consistent across the season. Less boom-bust than Carniolan. Predictable, even laying rate that makes it easier for new players to establish expectations. | Very clean pattern, similar to Italian. Buckfast at grade A is arguably the most readable brood pattern in the game — good for players learning the system. |
| Caucasian | Very slow spring buildup — the slowest of the available species. Stays in a slow buildup mode well into early summer. Not ideal for Cedar Bend's short spring flow window. | Smaller brood nest than other species at equal grades. A Caucasian A-queen looks similar to an Italian B-queen in brood volume — important distinction when evaluating a newly acquired hive. |


Age Effects on the Pattern

A queen's laying performance is not static. It degrades naturally with age, and the player can observe this degradation in the brood pattern over seasons.


| Queen Age | Typical Grade Range | Observable Pattern Change |
| --- | --- | --- |
| Year 1 (new queen) | A to S | Pattern is dense and reliable. Queen is at or near her peak genetic potential. |
| Year 2 (prime) | A to S | No significant change from Year 1 for a well-performing queen. This is the optimal productive period. |
| Year 3 (mature) | B to A | Slight loosening of the pattern — small gaps appearing that weren't there before. Still functional and productive. |
| Year 4 (aging) | C to B | Noticeably more gaps. The brood arc begins to look less oval, more irregular. Honey production starts to reflect the decline. Many beekeepers replace queens at this stage proactively. |
| Year 5+ (old) | D to C | Pattern is clearly spotty. Player will have observed the decline over at least one full season. Colony at risk. Replacement is overdue. |


*Design Note: The player is never told a queen's age directly. They observe it through the pattern. A well-kept hive journal (Knowledge Log) helps — the player can note when they installed a queen and track the pattern quality year over year. This is authentic beekeeping practice: knowing your queens and their history.*

What the Player Does During a Frame Inspection

The frame inspection view is a close-up, scrollable illustration of each frame face. The player interacts with it in the following ways:


| Pull Frame | Select a frame to inspect. Frames are shown in order, left to right. The player can inspect any or all frames. |
| --- | --- |
| Flip Frame [F] | View the second side of the frame. Press [F] to flip between Side A and Side B. Each side has its own cell grid and is rendered independently. Stats accumulate progressively — each side viewed adds its cell counts to the running total for this inspection. A "Seen X/20" counter tracks how many frame sides have been examined. Viewing all 10 frames × 2 sides gives the complete picture. Dev mode bypasses accumulation and shows full hive stats immediately. |
| Identify Cell Types | Cell identification is gated by Inspection Knowledge Tier (see §6.1.1). Level 1 (Hobbyist) sees nothing on hover. Levels 2–5 all reveal cell state names only on mouseover. Cell age and coordinates are dev mode only (G key active). This models how a beekeeper's observational skill develops from "what am I looking at?" to instant diagnostic reading. |
| Find the Queen | The queen is present on one of the frames. Finding her is not required but earns a small XP bonus and confirms she is alive. Queen-finding skill improves with experience. An S/A Italian queen is easier to spot (large, distinctive abdomen, ring of attendants). A Russian queen in a defensive colony is harder. |
| Flag a Cell | The player can mark specific cells or frames for follow-up. These flags persist to the next inspection, allowing comparison. |
| Annotate Frame | A short text or symbol note can be attached to a frame. This feeds the hive's field log. |
| Pattern Evaluation | After reviewing the frame, the player selects a pattern quality descriptor (or leaves it for the game to auto-note based on what was observed). This comparison over weeks is how the player tracks queen decline. |


Connecting Frame Observations to Decisions

The frame inspection is only meaningful if what the player sees connects directly to available actions. This table maps key observations to their appropriate responses.


| Observation | Probable Cause | Player Action Options |
| --- | --- | --- |
| Solid brood, eggs visible, stores good | Healthy queen, well-functioning colony | No intervention needed. Note as healthy. Add super if frames are filling. |
| Pattern becoming spotty over 2+ weeks | Queen aging or early disease pressure | Do a mite count. Check for disease signs. Consider preemptive requeening. |
| No eggs, young larvae present | Queen present but not observed, or very recent loss | Inspect again in 5 days. Do not panic-requeen. |
| No eggs, capped brood only, 1 week later no young brood | Queen lost 7–14 days ago | Look for emergency queen cells. Order a replacement queen. Assess timeline. |
| Multiple eggs per cell, eggs on cell walls | Laying worker — queen gone 3–4+ weeks | Difficult to correct. Options: combine with queenright colony, or introduce new queen (low acceptance rate). |
| Sunken, perforated cappings, rope test positive | American Foulbrood suspected | Stop inspection immediately. Contact Dr. Harwick. Do not reuse equipment. |
| Chalky white mummies on landing board and in cells | Chalkbrood | Improve ventilation. Requeen if severe. Often self-resolves. |
| Solid brood but many bees with shriveled wings | High varroa + Deformed Wing Virus | Do a mite wash immediately. Treat if above threshold. Late-season urgency. |
| Queen cells present on bottom bars | Swarm preparation | Assess space. Split hive if strong. Remove cells only as temporary measure. |
| Queen cells in middle of frames | Supersedure — colony replacing a failing queen naturally | Observe and allow. This is the colony self-correcting. Monitor for new queen acceptance. |
| Brood only in 3–4 frames, sparse population | Small or struggling colony, possibly post-swarm | Consider combining with a weaker neighbor. Ensure adequate stores. Do not add supers. |


*Design Note: This decision table is also the underlying logic for Darlene's advice system. When the player flags an observation, Darlene's response (if the player talks to her that week) draws from this table. Over time the player internalizes the table and no longer needs the advice — which is exactly the learning arc the game is designed to produce.*

### 3.8.A Godot Implementation — Frame & Population Simulation

This section describes the theoretical architecture for implementing the frame-level brood simulation and laying pattern in Godot 4 without tanking performance. This is logic and pseudocode — not a finished script — intended to guide the developer working on the population algorithm so that both systems speak the same language.

*Design Note: The core challenge: a single hive has ~70,000 cells. Naively tracking every cell as a live object every frame would be catastrophic for performance. The solution is to never update individual cells in real-time — instead, treat the hive as a data structure that is calculated on-demand and only rendered when the player opens the inspection view.*

Architecture Overview

The simulation separates three distinct concerns that must not be conflated:

The Simulation Layer — pure data, runs on a daily tick, no rendering. Lives in a non-visual script (HiveSimulation.gd or similar). Updates cell states, ages bees, applies mortality. Never touches the scene tree during a tick.

The State Snapshot — a compact read-only representation of the hive produced after each daily tick. This is what gets saved and what the render layer reads from. It is a dictionary or Resource, not a live object.

The Render Layer — only active when the player opens the inspection view. Reads the latest State Snapshot and draws what it finds. Destroyed when the player closes the view. Never runs during simulation ticks.

This separation means the simulation can run 7 ticks at once (one per in-game week) during a 'skip week' action without any rendering cost. The render layer wakes up only when the player asks to see a frame.

Data Structure — The Frame Grid

Each frame face is a 2D grid of cells. Rather than Godot nodes, cells are stored as a compact typed array — the most memory-efficient structure available.


| Frame representation | Each frame face = a PackedByteArray or PackedInt32Array of length 3,500 (one entry per cell). Two arrays per frame (front and back). 10 frames per deep box = 20 arrays per box. |
| --- | --- |
| Cell state encoding | Each cell is encoded as a single integer: 0 = empty, 1 = egg (age 0–2), 2 = open larva (age 3–8), 3 = capped larva (age 9–10), 4 = pupa (age 11–20), 5 = newly hatched (age 21–22), 6 = bee bread (pollen), 7 = nectar, 8 = capped honey, 9 = damaged/dead cell. Age is stored separately in a parallel age array. |
| Age tracking | A parallel PackedByteArray stores the age in days of whatever occupies each cell. On each daily tick, all occupied cells have their age incremented. Cells that reach their stage transition age flip to the next state automatically. |
| Memory footprint | 3,500 cells × 2 sides × 10 frames × 2 arrays (state + age) × 1 byte each = 140,000 bytes per deep box = ~137 KB. Even with 25 hives and 2 boxes each, total: ~6.7 MB. Trivial. |
| Super frames | Supers use the same structure but cells only ever contain states 7 (nectar) or 8 (capped honey). Simplifies their update logic significantly. |


The Daily Tick — HiveSimulation.gd

A game-wide timer or calendar node fires a signal once per in-game day. Each active hive's simulation script receives this signal and runs its update function. The update function never yields, never awaits, and never touches the scene tree.


| Tick trigger | GameCalendar.gd emits day_passed signal. All registered HiveSimulation nodes receive it via a direct connection or through a HiveManager autoload. |
| --- | --- |
| Batch processing | If the player skips a week, the calendar fires 7 day_passed signals in a single _process frame using a counter. Because the simulation is pure data, all 7 run in microseconds. The render layer does not update until the player opens the view. |
| Tick ordering | Within each daily tick: (1) queen lays eggs into the grid, (2) all existing cells age by 1, (3) cells at transition age flip state, (4) mortality checks run, (5) role counts (nurse, forager, etc.) are recalculated from live cell population, (6) state snapshot is written. |
| Thread safety | If performance profiling shows the tick is too slow with many hives, the per-hive update functions can be pushed to a WorkerThread using Godot 4's Thread class. Each hive is independent — no shared mutable state — so threading is safe and straightforward. |


Queen Laying Logic — Pseudocode

The queen's laying behavior is the most spatially complex part of the simulation. It must produce a realistic inverted-ellipse pattern that radiates from frame center outward, respects existing cell states, and degrades naturally with queen grade. The following is the intended logic:


| Step 1: Calculate daily egg budget | eggs_today = queen.base_laying_rate × queen.grade_modifier × seasonal_modifier(current_week) × forage_modifier(location.forage_level) × colony_stress_modifier(hive.health) Clamp to species maximum (e.g. 2000 for S-grade Italian). |
| --- | --- |
| Step 2: Determine active laying frame | Queen has a current_frame index and a current_position (x, y) on that frame. Each day she continues from where she left off. When a frame is fully laid, she moves to the adjacent frame. The sequence is center-out: she starts on frame 5, fills it, expands to frames 4 and 6, then 3 and 7, etc. This naturally produces the observed multi-frame brood nest pattern. |
| Step 3: Generate the ellipse mask | For the current frame, compute an ellipse centered at (frame_center_x, frame_center_y). Ellipse semi-axes: a = frame_width × 0.4, b = frame_height × 0.45 (taller than wide — the inverted ellipse shape). Only cells within the ellipse boundary are eligible laying targets. As the queen fills the center, the ellipse expands outward each day until the frame's eligible area is saturated. |
| Step 4: Sort eligible cells by priority | Within the ellipse, prioritize cells in this order: 1. Empty cells at the current laying front (innermost unfilled ring) 2. Empty cells that were previously occupied (cleaned, cured cells) 3. Empty cells at the ellipse boundary Skip: cells containing any state other than 0 (empty). The queen does not lay over existing brood, pollen, or honey. |
| Step 5: Apply grade-based skip probability | For each eligible cell, roll a random float 0.0–1.0. If roll < queen.skip_probability, skip this cell (leave it empty). skip_probability by grade: S = 0.02 (2% skip — almost solid) A = 0.06 B = 0.12 C = 0.22 D = 0.38 F = 0.60+ This is what produces the visual pattern quality difference between grades. A grade S queen almost never skips. A grade D queen skips more than a third of eligible cells. |
| Step 6: Write eggs to grid | For each cell selected in steps 4–5: frame_state[cell_index] = STATE_EGG frame_age[cell_index] = 0 Decrement eggs_today by 1. Stop when eggs_today reaches 0 or no eligible cells remain. |
| Step 7: Handle frame overflow | If eggs_today > 0 after exhausting eligible cells on the current frame, advance queen.current_frame by ±1 (alternating outward from center). Repeat steps 3–6 on the new frame. If all brood frames are full (brood-bound condition), eggs_today is wasted — the queen has nowhere to lay. This is the brood-bound trigger (see Section 3.8.B). |


Cell Aging & State Transitions — Pseudocode

After laying, the tick iterates every occupied cell and increments age. Transitions are deterministic — no randomness needed for normal progression. Randomness only enters through mortality checks.


| Age the cell | for each cell in all_frame_arrays: if frame_state[i] != STATE_EMPTY: frame_age[i] += 1 |
| --- | --- |
| Check transitions | match frame_state[i]: STATE_EGG: if frame_age[i] >= 3: transition to STATE_OPEN_LARVA, reset age to 0 STATE_OPEN_LARVA: if frame_age[i] >= 6: transition to STATE_CAPPED_LARVA, reset age to 0 STATE_CAPPED_LARVA: if frame_age[i] >= 2: transition to STATE_PUPA, reset age to 0 STATE_PUPA: if frame_age[i] >= 10: transition to STATE_HATCHED, reset age to 0 also: cap_the_cell() -- sets visual capping flag STATE_HATCHED: if frame_age[i] >= 2: add_bee_to_population(BeeRole.NURSE) frame_state[i] = STATE_EMPTY frame_age[i] = 0 |
| Mortality check (brood) | Run after transitions, before emptying hatched cells. For each brood cell (EGG through PUPA): mortality_chance = base_mortality + varroa_modifier(hive.mite_count) # highest impact on PUPA + disease_modifier(hive.disease_flags) + chilling_modifier(nurse_ratio, temperature) if randf() < mortality_chance: frame_state[i] = STATE_DAMAGED frame_age[i] = 0 # Damaged cells must be cleaned before reuse — a 1–2 day delay |
| Pollen & honey cells | Bee bread (pollen) and honey cells are not aged the same way. They are consumed by nurse bees proportional to open larva count. Each day: pollen_consumed = open_larva_count × POLLEN_PER_LARVA_PER_DAY Deduct from nearest pollen cells to the brood arc. Honey cells consumed similarly based on colony energy needs. If pollen cells reach 0 within the forage radius of the brood nest: pollen_deficiency = true. |


Spatial Layout of the Outer Frames — Bee Bread & Honey

The pollen and honey layout is not random — it follows the same biology the brood arc does. Nurse bees store bee bread (pollen + honey mix) in a band immediately surrounding the brood arc on each frame. Capped honey fills the arc at the top and extends to the outer frames.


| Pollen band placement | When foragers return with pollen, it is deposited in cells immediately adjacent to the outermost ring of the brood ellipse on the same frame. In the grid: cells within 2–4 cell-widths outside the ellipse boundary are the first targets for pollen storage. This is why the player sees the characteristic rainbow pollen band ringing the brood on a healthy frame. |
| --- | --- |
| Honey arc placement | Honey is stored in the top third of each frame first — bees prefer to store honey above the brood nest. Top cells of frames 3–8 fill first. Once those are full, honey spreads to frames 2 and 9. Outer frames (1 and 10) fill entirely with honey last. Supers: honey storage preference routes incoming nectar to the super first if supers are present and the brood box top-third is already >80% full. |
| Routing logic pseudocode | func deposit_honey(amount): # Prefer super if available and brood box top is >80% full if has_super and brood_box_top_fill > 0.80: deposit_to_super(amount) else: # Fill top of center frames outward for frame_index in [5,6,4,7,3,8,2,9,1,10]: remaining = deposit_to_top_third(frame_index, amount) amount = remaining if amount <= 0: break if amount > 0: honey_overflow = true # signal: add super or harvest |
| Routing logic for pollen | func deposit_pollen(amount): # Target the pollen band ring on brood frames for frame_index in brood_frames: target_cells = get_pollen_band_cells(frame_index) remaining = fill_cells(target_cells, STATE_BEEBREAD, amount) amount = remaining if amount <= 0: break if amount > 0: # Overflow: pollen goes into any empty cell near brood deposit_to_overflow_pollen_cells(amount) |


Render Layer — How the Frame View Is Drawn

The render layer is completely separate from the simulation. It activates only when the player opens a hive for inspection. It reads the current State Snapshot and draws what it finds. It does not run any game logic.


| FrameRenderer.gd | A CanvasItem (Node2D or Control) that receives a frame_state array and frame_age array. Draws each cell as a colored tile using draw_rect() or a pre-baked TextureAtlas. One draw call per cell type (batch all CAPPED_BROOD cells, then all EGG cells, etc.) using draw_multiline_rect or a custom mesh. With 3,500 cells per face at ~8×8 pixels each, the full frame face is ~224×224 pixels — small enough to fit comfortably in the inspection viewport at any resolution. |
| --- | --- |
| Cell color mapping | STATE_EMPTY = light wax yellow STATE_EGG = white dot on wax background STATE_OPEN_LARVA = white crescent (age-scaled size) STATE_CAPPED_LARVA / PUPA = tan flat cap STATE_HATCHED = briefly empty with chewed-edge texture STATE_BEEBREAD = multi-color spectrum (reflects pollen diversity — visual richness cue) STATE_NECTAR = transparent amber STATE_CAPPED_HONEY = golden capped STATE_DAMAGED = dark, concave, off-color — visually distinct alarm signal |
| LOD (Level of Detail) | When viewing the full frame (zoomed out): cells are 2×2 pixels, using averaged color per cluster. When zoomed in to inspect eggs: cells are 8×8 pixels with full detail. The player can zoom using scroll wheel or pinch. Only the zoomed region rerenders at full detail. This means the most expensive render (full detail, all cells) only runs on the ~100 cells in the current zoom window — trivially fast. |
| Queen position indicator | If the queen is on this frame, her location is stored in the State Snapshot as queen_frame and queen_cell_index. The renderer draws a small ring or highlight on that cell. Queen visibility is gated by the player's experience level and a per-inspection detection roll — not always shown. |
| Dirty flag optimization | Each frame has a is_dirty boolean. It is set to true when any cell in that frame changed state during the last tick. The renderer only redraws frames where is_dirty == true. In practice, outer honey/pollen frames may go many days without any state change — they are never redrawn during those periods. |


Performance Summary


| Simulation tick cost | Pure array iteration. No scene tree, no rendering, no signals during the loop. For 25 hives × 2 boxes × 20 arrays × 3,500 cells = 3.5 million cell checks per daily tick. At ~1ns per check (conservative for a simple match statement on a byte), this is ~3.5ms per day tick. Acceptable. With threading, distributable across cores. |
| --- | --- |
| Render cost | Only active during inspection. FrameRenderer draws ~3,500 cells per face using batched draw calls. With LOD, the expensive per-pixel render only runs on the currently zoomed region (~100–400 cells). Full-frame redraws at low detail are fast. |
| Memory cost | ~137 KB per box (see above). 25 hives × 2 boxes = ~6.7 MB total for all cell state arrays. Trivial on any target platform. |
| Save/load cost | State snapshot is a dictionary of PackedByteArrays. Godot's built-in serialization handles this efficiently. Hive state can be saved as a .tres Resource or a binary blob. Incremental saves (only write hives that changed this week) further reduce I/O. |
| Godot 4 specifics | Use PackedByteArray (not Array[int]) for cell state and age — it avoids Variant overhead and keeps memory tight. Use direct array indexing (arr[i]) not iterators in hot loops. Avoid GDScript for the inner tick loop if profiling shows it is a bottleneck — consider GDNative/C++ extension for that function only. |


*Design Note: The single most important architectural decision is the strict separation of simulation (data) and rendering (view). As long as the tick function never touches a Node, never emits display signals, and never yields, it will be fast regardless of hive count. The render layer is only ever as expensive as what the player is currently looking at.*

#### Colony Stress Modifier — Formula Definition

The `colony_stress_modifier` referenced in the queen laying pseudocode is a composite float (0.0–1.0) that scales the daily egg budget. A value of 1.0 means no stress; 0.0 means the queen lays no eggs. It is calculated each tick from five input factors:


```gdscript
colony_stress_modifier = (
    forage_factor    × 0.35 +
    congestion_factor × 0.25 +
    varroa_factor    × 0.20 +
    disease_factor   × 0.15 +
    queen_factor     × 0.05
)
```


| Factor | Input | Value Mapping |
| --- | --- | --- |
| forage_factor | forage_pool_fill_ratio at current location (0.0–1.0+) | ≥0.8 → 1.0; 0.5–0.8 → ratio/0.8; <0.5 → ratio×0.5 (exponential penalty) |
| congestion_factor | current CongestionState enum | NORMAL → 1.0; HONEY_BOUND → 0.85; BROOD_BOUND → 0.75; FULLY_CONGESTED → 0.50 |
| varroa_factor | mites_per_100_bees | <1 → 1.0; 1–2 → 0.95; 2–3 → 0.85; 3–5 → 0.70; 5–8 → 0.50; >8 → 0.25 |
| disease_factor | active disease flags | None → 1.0; Nosema → 0.80; EFB → 0.75; Sacbrood → 0.85; AFB → 0.40. Multiple diseases: multiply individual factors. |
| queen_factor | queen.grade | S/A → 1.0; B → 0.95; C → 0.80; D → 0.60; F → 0.0 (queen_factor alone zeroes the laying budget) |


Result is clamped to [0.0, 1.0]. At 0.0 the queen does not lay. At 0.5 she lays at half capacity. Values above 0.85 are typical for a well-managed colony in good forage conditions.

### 3.8.B Congestion Detection — Brood-Bound & Honey-Bound

Congestion is one of the most consequential and frequently misread hive conditions. A colony can become congested with brood (no room for the queen to lay) or with honey (no room for incoming nectar), and the causes, consequences, and player responses are different in each case. Both conditions are directly detectable from the frame grid simulation.

Correctly diagnosing and responding to congestion is also the game's primary strategic decision point — the choice between investing in colony strength or extracting immediate honey profit is made here, multiple times per season.

Detecting Brood-Bound Conditions

A hive is brood-bound when the queen cannot find sufficient empty cells to sustain her laying rate. The simulation detects this automatically.


| Trigger condition | During the queen's daily laying step (Step 7 of laying pseudocode), if eligible_empty_cells_in_brood_zone < eggs_today × 0.5 for 3 or more consecutive days, set hive.brood_bound_flag = true. |
| --- | --- |
| Root causes | 1. Honey filling the brood frames from the top down — bees have nowhere else to put incoming nectar, so they store it in cells the queen needs. 2. Pollen band overflow — excess pollen encroaching into the brood zone. 3. Colony outgrowing the box — the brood nest wants to expand but has hit the frame boundaries. 4. Population explosion in spring (especially Carniolan queens) — the colony grows faster than the bee bread/honey balance adjusts. |
| Frame evidence | Player sees during inspection: brood frames with increasingly heavy honey arcs creeping down from the top, pollen packed densely around the brood, queen cells on the bottom bars (swarming is imminent if unaddressed), and possibly a queen found walking on the outer honey frames looking for laying space. |
| Simulation signal to player | Hive status icon changes to a 'crowded brood' indicator visible on the apiary view without opening the hive. Darlene may comment: 'Your strongest hive is getting cramped — might be time to give them more room.' |


Detecting Honey-Bound Conditions

A hive is honey-bound when incoming nectar has no appropriate storage destination and is being packed into cells that should remain empty for cluster movement or brood expansion.


| Trigger condition | honey_overflow flag (from deposit_honey pseudocode) fires for 2+ consecutive days AND no super is present. Alternatively: top-third fill rate of brood box frames 3–8 exceeds 90%. |
| --- | --- |
| Root causes | Peak nectar flow with no super added — the most common beginner mistake. Super that is full and not harvested — flow continues but honey has nowhere to go. Small colony during a strong flow — not enough bees to process and cap incoming nectar fast enough, leading to 'wet' uncapped honey filling the brood area. |
| Frame evidence | Player sees during inspection: heavy uncapped nectar in the upper half of all brood frames, the characteristic 'water curtain' of glistening wet nectar, bees fanning vigorously to evaporate moisture. Honey is encroaching toward the brood zone from the top. If unaddressed, the brood arc shrinks as honey displaces it. |
| Simulation signal to player | Hive status shows a 'honey-bound' indicator. This is time-sensitive — if the flow is at peak and no action is taken within ~3 days, honey production is lost (cells full, incoming nectar is rejected) and the brood arc begins to compress. |


The Congestion Decision — Strategic Fork

When either brood-bound or honey-bound conditions are detected, the player must choose an intervention. This is the game's central seasonal strategic decision. It is not a clear right answer — it depends on the player's goals for that hive and that season.


| Condition | Option A: Build Colony Strength | Option B: Maximize Immediate Honey Profit |
| --- | --- | --- |
| Brood-Bound | Add a second deep body below or above the current box. Bees draw out new comb, queen gains ~70,000 new cells of laying space. Colony population will double over the next 3–4 weeks. Cost: substantial time and equipment. Benefit: a very strong fall colony with better overwinter odds and next year's productivity. | Do not add space. Allow the colony to swarm or perform a split. A split redirects the swarming impulse — you get a second hive but the original colony weakens temporarily. Cost: reduced honey production this season from both halves. Benefit: two hives going into next year. |
| Honey-Bound (strong flow) | Add a honey super. Bees immediately route incoming nectar to the super, relieving pressure on the brood box. Queen regains laying room. Colony stays strong and continues building population through the flow. Cost: equipment (super, frames), time. Benefit: maintains colony strength AND captures the flow. The correct choice in most cases during peak summer. | Harvest the existing super or brood box honey now rather than adding space. Queen's laying room is restored by emptying cells. Cost: early harvest means lower moisture, lower yield (bees haven't finished curing some frames). Benefit: immediate income, no additional equipment needed. Viable during a secondary flow with a weaker hive. |
| Honey-Bound (dearth / late season) | Do not add a super — there is no flow to fill it. Instead, ensure adequate stores for winter are present in the brood box. Treat this as a positive signal: the colony has good stores. Action: verify the weight threshold for winter stores is met. If yes, harvest carefully and leave the minimum. | This is the fall harvest decision. The player must balance how much to take vs. how much the colony needs to survive winter. The simulation tracks the exact cell-by-cell honey inventory, so the player can see precisely how many frames of honey are present during inspection. |


*Design Note: The brood-bound / honey-bound system is where the population simulation and the forage pool system intersect with player economics. It is the moment when all the background simulation becomes a concrete decision with a visible outcome. This moment should happen multiple times per season — it is a primary gameplay loop driver, not a rare edge case.*

How the Simulation Tracks Congestion Over Time

The simulation maintains running tallies that feed the congestion detection logic. These are recalculated at the end of each daily tick as part of the State Snapshot.


| brood_cell_count | Total cells in STATE_EGG + STATE_OPEN_LARVA + STATE_CAPPED_LARVA + STATE_PUPA across all frames in the box. Compared to total available cells to calculate brood_fill_pct. |
| --- | --- |
| honey_cell_count | Total cells in STATE_CAPPED_HONEY across all frames. Compared against species-normal winter store threshold and frame capacity. |
| nectar_cell_count | Total cells in STATE_NECTAR (uncapped). High nectar + low capped honey = bees are processing a flow. High nectar + high capped honey = honey-bound risk. |
| pollen_cell_count | Total cells in STATE_BEEBREAD. Low pollen relative to open larva count = pollen deficiency risk. |
| empty_brood_zone_cells | Empty cells within the queen's laying ellipse. The queen's daily laying step compares eggs_today against this. When this drops below a threshold, brood-bound detection fires. |
| box_fill_pct | Overall fill percentage = (brood + honey + pollen + nectar cells) / total cells in box. When this exceeds ~85%, the hive is at capacity regardless of specific content type. |
| congestion_state | An enum: NORMAL, BROOD_BOUND, HONEY_BOUND, FULLY_CONGESTED. Set by the detection logic. Read by the UI system to show the hive status indicator and by Darlene's advice system to trigger relevant dialogue. |


*Design Note: These tallies are cheap to maintain — they are simple counters incremented and decremented as cells change state, not full-array scans. The box\_fill\_pct and empty\_brood\_zone\_cells values are updated on every tick as a natural byproduct of the cell aging loop. There is no additional performance cost to tracking congestion.*

### 3.9 Queen Breeding & Rearing System

Queen breeding is the game's deepest late-game system. It is unlocked at Level 4 (Journeyman) after the player has built a Queen Rearing Area structure and demonstrated mastery of basic queen management. It is the mechanic where all prior knowledge converges — genetics, population health, forage timing, and precision technique — and where the player's ability to micro-optimize their operation peaks.

The goal is to allow the player to selectively propagate traits from their best queens into new stock, producing S-grade daughters that outperform anything purchasable from a supplier. It is also the route to selling high-value nucleus colonies and queens to other beekeepers, the game's most premium income stream.

*Design Note: This system is intentionally gated behind significant progression. A player who encounters it in Year 1 would be overwhelmed. A player who reaches it in Year 3–4 has already internalized everything they need to make meaningful breeding decisions.*

3.9.1 Genetic Trait System

Each queen carries a genetic profile composed of several heritable traits. These traits are not visible to the player as raw numbers — they are observed through colony behavior and performance over time, exactly as a real beekeeper would assess them. Internally, each trait is a value the algorithm tracks and passes to offspring through the breeding mechanics.


| Trait | How the Player Observes It | What It Affects |
| --- | --- | --- |
| Laying Rate | Brood pattern density, frame coverage, colony buildup speed | Eggs per day output; directly drives population simulation input |
| Pattern Consistency | Uniformity of capped brood arc; how few gaps appear in the brood zone | Brood survival rate; reflects egg viability and laying precision |
| Temperament | Hive behavior during inspections — calm vs. defensive, fanning vs. following the smoker | Inspection ease; stinging risk; defensive behavior during dearth |
| Varroa Resistance | Mite counts over time relative to neighboring hives; hygienic behavior (do workers remove diseased brood?) | Mite load growth rate; treatment frequency needed |
| Hygienic Behavior | Whether bees remove dead or diseased larvae quickly (observable during disease events) | Disease spread rate; chalkbrood and AFB resistance; mite reproduction disruption |
| Winter Hardiness | Cluster size relative to fall population; stores consumption rate; spring buildup speed | Overwinter survival probability; winter bee vitellogenin quality |
| Honey Production | Honey frame fill rate per week during peak flow relative to forage available | Nectar processing efficiency; wax secretion rate; house bee work rate |
| Foraging Range | Not directly visible — inferred from honey production relative to visible local forage | Distance bees will travel; useful in low-forage locations |


*Design Note: Traits are polygenic — no single trait operates in isolation. A queen with excellent laying rate but poor hygienic behavior will produce a booming colony that is also a varroa magnet. The player learns to breed for a balanced profile, not just one star trait. This is authentic selective breeding practice.*

3.9.2 Trait Inheritance

Queen genetics in real honeybees are unusually complex — queens mate with multiple drones (polyandry), meaning a single queen's worker offspring have different fathers. The game models this in a simplified but authentic way.


| Queen's Contribution | The queen contributes 50% of the genetic value for each trait to her daughters. Her trait profile is known to the player through observation over at least one full season. |
| --- | --- |
| Drone Contribution | The other 50% comes from drones. In open mating (natural), the drone contribution is semi-random — drawn from the drone population of nearby hives (player's own and ambient wild colonies). In controlled mating (the minigame), the player selects the drone source hive, dramatically improving trait predictability. |
| Trait Blending | Each heritable trait in a daughter queen = (Mother trait value + Drone source trait value) / 2, plus a small random variance (±5–10%). This means breeding from two S-grade parents does not guarantee an S-grade daughter, but substantially increases the probability. |
| Regression to the Mean | If one parent has an exceptional trait value and the other is average, the daughter will typically land between them. Consistent improvement requires both parents to be above average on the target trait — the real-world challenge of a breeding program. |
| Hybrid Vigor | Crossing two distinct species (e.g., Italian × Carniolan) sometimes produces offspring with slightly elevated trait values above either parent on specific traits — a real biological phenomenon. Buckfast bees are the canonical example. Unpredictable but occasionally rewarding. |
| Trait Tracking | The player's Queen Rearing notebook (an extension of the Knowledge Log) records each queen's observed trait assessments. Over multiple generations the player builds a breeding record they can refer to — a genuine pedigree system. |


3.9.3 The Queen Rearing Process

Queen rearing follows the real biological method of grafting or cell punching, rendered as a multi-step minigame sequence. Each step requires the right equipment, the right timing, and appropriate skill. The full process takes approximately 4–5 in-game weeks from start to mated, laying queens.


| Step | Real-World Process | In-Game Mechanic |
| --- | --- | --- |
| 1. Select a Mother Queen | Identify a queen with the traits you want to propagate. Ideally she has at least two seasons of documented performance. | Player opens their Queen Rearing notebook, reviews their queens' observed trait profiles, and designates a 'breeding queen.' Her colony becomes the larva source hive. |
| 2. Prepare the Cell Builder Colony | A strong, queenless (or temporarily queenless) colony is set up as the cell builder. It must be well-fed and populous — nurse bees are the labor force that raise the queen cells. | Player selects a strong queenright hive and removes the queen to a nuc (or uses a queenless colony). The cell builder must meet a minimum nurse bee population threshold — checked by the population simulation. Inadequate nurse bees = poor cell quality. |
| 3. Graft Larvae (or Use a Grafting Alternative) | Young larvae (under 24 hours old — ideally just-hatched from the egg) are transferred from the mother queen's frames into artificial queen cups using a grafting tool. | The Grafting Minigame (see 3.9.4). The player uses the grafting tool on a magnified frame view to select and transfer larvae. Skill and equipment quality determine graft acceptance rate. |
| 4. Introduce Grafts to Cell Builder | The graft bar is placed in the cell builder colony. Workers begin drawing out the cups into full queen cells over the next ~10 days. | Player places the graft bar in the cell builder. A progress indicator shows cell development over the following days. Cell quality is influenced by nurse bee population and forage/feeding adequacy of the cell builder during this period. |
| 5. Distribute Queen Cells | After ~10 days, cells are capped and nearly ready to emerge (~day 11 from grafting). Cells are distributed into mating nucs before they emerge. | Player harvests capped cells and places them into prepared mating nucs. Timing is critical — a cell that emerges in the cell builder will result in the first virgin killing all remaining cells. |
| 6. Virgin Queens in Mating Nucs | Virgin queens emerge in mating nucs, take orientation flights, then mating flights over 1–2 weeks. They mate with drones at a DCA. | The Mating Minigame (see 3.9.5). The player monitors weather windows and manages the mating nuc's food stores during the 1–2 week mating period. Mating flight success depends on weather and available drone quality. |
| 7. Confirm Laying | After mating, the queen returns and begins laying within 5–7 days. The beekeeper inspects to confirm a solid, fertilized brood pattern. | Player inspects the mating nuc after 10 days. A solid pattern with the correct cell size confirms mated success. Drone-sized cells in a small pattern = failed mating (drone layer). The player can now use the queen or bank her for later. |
| 8. Use or Bank the Queen | Mated queens can be introduced to production colonies, sold, or held temporarily in a bank colony. | Player choices: introduce to a production hive (requeen), install in a new split, sell to the Cedar Valley Beekeepers Association or Uncle Bob for premium income, or hold in the queen bank (see 3.9.6). |


3.9.4 The Grafting Minigame

Grafting is the precision heart of the queen rearing system. It is a close-up, real-time interaction with a frame from the mother queen's hive. The player uses a grafting tool to transfer individual larvae into queen cups. It is deliberately skilled — not punishing, but rewarding of care and the right equipment.


| Frame View | The player sees a magnified view of a brood frame from the mother queen's colony. Cells are visible at a scale where individual larvae can be identified. The player must find cells with the youngest larvae — ideally just-hatched, under 24 hours old. |
| --- | --- |
| Larva Age Identification | Larva age is visible as size. A just-hatched larva is a tiny crescent floating in a pool of royal jelly. A 24-hour larva is slightly larger. A 48-hour larva is noticeably larger and less curled. Only the youngest larvae produce the best queens — the player learns to identify them. |
| The Transfer | Player clicks or taps to select a target larva, then moves it to a queen cup on the graft bar. A steady hand mechanic (mouse precision or tap timing on mobile) affects whether the larva is damaged during transfer. A damaged larva is rejected by the nurse bees. |
| Equipment Effect | A basic grafting tool has a moderate success rate (~70% acceptance). A Chinese grafting tool (spring-loaded, more forgiving) raises acceptance to ~80%. A Jenter or OAC cell punch kit (no grafting required — see below) raises acceptance to ~90%+ but requires additional setup. |
| Lighting | A bright light source is required. The basic shed provides poor lighting. A proper inspection lamp (purchasable equipment) significantly improves larva visibility and graft accuracy. This is a real-world beekeeper's essential tool. |
| Graft Bar Capacity | Standard graft bar holds 10–20 cups. The player typically grafts more than needed as insurance — a 70% acceptance rate on 15 grafts yields ~10–11 successful cells, which is a full round of queens. |
| Jenter/Punch Alternative | The Jenter kit uses a plastic frame insert where the queen lays directly into pre-formed cups. No larva transfer is needed — the cups are simply removed and placed in the cell builder. Eliminates grafting skill entirely but requires getting the queen to lay in the kit first (a separate minigame interaction). Unlocked as premium equipment. |


*Design Note: The grafting minigame should feel like the moment the player transitions from 'managing bees' to 'practicing beekeeping as a craft.' It is delicate, focused, and rewarding when done well. It should not be frustrating — equipment upgrades exist specifically to lower the skill floor for players who find it difficult.*

3.9.5 The Mating Process

After the virgin queen emerges in her mating nuc, the mating process begins. This is less a minigame and more a management window — the player must create the right conditions and then wait, monitoring for the outcome.


| Mating Nucs | Small 3–5 frame colonies specifically maintained to house virgin queens during mating. The player builds and maintains a bank of 2–6 mating nucs in the Queen Rearing Area. Each nuc needs adequate bees, food stores, and ideally a drone-rich environment nearby. |
| --- | --- |
| Orientation Flights | The virgin queen takes short orientation flights for 2–3 days before her mating flights. She must be allowed to exit freely — reducing the nuc entrance to almost nothing risks trapping her. A small interaction moment: the player can choose entrance size before this period. |
| Mating Flights | Queens mate on warm (above 65°F), calm, sunny days. The weather system controls when mating flights are possible. A string of cold or rainy days during the mating window can delay or prevent mating — a real beekeeping challenge in Cedar Bend springs. |
| Drone Source | In open mating, queens mate with drones from any nearby hive, including ambient wild colonies. The player has partial control by ensuring their own hives have high-quality drones present. Full control requires instrumental insemination (see 3.9.7). |
| Mating Success Factors | Weather window availability, drone population quality and quantity, queen age (a virgin queen that hasn't mated by day 28 becomes a drone layer), nuc population health. |
| Confirming Mating | The player inspects the mating nuc 10–12 days after the queen should have begun laying. A solid, fertilized worker-sized brood pattern = mated success. The trait profile of the resulting queen is determined by the drone source genetics. |
| Failed Mating | If the brood pattern shows only drone-sized cells with irregular spacing, the queen is a drone layer — she mated but the sperm was insufficient or she failed to mate. This queen must be replaced. The player loses the time investment but not the nuc population. |


3.9.6 Queen Banking

Mated queens waiting for deployment or sale can be held temporarily in a queen bank — a specialized frame or small colony that maintains queens in laying suspension until they are needed.


| Bank Frame | A frame with individual queen cages that can hold 6–12 mated queens simultaneously. Installed in a strong queenright colony — the workers feed and tend the caged queens. Available as mid-tier crafted equipment. |
| --- | --- |
| Bank Duration | Queens can be banked for up to 4–6 in-game weeks without significant quality loss. Beyond that, laying rate begins to decline. The player must track banking time via the Queen Rearing notebook. |
| Bank Colony Health | The quality of the bank colony matters. A well-fed, populous bank colony maintains queen quality better than a stressed one. Another reason to keep strong production colonies. |
| Sale Window | Banked queens can be listed for sale to the Cedar Valley Beekeepers Association or to Uncle Bob (who has a network of hobby beekeepers). S-grade queens from a documented breeding program command a significant premium over standard purchased queens. |


3.9.7 Instrumental Insemination (Late Game Prestige Unlock)

Instrumental insemination (II) is the ultimate control mechanic — it allows the player to completely specify both parents of a queen, eliminating the randomness of natural mating. It is a prestige unlock available only at Master Beekeeper level and requires a significant equipment investment.


| Unlock Requirement | Level 5 (Master Beekeeper) + completion of a mastery quest from Dr. Ellen Harwick involving multi-season trait documentation and a workshop event at the MSU experienced local beekeeper. |
| --- | --- |
| Equipment Required | Insemination apparatus (microscope, syringe, CO2 canister for anesthetizing the queen), high-quality magnification lamp, specialized storage vials. These are expensive, crafted or ordered items. |
| The Minigame | A precision close-up interaction more demanding than grafting. The player anesthetizes a virgin queen with CO2, mounts her under magnification, and uses the syringe tool to introduce collected drone semen. Requires very steady input. A dedicated minigame sequence distinct from all other interactions in the game. |
| Drone Semen Collection | A second interaction: selecting drones from a chosen father colony and collecting semen. The player selects which hive's drones to use, choosing based on their documented trait profiles. |
| Outcome | A queen inseminated instrumentally has a precisely known genetic profile — both parents are player-specified. Trait prediction accuracy increases significantly. The variance band on trait inheritance narrows from ±10% to ±3–4%. |
| Trade-off | II queens occasionally have slightly lower vitality than naturally mated queens (a real-world phenomenon). The precision comes at a small reduction in long-term laying rate. The player must weigh guaranteed genetics against slightly reduced peak output. |
| Purpose in Game | This is the endgame optimization loop. A player running 25 hives, selling premium queens, and producing varietal honey at scale wants to know exactly what trait profile every queen in their operation carries. II makes that possible. |


3.9.8 Queen Rearing Equipment Reference

The following equipment supports the queen rearing system. Items are acquired through the feed store, online orders (via the post office), or crafted in the Queen Rearing Area.


| Equipment | Function | Unlock / Cost Tier |
| --- | --- | --- |
| Grafting Tool (basic) | Transfers larvae from cells to queen cups. Moderate skill requirement. | Available from start of queen rearing |
| Chinese Grafting Tool | Spring-loaded, self-clearing tip. More forgiving transfer mechanic. Raises acceptance rate. | Feed store, Year 3 |
| Grafting Light / Lamp | Strong directional light for identifying young larvae. Required for reliable grafting. | Feed store, Year 3 |
| Queen Cups (wax or plastic) | Pre-formed cups mounted on a graft bar, placed in the cell builder for workers to draw out into full cells. | Consumable, available Year 3 |
| Cell Bar Frame | Holds multiple rows of queen cups in the cell builder colony. | Craftable, Year 3 |
| Mating Nucs (3-frame) | Small colonies for virgin queen mating and confirmation. | Craftable, Year 3 |
| Jenter Cell Kit | Plastic insert frame allowing the queen to lay directly into pre-formed cups. Eliminates grafting entirely. | Premium equipment, feed store order, Year 4 |
| Queen Introduction Cage | Candy-plug cage for introducing mated queens to production colonies. | Available from start of queen management |
| Queen Bank Frame | Holds 6–12 caged mated queens in a bank colony. Allows delayed deployment or sale. | Craftable, Year 4 |
| Queen Marking Kit | Small paint pen and catcher tube for marking queens by year color (international convention). Makes queen-finding much easier in future inspections. | Feed store, Year 3 |
| Insemination Apparatus | Microscope, syringe, CO2 supply. Required for instrumental insemination. | Expensive order, Level 5 unlock only |
| Queen Rearing Notebook | In-game extension of the Knowledge Log specifically for breeding records. Tracks parent traits, graft dates, mating outcomes, daughter performance. | Unlocked with Queen Rearing Area |


3.9.9 The Breeding Reward Loop

The full queen breeding arc spans multiple seasons and represents the game's most satisfying long-term progression. Here is the intended player experience:


| Year 1–2: Observation | The player manages purchased queens, learns to read brood patterns, and begins noting which hives consistently outperform others. The seed of a breeding program is planted through observation, not action. |
| --- | --- |
| Year 2–3: First Rearing | The player unlocks the Queen Rearing Area and attempts their first graft round. The process feels unfamiliar and imprecise — acceptance rates are moderate, mating weather may be poor, outcomes are mixed. This is intentional. The player is learning. |
| Year 3–4: Refinement | With better equipment and documented trait profiles, graft acceptance improves. The player identifies a standout queen — an S-grade Italian with exceptional hygienic behavior and winter hardiness — and builds a deliberate breeding program around her. Daughter queens outperform anything purchasable. |
| Year 4–5: Optimization | The player is selling queens and nucs, producing varietal honey at high quality grades from well-managed, genetics-optimized colonies. Every hive in the operation has a documented queen lineage. The Queen Rearing Notebook is a record the player is proud of. |
| Level 5: Mastery | Instrumental insemination unlocks. The player now has full genetic control. They are no longer a beekeeper who manages what nature provides — they are a selective breeder shaping what nature produces. This is the top of the skill pyramid. |


*Design Note: The queen breeding system should feel like the difference between playing a sim and understanding what the sim is modeling. A player who reaches instrumental insemination has genuinely learned a substantial amount about real honeybee genetics and queen rearing. The game's educational mission is fulfilled at this moment.*

**PART III**

**The Game**

*Systems, mechanics, progression, economy, art, and audio.*

---

[< Player Tasks by Season](02-Player-Tasks-by-Season) | [Home](Home) | [Game Overview >](04-Game-Overview)