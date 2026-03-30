PHASE 5: DISEASE & PEST DYNAMICS
==================================
Maps to: CellStateTransition.gd (disease states) + HiveSimulation.gd (mites)
Script:  disease_sim.py
Dependencies: NONE (standalone validation)

WHAT THIS PHASE VALIDATES
-------------------------
The disease/pest layer that can collapse colonies:
  - Varroa destructor: exponential reproduction in capped brood
    * Growth rate: 1.7%/day * brood availability
    * Doubling time: 40-70 days at moderate infestation
    * #1 colony killer worldwide
  - American Foulbrood (AFB): bacterial, spreads cell-to-cell
    * 1.2% per neighbor per tick, radius 1
    * Only infects brood cells (not honey/empty)
  - European Foulbrood (EFB): less severe, can self-cure
    * 4% mortality/day, 30% self-cure with good conditions
  - Treatment model: formic acid, oxalic acid, apivar, thymol

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python disease_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when all 6 tests pass:
  - Varroa Doubling Time (40-70 days)
  - Untreated Colony Trajectory (reaches critical within a year)
  - Treatment Effectiveness (each treatment matches stated %)
  - AFB Spread Rate (~1.2% per neighbor, stochastic so allow variance)
  - EFB Self-Cure (infected count decreases with good conditions)
  - No Negative Mites (even after double treatment)

The AFB test uses 1000 trials to average out stochastic variance.
If it fails by a small margin, the spread chance constant may need
a tiny adjustment.

MOVE TO PHASE 6:
  cd ..\phase6_environment
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 8 will trust that:
  - Varroa growth is biologically calibrated
  - Disease spread mechanics are correct
  - Treatments work at stated efficacy
  - No impossible disease states
