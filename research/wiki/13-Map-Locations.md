[< Setting & World Overview](12-Setting-and-World-Overview) | [Home](Home) | [Forage Pool & Nectar Mechanic >](14-Forage-Pool-and-Nectar-Mechanic)

---

# Map Locations


### 13.1 The Home Property

The home property is the game's anchor — the first scene the player ever sees and the one they return to most. It must read immediately as a working rural homestead: lived-in, functional, and full of quiet detail. Every element on this scene either serves a gameplay purpose or communicates something true about the character who lives here.

Scene Layout & Spatial Design

The scene is a side-scrolling or slight top-down-perspective view, roughly 3–4 screens wide. The player navigates it by walking left or right. The camera follows the player character but the full scene is wider than the viewport, so the player must physically travel between areas.


| Overall dimensions | Approximately 80×40 meters of usable space. Wide enough that the far edges feel like a separate trip, but not so large that travel feels like a chore. |
| --- | --- |
| Camera | Slight downward angle (isometric-adjacent or 2.5D) — enough to see the ground plane, the tops of hive bodies, and the organic wildflower patches. Not top-down. Think Stardew Valley's angle but slightly more portrait. |
| Zone layout (left to right) | Far left: Darlene's fence line and neighbor view. Center-left: house exterior and garden. Center: apiary clearing. Center-right: shed / honey house. Far right: back field gate. |
| Depth layers | Foreground: player, hives, wildflower patches, walkways. Mid-ground: house, shed, fence, mature trees. Background: rolling hills, distant farm fields, sky. Background is parallax-scrolled, not interactive. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| House exterior | A single-story white clapboard farmhouse. Front porch with two steps. Screen door. One visible window with curtains. Flower box under the window. Modest but well-kept. Approximately 12m wide × 6m tall in world space. | Must have an interactive trigger on the door — entering opens the house interior sub-scene. Seasonal variants: summer has open windows; winter has smoke from chimney and snow on roof. Spring has mud on the steps. |
| House interior (sub-scene) | A warm kitchen/living room. Wood table (Knowledge Log interaction point), woodstove or radiator, window looking out toward the apiary, coat hooks with beekeeping gear, a shelf with honey jars. Approximately 8×5m. | Interior is only accessible when player is at the house door. Separate subscene loaded on entry. Crafting bench is in this room early-game. In winter this is a primary activity hub — make it feel inviting. |
| Honey House (dilapidated) | A small timber-frame building approximately 8m wide x 5m tall, set between the shed and the apiary clearing. Visible from game start in a state of disrepair: sagging roof with missing shingles, broken windows boarded with plywood, weathered door hanging off one hinge, weeds growing around the foundation. Uncle Bob's old extraction facility. Through the broken windows the player can glimpse rusted equipment inside -- a tantalizing preview of what the building will become. | Non-interactive until the player examines it (triggers Silas Q1). During Silas's quest chain, the building visually transforms over 7 in-game days: scaffolding appears (day 1-2), new roof goes on (day 3-4), windows replaced (day 5), door hung and exterior painted (day 6-7). After restoration, it becomes the Honey House interior sub-scene with extraction equipment. The Tier 2 upgrade (Silas Q4) adds a visible curing room extension on the right side. |
| Shed exterior | A weathered red/brown wooden shed, approximately 6m wide x 4m tall. Sliding barn door (always slightly ajar in active seasons). Hive tool, smoker, and spare frames visible on the exterior wall. A rain gauge mounted by the door. | Door is interactive -- opens the shed interior sub-scene. Storage and workbench facility. Separate from the Honey House. |
| Shed interior (sub-scene) | Workbench along one wall. Pegboard with tools. Shelving with spare equipment. In early game: spare frames, smoker fuel, treatments. In late game: extraction equipment, bottling station. | Tool storage here affects what the player can do in the field. Inspect the shed to see what's in stock. Frame-building minigame happens at the workbench. |
| Apiary clearing | A flat, south-facing area with a low white picket fence on three sides. The ground is slightly elevated above the surrounding lawn on a simple wooden platform/stand system. 5 hive slots clearly marked — either by existing stands or by visible cleared areas awaiting hives. | Each hive slot is a distinct interactive object. Empty slots show a faint outline or cleared grass patch. Hives placed here are full 3D-ish sprites with visual state (entrance activity, propolis staining, snow cover in winter). The fence should have a gate that the player opens when inspecting. |
| Hive stand sprites (×5) | Simple wooden two-post stands, approximately 40cm tall. Each one can hold a bottom board + hive body + super stack. The stack grows visibly as supers are added — a single hive might be 1 box tall in spring, 3–4 boxes tall in peak summer. | Hive sprite is a composite: bottom board + N hive body segments + M super segments + lid. Each segment is a separate sprite layer. Bees are a particle system at the entrance, density driven by forager population. |
| Organic wildflower system | Flowers spawn organically across grass tiles based on seasonal quality ranking (S/A/B/C/D/F). Each flower type has a realistic bloom window and spreads to adjacent tiles during its lifecycle. No garden beds — all flowers grow naturally in the grass. B rank (average) supports 1–2 hives. | FlowerLifecycleManager spawns individual flower sprites per tile with random rotation, scale, and alpha variation for organic appearance. Flowers fade in at bloom start, reach full intensity at peak, and fade out at bloom end. Transparent-background sprites overlay grass tiles seamlessly. |
| Back field gate | A simple metal farm gate in a wire fence. Beyond it is the back field — a larger grass and planting area. Gate is locked (tutorial interaction) until unlocked in Year 1 progression. | The back field is either a separate sub-scene or a continuation of the main scene to the right. Recommend separate sub-scene for performance. Gate opening is a milestone moment. |
| Back field (sub-scene) | Open grass area approximately 40×30m. Grid of plantable tiles visible as slightly raised squares in the grass. Tree planting spots marked with small stakes in Year 1. Mature planted trees are large persistent sprites that grow across seasons/years. | This is the long-horizon investment zone. Tree sprites must have Year 1 (sapling), Year 2 (small tree), Year 3 (young tree), Year 4+ (mature, blooming) variants. Each variant is swapped at season start. |
| Darlene's fence line | A wooden post-and-board fence running the left edge of the scene. Darlene's property is visible beyond — her house porch, her hives in a row (always 3 hives, tidy and established). She is sometimes visible on her porch or walking near the fence. | This is a non-interactive background for most of the game. Darlene as an NPC sprite appears here when she is 'home.' Player walks to the fence to trigger dialogue. Her hives should look healthier and more established than the player's in Year 1 — a visual goal-setting tool. |
| Lawn grass tiles | The connective tissue of the scene. Standard green grass with mowing state (short/medium/long). Long grass generates dandelion scatter in Quickening/Greening. Short grass does not. | Mowing is an optional player action. The visual difference between mowed and unmowed should be clear. Dandelion scatter is procedural over the grass tile layer using the annual roll density (see Section 14.8). |
| Seasonal modifiers | Spring: mud patches, puddles near the fence, dandelions spreading across the grass, lilac bloom on windbreak. Summer: full green, bees visible at hive entrances, clover and bergamot in bloom. Fall: leaf litter, golden light, goldenrod and aster along field edges. Winter: snow layer over everything, smoke from chimney, frozen puddles, no flowers. | Seasonal variants are palette swaps + additive sprite layers (snow, leaf litter, bloom overlay). Do not rebuild geometry — overlay and recolor. A single CanvasLayer with seasonal modifiers can handle this efficiently. |
| Ambient wildlife | Occasional robin, starling, or sparrow on the fence. A butterfly near the garden in summer. Fireflies at dusk in Wide-Clover and High-Sun. These are ambient particle/sprite systems, not interactable. | Run on a random timer. Do not spawn if the player is in an active task. These details make the world feel alive at low implementation cost. |


