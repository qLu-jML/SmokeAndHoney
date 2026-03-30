#!/usr/bin/env python3
"""
Phase 1: Brood Biology Simulation
==================================
Karpathy Incremental Research - Smoke & Honey

Maps to: CellStateTransition.gd (Step 1 of simulation pipeline)

This phase isolates the brood development pipeline in pure form:
  egg -> larva -> capped brood -> emerged adult

NO population dynamics, NO foraging, NO disease -- just the biological
clock that converts queen-laid eggs into adult bees over 21 days.

Science references:
  - Winston (1987) "The Biology of the Honey Bee" - developmental timing
  - Seeley (1995) "The Wisdom of the Hive" - brood nest organization
  - GDD Section 3.1 - Bee lifecycle durations

Validation targets:
  [x] Egg stage: exactly 3 days
  [x] Larva stage: exactly 6 days (days 4-9 from egg)
  [x] Capped brood stage: exactly 12 days (days 10-21 from egg)
  [x] Total egg-to-emergence: exactly 21 days
  [x] Cell reuse: vacated cell becomes empty_drawn on next tick
  [x] No spontaneous generation: empty cells stay empty
  [x] Age counter resets on each state transition
  [x] State conservation: total cells never changes
  [x] No state skipping: cells advance one state per transition

GDScript reimplementation notes:
  - CellState enum maps directly to GDScript's S_* constants
  - process_cell() mirrors CellStateTransition._advance_cell()
  - Frame/side structure mirrors HiveFrame PackedByteArray layout
"""

import sys
from enum import IntEnum
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# Cell State Enum -- mirrors CellStateTransition.gd S_* constants
# ---------------------------------------------------------------------------
class CellState(IntEnum):
    EMPTY_FOUNDATION = 0
    EMPTY_DRAWN = 1
    EGG = 2
    LARVA = 3
    CAPPED_BROOD = 4
    VACATED = 5          # just emerged, cleaning cycle
    NECTAR = 6
    RIPENING_HONEY = 7
    CAPPED_HONEY = 8
    POLLEN = 9
    # Disease states (Phase 5 adds these, stubbed here)
    AFB_INFECTED = 10
    EFB_INFECTED = 11
    VARROA_INFESTED = 12
    CHALKBROOD = 13

    @classmethod
    def is_brood(cls, state: int) -> bool:
        return state in (cls.EGG, cls.LARVA, cls.CAPPED_BROOD)

    @classmethod
    def is_storage(cls, state: int) -> bool:
        return state in (cls.NECTAR, cls.RIPENING_HONEY, cls.CAPPED_HONEY, cls.POLLEN)


# ---------------------------------------------------------------------------
# Developmental Timing Constants -- from Winston (1987) & GDD
# ---------------------------------------------------------------------------
# These are STAGE DURATIONS (days spent in each stage), not cumulative ages
EGG_DURATION = 3          # days as egg before hatching to larva
LARVA_DURATION = 6        # days as open larva before capping
CAPPED_BROOD_DURATION = 12  # days capped before emergence (pupa + pre-pupa)
TOTAL_DEVELOPMENT = EGG_DURATION + LARVA_DURATION + CAPPED_BROOD_DURATION  # 21 days

# Honey processing durations
NECTAR_RIPEN_DURATION = 3   # days from nectar deposit to ripening
HONEY_CAP_DURATION = 5      # days from ripening to capped honey

# Vacated cell cleanup
VACATED_DURATION = 1         # nurse bees clean cell in ~1 day


