[< NPCs](09-NPCs) | [Home](Home) | [Monetization (TBD) >](11-Monetization)

---

# Art Direction & Audio


### 10.1 Visual Style


| Overall Style | Warm, muted, cozy top-down pixel art. Not cartoon-flat, not photorealistic. Think illustrated field guide meets Stardew Valley — pastoral, nostalgic, grounded. Everything feels lit by soft afternoon Iowa sunlight. Nothing is bright or over-saturated. |
| --- | --- |
| Perspective | True top-down with a very slight north-tilt (~15°) — the classic SNES/GBC RPG view. You see the roof of buildings from above and the front face below the roofline. This is the Stardew Valley / early Harvest Moon perspective. |
| Color Palette | Earthy and muted year-round, season-tinted. Base: muted olive-green grass, sandy tan dirt, warm gray stone, dark slate roofs, warm brown timber. Spring tint: soft green + cream. Summer: deep green + amber. Fall: burnt orange + burgundy. Winter: muted blue-gray + warm interior light. No pure saturated primaries. |
| Outlines | No pure black (#000000) outlines anywhere. Edges are formed by using the darkest shade of the local hue. This gives the art its soft, painterly quality and is the single most important stylistic rule for new assets. |
| Hive Frame Inspection | Separate close-up scene — front-facing view (not top-down). Higher detail than the overworld. Readable hexagonal cell grid; color-coded cell states (pale yellow empty comb, golden capped honey, tan capped brood, white larvae, egg dots). Bees have character but are not anthropomorphized. Uses the same warm amber/tan palette family. |
| Environment | Apiary grounds show growth over time. Planted trees grow visibly between years. Established apiaries feel lived-in. Ground cover and wildflowers change seasonally. Mowed vs. unmowed grass is visually distinct. |
| UI Philosophy | Almost no UI during normal play. The world is the interface. Data surfaces contextually: hover a hive to see a simple status icon; enter inspection mode for detail. UI elements are themed as Langstroth hive frames — thick wooden borders, honeycomb cell interiors, warm amber/beeswax color palette. Panels look like wooden frame components; buttons like individual wax cells; fill bars drain and fill cell-by-cell in amber honey tones. Skeuomorphic but restrained. No harsh beeps or mechanical clicks. See §10.1.4 for the full Langstroth Frame UI Design System specification. |
| Seasonal Transitions | Animated transition screen between seasons. Visual change to the apiary environment is gradual week-by-week, not sudden. Palette shift is applied as a screen-level tint layer over the base sprites — one sprite sheet serves all seasons. |


#### Visual Style — Technical Specifications


| Spec | Value |
| --- | --- |
| Base tile size | 16×16 pixels (matches the Cainos Village asset pack grid) |
| Small items / inventory icons | 16×16 pixels |
| Player character sprite | 120×120 pixels per frame — 8 directions; idle (1 frame/dir), walk (8 frames/dir), run (8 frames/dir). Single spritesheet 960×2880 px (8 cols × 24 rows). Runtime-loaded via Image.load_from_file(); no Godot import pipeline dependency. |
| NPC sprites | 120×120 pixels per frame. 8-direction movement; single spritesheet 960×2880 px per character (8 cols × 24 rows). Runtime-loaded via Image.load_from_file(); no Godot import pipeline dependency. Distinct silhouettes per character. |
| Building sprites | Multi-tile. Small structures ~48–64px wide; larger buildings ~80–96px wide. All rendered at slight north-tilt showing roof (dominant) and front facade (below roofline). Shadow is a separate sprite layer. |
| World perspective | Top-down with slight north-tilt. Camera is fixed overhead per scene. Scenes scroll; player walks through them. NOT side-scrolling. |
| Frame inspection view | Front-facing (portrait orientation). Not top-down. Higher fidelity — individual cells visible at 3–4px per cell. Separate scene loaded on inspect. |
| Shading depth | 2–3 tones per color family (mid → light highlight → dark shadow). Dithering used only on ground textures, not characters or buildings. |
| Shadow system | Objects cast soft drop shadows as a separate layer, offset slightly south-east. Shadow color = darkened desaturated ground color. Never baked into the sprite. |
| Visual references | Primary: Pixel Art Top Down – Village by Cainos (the foundation asset pack). Secondary: Stardew Valley (world scale, character charm), early Harvest Moon GBA (palette mood). Hive inspection: field guide illustration style, readable over cozy. |


#### 10.1.2 Asset Foundation & Art Direction

The visual foundation of Smoke & Honey is the ***Pixel Art Top Down – Village* asset pack by Cainos (v1.0.7)**, located in `assets/sprites/paid/`. This pack provides all core tilesets (grass, dirt, terrain), village buildings, props, plants, and particle effects. Every new asset created for the game — beehives, NPC characters, beekeeping tools, hive frame UI, market stalls — must match this pack's style precisely.

The pack's defining visual characteristics, in order of importance:

1. **No pure black outlines.** The single biggest differentiator. All edges use the darkest shade of the local hue. Violating this makes new assets look pasted-in and foreign.
2. **Muted, earthy palette.** Olive greens, sandy tans, warm gray stone, dark slate roofs, warm brown timber, muted teal water. No neon. No primaries. The whole scene should feel like one cohesive color family.
3. **2–3 shade depth per color.** Not flat, not over-rendered. Highlight, mid, shadow — that's the full range per color group.
4. **Soft drop shadows as a separate layer.** Never baked into the sprite. This allows shadow toggling and consistent lighting across scenes.
5. **Top-down slight north-tilt perspective.** Roofs are the dominant face of buildings. The front wall peeks out below the roofline. Ground tiles fill the rest.

#### Core Palette Reference


| Role | Description | Use in prompts |
| --- | --- | --- |
| Ground grass | Muted olive yellow-green, slightly dull | muted olive green ground |
| Dirt / path | Warm sandy tan, slight orange cast | sandy tan dirt path |
| Tree canopy | 3–4 tones: dark forest green → bright highlight dot | rounded fluffy olive-green tree canopy |
| Building wall | Cool mid-gray stone, or warm cream plaster | cool gray stone wall / warm cream plaster wall |
| Timber framing | Warm medium brown, amber highlights | warm brown half-timber frame |
| Roof | Dark slate gray, pixel-shaded depth | dark slate gray roof with pixel shading |
| Wood props | Tan-to-medium-brown barrels, crates | weathered wood brown |
| Honey / amber | Warm amber gold — #C8860A range | warm amber honey gold |
| Beekeeper suit | Off-white with warm cast — not pure white | off-white warm beekeeping suit |


#### 10.1.3 AI Asset Generation — PixelLab Prompt System

For assets not covered by the Cainos pack (beehives, beekeeper character, tools, hive frame UI, NPCs, bee-specific props), the project uses **PixelLab.ai** as the primary AI generation tool. All new assets must be generated using the master prompt block below as the base, with a subject-specific line appended. The full prompt guide with per-asset templates lives in `PIXELLAB_STYLE_GUIDE.md`.

#### Master Prompt Block

Paste this into every PixelLab generation, then add the subject line at the end:


```gdscript
top-down RPG pixel art, 16x16 tile grid, warm muted earthy palette,
olive-green grass, sandy tan dirt paths, half-timbered European village style,
slate gray roofs, warm brown timber framing, stone walls in cool gray,
soft ambient lighting from upper-left, 2-3 shade depth shading,
no hard black outlines (use darkened hue for shadows),
subtle pixel dithering on ground textures, rounded tree canopies
with highlight dots, cozy pastoral mood, Stardew Valley aesthetic,
in the style of Pixel Art Top Down Village by Cainos,
transparent background, [YOUR SUBJECT HERE]
```


#### Key Assets Needed (not covered by the Cainos pack)


| Asset | Size | Notes |
| --- | --- | --- |
| Langstroth beehive (overworld) | 16×24 px | Stacked white-painted wooden supers, top-down tilt view |
| Hive stand (overworld prop) | 16×8 px | Simple wooden stand, weathered brown |
| Bee swarm / flying bee particle | 8×8 px | Single bee sprite for particle system; warm golden-yellow + black stripe |
| Honey jar (inventory icon) | 16×16 px | Rounded amber glass jar, gold lid, highlight pixel |
| Beekeeper player sprite sheet | 120×120 px per frame | 8-dir movement; idle (1 frame), walk (8 frames), run (8 frames) per direction; white suit + mesh veil; spritesheet: beekeeper_spritesheet.png (960×2880, 8 cols × 24 rows) |
| Uncle Bob NPC sprite | 120×120 px per frame | Older man, denim overalls + plaid flannel, gray hair, warm tones; spritesheet: uncle_bob_spritesheet.png (960×2880, 8 cols × 24 rows); 8-dir movement matching beekeeper layout |
| Hive frame (inspection UI) | Front-facing, ~320×192 px | Different perspective from overworld — see Section 15.10 |
| Smoker tool (inventory icon) | 16×16 px | Tin cylinder, brown leather bellows, smoke wisp |
| Wildflower forage tile overlay | 16×16 px | Clover/dandelion pixels over standard grass tile |
| Saturday Market stall | 32×48 px | Tan/green striped awning, wooden counter, honey jars displayed |
| Cedar Bend Feed & Supply (building) | ~80×64 px | Tan clapboard siding, wooden porch, barrels; must match Cainos building style |
| Cedar Bend Diner (building) | ~80×64 px | Cream plaster, red-and-white striped awning, glass front door |


#### Style Rules for New Assets (enforce on every review)

- No pure black (#000000) outlines — always darkened hue
- No bright saturated colors — muted and earthy throughout
- No pure white backgrounds — always transparent PNG
- No fantasy or medieval theming on BeeKeeper-specific assets — this is rural Iowa
- No heavy dithering on characters or buildings — dithering is for ground tiles only
- Shadow is always a separate sprite, never baked in
- When in doubt: does it look like it belongs in the Cainos Village scene overview screenshot? If yes, ship it. If no, regenerate.

#### 10.1.4 Langstroth Frame UI Design System

All in-game UI elements follow the **Langstroth Frame Aesthetic** — a unified visual identity that treats every UI component as if it were crafted from the same wooden frames and beeswax comb that the player manages in the hive. This design language was established in the Phase 1 UI sprint and replaces any generic "wood/paper" UI treatment. Every UI asset lives in `assets/sprites/ui/`; preview composites in `assets/sprites/ui/previews/`.

#### Design Language Overview

A Langstroth frame is the rectangular wooden frame that hangs inside a hive box. It has a thick top bar, side bars, and bottom bar forming the frame body, with the interior filled by drawn honeycomb cells (hexagonal wax cells). The UI system translates this into interactive components:


| Component | Visual Metaphor | Asset(s) |
| --- | --- | --- |
| Panels / menus | Langstroth frame with thick wooden border (4px multi-tone), interior wax-cream background with subtle honeycomb cell overlay. Top header band is solid wood with grain lines. | menu_panel.png, dialogue_panel.png, panel_wood.png |
| Buttons | Individual honeycomb cell or small wooden frame segment. Normal: wax-cream interior with honeycomb dot pattern. Hover: amber-washed interior, brightened. Pressed: inverted shadow (sunken), darker amber fill — like a capped cell. | btn_normal.png, btn_hover.png, btn_pressed.png |
| Fill bars (XP, energy, honey) | A row of comb cells set into a wooden rail. Cells fill left-to-right with warm amber honey. Divider lines every cell-width. Background cells show empty-comb cream; filled cells show amber gold with highlight. No gradients — discrete cell fills only. | xp_bar.png, xp_bar_bg.png, xp_bar_fill.png, energy_bar_bg.png, energy_bar_fill.png |
| Toast notifications | Sticky note pinned to a frame — warm cream parchment body, amber top "tape" strip, torn left edge suggesting the note is pinned or peeled from the frame. Stack vertically from the top-right. | notification_bg.png |
| Dialogue boxes | Field inspection card / beekeeper's notebook page. Thick wooden outer frame border, solid wood top header bar (with grain lines), warm wax-paper interior with faint ruled lines. Portrait area inset on the left with its own wooden sub-frame. | dialogue_panel.png |
| Speech bubbles | Wooden-framed box with a triangular wooden tail pointing toward the speaker. Interior is wax-paper white with a very faint honeycomb overlay. Top edge is a thin header bar. | speech_bubble.png |
| Title plate | Rectangular wooden frame with an amber/honey recess panel inside. The amber recess is where the game title or panel title sits. Four corner nail markers at the frame joints. | title_plate.png |
| HUD bars | Langstroth top bar and bottom bar — thick horizontal wood rails across the full viewport width. Top bar: grain lines run horizontal; amber resin spots for texture. Bottom bar: lighter top face, deeper shadow bottom. Both are 16–20px tall. | hud_top_bar.png, hud_bottom_bar.png |
| Interact prompt | Small wooden tag with a punch-hole on the left (frame hanging notch). Wax-cream interior. Used for contextual "Press [E]" prompts. | interact_prompt_bg.png |
| Inventory slots | Hexagonally-influenced square cell. Wood-framed edges with an empty-comb interior. Cross-hair dividers suggest the comb grid. New-item variant glows amber. | inventory_slot.png, inventory_slot_new.png |
| Log page | Warm parchment tile with ruled lines and a corner fold. Used as the background texture for the Knowledge Log and field notebooks. The margin line at left is a warm amber rule. | log_page.png |
| Map background | Parchment interior with aged texture (light dithered dots), enclosed in a 6px Langstroth wood border with grain lines and corner joint marks. Faint grid overlay. | map_background.png |
| Level badge | Hexagonal badge — the natural beehive hex. Wood outer ring, amber interior, bright honey center highlight. Used for the player level number display. | level_badge.png |


#### Langstroth Frame Color Palette — UI Tokens


| Token | Hex | RGB | Use |
| --- | --- | --- | --- |
| WD_DARKEST | #261206 | 38, 18, 6 | Deepest shadow, outer edge of frame. Never pure black. |
| WD_DARK | #46260C | 70, 38, 12 | Main dark wood body, outer frame ring. |
| WD_MID | #6C4016 | 108, 64, 22 | Primary wood face color. Most common wood tone. |
| WD_LIGHT | #94602A | 148, 96, 42 | Wood highlight / side bar lighter face. |
| WD_PALE | #BA8A48 | 186, 138, 72 | Aged wood highlight. Top edge of rails, corner highlights. |
| AMBER_DARK | #985808 | 152, 88, 8 | Deep honey amber. Bar fill shadows, cell wall shadows. |
| AMBER_MID | #C8820C | 200, 130, 12 | Main honey amber. Primary fill color for bars and buttons (hover). |
| AMBER_LIGHT | #E6A220 | 230, 162, 32 | Bright honey. Highlight row on filled bars, hover button interior. |
| HONEY_PALE | #F4CC6E | 244, 204, 110 | Pale honey gold. Toast note body, soft amber accent. |
| WAX_CREAM | #F2E4B2 | 242, 228, 178 | Beeswax cream. Button normal interior, prompt tag interior. |
| WAX_WHITE | #FCF5D7 | 252, 245, 215 | Pale wax / panel interior. Primary background for text areas. |
| CELL_EMPTY | #E4D498 | 228, 212, 152 | Drawn but unfilled comb. Empty cells in bars and inventory slots. |
| CELL_HONEY | #D49E28 | 212, 158, 40 | Honey-filled capped cell. Used in pressed button state. |
| CELL_WALL | #B48430 | 180, 132, 48 | Cell wall divider lines. Honeycomb grid lines in inventory, bars. |
| CELL_DARK | #94681C | 148, 104, 28 | Cell wall shadow. Bottom edge of comb cell rows. |


#### Frame Border Construction Rules

All panels use a consistent multi-layer border system that replicates the cross-section of a wooden Langstroth frame:

1. **Layer 0 (outermost):** `WD_DARKEST` — 1px outer shadow/ground shadow edge
2. **Layer 1:** `WD_MID` — main wood body fill
3. **Layer 2:** `WD_LIGHT` — inner highlight edge (lighter face of the wood)
4. **Layer 3:** `WD_MID` — secondary body layer
5. **Layer 4+ (interior):** `WAX_WHITE` — interior content area

Corner joints are marked with a small 5×5px `WD_DARKEST` dot — representing the nail or screw at each frame joint. Top header bars within panels are 12–16px solid `WD_MID` with horizontal grain lines at 4px intervals.

#### Honeycomb Cell Grid — Usage Rules

- Cell size in fill bars: 8–10px wide, 6–8px tall (landscape hex approximation)
- Cell dividers: 1px lines in `CELL_WALL` at regular intervals across fill bars
- Interior panel honeycomb overlay: very subtle, alpha ≤30%, used as texture not pattern
- Cell walls must never dominate the readability of text — keep overlay opacity low
- Fill bars always fill left-to-right in discrete cell segments — no fractional cell fills (snap to nearest whole cell)

#### Button Cell Design — Three States


| State | Interior Fill | Top Edge | Bottom Edge | Metaphor |
| --- | --- | --- | --- | --- |
| Normal | WAX_CREAM with CELL_WALL honeycomb dots | WD_LIGHT (lit from above) | WD_DARKEST (shadow) | Drawn but empty comb cell |
| Hover | HONEY_PALE with stronger dot pattern | WD_PALE (brighter) | WD_DARK | Cell filling with fresh nectar |
| Pressed | CELL_HONEY with AMBER_DARK dots | WD_DARKEST (inverted — sunken) | WD_LIGHT (inverted) | Capped, filled cell — pressed in |


#### Fill Bar Animation Spec — Cell-by-Cell Fill

Fill bars (XP, energy, honey) do not animate as smooth gradients. They fill in discrete cell segments — the bar visually *fills one cell at a time* as the underlying value increases. This gives a satisfying, organic quality consistent with the honeycomb metaphor:

- Each cell segment transitions from `CELL_EMPTY` → `AMBER_MID` as it fills
- The currently-filling cell shows a partial amber overlay scaled to the fractional fill within that cell
- On level-up or full fill, a brief pulse animation flashes each cell in sequence from left to right (`AMBER_LIGHT` pulse, 3 frames)
- Energy drain plays in reverse — rightmost cell empties first

#### Font and Text Treatment

- All UI text renders on `WAX_WHITE` or `WAX_CREAM` backgrounds
- Primary label color: `WD_DARKEST` (38, 18, 6) — warm very-dark-brown, not black
- Accent labels (values, quantities): `AMBER_DARK`
- Header text in wood bars: `WAX_CREAM`
- Preferred pixel font: any slightly condensed, warm-toned pixel bitmap font. Avoid pure-white or pure-black text.

#### PixelLab Prompt — UI Elements (Langstroth Frame Theme)

Use this prompt base for generating any new UI element assets to match the Langstroth frame aesthetic:


```gdscript
pixel art UI element, game interface sprite, Langstroth hive frame aesthetic,
thick wooden frame border (warm brown #6C4016, dark edge #46260C),
interior filled with warm wax-cream color (#FCF5D7) or honeycomb cell pattern,
warm amber honey tones (#C8820C, #E6A220), beeswax cream background,
hexagonal comb cells where appropriate, aged wood grain detail,
no pure black outlines (darkest tone #261206), no gradients (dithering and cell patterns only),
no bright saturated colors, warm muted earthy palette,
transparent background where applicable, [YOUR UI ELEMENT HERE]
```


### 10.2 Sound Design


| Background Music | Original instrumental score. Acoustic guitar, piano, light percussion. Each season has its own theme with shared motifs. Music reacts to colony health — a struggling hive is accompanied by a quieter, more minor-key underscore. |
| --- | --- |
| Bee Ambient Sound | The ambient hum of a healthy colony is a constant, satisfying presence. Colony stress changes the frequency and character of the hum — a subtle but learnable audio cue. |
| Inspection Audio | Distinct sounds for: frame removal, bee movement, queen spotted (a brief musical sting), disease discovered (a dissonant note). Players learn to listen as well as look. |
| Weather | Rain on the hive roof. Wind through flower fields. The crunch of frost underfoot. Each season's outdoor soundscape is distinct. |
| Harvest | The centrifuge spinning up, honey flowing into a bucket, the satisfying thwack of an uncapping knife — all tactile and rewarding. |
| UI Sounds | Minimal. Soft, organic sounds only. No harsh beeps or mechanical clicks. Opening the Knowledge Log sounds like turning a paper page. |


---

[< NPCs](09-NPCs) | [Home](Home) | [Monetization (TBD) >](11-Monetization)