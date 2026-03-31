[< Forage Pool & Nectar Mechanic](14-Forage-Pool-and-Nectar-Mechanic) | [Home](Home) | [Save / Load System >](16-Save-Load-System)

---

# Core Simulation Scripts


This section defines every script responsible for the day-to-day simulation of a live honeybee colony. The goal is biological fidelity at game scale: a player who opens a frame on Day 5 sees different cells than on Day 3, every larva ages visibly, the queen's path is traceable through the brood arc, and colony decline or growth is the natural consequence of real biological processes — not an abstraction behind a health number.

The simulation runs on a daily tick. Each tick is one in-game day. No real-time interpolation is required between ticks; the visual state is a snapshot of the colony after each tick completes.

### 15.1 Script Map & Dependency Order

Scripts execute in this order each tick. Each script reads from the shared HiveFrame data and writes its results back before the next script runs. No script may read results from a later script in the same tick.


| Order | Script | Responsibility |
| --- | --- | --- |
| 1 | CellStateTransition | Age every cell by 1 day. Apply state transitions at biological thresholds. Apply brood mortality. Write final cell states for the tick. |
| 2 | PopulationCohortManager | Age every adult bee cohort by 1 day. Apply mortality to each cohort. Promote hatched bees to nurse role. Promote nurses to house bees. Promote house bees to foragers. |
| 3 | NurseSystem | Check nurse-to-larva ratio. Apply starvation mortality to larvae if nurses are insufficient. Cap larvae that have completed 6 days of open feeding. |
| 4 | ForagerSystem | Calculate foragers available today (weather gate). Simulate forager field trips. Apply field mortality. Return surviving foragers with nectar and pollen loads. Deposit loads into frames. |
| 5 | NectarProcessor | Advance nectar curing on all uncapped honey cells. Cap honey cells that have reached target moisture. Update moisture tracking per cell. |
| 6 | QueenBehavior | Calculate today's egg budget (base rate × colony_stress_modifier). Lay eggs into eligible cells following the frame-sequence/ellipse algorithm. Write egg cells. |
| 7 | CongestionsDetector | Count available empty cells vs. eggs_today. Count brood vs. honey fill in top third. Update congestion state flags. Trigger congestion events if thresholds crossed. |
| 8 | HiveHealthCalculator | Recompute the hidden health score from 8 weighted components. Update colony_stress_modifier for next tick's queen calculation. |
| 9 | SnapshotWriter | Walk all frames. Derive all summary statistics from raw cell data. Write read-only snapshot dict for the render layer and UI. |
| 10 | FrameRenderer | (Render layer — only active during player inspection.) Translate cell states to pixel colors. Place bee sprites. Apply LOD. Mark dirty cells for incremental redraw. |


*Design Note: Scripts 1–9 run headlessly every tick regardless of whether the player has any hive open. Script 10 is lazy — it only runs when the player enters inspection mode, and only redraws cells flagged dirty since the last render. This keeps simulation cost constant and render cost proportional to the player's attention.*

### 15.2 HiveFrame — Cell Grid Data Structure

The fundamental data unit. Every hive contains one or more HiveBox objects, each holding 10 HiveFrame objects. A HiveFrame represents one physical frame of comb — both faces included. Each side is stored as a separate PackedByteArray pair (cells + cell\_age), mirroring how a real Langstroth frame has two independently drawn comb faces.


```gdscript
## HiveFrame constants
FRAME_WIDTH  = 70      # cells across
FRAME_HEIGHT = 50      # cells tall
FACE_SIZE    = 3500    # FRAME_WIDTH × FRAME_HEIGHT (per side)
SIDE_A       = 0       # front face
SIDE_B       = 1       # back face

## Cell state byte values (CellStateTransition canonical definitions)
S_EMPTY_FOUNDATION =  0   # No wax drawn — queen won't lay; bees must draw
S_DRAWN_EMPTY      =  1   # Empty drawn comb — ready for queen or storage
S_EGG              =  2   # Worker/queen egg, days 1–3; tiny white
S_OPEN_LARVA       =  3   # Uncapped larva, days 4–9; nurse-fed
S_CAPPED_BROOD     =  4   # Worker pupa, days 10–21; emerges as adult
S_CAPPED_DRONE     =  5   # Drone pupa, days 10–24; longer development
S_NECTAR           =  6   # Fresh nectar; high moisture; uncapped; glistening
S_CURING_HONEY     =  7   # Being dehydrated by fanning bees; ~3 days
S_CAPPED_HONEY     =  8   # Fully cured; moisture ≤18%; wax capped; harvestable
S_PREMIUM_HONEY    =  9   # Aged 7+ days capped; higher varietal value
S_VARROA           = 10   # Mite-infested capped brood; bee may emerge deformed
S_AFB              = 11   # American Foulbrood infection; stays until treated/burned
S_QUEEN_CELL       = 12   # Peanut-shaped queen rearing cell
S_VACATED          = 13   # Dead brood remnant; bees clean over time

## Per-side data arrays (PackedByteArray, 3500 bytes each)
# Side A (front)
var cells:      PackedByteArray   # cell state values
var cell_age:   PackedByteArray   # cumulative days from egg-lay (0–255)
# Side B (back)
var cells_b:    PackedByteArray   # cell state values
var cell_age_b: PackedByteArray   # cumulative days from egg-lay (0–255)

## Side-aware accessors
func get_cell(x: int, y: int, side: int = SIDE_A) -> int
func set_cell(x: int, y: int, state: int, age: int = 0, side: int = SIDE_A)

## Ellipse mask — used by QueenBehavior for laying pattern
## Ratio 0.52 gives ~29,732 laying cells per side, allowing 1,416 eggs/day
## max across both sides and ~55,000 equilibrium adults in summer.
func in_laying_ellipse(x: int, y: int) -> bool:
    var cx = FRAME_WIDTH  / 2.0    # 35.0
    var cy = FRAME_HEIGHT / 2.0    # 25.0
    var rx = FRAME_WIDTH  * 0.52   # ~36.4
    var ry = FRAME_HEIGHT * 0.52   # ~26.0
    var dx = (x - cx) / rx
    var dy = (y - cy) / ry
    return (dx*dx + dy*dy) <= 1.0

## Memory: 3,500 cells × 2 sides × 2 arrays × 1 byte = 14,000 bytes per frame.
## 10 frames per box = 140 KB. Trivial even with 25 hives.

```


