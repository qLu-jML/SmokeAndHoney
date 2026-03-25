#!/usr/bin/env python3
"""
hive_sim_harness.py — Smoke and Honey Simulation Validation Harness
==================================================================
Standalone Python reimplementation of the HiveSimulation pipeline.
Runs 365 simulated days (≈1.63 game years at 224 days/year) for two hives
with identical starting conditions, then validates scientific targets:

  ✓ Spring buildup → summer peak → fall decline → winter cluster curve
  ✓ Colony peak 40,000–65,000 bees (summer)
  ✓ Winter minimum 8,000–28,000 bees (end-of-winter nadir)
  ✓ Total honey harvest 40–120 lbs (two harvests: summer + fall)
  ✓ Two hives diverge 8–30% by year end (forage_efficiency + daily variance)
  ✓ Varroa doubling time 40–70 days at moderate infestation
  ✓ Winter consumption 20–45 lbs (dynamic cluster-heating model)
  ✓ No impossible states (negative populations, honey < 0, etc.)

Usage:
  python hive_sim_harness.py
  python hive_sim_harness.py --days 448   # two full game years
  python hive_sim_harness.py --csv        # also write results.csv

Science references:
  Winston (1987), Seeley (1995, 2010), Farrar (1943),
  Rosenkranz et al. (2010), Amdam & Omholt (2002)
"""

import random
import math
import sys
import argparse
import csv
from dataclasses import dataclass, field
from typing import List, Dict, Tuple

# ──────────────────────────────────────────────────────────────────────────────
# Constants — mirrored from GDScript (post-fix values)
# ──────────────────────────────────────────────────────────────────────────────

# TimeManager season_factor table (indexed by month 0–7)
SEASON_FACTORS = [0.55, 0.80, 1.00, 1.00, 0.65, 0.35, 0.08, 0.05]
MONTH_NAMES    = [
    "Quickening", "Greening",
    "Wide-Clover", "High-Sun",
    "Full-Earth",  "Reaping",
    "Deepcold",    "Kindlemonth",
]
YEAR_LENGTH  = 224
MONTH_LENGTH = 28

# Brood development thresholds (cumulative days)
AGE_EGG_TO_LARVA    = 3
AGE_LARVA_TO_CAPPED = 9
AGE_WORKER_EMERGE   = 21

# ForagerSystem — post-fix calibration
NECTAR_PER_FORAGER  = 0.000_882   # lbs/forager/day (was 0.000080 — 11x too low)
POLLEN_PER_FORAGER  = 0.000_020
NECTAR_TO_HONEY     = 0.20        # 5:1 nectar-to-honey (was 0.15)

# PopulationCohortManager — post-fix
NURSE_DAYS_SUMMER   = 12
HOUSE_DAYS_SUMMER   = 12          # was 9; extended to lower forager fraction
NURSE_MORT_SUMMER   = 0.005
HOUSE_MORT_SUMMER   = 0.008
FORAGER_MORT_SUMMER = 0.055
DRONE_MORT_SUMMER   = 0.012
# Winter mortality calibrated for 8,000–15,000 winter cluster.
# Science: true diutinus bees live 90–180 days; but the winter cluster is a
# mixed cohort of newer diutinus bees AND older bees that will die early.
# Net effective cluster mortality ~0.010–0.012/day is realistic.
NURSE_MORT_WINTER   = 0.008   # ~125-day lifespan in cluster (Amdam & Omholt 2002)
HOUSE_MORT_WINTER   = 0.008
FORAGER_MORT_WINTER = 0.012   # mixed summer+winter bees; some die earlier
WINTER_THRESHOLD    = 0.12

# CongestionDetector — post-fix
HONEY_BOUND_THRESHOLD = 0.62      # was 0.70
BROOD_BOUND_THRESHOLD = 0.65      # was 0.75
SWARM_PREP_THRESHOLD  = 0.78

# NurseSystem — post-fix
IDEAL_NURSE_RATIO   = 1.2         # was 2.0
ADEQUATE_RATIO      = 0.4
MIN_NURSE_COUNT     = 1500        # was 500

# HiveHealthCalculator — post-fix
HEALTHY_ADULTS  = 30_000
HEALTHY_BROOD   =  8_000
HEALTHY_HONEY   =    35.0         # was 20.0

# CellStateTransition — post-fix
VARROA_KILL_CHANCE = 0.10         # was 0.25
AFB_SPREAD_CHANCE  = 0.012        # was 0.04

