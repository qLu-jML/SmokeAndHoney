# Smoke & Honey — PixelLab.ai Style Guide
*Art direction based on "Pixel Art Top Down - Village v1.0.7" asset pack*

---

## Core Style DNA

The art pack is **warm, muted, cozy top-down RPG pixel art** — think Stardew Valley meets early Harvest Moon, rendered in a slightly more painterly, European-village style. The mood is pastoral, nostalgic, and grounded. Nothing is bright or saturated; everything feels like it's lit by soft afternoon Iowa sunlight.

---

## The Master Prompt Block

Copy this block into every PixelLab generation as your base, then add the subject-specific line at the end:

```
top-down RPG pixel art, 16x16 tile grid, warm muted earthy palette,
olive-green grass, sandy tan dirt paths, half-timbered European village style,
slate gray roofs, warm brown timber framing, stone walls in cool gray,
soft ambient lighting from upper-left, 2-3 shade depth shading,
no hard black outlines (use darkened hue for shadows),
subtle pixel dithering on ground textures, rounded tree canopies
with highlight dots, cozy pastoral mood, Stardew Valley aesthetic,
transparent background, [YOUR SUBJECT HERE]
```

---

## Palette Reference

These are the dominant color families pulled from the asset sheets — use these to describe colors in your prompts:

| Role | Description | Prompt keyword |
|---|---|---|
| Ground grass | Muted olive yellow-green, slightly dull | `muted olive green ground` |
| Dirt/path | Warm sandy tan, slightly orange | `sandy tan dirt path` |
| Tree canopy | 3–4 tones: dark forest green → bright highlight | `rounded fluffy olive-green tree canopy` |
| Building wall | Cool mid-gray stone, or warm cream plaster | `cool gray stone wall` / `warm cream plaster wall` |
| Timber framing | Warm medium brown, amber highlights | `warm brown half-timber frame` |
| Roof | Dark slate gray, pixel-shaded depth | `dark slate gray roof with pixel shading` |
| Water | Desaturated teal with subtle texture | `muted teal water` |
| Wood props | Tan-to-medium-brown barrels, crates | `weathered wood brown` |
| Shadows | Soft dark blob under objects, same hue darkened | `soft dark drop shadow, same hue` |

---

## Technical Specs (Always include these)

- **Tile size:** 16×16 px base tiles. Objects span multiple tiles — a small prop is ~16×16, a building is ~80×96 px or larger.
- **Perspective:** True top-down with a very slight north-tilt (~15°) — you see the front face of buildings but the roof dominates. Roofs are viewed at ~45°. This is the classic SNES/GBC RPG view.
- **Outline style:** No pure black outlines. Edges are formed by using the darkest shade of each color. This gives the art a soft, painterly quality.
- **Shading:** 2 to 3 tones per color (e.g., mid → light highlight → dark shadow). Dithering is used sparingly on ground tiles for texture, not for shading.
- **Shadow layer:** Objects cast a separate soft shadow (darker desaturated version of the ground color) slightly offset south and east. Shadows are their own sprite layer, not baked in.
- **Transparency:** All non-ground sprites use transparent backgrounds (PNG with alpha).

---

## Subject-Specific Prompt Templates

Use these ready-to-go prompts for Smoke & Honey specific assets:

---

### Langstroth Beehive (top-down)
```
top-down RPG pixel art, 16x16 tile grid, warm muted earthy palette,
no black outlines, 2-3 shade shading, soft shadow, transparent background,
Langstroth beehive box, stacked white-painted wooden supers,
warm cream and off-white wood planks, slight wood grain pixel detail,
top-down view with slight north tilt showing front face and top,
cozy pastoral Stardew Valley style
```

---

### Bee Yard / Apiary Area (tileable ground prop)
```
top-down RPG pixel art, 16x16 tile grid, warm muted earthy palette,
no black outlines, soft ambient lighting, transparent background,
small backyard apiary corner, short mowed grass, 2-3 white Langstroth hive boxes
arranged in a row, wooden hive stand, wildflowers nearby,
cozy pastoral Stardew Valley style, olive green grass ground
```

---