Lighting & Time-of-Day


| Pre-dawn (4:00–6:00) | Dark blue ambient. Hives are still. No bee particles. A single light in the house window (kitchen light on). Stars visible in background. |
| --- | --- |
| Morning (6:00–10:00) | Warm golden-pink light from the right (east). Long shadows to the left. Bee particles begin appearing at hive entrances. Dew sparkle on grass tiles. |
| Midday (10:00–14:00) | High white-yellow light, short shadows. Maximum bee activity at entrances. Wildflowers at peak visibility. |
| Afternoon (14:00–18:00) | Warm amber-gold light from the right shifting. Slightly hazy. Bees returning to hives — entrance activity visible in both directions. |
| Evening (18:00–21:00) | Orange-pink sky. Long shadows. Bees mostly in hive. House window light comes on. Fireflies in summer. |
| Night (21:00–4:00) | Deep blue-black. House interior light visible from windows. Hives quiet. Stars. Moon if appropriate for season. |


*Design Note: The lighting system is the most cost-effective way to make the scene feel alive across the day. A single global tint CanvasLayer driven by the in-game clock handles most of this. The sun position can be faked with a directional light2D whose angle and color change on the clock signal. Shadows should be baked sprites, not real-time — this is a 2D scene.*

Home Property Forage Profile


| Quickening (Spring M1) | Lilac windbreak provides first pollen. Dandelions in the lawn if unmowed. Very limited — supplements needed. |
| --- | --- |
| Greening (Spring M2) | Home garden flowers in bloom. Back field clover if seeded. Modest flow. |
| Wide-Clover / High-Sun | Full garden and back field in production. Fruit trees contribute by Year 3. |
| Full-Earth / Reaping | Asters and goldenrod in field edges if planted. Flow tapers off. |
| Deepcold / Kindlemonth | No forage. Bees on stores. |
| Forage Cap | 5 hives at full production capacity with a well-developed home garden and back field. |


#### Hive Component Build Sequence

Hives on the Home Property (and all other apiary locations) are built component by component rather than placed as a complete unit. This reflects real beekeeping practice and gives the player a tactile sense of assembling their equipment. The build state is tracked per hive object in `hive.gd`.


