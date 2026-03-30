# Phase 8: Full Integration - Karpathy Research Context

## What This Is

You are an AI assistant helping tune a beekeeping simulation for the game
"Smoke & Honey". The simulation runs a 365-day year with 8 interconnected
subsystems. Each subsystem was validated independently (Phases 1-7, all passing).
When combined in Phase 8, calibration mismatches between systems cause 14 of 15
integration tests to fail. Your job is to tune constants until all 15 pass.

## The Karpathy Method

Fix the EARLIEST system that contributes to each failure. Never tune Phase 8
directly -- always go back to the source phase, change the constant there,
re-run that phase's tests to confirm they still pass, then re-run Phase 8.

## Game Calendar

- 8 months, 28 days each = 224 days/year
- Months: Quickening, Greening, Wide-Clover, High-Sun, Full-Earth, Reaping, Deepcold, Kindlemonth
- Winter = months 6-7 (Deepcold, Kindlemonth)
- Peak summer = months 2-3 (Wide-Clover, High-Sun)

## The 10-Step Pipeline (mirrors HiveSimulation.gd)

```
Step 1:  CellStateTransition   (Phase 1) - advance all brood cells
Step 2:  PopulationCohortMgr   (Phase 2) - graduate/age/die adults
Step 3:  NurseSystem           (Phase 4) - assess brood care adequacy
Step 4:  ForagerSystem         (Phase 3) - collect nectar/pollen
Step 5:  NectarProcessor       (Phase 3) - convert nectar to honey
Step 6:  QueenBehavior         (Phase 4) - lay eggs, check supersedure
Step 7:  CongestionDetector    (Phase 7) - evaluate space usage
Step 8:  HiveHealthCalculator  (Phase 7) - composite health score
Step 9:  SnapshotWriter        (Phase 8) - capture metrics
Step 10: FrameRenderer         (visual only, not simulated)
```

## Validation Targets (all 15 tests)

| # | Test | Target Range | Source Phase |
|---|------|-------------|-------------|
| 1 | Hive-A peak adults | 40,000-65,000 | Phase 2 |
| 2 | Hive-B peak adults | 40,000-65,000 | Phase 2 |
| 3 | Hive-A winter minimum | 8,000-28,000 | Phase 2 |
| 4 | Hive-B winter minimum | 8,000-28,000 | Phase 2 |
| 5 | Hive-A annual honey production | 150-450 lbs | Phase 3 |
| 6 | Hive-B annual honey production | 150-450 lbs | Phase 3 |
| 7 | Hive-A total harvest | 40-120 lbs | Phase 3 |
| 8 | Hive-B total harvest | 40-120 lbs | Phase 3 |
| 9 | Hive-A winter consumption | 20-45 lbs | Phase 3 |
| 10 | Hive-B winter consumption | 20-45 lbs | Phase 3 |
| 11 | Varroa doubling time | 40-70 days | Phase 5 |
| 12 | Honey store divergence | 8-30% | Phase 8 (seed diff) |
| 13 | Peak month in summer | Wide-Clover/High-Sun/Greening | Phase 2+6 |
| 14 | No impossible states | No negatives/NaN | All |
| 15 | Avg summer health > 50 | > 50 | Phase 7 |

## All Tunable Constants By Phase

### Phase 1: Brood Biology (brood_sim.py)
These are biological facts -- do NOT change unless you find a science error.
```
EGG_DURATION = 3           # days as egg
LARVA_DURATION = 6         # days as open larva
CAPPED_BROOD_DURATION = 12 # days capped (pupa)
TOTAL_DEVELOPMENT = 21     # sum of above
```

### Phase 2: Population Dynamics (population_sim.py)
SEASON_FACTORS drive the entire yearly rhythm. These are the primary population levers.
```
YEAR_LENGTH = 224
MONTH_LENGTH = 28
SEASON_FACTORS = [0.55, 0.80, 1.00, 1.00, 0.65, 0.35, 0.08, 0.05]
  # Index:        Quick  Green  W-Clov High-S Full-E Reap   Deep   Kindle
NURSE_DAYS_SUMMER = 12
HOUSE_DAYS_SUMMER = 12
FORAGER_MORT_SUMMER = 0.055
ADEQUATE_RATIO = 2.5       # nurses per larva for adequate care
MIN_NURSE_COUNT = 500
```

