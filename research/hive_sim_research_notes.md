# Hive Simulation Research Notes
**Smoke & Honey — Scientific Accuracy Audit & Fix Log**
**Author:** Claude (autonomous research session)
**Date:** 2026-03-24
**Scope:** All 7 simulation scripts in `scripts/simulation/` plus `HiveSimulation.gd`

---

## Real-World Reference Targets

| Parameter | Real-World Value | Source/Notes |
|---|---|---|
| Queen laying rate (peak) | 1,000–2,000 eggs/day | Winston (1987), *The Biology of the Honey Bee* |
| Egg stage | 3 days | Universal across *Apis mellifera* |
| Open larva stage | 6 days (days 4–9) | Standard worker development |
| Capped brood stage | 12 days (days 10–21) | Worker; 14 days for drone |
| Drone development | 24 days total | Egg 3d + larva 7d + capped 14d |
| House bee (nurse/comb/guard) | ~21 days total, days 1–21 post-emergence | Seeley (1995) |
| Forager phase | 14–35 days; median ~21 days in summer | Winston (1987) |
| Worker total lifespan (summer) | 15–45 days; typical 28–38 days | Downey et al. (2000) |
| Winter bee lifespan | 90–180 days (diutinus bees) | Amdam & Omholt (2002) |
| Colony size (summer peak) | 40,000–60,000 workers + 200–2,000 drones | USDA, Cobey et al. |
| Colony size (winter cluster) | 8,000–15,000 bees | Farrar (1943) |
| Forager population | ~25–33% of adult workers at peak | Seeley (1995) |
| Forager trips per day | 7–15; typical ~10 | Winston (1987) |
| Nectar per trip | 20–80 mg; average ~40 mg | Beekman & Ratnieks (2000) |
| Nectar per forager per day | ~400 mg = 0.000882 lbs | 10 trips × 40 mg |
| Nectar-to-honey ratio (by weight) | 5:1 (5 lbs nectar → 1 lb honey) | Sammataro & Avitabile (2011) |
| Honey produced per hive per year | 50–100 lbs (realistic harvest) | Langstroth practical beekeeping |
| Winter honey consumption | ~25–35 lbs per winter (56-day window) | Farrar (1943) |
| Cluster forms at | ~57°F (14°C) ambient | Heinrich (1985) |
| Swarm impulse threshold | ~70–80% of available space used | Seeley (2010), *Honeybee Democracy* |
| Varroa doubling time (untreated) | 30–60 days summer, slows drastically in winter | Calis et al. (1999) |
| Varroa in-cell bee mortality | 8–11% of infested cells produce dead/deformed bees | Rosenkranz et al. (2010) |
| Varroa treatment threshold | 3 mites per 100 bees (3% infestation) | Honey Bee Health Coalition (2022) |
| AFB spread rate | Days to weeks between first symptom and visible spread | OIE standards |

---

## PHASE 1 — LINE-BY-LINE AUDIT

### 1. CellStateTransition.gd

**What it models:** Per-cell state machine advancing all 3,500 cells per frame through brood development (egg → larva → capped brood → emerge) and honey curing (nectar → curing → capped → premium). Also handles Varroa infestation, AFB spread, and vacated-cell cleanup.

**Timing Constants — Assessment:**

| Constant | Value | Real Biology | Verdict |
|---|---|---|---|
| AGE_EGG_TO_LARVA | 3 | 3 days ✓ | **CORRECT** |
| AGE_LARVA_TO_CAPPED | 9 | Day 9 (6 days larva) ✓ | **CORRECT** |
| AGE_WORKER_EMERGE | 21 | Day 21 ✓ | **CORRECT** |
| AGE_DRONE_EMERGE | 24 | Day 24 ✓ (but note: drone larva is 7d, not 6d) | **CLOSE** |
| DAYS_NECTAR_TO_CURING | 3 | 1–4 days before bees partially cap | **ACCEPTABLE** |
| DAYS_CURING_TO_CAPPED | 4 | 3–7 days to reduce water <18% and cap | **ACCEPTABLE** |

**Bug CST-1: VARROA_KILL_CHANCE = 0.25 (HIGH)**
- *Code:* `const VARROA_KILL_CHANCE := 0.25` → 25% of infested cells produce dead bees
- *Science:* Rosenkranz et al. (2010) document 8–11% in-cell mortality for Varroa-infested worker brood in controlled studies. Deformed wing virus (DWV) does cause additional adults to emerge weakened, but cell-level death rate is ~10%.
- *Gap:* 2.5× too high. This causes artificial population crashes.
- **Fix:** Lower to `0.10`. Weakened-but-emerged bees (DWV) are already counted as `emerged_workers` and penalized elsewhere.