| Step | Item Required | Build State After | Visual / Prompt |
| --- | --- | --- | --- |
| 1. Place Stand | Hive Stand ($18) | STAND_PLACED | Bare stand sprite. Prompt: "Add Deep Body" |
| 2. Add Deep Body | Deep Body ($35) — active slot, E near stand | BODY_ADDED | Stand + box sprite (empty). Prompt: "Add Frames / Lid" |
| 3. Add Frames | Frames ($18/10pk) — active slot, E near body | FRAMES_PARTIAL (1–9) or stays BODY_ADDED (0) | Frame indicator updates. As many frames as inventory holds, up to 10. Prompt: "Frames X/10 · Lid?" |
| 4. Add Lid | Hive Lid ($12) — active slot, E near body/frames | COMPLETE | Full hive sprite with lid. Colony simulation begins. Prompt: "[E] Inspect" |


A **Complete Hive** item ($85 at Cedar Bend Feed & Supply) skips the build sequence entirely — it places a stand + deep body + 10 frames + lid as one action. This is the legacy behavior and is kept for convenience. Components can be purchased individually for lower total cost ($18 + $35 + $18 + $12 = $83 vs. $85 pre-assembled).

Inspection is only available on COMPLETE hives. Hives in intermediate build states display a context-appropriate prompt but cannot be opened for frame inspection. The simulation (varroa, honey production, colony health) only runs on COMPLETE hives.

### 13.2 The County Road

The county road is a transitional scene — it is the between-places space that makes the world feel physically connected. The player arrives here when leaving the home property headed anywhere, and it is where the map navigation interface lives. It should feel like a real gravel road in Cedar Bend County, not a loading screen.

Scene Layout & Spatial Design


| Dimensions | Approximately 60m wide × 25m tall. Narrower than the home property — it is a corridor, not a destination. |
| --- | --- |
| Perspective | Same angle as home property. The road runs left-to-right across the scene. The player character stands beside the truck, which is parked on the right shoulder. |
| Zone layout | Left: road continuing toward home (implied, off-screen). Center: the road itself with the parked truck. Right: road continuing toward town (implied). Background left: Harmon farm fields. Background right: tree line and water tower silhouette of Cedar Bend. |
| Navigation trigger | Clicking/interacting with the truck dash or a destination sign post opens the map overlay. Destinations are shown as named pins on a simple illustrated county map. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| Gravel road | Two-lane gravel road running the width of the scene. Slightly crowned center. Tire track ruts in spring. Dusty heat shimmer texture in High-Sun. Snow-packed and plowed in Deepcold. | The road surface is a tileable texture with seasonal variants. Spring variant has visible wet-dark gravel and puddles in the ruts. Summer is dry pale grey. Fall has scattered leaves. Winter is packed snow with a central cleared strip. |
| Player's truck | A mid-2000s pickup truck, well-used but maintained. The bed holds equipment in active seasons. Parked on the right shoulder, nose pointing right (toward town). Cab interior is partially visible — radio dial, hanging bee gauge, worn seat. | The truck is the player's travel anchor. It should feel personal and earned. Seasonal variants: summer has a window cracked; winter has frost on the windshield in morning hours. The truck cab is a simple interior overlay that appears when the player 'gets in' to open the map. |
| Road ditches | Both sides of the road have ~3m grassy ditch areas. Left ditch faces the Harmon fields. Right ditch faces the tree line. Ditch grass generates goldenrod (Full-Earth) and wildflower scatter using the same procedural system as the home property lawn. | The ditch is non-interactive forage — it contributes to the regional pool but the player cannot tend it. Its visual state changes with the annual forage rolls just like plantable areas. |
| Harmon farm fields (background) | Rolling crop field extending to the horizon on the left side. In corn years: bare soil in spring → green rows in summer → brown stalks in fall → bare in winter. In soybean years: different growth profile, shorter canopy. | This is the crop rotation visual. The field is a background layer that swaps its sprite based on the current year's crop AND the current season. The player reads this as a forage signal — if they see corn, they know it is a low-forage year. |
| Grain elevator | Mid-distance on the right side, visible above the tree line. A classic Midwest cylindrical concrete elevator with a bin cluster and conveyor leg. Not interactive — pure atmosphere. | Static background element. In fall it shows activity (lights on, dust rising from loading). In winter it is quiet. This establishes the agricultural scale of the region. |
| Water tower | Far background right, above the tree line. Reads as 'Cedar Bend is that way.' Simple blue-grey cylinder on legs. Optionally has a faint town name painted on it. | Static background element. Acts as a persistent directional cue — the player always knows which way town is. |
| Mailbox | A rural mailbox on a post at the left edge of the road scene, positioned as if belonging to an unseen neighbor. Occasionally has a red flag up — this is a passive notification that something has arrived (bee packages in spring, supply orders). | The mailbox flag is driven by game state, not random. When the player has a pending delivery, the flag goes up on the road scene. Interacting with the mailbox triggers the pickup/notification. This is more atmospheric than a UI popup. |
| Seasonal road details | Spring: mud puddle in a low spot in the road, tire tracks in the soft shoulder, leftover sand/salt from winter plowing. Summer: heat haze shimmer effect on the road surface (shader effect), dust trail fading in air when the player arrives. Fall: leaf scatter across the road surface, frost on the grass early mornings. Winter: snow banks on both shoulders from plowing. | These are additive particle and overlay effects, not geometry changes. A CanvasLayer with seasonal variants handles most of this efficiently. |
| Map overlay (UI layer) | When the player opens the truck cab or interacts with a destination sign, a hand-drawn illustrated county map slides in from the right. It shows the home property, Cedar Bend, the timber, the Harmon farm, and the river bottom as illustrated landmarks. Locked locations are greyed out with a padlock icon. | The map is a UI element, not a world asset — but it should be designed to feel like an in-world object (a paper map, not a digital HUD). Warm parchment background, hand-lettered location names, illustrated topography. Locations unlock progressively and animate in when first discovered. |


