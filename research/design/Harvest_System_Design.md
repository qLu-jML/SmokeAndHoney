# Harvest System — Detailed Feature Design
## Smoke & Honey Phase 2: "Something to Sell"

---

## PREREQUISITE: Super & Box Management System

Before harvest can exist, the player needs honey supers on their hives. This section defines the full box management system that must be in place first.

### Real-World Langstroth Dimensions (Research)

| Component | Length | Width | **Height** | Weight (full) | Frames |
|-----------|--------|-------|-----------|---------------|--------|
| **Deep Body** (brood) | 19⅞" | 16¼" | **9⅝"** | ~80-90 lbs | 10 deep frames (9⅛" tall) |
| **Medium Super** | 19⅞" | 16¼" | **6⅝"** | ~50-60 lbs | 10 medium frames (6¼" tall) |
| **Shallow Super** | 19⅞" | 16¼" | **5⅞"** | ~35-40 lbs | 10 shallow frames (5⅜" tall) |

**Key ratio for sprites**: A shallow super is roughly **61%** the height of a deep body (5.875 / 9.625). A medium super is roughly **69%** the height of a deep body.

**Game choice**: We use **medium supers** as our honey super — they're the most common in real beekeeping, hold a good amount of honey (~50 lbs full), and aren't backbreakingly heavy like a full deep. The height ratio for sprites is ~**2:3** (super:deep).

### Sprite Requirements

Current overworld hive sprite: **24 × 36 pixels** (shows complete hive as single image)

**New approach — modular stacking sprites:**

| Sprite | Dimensions | Description |
|--------|-----------|-------------|
| `hive_base.png` | 24 × 6 px | Bottom board + landing strip |
| `hive_deep.png` | 24 × 14 px | Deep body (brood box). Taller, darker wood tone. |
| `hive_super.png` | 24 × 10 px | Medium honey super. Shorter, lighter wood tone. |
| `hive_excluder.png` | 24 × 2 px | Queen excluder — thin metal-grey strip between deep and super |
| `hive_lid.png` | 24 × 6 px | Telescoping outer cover (lid). Always on top. |

**Stacking examples:**
- **1 deep, no super** (starting hive): base + deep + lid = 24 × 26 px
- **1 deep + 1 super**: base + deep + excluder + super + lid = 24 × 38 px
- **2 deeps + 1 super**: base + deep + deep + excluder + super + lid = 24 × 52 px
- **2 deeps + 2 supers**: base + deep + deep + excluder + super + super + lid = 24 × 62 px

The overworld hive **visually grows taller** as the player adds boxes. This is satisfying and informative — you can see at a glance which hives have supers.

### Box Management — Player Actions

#### Adding a Second Deep (Brood Expansion)
**When**: Colony is thriving — brood box is 75%+ full of drawn comb and brood. The queen needs more laying room or she'll get congestion signals and swarm.

**Trigger**: During inspection, if brood box fill > 75%, show notification:
> "This colony is running out of room. Consider adding a second deep body for brood expansion."

**Player action**: Select `ITEM_DEEP_BOX` from inventory → walk to hive → press [E] → "Add Second Deep Body"

**Mechanic**:
- New deep box goes ON TOP of existing deep (boxes[1] with is_super=false)
- Contains 10 empty foundation frames
- Queen can move freely between both deeps
- Bees draw comb upward into the new box naturally (simulation handles this)
- This is standard real-world practice — "nadiring" is rare, most beekeepers add on top

**When NOT to add**: If colony is weak, adding space they can't defend invites pests. Player learns this through consequences (small hive beetle, wax moths in empty comb).

#### Adding a Queen Excluder
**When**: Before adding honey supers. The excluder is a metal grid that worker bees can pass through but the larger queen cannot. This keeps the queen in the brood boxes and ensures supers contain ONLY honey (no brood).

**Player action**: Select `ITEM_QUEEN_EXCLUDER` → walk to hive with ≥1 deep → press [E] → "Place Queen Excluder"

**Mechanic**:
- Excluder sits between the top-most deep body and the first super
- `hive.has_excluder: bool` flag
- **Without excluder**: Queen can lay in supers → brood in honey frames = bad harvest (contaminated honey, dead brood when you extract). Strong negative consequence teaches why excluders matter.
- **With excluder**: Queen confined to deeps. Supers are guaranteed honey-only.