### 15.3 CellStateTransition — Daily Aging Engine

Runs first each tick. Advances every living cell's age counter and applies state transitions when biological thresholds are reached. Also applies mortality at the cell level (varroa, disease, chilling, starvation of larvae).


```gdscript
## Biological timing constants (days in each state)
EGG_DURATION          = 3    # egg → open larva on day 4
OPEN_LARVA_DURATION   = 6    # larva → capped on day 10 (after 6 days feeding)
CAPPED_LARVA_DURATION = 2    # capped larva still feeding; spins cocoon
PUPA_DURATION         = 10   # metamorphosis; total capped = 12 days
HATCHED_DURATION      = 2    # soft bee; being fed; cleaning up after herself
DRONE_CAPPED_DURATION = 14   # drones take longer (total 24 days egg-to-adult)

func tick_all_cells(frame: HiveFrame, hive_state: HiveState):
    for i in range(HiveFrame.TOTAL_CELLS):
        var state = frame.cell_state[i]
        if state == CELL_EMPTY:
            continue   # nothing to do

        frame.cell_age[i] += 1
        var age = frame.cell_age[i]

        match state:

            ## ── Egg ──────────────────────────────────────────────────
            CELL_EGG:
                if age >= EGG_DURATION:
                    _transition(frame, i, CELL_OPEN_LARVA)

            ## ── Open Larva ───────────────────────────────────────────
            CELL_OPEN_LARVA:
                ## Starvation check: nurse system will have set a flag if
                ## nurse population is insufficient. Unfed larvae die.
                if frame.cell_flags[i] & FLAG_UNFED:
                    _kill_cell(frame, i, "starvation")
                    continue

                ## Disease check (EFB most lethal at open larva stage)
                if hive_state.disease_flags.has("EFB"):
                    if randf() < 0.04 * hive_state.disease_severity:
                        _kill_cell(frame, i, "EFB")
                        continue

                ## Chilling check (insufficient nurse coverage of brood nest)
                if hive_state.brood_chilling_risk > 0.0:
                    if randf() < hive_state.brood_chilling_risk:
                        _kill_cell(frame, i, "chilling")
                        continue

                if age >= EGG_DURATION + OPEN_LARVA_DURATION:
                    _transition(frame, i, CELL_CAPPED_LARVA)

            ## ── Capped Larva ─────────────────────────────────────────
            CELL_CAPPED_LARVA:
                ## AFB most lethal at capping stage (spores in royal jelly)
                if hive_state.disease_flags.has("AFB"):
                    var afb_cell_roll = randf()
                    if afb_cell_roll < 0.08 * hive_state.afb_severity:
                        _kill_cell(frame, i, "AFB")
                        _spread_afb(frame, i, hive_state)   # try infecting neighbors
                        continue

                ## Varroa: foundress mite entered just before capping
                if frame.cell_flags[i] & FLAG_VARROA_PRESENT:
                    ## Mite reproduces; damages developing pupa
                    ## 15-25% chance of lethal damage; rest hatch with defects
                    if randf() < 0.20:
                        _kill_cell(frame, i, "varroa_lethal")
                        continue
                    ## Survivor: will hatch with wing/leg defects (DWV)
                    ## tracked via a CELL_flag for the SnapshotWriter

                if age >= EGG_DURATION + OPEN_LARVA_DURATION + CAPPED_LARVA_DURATION:
                    _transition(frame, i, CELL_PUPA)

            ## ── Pupa ─────────────────────────────────────────────────
            CELL_PUPA:
                var total_capped = CAPPED_LARVA_DURATION + PUPA_DURATION
                if age >= EGG_DURATION + OPEN_LARVA_DURATION + total_capped:
                    _transition(frame, i, CELL_HATCHED)
                    ## Notify PopulationCohortManager: a new bee has emerged
                    hive_state.pending_hatch_count += 1
                    if frame.cell_flags[i] & FLAG_VARROA_PRESENT:
                        hive_state.pending_hatch_defective += 1

            ## ── Hatched ──────────────────────────────────────────────
            CELL_HATCHED:
                ## Cell is briefly marked; cleared by house bees (polishing)
                if age >= EGG_DURATION + OPEN_LARVA_DURATION + CAPPED_LARVA_DURATION \
                        + PUPA_DURATION + HATCHED_DURATION:
                    _transition(frame, i, CELL_EMPTY)

            ## ── Nectar (curing) ──────────────────────────────────────
            ## NectarProcessor handles this; skip here
            CELL_NECTAR, CELL_CAPPED_HONEY, CELL_POLLEN:
                pass   # handled by NectarProcessor

func _transition(frame, i, new_state):
    frame.cell_state[i] = new_state
    frame.cell_age[i]   = 0
    frame.cell_flags[i] |= FLAG_DIRTY   # mark for visual redraw

func _kill_cell(frame, i, cause):
    frame.cell_state[i] = CELL_DAMAGED
    frame.cell_age[i]   = 0
    frame.cell_flags[i] |= FLAG_DIRTY
    ## Cause logged for inspection diagnostics (player can read cause on hover)

func _spread_afb(frame, i, hive_state):
    ## Try infecting the 6 adjacent cells (honeycomb hex-grid neighbors)
    for neighbor_idx in _get_neighbors(frame, i):
        if frame.cell_state[neighbor_idx] == CELL_CAPPED_LARVA:
            if randf() < 0.08:
                frame.cell_flags[neighbor_idx] |= FLAG_AFB_INFECTED
    hive_state.afb_cell_count += 1

```


