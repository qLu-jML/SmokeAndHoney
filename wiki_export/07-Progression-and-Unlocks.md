[< Core Game Systems](06-Core-Game-Systems) | [Home](Home) | [Quests & Events >](08-Quests-and-Events)

---

# Progression & Unlocks


Progression in Smoke & Honey is expressed through three parallel tracks: Player Experience, Apiary Scale, and Knowledge. All three grow together and reinforce each other.

### 7.1 Player Experience Track


| Level | Title | Key Unlocks |
| --- | --- | --- |
| 1 | Hobbyist | 1 hive. Basic equipment. Italian or Carniolan queen only. Tutorial quests active. |
| 2 | Apprentice | Up to 3 hives. Nucs for sale. Refractometer. Basic crafting (candles, standard jars). |
| 3 | Beekeeper | Up to 8 hives. 2nd apiary location. Buckfast queen. Mead crafting. Honey House curing room upgrade available (Silas Q4). |
| 4 | Journeyman | Up to 15 hives. Queen rearing. Russian queen. Varietal honey labeling. Cosmetics crafting. |
| 5 | Master Beekeeper | Unlimited hives. All bee species. All hive types. All crafting recipes. Mentor NPC quests complete. |


#### XP Values and Earning Rate

XP is earned through beekeeping actions, discoveries, and decisions. Thresholds are designed to mirror the real arc of a hobbyist beekeeper's development — slow and deliberate in the early years when the operation is small, accelerating as hive count and activity diversity grow. A player who inspects regularly, completes quests, and engages with the full range of seasonal activities will level naturally over approximately 6–7 in-game years without grinding. A 2-hive Year 1 player earns roughly 2,000 XP across a full active season; by Year 6 with a large operation and mastery-level engagement, that rate is 5,000–6,000 XP per year. The gaps between level thresholds are calibrated to this scaling — each bracket takes roughly the same amount of real play-time despite the growing XP requirements.


| Level Threshold | XP Required (cumulative total) | XP Earned Above Prior Level | Approximate In-Game Timeline |
| --- | --- | --- | --- |
| Level 1 → 2 | 2,000 XP | 2,000 XP | Very end of Year 1 active season (fall) |
| Level 2 → 3 | 6,000 XP | +4,000 XP | ~Mid Year 3 (~1.5 years after Level 2) |
| Level 3 → 4 | 13,000 XP | +7,000 XP | ~Mid Year 5 (~2 years after Level 3) |
| Level 4 → 5 | 24,000 XP | +11,000 XP | ~Mid Year 7 (~2 years after Level 4) |


*Design Note: The growing XP gap between levels is intentional and not punishing — it reflects that a Year 5 player with 12 hives, a queen-rearing operation, and multiple market channels earns 3–4× more XP per week than a Year 1 player with 2 hives. Each level transition should feel like roughly the same amount of engaged play-time, despite the raw XP numbers growing. Exact per-action values will require playtesting calibration; the thresholds above are the design target, not the implementation ceiling.*


| Action | XP Awarded |
| --- | --- |
| First hive inspection of the week (per hive) | 5 XP |
| Spotting the queen during inspection | +15 XP bonus |
| Identifying a health issue during inspection | +10 XP bonus |
| Successful harvest (≥5 lbs) | 20 XP |
| Successful hive split (new colony viable) | 35 XP |
| Catching a swarm | 40 XP |
| Confirmed varroa treatment (post-treatment count below threshold) | 15 XP |
| Raising a queen to laying status | 50 XP |
| Knowledge Log entry unlocked (first time) | 20 XP |
| Hive survives winter (spring bonus, per hive) | 25 XP |
| Honey sale revenue (per $10 earned, rounded down) | 2 XP |
| Daily task completed | 10–30 XP (based on complexity) |
| Seasonal goal completed | 75–200 XP |
| NPC quest completed | 50–150 XP |
| Mastery quest completed | 200 XP |
| Forage garden bed planted (per bed, first time) | 10 XP |
| Forage garden first bloom of season (per plant species) | 15 XP |
| Full forage garden established (all beds planted) | 20 XP |
| Hive observation session (entrance watching) | 5–8 XP (diminishing; max 2/week) |
| Equipment crafted at workbench (frames, boxes, feeders) | 15–25 XP (based on complexity) |
| Wax product batch completed (candles, lip balm, polish) | 20 XP |
| CVBA club meeting attended | 30 XP (monthly) |
| Uncle Bob mentorship visit | 20–25 XP (bi-weekly) |
| Routine mite monitoring completed (per hive, per count) | 5 XP |
| Study session completed (Knowledge Log library) | 10 XP (max 1/week) |
| Saturday Market participation (sales completed) | 15–25 XP |