**Optional gameplay nuance**: Some real beekeepers don't use excluders ("honey excluders" they call them, because workers are slightly reluctant to pass through). Could add a small nectar throughput penalty (-5%) when excluder is present. Creates a real decision: safety vs efficiency.

#### Adding Honey Supers
**When**: Colony has filled brood boxes and nectar flow is strong. Usually early-to-mid summer.

**Trigger**: During inspection, if top deep box honey stores are 80%+ full and it's a nectar flow month (Wide-Clover or High-Sun), show:
> "Nectar flow is strong and the bees are running out of storage space. Time to add a honey super!"

**Player action**: Select `ITEM_SUPER_BOX` → walk to hive with excluder → press [E] → "Add Honey Super"

**Mechanic**:
- Super goes on top of excluder (or on top of existing supers if stacking multiple)
- Contains 10 empty foundation frames (medium size)
- Bees draw comb and store nectar in supers
- Multiple supers can be stacked (practical limit: 3-4 per hive)
- **Without excluder warning**: "No queen excluder detected. The queen may lay eggs in this super, contaminating the honey. Add excluder first?" [Add Anyway] [Cancel]

**Super frame data**: Same HiveFrame class but with `is_super_frame: bool = true`. Cell grid is **70 × 35** (shorter frames) instead of 70 × 50 for deep frames. This means 2450 cells per side instead of 3500. `LBS_PER_FULL_SUPER_FRAME = 3.5` (vs 5.0 for deep).

### Collecting Supers for Harvest

**This is the bridge between inspection and the Honey House.**

**Player flow**:
1. Inspect hive → see super frames are well-capped (80%+)
2. Press [H] to mark frames or [Shift+H] to mark entire super
3. Exit inspection
4. Walk to hive → prompt changes to: "[E] Remove Marked Super" (if entire super is marked)
5. Super box goes into player inventory as `ITEM_FULL_SUPER` (heavy! counts as 1 item but slows player movement by 15% per super carried)
6. Walk to Extraction Table / Honey House → press [E] → super's frames populate the extraction queue
7. After extraction, empty super frames are returned → player can re-add the super to the hive

