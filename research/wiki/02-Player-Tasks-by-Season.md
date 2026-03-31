[< Player Overview](01-Player-Overview) | [Home](Home) | [Hive Object & Data Model >](03-Hive-Object-and-Data-Model)

---

# Player Tasks by Season


Each season's task table represents the real-world activities a beekeeper performs during that time of year. The Mechanic / Notes column maps each task to a specific game system — this column is the primary working space for feature development.

### 2.1 Spring

Spring is the most action-dense season. The player emerges from winter facing real losses and real decisions. Every week counts as the colony builds toward the first nectar flow.


| # | Task / Goal | Mechanic / Notes |
| --- | --- | --- |
| 1 | Evaluate hive loss from winter |  |
| 2 | Clean dead hives |  |
| 3 | Place order for more bees (packages, nucs, or full hives) |  |
| 4 | Craft or purchase supplies for making new hives |  |
| 5 | Assemble new hives and frames |  |
| 6 | Repair damaged hardware |  |
| 7 | Prepare apiaries: position hives ready for package and nuc installation |  |
| 8 | Manage apiary location relative to nectar sources, flowers, and farm fields |  |
| 9 | Monitor explosive spring growth — decide to split hives or allow swarming |  |
| 10 | Check queen status for all newly installed hives |  |


Spring Design Notes

*Design Note: Hive loss from winter should feel meaningful — not just a stat reset. Dead hives should leave visual evidence (dead cluster, empty frames, molded stores) that the player cleans up before reusing equipment.*

*Design Note: Ordering bees involves a lead time mechanic. Packages and nucs arrive on a future date based on supplier stock and shipping time. Players who plan ahead get better bees; last-minute orders may get lower-grade stock.*

*Design Note: The split vs. swarm decision is the first major strategic fork in the game. Letting a hive swarm loses half the workforce. Splitting correctly doubles the apiary but requires a good queen in each half.*

### 2.2 Summer

Summer is the peak production season. Colonies are at maximum strength, nectar flow is high, and the player must manage growth, space, and overcrowding simultaneously.


| # | Task / Goal | Mechanic / Notes |
| --- | --- | --- |
| 1 | Monitor growth and honey production to time the adding of supers | Honey-bound detection; see Section 3.8.B |
| 2 | Check hives for health, growth, and queen status | Frame inspection; brood pattern; see Section 3.8 |
| 3 | Prepare new possible apiary locations for expansion next year |  |
| 4 | Plant new flowers and plants around apiaries to support healthier forage | Forage pool investment; see Section 14 |
| 5 | Monitor for overcrowding — too many bees for the available nectar | Forage pool stressed/depleted signal; see Section 14.4 |
| 6 | Respond to brood-bound conditions — split, add deep body, or allow swarm | Brood-bound detection; strategic fork; see Section 3.8.B |
| 7 | Respond to honey-bound conditions — add super or harvest depending on season goal | Honey-bound detection; strategic fork; see Section 3.8.B |


Summer Design Notes

*Design Note: Super timing is the central skill of summer. Adding supers too late causes honey-bound brood boxes and triggers swarming. Adding them too early wastes space and creates cold spots. Players learn to read frame fullness as the signal.*

*Design Note: Overcrowding is distinct from swarming. A hive can be bee-dense but low on nectar during a dearth — bees become agitated and may rob neighboring hives. Players must reduce colony stress through feeding or mechanical intervention.*

*Design Note: Apiary scouting is a low-urgency summer task that pays off in spring. A good site needs: sun exposure, wind protection, water access, proximity to forage, and ease of vehicle access for equipment.*

### 2.3 Fall

Fall is the harvest season and the preparation season. Every decision made in fall directly determines whether colonies survive winter.


| # | Task / Goal | Mechanic / Notes |
| --- | --- | --- |
| 1 | Harvest honey |  |
| 2 | Prepare hives for winter |  |
| 3 | Evaluate hives for feeding requirements |  |
| 4 | Plant trees if possible |  |


Fall Design Notes

