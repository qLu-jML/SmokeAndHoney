[< Game Overview](04-Game-Overview) | [Home](Home) | [Core Game Systems >](06-Core-Game-Systems)

---

# Time & Calendar System


Smoke & Honey uses a real-time day/night cycle and a structured seasonal calendar. Time passes continuously while the player is active. The calendar provides the long-term structure — seasons, months, years — while the day/night cycle and the player's energy bar govern what gets done each day.

### 5.1 Calendar Structure


| Year | 4 seasons. One full year = 8 months = 32 weeks = 224 days. |
| --- | --- |
| Season | 2 months per season. Each season is 56 days (8 weeks of 7 days). |
| Month | 4 weeks / 28 days. Each month has a proper name drawn from the agricultural and natural character of that period. |
| Week | 7 days. The primary rhythm for hive management — most inspection and maintenance decisions are made on a weekly cadence. |
| Day | 24 in-game hours. Each real-time minute = 1 in-game hour. One full in-game day takes 24 real-time minutes to complete at normal speed. |


#### The Eight Months of Cedar Bend

Cedar Bend's calendar uses traditional agricultural month names passed down through the farming communities of Millhaven County. They are not the months of the outside world — they are the months of this land, named for what happens in them.


| Month | Season / Position | Character & Meaning |
| --- | --- | --- |
| Quickening | Spring, Month 1 (Days 1–28) | The world wakes up. Ice thaws. The first willow catkins appear. Bees take their first cleansing flights. Named for the quickening of life returning to the ground after winter's hold. Everything is uncertain and fragile and full of possibility. |
| Greening | Spring, Month 2 (Days 29–56) | Dandelions bloom. Fruit trees flower. The colony explodes with new bees. The land goes from grey to vivid green almost overnight. Named for the transformation that happens when warmth finally holds. The most beautiful month and the most anxious for the beekeeper. |
| Wide-Clover | Summer, Month 3 (Days 57–84) | The clover flows. Bees work the fields from first light to dusk. Honey frames fill steadily. Named for the wide open sea of white and red clover that covers the fields and roadsides in Cedar Bend County's summer. The beekeeper's richest and most demanding month. |
| High-Sun | Summer, Month 4 (Days 85–112) | Peak heat. Linden fades. The midsummer dearth may arrive. Goldenrod is still weeks away. Named for the ruthless midday sun of a Cedar Bend August. Beautiful and relentless. The harvest window opens late in this month — pull your good honey before it's too late. |
| Full-Earth | Fall, Month 5 (Days 113–140) | The goldenrod burns gold along every fence line and ditch row. The main harvest happens. Hives are heavy and the air smells of ripe honey. Named for the earth at its most full — the culmination of everything the year built toward. Beekeepers work fast and sleep well. |
| Reaping | Fall, Month 6 (Days 141–168) | The first frosts come. Goldenrod ends. Hives are closed up for winter. Feed syrup goes on. The last accounting of the year — did you leave enough? Named for the act of taking what's owed and leaving what's needed. A month of honest reckoning. |
| Deepcold | Winter, Month 7 (Days 169–196) | True winter. Snow covers the fields. Bees are clustered. No inspections, no harvests. The beekeeper makes frames, renders wax, brews mead, and waits. Named for the cold that settles into the ground and stays. Quiet, dark, and necessary. |
| Kindlemonth | Winter, Month 8 (Days 197–224) | The cold remains but the light is returning. Days are lengthening. The queen may begin laying again late in the month. The beekeeper orders bees, plans spring apiaries, and tends the fire. Named for the kindling of warmth and hope that precedes the new year. Quickening is coming. |


*Design Note: The month names are part of the world's texture — NPCs use them in dialogue. Darlene says 'It's Reaping already and you haven't checked your stores?' Uncle Bob says 'Wide-Clover honey is what my customers want — get me ten jars by the end of the month.' The names ground the player in Cedar Bend's rhythm rather than the calendar of the outside world.*

Seasonal Reference Quick Table


| Season | Months | Days | Primary Focus |
| --- | --- | --- | --- |
| Spring | Quickening + Greening (Months 1–2) | Days 1–56 |  |
| Summer | Wide-Clover + High-Sun (Months 3–4) | Days 57–112 |  |
| Fall | Full-Earth + Reaping (Months 5–6) | Days 113–168 |  |
| Winter | Deepcold + Kindlemonth (Months 7–8) | Days 169–224 |  |