*Design Note: The energy system (§5.4) is the sole pacing mechanic. References to "work slots" in earlier versions of this document are retired — energy cost per action is the implementation of finite-action pressure. There is no separate work slot system.*

#### 7.1.1 Year 1 Early-Game Activities (2-Hive Downtime)

A new beekeeper with 2 hives has roughly one meaningful hive inspection per week and a lot of open time in between. Without additional activities, Year 1 feels empty — there is not enough colony management to fill the week, and the player has no way to earn XP between inspections. The following activity categories are designed specifically for this window: they are things a real first-year beekeeper would naturally do, they are genuinely enjoyable, and they produce tangible in-game payoffs that compound into later seasons.


| Activity | Description | Year 1 Availability | Payoff |
| --- | --- | --- | --- |
| Forage Garden | Plant bee-friendly species (clover, wild bergamot, coneflower, anise hyssop, sunflower) in beds on the home property. Seeds ordered from Tanner's Supply or saved from season prior. Activities: bed prep, planting, occasional watering, seed saving in fall. | Available from game start. Seeds at Tanner's from early spring. | Each established species adds NU to the Home Apiary forage pool from Year 2 onward. Teaches forage timing. Connects to §14 (Forage System). XP from planting, bloom milestones, and full-garden completion. |
| Hive Observation Sessions | Spend 30 in-game minutes watching the hive entrance. Observe forager traffic, note pollen colors being carried in, watch for robbing, drift, or unusual behavior. No tools required. Low energy cost. | Available from game start. Diminishing XP return after 2 sessions per week. | Unlocks behavioral Knowledge Log entries ("What heavy forager traffic means," "Identifying robbing behavior," etc.). Teaches the player to read hive health between inspections — a real beekeeper skill that scales into late game. XP: 5–8 per session. |
| Workbench Crafting | Using the basic workbench already in the shed, the player can build additional frames, assemble an extra super, build a sugar feeder, or paint hive boxes. Uses materials from Tanner's Supply. Cheaper than buying finished equipment. | Available from game start. Predates the Crafting Station (Level 2 unlock). | Saves money vs. buying. Produces usable equipment. XP: 15–25 per item. Prepares the player to engage with the full Crafting Station system at Level 2. |
| Kitchen Wax Rendering | Process cappings wax from harvest using a double-boiler kitchen setup. Produces: standard candles (sellable at Saturday Market), lip balm, or equipment wood polish. Predates the Honey House and Crafting Station. | Available after first harvest (typically mid-summer Year 1). | Minor income. Satisfying loop. Unlocks wax Knowledge Log entries. XP: 20 per batch. Introduces the crafting economy the player expands at Level 2–3. |
| CVBA Club Meetings | Monthly gathering at the Grange Hall. A speaker presents on a beekeeping topic (varroa management, queen biology, honey marketing, etc.). NPCs present include Dr. Harwick, Lloyd Petersen, and rotating community members. | Available from game start. One meeting per in-game month. | XP: 30 per meeting. Unlocks a Knowledge Log entry tied to that month's topic. Introduces NPCs whose quest chains open in Year 2+. Builds community standing passively. |
| Uncle Bob Mentorship Visits | Visit Uncle Bob at his property (he has 3 hives). The player observes his operation, asks questions, and occasionally helps with a task. Available bi-weekly. Dialogue expands as the NPC relationship deepens. | Available from game start. Bi-weekly frequency. Primary vehicle for his Year 1 NPC quest chain. | XP: 20–25 per visit. Unlocks Knowledge Log entries from his demonstrations. Advances his quest chain (which unlocks the Timber & Woodlot apiary site at Level 2). Teaches practices the player hasn't yet encountered in their own hives. |
| Routine Mite Monitoring | A quick bi-weekly alcohol wash or sugar roll for each hive. Takes minimal energy. Feeds data into the varroa simulation, allowing the player to catch mite buildup before it becomes a crisis. Builds the habit early. | Available from game start. Bi-weekly per hive. | XP: 5 per count. Small but consistent. Teaches the most important preventive habit in beekeeping. Data informs the varroa simulation — players who monitor regularly are less likely to be surprised by a varroa event. |
| Study Sessions | Spend an evening reading from the Knowledge Log library (extension publications, beginner manuals, reference texts). Unlocks a Knowledge Log entry proactively — before the player encounters it in the field. | Available from game start. Limited to 1 session per week. | XP: 10 per session. Gives the player agency over what they learn next. Good "rainy day" or low-energy-day activity. Prevents knowledge gaps that lead to avoidable mistakes. |
| Saturday Market Participation | Attend the Saturday Market even with limited inventory — wax goods, a few jars of honey, or forage herbs from the garden. Social event: NPC conversations, community standing, occasional random events regardless of inventory. | Available from game start. Weekly on Saturdays. | XP: 15–25 per market day for completed sales. Small community standing for attendance alone. Introduces the market economy and NPC cast. Wax goods provide meaningful income before the first honey harvest. |


