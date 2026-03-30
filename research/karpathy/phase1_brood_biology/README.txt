PHASE 1: BROOD BIOLOGY
======================
Maps to: scripts/simulation/CellStateTransition.gd
Script:  brood_sim.py
Dependencies: NONE (this is the foundation phase)

WHAT THIS PHASE VALIDATES
-------------------------
The brood development pipeline in pure isolation:
  egg (3 days) -> larva (6 days) -> capped brood (12 days) -> emerged adult
  Total: 21 days from egg to bee (matches Winston 1987)

Also validates: nectar -> ripening honey -> capped honey timing,
cell state conservation, and no spontaneous generation.

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python brood_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when: All 7 tests show [PASS]
  - Brood Cycle Timing
  - No Spontaneous Generation
  - Age Resets on Transition
  - State Conservation
  - No State Skipping
  - Storage Cycle Timing
  - Frame-Level Simulation

If ANY test shows [FAIL]:
  - Read the failure message to understand what went wrong
  - Adjust the constants or logic in brood_sim.py
  - Re-run until all pass
  - Do NOT move to Phase 2 with failures here -- every later
    phase depends on these guarantees

MOVE TO PHASE 2:
  cd ..\phase2_population
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 2 will IMPORT brood_sim.py and trust that:
  - 21-day development cycle is exact
  - Cell states are conserved
  - Empty cells never spontaneously populate
  - Ages reset on every transition