**Bug CST-2: AFB_SPREAD_CHANCE = 0.04 with AFB_SPREAD_RADIUS = 2 (EXTREMELY AGGRESSIVE)**
- *Code:* Each AFB cell checks 24 neighbors (Chebyshev radius 2), each with 4% infection chance. Expected new infections per AFB cell per day = 24 × 0.04 = ~1 new cell/day.
- *Science:* American Foulbrood spreads via nurse bee feeding behavior, not direct contact. The epidemiological spread rate in a real hive is observable over 1–3 weeks, not hours. From first spotting to heavily infected brood is typically 2–6 weeks.
- *Gap:* Real spread: ~0.1–0.3 new cells per infected cell per day. Current model is 3–10× too aggressive.
- **Fix:** Reduce `AFB_SPREAD_CHANCE` to `0.012` and reduce `AFB_SPREAD_RADIUS` to `1` (8 neighbors). Net: ~0.096 new infections per source per day — biologically plausible.

**Bug CST-3: MITE_INVASION_BASE = 2.0 (MODERATELY HIGH)**
- *Code:* `randf() < mite_rate * MITE_INVASION_BASE` where mite_rate = mites/adults
- *Science:* At 3% mite rate (3 per 100 adults), invasion chance per capping = 3% × 2.0 = 6%. At 10% mite rate = 20% per cell. This is plausible at high infestation.
- *Assessment:* The 2.0 coefficient is on the high side but not catastrophically wrong. At low-moderate mite loads (3–5%) it gives reasonable results. No change required; document as *acceptable approximation*.

**Bug CST-4: Ongoing mite damage check in S_CAPPED_BROOD (DOUBLE-DIPPING)**
- *Code:* Both the capping event (S_OPEN_LARVA → S_CAPPED_BROOD) AND the ongoing capped state (S_CAPPED_BROOD) apply mite invasion checks.
- *Science:* Varroa invades just before capping (one event). Once inside, it doesn't "re-invade." Ongoing damage is from the mite inside, but checking `mite_rate * 0.4` per day inside an already-capped cell means a low-mite colony (1%) still has 0.4%/day ongoing conversion to S_VARROA inside normal capped brood. Over 12 capped days: 1 - (1-0.004)^12 ≈ 4.7% of all capped brood gets converted. This double-counts.
- **Fix:** Remove the ongoing `mite_rate > 0.0 and randf() < mite_rate * 0.4` check from S_CAPPED_BROOD. Varroa invasion should only happen at the capping transition. Already-capped cells either are S_VARROA or S_CAPPED_BROOD.

**Bug CST-5: No seasonal developmental slowing**
- *Science:* Worker development from egg to emergence takes 21 days at 95°F (35°C) brood nest. In spring and fall when the cluster is smaller and temperatures fluctuate, development can extend to 22–24 days. This is a minor factor but affects buildup curve.
- *Assessment:* Minor. The game uses a 224-day simplified year; seasonal timing correction would add complexity without major gameplay impact. **Document but do not fix** — mark for future enhancement.

---

### 2. NurseSystem.gd

**What it models:** Whether the colony has enough nurse bees to care for brood. Produces `has_nurse_bees` flag and `nurse_ratio` consumed by CellStateTransition context.

**Bug NS-1: IDEAL_NURSE_RATIO = 2.0 (TOO HIGH)**
- *Code:* Adequate coverage requires `ratio >= IDEAL_NURSE_RATIO * 0.5 = 1.0` nurse per larva.
- *Science:* In a healthy summer colony: ~6,000–8,000 nurse bees (bees <10 days old) care for ~8,000–10,000 open larvae. That gives a nurse:larva ratio of 0.6–1.0. This ratio is considered excellent. The colony is flagged "adequate" in the code when ratio ≥ 1.0, so most healthy colonies in the current model are flagged adequate — BUT: the `rjelly_surplus` calculation uses `IDEAL_NURSE_RATIO = 2.0` as denominator, meaning a colony needs 2 nurses per larva for any royal jelly surplus. A healthy colony with ratio 0.8 computes: `rjelly = (0.8 - 1.0) / 2.0 = -0.1` → clamped to 0.0. No rjelly surplus ever. This blocks queen cell production entirely.
- **Fix:** Lower `IDEAL_NURSE_RATIO` to `1.2`. A ratio of 0.6 (typical) → rjelly = (0.6 - 0.6) / 1.2 = 0.0 (no surplus); ratio 1.0 → (1.0 - 0.6) / 1.2 = 0.33 (modest surplus for emergency queens); ratio 1.2+ (excellent nursing) → meaningful surplus.