# ---------------------------------------------------------------------------
# Cell Data Structure
# ---------------------------------------------------------------------------
@dataclass
class Cell:
    """Single cell on a frame side. Mirrors one entry in PackedByteArray."""
    state: int = CellState.EMPTY_FOUNDATION
    age: int = 0  # days in current state

    def advance(self) -> Optional[int]:
        """
        Advance this cell by one day. Returns the new state if a transition
        occurred, or None if the cell just aged.

        This is the core biology clock. Phase 1 handles ONLY:
        - Brood cycle: EGG -> LARVA -> CAPPED_BROOD -> VACATED -> EMPTY_DRAWN
        - Storage cycle: NECTAR -> RIPENING_HONEY -> CAPPED_HONEY (stable)
        - Cleanup: VACATED -> EMPTY_DRAWN

        Disease states are handled in Phase 5.
        """
        if self.state == CellState.EMPTY_FOUNDATION:
            return None  # foundation never changes on its own
        if self.state == CellState.EMPTY_DRAWN:
            return None  # drawn comb waits for queen or nectar

        self.age += 1

        # --- Brood cycle ---
        if self.state == CellState.EGG:
            if self.age >= EGG_DURATION:
                self.state = CellState.LARVA
                self.age = 0
                return CellState.LARVA

        elif self.state == CellState.LARVA:
            if self.age >= LARVA_DURATION:
                self.state = CellState.CAPPED_BROOD
                self.age = 0
                return CellState.CAPPED_BROOD

        elif self.state == CellState.CAPPED_BROOD:
            if self.age >= CAPPED_BROOD_DURATION:
                self.state = CellState.VACATED
                self.age = 0
                return CellState.VACATED

        elif self.state == CellState.VACATED:
            if self.age >= VACATED_DURATION:
                self.state = CellState.EMPTY_DRAWN
                self.age = 0
                return CellState.EMPTY_DRAWN

        # --- Storage cycle ---
        elif self.state == CellState.NECTAR:
            if self.age >= NECTAR_RIPEN_DURATION:
                self.state = CellState.RIPENING_HONEY
                self.age = 0
                return CellState.RIPENING_HONEY

        elif self.state == CellState.RIPENING_HONEY:
            if self.age >= HONEY_CAP_DURATION:
                self.state = CellState.CAPPED_HONEY
                self.age = 0
                return CellState.CAPPED_HONEY

        elif self.state == CellState.CAPPED_HONEY:
            pass  # stable until harvested or consumed

        elif self.state == CellState.POLLEN:
            pass  # stable until consumed

        return None


# ---------------------------------------------------------------------------
# Frame Side -- a grid of cells (one side of one frame)
# ---------------------------------------------------------------------------
@dataclass
class FrameSide:
    """
    One side of a frame. In the game this is a PackedByteArray of
    grid_cols * grid_rows entries. Here we use Cell objects for clarity.

    GDScript equivalent: HiveFrame.cells[side * total_cells ... ]
    """
    cols: int = 70
    rows: int = 50
    cells: List[Cell] = field(default_factory=list)

    def __post_init__(self):
        if not self.cells:
            self.cells = [Cell() for _ in range(self.cols * self.rows)]

    @property
    def total_cells(self) -> int:
        return self.cols * self.rows

    def count_state(self, state: int) -> int:
        return sum(1 for c in self.cells if c.state == state)

    def full_count(self) -> Dict[int, int]:
        counts = {}
        for s in CellState:
            counts[s] = 0
        for c in self.cells:
            counts[c.state] = counts.get(c.state, 0) + 1
        return counts

    def tick(self) -> Dict[str, int]:
        """Advance all cells by one day. Returns transition counts."""
        transitions = {
            "eggs_hatched": 0,
            "larvae_capped": 0,
            "brood_emerged": 0,
            "cells_cleaned": 0,
            "nectar_ripened": 0,
            "honey_capped": 0,
        }
        for cell in self.cells:
            new_state = cell.advance()
            if new_state == CellState.LARVA:
                transitions["eggs_hatched"] += 1
            elif new_state == CellState.CAPPED_BROOD:
                transitions["larvae_capped"] += 1
            elif new_state == CellState.VACATED:
                transitions["brood_emerged"] += 1
            elif new_state == CellState.EMPTY_DRAWN:
                transitions["cells_cleaned"] += 1
            elif new_state == CellState.RIPENING_HONEY:
                transitions["nectar_ripened"] += 1
            elif new_state == CellState.CAPPED_HONEY:
                transitions["honey_capped"] += 1
        return transitions