*Design Note: The 2-month season is calibrated so that a player who checks in for 20–30 minutes per day (one in-game day) completes one season in roughly 8 weeks of real time. Players who play longer sessions advance faster.*

### 5.2 Day/Night Cycle

The in-game world runs on a continuous 24-hour clock. Each real-time minute equals one in-game hour. A full day cycles through distinct time periods that affect what the player can do and what the world looks like.


| Time of Day | In-Game Hours | World State & Player Availability |
| --- | --- | --- |
| Pre-dawn | 4:00 – 6:00 | Dark, quiet. Hives are still. No bee activity visible. Player can walk the property, review notes, or start early preparation. No inspections. |
| Morning | 6:00 – 10:00 | Light rising. Best inspection window opens around 8:00 when temperatures warm and foragers begin leaving. Bees are calm. All outdoor actions available. |
| Midday | 10:00 – 14:00 | Peak forager activity. Brood box inspections are easiest — most foragers are away, hive is calmer and less crowded. Prime work window. |
| Afternoon | 14:00 – 18:00 | Foragers returning. Hive activity high. Inspections become more difficult as the hive fills. Harvest prep, crafting, and travel are good afternoon tasks. |
| Evening | 18:00 – 21:00 | Foragers home. Bees defensive near entrances. No inspections recommended. Market trips, feed store visits, and social calls (NPC conversations) available in town. |
| Night | 21:00 – 4:00 | Dark. Bees clustered. All outdoor hive work is unavailable. Player can craft indoors, review the Knowledge Log, plan next day's tasks, or go to bed. |


*Design Note: The time-of-day window for inspections is not arbitrary — it mirrors real beekeeping practice. Inspecting in the morning when foragers are out means fewer bees in the box, calmer bees, and easier queen-finding. Evening inspections agitate a full hive with all bees home. New players who learn this will instinctively schedule their days correctly.*

### 5.3 Day Advancement

The day does not advance automatically at midnight. The player controls when the day ends. This gives players the flexibility to pace their own sessions without being locked to a real-time schedule.


| Sleep (recommended) | Player goes to bed from the house interior. Triggers a rest sequence (brief fade, morning ambience). Day advances to the following morning at 6:00. Energy bar fully restored. This is the normal end-of-day action. |
| --- | --- |
| Stay up all night | The player can remain active through the night. At midnight, the energy bar continues depleting. A player who pushes through all 24 hours will arrive at the next morning with a severely depleted energy bar. All actions for that day will be slow and limited. There is no game penalty beyond the energy consequence — it is a player choice. |
| Nap (partial rest) | The player can lie down during the day for a short nap (2–3 in-game hours). Restores approximately 25–30% of the energy bar. Costs time. Useful if the player runs low early but has important evening tasks remaining. |
| Time skip | From the pause menu, the player can skip forward to a chosen hour (morning, midday, evening) without sleeping. Energy does not restore. The world advances. Used to skip nighttime quickly without sleeping — useful for players who want to start the next morning immediately. |


### 5.4 Player Energy System

The energy bar is the player's daily resource. It represents the physical stamina of the beekeeper — a real constraint that prevents the player from cramming unlimited tasks into a single day and forces prioritization. It is not a punishment mechanic; it is the game's pacing layer.

Energy Bar Properties


| Maximum capacity | 100 energy. Displayed as a simple bar in the HUD. No numerical readout — just the bar, which the player learns to read intuitively. |
| --- | --- |
| Starting state | Full (100) at the start of every day after a full night's sleep. Partially restored after eating. Not restored by any other means. |
| Depletion rate | Each player action costs energy proportional to its physical demand. Light tasks (reviewing notes, talking to NPCs) cost very little. Heavy tasks (full hive inspection, extracting honey, building frames) cost significantly more. |
| Depletion over time | Standing around or traveling costs a small passive energy drain — about 1–2 energy per in-game hour. A player who stays active all day without sleeping will deplete their bar even between tasks. |
| Warning states | Bar color shifts: green (full) → yellow (50%) → orange (25%) → red (10%). At red, the player moves slightly slower and a visual fatigue effect (subtle screen edge softening) appears. Tasks can still be performed. |
| Empty bar | When the energy bar reaches 0, the player cannot perform any active task. They can still walk, talk to NPCs, and review menus — but no physical work is possible. The game gently prompts: 'You're exhausted. Time to rest.' The player can still choose to go to bed or eat to partially recover. |