**Carrying limit**: Player can carry max 2 full supers at once (they're heavy — 50+ lbs each in real life). Multiple trips required for big operations.

### New Items Required

| Item Constant | Display Name | Buy Price | Source | Notes |
|--------------|-------------|-----------|--------|-------|
| `ITEM_DEEP_BOX` | Deep Hive Body | $25.00 | Feed & Supply | Includes 10 foundation frames |
| `ITEM_SUPER_BOX` | Honey Super | $20.00 | Feed & Supply | Medium depth, 10 foundation frames |
| `ITEM_QUEEN_EXCLUDER` | Queen Excluder | $8.00 | Feed & Supply | Metal grid, reusable |
| `ITEM_FULL_SUPER` | Full Honey Super | — | From hive | Not purchasable. Temporary carry item. |
| `ITEM_JAR` | Empty Glass Jar | $0.50 | Feed & Supply | For bottling |

### Inspection Overlay — Multi-Box Navigation

**Current state**: InspectionOverlay only reads `boxes[0]`. Must be expanded.

**New navigation**:
- **W/S keys** (or Up/Down): Navigate between boxes (W = up toward supers, S = down toward brood)
- **A/D keys**: Navigate between frames within current box (unchanged)
- **F key**: Flip frame side (unchanged)
- **Box indicator**: Top of overlay shows "Box: Brood 1 of 2" or "Box: Super 1 of 2"
- **Color coding**: Brood box frames have warm brown border, super frames have golden/amber border
- **Super frames render shorter**: 70×35 grid instead of 70×50, matching real proportions

### Simulation Changes

**Nectar routing** (when supers exist):
- Incoming nectar preferentially fills supers when brood box top fill > 80%
- Foragers deposit nectar in nearest empty cells to the entrance (bottom-up for brood box, then overflow to supers)
- If no super space available, nectar fills brood box → triggers congestion → eventual swarm signal

**Queen behavior with excluder**:
- Queen's `_queen_lay()` method must respect box boundaries
- With excluder: queen only considers frames in boxes where `is_super == false`
- Without excluder: queen can lay in any frame (including supers) — she prefers brood boxes but will move up if congested

**Comb drawing in supers**:
- Same `_draw_comb()` logic but on medium frames (2450 cells per side)
- Bees are reluctant to draw new foundation in supers — drawing rate is 60% of brood box rate
- Pre-drawn super frames (from previous year) are filled much faster (no wax production needed)

---

## Overview & Philosophy

The harvest is the **payoff moment** of the beekeeping year. Every decision the player made — hive placement, inspection timing, mite treatment, forage management — converges into this one question: *how much honey did we make, and how good is it?*

The harvest pipeline is physical, tactile, and educational. The player doesn't press a "collect honey" button. They **transport supers to the Honey House**, **uncap each frame by hand**, **spin them in an extractor**, **read the moisture**, and **choose how to bottle**. Each step teaches real beekeeping while creating meaningful decisions.

### Core Design Tension
- **Harvest too early** → uncapped honey, high moisture, low grade (Economy or Fermented)
- **Harvest too late** → bees consume stores, less to sell, frames get propolis-locked
- **Harvest too much** → colony starves over winter (winter reserve warning)
- **Harvest just right** → Premium grade, maximum yield, healthy winter colony

---

## FEATURE 1: Harvest Decision UI

### Concept
The player inspects their hive normally (InspectionOverlay), evaluates frame-by-frame capping percentages, then makes a conscious decision: "This super is ready" or "I'll wait." There is **no auto-harvest** — the player must physically transport chosen supers to the Honey House building to begin extraction.

### Player Flow
1. Player inspects hive with Hive Tool (existing system)
2. InspectionOverlay shows per-frame capping % in the stats sidebar
3. For super frames (box index > 0), a new indicator shows harvest readiness:
   - **Green honeycomb icon** = 80%+ capped → "Ready to harvest"
   - **Yellow warning** = 60-79% capped → "Needs more time"
   - **Red warning** = <60% capped → "Not ready - high fermentation risk"
4. Player presses **[H] Mark for Harvest** on individual frames or **[Shift+H] Mark Entire Super**
5. Marked frames get a visual tag (small harvest icon in corner)
6. Player exits inspection → walks to Honey House → presses **[E] Begin Extraction**
7. Only marked frames from that hive appear in the Honey House UI

### Technical Spec
- **New field on HiveFrame**: `marked_for_harvest: bool = false`
- **New method in HiveSimulation**: `get_harvestable_frames() -> Array[Dictionary]`
  - Returns array of `{box_idx, frame_idx, capping_pct, honey_lbs, side_a_honey, side_b_honey}`
  - Only includes frames where `marked_for_harvest == true`
- **Capping percentage calculation**:
  ```
  capping_pct = (S_CAPPED_HONEY + S_PREMIUM_HONEY) / (S_CAPPED_HONEY + S_PREMIUM_HONEY + S_CURING_HONEY + S_NECTAR)
  ```
  Only counts honey-related cells; ignores brood/empty cells
- **Remove**: `_harvest_from_overlay()` function in InspectionOverlay.gd (the auto-harvest on E key)
- **Remove**: The E key harvest binding in `_unhandled_key_input()`
- **Add to InspectionOverlay**: H key binding for mark/unmark, Shift+H for whole super
- **Super detection**: `box_idx > 0` means it's a super (index 0 = brood box)

### Fermentation Warning
When player marks a frame with <80% capping, show a confirmation dialog:
> "This frame is only XX% capped. Uncapped honey has high moisture and may ferment. Harvest anyway?"
> [Harvest Anyway] [Wait]

This teaches the 80% rule without blocking the action — the player can still harvest early if they choose to accept the grade penalty.

---

## FEATURE 2: Uncapping Mini-Game

### Concept
Before honey can be extracted, wax cappings must be removed from each frame. This is a **hands-on mini-game** where the player drags an uncapping knife across the frame surface. Speed and accuracy determine how much beeswax is recovered and how much honey is lost to spillage.

### Mini-Game Design: "The Uncapping Swipe"
- **Display**: The frame fills the center of the screen, showing the honeycomb texture (reuse FrameRenderer output)
- **Capped cells** are highlighted with a golden wax overlay
- **Player drags** the uncapping knife from top to bottom (or side to side) across the frame
- **Swipe zones**: The frame is divided into 5 horizontal strips
- **Each strip** requires one clean swipe (click-drag from one edge to the other)
- **Scoring per strip**:
  - **Clean swipe** (smooth, straight path): 100% cappings recovered, 0% honey spillage
  - **Messy swipe** (jagged, too fast): 70% cappings recovered, 5% honey lost to spillage
  - **Missed areas** (player didn't cover the strip): Those cells stay capped → less honey extracted later
- **Energy cost**: 1 energy per frame uncapped (as per GDD)
- **Tool choice** (future upgrade path):
  - **Scratch roller** (starting tool): Slower swipe required, more forgiving on accuracy
  - **Hot uncapping knife** (Feed & Supply purchase): Faster swipe allowed, cleaner cuts, more wax recovered
  - **Electric uncapping plane** (Year 2 unlock): Auto-uncaps with single click, max recovery

### Technical Spec
- **New scene**: `scenes/ui/uncapping_minigame.tscn` + `scripts/ui/uncapping_minigame.gd`
- **Input**: Track mouse drag path across 5 zones
- **Output Dictionary per frame**:
  ```
  {
    cells_uncapped: int,        # how many capped cells were successfully uncapped
    cells_total_capped: int,    # total capped cells on this frame
    cappings_wax_lbs: float,    # beeswax recovered (cells_uncapped × 0.00015 lbs per cell)
    honey_spillage_pct: float,  # % of honey lost during uncapping (0-5%)
    uncap_quality: String       # "clean" / "messy" / "partial"
  }
  ```
- **Wax-to-beeswax conversion**: Each uncapped cell yields ~0.00015 lbs of wax. A full frame (7000 cells, both sides) yields ~1.05 lbs wax if all cells were capped honey. Realistic range: 0.3-0.8 lbs per frame.
- **Energy**: Deduct 1.0 from GameData.energy per frame
- **Skip option**: "Uncap All (Quick)" button uncaps remaining frames with "messy" quality — for players who don't enjoy the mini-game. Still costs energy.

### Visual Style
- Warm amber background (Langstroth frame aesthetic)
- Knife cursor replaces mouse pointer during swipe
- Wax curls peel away satisfyingly as player swipes
- Cappings fall into a collection tray at bottom of screen (visual only)
- Sound: satisfying scraping/peeling sound effect per strip

---

## FEATURE 3: Extraction + Grading

### Concept
After uncapping, frames go into the extractor — a centrifuge that spins honey out of the comb. The extracted honey is then graded by moisture content. The **refractometer** (if owned) shows exact moisture %; otherwise the player only sees the qualitative grade.

### Extraction Flow
1. Uncapped frames load into extractor (2 at a time with basic manual extractor)
2. Player presses **[Space] Spin** — animated extractor spins
3. Honey drains into settling bucket below extractor
4. After all frames are processed, a **Grading Screen** appears

### Moisture Calculation (per GDD §6.6)
```
moisture_pct = base_season_humidity
             + (uncapped_cell_fraction × 6.0)
             - curing_bonus
```

| Season | Base Humidity |
|--------|-------------|
| Quickening/Greening (Spring) | 17.5% |
| Wide-Clover/High-Sun (Summer) | 16.5% |
| Full-Earth/Reaping (Fall) | 18.0% |
| Active rainfall week | +0.8% stacking |

- **uncapped_cell_fraction**: cells that were NOT capped at harvest time ÷ total honey cells. From the uncapping step, any cells the player missed (still capped) count as capped. Cells that were never capped (S_NECTAR, S_CURING_HONEY) count as uncapped.
- **curing_bonus**: -0.8% if Honey House is upgraded (Year 2+). Basic extraction setup = no bonus.
- **Feeding flag**: If the hive was fed sugar syrup within the last 30 days, set `was_fed = true`. This prevents varietal labeling and adds +0.3% moisture (sugar syrup is wetter).

### Grading Table
| Moisture % | Grade | Price Modifier | Color Tag |
|-----------|-------|---------------|-----------|
| ≤17.0% | Premium | +40% ($14.00/jar) | Gold |
| 17.1–18.6% | Standard | Base ($8.50/jar) | Amber |
| 18.7–20.5% | Economy | -20% ($5.00/jar) | Brown |
| >20.5% | Fermented | Cannot sell as honey | Red |

### Grading Screen
- **With refractometer**: Shows exact moisture % number, grade, and price modifier
- **Without refractometer** (early game): Shows only the qualitative grade label and color. Player must learn what affects moisture through experimentation.
- **Fermented honey**: Not wasted — goes into inventory as `ITEM_FERMENTED_HONEY`, usable later for mead crafting (Phase 4)

### Yield Calculation
```
total_honey_lbs = sum of all extracted frames:
  per_frame_lbs = (cells_uncapped / FRAME_SIZE_BOTH_SIDES) × LBS_PER_FULL_FRAME × (1.0 - honey_spillage_pct)
```
Where:
- `FRAME_SIZE_BOTH_SIDES` = 7000 (3500 × 2)
- `LBS_PER_FULL_FRAME` = 5.0 lbs
- `honey_spillage_pct` = from uncapping quality (0% clean, 5% messy)

### Technical Spec
- **New scene**: `scenes/ui/extraction_screen.tscn` + `scripts/ui/extraction_screen.gd`
- **Input**: Array of uncapped frame data from uncapping step
- **Processing**: Batch all frames → calculate total lbs → calculate average moisture → assign grade
- **Output**: `{total_lbs: float, moisture_pct: float, grade: String, was_fed: bool, varietal: String}`
- **Varietal detection**: If 70%+ of the hive's forager visits in the last 30 days came from one plant type (tracked by ForageManager), honey gets a varietal label (e.g., "Clover Honey", "Wildflower Honey"). Varietal + Premium = highest value.
- **Deduct from simulation**: After extraction, set extracted frame cells from S_CAPPED_HONEY/S_PREMIUM_HONEY → S_DRAWN_EMPTY. Reduce hive's honey_stores by extracted amount.

---

## FEATURE 4: Bottling UI

### Concept
After extraction and grading, the player chooses how to package their honey. This is a simple but meaningful economic decision.

### Options
| Choice | Container | Time | Price per Unit | Notes |
|--------|-----------|------|---------------|-------|
| **Jar** | 1 lb glass jar | 1 jar at a time (click per jar) | Grade-based (see grading table) | Requires empty jars in inventory. Higher margin. |
| **Bulk Bucket** | 5 lb bucket | Instant fill | 60% of jar price per lb | No jar required. Faster but lower value. Sells to Frank at wholesale. |
| **Store Raw** | Stays in settling tank | Instant | No immediate sale | Keeps honey available for crafting recipes (Phase 4). |

### Bottling Screen
- Shows total extracted honey (e.g., "18.4 lbs of Standard Wildflower Honey")
- Three buttons: [Fill Jars] [Fill Bucket] [Store Raw]
- **Fill Jars**: Each click fills one jar, consumes 1 ITEM_JAR from inventory, creates 1 ITEM_HONEY_JAR with grade metadata
- **Fill Bucket**: Fills 5 lbs at a time into bulk container
- **Jar label**: Shows grade + varietal (if applicable). "Premium Clover Honey" or "Standard Wildflower Honey"
- Running counter: "Bottled: 12 jars | Remaining: 6.4 lbs"

### Technical Spec
- **New scene**: `scenes/ui/bottling_screen.tscn` + `scripts/ui/bottling_screen.gd`
- **Honey jar metadata**: Extend inventory system to track per-stack grade:
  ```
  inventory_slot = {
    item: "honey_jar",
    count: 12,
    grade: "premium",      # premium / standard / economy
    varietal: "clover",    # or "wildflower" / "goldenrod" / etc.
    moisture: 16.8         # exact moisture for refractometer display
  }
  ```
- **New items needed in GameData**:
  - `ITEM_HONEY_BULK` — bulk bucket (5 lb units), sells at 60% jar rate
  - `ITEM_FERMENTED_HONEY` — fermented batch, only usable for mead
  - `ITEM_JAR` — empty glass jar (bought at Feed & Supply)
- **Jar supply**: Player must buy empty jars at Feed & Supply ($0.50 each). This creates a cash-flow decision: spend money on jars to make more money, or sell bulk cheap.

---

## FEATURE 5: Beeswax Collection

### Concept
Every frame uncapped during the harvest produces beeswax cappings as a byproduct. This accumulates automatically during the uncapping step and goes into the player's inventory. Beeswax is the foundation resource for Phase 4 crafting (candles, lip balm, furniture polish, foundation sheets).

### Collection Flow
1. During uncapping mini-game, cappings fall into collection tray (visual)
2. After all frames are uncapped, total wax is calculated
3. Notification: "Collected X.X lbs of beeswax cappings"
4. Beeswax added to player inventory as ITEM_BEESWAX

### Wax Yield Math
```
wax_per_cell = 0.00015 lbs (roughly 1 oz per 400 cells)
wax_per_frame = cells_uncapped × wax_per_cell × recovery_rate

recovery_rate:
  - Clean uncapping: 1.0 (100% recovered)
  - Messy uncapping: 0.70 (30% lost to crumbling/sticking)
  - Partial uncapping: proportional to coverage
```

Realistic yields per harvest:
- Small harvest (3-4 frames): ~0.5-1.0 lbs beeswax
- Medium harvest (8-10 frames): ~2.0-3.5 lbs beeswax
- Large harvest (15-20 frames): ~4.0-7.0 lbs beeswax

### GameData Tracking
- `GameData.beeswax_lifetime: float` — total beeswax ever collected (for achievements)
- Player inventory tracks current beeswax via existing ITEM_BEESWAX slot
- **Sell price**: $3.25/lb raw at Feed & Supply (or $8-15/lb as crafted candles in Phase 4)

### Technical Spec
- Wax calculation happens inside `uncapping_minigame.gd` as a side-output
- After uncapping phase completes, wax total is passed through to the extraction screen
- Final wax amount displayed in harvest summary at end of pipeline
- Added to player inventory via `player.add_item(GameData.ITEM_BEESWAX, wax_count)`
- `wax_count` = integer lbs (floor of total, remainder tracked in GameData.beeswax_fractional)

---

## FEATURE 6: Winter Reserve Warning

### Concept
The most common beginner mistake in beekeeping is harvesting too much honey, leaving the colony without enough stores to survive winter. This system provides escalating visual warnings on the overworld hive when honey stores drop below safe thresholds.

### Warning Thresholds (per GDD §6.6)
| Honey Stores | Warning Level | Visual | Notification |
|-------------|--------------|--------|-------------|
| ≥60 lbs | Safe | Normal hive appearance | None |
| 40-59 lbs | Caution | **Orange tint** on overworld hive sprite | "Colony stores are getting low" (first time only) |
| <40 lbs | Danger | **Red tint** on overworld hive sprite | "DANGER: Colony may not survive winter at current stores" |
| <20 lbs | Critical | **Red pulsing tint** + skull icon | "CRITICAL: Feed immediately or colony will die" |

### Timing
- Warnings activate during **Reaping** month (month 6, late fall) — the last harvest window
- During earlier months, low stores are less alarming (bees are still foraging)
- Warning tint **persists** on the overworld hive until stores recover above the threshold
- If player harvests during Reaping and stores drop below 60 lbs, show a one-time dialog:
  > "Uncle Bob's voice echoes in your mind: 'A dead hive makes no honey next year. Leave 'em at least 60 pounds, maybe 80 if it's a cold winter.'"

### Technical Spec
- **SnapshotWriter** already computes `honey_stores` — this data is available
- **hive.gd**: New method `_update_winter_warning()` called after each simulation tick
  - Reads `simulation.honey_stores` and current month from TimeManager
  - Sets `_warning_level: int` (0=safe, 1=caution, 2=danger, 3=critical)
  - Applies modulate color to overworld hive sprite:
    - Level 0: `Color(1, 1, 1)` (normal)
    - Level 1: `Color(1, 0.85, 0.5)` (warm orange tint)
    - Level 2: `Color(1, 0.5, 0.5)` (red tint)
    - Level 3: `Color(1, 0.3, 0.3)` with pulsing alpha (red pulse)
- **Harvest gate**: When player tries to mark frames for harvest and post-harvest stores would drop below 40 lbs, show a strong warning (but don't block — player choice is sacred):
  > "Harvesting this frame will leave your colony with only XX lbs of honey. This is below the safe winter minimum of 60 lbs. Continue?"

---

## HONEY HOUSE BUILDING

### The Missing Piece
The GDD lists Honey House as Year 2, Level 3 — but we need *somewhere* to extract honey in Year 1. Solution: **two tiers of extraction facility**.

### Tier 1: Extraction Table (Available from start)
- **Location**: A basic folding table on the home property (pre-placed, no build cost)
- **Equipment**: Hand-crank 2-frame extractor, basic straining bucket
- **Capacity**: Process 2 frames at a time
- **No curing bonus** (0% moisture reduction)
- **Visual**: Simple outdoor setup — table, bucket, hand extractor

### Tier 2: Honey House (Year 2, Level 3, $500)
- **Location**: Dedicated building on home property (player builds it)
- **Equipment**: 4-frame electric extractor, proper settling tank, temperature control
- **Capacity**: Process 4 frames at a time
- **Curing bonus**: -0.8% moisture (per GDD)
- **Visual**: Interior scene like Diner/Feed & Supply — wooden floor, equipment, shelves of jars

### Player Interaction
1. Player walks to Extraction Table / Honey House
2. Presses [E] → "Begin Extraction"
3. If player has marked frames on any hive, those frames populate the extraction queue
4. Pipeline begins: Uncapping → Extraction → Grading → Bottling
5. Player exits with honey jars, beeswax, and empty frames (returned to hive automatically)

---

## FULL PIPELINE SUMMARY

```
FIELD                          HONEY HOUSE
┌─────────────┐               ┌──────────────────────────────────────────────┐
│ Inspect Hive │               │                                              │
│ (existing)   │               │  1. UNCAP ─── mini-game per frame            │
│              │               │     └─→ beeswax cappings collected           │
│ [H] Mark     │───transport──▶│                                              │
│ frames for   │   (walk to    │  2. EXTRACT ─── spin in extractor            │
│ harvest      │    building)  │     └─→ honey separated from comb            │
│              │               │                                              │
│ Per-frame    │               │  3. GRADE ─── moisture reading               │
│ capping %    │               │     └─→ Premium / Standard / Economy         │
│ shown        │               │                                              │
└─────────────┘               │  4. BOTTLE ─── jar / bulk / store raw        │
                               │     └─→ labeled jars → inventory             │
                               │                                              │
                               └──────────────────────────────────────────────┘

OVERWORLD: Winter reserve warning tints hive orange/red if stores < 60/40 lbs
```

---

## IMPLEMENTATION ORDER

### Phase A: Box Foundation (must exist before harvest)
1. **Modular hive sprites** — create stacking sprite components (base, deep, super, excluder, lid)
2. **Multi-box inspection** — W/S key navigation between boxes in InspectionOverlay
3. **Add second deep** — player action + simulation support for 2-deep hives
4. **Queen excluder** — item, placement mechanic, queen confinement logic
5. **Add honey supers** — player action, medium frame grid (70×35), nectar routing to supers
6. **Super collection** — mark frames, remove super from hive, carry to extraction

### Phase B: Core Harvest Loop (must work end-to-end)
7. **Extraction Table** — place interactable object on home property
8. **Remove auto-harvest** — gut _harvest_from_overlay(), replace E key with H for marking
9. **Extraction + Grading** — moisture calc, grade assignment, refractometer integration
10. **Bottling** — jar/bulk/store choice, inventory integration
11. **Empty jars + new items** — add to Feed & Supply shop inventory

### Phase C: Polish + Systems (add one at a time, test each)
12. **Uncapping Mini-Game** — swipe-based uncapping with quality scoring
13. **Beeswax Collection** — wire into uncapping output, inventory integration
14. **Winter Reserve Warning** — overworld tint + notifications + Uncle Bob dialog

### Phase D: Upgrades (future phases)
15. **Honey House building** — Year 2 upgrade with curing bonus + 4-frame extractor
16. **Electric uncapping plane** — auto-uncap tool upgrade
17. **Varietal detection** — forager tracking integration for labeled honey