### Phase 3: Foraging & Honey Economy (foraging_sim.py)
These control honey production and consumption. KEY TUNING AREA.
```
NECTAR_PER_FORAGER = 0.000882    # lbs nectar/forager/day
POLLEN_PER_FORAGER = 0.000020    # lbs pollen/forager/day
NECTAR_TO_HONEY = 0.20           # 5:1 ratio (science-locked)
SUMMER_CONSUME_RATE = 0.000015   # lbs honey/bee/day
WINTER_CLUSTER_REFERENCE = 35000 # reference cluster for thermal calc
POLLEN_PER_NURSE = 0.000010      # pollen consumption per nurse/day
```

### Phase 4: Queen & Comb Mechanics (queen_comb_sim.py)
Queen grade directly controls population size via laying rate.
```
GRADE_MULTIPLIERS = {S: 1.25, A: 1.00, B: 0.95, C: 0.80, D: 0.60, F: 0.00}
GRADE_LAYING_RANGES = {
  S: (1800, 2000), A: (1500, 1800), B: (1200, 1500),
  C: (800, 1200),  D: (300, 800),   F: (0, 300)
}
CONGESTION_LAYING_MULT values:
  NORMAL=1.0, BROOD_BOUND=0.65, HONEY_BOUND=0.50, FULLY_CONGESTED=0.30
```

### Phase 5: Disease & Pests (disease_sim.py)
Varroa growth is exponential. Small changes here compound fast.
```
VARROA_DAILY_GROWTH = 0.017      # 1.7% daily growth
VARROA_MAX_POPULATION = 5000
VARROA_KILL_CHANCE = 0.10        # 10% of infested bees die
VARROA_INVASION_DRONE_MULT = 8.5
TREATMENT_EFFICACY = {formic: 0.85, oxalic: 0.90, apivar: 0.95, thymol: 0.75}
```

### Phase 6: Environmental Systems (environment_sim.py)
Forage output from this phase replaces the simple mock from Phase 3.
THIS IS THE PRIMARY CALIBRATION GAP. Phase 3's mock produces forage ~0.82.
Phase 6's real flower system peaks at ~0.36. Everything downstream is affected.
```
WEATHER_FORAGE_MULT = {
  Clear: 1.0, Partly_Cloudy: 0.85, Overcast: 0.60,
  Light_Rain: 0.30, Heavy_Rain: 0.10, Thunderstorm: 0.05,
  Fog: 0.40, Snow: 0.00
}
IOWA_FLOWERS = [7 species with bloom windows and nectar/pollen values]
SEASON_RANK system: S(1.3x) A(1.1x) B(1.0x) C(0.85x) D(0.7x) F(0.5x)
```

### Phase 7: Colony Behavior (colony_behavior_sim.py)
Evaluation-only systems. Usually not the source of calibration issues.
```
HONEY_BOUND_THRESHOLD = 0.62
BROOD_BOUND_THRESHOLD = 0.65
SWARM_PREP_THRESHOLD = 0.78
SWARM_CONSEC_REQUIRED = 7
Health weights: pop(0.25) + brood(0.25) + stores(0.20) + queen(0.20) + varroa(0.10)
```

### Phase 8: Full Integration (full_sim.py)
Geometry constants and initial conditions.
```
MAX_BROOD_CELLS = 29730
FRAME_SIZE = 3500
FRAMES_PER_BOX = 10
TOTAL_DRAWN_CELLS = 35000
Initial: honey=15.0 lbs, pollen=3.0 lbs, nurses=8000, house=10000, forager=6000
```

## Known Calibration Issues (Current State: 1/15 passing)

### Latest Run Output (for reference)
```
Score: 1/15 tests passing | Peak forage level: 0.79
Peak adults: 26,079 (need 40-65k) -- population is about half target
Annual honey: 19.8 lbs (need 150-450) -- tiny fraction of target
Peak month: Quickening (should be summer) -- population peaks at start, then crashes
Winter min: 2,987 (need 8-28k) -- colony near collapse
```