Energy Costs by Task


| Task Category | Example Tasks | Energy Cost |
| --- | --- | --- |
| Very Light | Reviewing the Knowledge Log, talking to an NPC, checking a hive entrance from outside, reviewing market prices | 1–3 energy |
| Light | Traveling between locations, checking hive weight (hive scale), placing a feeding shim, checking a sticky board | 3–8 energy |
| Moderate | Full hive inspection (one hive), planting a flower bed, performing a sugar roll mite count, bottling honey jars | 10–18 energy |
| Heavy | Full inspection of multiple hives back-to-back, harvesting a super (pulling, transporting, uncapping), building new frames | 18–28 energy per session |
| Very Heavy | Full honey extraction day (multiple supers), assembling a new hive body, splitting a hive and installing a new package | 25–40 energy |
| Exhausting | A full day of heavy beekeeping — inspecting 5+ hives, treating, and harvesting in sequence without rest | Depletes bar fully. Should require two days or a town meal break. |


#### Bee Stings — Energy Loss Hazard

Bee stings are an inevitability when working with bees. Each sting costs the player energy, representing pain, swelling, and distraction. Stings are rolled during hive inspection (see §6.1 Sting Probability Model below). The player can mitigate sting frequency through protective equipment and proper smoker use.


| Sting energy cost | Each sting deducts 5–8 energy from the player's current total. Multiple stings in a single inspection stack. |
| --- | --- |
| Bee suit (worn) | Wearing a bee suit reduces sting probability by 80%. The suit is a purchasable/craftable piece of equipment that must be equipped before beginning an inspection. |
| Smoker use (pre-inspection) | Properly smoking the hive before inspection provides an additional 15% reduction in sting probability. This stacks with the bee suit. A player wearing a suit who also smokes the hive has a combined 95% reduction in sting chance (calculated as: base chance × 0.20 × 0.85). |
| No protection | Without a suit or smoke, the player faces the full base sting probability each inspection step. This is punishing but survivable — new players learn quickly to gear up. |


*Design Note: Energy costs are calibrated so that a full day's sleep allows a player to accomplish one major task (like a full inspection round) plus several lighter supporting tasks. A player who wants to do everything in one day will need to eat in town. This creates a natural reason to go to town mid-week beyond just shopping — it is the energy management strategy for ambitious days.*

Energy Restoration


| Full night's sleep | Restores to 100. The only way to fully restore. Go to bed from the house interior between 20:00 and 04:00. |
| --- | --- |
| Eating at the diner | The Crossroads Diner in Cedar Bend serves breakfast, lunch, and dinner. Each meal restores 40–50 energy. A player can eat once per meal period (morning, midday, evening) for partial restoration. Cost: a small in-game money charge. Eating twice in the same meal period has no additional benefit — the player is full. |
| Packed lunch | The player can pack a lunch at home before heading out (a morning kitchen interaction). Restores 20 energy when consumed at any point during the day. Cheaper than the diner but less effective. Useful for remote apiary days. |
| Coffee (morning only) | A cup of coffee from the diner or the kitchen adds a temporary 15-energy burst and prevents the passive drain for 2 in-game hours. Only effective before 10:00. No effect if taken later in the day. |
| Nap | Lying down for 2–3 in-game hours restores ~25 energy. Costs time. Can be done at home or in the truck (parked at a remote location). |


### 5.5 The Crossroads Diner