### 13.3 The Town of Cedar Bend

Cedar Bend is not a large town but it must feel like a real one — a specific place with a character, a history, and people who have been here their whole lives. The town scene is a single main street view, navigated by walking. The player cannot enter every building — only the key locations that serve gameplay functions. The rest is dressed background.

Scene Layout & Spatial Design


| Dimensions | Approximately 120m wide × 30m tall. The widest scene in the game. The player walks the full length to reach different destinations. |
| --- | --- |
| Perspective | Same angle as all other scenes. Street runs left-to-right. Buildings face forward (toward the player) with visible facades, signage, and windows. |
| Zone layout | Far left: residential houses trailing off, the grain elevator beyond. Left-center: Tanner's Supply feed store + Post Office. Center: The Crossroads Diner + Saturday Market area. Right-center: Dr. Harwick's experienced local beekeeper + Grange Hall. Far right: fairgrounds entrance gate (visible but only accessible during fair season). |
| Time of day | Most businesses are open 8:00–18:00. The diner is open 6:00–21:00. At night the main street has amber streetlight pools and dark storefronts. On Saturday mornings (market day) the center of town fills with market booth sprites. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| Main street ground | Cracked blacktop with painted center line, faded. Sidewalks on both sides: concrete slabs with grass growing through cracks. The kind of sidewalk that has been here since 1955 and nobody has fully fixed it. | The street surface is a wide tileable texture. The cracks and aging are baked into the texture, not real-time. Seasonal variants: puddles in spring, bright in summer, leaf-strewn in fall, snow-cleared center with piles at curbs in winter. |
| The Crossroads Diner | A classic 1960s diner: long horizontal building, glass block windows, a neon 'OPEN' sign (lit during hours), a hand-lettered specials board visible through the window. Counter seating visible through the front window. A pie case is backlit. A bell above the door. | The diner has the most animation of any town building. During open hours: warm interior light spills through windows, occasional silhouette movement inside, steam from the kitchen exhaust vent. The NPC schedule means certain NPCs are visible inside at their regular times (Uncle Bob on Tuesday mornings is a silhouette at the counter). |
| Diner interior (sub-scene) | Counter with 8 stools, 4 booths along the window. A pie case. A coffee station. Black-and-white photos of old Cedar Bend on the walls. Chalkboard menu. A TV above the counter (local news, weather). | The interior is a separate sub-scene. The player sits at the counter or a booth to order. The waitress NPC (minor character, named, consistent) takes the order. Meals appear as simple food sprites. The TV shows a weather graphic that reflects the actual in-game weather forecast — this is an elegant way to surface weather data without a HUD widget. |
| Tanner's Supply | A working farm supply store: green metal siding, a loading dock on the right side, pallets of bag goods visible through the open bay door. A hand-painted sign. Seed company logos on a banner. A bulletin board by the front door. | The bulletin board is an interactive object — it shows bee package availability, local notices, and periodic community events. The store interior loads as a sub-scene with shelving, products, and Carl Tanner behind the counter. Seasonal stock changes the shelving sprite (spring: package bee flats and seed displays; fall: winter prep supplies; winter: quiet, reduced stock). |
| Post Office | A small federal building: brick, American flag, black lettering on the door. A single step up to the entrance. A package notice board by the door. | The post office is a focused interaction: the player enters, June (the postmaster) is behind the counter, she hands over packages or confirms shipments. The interior is minimal — counter, pigeonhole mail sorters, the buzzing package box in spring. |
| Saturday Market (seasonal overlay) | When it is Saturday and spring–fall, the center section of the main street has a market overlay: white tent canopies, tables of produce and goods, people browsing. The player has their own booth in this setup. | The market is a Saturday-only scene overlay. On non-market days, the center street is clear. On market days, the tent and booth sprites activate. The player's booth is interactive — they set prices, display their honey, and respond to buyers. Booth quality and display upgrades are visible as improved furniture and signage. |
| Dr. Harwick's experienced local beekeeper | A modest institutional building at the edge of town: plain brick, a university extension banner, a parking lot with two cars, a small experimental garden bed in front (labeled plant varieties). | The office interior is a waiting room + consultation desk. Dr. Harwick sits at her desk surrounded by agricultural reference materials and pest specimens in jars. The player submits samples here and returns days later for results — a physical version of a crafting timer. |
| Grange Hall | A community hall: white painted wood, a marquee sign showing the next meeting date, a parking lot. Classic Midwest vernacular architecture — could be a church or a VFW. | The hall interior is active only on meeting nights (one evening per in-game month). Folding chairs in rows, a lectern, tables along the walls with equipment for trade. When inactive, the hall interior is dark and the front door locked. |
| County Fairgrounds gate | A wide entry gate at the far right of the town scene: wooden arch with 'Millhaven County Fair' painted across it, ticket booths on either side. Only accessible during the fair event in High-Sun. | The gate is always visible but locked with an INACTIVE overlay outside fair season. When the fair is active, the gate opens, colored banners appear, and crowd ambient sound begins. The fairgrounds are a separate sub-scene accessed through this gate. |
| Fairgrounds (sub-scene) | A classic county fair layout: midway with game booths, a livestock/exhibit barn, a competition pavilion (honey judging here), a food vendor row, and a show ring. Crowded and colorful. | The fairgrounds sub-scene is the largest and most complex non-home scene. The honey judging happens in the pavilion — a focused minigame where the player submits jars and receives scores with qualitative feedback. The bee beard competition is a spectator event the player watches. |
| Background buildings (dressed set) | A hardware store, a bar, a small library, a bank — visible facades only. Some have people walking past. None are interactive. They complete the street. | These are static sprites with window light states (on/off by time of day). No sub-scenes. They exist to make the town feel inhabited and full rather than a series of isolated gameplay objects. |
| People on the street | A handful of townspeople walk the sidewalk at various times of day. They are ambient sprites: 4–6 unique character designs that cycle randomly. They do not initiate dialogue but may comment passively when the player walks near. | Ambient pedestrians are a simple sprite animation system on a random walk path between defined waypoints. They do not pathfind around the player — they either continue or stop and idle. Their presence/absence follows the time of day (busy at noon, quiet at 7am and 8pm). |


