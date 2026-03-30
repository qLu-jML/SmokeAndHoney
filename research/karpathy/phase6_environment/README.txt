PHASE 6: ENVIRONMENTAL SYSTEMS
================================
Maps to: scripts/autoloads/WeatherManager.gd + scripts/world/flower_lifecycle_manager.gd
Script:  environment_sim.py
Dependencies: NONE (standalone validation)

WHAT THIS PHASE VALIDATES
-------------------------
The external environment driving colony behavior:
  - Iowa weather: 8 states (clear, cloudy, rain, storm, fog, snow)
    with season-specific probability tables
  - 7 Iowa-native flower species with bloom windows:
    Dandelion (earliest) -> White Clover -> Black Locust -> Basswood ->
    Prairie Clover -> Goldenrod -> Aster (latest)
  - 5-phase flower lifecycle: SEED -> SPROUT -> GROWING -> MATURE -> WITHERED
  - Season ranking (S/A/B/C/D/F) for year-to-year variety
  - Forage availability = flowers * weather * rank

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python environment_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when all 8 tests pass:
  - Bloom Season Coverage (no summer gaps)
  - Bloom Order (Dandelion first, Aster last)
  - Rank Probabilities Sum to 1.0
  - Rank Density Ordering (S > A > B > C > D > F)
  - Weather Stops Foraging (rain, storm, snow = 0)
  - Winter No Forage (Deepcold + Kindlemonth = 0)
  - Flower Lifecycle Phases (each species hits 4+ phases)
  - Full Year Forage Curve (peak in summer, dead in winter)

IMPORTANT: This phase's forage output is what Phase 8 uses for
the integrated simulation. If you change bloom windows or forage
yields here, Phase 8 results will change too. The Phase 3 "simple
mock" was tuned to match the game's current ForageManager -- this
phase validates the REAL flower system which is more conservative.

MOVE TO PHASE 7:
  cd ..\phase7_colony_behavior
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 8 will trust that:
  - Iowa bloom calendar has no summer gaps
  - Weather correctly modulates foraging
  - Season ranking provides realistic variety
  - Winter = zero forage