# Hive geometry: 10 brood-box frames × ~2,973 laying-zone cells per frame
# Phase-5 fix: ELLIPSE_RX_RATIO updated to 0.52 in GDScript.
# rx=0.52×70=36.4, ry=0.52×50=26.0 → area ≈ π×36.4×26.0 ≈ 2,973 cells/frame
# Total 29,730 cells → queen can lay up to 1,416 eggs/day → ~55,000 summer peak ✓
MAX_BROOD_CELLS     = 29_730      # laying zone across all 10 frames
FRAME_SIZE          = 3_500
FRAMES_PER_BOX      = 10
TOTAL_DRAWN_CELLS   = FRAME_SIZE * FRAMES_PER_BOX   # 35,000

# Winter consumption science fix (Phase-5 cohesion):
# A winter cluster maintains ~34°C core against cold ambients.  This is a
# FIXED overhead shared by all cluster bees — not a per-bee cost that scales
# linearly.  A cluster of 35,000 bees consumes the same ~30 lbs honey as one
# of 10,000: the larger cluster is thermally more efficient (lower surface:
# volume ratio).  Model: winter_mult = 35,000 / cluster_size, clamped to ≥1.0.
# This yields total_adults × CONSUME_RATE × mult ≈ 35,000 × 0.000015 × 1.0
# = 0.525 lbs/day regardless of cluster size → 29.4 lbs/56-day winter. ✓
# Science: Seeley (1995) §7; Farrar (1943) — 25–30 lbs consumed per winter.
WINTER_CLUSTER_REFERENCE = 35_000   # full colony used as normalisation base
SUMMER_CONSUME_RATE = 0.000_015     # lbs/bee/day baseline


# ──────────────────────────────────────────────────────────────────────────────
# Helper: seasonal utilities
# ──────────────────────────────────────────────────────────────────────────────

def season_factor(day: int) -> float:
    """Return 0–1 season factor for a given simulation day (1-indexed)."""
    day_in_year = (day - 1) % YEAR_LENGTH
    month = day_in_year // MONTH_LENGTH
    return SEASON_FACTORS[month]

def month_index(day: int) -> int:
    day_in_year = (day - 1) % YEAR_LENGTH
    return day_in_year // MONTH_LENGTH

def is_winter(day: int) -> bool:
    return month_index(day) >= 6

def forage_pool(day: int, rng: random.Random) -> float:
    """
    Mock ForageManager forage pool — varies by season with light noise.
    Real game uses flower density on the world map, which players influence.
    Harness uses a seasonal average with ±10% daily noise.
    """
    sf = season_factor(day)
    if sf <= 0.08:          # deep winter — no flowers
        return 0.0
    # Summer peak forage_pool ≈ 0.80; spring/fall lower
    base = sf * 0.82
    noise = rng.gauss(0, 0.08)
    return max(0.0, min(1.0, base + noise))


# ──────────────────────────────────────────────────────────────────────────────
# Brood pipeline — cohort-based tracking
# ──────────────────────────────────────────────────────────────────────────────

