PHASE 7: COLONY BEHAVIOR & HEALTH
====================================
Maps to: CongestionDetector.gd (Step 7) + HiveHealthCalculator.gd (Step 8)
Script:  colony_behavior_sim.py
Dependencies: NONE (standalone validation)

WHAT THIS PHASE VALIDATES
-------------------------
The "judgment" systems that evaluate colony state:
  - Congestion detection: 4 states (NORMAL, BROOD_BOUND, HONEY_BOUND, FULLY_CONGESTED)
    * Honey-bound threshold: 62% of cells are honey/nectar
    * Brood-bound threshold: 65% of cells are brood
    * Swarm prep: 78% total occupancy
  - Swarm impulse: accumulates after 7+ consecutive congested ticks
  - Composite health score (0-100) with weighted components:
    * Population: 25%
    * Brood pattern: 25%
    * Stores: 20%
    * Queen quality: 20%
    * Varroa load: 10%
  - Queen supersedure conditions

HOW TO RUN
----------
1. Open PowerShell in this folder
2. Run: .\run.ps1
   (or: python colony_behavior_sim.py)

WHEN TO STOP AND MOVE ON
-------------------------
STOP when all 7 tests pass:
  - Health Score Weights (sum to 1.0)
  - Health Score Bounds (always 0-100)
  - Congestion Detection (correct thresholds)
  - Swarm Impulse Timing (requires 7+ ticks)
  - Healthy Colony Range (score 60-85)
  - Struggling Colony Low (< 40)
  - Component Independence (each weight contributes correctly)

These are deterministic evaluation checks. The congestion
detector and health calculator are pure functions of colony
state -- no stochastic variance to worry about.

MOVE TO PHASE 8:
  cd ..\phase8_full_integration
  .\run.ps1

WHAT THIS CARRIES FORWARD
--------------------------
Phase 8 will trust that:
  - Congestion thresholds are correctly calibrated
  - Health score weights match the GDD
  - Swarm impulse requires sustained congestion
  - No impossible health states (always 0-100)