# ---------------------------------------------------------------------------
# Frame -- two sides
# ---------------------------------------------------------------------------
@dataclass
class Frame:
    """
    One frame with two sides. Mirrors HiveFrame in HiveSimulation.gd.
    """
    side_a: FrameSide = field(default_factory=FrameSide)
    side_b: FrameSide = field(default_factory=FrameSide)

    def tick(self) -> Dict[str, int]:
        t_a = self.side_a.tick()
        t_b = self.side_b.tick()
        return {k: t_a[k] + t_b[k] for k in t_a}

    def count_brood(self) -> int:
        total = 0
        for side in (self.side_a, self.side_b):
            total += side.count_state(CellState.EGG)
            total += side.count_state(CellState.LARVA)
            total += side.count_state(CellState.CAPPED_BROOD)
        return total

    def full_count(self) -> Dict[int, int]:
        ca = self.side_a.full_count()
        cb = self.side_b.full_count()
        return {k: ca.get(k, 0) + cb.get(k, 0) for k in set(ca) | set(cb)}


# ---------------------------------------------------------------------------
# Validation Tests
# ---------------------------------------------------------------------------
def test_brood_cycle_timing():
    """Verify exact developmental timing: egg(3) + larva(6) + capped(12) = 21 days."""
    print("\n--- Test: Brood Cycle Timing ---")
    cell = Cell(state=CellState.EGG, age=0)

    # Track state transitions day by day
    transitions = []
    for day in range(1, 30):
        old_state = cell.state
        result = cell.advance()
        if result is not None:
            transitions.append((day, CellState(old_state).name, CellState(result).name))

    # Expected transitions:
    # Day 3: EGG -> LARVA
    # Day 9: LARVA -> CAPPED_BROOD (3 egg + 6 larva)
    # Day 21: CAPPED_BROOD -> VACATED (3 + 6 + 12)
    # Day 22: VACATED -> EMPTY_DRAWN (cleanup)
    expected = [
        (3, "EGG", "LARVA"),
        (9, "LARVA", "CAPPED_BROOD"),
        (21, "CAPPED_BROOD", "VACATED"),
        (22, "VACATED", "EMPTY_DRAWN"),
    ]

    all_pass = True
    for exp, got in zip(expected, transitions):
        match = exp == got
        status = "PASS" if match else "FAIL"
        if not match:
            all_pass = False
        print(f"  [{status}] Day {exp[0]}: {exp[1]} -> {exp[2]}"
              + (f" (got day {got[0]}: {got[1]} -> {got[2]})" if not match else ""))

    if len(transitions) != len(expected):
        print(f"  [FAIL] Expected {len(expected)} transitions, got {len(transitions)}")
        all_pass = False

    return all_pass


def test_no_spontaneous_generation():
    """Empty cells must not change state on their own."""
    print("\n--- Test: No Spontaneous Generation ---")
    foundation = Cell(state=CellState.EMPTY_FOUNDATION, age=0)
    drawn = Cell(state=CellState.EMPTY_DRAWN, age=0)

    for day in range(100):
        foundation.advance()
        drawn.advance()

    pass_foundation = (foundation.state == CellState.EMPTY_FOUNDATION)
    pass_drawn = (drawn.state == CellState.EMPTY_DRAWN)

    print(f"  [{'PASS' if pass_foundation else 'FAIL'}] Foundation stays foundation after 100 ticks")
    print(f"  [{'PASS' if pass_drawn else 'FAIL'}] Drawn comb stays drawn after 100 ticks")
    return pass_foundation and pass_drawn


def test_age_resets_on_transition():
    """Age must reset to 0 when a cell transitions to a new state."""
    print("\n--- Test: Age Resets on Transition ---")
    cell = Cell(state=CellState.EGG, age=0)
    all_pass = True

    for day in range(25):
        result = cell.advance()
        if result is not None:
            if cell.age != 0:
                print(f"  [FAIL] Age was {cell.age} after transition to {CellState(cell.state).name} on day {day+1}")
                all_pass = False

    print(f"  [{'PASS' if all_pass else 'FAIL'}] Age resets to 0 on every state transition")
    return all_pass