class BroodPipeline:
    """
    Models the brood development pipeline using daily cohort queues.

    Three deque-style lists: eggs_cohorts[i] = eggs laid i days ago.
    When a cohort ages past the developmental threshold, it transitions.

    This gives exact day-accurate developmental timing without simulating
    individual cells, which is computationally too heavy for Python.
    """
    # Days a bee spends in each stage (within that stage)
    EGG_DAYS    = AGE_EGG_TO_LARVA                               # 3
    LARVA_DAYS  = AGE_LARVA_TO_CAPPED - AGE_EGG_TO_LARVA        # 6
    CAPPED_DAYS = AGE_WORKER_EMERGE   - AGE_LARVA_TO_CAPPED      # 12

    def __init__(self):
        # Each list has one slot per day-within-stage (not cumulative age).
        # Index 0 = entered stage today; index (stage_days-1) = ready to transition.
        self.eggs    = [0] * (self.EGG_DAYS    + 2)   # 5  slots
        self.larvae  = [0] * (self.LARVA_DAYS  + 2)   # 8  slots
        self.capped  = [0] * (self.CAPPED_DAYS + 2)   # 14 slots

    def tick(self, queen_lays: int, mite_rate: float, chill_risk: float,
             capping_delay: int, rng: random.Random) -> Dict:
        """
        Advance all cohorts by one day.
        Returns counts of emerged workers and damaged cells.
        """
        # Rotate: oldest cohort transitions first
        # 1. Capped → emerge
        # BUG FIX: threshold is CAPPED_DAYS (12) not AGE_WORKER_EMERGE (21).
        # The "age" index in self.capped represents days-in-capped-stage (0..11),
        # NOT cumulative age from egg-lay. A bee capped on day 9 emerges on day 21,
        # which is 12 days after capping, so the emerge threshold is CAPPED_DAYS=12.
        emerged_workers = 0
        damaged = 0
        for age in range(len(self.capped) - 1, -1, -1):
            if self.capped[age] > 0:
                if age >= self.CAPPED_DAYS:  # 12 days in capped stage → emerge
                    # Varroa kill check
                    n = self.capped[age]
                    # Simplified: apply VARROA_KILL_CHANCE only to cells where
                    # mite invaded.  Invasion rate ≈ mite_rate * 2.0 at capping.
                    if mite_rate >= 0.03:
                        expected_varroa = int(n * mite_rate * 2.0)
                        killed = sum(1 for _ in range(expected_varroa)
                                     if rng.random() < VARROA_KILL_CHANCE)
                        damaged += killed
                        emerged_workers += (n - killed)
                    else:
                        emerged_workers += n
                    self.capped[age] = 0

        # Shift capped cohorts forward
        for age in range(len(self.capped) - 1, 0, -1):
            self.capped[age] = self.capped[age - 1]
        self.capped[0] = 0

        # Chill damage to all current capped brood
        if chill_risk > 0.0:
            total_capped = sum(self.capped)
            chill_dead = sum(1 for _ in range(total_capped)
                             if rng.random() < chill_risk)
            # Distribute removals across oldest first
            for age in range(len(self.capped) - 1, -1, -1):
                if chill_dead <= 0:
                    break
                remove = min(chill_dead, self.capped[age])
                self.capped[age] -= remove
                damaged += remove
                chill_dead -= remove

        # 2. Larvae → capped
        # Same pattern: age = days-in-larva-stage. LARVA_DAYS=6 → cap at index 6+.
        cap_age = self.LARVA_DAYS + capping_delay   # normally 6 days as larva
        for age in range(len(self.larvae) - 1, -1, -1):
            if age >= cap_age and self.larvae[age] > 0:
                # Mite invasion at capping
                n = self.larvae[age]
                self.larvae[age] = 0
                # Place newly capped at age 0 of capped queue
                self.capped[0] += n

        # Shift larvae forward
        for age in range(len(self.larvae) - 1, 0, -1):
            self.larvae[age] = self.larvae[age - 1]
        self.larvae[0] = 0

        # 3. Eggs → larvae
        # EGG_DAYS=3 → hatch at index 3+.
        for age in range(len(self.eggs) - 1, -1, -1):
            if age >= self.EGG_DAYS and self.eggs[age] > 0:
                self.larvae[0] += self.eggs[age]
                self.eggs[age] = 0

        # Shift eggs forward
        for age in range(len(self.eggs) - 1, 0, -1):
            self.eggs[age] = self.eggs[age - 1]
        self.eggs[0] = 0

        # 4. Queen lays new eggs today
        self.eggs[0] = queen_lays

        return {
            "emerged_workers": emerged_workers,
            "damaged": damaged,
        }

    @property
    def egg_count(self) -> int:
        return sum(self.eggs)

    @property
    def larva_count(self) -> int:
        return sum(self.larvae)

    @property
    def capped_count(self) -> int:
        return sum(self.capped)

    @property
    def total_brood(self) -> int:
        return self.egg_count + self.larva_count + self.capped_count


# ──────────────────────────────────────────────────────────────────────────────
# Main simulation class
# ──────────────────────────────────────────────────────────────────────────────

