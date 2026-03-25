# GDD Update Proposal — Flower System Overhaul

All code changes are already implemented. This document specifies exactly what needs to change in `Smoke_and_Honey_GDD.html`.

---

## 1. Section 14.3 — Nectar Units (NU) Plant Reference Table

### DELETE these rows:
- **Phacelia (bed/row)** — 9 NU — exceptional nectar, early season | Greening – Wide-Clover
- **Lavender (bed/row)** — 6 NU — aromatic honey contribution | Wide-Clover (early)
- **Borage (bed/row)** — 8 NU — continuous bloom, self-seeding | Wide-Clover – High-Sun
- **Red Clover (bed/row)** — 7 NU — good flow, shorter tongue needed | Wide-Clover – High-Sun
- **Buckwheat (bed/row)** — 8 NU — late season, dark honey | High-Sun – Full-Earth

### ADD these rows (insert after White Clover):
| Plant | NU per Planting Unit (at peak bloom) | Bloom Window |
|-------|--------------------------------------|--------------|
| Wild Bergamot (native prairie) | 7 NU — excellent nectar, Iowa prairie native | Wide-Clover – High-Sun |
| Purple Coneflower (native prairie) | 6 NU — high pollen, moderate nectar | Wide-Clover – Full-Earth |

### MODIFY existing rows:
| Plant | Old Value | New Value |
|-------|-----------|-----------|
| Dandelion (wild) | bloom: "April–May" | bloom: "Quickening – early Greening (Day 5–50)" |
| White Clover | 10 NU, "Greening through Wide-Clover" | 10 NU, "Greening through Full-Earth (Day 30–140)" |
| Sunflower | 5 NU, "High-Sun" | 5 NU, "High-Sun – Full-Earth (Day 80–130)" |
| Goldenrod | 2–20 NU, "Aug–Oct" | 2–20 NU, "Full-Earth – Reaping (Day 110–165)" |
| Native Asters | 7 NU, "Full-Earth – Reaping" | 7 NU, "Full-Earth – Reaping (Day 120–165)" |

### REPLACE the Design Note at the bottom of §14.3:
**Old:** *"A full home garden with 4 flower beds of white clover, borage, phacelia, and goldenrod gives about 37 NU at peak — enough to support 1–2 hives well, but not 5."*

**New:** *"A full home garden with 4 flower beds of white clover, wild bergamot, coneflower, and goldenrod gives about 33 NU at peak — enough to support 1–2 hives well, but not 5. Planting trees and developing additional apiary locations is the route to supporting more hives."*

---

## 2. NEW Section — Insert as §14.2.1 (before §14.3) or as §14.8.0

### Title: "Flower Lifecycle Phase System"

### Content to add:
> All wildflowers in the game progress through five discrete visual phases. Each phase has its own sprite — there is no fading or alpha blending.
>
> **Phase Progression (per tile):**
>
> | Phase | Visual | Produces NU? | Duration | Notes |
> |-------|--------|:---:|----------|-------|
> | SEED | Dirt mound with visible seed | No | 2–4 days | Tile occupied but contributes nothing |
> | SPROUT | Tiny green cotyledon shoot | No | 2–5 days | Visible growth each day |
> | GROWING | Taller stem with closed bud | No | 3–7 days | Species-specific bud shape |
> | MATURE | Full bloom (species-specific) | **Yes** | Bulk of bloom window | Only phase that produces nectar and pollen |
> | WITHERED | Drooping brown dried flower | No | 4–6 days | Occupies tile, prevents spread, then removed |
>
> **Key mechanics:**
> - Only MATURE-phase plants produce Nectar Units and pollen (protein). Seeds, sprouts, growing buds, and withered plants contribute zero forage.
> - WITHERED plants occupy their tile for 4–6 days after the mature phase ends. This prevents runaway spread by blocking new seeds from claiming that space.
> - Spread only occurs FROM mature tiles. New tiles always begin as SEED, creating a natural growth delay.
> - Phase durations scale proportionally to each species' bloom window. Short-lived species (dandelion, 45 days total) progress through early phases in ~8 days. Long-lived species (clover, 110 days) take ~16 days to reach maturity.
> - After a species' bloom window ends, all remaining tiles force-wither and eventually clean themselves up.
>
> **NU Scaling:**
> Per-tile nectar and pollen values use a whole-number point scale (1–5). These are converted to GDD-scale Nectar Units via the formula:
>
> `Zone NU = sum(mature_tiles × species_nectar_points) / NU_SCALE`
>
> Where `NU_SCALE = 250`. This is calibrated so that B-rank wildflowers on the starting zone produce ~35–43 NU at peak summer (High-Sun), supporting 1–2 hives at 20 NU/week demand. Player investment in planted gardens and trees is required to reach the 80–100 NU "fully developed home property" target.
>
> **Per-tile point values:**
>
> | Species | Nectar pts | Pollen pts | Role |
> |---------|:---:|:---:|------|
> | Dandelion | 2 | 3 | First spring forage, critical pollen |
> | White Clover | 4 | 2 | Backbone nectar producer, longest bloom |
> | Wild Bergamot | 3 | 2 | Summer prairie nectar |
> | Purple Coneflower | 2 | 3 | Summer pollen powerhouse |
> | Sunflower | 2 | 4 | Massive pollen, moderate nectar |
> | Goldenrod | 3 | 1 | Dominant fall nectar |
> | Aster | 2 | 2 | Fall companion, balanced |

