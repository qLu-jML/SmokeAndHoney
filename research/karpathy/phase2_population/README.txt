PHASE 2: POPULATION DYNAMICS
=============================
Maps to: scripts/simulation/PopulationCohortManager.gd
Script:  population_sim.py
Dependencies: Phase 1 (brood_sim.py)

WHAT THIS PHASE VALIDATES
-------------------------
Adult bee cohort lifecycle on top of Phase 1's brood pipeline:
  emerged brood -> nurse (12 days) -> house bee (12 days) -> forager -> death

Key dynamics:
  - Summer worker lifespan: ~35 days total as adult
  - Winter (diutinus) bees: ~125-180 day lifespan
  - Forager mortality: 5.5%/day (~18-day forager lifespan)
  - Drones expelled in fall, return in spring
  - Nurse ratio feedback: low nurses = delayed capping

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python population_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when these tests pass:
  - 365-Day Population Curve (peak 40-65k, winter min 8-28k)
  - Nurse Ratio Feedback (low nurses causes delay)
  - Drone Seasonal Expulsion
  - Emergence Feeds Population

NOTE: The "peak month" sub-check may flag Full-Earth instead of
High-Sun. This is acceptable -- Full-Earth is late summer and within
the biological range. The important thing is peak adults hitting 40-65k.

MOVE TO PHASE 3:
  cd ..\phase3_foraging_honey
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 3 will trust that:
  - Summer peak: 40,000-65,000 adults
  - Winter minimum: 8,000-28,000 adults
  - Nurse ratio feedback loop is working
  - Drones are seasonal
  - No negative populations anywhere