### Bee Swarm / Flying Bee Particle
```
top-down RPG pixel art, 16x16 sprite, warm golden-yellow bee,
black stripe detail at 16px scale, tiny wings visible,
1-2px motion blur suggestion, transparent background,
warm muted palette, no black outlines, cozy style
```

---

### Honey Jar (inventory item)
```
RPG pixel art inventory item, 16x16 px, warm amber honey jar,
rounded glass jar with gold lid, honey color #C8860A,
subtle highlight pixel on jar surface, transparent background,
warm muted palette, no black outlines, 2-3 shade depth,
Stardew Valley item style
```

---

### Beekeeper Character (player, top-down walking sprite)
```
top-down RPG pixel art walking sprite sheet, 16x32 px per frame,
4 directions (down, left, right, up), 3 frames per direction,
beekeeper character wearing white beekeeping suit, mesh veil helmet,
warm off-white suit color, muted style, no black outlines,
rounded blobby silhouette consistent with TX Player style,
warm muted earthy palette, transparent background, Stardew Valley feel
```

---

### Uncle Bob NPC (older man, beekeeper)
```
top-down RPG pixel art NPC sprite, 16x32 px, standing pose,
older man in his 60s, wearing worn denim overalls and plaid flannel shirt,
warm earth tones (tan, brown, faded blue denim), gray hair,
friendly round face, no black outlines, 2-3 shade shading,
transparent background, cozy Stardew Valley NPC style
```

---

### Hive Frame (close-up inspection view — NOT top-down)
*Note: the hive frame inspection screen is a different view than the overworld. Use this for the frame UI.*
```
pixel art hive frame, front-facing view (not top-down),
wooden Langstroth frame with wire, hexagonal comb cells visible,
color-coded cells: pale yellow empty comb, golden capped honey,
tan capped brood, white larvae curled in cells, eggs as tiny dots,
warm amber and tan palette, clean readable pixel detail,
no black outlines, 2-3 shade depth per cell type,
transparent background, game UI art style
```

---

### Cedar Bend Diner (building)
```
top-down RPG pixel art building, warm muted earthy palette,
no black outlines, 2-3 shade pixel shading, slate gray roof,
warm cream plaster walls with wood trim, small-town American diner,
red-and-white striped canvas awning, front door with glass window,
slightly larger than house buildings, slight north-tilt perspective showing
roof and front face, soft drop shadow layer, transparent background,
Stardew Valley village aesthetic
```

---

### Cedar Bend Feed & Supply Store
```
top-down RPG pixel art building, warm muted earthy palette,
no black outlines, slate gray roof, warm tan wooden clapboard siding,
general farm store, wooden porch with barrels and feed sacks props,
hand-painted sign panel, slight north-tilt perspective,
soft drop shadow, transparent background, Stardew Valley village aesthetic
```

---

### Saturday Market Stall
```
top-down RPG pixel art market stall prop, 2-tile wide (32x48 px),
wooden counter with striped canvas awning (tan and green stripes),
honey jars and produce displayed on counter top,
warm wood brown frame, muted palette, no black outlines,
slight north-tilt showing front face and canopy top,
transparent background, cozy village market style
```

---

### Wildflower Patch (forage tile)
```
top-down RPG pixel art ground tile, 16x16 px,
muted olive green grass base with small wildflowers,
clover flowers (white/pink), dandelions (yellow),
2-3 flower pixels per tile, subtle dithered texture,
no black outlines, warm earthy palette, tileable, transparent background
```

---

### Smoker Tool (inventory item)
```
RPG pixel art inventory item, 16x16 px,
beekeeping smoker, metallic tin cylinder with bellows,
dark gray metal body with smoke wisps from top,
warm brown leather bellows, subtle highlight pixel,
warm muted palette, no black outlines, transparent background,
Stardew Valley item icon style
```

---

## Style Don'ts (what to avoid)

