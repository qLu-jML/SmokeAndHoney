PHASE 3: FORAGING & HONEY ECONOMY
===================================
Maps to: scripts/simulation/ForagerSystem.gd + NectarProcessor.gd
Script:  foraging_sim.py
Dependencies: Phase 1 (brood) + Phase 2 (population)

WHAT THIS PHASE VALIDATES
-------------------------
The resource economy layer:
  foragers collect nectar -> nectar processed to honey -> consumption

Key constants:
  - 5:1 nectar-to-honey ratio (nectar is 80% water, honey is 18%)
  - Forager collects ~0.000882 lbs nectar/day (~40mg/trip x 11 trips)
  - Winter consumption: fixed overhead model (cluster heating)
  - Summer consumption: 0.000015 lbs/bee/day

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python foraging_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when these core tests pass:
  - Nectar-to-Honey Ratio (must be exact: 5:1)
  - Forager Collection Rate (within 30% of science)
  - Winter Consumption Model (fixed overhead)
  - 365-Day Honey Economy:
      * Annual production: 150-450 lbs (MUST pass)
      * Harvest: 40-120 lbs (MUST pass)
      * Winter consumption: 20-45 lbs (SHOULD pass, tuning area)
      * No negative honey (MUST pass)

KNOWN TUNING AREA: The winter consumption test uses a simplified
seasonal forage mock. When Phase 8 integrates the real flower system
(Phase 6), forage yields are lower, which changes the economy. This
is expected -- fix it here first with the simple mock, then recalibrate
in Phase 8.

MOVE TO PHASE 4:
  cd ..\phase4_queen_comb
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 4 and beyond will trust that:
  - 5:1 nectar-to-honey conversion is correct
  - Forager collection rate matches science
  - Winter consumption model is thermally realistic
  - Honey stores never go negative