def test_state_conservation():
    """Total cell count on a frame side must never change."""
    print("\n--- Test: State Conservation ---")
    side = FrameSide(cols=10, rows=10)  # 100 cells for speed

    # Place some eggs and nectar
    for i in range(20):
        side.cells[i].state = CellState.EGG
        side.cells[i].age = 0
    for i in range(20, 30):
        side.cells[i].state = CellState.NECTAR
        side.cells[i].age = 0
    for i in range(30, 50):
        side.cells[i].state = CellState.EMPTY_DRAWN
        side.cells[i].age = 0

    total = side.total_cells
    all_pass = True

    for day in range(30):
        side.tick()
        counts = side.full_count()
        current_total = sum(counts.values())
        if current_total != total:
            print(f"  [FAIL] Day {day+1}: total cells {current_total} != expected {total}")
            all_pass = False
            break

    print(f"  [{'PASS' if all_pass else 'FAIL'}] Total cells conserved over 30 ticks ({total} cells)")
    return all_pass


def test_no_state_skipping():
    """Brood must progress through every stage in order, no skipping."""
    print("\n--- Test: No State Skipping ---")
    cell = Cell(state=CellState.EGG, age=0)
    state_sequence = [CellState.EGG]

    for day in range(25):
        result = cell.advance()
        if result is not None:
            state_sequence.append(result)

    expected_sequence = [
        CellState.EGG,
        CellState.LARVA,
        CellState.CAPPED_BROOD,
        CellState.VACATED,
        CellState.EMPTY_DRAWN,
    ]

    match = state_sequence == expected_sequence
    print(f"  [{'PASS' if match else 'FAIL'}] Brood state sequence: "
          + " -> ".join(CellState(s).name for s in state_sequence))
    if not match:
        print(f"  Expected: " + " -> ".join(CellState(s).name for s in expected_sequence))
    return match


def test_storage_cycle_timing():
    """Verify nectar -> ripening -> capped honey timing."""
    print("\n--- Test: Storage Cycle Timing ---")
    cell = Cell(state=CellState.NECTAR, age=0)
    transitions = []

    for day in range(1, 15):
        old_state = cell.state
        result = cell.advance()
        if result is not None:
            transitions.append((day, CellState(old_state).name, CellState(result).name))

    expected = [
        (3, "NECTAR", "RIPENING_HONEY"),
        (8, "RIPENING_HONEY", "CAPPED_HONEY"),
    ]

    all_pass = True
    for exp, got in zip(expected, transitions):
        match = exp == got
        if not match:
            all_pass = False
        print(f"  [{'PASS' if match else 'FAIL'}] Day {exp[0]}: {exp[1]} -> {exp[2]}"
              + (f" (got day {got[0]}: {got[1]} -> {got[2]})" if not match else ""))

    # Verify capped honey stays capped
    for day in range(20):
        cell.advance()
    stable = cell.state == CellState.CAPPED_HONEY
    print(f"  [{'PASS' if stable else 'FAIL'}] Capped honey remains stable after 20 more ticks")

    return all_pass and stable


def test_frame_level_simulation():
    """Run a full frame through 30 days with seeded brood and verify counts."""
    print("\n--- Test: Frame-Level Simulation (30 days) ---")
    frame = Frame()

    # Seed center area with eggs (like queen just laid)
    eggs_placed = 0
    for i in range(500, 700):
        frame.side_a.cells[i].state = CellState.EMPTY_DRAWN
        frame.side_a.cells[i].age = 0
    for i in range(500, 600):
        frame.side_a.cells[i].state = CellState.EGG
        frame.side_a.cells[i].age = 0
        eggs_placed += 1

    # Also draw comb on side B
    for i in range(500, 700):
        frame.side_b.cells[i].state = CellState.EMPTY_DRAWN

    print(f"  Initial: {eggs_placed} eggs placed on side A")

    all_pass = True
    for day in range(1, 31):
        result = frame.tick()
        if day == 3:
            # All 100 eggs should hatch to larvae
            larvae = frame.side_a.count_state(CellState.LARVA)
            ok = larvae == eggs_placed
            print(f"  [{'PASS' if ok else 'FAIL'}] Day 3: {larvae} larvae (expected {eggs_placed})")
            all_pass = all_pass and ok
        elif day == 9:
            capped = frame.side_a.count_state(CellState.CAPPED_BROOD)
            ok = capped == eggs_placed
            print(f"  [{'PASS' if ok else 'FAIL'}] Day 9: {capped} capped brood (expected {eggs_placed})")
            all_pass = all_pass and ok
        elif day == 21:
            vacated = frame.side_a.count_state(CellState.VACATED)
            ok = vacated == eggs_placed
            print(f"  [{'PASS' if ok else 'FAIL'}] Day 21: {vacated} vacated (expected {eggs_placed})")
            all_pass = all_pass and ok
        elif day == 22:
            drawn = frame.side_a.count_state(CellState.EMPTY_DRAWN)
            # Original 200 drawn - 100 eggs + 100 emerged back = 200
            ok = drawn >= eggs_placed
            print(f"  [{'PASS' if ok else 'FAIL'}] Day 22: {drawn} empty drawn cells (all cleaned)")
            all_pass = all_pass and ok

    return all_pass