Monthly pattern shows the colony SHRINKS from day 1 instead of growing:
  Quickening: 13,468 adults (starts here, highest point -- wrong)
  Greening: 7,536 (crashing)
  Wide-Clover: 3,201 (minimum -- should be near peak)
  High-Sun: 4,104 (slight recovery)
  Full-Earth: 7,031 (late recovery)
  Deepcold: 4,357 (winter)

### Issue 1: Population Collapse (HIGHEST PRIORITY)
The colony starts at 24,000 adults (8k nurse + 10k house + 6k forager) but
immediately crashes instead of growing toward 40-65k. Queen lays only 6 eggs/day
in month 1 and 64/day in month 2 (should be hundreds). By the time laying ramps
up (224/day in High-Sun), the colony is too small to recover.

The root cause is likely in Phase 2/4 interaction: the queen laying rate depends
on season_factor, available cells, congestion, varroa, and forage. In month 1,
season_factor is only 0.55 and forage is 0.025 -- these multiply together to
nearly zero the laying rate.

**Fix strategy (Phase 2 + Phase 4):**
- The queen needs to lay significantly more in early months
- Check if forage_laying_mult is too aggressive at low forage levels
- SEASON_FACTORS[0] = 0.55 might be too low for Quickening (spring buildup)
- The queen's base_rate * grade_mult * season * forage may be over-dampened
- Consider: the forage_ratio input to queen laying should not suppress laying
  this heavily -- queens lay based on stored pollen, not current forage

### Issue 2: Honey Production Near Zero
Annual production is 19.8 lbs vs 150-450 target. With only 3,200 foragers at
peak (vs 20,000+ expected), nectar collection is proportionally tiny:
  3200 foragers * 0.000882 lbs/day * 0.3 forage * 0.2 conversion = 0.17 lbs/day
  vs target of ~1.0-2.0 lbs/day

**Fix strategy:** This is downstream of Issue 1. Fix population first. With
proper 40-65k population and 15-20k foragers, honey math should work.

### Issue 3: Forage Timing
Peak forage (0.314) occurs in High-Sun (month 3) but the colony has already
crashed by then. Forage in Quickening is only 0.025 -- essentially zero.

**Fix strategy (Phase 6):**
- Iowa spring starts with dandelion and fruit tree bloom in April
- Quickening forage should be 0.15-0.30, not 0.025
- Check if the Iowa flower bloom windows are too late in the season
- Early spring pollen is critical for colony buildup

## How To Run A Tuning Iteration

1. Pick the earliest-phase constant to adjust
2. Edit that phase's .py file
3. Run that phase's tests: `cd ..\phaseN_xxx && python phase_sim.py`
4. Confirm all tests still pass
5. Come back: `cd ..\phase8_full_integration && python full_sim.py`
6. Check which tests improved
7. Repeat

## File Locations (relative to this directory)

```
../phase1_brood_biology/brood_sim.py
../phase2_population/population_sim.py
../phase3_foraging_honey/foraging_sim.py
../phase4_queen_comb/queen_comb_sim.py
../phase5_disease_pests/disease_sim.py
../phase6_environment/environment_sim.py
../phase7_colony_behavior/colony_behavior_sim.py
./full_sim.py
```

## Real-World Science Anchors (do not violate)

- Brood development: 21 days total (3 egg + 6 larva + 12 capped) -- Winston 1987
- Nectar to honey ratio: 5:1 (NECTAR_TO_HONEY = 0.20) -- science-locked
- Summer colony peak: 40,000-65,000 adults -- standard beekeeping reference
- Winter cluster minimum: 8,000-28,000 adults -- varies by region/breed
- Varroa doubling time: 40-70 days untreated -- varies by season/brood availability
- Annual honey surplus: 40-120 lbs harvestable in Iowa -- USDA/extension data
- Winter consumption: 60-90 lbs total (20-45 lbs in our compressed calendar)