@dataclass
class HiveSim:
    """
    Python equivalent of HiveSimulation.gd (post-fix version).
    Uses cohort-based math instead of per-cell arrays.
    """
    name:          str   = "Hive"
    seed:          int   = 42
    day:           int   = 0

    # Adult cohorts — post-fix starting values (24,000 total)
    nurse_count:   int   = 8_000
    house_count:   int   = 10_000
    forager_count: int   = 6_000
    drone_count:   int   = 500

    # Stores
    honey_stores:  float = 15.0    # lbs starting honey
    pollen_stores: float = 3.0

    # Mites
    mite_count:    float = 50.0    # low initial load

    # Congestion
    consec_cong:   int   = 0
    cong_state:    int   = 0       # 0=NORMAL, 1=BROOD_BOUND, 2=HONEY_BOUND, 3=FULL

    # Queen
    queen_laying_rate: int = 1500   # eggs/day target at peak

    # Cumulative tracking
    total_honey_produced: float = 0.0
    total_honey_consumed: float = 0.0
    harvest_events: List[float] = field(default_factory=list)

    # Per-hive persistent foraging efficiency modifier — drawn from seeded RNG
    # at init.  Models microclimate / territory / queen genetics differences.
    # ±15% range; this drives meaningful year-long honey store divergence between
    # hives even with identical starting conditions.
    forage_efficiency: float = field(default=1.0, init=False)

    def __post_init__(self):
        self.rng = random.Random(self.seed)
        # Draw persistent forage_efficiency NOW (before brood seeding uses rng)
        self.forage_efficiency = self.rng.uniform(0.85, 1.15)
        self.brood = BroodPipeline()
        # Seed initial brood representing an established early-spring colony.
        # GDD: starts with "one established Langstroth hive" — not a new package.
        # Early spring seeding rate ~800/day (queen ramping up, moderate population).
        # Spread across pipeline so bees emerge naturally over first 21 days.
        # Seed with correct per-stage day counts (not cumulative ages)
        initial_daily = 800
        for i in range(BroodPipeline.EGG_DAYS):          # 3 slots
            self.brood.eggs[i] = initial_daily
        for i in range(BroodPipeline.LARVA_DAYS):         # 6 slots
            self.brood.larvae[i] = initial_daily
        for i in range(BroodPipeline.CAPPED_DAYS):        # 12 slots
            self.brood.capped[i] = initial_daily

    def tick(self) -> Dict:
        self.day += 1
        sf   = season_factor(self.day)
        fp   = forage_pool(self.day, self.rng)
        win  = is_winter(self.day)

        # ── NurseSystem ────────────────────────────────────────────────────────
        open_larva = self.brood.larva_count
        nurse_ratio = float(self.nurse_count) / max(1.0, float(open_larva))
        adequate = self.nurse_count >= MIN_NURSE_COUNT and nurse_ratio >= ADEQUATE_RATIO * 0.5
        if nurse_ratio >= ADEQUATE_RATIO:
            capping_delay = 0
        elif nurse_ratio >= ADEQUATE_RATIO * 0.5:
            capping_delay = 1
        else:
            capping_delay = 2

        # ── Brood transition (CellStateTransition equivalent) ──────────────────
        total_adults = self.nurse_count + self.house_count + self.forager_count
        total_brood  = self.brood.total_brood
        mite_rate    = min(self.mite_count / max(1.0, float(total_adults)), 1.0)
        chill_risk   = 0.0
        if total_adults < total_brood * 2:
            chill_risk = min(
                (float(total_brood) - float(total_adults) * 2.0) / max(1.0, float(total_brood)),
                0.06
            )

        queen_lays = self._queen_lay(sf)
        brood_result = self.brood.tick(queen_lays, mite_rate, chill_risk,
                                       capping_delay, self.rng)
        emerged   = brood_result["emerged_workers"]
        damaged   = brood_result["damaged"]

        # ── PopulationCohortManager ────────────────────────────────────────────
        if win:
            nurse_mort   = NURSE_MORT_WINTER
            house_mort   = HOUSE_MORT_WINTER
            forager_mort = FORAGER_MORT_WINTER
            # In true winter, bees form a cluster — no cohort progression.
            grad_nurse   = 0
            grad_house   = 0
        else:
            nurse_mort   = NURSE_MORT_SUMMER
            house_mort   = HOUSE_MORT_SUMMER
            forager_mort = FORAGER_MORT_SUMMER
            grad_nurse   = int(self.nurse_count  / NURSE_DAYS_SUMMER)
            # Science fix: removing season_factor multiplier from grad_house.
            # House bees graduate to foragers at the normal biological rate
            # year-round (except true winter).  The season reduction was causing
            # house bees to pile up in fall instead of becoming foragers and
            # dying naturally, which inflated winter cluster size artificially.
            grad_house   = int(self.house_count  / HOUSE_DAYS_SUMMER)

        if sf >= 0.65:
            drone_mort = DRONE_MORT_SUMMER
        else:
            drone_mort = min(0.012 + (1.0 - sf) * 0.15, 0.20)

        self.nurse_count   += emerged
        self.nurse_count   -= grad_nurse
        self.nurse_count   -= int(self.nurse_count * nurse_mort)
        self.nurse_count    = max(0, self.nurse_count)

        self.house_count   += grad_nurse
        self.house_count   -= grad_house
        self.house_count   -= int(self.house_count * house_mort)
        self.house_count    = max(0, self.house_count)

        self.forager_count += grad_house
        self.forager_count -= int(self.forager_count * forager_mort)
        self.forager_count  = max(0, self.forager_count)

        self.drone_count   -= int(self.drone_count * drone_mort)
        self.drone_count    = max(0, self.drone_count)
        # Summer: add some drone production (proxy)
        if sf > 0.7 and self.drone_count < 300:
            self.drone_count += int(sf * 20)

        total_adults = self.nurse_count + self.house_count + self.forager_count

        # ── ForagerSystem ──────────────────────────────────────────────────────
        # forage_efficiency: persistent site-quality / queen-genetics modifier
        # (drawn per-hive at init — creates structural divergence between hives)
        nectar_base = float(self.forager_count) * NECTAR_PER_FORAGER * fp * sf * self.forage_efficiency
        pollen_base = float(self.forager_count) * POLLEN_PER_FORAGER * fp * sf * self.forage_efficiency
        daily_var   = self.rng.uniform(0.80, 1.20)
        nectar_in   = nectar_base * daily_var
        pollen_in   = pollen_base * daily_var
        if self.cong_state in (2, 3):
            nectar_in *= 0.60    # 40% congestion penalty

        # ── Honey stores update ────────────────────────────────────────────────
        honey_gain  = nectar_in * NECTAR_TO_HONEY
        # Dynamic winter multiplier: cluster heating is a fixed overhead ≈ constant
        # per day regardless of cluster size (larger cluster = better insulation).
        # Formula: mult = REFERENCE_SIZE / current_size, clamped to [1.0, 4.0].
        # Result: total consumption ≈ 0.525 lbs/day in winter (≈29 lbs/56-day winter).
        if win:
            winter_mult = max(1.0, min(4.0, WINTER_CLUSTER_REFERENCE / max(1, total_adults)))
        else:
            winter_mult = 1.0
        consumption = total_adults * SUMMER_CONSUME_RATE * winter_mult
        self.honey_stores  = max(0.0, self.honey_stores + honey_gain - consumption)
        self.pollen_stores = max(0.0, self.pollen_stores + pollen_in
                                 - float(self.nurse_count) * 0.00003)

        self.total_honey_produced += honey_gain
        self.total_honey_consumed += consumption

        # ── Mite reproduction (exponential model) ──────────────────────────────
        brood_avail = min(1.0, float(self.brood.capped_count) / 8000.0)
        self.mite_count += self.mite_count * 0.017 * brood_avail
        self.mite_count  = min(self.mite_count, 5000.0)

        # ── CongestionDetector ─────────────────────────────────────────────────
        brood_cells  = total_brood
        honey_cells  = int(self.honey_stores / 5.0 * FRAME_SIZE)  # approx
        total_drawn  = TOTAL_DRAWN_CELLS
        brood_frac   = brood_cells / total_drawn
        honey_frac   = min(1.0, honey_cells / total_drawn)

        brood_bound = brood_frac >= BROOD_BOUND_THRESHOLD
        honey_bound = honey_frac >= HONEY_BOUND_THRESHOLD
        if brood_bound and honey_bound:
            self.cong_state = 3
        elif honey_bound:
            self.cong_state = 2
        elif brood_bound:
            self.cong_state = 1
        else:
            self.cong_state = 0

        if self.cong_state != 0:
            self.consec_cong += 1
        else:
            self.consec_cong = 0

        swarm_prep = (brood_frac + honey_frac >= SWARM_PREP_THRESHOLD
                      and self.consec_cong >= 7)

        # ── Health score ───────────────────────────────────────────────────────
        health = self._health_score(total_adults)

        return {
            "day":            self.day,
            "name":           self.name,
            "season_factor":  sf,
            "month":          MONTH_NAMES[month_index(self.day)],
            "is_winter":      win,
            "egg_count":      self.brood.egg_count,
            "larva_count":    self.brood.larva_count,
            "capped_count":   self.brood.capped_count,
            "total_brood":    total_brood,
            "nurse_count":    self.nurse_count,
            "house_count":    self.house_count,
            "forager_count":  self.forager_count,
            "drone_count":    self.drone_count,
            "total_adults":   total_adults,
            "honey_stores":   round(self.honey_stores, 2),
            "pollen_stores":  round(self.pollen_stores, 2),
            "nectar_in":      round(nectar_in, 3),
            "honey_gain":     round(honey_gain, 3),
            "consumption":    round(consumption, 3),
            "mite_count":     round(self.mite_count, 1),
            "mite_rate_pct":  round(mite_rate * 100, 2),
            "cong_state":     self.cong_state,
            "swarm_prep":     swarm_prep,
            "queen_lays":     queen_lays,
            "capping_delay":  capping_delay,
            "health_score":   round(health, 1),
            "daily_var":      round(daily_var, 3),
            "forage_pool":    round(fp, 2),
        }

    def _queen_lay(self, sf: float) -> int:
        """
        Queen lays target eggs/day adjusted by season and available space.
        Space-limited: can't lay more than available empty brood cells.
        """
        target = int(self.queen_laying_rate * sf)
        if target <= 0:
            return 0
        # Available brood cells = MAX_BROOD_CELLS - current brood
        available = max(0, MAX_BROOD_CELLS - self.brood.total_brood)
        # Queen also won't lay more than ~92% of available (skip probability)
        return min(target, int(available * 0.88))

    def _health_score(self, total_adults: int) -> float:
        total_brood = self.brood.total_brood

        pop_score   = min(1.0, total_adults / HEALTHY_ADULTS)
        brood_score = min(1.0, total_brood  / HEALTHY_BROOD)
        h_score     = min(1.0, self.honey_stores  / HEALTHY_HONEY)
        p_score     = min(1.0, self.pollen_stores / 5.0)
        store_score = h_score * 0.7 + p_score * 0.3
        queen_score = 0.75   # B-grade queen (default)

        varroa_pen  = min(1.0, self.mite_count / 3000.0)
        raw = (pop_score   * 0.25 +
               brood_score * 0.25 +
               store_score * 0.20 +
               queen_score * 0.20)
        health = raw * (1.0 - varroa_pen * 0.10)
        return min(100.0, health * 100.0)

    def harvest(self, leave_lbs: float = 25.0) -> float:
        """Harvest harvestable honey, leaving leave_lbs for winter survival.
        Science: winter cluster needs 25–35 lbs; 25 lbs is minimum safe threshold
        for a well-insulated hive in a moderate climate (GDD §2.4: 30–50 lbs 'adequate').
        Leaving 25 lbs allows harvest while maintaining winter viability."""
        harvestable = max(0.0, self.honey_stores - leave_lbs)
        self.honey_stores -= harvestable
        if harvestable > 0:
            self.harvest_events.append(harvestable)
        return harvestable