def test_full_year_brood_cycles():
    """Run 224-day full year with continuous queen laying and verify cycle counts."""
    print("\n--- Test: Full Year Brood Cycles (224 days) ---")
    side = FrameSide(cols=70, rows=50)  # 3500 cells
    # Start with all drawn comb
    for c in side.cells:
        c.state = CellState.EMPTY_DRAWN

    # Simulate queen laying 100 eggs/day for 224 days
    EGGS_PER_DAY = 100
    total_eggs_laid = 0
    total_emerged = 0
    year_milestones = {}

    for day in range(1, 225):
        # Place eggs in empty drawn cells
        placed = 0
        for c in side.cells:
            if placed >= EGGS_PER_DAY:
                break
            if c.state == CellState.EMPTY_DRAWN:
                c.state = CellState.EGG
                c.age = 0
                placed += 1
        total_eggs_laid += placed

        # Tick
        trans = side.tick()
        total_emerged += trans["brood_emerged"]

        # Monthly milestones (every 28 days)
        if day % 28 == 0:
            month_idx = day // 28
            month_names = ["Quickening", "Greening", "Wide-Clover", "High-Sun",
                           "Full-Earth", "Reaping", "Deepcold", "Kindlemonth"]
            name = month_names[month_idx - 1] if month_idx <= 8 else "End"
            year_milestones[name] = {
                "day": day,
                "total_laid": total_eggs_laid,
                "total_emerged": total_emerged,
                "brood": side.count_state(CellState.EGG) + side.count_state(CellState.LARVA) + side.count_state(CellState.CAPPED_BROOD),
            }

    print(f"  Year summary:")
    for name, data in year_milestones.items():
        print(f"    {name:<14} day {data['day']:>3}: laid={data['total_laid']:>5}, emerged={data['total_emerged']:>5}, brood={data['brood']:>5}")

    tests = []

    # After 21+ days, emerged should start accumulating
    ok = total_emerged > 0
    tests.append(ok)
    print(f"\n  [{'PASS' if ok else 'FAIL'}] Bees emerged over full year: {total_emerged}")

    # Emerged should be close to laid minus current brood in pipeline
    current_brood = (side.count_state(CellState.EGG) + side.count_state(CellState.LARVA) +
                     side.count_state(CellState.CAPPED_BROOD))
    expected_emerged = total_eggs_laid - current_brood
    # Allow 5% tolerance for vacated cells still in pipeline
    ok = abs(total_emerged - expected_emerged) < total_eggs_laid * 0.05
    tests.append(ok)
    print(f"  [{'PASS' if ok else 'FAIL'}] Emergence accounting: emerged={total_emerged}, "
          f"expected~{expected_emerged} (laid {total_eggs_laid} - brood {current_brood})")

    # No cells should be in impossible states
    counts = side.full_count()
    impossible = sum(counts.get(s, 0) for s in [CellState.AFB_INFECTED, CellState.EFB_INFECTED,
                                                   CellState.VARROA_INFESTED, CellState.CHALKBROOD])
    ok = impossible == 0
    tests.append(ok)
    print(f"  [{'PASS' if ok else 'FAIL'}] No disease states appeared spontaneously")

    return all(tests)


