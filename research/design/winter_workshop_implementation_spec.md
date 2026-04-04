# Winter Workshop - Implementation Spec

**Status:** APPROVED - ready for implementation
**Date:** April 4, 2026
**Scope:** Only items marked SETTLED below. Items marked PENDING require further design and must NOT be implemented yet.

---

## How to use this document

Each section has a status: SETTLED (implement now) or PENDING (do not implement). Cowork should work through SETTLED items in the order listed. Each item includes the specific files/systems affected and the expected behavior.

---

## 1. SETTLED - Transition month clarification

Each season has two months. The first is the **transition month** (shift from previous season), the second is the **true season month**.

| Season | Month 1 (Transition) | Month 2 (True) |
|--------|---------------------|----------------|
| Spring | Quickening (Days 1-28) - transition from winter | Greening (Days 29-56) - true spring |
| Summer | Wide-Clover (Days 57-84) - transition from spring | High-Sun (Days 85-112) - true summer |
| Fall | Full-Earth (Days 113-140) - transition from summer | Reaping (Days 141-168) - true fall |
| Winter | Deepcold (Days 169-196) - transition from fall | Kindlemonth (Days 197-224) - true winter |

### Action items

- [ ] Update `scripts/autoloads/TimeManager.gd` to include a `is_transition_month() -> bool` helper function and a `get_season_phase() -> String` that returns "early" or "true"
- [ ] Audit all NPC dialogue files for month/season references and update to use the correct transition/true terminology where it matters narratively
- [ ] Update notification text that references seasons to be aware of the distinction where relevant
- [ ] No gameplay mechanical changes - this is a narrative/flavor distinction, not a system gate

---

## 2. SETTLED - Honey House starts open (no quest gate)

The Honey House is functional from game start. It is Uncle Bob's inherited workshop - old but working. The player never needs to "unlock" it.

### What exists at game start inside the Honey House