### 15.4 QueenBehavior — Laying Algorithm

The queen moves through the brood nest in a biologically realistic pattern: always working from the warmest, most-tended area outward. She does not teleport — her position carries over between ticks, and she works the adjacent cells before moving to a new frame.


```gdscript
## Frame visit sequence — queen starts at center frames, works outward
## In a 10-frame box, frames are numbered 0-9 left to right
QUEEN_FRAME_ORDER = [4, 5, 3, 6, 2, 7, 1, 8, 0, 9]

## Species base laying rates (eggs per day, peak season)
BASE_LAYING_RATES = {
    "Italian":   1800,   # prolific; needs space management
    "Carniolan": 1600,   # explosive spring buildup
    "Buckfast":  1700,   # consistent; disease-resistant
    "Russian":   1200,   # conservative; varroa-resistant behavior
    "Caucasian": 1300,   # slow buildup; excellent foragers
}

## Grade modifier (applied to base rate)
GRADE_MULTIPLIERS = { "S": 1.25, "A": 1.10, "B": 1.00, "C": 0.85, "D": 0.65, "F": 0.0 }

## Skip probability per grade (chance queen passes over an eligible cell)
## Higher skip = less solid brood pattern
SKIP_PROBABILITY = { "S": 0.02, "A": 0.06, "B": 0.12, "C": 0.22, "D": 0.38, "F": 1.0 }

func queen_lay_tick(hive: HiveSimulation):
    var queen = hive.queen

    ## Step 1: Calculate today's egg budget
    var base_rate   = BASE_LAYING_RATES[queen.species]
    var grade_mod   = GRADE_MULTIPLIERS[queen.grade]
    var age_mod     = _get_age_multiplier(queen.age_years)
    var season_mod  = hive.time_manager.season_factor()   ## 0.0 (winter) – 1.0 (summer peak)
    var stress_mod  = hive.colony_stress_modifier          ## 0.0 – 1.0 from HiveHealthCalculator

    var eggs_today  = int(base_rate * grade_mod * age_mod * season_mod * stress_mod)
    eggs_today = max(0, eggs_today)

    if eggs_today == 0:
        return   ## Queen not laying today (winter, failing queen, or max stress)

    ## Step 2: Walk the frame sequence, laying into eligible cells
    var eggs_laid = 0
    var skip_prob = SKIP_PROBABILITY[queen.grade]

    for frame_idx in QUEEN_FRAME_ORDER:
        if eggs_laid >= eggs_today:
            break
        var frame = hive.get_brood_box().frames[frame_idx]

        ## Build sorted list of eligible empty cells for this frame
        ## Sorted by: (a) inside laying ellipse, (b) adjacent to existing brood
        var candidates = _get_eligible_cells(frame, queen)

        for cell_idx in candidates:
            if eggs_laid >= eggs_today:
                break

            ## Grade-based skip: imperfect queens miss eligible cells
            if randf() < skip_prob:
                continue

            ## Lay the egg
            frame.cell_state[cell_idx] = CELL_EGG
            frame.cell_age[cell_idx]   = 0
            frame.cell_flags[cell_idx] = FLAG_DIRTY

            ## Move queen sprite to this cell for visual tracking
            queen.current_frame = frame_idx
            queen.current_cell  = cell_idx

            eggs_laid += 1

    hive.last_snapshot["eggs_laid_today"] = eggs_laid

func _get_eligible_cells(frame: HiveFrame, queen) -> Array:
    ## Eligible: CELL_EMPTY, inside laying ellipse, not in top 10% of frame (honey arc)
    ## Sorted by adjacency to existing brood (eggs or larvae nearby = preferred)
    var candidates = []
    for i in range(HiveFrame.FACE_SIZE):   ## front face only for primary laying
        if frame.cell_state[i] != CELL_EMPTY:
            continue
        var pos = frame.index_to_xy(i)
        if not frame.in_laying_ellipse(pos.x, pos.y):
            continue
        if pos.y < 4:   ## top rows reserved for honey arc
            continue
        var adjacency_score = _count_adjacent_brood(frame, i)
        candidates.append({ "idx": i, "score": adjacency_score })

    ## Sort: highest adjacency score first (queen fills gaps in existing brood)
    candidates.sort_custom(func(a, b): return a.score > b.score)
    return candidates.map(func(c): return c.idx)

func _count_adjacent_brood(frame: HiveFrame, idx: int) -> int:
    ## Counts adjacent cells that are in egg/larva/capped state
    ## Used to bias the queen toward filling gaps within the brood nest
    var count = 0
    for neighbor in _get_neighbors(frame, idx):
        var s = frame.cell_state[neighbor]
        if s in [CELL_EGG, CELL_OPEN_LARVA, CELL_CAPPED_LARVA, CELL_PUPA]:
            count += 1
    return count

func _get_age_multiplier(age_years: float) -> float:
    ## Piecewise linear interpolation of the queen age curve
    if age_years <= 1.0:  return 1.00
    if age_years <= 2.0:  return lerp(1.00, 1.05, age_years - 1.0)   ## peak at year 2
    if age_years <= 3.0:  return lerp(1.05, 0.85, age_years - 2.0)
    if age_years <= 4.0:  return lerp(0.85, 0.65, age_years - 3.0)
    if age_years <= 5.0:  return lerp(0.65, 0.40, age_years - 4.0)
    return lerp(0.40, 0.20, min(age_years - 5.0, 1.0))

```


### 15.5 PopulationCohortManager — Adult Bee Tracking

Tracking 50,000 individual bees as objects is not feasible. Instead, bees are tracked as daily cohorts — all bees that hatched on the same day share a cohort object. A cohort stores a count and an age; mortality is applied to the count each day. Role transitions happen at fixed age thresholds.