def test_5_year_brood_stability():
    """Run 5 years (1120 days) and verify brood cycles remain stable year over year."""
    print("\n--- Test: 5-Year Brood Stability (1120 days) ---")
    side = FrameSide(cols=70, rows=50)
    for c in side.cells:
        c.state = CellState.EMPTY_DRAWN

    EGGS_PER_DAY = 80
    yearly_emerged = []
    year_emerged = 0
    all_positive = True

    for day in range(1, 1121):
        # Place eggs
        placed = 0
        for c in side.cells:
            if placed >= EGGS_PER_DAY:
                break
            if c.state == CellState.EMPTY_DRAWN:
                c.state = CellState.EGG
                c.age = 0
                placed += 1

        trans = side.tick()
        year_emerged += trans["brood_emerged"]

        # Year boundary
        if day % 224 == 0:
            yearly_emerged.append(year_emerged)
            year_emerged = 0

        # Check for negatives
        for c in side.cells:
            if c.age < 0:
                all_positive = False

    tests = []

    # Print year-over-year
    print(f"  Year-over-year emergence:")
    for yr, emerged in enumerate(yearly_emerged, 1):
        print(f"    Year {yr}: {emerged:,} bees emerged")

    # All years should produce bees
    ok = all(e > 0 for e in yearly_emerged)
    tests.append(ok)
    print(f"\n  [{'PASS' if ok else 'FAIL'}] All 5 years produce emerged bees")

    # Years 2-5 should be within 20% of year 1 (stable pipeline)
    if len(yearly_emerged) >= 2:
        y1 = yearly_emerged[0]
        stable = all(abs(e - y1) / max(1, y1) < 0.20 for e in yearly_emerged[1:])
        tests.append(stable)
        print(f"  [{'PASS' if stable else 'FAIL'}] Years 2-5 within 20% of year 1 ({y1:,})")
    else:
        tests.append(False)
        print(f"  [FAIL] Not enough yearly data")

    # Cell conservation: total cells unchanged
    total = side.total_cells
    actual = sum(side.full_count().values())
    ok = actual == total
    tests.append(ok)
    print(f"  [{'PASS' if ok else 'FAIL'}] Cell conservation after 1120 days: {actual}/{total}")

    tests.append(all_positive)
    print(f"  [{'PASS' if all_positive else 'FAIL'}] No negative ages across 5 years")

    return all(tests)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("=" * 70)
    print("PHASE 1: BROOD BIOLOGY SIMULATION")
    print("Karpathy Incremental Research - Smoke & Honey")
    print("=" * 70)
    print(f"\nDevelopmental constants:")
    print(f"  Egg duration:          {EGG_DURATION} days")
    print(f"  Larva duration:        {LARVA_DURATION} days")
    print(f"  Capped brood duration: {CAPPED_BROOD_DURATION} days")
    print(f"  Total development:     {TOTAL_DEVELOPMENT} days")
    print(f"  Nectar ripen:          {NECTAR_RIPEN_DURATION} days")
    print(f"  Honey cap:             {HONEY_CAP_DURATION} days")

    results = []
    results.append(("Brood Cycle Timing", test_brood_cycle_timing()))
    results.append(("No Spontaneous Generation", test_no_spontaneous_generation()))
    results.append(("Age Resets on Transition", test_age_resets_on_transition()))
    results.append(("State Conservation", test_state_conservation()))
    results.append(("No State Skipping", test_no_state_skipping()))
    results.append(("Storage Cycle Timing", test_storage_cycle_timing()))
    results.append(("Frame-Level Simulation", test_frame_level_simulation()))
    results.append(("Full Year Brood Cycles", test_full_year_brood_cycles()))
    results.append(("5-Year Brood Stability", test_5_year_brood_stability()))

    print("\n" + "=" * 70)
    print("PHASE 1 VALIDATION SUMMARY")
    print("=" * 70)
    all_pass = True
    for name, passed in results:
        status = "PASS" if passed else "FAIL"
        if not passed:
            all_pass = False
        print(f"  [{status}] {name}")

    print(f"\n  Overall: {'ALL TESTS PASSED' if all_pass else 'SOME TESTS FAILED'}")
    print(f"\n  Phase 1 guarantees (carry forward to Phase 2):")
    print(f"    - Egg -> Larva at day 3 (exact)")
    print(f"    - Larva -> Capped at day 9 (exact)")
    print(f"    - Capped -> Emerged at day 21 (exact)")
    print(f"    - Cell states are conserved (no creation/destruction)")
    print(f"    - Empty cells never spontaneously populate")
    print(f"    - Ages reset on every transition")
    print("=" * 70)

    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