### 13.4 The Timber & Woodlot

The timber is the most atmospherically distinct location in the game. It feels older and deeper than the home property or town — a place that predates farming, that has its own rhythms and its own risks. The linden trees that make it so valuable beekeeping-wise also make it visually spectacular in Wide-Clover, when the whole canopy smells of honey and every tree is covered in bees.

Scene Layout & Spatial Design


| Dimensions | Approximately 80m wide × 35m tall. Slightly narrower than the home property but with more vertical layering from the tree canopy. |
| --- | --- |
| Perspective | Same base angle but the canopy is more prominent — large tree trunks in the foreground, filtered light through the canopy above, the ground plane lower in frame than in the open scenes. |
| Zone layout | Far left: timber edge, dense canopy, Lloyd Petersen's access path. Left-center: creekside (with willows — earliest spring pollen source). Center: the apiary clearing. Center-right: the linden grove (key summer visual). Far right: a diseased tree section (cleared as part of the access quest, then replanted). |
| Seasonal access | In Quickening (early spring), the access road is flooded. The scene is inaccessible and shows a FLOODED ROAD notification instead. By Greening week 2 the water recedes. This is a hard gate, not a gradual unlock. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| Tree canopy system | 4–5 species of hardwood trees rendered at large scale: silver maple (medium crown, winged samaras in spring), cottonwood (tall, narrow, cottony seed release in summer), basswood/linden (wide crown, small yellow-white flower clusters in Wide-Clover), wild plum (shrub-scale, white bloom in Greening). Each species needs 3–5 trunk+crown sprite variants for visual variety. | Trees are layered: foreground trunks (dark, detailed) block the player and frame the scene. Mid-ground trees are slightly desaturated. Background is a painted sky-and-canopy backdrop. The canopy layer has a wind animation: a gentle sway shader on the leaf layer. Seasonal crown variants swap at season transitions. |
| Creek | A shallow creek running left to right across the lower portion of the scene. Visible stone bed. Clear water with a subtle flow animation. Willows overhang the near bank. The creek is high and fast in Quickening (spring thaw), low and clear in High-Sun, and partially iced at the edges in Deepcold. | The creek is a background element with a water surface shader (ripple + refraction). The water level changes with season: spring is noticeably higher with turbid color; summer is clear and low; winter has ice crystal overlay at the edges. The player cannot interact with the creek directly but can see it behind the apiary area. |
| Apiary clearing | A sun-dappled opening in the timber edge — the old fence-post remnants of a former pasture corner. Flat ground, morning sun, afternoon shade from the canopy. 6 hive slots on simple rough-hewn wooden stands. A rusted water trough (repurposed as a bee water source). A wide stump that serves as a worktable for inspections. | Same hive slot system as the home property but rendered in a rougher, more natural style. Stands are weathered wood, not painted. The stump/worktable is a fixed prop — the player places tools on it during inspection events. The area has leaf-fall overlay in Full-Earth and snow dusting in Deepcold. |
| Linden grove | 4–6 mature basswood/linden trees in a loose cluster to the right of the apiary clearing. In Wide-Clover they carry their small yellow-green flower clusters — the scene has a warm golden-amber light tint in this period and the air above the trees has a heavy bee particle system (more bees visible here than anywhere in the game). | The linden bloom is the scene's signature visual moment. In Wide-Clover, activate: intensified bee particle system over the grove, a golden canopy tint, and a soft ambient nectar-smell visual effect (gentle golden particles drifting down from the canopy). This should feel like standing inside a flow. Non-bloom seasons the grove is simply green or bare — the contrast emphasizes the bloom's value. |
| Lloyd Petersen | An elderly man in worn work clothes and a canvas hat. He appears near the creek path or the timber edge, checking on trees, cutting away deadfall, occasionally sitting on a log with a thermos. He has his own idle animations: examining bark, looking up at the canopy, writing in a small notebook. | Lloyd is a semi-random presence — he is here 3–4 days per week in active seasons. He is never here in Deepcold or when the road is flooded. His appearance triggers the possibility of a conversation. He does not approach the player — the player approaches him. His dialogue is specifically about what he observes that day: a particular tree's condition, an unusual weather pattern, the quality of the creek water. |
| Diseased tree section (left edge) | Before the access quest: a section of dead and diseased elm trees, gray and bare with shelf fungi, some fallen. After the quest (Lloyd's access quest involves helping clear this): the section is cleared, stumps visible, and a row of young replacement trees planted — willows and wild plum, which become forage assets in years 2–3. | This is a before/after visual that marks the player's investment in the location. The transition is not animated — it simply swaps the sprite set when the quest completes. The new plantings have sapling sprites that grow each season. |
| Flooded road overlay | For Quickening weeks 1–2, the access road is shown with standing water across it. A simple scene-entry block: instead of entering the timber scene, the player sees a message overlay on a thumbnail of the flooded road. | This is not a full scene — it is a notification image with a 'Come back in a few days' message. The road itself does not need to be a separate asset; a simple water overlay on the standard road entrance sprite is sufficient. |


### 13.5 The Harmon Farm

The Harmon farm is the game's most functionally dynamic location — it changes based on the crop rotation, the player's relationship with the family, and the season. It must look and feel like a working operation, not a decorative set piece. The farmyard has a lived-in messiness: a tractor parked with the door open, a barn cat sleeping on the hay bales, equipment scattered with purpose.

Scene Layout & Spatial Design


| Dimensions | Approximately 100m wide × 35m tall. Wide enough to show the farmstead on the left and the field extending to the horizon on the right. |
| --- | --- |
| Perspective | Same angle. The farmyard occupies the left third. The field occupies the right two-thirds. The boundary between farmyard and field is a dirt lane with a gate. |
| Zone layout | Far left: farmhouse and front yard. Center-left: barn, machine shed, grain bins. Center: farmyard lane with access to the orchard (northwest corner, behind the barn). Center-right: field gate and near-field edge. Right: crop field extending to horizon. Background: rolling hills, neighbor properties. |
| Orchard | The old orchard (apple, cherry, pear) is accessed via a path behind the barn. It is a separate sub-area of the same scene — the player walks behind the barn to find it. The orchard is invisible and inaccessible until the relationship with the Harmons is established. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| Farmhouse | A two-story white clapboard farmhouse, larger and older than the player's house. A wraparound porch. A mudroom extension on the side. Visible barn boots by the door. A weather vane on the rooftop. An American flag on a pole. | Walt Harmon is often visible on the porch or in the driveway. Kacey's car (a newer compact) is parked in the driveway when she is home. The house is not fully interactive early-game — the player can walk up and knock but Walt is terse until the relationship develops. Later, Kacey invites the player inside for key dialogue scenes. |
| Farmhouse interior (sub-scene, unlocked mid-game) | A working farmhouse kitchen: practical, not decorated. Farm records on the table. A laptop open with crop planning software (Kacey's). Old seed company calendars on the wall. A window overlooking the fields. | Interior is unlocked after the first successful Kacey quest. This is where key quest dialogue scenes happen. The table with farm records is interactive — Kacey can show the player the crop rotation plan, which reveals future year forage conditions. |
| Barn | A classic red gambrel-roof barn, large. Sliding doors on the front face, one open. Inside visible: hay bales, a tractor, milking equipment from a previous era (this farm stopped running cattle years ago). Swallow nests visible in the gable. | The barn is a navigable interior (simple left-right layout, no sub-scene required). It is where Walt Harmon is often found in active seasons. Equipment stored here includes the sprayer — the player can see it parked, which is a visual cue that a pesticide event may be coming. |
| Machine shed | A metal pole building behind the barn. The large roll-up door is usually open. A combine, a planter, and the crop sprayer are parked inside. The sprayer is the key visual indicator — when it is being prepared (moved forward, fuel cans visible), a pesticide event is imminent. | The machine shed is a passive information source. The player does not need to interact with it directly — they simply observe. The sprayer sprite changes state: parked deep inside (no event) → moved to the front (event in 1–2 days) → gone (event active) → back inside (event over). |
| Grain bins | Two or three large corrugated metal grain bins (24–36 ft diameter) with aeration fans and hatches. The bins fill in fall and empty through winter. A conveyor auger is parked alongside. | Grain bins are atmospheric background assets. Their visual state (full/empty) tracks the harvest season. Autumn: bins are full, auger attached. Winter/spring: bins are partially empty or empty. This is background farming detail that makes the world feel economically real. |
| Crop field | The large field occupying the right portion of the scene. Crop state reflects year (corn/soybeans) AND season. Corn: bare soil → green rows → full height (taller than a person) → brown harvest-ready → stubble. Soybeans: bare soil → low canopy → mid canopy → yellowing → stubble. | The field is a background sprite layer with seasonal-and-year variants. At least 4 growth stage variants per crop type. The field grid is implied by the row pattern, not explicitly drawn as a simulation grid. A separate far-background layer shows the rolling fields beyond as hills of color. |
| Orchard (sub-area) | 12–15 mature fruit trees (apple, cherry, pear) in 3 rows, behind the barn and slightly elevated. The orchard floor is grass with clover growing between the trees. A simple wooden ladder leans against one tree. The tree sprites need bloom variants (Greening), full-leaf variants, and fall color / bare variants. | The orchard becomes the Harmon Orchard apiary location when unlocked. Hive slots appear here (4 total) and the player places and manages hives among the trees. Bloom season in Greening — when the trees are covered in white and pink blossoms and the hives are active — is a specific beautiful scene that rewards the relationship investment. |
| Field edge goldenrod | The untended margins between field and fence line generate goldenrod in Full-Earth using the same scatter system as all other scenes. These margins are where the Harmon farm contributes to the regional forage pool if unmowed. | The Kacey quest line includes asking the Harmons to leave the field margins unmowed. Before the quest resolves, the margins are short-cut. After the quest, the margins are longer and generate the full goldenrod scatter. This is a persistent visible change to the scene. |
| Walt Harmon sprite | A heavyset man in his late 50s, worn denim and a cap. Slow, deliberate movements. He is most often near the barn, the machine shed, or the field gate. He has a reserved posture when talking to the player early in the relationship — arms crossed, short answers. | Walt's posture changes as the relationship develops. Year 1: arms crossed, positioned slightly turned away. Year 2: more open stance, occasional nod. Year 3+: he meets the player at the gate, offers coffee, names the player by name in dialogue. These are behavioral animation states, not just dialogue changes. |
| Kacey Harmon sprite | A woman in her late 20s, practical outdoors clothes (not glamorous farmer aesthetic — she is a working agronomist). Laptop bag over her shoulder. More energetic movement than Walt. Often in the farmyard or the barn office corner she has set up. | Kacey is the player's primary point of contact at this location. She initiates quest conversations rather than waiting to be approached. Her sprite should communicate agency and purpose — she is doing things when the player arrives, not standing idle. |


### 13.6 The River Bottom

The river bottom is the game's most remote and most atmospheric location. It must feel genuinely far from the farmstead — wilder, wetter, more primal. The Cedar Bend River is a real presence here, not just background detail. The scene should be the most beautiful in the game in Full-Earth (golden wildflower meadow, heavy bees, late afternoon amber light on the water) and the most menacing in Quickening (high brown water, muddy banks, flooded low spots).

Scene Layout & Spatial Design


| Dimensions | Approximately 90m wide × 40m tall. The tallest scene in the game due to the river and the elevated bank. |
| --- | --- |
| Perspective | Slight angle change from other scenes — the river runs diagonally across the mid-ground from upper-left to lower-right, giving a sense of depth not achievable in a fully horizontal scene. The apiary clearing is on a raised flat bank above the flood plain. |
| Zone layout | Far left: willow thicket (earliest spring pollen, atmospheric). Center-left: access path from the road (muddy two-track). Center: the apiary clearing on elevated bank. Center-right: native wildflower meadow (primary summer forage). Far right: cottonwood flat tapering to the river bend. Background: the river itself, the far bank, rolling hills beyond. |
| Flooding zone | The lower portion of the scene (between the access path and the apiary clearing) is in the flood plain. In Quickening, this area is covered in standing water 1–2 weeks. Hives on standard stands are at risk; hives on elevated stands are not. The flooding is a persistent visual that the player can see before committing to entry. |


Required Scene Assets


| Asset | Description & Specs | Notes for Implementation |
| --- | --- | --- |
| The Cedar Bend River | A medium-width river (20–30m wide in world space) visible in the mid-to-background. Brown and fast in spring, clear and slower in summer, lower in fall with exposed gravel bars, partially frozen with ice shelves in winter. The far bank is a line of cottonwoods and scrub. | The river is primarily a background visual. The water surface is a shader effect (flow direction mapped, surface ripples, color varies by season: turbid brown in spring, clear blue-green in summer). The river level changes visually between seasons — spring shows the bank at the water's edge; summer shows a 2–3m gravel/mud margin between water and vegetation. |
| Willow thicket | A dense stand of large willows at the left edge of the scene, their branches trailing into the water. Catkins are visible in Quickening — yellow-green clusters on bare branches before any leaves appear. By Wide-Clover they are in full leaf. In Deepcold they are bare grey whips over snow. | The willows are the game's earliest spring pollen source and should be visually prominent in Quickening. Recommend a golden-yellow branch tint in early spring (catkin bloom) that is distinct from any other location's spring color. The bee particle system activates over the willows earlier than anywhere else in the game — this is a visual signal that spring has truly begun. |
| Native wildflower meadow | A large open meadow to the right of the apiary clearing. In summer it is a complex mix of prairie species: coneflower, bergamot, black-eyed Susan, ironweed, milkweed. In Full-Earth it transitions to goldenrod and aster dominance — tall gold and purple. This meadow is the richest single forage source in the game. | The meadow uses a dense flower sprite layer over the grass base. Each bloom period should have a distinct color palette: Wide-Clover/High-Sun is warm yellow and purple; Full-Earth is bold gold (goldenrod) fading to pale purple (aster). The meadow has the most intensive bee particle system in the game during peak flow — this location should feel almost electric with activity in summer. |
| Apiary clearing (elevated bank) | A flat grassy shelf 2–3m above the normal flood level. Old fence posts from a former grazing setup mark the edges. 8 hive slots on rough wooden stands, elevated on 50cm legs (the elevated stands that protect from flooding). A large cottonwood at the clearing edge provides afternoon shade. A flat river stone serves as a worktable. | Same hive slot system as other apiaries but with the elevated stand variant. The elevated stands are a visual and mechanical upgrade — they cost in-game materials to build but prevent flood damage. Standard stands are visible here too as an option; they are cheaper but have flood risk. The player chooses per-slot. |
| Flood plain (seasonal hazard zone) | The low ground between the access path and the elevated bank. In Quickening, this is 30–60cm of standing water — visible as a flat reflective surface covering the lower zone. Approaching it on foot is possible but slow (wading). Hives on standard stands here are submerged. | The flood plain is a zone modifier, not a separate asset. The water is a flat transparent layer that activates over the base ground in spring weeks 1–2. It has a gentle ripple shader and reflects the sky color. The player character wades through it (slowed movement animation, water splash particles) or avoids it by staying on the elevated bank. |
| Cottonwood flat | A stand of large cottonwood trees at the far right. Huge trunks. Cottony seed release in Wide-Clover — visible as white fluffy particles drifting across the scene (purely atmospheric). In fall: golden-yellow leaf color. In winter: bare cathedral arches of branches. | The cottonwood seed release is one of the game's most atmospheric visual moments. A particle system of slow-drifting white fluff fills the scene for 1–2 in-game weeks in late spring. It does not affect gameplay — it is pure sensory pleasure. Use a CanvasLayer particle system with a very slow downward drift and slight horizontal wind influence. |
| Terri Vogel sprite | A woman in her 40s, experienced beekeeper energy. Wears her gear more casually than the player character — veil pushed back, not wearing gloves because she has long-since earned the confidence. She is often found inspecting her own hives (she has 3 hives at the far right of the clearing) or walking the meadow edge. | Terri's hives are visible and can be observed from a distance. The player cannot inspect Terri's hives but can see their status and entrance activity. In High-Sun she is often pulling frames — visible through the same inspection animation the player uses, creating a sense of shared practice. Terri's hives are always healthy (they serve as a visual benchmark). |
| Ambient wildlife | This scene should have the richest ambient wildlife: herons standing in the shallows (visible in background), kingfisher movement over the water, frogs audible at dawn and dusk (sound only), dragonflies over the meadow in summer, red-winged blackbirds on the willow stems. | These are ambient sprite animations on random timers. None are interactive. The heron is the highest-value: a large, slow-moving bird that appears in the river background once or twice per real-time visit. Its presence signals a healthy river ecosystem — subtle world-building. Dragonfly sprites are small fast-moving sprites over the meadow in summer only. |


### 13.7 Location Summary


| Location | Max Hives | Unlock |
| --- | --- | --- |
| Home Property | 5 | Available from start |
| The Timber (Woodlot) | 6 | Year 2 — Lloyd Petersen quest via Darlene |
| Harmon Orchard | 4 | Year 2–3 — Kacey Harmon relationship quest |
| River Bottom | 8 | Year 3 — Cedar Valley Beekeepers Association standing |
| Town Garden | 2 | Year 2 — Uncle Bob town beautification quest (bonus small location) |


Total maximum hives across all locations: 25. This is the practical late-game ceiling for a solo beekeeper operation. Managing all 25 well is a genuine achievement.

#### Queen Marking — Color System

Queen marking pens are unlocked at Level 3 (Year 3). Marking does not affect queen behavior but provides two practical benefits: the queen is 30% easier to spot during frame inspection, and her age is immediately trackable by color.

Smoke & Honey uses the international Koschevnikov color rotation system, which is the real-world standard used by commercial beekeepers worldwide:


| Year Ending In | Color |
| --- | --- |
| 1 or 6 | White |
| 2 or 7 | Yellow |
| 3 or 8 | Red |
| 4 or 9 | Green |
| 5 or 0 | Blue |


The in-game year maps to this rotation. A queen raised in Year 2 receives yellow; Year 3 receives red. A player who sees an old red mark on a queen they think is young knows immediately that the queen is older than expected — possibly a laying worker situation or a quiet supersedure they missed.

---

[< Setting & World Overview](12-Setting-and-World-Overview) | [Home](Home) | [Forage Pool & Nectar Mechanic >](14-Forage-Pool-and-Nectar-Mechanic)