```gdscript
## A single cohort: all bees that hatched on the same in-game day
class BeeCohort:
    var count:       int      ## living bees remaining in this cohort
    var age_days:    int      ## total days since hatch
    var is_winter:   bool     ## winter bees live much longer; different mortality
    var defective:   int      ## bees with DWV or other varroa-caused wing defects

## Role thresholds (days since hatch)
NURSE_START     = 2    ## after 2 days of being fed, joins nursing
NURSE_END       = 14   ## transitions to house bee roles
HOUSE_BEE_END   = 23   ## transitions to forager
FORAGER_START   = 23

func tick_all_cohorts(hive: HiveSimulation):
    var new_cohorts = []

    ## Add newly hatched bees from today's CellStateTransition
    if hive.pending_hatch_count > 0:
        var cohort       = BeeCohort.new()
        cohort.count     = hive.pending_hatch_count
        cohort.age_days  = 0
        cohort.is_winter = hive.time_manager.is_winter_bee_season()
        cohort.defective = hive.pending_hatch_defective
        new_cohorts.append(cohort)
        hive.pending_hatch_count = 0

    ## Age existing cohorts and apply mortality
    var surviving = []
    for cohort in hive.adult_cohorts:
        cohort.age_days += 1

        ## Apply daily mortality
        var deaths = _calculate_cohort_deaths(cohort, hive)
        cohort.count = max(0, cohort.count - deaths)

        if cohort.count > 0:
            surviving.append(cohort)

    hive.adult_cohorts = surviving + new_cohorts

    ## Recalculate role totals from cohort ages
    _update_role_counts(hive)

func _calculate_cohort_deaths(cohort: BeeCohort, hive: HiveSimulation) -> int:
    var p_death = 0.0   ## daily probability of death per bee

    if cohort.is_winter:
        ## Winter bees: very low base mortality (they are built to last)
        p_death = 0.003
        ## But: if cluster is cold or stores are low, mortality rises sharply
        if hive.winter_cluster_stress > 0.5:
            p_death += hive.winter_cluster_stress * 0.04
    else:
        var age = cohort.age_days
        if age < FORAGER_START:
            ## Pre-forager bees: low mortality from in-hive causes
            p_death = 0.004
        else:
            ## Forager phase: age-based accelerating mortality
            var forager_age = age - FORAGER_START
            p_death = 0.010 + pow(0.0025 * max(0, forager_age - 8), 2)
            ## Apply season multiplier
            p_death *= hive.time_manager.forager_mortality_season_multiplier()
            ## Apply environmental multiplier
            p_death *= hive.current_environmental_mortality_multiplier
            ## Defective bees die sooner (DWV shortens forager life ~40%)
            if cohort.defective > 0:
                var defect_ratio = float(cohort.defective) / float(cohort.count)
                p_death += defect_ratio * 0.03

    p_death = clamp(p_death, 0.001, 0.95)

    ## Binomial approximation: expected deaths with some variance
    var expected = cohort.count * p_death
    var variance = cohort.count * p_death * (1.0 - p_death)
    var stddev   = sqrt(variance)
    return int(clamp(expected + randfn(0, stddev), 0, cohort.count))

func _update_role_counts(hive: HiveSimulation):
    var nurses = 0; var house_bees = 0; var foragers = 0; var newly_hatched = 0

    for cohort in hive.adult_cohorts:
        var age = cohort.age_days
        if   age < NURSE_START:     newly_hatched += cohort.count
        elif age < NURSE_END:       nurses        += cohort.count
        elif age < HOUSE_BEE_END:   house_bees    += cohort.count
        else:                        foragers      += cohort.count

    hive.pop_newly_hatched = newly_hatched
    hive.pop_nurses        = nurses
    hive.pop_house_bees    = house_bees
    hive.pop_foragers      = foragers
    hive.pop_total_adults  = newly_hatched + nurses + house_bees + foragers

```


### 15.6 NurseSystem — Brood Care & Feeding

Nurse bees are the colony's bottleneck resource. Each nurse can tend approximately 3–4 open larvae per day (real-world ratio from bee physiology research). When the ratio falls below this threshold, larvae are abandoned in reverse order of their development — the youngest larvae are left to die first.


```gdscript
## Nurse capacity constants (based on bee biology research)
LARVAE_PER_NURSE      = 3.5   ## average larvae one nurse can feed per day
CRITICAL_RATIO        = 0.5   ## below 50% coverage: chilling and starvation risk begins
CATASTROPHIC_RATIO    = 0.25  ## below 25%: rapid brood die-off

func nurse_system_tick(hive: HiveSimulation):
    ## Count open larvae across all frames
    var total_open_larvae = 0
    for box in hive.boxes:
        for frame in box.frames:
            total_open_larvae += frame.count_state(CELL_OPEN_LARVA)

    var nursing_capacity  = hive.pop_nurses * LARVAE_PER_NURSE
    var coverage_ratio    = nursing_capacity / max(1, total_open_larvae)

    ## Update chilling/starvation risk for CellStateTransition
    if coverage_ratio >= 1.0:
        hive.brood_chilling_risk = 0.0
    elif coverage_ratio >= CRITICAL_RATIO:
        ## Partial coverage: slight mortality risk proportional to deficit
        hive.brood_chilling_risk = (1.0 - coverage_ratio) * 0.08
    elif coverage_ratio >= CATASTROPHIC_RATIO:
        hive.brood_chilling_risk = 0.15 + (CRITICAL_RATIO - coverage_ratio) * 0.30
    else:
        hive.brood_chilling_risk = 0.45   ## rapid brood die-off

    ## Mark youngest larvae as UNFED if capacity is insufficient
    ## (CellStateTransition kills unfed larvae at EGG_DURATION + 1)
    if coverage_ratio < 1.0:
        _mark_unfed_larvae(hive, coverage_ratio)

    ## Capping decision: larvae that have completed full 6-day feeding period
    ## are capped by house bees. This happens automatically in CellStateTransition,
    ## but the nurse system confirms the larva was adequately fed first.
    ## (Larvae that received less than 60% of required feeding are capped early
    ## and will produce undersized or non-viable adults.)

func _mark_unfed_larvae(hive: HiveSimulation, coverage: float):
    ## When under capacity, abandon youngest larvae first
    ## (biologically: nurses instinctively protect older, more-invested brood)
    var unfed_quota = int(hive.pop_nurses * LARVAE_PER_NURSE * (1.0 - coverage))

    for box in hive.boxes:
        for frame in box.frames:
            for i in range(HiveFrame.TOTAL_CELLS):
                if unfed_quota <= 0:
                    return
                if frame.cell_state[i] == CELL_OPEN_LARVA and frame.cell_age[i] == 0:
                    ## Day-0 larvae (just hatched from egg) are abandoned first
                    frame.cell_flags[i] |= FLAG_UNFED
                    unfed_quota -= 1

```