- ❌ No bright saturated colors (no neon greens, primary blues, vivid reds)
- ❌ No pure black (#000000) outlines — always use darkened hue
- ❌ No clean white backgrounds — always transparent or grass ground
- ❌ No fantasy/medieval aesthetic for new Smoke & Honey-specific assets (this is rural Iowa, not a castle town)
- ❌ No anime or cartoon exaggeration — keep it grounded and readable
- ❌ No heavy dithering on characters or buildings (dithering is for ground texture only)

---

## Tips for PixelLab Specifically

1. **Use "no black outlines"** in every prompt — this is the single biggest thing that separates this pack's style from generic pixel art.
2. **Specify pixel dimensions** — PixelLab respects exact sizes. 16×16 for items/tiles, 16×32 for characters, 80×96 or larger for buildings.
3. **"Transparent background"** is essential for anything that will be placed in-game.
4. **Reference the pack name** if PixelLab supports style references: *"in the style of Pixel Art Top Down Village by Cainos"* — this pack is by the artist Cainos and may be in their training data.
5. For **buildings**, always add *"slight north-tilt RPG perspective, roof visible from above, front facade visible"* — without this, generators default to strict top-down or isometric.
6. For **character sheets**, specify the full grid: *"4-direction walk cycle, 3 frames per direction, arranged in rows"* — PixelLab can output sprite sheets if asked explicitly.

---

## UI Asset Direction — Langstroth Frame Aesthetic

> **This section governs all UI sprites.** World art and character art rules above still apply to overworld and character assets. UI assets follow the Langstroth Frame system below.

All in-game interface elements use the **Langstroth Frame Aesthetic** — a visual language that treats every UI component as if it were crafted from the same hive frames and beeswax comb the player manages. This is the official UI design identity for Smoke & Honey as of Phase 1.

### What a Langstroth Frame Looks Like (reference)

A Langstroth frame is a rectangular wooden frame hanging inside a hive box:
- **Top bar** — thick wood plank (~25mm), warm brown, with grain lines
- **Side bars** — thinner wood, same warm tones
- **Bottom bar** — thinner bottom rail, often slightly lighter on the top face
- **Interior** — drawn honeycomb cells: hexagonal wax cells, warm amber to pale cream, slightly translucent when empty, golden amber when filled with honey

### UI Palette (Langstroth Frame Tokens)

| Token | Hex | Use |
|---|---|---|
| `WD_DARKEST` | `#261206` | Outer frame shadow edge — never pure black |
| `WD_DARK` | `#46260C` | Frame outer body |
| `WD_MID` | `#6C4016` | Primary wood face — most common wood tone |
| `WD_LIGHT` | `#94602A` | Wood highlight / lit face |
| `WD_PALE` | `#BA8A48` | Aged pale highlight, top bar edge |
| `AMBER_DARK` | `#985808` | Deep honey shadow |
| `AMBER_MID` | `#C8820C` | Main honey amber — fill bars, hover state |
| `AMBER_LIGHT` | `#E6A220` | Bright honey — highlight row in fills |
| `HONEY_PALE` | `#F4CC6E` | Pale honey — toast notes, soft accents |
| `WAX_CREAM` | `#F2E4B2` | Beeswax cream — button interior, tags |
| `WAX_WHITE` | `#FCF5D7` | Pale wax — text area backgrounds |
| `CELL_EMPTY` | `#E4D498` | Drawn empty comb cell fill |
| `CELL_HONEY` | `#D49E28` | Capped honey cell fill |
| `CELL_WALL` | `#B48430` | Cell wall divider lines |
| `CELL_DARK` | `#94681C` | Cell wall shadow (bottom edge) |

### PixelLab Prompt — UI Elements (Master Block)

```
pixel art UI element, game interface sprite, Langstroth hive frame aesthetic,
thick wooden frame border, warm brown wood tones (#6C4016, #46260C, #94602A),
interior warm wax-cream (#FCF5D7) or honeycomb cell pattern,
amber honey fill color (#C8820C, #E6A220) where filled,
beeswax cream (#F2E4B2) where empty or neutral,
hexagonal comb cell detail where appropriate,
horizontal wood grain lines in bars and rails,
no pure black outlines (darkest #261206), no gradients (cell patterns and dithering only),
warm muted earthy palette, no bright saturated colors,
transparent background, pixel art, [YOUR UI ELEMENT HERE]
```

---

### Per-Element Prompt Templates

---

#### Panel / Menu Background
```
pixel art UI panel background, Langstroth hive frame aesthetic,
thick 4px wooden border (outer: #46260C, main: #6C4016, highlight inner edge: #94602A),
solid wood header bar at top with horizontal grain lines,
interior warm wax-white (#FCF5D7) with very subtle honeycomb cell overlay,
corner nail markers (5x5px #261206 dots at each corner joint),
no pure black, no gradients, transparent background,
[PANEL DIMENSIONS, e.g. 180x130 px]
```

---

#### Button (Normal / Hover / Pressed)
```
pixel art UI button, Langstroth honeycomb cell aesthetic,
wooden outer border (#46260C outer, #6C4016 main),
NORMAL: interior fill wax-cream (#F2E4B2), top edge lighter (#94602A), bottom edge darker (#261206),
subtle honeycomb dot texture on interior,
no gradients, warm muted palette, transparent background,
[BUTTON DIMENSIONS, e.g. 80x14 px]
```

For hover, replace interior with `#F4CC6E` (honey pale), brighten top edge.
For pressed, invert shading (dark top, light bottom) and fill interior with `#D49E28` (capped cell).

---

#### Fill Bar (XP / Energy / Honey)
```
pixel art UI fill bar, honeycomb cell row aesthetic,
wooden outer rail (top: #94602A, bottom: #261206, body: #46260C),
interior: row of honeycomb cells,
EMPTY cells: #E4D498 (pale drawn comb), with top highlight and bottom shadow,
FILLED cells: #C8820C amber with #E6A220 highlight row at top, #985808 shadow at bottom,
vertical cell divider lines in #B48430 at regular intervals (every 8-10px),
no gradients — discrete cell fill only, warm muted palette,
transparent background, [BAR DIMENSIONS, e.g. 80x4 px bg / fill]
```

---

#### Toast Notification
```
pixel art toast notification, sticky note pinned to wooden frame,
warm cream parchment body (#FCF5D7), amber top tape strip (#C8820C, 3px),
torn left edge (alternating pixel dots #C8820C),
faint ruled baseline on lower portion,
outer edges in #985808 / #C8820C, no gradients, warm muted palette,
transparent background, [NOTIFICATION DIMENSIONS, e.g. 160x16 px]
```

---

#### Dialogue Box
```
pixel art dialogue box, beekeeper field notebook page,
thick 4px wooden Langstroth frame border,
solid wood top header band (12-16px, #6C4016 with grain lines),
warm wax-paper interior (#FCF5D7) with faint horizontal ruled lines,
left portrait inset area with its own wooden sub-frame border,
corner nail markers, no pure black, no gradients,
transparent background, [BOX DIMENSIONS, e.g. 300x52 px]
```

---

#### Speech Bubble
```
pixel art speech bubble, wooden Langstroth frame style,
rectangular frame with thick wood border,
thin wood header bar at top, warm wax-paper interior (#FCF5D7),
triangular wooden tail pointing down-left from bottom edge,
very faint honeycomb overlay at low opacity,
corner nail dots, no pure black, warm muted palette,
transparent background, [BUBBLE DIMENSIONS, e.g. 96x40 px]
```

---

#### HUD Bar (Top / Bottom)
```
pixel art HUD bar, Langstroth top rail (or bottom rail),
full-width horizontal wood plank,
top rail: outer dark edge (#46260C), body (#6C4016), highlight row (#94602A), bright face bottom (#F2E4B2),
horizontal wood grain lines every 4px, amber resin spot accents,
left/right end caps (#261206),
no gradients, warm muted palette, [BAR DIMENSIONS, e.g. 320x16 px]
```

---

### UI Style Don'ts

- ❌ No gradients on any UI element — use cell patterns and dithering only
- ❌ No pure black (#000000) outlines — use `WD_DARKEST` (#261206)
- ❌ No cool blue/gray tones in UI (reserved for winter world palette, not UI frames)
- ❌ No slick digital / flat UI look — everything should have material texture
- ❌ No heavy honeycomb overlay that obscures text — keep interior overlay alpha ≤30%
- ❌ No fractional cell fills in progress bars — snap to nearest whole cell
- ❌ No smooth color washes — all color transitions are 1-2px pixel-hard steps