*Design Note: These activities are not mandatory — the player can ignore the forage garden or skip club meetings. But a player who engages with them will hit the Level 2 threshold right at season's end as intended, while a player who only inspects their 2 hives will fall meaningfully short, creating a natural incentive to explore without forcing it. The activities also serve a secondary purpose: they teach systems that become important later (forage management, market economy, NPC relationships, varroa habits) so that Year 2 unlocks feel earned rather than sudden.*

### 7.2 Apiary Structures


| Structure | Function | Unlock |
| --- | --- | --- |
| Basic Shed | Stores equipment and tools. Protects equipment from weather degradation. | Available from start |
| Crafting Station | Required for all crafting beyond raw honey jarring. | Year 1, Level 2 |
| Manual Extraction Area | Outdoor processing spot near the shed. Player uses hand tools (comb scraper, hand spinner, bottling kit) purchased from catalogue. Slow, energy-intensive, +1.5% moisture penalty. The authentic first-year experience. | Available from start (tools purchased separately) |
| Honey House (Dilapidated) | Uncle Bob's old honey house. Visible on the home property from game start but inaccessible -- broken windows, sagging roof, rusted equipment inside. A visual promise of what's to come. Examining it triggers Silas Crenshaw's quest chain. | Visible from start (non-functional) |
| Honey House (Restored) | Full indoor extraction facility with hand-crank 2-frame extractor, settling bucket, bottling station. Faster processing, lower energy cost, no moisture penalty. Restored through Silas Q1-Q3. | Mid-summer Y1 (Silas quest chain + ~$230 in materials/labor) |
| Honey House (Upgraded) | Temperature-controlled curing room added. 4-frame extractor, proper bottling line. Curing bonus: -0.8% moisture. The full professional setup. | Year 2, Level 2 (Silas Q4 + ~$375 in materials/labor) |
| Fermentation Room | Required for mead production. Stable temperature environment. | Year 2, Level 3 |
| Queen Rearing Area | Allows player to raise queens from their own best stock. | Year 3, Level 4 |
| Observation Hive | Glass-sided hive. Provides continuous passive health data on one colony. | Year 3, Level 4 |
| Apiary #2 | A second physical apiary location with its own forage zone. | Year 2, Level 3 |
| Additional Apiaries | Further expansion. Each has unique forage potential and seasonal characteristics. | Year 3+, Level 4+ |


#### Location Unlock Conditions — Full Specification


| Location | Unlock Condition | Cost |
| --- | --- | --- |
| Home Property | Available from start | Free |
| County Road (ambient forage access) | Available from start | Free |
| Town Garden (Cedar Bend) | Year 1, Uncle Bob beautification quest + donate 2 lbs honey to the project | 2 lbs honey (donated, no cash) |
| Timber & Woodlot | Level 2 + Lloyd Petersen quest chain (3 quests, via Darlene introduction) | $200 site clearing fee paid to Lloyd |
| Harmon Farm / Orchard | Level 2–3, Kacey Harmon friendship level 3 (3 quests). No monetary cost — the arrangement is pollination services in exchange for apiary access. | Free (service exchange) |
| River Bottom | Level 3 + Community Standing ≥ 500 (Respected tier) + Cedar Valley Beekeepers Association quest completion | $500 site preparation and seasonal lease |


### 7.3 Knowledge Log

The Knowledge Log is the player's personal field notebook. It fills in as the player encounters new situations, discoveries, and outcomes. Entries are written in first-person beekeeper voice and serve as both lore and tutorial reinforcement.

Unlocked by observation (finding AFB for the first time, catching a swarm, seeing DWV symptoms)

Each entry includes a plain-language description of the phenomenon and what the player should do next time