### 15.7 ForagerSystem — Field Activity, Mortality & Return

Foragers are the colony's resource engine. Every day a proportion of foragers leaves; some die; survivors return with nectar and pollen. The simulation does not track individual forager flights — it treats the forager population as a daily batch with probabilistic outcomes.


```gdscript
## Forager trip constants (real-world biology)
NECTAR_LOAD_PER_FORAGER   = 0.040  ## kg nectar per round trip (40mg; real bee data)
POLLEN_LOAD_PER_FORAGER   = 0.015  ## kg pollen per round trip (15mg)
POLLEN_FORAGER_RATIO      = 0.20   ## ~20% of foragers collect pollen on any given trip
FORAGER_DAILY_TRIPS       = 10     ## trips per day per forager under good conditions
FORAGE_RADIUS_MILES       = 2.0    ## max effective forage radius (bees fly up to 5 mi but efficiency drops)

func forager_system_tick(hive: HiveSimulation):
    ## Weather gate: no foraging in rain, below 50°F, or above 95°F
    if not _weather_allows_foraging(hive):
        ## No field mortality on non-flying days
        return

    var foragers = hive.pop_foragers
    if foragers == 0:
        return

    ## Scale active foragers by time of day (not modeled intra-day;
    ## simplified to a daily batch of "trips equivalent")
    var trips_today = foragers * FORAGER_DAILY_TRIPS

    ## Apply field loss mortality to the forager cohorts
    ## (mortality is handled in PopulationCohortManager, but we need
    ## the environmental multiplier set before it runs)
    hive.current_environmental_mortality_multiplier = _get_env_multiplier(hive)

    ## Calculate forage availability at this location
    var forage_pool = hive.forage_manager.get_forage_pool(hive.location)
    var hive_demand = foragers * NECTAR_LOAD_PER_FORAGER * FORAGER_DAILY_TRIPS
    var actual_draw = min(hive_demand, forage_pool.available_nectar_kg)

    ## Update forage pool (shared with other hives at this location)
    forage_pool.deplete(actual_draw)

    ## Calculate returns (foragers that survived × their load)
    var survival_rate   = 1.0 - hive.current_environmental_mortality_multiplier \
                          * 0.01   ## baseline field loss ~1%; multiplier scales it
    survival_rate = clamp(survival_rate, 0.85, 0.999)

    var surviving_foragers = int(foragers * survival_rate)
    var nectar_returned_kg = (actual_draw / max(1, foragers)) * surviving_foragers
    var pollen_returned_kg = surviving_foragers * POLLEN_LOAD_PER_FORAGER \
                             * POLLEN_FORAGER_RATIO * forage_pool.pollen_multiplier

    ## Deposit nectar and pollen into frames
    _deposit_nectar(hive, nectar_returned_kg)
    _deposit_pollen(hive, pollen_returned_kg)

func _deposit_nectar(hive: HiveSimulation, kg: float):
    ## Nectar goes into CELL_EMPTY cells in the upper/outer arc of the brood nest
    ## House bees receive it from foragers and store it
    var cells_needed = int(kg / 0.000030)   ## ~30mg per cell for fresh nectar
    var deposited    = 0

    for box in hive.boxes:
        for frame_idx in range(box.frames.size() - 1, -1, -1):   ## fill from outer frames inward
            var frame = box.frames[frame_idx]
            if deposited >= cells_needed:
                break
            for i in range(HiveFrame.TOTAL_CELLS):
                if deposited >= cells_needed:
                    break
                var pos = frame.index_to_xy(i)
                ## Nectar stored in top portion of frame and outer edges (above brood arc)
                if frame.cell_state[i] == CELL_EMPTY and pos.y <= 15:
                    frame.cell_state[i]    = CELL_NECTAR
                    frame.cell_age[i]      = 0
                    ## Initial moisture set by season baseline + high (just arrived, ~80% water)
                    ## NectarProcessor will cure this down over days
                    frame.cell_moisture[i] = 250   ## 25.0% — raw nectar; cures over ~3-7 days
                    frame.cell_flags[i]    |= FLAG_DIRTY
                    deposited += 1

    hive.stores_nectar_kg += kg

func _get_env_multiplier(hive: HiveSimulation) -> float:
    var m = hive.time_manager.forager_mortality_season_multiplier()
    if hive.forage_manager.is_dearth_period(hive.location):
        m *= 1.5
    if hive.active_events.has("pesticide_event"):
        m *= 8.0
    if hive.location == "river_bottom":
        m *= 1.1
    return clamp(m, 0.7, 8.0)

func _weather_allows_foraging(hive) -> bool:
    var wx = hive.weather_system.today
    return wx.rain == false and wx.temp_f >= 50.0 and wx.temp_f <= 95.0 \
           and wx.wind_mph < 20.0

```


### 15.8 NectarProcessor — Honey Curing Pipeline

Raw nectar arriving in the hive is approximately 80% water. Bees cure it by fanning and enzymatic conversion over 3–7 days, depending on temperature and hive ventilation. The game models this per-cell, so the player can actually see uncapped nectar cells transition to capped honey across multiple inspection days.