---

## 3. Section 14.8 — Dandelions & Goldenrod — Critical Wild Forage Events

### Rename §14.8.4 from "DandelionSpawner — GDScript Implementation" to:
**"FlowerLifecycleManager — Unified Wildflower System"**

### Replace §14.8.4 content with:
> The FlowerLifecycleManager replaces the old DandelionSpawner and handles all 7 wildflower species through a unified tile-based system. Each species is subject to season-ranked density (S/A/B/C/D/F), per-tile phase progression (SEED → SPROUT → GROWING → MATURE → WITHERED), and mature-only spread mechanics.
>
> Iowa-native (or naturalized) species in the system:
> - Dandelion (*Taraxacum officinale*) — Day 5–50
> - White Clover (*Trifolium repens*) — Day 30–140
> - Wild Bergamot (*Monarda fistulosa*) — Day 55–105
> - Purple Coneflower (*Echinacea purpurea*) — Day 60–130
> - Sunflower (*Helianthus annuus*) — Day 80–130
> - Goldenrod (*Solidago* spp.) — Day 110–165
> - Aster (*Symphyotrichum novae-angliae*) — Day 120–165

### ADD to §14.8.1 (Dandelions — Spring Lifeline):
> *Note: Dandelion tiles take ~8 days to reach MATURE phase (2 seed + 2 sprout + 4 growing). In a POOR year with late bloom, colonies face a critical gap before any dandelion nectar is available. Supplemental feeding may be essential.*

### ADD to §14.8.2 (Goldenrod):
> *Note: Goldenrod tiles take ~11 days to reach MATURE phase (3 seed + 3 sprout + 5 growing). The fall flow ramps up slower than the calendar bloom date suggests, reflecting real-world conditions where goldenrod fields take time to fully open.*

---

## 4. Global Search-and-Replace

| Find | Replace | Scope |
|------|---------|-------|
| phacelia | wild bergamot | All references to the planted flower species |
| Phacelia | Wild Bergamot | Title case references |
| lavender | purple coneflower | References to the planted flower species ONLY |
| Lavender | Purple Coneflower | Title case references to the flower ONLY |

**DO NOT replace** "lavender" when used as a color name (e.g., "lavender" in FrameRenderer for queen cell color).

---

## 5. Section 14.4 — Hive Carrying Capacity (NO CHANGES)

The location capacity table values remain correct:
- Home Property (fully planted): 80–100 NU / 4–5 hives ← still the target
- Town Garden: 30–40 NU / 1–2 hives ← matches B-rank wildflower output

These values assume the full development arc (player-planted gardens + trees + wild). The wildflower system alone at B-rank provides ~35–43 NU at peak, right at the "undeveloped home property, 1–2 hives" level.

---

## 6. Seasonal Flow Calendar (§14.7 or wherever the monthly flow chart lives)

### Updated monthly overlap at B-rank:

| Month | Season | Mature Wild Flowers | Est. Zone NU (nectar) | Hive Support |
|-------|--------|--------------------|-----------------------|--------------|
| Quickening | Spring | Dandelion only | ~7 NU | < 1 hive (need feeding) |
| Greening | Spring | Dandelion + Clover starting | ~24 NU | ~1 hive |
| Wide-Clover | Summer | Clover + Bergamot | ~36 NU | ~1.5 hives |
| **High-Sun** | **Summer** | **Clover + Bergamot + Coneflower + Sunflower** | **~43 NU** | **~2 hives (peak)** |
| Full-Earth | Fall | Clover (ending) + Goldenrod | ~28 NU | ~1.5 hives |
| Reaping | Fall | Goldenrod + Aster | ~18 NU | < 1 hive |
| Deepcold | Winter | NONE | 0 NU | Dearth |
| Kindlemonth | Winter | NONE | 0 NU | Dearth |

---

## 7. Trees (NO CHANGES)

Willow, Silver Maple, Linden/Basswood, Apple/Cherry/Pear, Wild Plum remain in the GDD table as-is. They are separate from the wildflower tile system and will be implemented as individual tree nodes later.

---

## Summary of Removed Content
- Phacelia (replaced by Wild Bergamot)
- Lavender (replaced by Purple Coneflower)
- Borage (removed for now)
- Red Clover (removed for now)
- Buckwheat (removed for now)
- All references to fade-in/fade-out bloom mechanics (replaced by 5-phase lifecycle)