Late-game entries go deeper — discussing the ecology, science, and history behind what the player is experiencing

The complete Knowledge Log is a meaningful in-game reward: it is effectively a beekeeping primer written in the player's voice

#### Knowledge Log — Entry List (Representative)

The Knowledge Log contains approximately 40–50 entries that unlock progressively across a full playthrough. Below is the representative set that must be authored and coded. Entries marked "Auto" unlock from simulation events; entries marked "Action" require a specific player action.

**Early Game (Year 1)**


| Title | Trigger | Type | Summary Content |
| --- | --- | --- | --- |
| First Inspection | Complete first hive inspection | Auto | Frame anatomy, what to look for, why inspections matter. |
| Eggs and Their Meaning | Identify eggs during inspection | Action | If you can see fresh eggs, the queen was present within 1–3 days. This is the most important diagnostic in beekeeping. |
| Reading Brood Pattern | Inspect 3 different frames | Auto | Solid vs. spotty brood and what it tells you about queen health and larval mortality. |
| The Varroa Problem | Perform first varroa count | Action | Varroa biology, why it kills colonies, the critical fall treatment window. |
| Nectar Flow Begins | First week of positive honey weight gain observed | Auto | What nectar flow is, how to recognize it, when to add supers and why timing matters. |
| Smoker Technique | Complete inspection with low alarm response | Auto | Why smoke works (simulates forest fire, triggers feeding response), how to read bee reactions to smoke quality. |
| The Queen — First Contact | Spot the queen for the first time | Action | How to identify the queen by size, abdomen shape, and movement. Why she matters above all else. |
| Winter Check Basics | Perform first warm-day winter check | Action | What hive weight, entrance activity, and dead bee accumulation tell you during winter without opening the hive. |


**Mid Game (Year 2–3)**


| Title | Trigger | Type | Summary Content |
| --- | --- | --- | --- |
| The Brood Nest Arc | Identify a healthy concentric brood arc | Action | How the queen works outward from center, what deviation from the arc pattern means. |
| Varroa Treatment Windows | Complete first varroa treatment | Action | Fall treatment timing is critical. Winter bees raised after a mite crash are the bees that decide if the colony survives. |
| Swarm Impulse | First swarm or queen cell found | Auto | Why bees swarm (reproductive success, not a failure), early warning signs, prevention strategies. |
| Splitting a Hive | Complete first successful split | Action | How to make a viable split, what each half needs, how to introduce a new queen. |
| Honey-Bound Crisis | First honey-bound state detected | Auto | Why bees fill the brood nest with honey, its connection to swarming, how to respond. |
| Forager Burnout | Colony declines sharply after a major nectar flow | Auto | High-yield nectar flows exhaust foragers faster. The "post-flow slump" is real and predictable. Plan for it. |
| Winter Bees — The Key to Survival | Colony population contracts in Reaping month | Auto | Fat body physiology, vitellogenin, why fall-raised bees are qualitatively different from summer bees, why mite load in fall is existential. |
| AFB — Know the Signs | Inspect a hive with any active disease | Auto | How to recognize AFB — color, smell, the ropiness test. What to do if you suspect it. |
| Queen Marking | First queen marking (requires marking pen, Year 3) | Action | International color-year system. How marking helps track queen age. Marked queens 30% easier to spot during inspection. |


**Late Game (Year 4–5)**


| Title | Trigger | Type | Summary Content |
| --- | --- | --- | --- |
| Queen Genetics | Begin queen rearing process | Action | What traits are heritable, how to evaluate for selection, the regression-to-mean principle. |
| Drone Congregation Areas | Observe strong drone flight during DCA season | Auto | How DCAs work, why mating location affects genetic diversity, why the River Bottom produces better-mated queens. |
| Varietal Honey | Complete first labeled varietal honey harvest | Action | What makes honey monofloral, how flavor profiles form from forage dominance, why varietal commands a premium. |
| Beekeeper's Eye | Reach Level 4 | Auto | What experienced beekeepers notice at a glance — entrance traffic, dead bee patterns, hive weight, bee temperament. The whole-hive picture vs. the frame-by-frame view. |
| Resistance Rotation | Use the same varroa treatment type for 3+ consecutive years | Auto | Why mite resistance to synthetic treatments develops, how to rotate treatment types to maintain efficacy. |


---

[< Core Game Systems](06-Core-Game-Systems) | [Home](Home) | [Quests & Events >](08-Quests-and-Events)