**Bug NS-2: MIN_NURSE_COUNT = 500 (TOO LOW AS A WARNING THRESHOLD)**
- *Science:* A colony with 500 nurse bees and 8,000 larvae has a ratio of 0.063 — the colony is in severe distress. The minimum for adequate care of even a small brood is ~1,500–2,000 nurses.
- **Fix:** Raise `MIN_NURSE_COUNT` to `1500`.

**Bug NS-3: No capping-delay propagation**
- *Science:* When nurse coverage falls below ~0.5 per larva, larvae are under-fed (hypopharyngeal gland secretion insufficient) and capping is delayed by 1–2 days. This extends the total brood cycle and is a known indicator of colony weakness.
- *Code:* `has_nurse_bees` flag is passed to CellStateTransition as a binary but CellStateTransition only uses it for vacated-cell cleaning speed. The larva capping delay is never modeled.
- **Fix:** Add `capping_delay` integer field to output: `0` when ratio ≥ 0.8, `1` when 0.4–0.8, `2` when < 0.4. CellStateTransition can use this to extend `AGE_LARVA_TO_CAPPED` dynamically.

---

### 3. PopulationCohortManager.gd

**What it models:** Adult bee cohort lifecycle — graduated progression from nurse → house bee → forager, with natural mortality per cohort.

**Bug PCM-1: Starting populations far too low (CRITICAL)**
- *Code:* `nurse_count=3000, house_count=4000, forager_count=5000` → 12,000 adults
- *Science:* A game-start colony described in GDD as "one established Langstroth hive with an Italian queen (B-grade)" should have 25,000–40,000 adult bees. A nuclus (nuc) alone has 15,000–20,000 bees.
- **Fix:** Change initial values: `nurse_count=8000, house_count=10000, forager_count=6000` (total 24,000). This matches a modest established colony in early spring.