- Hand-crank 2-frame extractor (functional)
- Bottling station (functional)
- Scraping/uncapping station with basic cold knife and capping scratcher (functional)
- Workbench for lumber crafting (functional)
- Craft table for candles, infusions, polish (functional)
- Space for mead crocks (functional, crocks purchased separately from Tanner's)
- Finished goods shelf (empty, fills as player crafts)
- Goal board on the wall (empty, populates as player sets goals)

### What is eliminated

- **The outdoor Harvest Yard (Tier 0) is removed.** All extraction happens inside the Honey House. Delete or repurpose any scenes, scripts, or references to the outdoor harvest yard stations.
- **The +1.5% moisture penalty for "outdoor processing" is removed.** The base Honey House has no moisture bonus and no moisture penalty - it is neutral (0%).
- **Silas Q1 ("The Old Honey House"), Q2 ("Gathering Materials"), and Q3 ("Raising the Roof") as Honey House UNLOCK quests are eliminated.** Silas's quest chain is being redesigned. For now, remove or disable these three quests if implemented. Do NOT delete the Silas NPC or his other content.

### Action items

- [ ] Create or update the Honey House interior scene to include all stations listed above
- [ ] Move all extraction functionality (scraping minigame, extractor minigame, bottling) into the Honey House interior scene
- [ ] Remove the outdoor Harvest Yard scene and any references to it
- [ ] Remove the moisture penalty for Tier 0 extraction
- [ ] Ensure the Honey House is accessible from game start (no quest flag required to enter)
- [ ] Update any tutorial/quest text that references "building" or "restoring" the Honey House
- [ ] Update `GameData` or equivalent to track Honey House upgrade tier (starting at 0, max 4) for future use. The upgrade system itself is PENDING.

---

## 3. SETTLED - Energy bar replacement (Option B: invisible fatigue)

Remove the visible energy bar from the HUD. Replace with character animation states that communicate fatigue through observation.

### The system

- The underlying energy math (100/day, task costs, restoration from food/sleep) remains UNCHANGED
- The HUD energy bar is REMOVED
- The player reads their fatigue through their character's behavior:

| Energy range | Character behavior |
|-------------|-------------------|
| 100-70 | Normal animation. Full speed. Upright posture. |
| 69-50 | Slightly slower walk speed (-10%). Occasional stretch animation when idle. |
| 49-25 | Noticeably slower (-20%). Yawning animation when idle. Slightly hunched posture. Subtle screen edge softening. |
| 24-10 | Slow walk (-30%). Rubbing eyes when idle. Sits down after 5 seconds of idle. Dialogue prompt when trying heavy task: "You're worn out. Maybe call it a day?" (player can still proceed). |
| 9-0 | Cannot perform active tasks. Character sits down automatically. Dialogue: "You're exhausted. Time to rest." Can still walk, talk to NPCs, access menus. |

### Action items

- [ ] Remove the energy bar from the HUD scene
- [ ] Keep all energy tracking math in PlayerData. Energy still exists as an internal value.
- [ ] Add fatigue animation states to the player character based on thresholds above
- [ ] Add idle behavior changes: stretch at 50-69, yawn at 25-49, sit at 10-24
- [ ] Add walk speed modifiers based on energy thresholds
- [ ] Change "not enough energy" from UI gate to dialogue prompt
- [ ] Keep diner energy restoration, packed lunch, coffee, and nap mechanics
- [ ] Add optional "How am I feeling?" self-assessment in pause menu: qualitative descriptions only

---

## 4. SETTLED - Winterization equipment system

During Deepcold (transition month, Days 169-196), the player should apply winterization to their hives.

### Winterization components (applied per hive)

| Component | Source | Cost | Apply Energy | Effect | Risk if skipped |
|-----------|--------|------|-------------|--------|----------------|
| Entrance reducer | Tanner's | $5 | 2 | Reduces cold air intrusion. Required for mouse guard. | +5% winter loss probability |
| Mouse guard | Tanner's OR craft | $8 buy / free craft | 2 | Blocks mice from entering | Mice nest in hive: -15 condition, destroyed comb, contaminated stores |
| Moisture quilt box | Craft (shavings + box) | ~$5 materials | 4 | Absorbs condensation. Prevents moisture drip. | +10% winter loss probability |
| Hive wrap/insulation | Tanner's | $12-20 | 5 | Reduces heat loss from walls | +8% winter loss in harsh winters |
| Top insulation board | Tanner's | $8 | 2 | Insulates above cluster. Most important single item. | +5% winter loss probability |
| Candy board / fondant | Craft (sugar + water) | ~$4 materials | 4 | Emergency feed on top bars | High starvation risk if stores < 50 lbs |
| Ventilation shim | Craft (scrap wood) | Free | 1 | Upper entrance for moisture escape | Reduced quilt effectiveness |

### Tier system

| Approach | Components | Cost/hive | Energy/hive | Survival modifier |
|----------|-----------|-----------|-------------|-------------------|
| Bare minimum | Entrance reducer only | $5 | 2 | Base (no bonus) |
| Basic | Reducer + mouse guard + top insulation | $21 | 6 | +10% survival |
| Standard | Basic + moisture quilt + vent shim | ~$26 | 11 | +20% survival |
| Full protection | Standard + wrap + candy board | ~$42-50 | 20 | +28% survival |

### Action items

- [ ] Add winterization items to Tanner's Supply inventory
- [ ] Add craftable winterization items to workbench recipes
- [ ] Create winterization action per hive: menu to select and apply components
- [ ] Add winterization state tracking per hive in HiveManager
- [ ] Add spring damage states for unprotected hives (mouse damage, moisture damage)
- [ ] Update Bob Q6 to teach winterization with the component system

---

## 5. SETTLED - Safety net systems

### Dr. Harwick research nuc

If the player starts spring with 0-1 surviving hives, Dr. Harwick offers a subsidized nuc ($80 instead of $130) from her extension program. She visits 3-4 times during the year to inspect it for research data.

- Triggers: Spring Day 1-7, if 0-1 colonized hives
- Fires once per game
- Dr. Harwick visits create natural NPC presence at the apiary

### Carl's tab

If cash drops below $50 during spring, Carl offers $150 credit at Tanner's. Repay by end of High-Sun or take -5 Standing.

### Equipment floor

Equipment condition minimum is 5. Never destroyed by neglect alone. Always repairable.

### Action items

- [ ] Add Harwick research nuc trigger (spring Day 1-7, hive count check)
- [ ] Add Dr. Harwick periodic visit events (3-4/year after nuc accepted)
- [ ] Add Carl's tab system (cash check, credit tracking, repayment deadline)
- [ ] Set equipment condition floor: `condition = max(condition, 5)`

---

## 6. SETTLED - Annual Beekeeping Catalogue (Kindlemonth)

Every Kindlemonth, June delivers the annual catalogue. Player has 7 days to order. Items arrive Quickening Day 1.

- **Trigger:** Kindlemonth Day 5-7 (Day 201-203)
- **Window:** 7 days to browse and order
- **Early order bonus:** First 3 days = A and B grade queens. After day 3, B and C only.
- **Payment:** Full at order time. No credit.
- **Y1:** Bob teaches the player about the catalogue

### Catalogue items

| Item | Year available | Price | Notes |
|------|---------------|-------|-------|
| Package bees (3 lb) | Y1+ | $130 | Quality depends on timing |
| Nuc colony (5-frame) | Y1+ | $180 | Better start than package |
| Premium queen (A-grade) | Y2+ | $45 | Only in first 3 days |
| Electric uncapping knife | Y2+ | $75 | Speeds up uncapping |
| 4-frame radial extractor | Y3+ | $200 | Honey House upgrade |
| Roller uncapper | Y3+ | $435 | Both sides at once, no heat |
| Motorized chain uncapper | Y5+ | $2,000+ | Endgame aspiration |

### Action items

- [ ] Create catalogue UI (browsable item list)
- [ ] Add Kindlemonth delivery trigger with notification
- [ ] Add 7-day ordering window with early-order quality bonus
- [ ] Add Bob's Y1 teaching dialogue about the catalogue
- [ ] Track orders in SaveManager; deliver to Post Office on Quickening Day 1
- [ ] Add catalogue-exclusive items to item database

---

## 7. SETTLED - Equipment degradation consequences

| Condition | Visual | Production | Pest risk | Winter survival | Repair |
|-----------|--------|-----------|-----------|----------------|--------|
| 100-80 | Clean | None | None | None | Not needed |
| 79-60 | Minor wear | None | None | None | Optional polish |
| 59-40 | Weathered, gaps | -10% | +5% SHB | -3% | Basic repair ($25, +20) |
| 39-20 | Warped wood | -20% | +10% | -8% | Full refurb ($60, to 75) |
| 19-5 | Failing | -35% | +20% | -15% | Full refurb required |

### Degradation rates

| Situation | Per week |
|-----------|----------|
| Active use, maintained | -1 |
| Active use, unsheltered | -2 |
| No protective paint | -4 |
| Stored in shed | +1 |
| Furniture polish applied | +10 immediate, +2% waterproof |

### Action items

- [ ] Verify equipment condition system matches these tables
- [ ] Add visual states to hive overworld sprites by condition range
- [ ] Ensure condition floor is 5
- [ ] Add furniture polish as applicable to hive equipment

---

## PENDING - Do not implement yet

1. **Silas quest chain redesign** - 4 quests being reworked. Content not finalized.
2. **Honey House upgrade tiers (1-4)** - Needs economy validation.
3. **Decapper upgrade progression** - Integration with Honey House tiers vs catalogue.
4. **Winter workshop crafting scene** - Station layout and interaction model not finalized.
5. **Goal board / stats panel** - Stats list needs expansion (3x + achievements).
6. **Dynamic spring vignette** - Art and animation specs needed.
7. **Apiary capacity analysis** - NU/PU consequences for over-placing hives.
8. **Economy rebalance pass** - New items need pricing validation.
9. **Art asset audit** - New sprites needed for winterization, catalogue UI, degraded equipment.
10. **Tiered suggestion system** - General/struggling/diligent player suggestions.

---

## File change summary

| File/System | Change | Section |
|------------|--------|--------|
| `scripts/autoloads/TimeManager.gd` | Add helpers | 1 |
| NPC dialogue files | Audit + update | 1 |
| Honey House scene | Major rework | 2 |
| Outdoor Harvest Yard | DELETE | 2 |
| GameData / hive state | Add tier, winterization | 2, 4 |
| HUD scene | Remove energy bar | 3 |
| Player animations | Add fatigue states | 3 |
| PlayerData / energy | Keep math, hide display | 3 |
| Tanner's inventory | Add winterization items | 4 |
| Workbench recipes | Add winterization crafts | 4 |
| HiveManager / winter | Add winterization modifier | 4 |
| Bob Q6 | Update for components | 4 |
| Dr. Harwick NPC | Research nuc + visits | 5 |
| Carl NPC / shop | Credit tab | 5 |
| Equipment system | Verify values, add floor | 7 |
| Hive sprites | Condition visuals | 7 |
| Post Office / June | Catalogue delivery | 6 |
| New: Catalogue UI | Create | 6 |
| SaveManager | Track orders, states | 6, 7 |
| Silas Q1-Q3 | DISABLE | 2 |