*Design Note: Harvest timing matters. Harvesting too early means uncapped (under-ripened) honey with high moisture content — it will ferment. Players must check frame cappings before pulling. A refractometer tool unlocks at a mid-game progression point.*

*Design Note: Winter prep is a multi-step process: reduce the entrance, add insulation or a moisture quilt, ensure adequate honey stores (a minimum weight threshold), check for a laying queen, and optionally wrap the hive for cold climates. Each step is a discrete player action.*

*Design Note: Tree planting is a long-horizon investment. Trees take multiple in-game seasons to mature. Early-game players who plant willows, lindens, or fruit trees will benefit significantly in later seasons — rewarding long-term thinking.*

### 2.4 Winter

Winter is the slow season. Direct hive intervention is minimal, but it is the best time to build, plan, and craft.


| # | Task / Goal | Mechanic / Notes |
| --- | --- | --- |
| 1 | Craft harvesting materials and equipment for the coming year |  |
| 2 | Craft value-added products: candles, mead, cosmetics |  |
| 3 | Ship finished goods or hold for seasonal market events |  |
| 4 | On warm days: check hive weight and entrance activity |  |
| 5 | Review the previous year — plan next spring's layout |  |
| 6 | Order queens, packages, or equipment for spring |  |


Winter Design Notes

*Design Note: Warm-day checks are passive observation only — no full inspections. The player can lift the back of the hive to feel weight (stores remaining), listen for cluster hum, and check for dead bees at the entrance. Opening the hive in cold weather breaks the cluster and can kill the colony.*

*Design Note: The ship-now vs. hold decision is the core economic tension of winter. Raw honey sells immediately at base price. Crafted goods sell for 2x–5x but require time, skill, and equipment. Market events in late winter offer a surge window.*

#### Winter Hive Check — Formal Mechanic

The warm-day hive check is a passive observation action available during Deepcold and Kindlemonth when the daily high temperature exceeds 45°F (7°C). It is available once per week per hive, costs 3 energy, and does not require opening the hive.


| Reading | Possible Results |
| --- | --- |
| Store Weight | Heavy (>50 lbs — good through winter), Adequate (30–50 lbs — monitor), Light (15–30 lbs — emergency feed when warm enough), Very Light (<15 lbs — likely lost) |
| Cluster Activity | Active (bees visible on sunny side — strong cluster), Quiet but alive (tapping produces audible hum), No response (unclear — may be normal in extreme cold, or dead) |
| Entrance Condition | Normal (few dead bees — expected winter attrition), Pile building (higher than normal mortality — investigate when warm), Clear (sealed tight — normal in very cold weather) |


*Design Note: Results are always presented as flavor text descriptions, never raw numbers. This preserves the observational learning loop — the player builds intuition about what "light" means through experience, not a readout. A Knowledge Log entry unlocks after the first check: "Winter Check Basics."*

### 2.5 All-Season Ongoing Tasks

These tasks apply every season and form the backbone of weekly gameplay. They are always present in the player's action queue.


| # | Task / Goal | Mechanic / Notes |
| --- | --- | --- |
| 1 | Weekly hive inspections | Core interaction loop; see Section 5.1 |
| 2 | Monitor general hive health indicators | Hidden composite score; player deduces from evidence |
| 3 | Monitor mite levels and treat if necessary | Varroa, tracheal mites; see Section 3.6 |
| 4 | Monitor queen health and laying status | Queen grade degrades over time; see Section 3.2 |
| 5 | Track honey production and recognize nectar flow | Flow calendar varies by region and flower mix |
| 6 | Respond to weather forecast | 3–5 day forecast; see Section 5.5 |
| 7 | Maintain equipment — clean, repair, replace | Neglected equipment reduces hive performance |
| 8 | Manage finances — balance income against expenses | Seasonal cash flow; see Section 5.7 |


**PART II**

**The Hives**

*Data models, colony mechanics, and everything that governs each beehive.*

---

[< Player Overview](01-Player-Overview) | [Home](Home) | [Hive Object & Data Model >](03-Hive-Object-and-Data-Model)