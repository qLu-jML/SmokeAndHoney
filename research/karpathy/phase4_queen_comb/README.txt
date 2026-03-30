PHASE 4: QUEEN & COMB MECHANICS
=================================
Maps to: scripts/simulation/QueenBehavior.gd + NurseSystem.gd
Script:  queen_comb_sim.py
Dependencies: NONE (standalone math validation)

WHAT THIS PHASE VALIDATES
-------------------------
Queen intelligence and comb building:
  - Queen grade system: S(1.25x) A(1.0x) B(0.95x) C(0.80x) D(0.60x) F(0x)
  - Queen age curve: peak at year 2, declining after
  - Grade degradation over time (S->A at 18 months, etc.)
  - Laying rate modifiers: season, congestion, varroa stress, forage stress
  - Comb drawing: scales with population + honey + forage
  - 3D ellipsoid brood nest pattern (center frames get more brood)

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python queen_comb_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when all 6 tests pass:
  - Grade Multipliers (must match GDD exactly)
  - Queen Age Curve (peak year 2)
  - Laying Respects Space (never overfills)
  - Comb Drawing Dynamics (stops below 3 lbs honey)
  - Brood Nest Ellipsoid (center < outer distance)
  - Congestion Reduces Laying (NORMAL > BROOD_BOUND > FULLY_CONGESTED)

These are all deterministic math checks -- they either pass or the
constants are wrong. No stochastic variation to worry about.

MOVE TO PHASE 5:
  cd ..\phase5_disease_pests
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 5+ will trust that:
  - Queen grade multipliers are correct
  - Laying rate respects all stress modifiers
  - Comb drawing has proper honey/population/forage gates
  - Brood nest pattern is biologically plausible