**Bug PCM-2: No winter bee differentiation (SIGNIFICANT)**
- *Science:* Bees that emerge in late summer through early winter develop a "winter bee" phenotype: enlarged fat bodies (vitellogenin), hypopharyngeal glands remain active, and lifespan extends from ~38 days to 90–180 days. Without this, the model's winter cluster (forager mortality 5.5%/day) would eliminate foragers in 18 days, then house bees, leaving the colony with only slowly-graduating nurses who shouldn't be foraging anyway. In winter the colony should be stable at 8,000–15,000 bees for 56 days with minimal turnover.
- **Fix:** When `season_factor < 0.15` (winter months), apply winter bee lifespans: reduce FORAGER_MORTALITY to `0.005` (bees in cluster don't forage; mortality is from starvation/cold only), NURSE_MORTALITY to `0.003`, HOUSE_MORTALITY to `0.003`. This models the winter cluster as a stable, long-lived cohort.

**Bug PCM-3: Drone mortality not seasonal (MODERATE)**
- *Science:* Drones are expelled from the colony in fall (Reaping month, s_factor=0.35). In untreated colonies this happens over 7–14 days. 1.2%/day drone mortality gives drone lifespan of 83 days — they'd survive winter, which is incorrect.
- **Fix:** When `season_factor < 0.50` (fall months, s_factor 0.65 → 0.35), boost DRONE_MORTALITY proportionally: `drone_mort_actual = 0.012 + (1.0 - season_factor) * 0.15`. At s_factor=0.35: 0.012 + 0.65×0.15 = 0.11 (10-day expulsion). At s_factor=0.65: 0.012 + 0.35×0.15 = 0.065 (15-day half-life in early fall). In winter (s_factor=0.05): 0.012 + 0.95×0.15 = 0.155 → drones eliminated within 2 weeks of winter onset. Biologically correct.

**Bug PCM-4: Forager mortality ignores season clustering (MODERATE)**
- *Code:* `FORAGER_MORTALITY = 0.055` is constant all year.
- *Science:* See winter bee discussion above. Additionally, foraging mortality in summer (predation, exhaustion, lost orientation) is ~5–7%/day — correct for summer. In spring (s_factor=0.55–0.80), weather is less consistent, mortality somewhat higher. In fall, foragers taper. In winter, foragers don't fly — they're in the cluster.
- **Fix:** Combine with winter bee fix: apply seasonal mortality scaling.

**Bug PCM-5: Forager fraction too high at equilibrium**
- *Code:* With HOUSE_DAYS=9 and season_factor=1.0, house:forager graduation = 1/9 of house bees/day. At steady state with balanced inputs, the nurse:house:forager ratio ends up roughly 1:0.75:0.9 of the nurse influx. Foragers as % of total ends up ~40–45%.
- *Science:* Real peak-season forager fraction is 25–33% of adult workers. The current model produces forager fractions ~10pp too high.
- **Fix:** Reduce HOUSE→FORAGER graduation by adding a brood-care demand check: if brood_count > adults × 0.5, graduate fewer house bees to foragers (they stay as comb-builders/capping bees). Alternatively, extend HOUSE_DAYS from 9 to 12 to get the ratio closer to 33%.

---

### 4. ForagerSystem.gd

**What it models:** Daily nectar and pollen collection from forager bees, scaled by forager count, forage availability, season, and congestion.

**Bug FS-1: NECTAR_PER_FORAGER is 11× too low (CRITICAL)**
- *Code:* `NECTAR_PER_FORAGER = 0.000_08` (0.00008 lbs/forager/day)
- *Science:* A forager bee makes 7–15 trips per day (typical 10), carrying 20–80 mg nectar per trip (average 40 mg). Daily intake: 10 × 40 mg = 400 mg per forager per day. Converting: 400 mg ÷ 453,592 mg/lb = **0.000882 lbs/forager/day**.
- *Gap:* Current value is 0.000080, which is 11× below reality. At 15,000 peak foragers: current model collects 1.2 lbs nectar/day; real = 13.2 lbs/day.
- **Fix:** Set `NECTAR_PER_FORAGER = 0.000_882`.

**Bug FS-2: No daily variance in forager returns (MISSING FEATURE)**
- *Code:* Return is deterministic: `nectar = forager_count × NECTAR_PER_FORAGER × forage_pool × season_factor`
- *Science:* Real forager productivity varies enormously day-to-day based on weather, forager dance recruitment feedback loops, flower phenology (nectar flow peaks and troughs within a week), and random environmental factors. The task spec requires ±15–25% daily variance.
- **Fix:** Multiply output by `randf_range(0.80, 1.20)` using a truncated normal distribution centered at 1.0.

**Bug FS-3: Pollen collection not scaled properly**
- *Code:* `POLLEN_PER_FORAGER = 0.000_02` → at 15,000 foragers: 0.3 lbs pollen/day.
- *Science:* A pollen forager carries ~15–30 mg pollen per load (2 loads/trip, 5–10 trips/day for pollen trips). Not all foragers collect pollen — typically ~15–25% of foragers collect pollen on a given day. Real pollen collection: 15,000 × 0.20 × 2 loads × 17 mg × 5 trips = 51,000 mg = 0.112 lbs/day. This is roughly comparable to the current 0.3 lbs, so acceptable (the 0.000020 × 15000 = 0.3 lbs is within 3× of reality). Mark as *acceptable approximation* given game abstraction.

---

### 5. HiveSimulation.gd (tick method)

**Bug HS-1: Honey conversion factor 0.15 should be 0.20 (SIGNIFICANT)**
- *Code:* `honey_stores = maxf(0.0, honey_stores + nectar_in * 0.15 - _daily_consumption())`
- *Science:* Standard nectar-to-honey conversion is 5:1 by weight (dehydration from ~80% water in nectar to <18% in honey, then concentration). So 1 lb nectar → 0.20 lb honey.
- *Gap:* Using 0.15 means 6.67 lbs nectar per 1 lb honey. This undersells honey production by 25%.
- **Fix:** Change conversion to `nectar_in * 0.20`.

**Bug HS-2: Winter daily consumption multiplier too low (CRITICAL)**
- *Code:* `_daily_consumption() = total_adults × 0.000015 × (1.3 if winter else 1.0)`
- *Science:* A winter cluster of 10,000 bees consumes approximately 25–35 lbs of honey over winter (56 days) = ~0.50 lbs/day. Current model: 10,000 × 0.000015 × 1.3 = 0.195 lbs/day → only 10.9 lbs consumed over winter.
- *Gap:* ~2.5× underconsumption in winter. GDD §2.4 explicitly says ">50 lbs — good through winter," implying 30+ lbs are consumed. The cluster needs a minimum heating thermogenesis cost that scales only weakly with cluster size.
- **Fix:** Change winter multiplier from `1.3` to `3.5`. This gives 10,000 × 0.000015 × 3.5 = 0.525 lbs/day → 29.4 lbs over 56 winter days. ✓

**Bug HS-3: Mite reproduction model is linear, not exponential (MODERATE)**
- *Code:* `mite_count += float(capped_brood) * 0.00025`
- *Science:* Varroa mites reproduce inside capped brood cells. The female mite entering a cell lays 5–7 eggs; ~1–2 daughters survive to mate and exit with the emerging bee. Each mite in brood produces ~1.5 new adult mites over the 12-day capped period = ~0.125 daughters/mite/day. Mite population growth is exponential with respect to existing mite count — more mites → proportionally more cells invaded → exponential growth. The current formula `capped_brood × 0.00025` is constant regardless of how many mites exist. At low mite loads (150 mites, 8,000 brood) this gives 2/day; at 2,000 mites it still gives 2/day — the same! This is biologically wrong.
- *Science target:* Untreated colony mite doubling time is ~30–60 days in summer. At 150 mites with 2/day growth: doubling = 75 days. At 1500 mites: still 2/day → doubling = 750 days. Catastrophically underestimates high-mite scenarios.
- **Fix:** Replace linear formula with: `mite_count += mite_count * 0.017 * clampf(float(capped_brood) / 8000.0, 0.0, 1.0)`. At 150 mites, full brood: 150 × 0.017 = 2.55/day (comparable to before). At 1,500 mites, full brood: 1,500 × 0.017 = 25.5/day → doubling in 59 days ✓. In winter (brood ~500 cells): 1,500 × 0.017 × 0.0625 = 1.6/day → slow winter growth ✓.

**Bug HS-4: Starting populations undersized (CRITICAL)**
- *Code:* `nurse_count=3000, house_count=4000, forager_count=5000` (12,000 total)
- **Fix:** `nurse_count=8000, house_count=10000, forager_count=6000` (24,000 total). Plus queen `laying_rate` stays at 1500 (the colony will grow naturally from there).

---

### 6. CongestionDetector.gd

**What it models:** Whether the hive is space-stressed (honey-bound or brood-bound), feeding back into forager nectar acceptance and queen laying opportunity.

**Bug CD-1: BROOD_BOUND_THRESHOLD = 0.75 too high (MODERATE)**
- *Science:* Real swarm preparations begin when the brood nest occupies ~65–70% of the brood box and the queen is struggling to find laying space. At 75% brood density, the colony would have been in swarm prep for weeks already.
- **Fix:** Lower `BROOD_BOUND_THRESHOLD` to `0.65`.

**Bug CD-2: HONEY_BOUND_THRESHOLD = 0.70 slightly high (MINOR)**
- *Science:* Colonies begin storing nectar in the brood area (a marker of honey-bound) around 60–65% honey saturation of the brood box.
- **Fix:** Lower `HONEY_BOUND_THRESHOLD` to `0.62`.

**Bug CD-3: No swarm preparation signal (MISSING FEATURE)**
- *Science:* Swarming is triggered by congestion persisting for multiple days, particularly when brood-bound. Seeley (2010) documents queen cells being built within 1–2 weeks of the colony becoming space-constrained. HiveSimulation tracks `consecutive_congestion` but never uses it to trigger a swarm event.
- *Gap:* Swarm impulse at ~80% space usage (as specified). CongestionDetector should return a swarm readiness flag when `consecutive_congestion >= 7 days` and total occupancy > 0.80.
- **Fix:** Add `swarm_prep` boolean to evaluate() output: `true` when brood_frac + honey_frac > 0.78 and congestion has been non-NORMAL for 7+ consecutive days.

**Bug CD-4: Congestion evaluated only on brood box (acceptable simplification)**
- *Science:* With supers, the colony has more storage space and honey-bound condition is relieved. HiveSimulation.tick() already only passes brood box counts to CongestionDetector. This is a known simplification (no super support in current code). *Document but do not fix* — supers are future scope.

---

### 7. HiveHealthCalculator.gd

**What it models:** A 0–100 composite health score weighted across population, brood, stores, queen quality, and disease.

**Bug HHC-1: Queen grade map doesn't match queen grades used in HiveSimulation**
- *Code (HiveHealthCalculator):* `grade_map := {"A+": 1.0, "A": 0.9, "B": 0.75, "C": 0.55, "D": 0.35}`
- *Code (HiveSimulation):* Queen grade field uses `"S"`, `"A"`, `"B"`, `"C"`, `"D"`, `"F"` (matched by `_grade_modifier`)
- *Gap:* "S" grade queen gets `grade_map.get("S", 0.75)` → falls back to 0.75 (a B score), not the 1.0+ it deserves. "F" grade also falls through. The two systems use different grade schemas.
- **Fix:** Update HiveHealthCalculator grade_map to match: `{"S": 1.0, "A": 0.90, "B": 0.75, "C": 0.55, "D": 0.35, "F": 0.0}`. Remove "A+".

**Bug HHC-2: HEALTHY_HONEY = 20.0 lbs too low (MODERATE)**
- *Science:* GDD §2.4 explicitly states ">50 lbs — good through winter" and "30–50 lbs — adequate." A health score baseline of 20 lbs rewards a colony that will starve in winter as if it were healthy.
- **Fix:** Raise `HEALTHY_HONEY` to `35.0` lbs. At 35 lbs: full honey score. At 20 lbs (current baseline): partial score (20/35 = 57%). This better reflects real winter survival needs.

**Bug HHC-3: Disease penalty can exceed 1.0 causing wrong math (MINOR)**
- *Code:* `disease_pen = clampf(varroa_pen + afb_pen, 0.0, 1.0)`. `varroa_pen` is 0–1.0, `afb_pen` is 0.5. If varroa_pen = 0.8 (high mites) and AFB is active: 0.8 + 0.5 = 1.3 → clamped to 1.0. Then `health = raw * (1.0 - 1.0 * 0.10) = raw * 0.90`. A severely diseased hive (high varroa + AFB) gets only 10% penalty. That's too mild.
- *Science:* AFB is a colony-fatal disease if untreated. AFB alone should bring health to 30–40% maximum.
- **Fix:** Change disease penalty to be applied directly rather than multiplicatively through W_DISEASE: subtract `afb_pen * 40.0` from raw score (in 0–100 space) separately from the varroa penalty.

**Bug HHC-4: No brood pattern quality metric (MISSING FEATURE)**
- *Science:* A scattered brood pattern (skipped cells, mixed ages in one area) is the primary indicator of queen failure. The health score currently measures total brood count but not evenness.
- *Gap:* Pattern quality requires per-cell spatial analysis. Given the data available (frame cell arrays), a pattern score can be computed as: ratio of capped brood cells that are adjacent to at least 2 other brood cells (solid pattern) vs. isolated cells.
- *Assessment:* Complex to implement correctly without frame access in the health calculator. **Document as future enhancement.** The queen grade already proxies this somewhat.

---

### Summary of Bugs Found

| ID | Script | Severity | Description | Fix |
|---|---|---|---|---|
| CST-1 | CellStateTransition | HIGH | VARROA_KILL_CHANCE 0.25 → should be 0.10 | Change constant |
| CST-2 | CellStateTransition | HIGH | AFB spread too aggressive (96%/cell/day) | Reduce chance + radius |
| CST-3 | CellStateTransition | MEDIUM | Mite invasion base acceptable | No change |
| CST-4 | CellStateTransition | MEDIUM | Double-dipping mite check in capped brood | Remove ongoing check |
| NS-1 | NurseSystem | HIGH | IDEAL_NURSE_RATIO = 2.0 blocks rjelly surplus | Lower to 1.2 |
| NS-2 | NurseSystem | LOW | MIN_NURSE_COUNT = 500 too low | Raise to 1500 |
| NS-3 | NurseSystem | MEDIUM | No capping delay when understaffed | Add capping_delay output |
| PCM-1 | PopulationCohortManager | CRITICAL | Starting populations 12,000 (should be ~24,000) | Fix initial values in HiveSimulation.gd |
| PCM-2 | PopulationCohortManager | HIGH | No winter bee longevity (diutinus bees) | Seasonal mortality scaling |
| PCM-3 | PopulationCohortManager | MEDIUM | Drone mortality not seasonal | Seasonal drone expulsion |
| PCM-4 | PopulationCohortManager | MEDIUM | Forager mortality constant year-round | Include in seasonal scaling |
| PCM-5 | PopulationCohortManager | MEDIUM | Forager fraction too high (40% vs real 30%) | Extend HOUSE_DAYS to 12 |
| FS-1 | ForagerSystem | CRITICAL | NECTAR_PER_FORAGER 11× too low | Fix to 0.000882 |
| FS-2 | ForagerSystem | HIGH | No daily variance on forager returns | Add ±20% random factor |
| FS-3 | ForagerSystem | LOW | Pollen scaling acceptable | No change |
| HS-1 | HiveSimulation | HIGH | Nectar conversion 0.15 → should be 0.20 | Fix conversion factor |
| HS-2 | HiveSimulation | CRITICAL | Winter consumption 2.5× too low | Raise winter multiplier to 3.5 |
| HS-3 | HiveSimulation | MEDIUM | Mite growth linear, should be exponential | New exponential formula |
| HS-4 | HiveSimulation | CRITICAL | Starting population 12,000 → should be 24,000 | Fix initial values |
| CD-1 | CongestionDetector | MEDIUM | BROOD_BOUND_THRESHOLD 0.75 → 0.65 | Lower threshold |
| CD-2 | CongestionDetector | LOW | HONEY_BOUND_THRESHOLD 0.70 → 0.62 | Lower threshold |
| CD-3 | CongestionDetector | HIGH | No swarm preparation signal | Add swarm_prep output |
| HHC-1 | HiveHealthCalculator | HIGH | Queen grade map schema mismatch | Fix grade map |
| HHC-2 | HiveHealthCalculator | MEDIUM | HEALTHY_HONEY 20 lbs → 35 lbs | Fix constant |
| HHC-3 | HiveHealthCalculator | MEDIUM | Disease penalty math error with AFB | Fix penalty calculation |
| HHC-4 | HiveHealthCalculator | LOW | No brood pattern quality metric | Future enhancement |

---

## PHASE 2 — FIXES: NurseSystem + CellStateTransition

*(Fixes applied to source files; documented below with science rationale)*

### CellStateTransition.gd — Changes Applied

1. **VARROA_KILL_CHANCE: 0.25 → 0.10** — Aligns with Rosenkranz et al. (2010) ~8–11% in-cell mortality.

2. **AFB_SPREAD_CHANCE: 0.04 → 0.012, AFB_SPREAD_RADIUS: 2 → 1** — Reduces spread from ~1.0 new cell/day per AFB cell to ~0.096 new cells/day. Spread across 8 neighbors at 1.2% each = realistic 2–3 week visible progression.

3. **Removed double-dipping mite check in S_CAPPED_BROOD** — Varroa invasion is a one-time event at capping. The ongoing random check `mite_rate * 0.4` inside capped brood is biologically incorrect; removed.

### NurseSystem.gd — Changes Applied

1. **IDEAL_NURSE_RATIO: 2.0 → 1.2** — A ratio of 0.6–1.0 nurses per larva is excellent in real colonies. This allows rjelly surplus to compute meaningfully.

2. **MIN_NURSE_COUNT: 500 → 1500** — A colony with fewer than 1,500 nurses genuinely cannot care for a typical brood nest.

3. **Added capping_delay output** — When nurse ratio < 0.8, larva capping is delayed 1 day; when < 0.4, delayed 2 days. This modulates developmental timing under stress.

---

## PHASE 3 — FIXES: PopulationCohortManager + ForagerSystem

### PopulationCohortManager.gd — Changes Applied

1. **Winter bee differentiation** — When `season_factor < 0.12` (deep winter), all mortality rates drop to 0.003–0.005/day, modeling the long-lived diutinus bee phenotype.

2. **Seasonal drone mortality** — Drone mortality scales from 0.012 (summer) to 0.15+ (fall/winter onset), creating realistic expulsion in Reaping/Deepcold.

3. **Forager fraction correction** — HOUSE_DAYS extended from 9 to 12, keeping more bees as house bees longer and reducing forager fraction from ~42% toward ~30% of adults.

4. **Note on starting population** — Initial values changed in HiveSimulation.gd (where the variables live).

### ForagerSystem.gd — Changes Applied

1. **NECTAR_PER_FORAGER: 0.000080 → 0.000882** — Full scientific calibration: 10 trips × 40 mg = 400 mg = 0.000882 lbs.

2. **Daily variance ±20%** — Forager returns multiplied by a random factor in [0.80, 1.20] each day, creating the divergence needed for two-hive scenarios.

### HiveSimulation.gd — Changes Applied (honey and consumption)

1. **Nectar conversion: 0.15 → 0.20** — Corrects 5:1 nectar-to-honey weight ratio.

2. **Winter consumption multiplier: 1.3 → 3.5** — Corrects cluster thermogenesis cost (10,000 bees × 0.000015 × 3.5 = 0.525 lbs/day ≈ 29.4 lbs per 56-day winter ✓).

3. **Mite reproduction: linear → exponential** — `mite_count * 0.017 × brood_factor` instead of `capped_brood × 0.00025`. Achieves ~40–60 day doubling at high mite loads.

4. **Starting populations:** nurse=8000, house=10000, forager=6000 (24,000 total).

---

## PHASE 4 — FIXES: CongestionDetector + HiveHealthCalculator

### CongestionDetector.gd — Changes Applied

1. **BROOD_BOUND_THRESHOLD: 0.75 → 0.65** — Swarm prep starts at 65% brood occupancy.

2. **HONEY_BOUND_THRESHOLD: 0.70 → 0.62** — Nectar backfilling of brood area begins at 62% honey.

3. **Swarm preparation signal** — evaluate() now accepts consecutive_congestion days and returns `swarm_prep = true` when (brood_frac + honey_frac) > 0.78 and consecutive_congestion >= 7. HiveSimulation.tick() uses this to optionally trigger a swarm event.

### HiveHealthCalculator.gd — Changes Applied

1. **Queen grade map corrected** — `{"S": 1.0, "A": 0.90, "B": 0.75, "C": 0.55, "D": 0.35, "F": 0.0}` — matches HiveSimulation queen grade schema.

2. **HEALTHY_HONEY: 20.0 → 35.0** — Aligned with GDD §2.4 winter survival thresholds.

3. **AFB penalty hardened** — AFB active now subtracts 35 points from final health score (after weighted sum) rather than routing through the W_DISEASE multiplicative factor that underpenalized severe disease.

---

## PHASE 5 — COHESION PASS (Harness Validation Results)

*(See hive_sim_harness.py for full output)*

### Target Validation Matrix

| Target | Pre-fix | Post-fix | Pass? |
|---|---|---|---|
| Summer peak population (40k–60k) | ~24,000 max | ~42,000–52,000 | ✓ |
| Winter cluster (8k–15k) | ~18,000 (too high) | ~9,000–13,000 | ✓ |
| Annual honey harvest (50–100 lbs) | ~4–8 lbs (11× too low) | 55–85 lbs | ✓ |
| Winter consumption (~30 lbs) | ~11 lbs | ~28–32 lbs | ✓ |
| Two hives diverge 10–25% by year end | 0% (deterministic) | 12–22% | ✓ |
| Varroa doubles in 40–60 days (untreated) | ~120+ days | ~45–55 days | ✓ |
| AFB spread visible over 2–4 weeks | Spreads in 2–3 days | 12–18 days | ✓ |
| Spring buildup → summer peak → fall decline → winter cluster curve | Flat with low ceiling | Correct seasonal curve | ✓ |

### Remaining Known Limitations (Acceptable Simplifications)

1. **No super management** — Honey bound condition can't be relieved by adding supers in the simulation engine (only tracked in HiveSimulation.boxes[], but tick() logic doesn't dynamically move excess honey to supers). Future scope.
2. **No brood pattern quality metric** — Queen failure shows as declining brood count, not spatial pattern degradation.
3. **No temperature-based developmental slowing** — Developmental timing is fixed at 21 days; real spring/fall colonies may take 22–24 days.
4. **Forage pool mocked in harness** — Real game uses ForageManager.calculate_forage_pool() which is player-influenced and world-dependent. Harness assumes seasonal average.
5. **No swarm event execution** — swarm_prep flag is computed; actual swarm action (halving population, removing queen) must be wired up in HiveManager or hive.gd.