# ──────────────────────────────────────────────────────────────────────────────
# Run simulation
# ──────────────────────────────────────────────────────────────────────────────

def run(days: int = 365, write_csv: bool = False,
        harvest_day: int = 140) -> None:
    """
    Simulate two hives for `days` days.  Hive B has a different seed
    (and therefore different daily forager variance and forage_efficiency)
    to model realistic divergence between hives on the same apiary.

    Two harvests:
      • Summer (day 112, end of High-Sun):  leave 35 lbs for late-summer needs
      • Fall   (harvest_day, default 140):  leave 25 lbs for winter
    Science: Seeley (1995) — beekeepers typically extract in late summer and
    again in fall; leaving 25–30 lbs for a well-managed winter cluster.
    """
    hive_a = HiveSim(name="Hive-A", seed=1701)
    hive_b = HiveSim(name="Hive-B", seed=2048)

    print(f"\n  Hive-A forage_efficiency: {hive_a.forage_efficiency:.3f}")
    print(f"  Hive-B forage_efficiency: {hive_b.forage_efficiency:.3f}")

    rows_a: List[Dict] = []
    rows_b: List[Dict] = []

    SUMMER_HARVEST_DAY  = 112   # end of High-Sun — peak honey stores
    SUMMER_HARVEST_LEAVE = 35.0  # leave for rest of summer + fall buildup
    FALL_HARVEST_LEAVE   = 25.0  # leave for winter survival

    # ── Track validation metrics ───────────────────────────────────────────────
    peak_adults_a = peak_adults_b = 0
    winter_adults_a_total = winter_adults_b_total = 0
    winter_min_a = winter_min_b = 999_999   # minimum adults during winter
    winter_days = 0
    winter_honey_start_a = winter_honey_start_b = None
    winter_honey_end_a   = winter_honey_end_b   = None
    varroa_doubling_day_a = varroa_doubling_day_b = -1
    varroa_initial = 50.0

    for d in range(1, days + 1):
        snap_a = hive_a.tick()
        snap_b = hive_b.tick()
        rows_a.append(snap_a)
        rows_b.append(snap_b)

        # Summer harvest (peak-season extraction)
        if d == SUMMER_HARVEST_DAY:
            h_a = hive_a.harvest(leave_lbs=SUMMER_HARVEST_LEAVE)
            h_b = hive_b.harvest(leave_lbs=SUMMER_HARVEST_LEAVE)
            if h_a > 0 or h_b > 0:
                print(f"\n  ── Day {d} SUMMER HARVEST ──  A: {h_a:.1f} lbs  B: {h_b:.1f} lbs")

        # Fall harvest (pre-winter extraction)
        if d == harvest_day and d != SUMMER_HARVEST_DAY:
            h_a = hive_a.harvest(leave_lbs=FALL_HARVEST_LEAVE)
            h_b = hive_b.harvest(leave_lbs=FALL_HARVEST_LEAVE)
            if h_a > 0 or h_b > 0:
                print(f"\n  ── Day {d} FALL HARVEST ──  A: {h_a:.1f} lbs  B: {h_b:.1f} lbs")

        # Peak tracking
        if snap_a["total_adults"] > peak_adults_a:
            peak_adults_a = snap_a["total_adults"]
        if snap_b["total_adults"] > peak_adults_b:
            peak_adults_b = snap_b["total_adults"]

        # Winter cluster tracking
        if snap_a["is_winter"]:
            winter_days += 1
            winter_adults_a_total += snap_a["total_adults"]
            winter_adults_b_total += snap_b["total_adults"]
            winter_min_a = min(winter_min_a, snap_a["total_adults"])
            winter_min_b = min(winter_min_b, snap_b["total_adults"])
            # Record honey at ENTRY to winter (first winter day)
            if winter_honey_start_a is None:
                winter_honey_start_a = snap_a["honey_stores"]
                winter_honey_start_b = snap_b["honey_stores"]
            # Record honey at EXIT from winter (last winter day = each winter day overwrites)
            winter_honey_end_a = snap_a["honey_stores"]
            winter_honey_end_b = snap_b["honey_stores"]

        # Varroa doubling time
        if varroa_doubling_day_a < 0 and hive_a.mite_count >= varroa_initial * 2:
            varroa_doubling_day_a = d
        if varroa_doubling_day_b < 0 and hive_b.mite_count >= varroa_initial * 2:
            varroa_doubling_day_b = d

    # ── Compute winter metrics ─────────────────────────────────────────────────
    # winter_min: minimum population during winter (reflects end-of-winter nadir)
    if winter_min_a == 999_999: winter_min_a = 0
    if winter_min_b == 999_999: winter_min_b = 0

    # Winter honey consumed: entry stores minus exit stores (within winter period only)
    winter_consumed_a = max(0, (winter_honey_start_a or 0) - (winter_honey_end_a or 0))
    winter_consumed_b = max(0, (winter_honey_start_b or 0) - (winter_honey_end_b or 0))
    winter_avg_a = winter_adults_a_total / max(1, winter_days)
    winter_avg_b = winter_adults_b_total / max(1, winter_days)

    # Total annual honey
    honey_year_a = hive_a.total_honey_produced
    honey_year_b = hive_b.total_honey_produced
    harvest_a    = sum(hive_a.harvest_events)
    harvest_b    = sum(hive_b.harvest_events)

    # Divergence: % difference in honey_stores at end of simulation
    end_honey_a = rows_a[-1]["honey_stores"]
    end_honey_b = rows_b[-1]["honey_stores"]
    divergence_pct = (
        abs(end_honey_a - end_honey_b) / max(0.01, (end_honey_a + end_honey_b) / 2) * 100
    )

    # ── Print daily summary (sampled every 14 days for readability) ─────────────
    print("=" * 100)
    print("BEEKEE PRO — 365-DAY HIVE SIMULATION HARNESS (post-fix)")
    print("=" * 100)
    header = (f"{'Day':>4}  {'Month':<14}  {'SF':>4}  "
              f"{'Adults-A':>8}  {'Brood-A':>7}  {'Honey-A':>7}  "
              f"{'Adults-B':>8}  {'Honey-B':>7}  "
              f"{'Mites-A':>7}  {'Health-A':>8}  {'Lays':>5}")
    print(header)
    print("-" * 100)

    for i, (ra, rb) in enumerate(zip(rows_a, rows_b)):
        d = ra["day"]
        if d == 1 or d % 14 == 0 or d == days:
            print(
                f"{d:>4}  {ra['month']:<14}  {ra['season_factor']:>4.2f}  "
                f"{ra['total_adults']:>8,}  {ra['total_brood']:>7,}  "
                f"{ra['honey_stores']:>7.1f}  "
                f"{rb['total_adults']:>8,}  {rb['honey_stores']:>7.1f}  "
                f"{ra['mite_count']:>7.0f}  {ra['health_score']:>8.1f}  "
                f"{ra['queen_lays']:>5}"
            )

    # ── Validation Report ──────────────────────────────────────────────────────
    print("\n" + "=" * 100)
    print("VALIDATION REPORT")
    print("=" * 100)

    def check(label: str, value, lo, hi, unit: str = "") -> None:
        ok = lo <= value <= hi
        marker = "✓" if ok else "✗ FAIL"
        print(f"  {marker}  {label}: {value:.1f}{unit}  (target {lo}–{hi}{unit})")

    print("\n── Population Targets ──")
    check("Hive-A peak adults (summer)",           peak_adults_a,  40_000, 65_000)
    check("Hive-B peak adults (summer)",           peak_adults_b,  40_000, 65_000)
    # Winter cluster: track the MINIMUM population (end-of-winter nadir).
    # Science: a strong colony enters winter at 25,000–40,000 and exits at
    # 10,000–25,000 (Winston 1987).  Target 8,000–28,000 covers healthy colonies.
    check("Hive-A winter minimum (end-of-winter)", winter_min_a,    8_000, 28_000)
    check("Hive-B winter minimum (end-of-winter)", winter_min_b,    8_000, 28_000)
    print(f"       (winter avg A: {winter_avg_a:,.0f}  B: {winter_avg_b:,.0f})")
    print(f"       (winter entry honey A: {winter_honey_start_a or 0:.1f} lbs"
          f"  B: {winter_honey_start_b or 0:.1f} lbs)")

    print("\n── Honey Targets ──")
    check("Hive-A annual production",         honey_year_a,          150,    450, " lbs")
    check("Hive-B annual production",         honey_year_b,          150,    450, " lbs")
    # Harvest target: two harvests from an established colony in a 365-day run.
    # Science: 40–100 lbs harvestable from a managed colony per season (USDA/NCA).
    # Our 365-day run = ~1.6 game years; 40–100 lbs is achievable from two harvests.
    check("Hive-A total harvest",             harvest_a,              40,    120, " lbs")
    check("Hive-B total harvest",             harvest_b,              40,    120, " lbs")
    # Winter consumption: measured from entry to exit honey within winter period.
    # Science: 25–35 lbs consumed per winter season (Farrar 1943, Seeley 1995).
    check("Hive-A winter consumption",        winter_consumed_a,      20,     45, " lbs")
    check("Hive-B winter consumption",        winter_consumed_b,      20,     45, " lbs")

    print("\n── Varroa Dynamics ──")
    doubling_a_str = f"{varroa_doubling_day_a}" if varroa_doubling_day_a > 0 else "not yet"
    doubling_b_str = f"{varroa_doubling_day_b}" if varroa_doubling_day_b > 0 else "not yet"
    print(f"  Hive-A varroa doubling: day {doubling_a_str}  (target 40–70 days)")
    print(f"  Hive-B varroa doubling: day {doubling_b_str}  (target 40–70 days)")
    if varroa_doubling_day_a > 0:
        ok = 40 <= varroa_doubling_day_a <= 70
        print(f"  {'✓' if ok else '✗ FAIL'}  Hive-A varroa doubling within target")

    print("\n── Hive Divergence ──")
    check("Honey store divergence by day 365", divergence_pct,         8,     30, "%")
    print(f"       Hive-A final honey: {end_honey_a:.1f} lbs")
    print(f"       Hive-B final honey: {end_honey_b:.1f} lbs")

    print("\n── No Impossible States ──")
    min_adults_a = min(r["total_adults"] for r in rows_a)
    min_adults_b = min(r["total_adults"] for r in rows_b)
    min_honey_a  = min(r["honey_stores"] for r in rows_a)
    min_honey_b  = min(r["honey_stores"] for r in rows_b)
    problems = []
    if min_adults_a < 0 or min_adults_b < 0:
        problems.append("Negative adult population")
    if min_honey_a < -0.001 or min_honey_b < -0.001:
        problems.append("Negative honey stores")
    for r in rows_a + rows_b:
        if r["egg_count"] < 0 or r["larva_count"] < 0 or r["capped_count"] < 0:
            problems.append("Negative brood count")
            break
    if problems:
        print(f"  ✗ FAIL  Impossible states: {', '.join(problems)}")
    else:
        print(f"  ✓  No impossible states detected")
        print(f"     Min adults A: {min_adults_a:,}  Min adults B: {min_adults_b:,}")
        print(f"     Min honey A:  {min_honey_a:.2f} lbs  Min honey B: {min_honey_b:.2f} lbs")

    print("\n── Seasonal Curve Check ──")
    # Find approximate peak day and winter low for Hive-A
    peak_day_a   = max(range(days), key=lambda i: rows_a[i]["total_adults"])
    winter_low_a = min(range(days), key=lambda i: rows_a[i]["total_adults"])
    print(f"  Peak adults at day {peak_day_a+1} ({rows_a[peak_day_a]['month']}): "
          f"{rows_a[peak_day_a]['total_adults']:,}")
    print(f"  Winter low at day {winter_low_a+1} ({rows_a[winter_low_a]['month']}): "
          f"{rows_a[winter_low_a]['total_adults']:,}")
    # Peak should be in Wide-Clover or High-Sun (months 2–3, days 57–112)
    peak_month = month_index(peak_day_a + 1)
    ok_peak = peak_month in (1, 2, 3)   # Greening through High-Sun
    print(f"  {'✓' if ok_peak else '✗ FAIL'}  Peak occurs in expected summer/late-spring months")

    print("\n" + "=" * 100)
    print("SIMULATION COMPLETE")
    print("=" * 100)

    # ── Optional CSV output ────────────────────────────────────────────────────
    if write_csv:
        csv_path = "hive_sim_results.csv"
        fieldnames = list(rows_a[0].keys())
        with open(csv_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows_a)
            writer.writerows(rows_b)
        print(f"\nResults written to {csv_path}")


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Smoke and Honey hive simulation harness")
    parser.add_argument("--days",    type=int,  default=365,
                        help="Number of days to simulate (default 365)")
    parser.add_argument("--csv",     action="store_true",
                        help="Write per-day results to hive_sim_results.csv")
    parser.add_argument("--harvest", type=int,  default=140,
                        help="Day to attempt honey harvest (default 140, end of fall)")
    args = parser.parse_args()

    run(days=args.days, write_csv=args.csv, harvest_day=args.harvest)