```gdscript
## Curing constants (based on real bee physiology)
TARGET_MOISTURE_PREMIUM  = 170   ## 17.0% × 10 — stored as byte
TARGET_MOISTURE_STANDARD = 186   ## 18.6% × 10
INITIAL_NECTAR_MOISTURE  = 250   ## ~25% — just arrived; still very watery
DAILY_MOISTURE_REDUCTION = 13    ## points per day under normal summer conditions
                                  ## (1.3% per day; real bees reduce ~3-5% per day
                                  ##  but game time is compressed)

func nectar_processor_tick(hive: HiveSimulation):
    var honey_house_bonus = 8 if hive.has_structure("honey_house") else 0
    var season_mod = _get_season_curing_rate(hive)

    for box in hive.boxes:
        for frame in box.frames:
            for i in range(HiveFrame.TOTAL_CELLS):
                var state = frame.cell_state[i]

                if state == CELL_NECTAR:
                    ## Cure: reduce moisture each day
                    var reduction = int(DAILY_MOISTURE_REDUCTION * season_mod)
                    frame.cell_moisture[i] = max(
                        TARGET_MOISTURE_PREMIUM,
                        frame.cell_moisture[i] - reduction - honey_house_bonus
                    )
                    frame.cell_age[i] += 1
                    frame.cell_flags[i] |= FLAG_DIRTY

                    ## Check if cured enough to cap
                    if frame.cell_moisture[i] <= TARGET_MOISTURE_STANDARD:
                        _cap_honey_cell(frame, i)

                    ## If not capped after 14 days: fermentation risk begins
                    if frame.cell_age[i] >= 14 and frame.cell_moisture[i] > TARGET_MOISTURE_STANDARD:
                        frame.cell_flags[i] |= FLAG_FERMENTATION_RISK

                elif state == CELL_CAPPED_HONEY:
                    ## Capped honey is stable. Continue minor curing.
                    ## Once capped: moisture is locked in from that moment.
                    ## The moisture value at capping time = the harvest quality grade.
                    pass

func _cap_honey_cell(frame, i):
    ## Record the moisture at capping time — this becomes the harvest quality
    frame.cell_state[i]  = CELL_CAPPED_HONEY
    ## Moisture byte retained — SnapshotWriter reads it at harvest
    frame.cell_flags[i] |= FLAG_DIRTY

func _get_season_curing_rate(hive) -> float:
    ## Summer heat speeds curing; fall slows it
    match hive.time_manager.current_month_name():
        "Wide-Clover", "High-Sun":  return 1.0    ## baseline
        "Greening", "Full-Earth":   return 0.85
        "Quickening", "Reaping":    return 0.70
        _:                          return 0.50   ## Deepcold / Kindlemonth

```


### 15.9 HiveSimulation — Master Tick Orchestrator

The top-level node that owns all simulation state and calls each subsystem in the correct order. This is what HiveManager calls once per day for every registered hive.


```gdscript
## HiveSimulation.gd — top-level colony simulation node
## Attached to scene: scenes/hives/HiveSimulation.tscn
## Children: one HiveBox node per physical box (brood + supers)

class_name HiveSimulation extends Node

## ── Identity ─────────────────────────────────────────────────────────
var hive_id:    String
var hive_name:  String   ## player-assigned label
var location:   String   ## apiary location key

## ── Queen state ───────────────────────────────────────────────────────
var queen: QueenData      ## species, grade, age, status, position

## ── Adult population (cohort list) ───────────────────────────────────
var adult_cohorts:  Array[BeeCohort] = []
var pop_nurses:     int = 0
var pop_house_bees: int = 0
var pop_foragers:   int = 0
var pop_total_adults: int = 0

## ── Composite state ───────────────────────────────────────────────────
var colony_stress_modifier:   float = 1.0
var brood_chilling_risk:      float = 0.0
var winter_cluster_stress:    float = 0.0
var current_environmental_mortality_multiplier: float = 1.0

## ── Event flags ───────────────────────────────────────────────────────
var disease_flags:   Dictionary = {}   ## { "AFB": severity, "EFB": severity, ... }
var active_events:   Array      = []   ## ["pesticide_event", ...]

## ── Congestion state ──────────────────────────────────────────────────
var congestion_state: int = CONGESTION_NORMAL
var brood_bound_days: int = 0
var honey_bound_days: int = 0

## ── Stores tracking ───────────────────────────────────────────────────
var stores_nectar_kg: float = 0.0
var stores_honey_kg:  float = 0.0

## ── Snapshot (read-only; written last each tick) ──────────────────────
var last_snapshot: Dictionary = {}

## ── Physical structure ───────────────────────────────────────────────
var boxes: Array[HiveBox] = []   ## index 0 = bottom brood box

## ─────────────────────────────────────────────────────────────────────
## MASTER TICK — called by HiveManager once per in-game day
## ─────────────────────────────────────────────────────────────────────
func tick():
    ## 1. Age cells; apply brood mortality
    CellStateTransition.tick_all_cells_in_hive(self)

    ## 2. Age cohorts; apply adult mortality; promote roles
    PopulationCohortManager.tick_all_cohorts(self)

    ## 3. Nurse ratio check; mark unfed larvae; starvation risk
    NurseSystem.nurse_system_tick(self)

    ## 4. Forager field trips; deposit nectar and pollen
    ForagerSystem.forager_system_tick(self)

    ## 5. Cure nectar toward honey; cap when ready
    NectarProcessor.nectar_processor_tick(self)

    ## 6. Queen lays eggs (using stress modifier from previous tick's HHC)
    QueenBehavior.queen_lay_tick(self)

    ## 7. Detect congestion states
    CongestionsDetector.detect(self)

    ## 8. Recalculate health score and stress modifier for next tick
    HiveHealthCalculator.calculate(self)

    ## 9. Write read-only snapshot for render layer and UI
    SnapshotWriter.write(self)

    ## Emit signal for HiveManager listeners (HUD, quest system, etc.)
    emit_signal("tick_complete", hive_id, last_snapshot)

```