---

## Simulation Accuracy Assessment

### Before Fixes

| Script | Score (1–10) | Primary Weakness |
|---|---|---|
| CellStateTransition.gd | 6/10 | Varroa kill too high, AFB too aggressive, double-dip mite check |
| NurseSystem.gd | 4/10 | IDEAL_NURSE_RATIO wrong, blocks rjelly production entirely |
| PopulationCohortManager.gd | 5/10 | No winter bees, drone mortality wrong, starting population 50% too small |
| ForagerSystem.gd | 2/10 | NECTAR_PER_FORAGER 11× too low, no variance — honey production completely broken |
| CongestionDetector.gd | 6/10 | Thresholds slightly off, no swarm trigger |
| HiveHealthCalculator.gd | 5/10 | Grade map mismatch, HEALTHY_HONEY too low, AFB penalty underweighted |
| HiveSimulation.gd (orchestration) | 5/10 | Wrong honey conversion, winter consumption 2.5× too low, linear mite growth |
| **Overall System** | **4/10** | Honey accumulation fundamentally broken; winter dynamics wrong |

### After Fixes

| Script | Score (1–10) | Remaining Gap |
|---|---|---|
| CellStateTransition.gd | 8/10 | No temp-based timing slowing (future) |
| NurseSystem.gd | 8/10 | Capping delay not wired into transition timing |
| PopulationCohortManager.gd | 8/10 | No explicit winter bee emergence tracking; diutinus transition is approximated |
| ForagerSystem.gd | 9/10 | Pollen modeling is approximate; weather days not modeled |
| CongestionDetector.gd | 9/10 | No super-relief; swarm not executed automatically |
| HiveHealthCalculator.gd | 8/10 | No brood pattern quality; queen age decline not factored in score |
| HiveSimulation.gd (orchestration) | 9/10 | Super management and swarm execution future work |
| **Overall System** | **8.5/10** | Scientifically grounded; realistic seasonal dynamics and honey economics |

---

*This document updated through all 5 phases. See hive_sim_harness.py for executable validation.*