The diner is a functional location in Cedar Bend (the game's fictional Midwest town — see Section 13.3) that serves as the player's primary mid-day energy recovery option and a social hub. It is not a complex system — it is a simple but atmospheric stop that makes going to town feel like a real part of the day rather than just a commercial transaction.


| Name | The Crossroads Diner. A classic Midwest diner on the main street of Cedar Bend. Counter seating, vinyl booths, a pie case. |
| --- | --- |
| Hours | Open 6:00 – 21:00. Breakfast menu until 11:00. Lunch 11:00–15:00. Dinner 15:00–21:00. Each service window has a different menu and energy restoration amount. |
| Breakfast | Eggs, toast, coffee. 40 energy. Available 6:00–11:00. Cheapest meal. The morning fuel-up before a heavy work day. |
| Lunch | Daily special (rotates by season — summer has BLTs and corn chowder; fall has beef stew; winter has pie and hot soup). 45 energy. Mid-range price. |
| Dinner | Larger plate. 50 energy. Most expensive but most restoring. Best used when the player has worked hard all day and needs to push through an evening task. |
| Coffee | Available all day. 15 energy burst + 2-hour passive drain suppression. Only full effect before 10:00. After that, just a small comfort bonus. |
| NPC presence | NPCs are sometimes at the diner at specific times. Uncle Bob eats breakfast there on Tuesdays. Darlene stops in for coffee on Friday mornings. These are opportunities for relationship-building dialogue that only trigger in this setting. |
| Atmosphere | The diner changes with the season and time of day. Early morning: quiet, radio playing farm market reports. Lunch: busier, locals discussing the weather and harvest. Evening: winding down, local news on the TV above the counter. |


*Design Note: The diner is deliberately simple — it is not a cooking minigame or a relationship sim. It is a functional pitstop that gives the player a reason to be in town beyond errands, adds atmosphere to Cedar Bend, and creates natural moments for NPC encounters that feel organic rather than quest-triggered.*

#### Crossroads Diner — Prices


| Item | Cost | Energy Restored | Available |
| --- | --- | --- | --- |
| Coffee | $2 | 15 energy burst + passive drain suppressed for 2 hours | All day (6:00–21:00) |
| Breakfast | $7 | 40 energy | Morning (6:00–11:00) |
| Lunch — Daily Special | $9 | 45 energy | Midday (11:00–15:00) |
| Dinner | $12 | 50 energy | Evening (15:00–21:00) |
| Seasonal Special (pie, soup) | $10 | 45 energy + minor mood buff increasing XP gain by 5% for the remainder of the day | Seasonal menu rotation |


### 5.6 The Nectar Flow Calendar

Nectar flow is not constant. It follows a predictable but variable calendar based on the local flower mix and weather. Understanding the flow calendar is one of the highest-value skills the player can develop.


| Month | Flow Status | Player Implication |
| --- | --- | --- |
| Quickening (Spring Month 1) | Trickle flow from willows, silver maple. Dandelion roll outcome determines if a meaningful flow exists. | Stimulative feeding may be needed. Monitor dandelion density. Do not add supers yet. The year's first anxiety. |
| Greening (Spring Month 2) | Main spring flow — dandelions (if GOOD/EXCEPTIONAL), fruit blossoms, clover beginning. Colony population exploding. | Dandelion harvest decision. First super timing begins. Monitor for brood-bound conditions as population peaks. |
| Wide-Clover (Summer Month 1) | Primary flow — clover, borage, linden arriving late in the month. The richest forage window of the year. | Add supers as needed. Monitor space weekly. Brood-bound risk if the queen runs out of room. |
| High-Sun (Summer Month 2) | Linden fades mid-month. Mid-summer dearth possible. Goldenrod still weeks away. | CRITICAL: Pull premium summer supers before goldenrod begins late in the month. Protect honey quality. See Section 14.8.2. |
| Full-Earth (Fall Month 1) | Goldenrod primary flow. Roll outcome determines strength. The last major nectar input of the year. | Goldenrod honey decision. Winter store building. Fall feeding if POOR goldenrod year. |
| Reaping (Fall Month 2) | Flow ends. Frost terminates goldenrod. Bees shifting to consuming rather than collecting. | Final harvest window closed. Winter prep. Entrance reduction. Feeding if stores are insufficient. |
| Deepcold (Winter Month 1) | No flow. Bees in cluster. The hive is silent. | Warm-day weight checks only. Crafting, planning, ordering for spring. The patient month. |
| Kindlemonth (Winter Month 2) | No flow. Cluster consuming stores. Queen may begin very light laying in the final week as days lengthen. | Monitor cluster via hive weight. Order spring bees and equipment. Spring plan finalized. Quickening is coming. |


*Design Note: The flow calendar shifts based on what plants the player has cultivated and what trees have matured. A player who planted linden trees two years ago now has a longer, richer early summer flow. A player who developed the river bottom apiary has access to a wildflower flow that extends well into fall. Long-term investment in forage is the single highest-leverage action in the game.*

---

[< Game Overview](04-Game-Overview) | [Home](Home) | [Core Game Systems >](06-Core-Game-Systems)