### 15.10 FrameRenderer — Visual Representation

The frame renderer translates the raw byte arrays of a HiveFrame into a visual display the player can inspect. It only runs when the player has a hive open. It uses a hash-based dirty check so unchanged frames return the cached texture instantly.

**Implementation status (current):** FrameRenderer uses a pre-built cell atlas PNG (14 states × 26×20 px hexagonal sprites) and composites them into a honeycomb layout using `Image.blend_rect()`. Alpha-aware blending ensures transparent hex-cell corners don't erase overlapping neighbours in the tight-packed grid. Three render modes are available:


```gdscript
## Cell Atlas: 364×20 px strip at res://assets/sprites/generated/cells/cell_atlas.png
## 14 hexagonal cell sprites, each 26×20 px with transparent corners.
## State N occupies atlas column (N * 26), row 0.

## Render modes:
## 1. render_honeycomb(frame, side) → 1833×755 ImageTexture
##    Realistic hex-offset grid.  Pointy-top layout with 15 px row step
##    (3/4 of cell height) and odd-row right-shift for tight hexagonal packing.
##    Uses blend_rect (not blit_rect) so hex-cell transparency composites correctly.
##    This is the default inspection view.
##
## 2. render_lod(frame, side) → 70×50 ImageTexture
##    One pixel per cell, colour-coded by state. For minimap or zoom < 50%.
##
## 3. render_frame(frame, side) → 1820×1000 ImageTexture
##    Flat grid (26×20 per cell, no hex offset). Debug/alternative view.

## LOD colour palette — one colour per state (indexed 0–13):
LOD_PALETTE = [
    Color(0.18, 0.14, 0.08),   ##  0 S_EMPTY_FOUNDATION  — dark wax / undrawn
    Color(0.82, 0.72, 0.44),   ##  1 S_DRAWN_EMPTY        — pale wax
    Color(0.98, 0.95, 0.78),   ##  2 S_EGG                — near-white
    Color(0.62, 0.88, 0.55),   ##  3 S_OPEN_LARVA         — light green
    Color(0.80, 0.65, 0.30),   ##  4 S_CAPPED_BROOD       — tan cap
    Color(0.60, 0.50, 0.28),   ##  5 S_CAPPED_DRONE       — darker tan
    Color(0.95, 0.85, 0.30),   ##  6 S_NECTAR             — bright yellow
    Color(0.90, 0.72, 0.20),   ##  7 S_CURING_HONEY       — amber-yellow
    Color(0.85, 0.55, 0.08),   ##  8 S_CAPPED_HONEY       — rich amber
    Color(0.72, 0.40, 0.04),   ##  9 S_PREMIUM_HONEY      — deep amber
    Color(0.70, 0.20, 0.20),   ## 10 S_VARROA             — dark red
    Color(0.30, 0.12, 0.08),   ## 11 S_AFB                — very dark brown
    Color(0.90, 0.75, 0.90),   ## 12 S_QUEEN_CELL         — lavender
    Color(0.40, 0.35, 0.30),   ## 13 S_VACATED            — grey-brown
]

## Side parameter: 0 = Side A (front), 1 = Side B (back).
## All three render modes accept a side parameter and read the corresponding
## cells/cells_b array from the HiveFrame.

## InspectionOverlay controls:
##   [A] / [D] — navigate between frames (1–10)
##   [F]       — flip frame to view Side A / Side B
##   [E]       — harvest honey from current frame
##   [ESC]     — close inspection
##
## The header shows: "Frame N / 10  Side A" or "Side B"
## Stats panel shows cell counts for the currently viewed side only.
## Colony-level stats (Adults, Mites, HP) come from the simulation snapshot.

```


The InspectionOverlay renders as a CanvasLayer at 320×180 viewport with a Langstroth frame structure: wooden top bar (with lug tabs), side bars, bottom bar, wax foundation background with support wires, and the honeycomb cell grid composited inside. The frame bars use a warm pine/oak palette with highlight and shadow edges for depth.

### 15.11 SnapshotWriter — Read-Only State Export

The snapshot is a Dictionary computed at the end of each tick from the raw simulation data. It is the *only* data the render layer and UI systems are permitted to read. Nothing outside HiveSimulation ever touches the raw frame arrays. This architectural rule keeps the simulation authoritative and prevents render-layer logic from accidentally modifying colony state.


```gdscript
func write(hive: HiveSimulation):
    var snap = {}

    ## ── Population ─────────────────────────────────────
    snap["pop_total"]       = hive.pop_total_adults
    snap["pop_nurses"]      = hive.pop_nurses
    snap["pop_house_bees"]  = hive.pop_house_bees
    snap["pop_foragers"]    = hive.pop_foragers

    ## ── Brood counts (derived from frame scan) ─────────
    var egg_count   = 0; var larva_count = 0
    var capped      = 0; var damaged     = 0
    var honey_cells = 0; var pollen_cells = 0

    for box in hive.boxes:
        for frame in box.frames:
            egg_count    += frame.count_state(CELL_EGG) + frame.count_state(CELL_DRONE_EGG)
            larva_count  += frame.count_state(CELL_OPEN_LARVA) + frame.count_state(CELL_DRONE_LARVA)
            capped       += frame.count_state(CELL_CAPPED_LARVA) + frame.count_state(CELL_PUPA) \
                          + frame.count_state(CELL_DRONE_CAPPED)
            damaged      += frame.count_state(CELL_DAMAGED)
            honey_cells  += frame.count_state(CELL_CAPPED_HONEY) + frame.count_state(CELL_NECTAR)
            pollen_cells += frame.count_state(CELL_POLLEN)

    snap["brood_eggs"]         = egg_count
    snap["brood_open_larvae"]  = larva_count
    snap["brood_capped"]       = capped
    snap["brood_damaged"]      = damaged
    snap["brood_total"]        = egg_count + larva_count + capped

    ## ── Stores ─────────────────────────────────────────
    snap["honey_cells"]        = honey_cells
    snap["pollen_cells"]       = pollen_cells
    snap["stores_honey_kg"]    = hive.stores_honey_kg
    snap["stores_estimate_lbs"] = hive.stores_honey_kg * 2.205

    ## ── Queen ──────────────────────────────────────────
    snap["queen_status"]       = hive.queen.status    ## Active / Failing / Missing / Virgin
    snap["queen_species"]      = hive.queen.species
    snap["queen_age_years"]    = hive.queen.age_years
    snap["queen_grade"]        = hive.queen.grade     ## NOT shown directly; player infers from brood
    snap["eggs_laid_today"]    = hive.queen.eggs_today

    ## ── Health ─────────────────────────────────────────
    snap["health_score"]       = hive.hidden_health_score   ## hidden from player
    snap["colony_stress"]      = hive.colony_stress_modifier
    snap["congestion_state"]   = hive.congestion_state
    snap["varroa_mites_per_100"] = _estimate_mite_load(hive)
    snap["disease_flags"]      = hive.disease_flags.duplicate()
    snap["brood_pattern_quality"] = _compute_pattern_quality(hive, damaged, capped)

    ## ── Observation clues (what the player sees on inspection) ─────
    ## These are the player-readable signals derived from simulation data
    snap["obs_eggs_visible"]      = egg_count > 0
    snap["obs_queen_seen"]        = _queen_spotted_chance(hive)   ## probabilistic
    snap["obs_laying_pattern"]    = _describe_brood_pattern(snap)
    snap["obs_stores_descriptor"] = _describe_stores(snap)
    snap["obs_pest_signs"]        = _describe_pest_signs(hive)

    hive.last_snapshot = snap

func _describe_brood_pattern(snap) -> String:
    var ratio = float(snap["brood_damaged"]) / max(1, snap["brood_capped"])
    if ratio < 0.02:   return "Solid — very few gaps. Excellent queen."
    if ratio < 0.08:   return "Good — scattered gaps. Acceptable."
    if ratio < 0.18:   return "Spotty — notable gaps. Queen may be struggling."
    if ratio < 0.35:   return "Poor — many empty cells. Requeening may be needed."
    return "Failing — majority of brood abnormal or absent."

func _queen_spotted_chance(hive) -> bool:
    ## Probability of spotting the queen depends on player XP level
    var base_chance = lerp(0.30, 0.85, hive.player_level / 5.0)
    ## Marked queens are always found if player is level 2+
    if hive.queen.is_marked and hive.player_level >= 2:
        base_chance = min(base_chance + 0.30, 0.98)
    return randf() < base_chance

```


### 15.12 What the Player Sees — Visual State Over Time

This section describes the expected visual output of the simulation across a full inspection cycle, grounding the pseudocode in observable game behavior. A developer implementing these scripts can use this as an acceptance test: if the player's inspection view does not match these descriptions, the simulation has a bug.


| Day of Colony | Expected Inspection View |
| --- | --- |
| Day 1 (fresh package installed) | Mostly empty comb. A few honey cells from transport. No eggs yet — queen not released or just released. No brood of any kind. Small bee cluster visible. Forage team not yet operating. |
| Day 4–5 | First eggs visible (small white dots at cell bases; only high-XP players see these clearly). Queen visible moving across frames. No larvae yet. Small nurse cohort forming. |
| Day 7–8 | Eggs from Day 4 have become open larvae — curled pale grubs visible in cells. Still no capping. Nurse bees visibly clustered around larval cells. |
| Day 12–14 | First capped brood appears (tan wax caps over cells that were capped at Day 10). Eggs + open larvae + capped brood now all visible simultaneously. Classic three-stage brood frame. |
| Day 21–22 | First hatched workers emerge (CELL_HATCHED — briefly visible as ragged holes). These first bees join the nurse cohort immediately. Population measurably growing. |
| Day 35+ | Full colony activity visible. Brood arc clearly defined in center frames. Honey arc building in upper corners and outer frames. Nurse bees throughout brood area. Queen visible moving in concentric path. Capped honey spreading outward from brood. |
| Peak summer | Dense brood across 7–8 frames. Solid capped brood with minimal gaps (good queen). Supers filling with capped honey. Entrance crowded with returning foragers. Bee buzz audible and intense. |
| Post-varroa treatment | Visible reduction in capped cells with FLAG_VARROA_PRESENT. Damaged cell count stops rising. Over 2–3 weeks, new healthy brood fills vacated cells. Color of capped cells returns to normal tan (no dark varroa indicators). |
| Queen failure (developing) | Egg count begins dropping. Open larvae diminish. Capped brood remains but nothing behind it. Damaged and empty cells increasing. Honey creep into brood area. Pattern goes from spotty to sparse to absent over 3–4 weeks. Player notices population declining before the reason is obvious. |
| AFB outbreak (early) | A few cells with dark sunken caps (CELL_DAMAGED with FLAG_AFB). Adjacent cells at elevated infection risk. Ropiness observable on hover (diagnostic interaction). Colony otherwise active. Window for intervention is open. |
| AFB outbreak (late) | Large patches of dark cells spreading from original infection point. Sunken and perforated caps. Smell described by NPCs as "rotting fish." Colony visibly weakened. Forager traffic reduced. Brood replacement failing to keep pace with losses. |


*Design Note: The visual state over time is the game's core feedback loop. Players who inspect regularly see the story of their colony — the queen's path visible as a rolling wave of capped brood, the varroa damage appearing as speckling in an otherwise solid field, the honey arc advancing as the nectar flow peaks. None of this is communicated through a UI panel. It is communicated through the frame itself. Every number in these scripts exists to produce that experience.*

**PART VI**

**Engine Systems**

*Save/load persistence, UI autoloads, and supporting infrastructure implemented during Phase 1.*

---

[< Forage Pool & Nectar Mechanic](14-Forage-Pool-and-Nectar-Mechanic) | [Home](Home) | [Save / Load System >](16-Save-Load-System)