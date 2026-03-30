PHASE 8: FULL INTEGRATION + KARPATHY RESEARCH LOOP
=====================================================
Maps to: HiveSimulation.gd (complete 10-step pipeline)
Dependencies: ALL phases 1-7 (imports from sibling directories)

FILES IN THIS FOLDER
--------------------
  full_sim.py        The 365-day two-hive integration test (15 tests)
  research_loop.py   Structured tuning reports for AI-assisted research
  CONTEXT.md         Complete reference document with all constants,
                     validation targets, calibration issues, and tuning
                     strategy. Feed this to your AI as context.
  run.ps1            Launcher with multiple modes (see below)
  README.txt         This file
  baseline.json      Auto-created when you save a baseline

HOW TO RUN
----------
Default (full simulation with detailed output):
  .\run.ps1

Research loop (structured report for AI analysis):
  .\run.ps1 loop

Save a baseline before making changes:
  .\run.ps1 baseline

After making changes, compare to baseline:
  .\run.ps1 compare

Show all current tunable constants:
  .\run.ps1 constants

Show what constants changed since baseline:
  .\run.ps1 diff

AI-ASSISTED KARPATHY RESEARCH LOOP
-------------------------------------
This is the workflow for using an AI (Ollama, Claude, etc.) to
iteratively tune the simulation constants:

  1. CONTEXT: Give CONTEXT.md to your AI as the system prompt or
     initial context. It has every constant, every test target,
     every known issue, and the tuning strategy.

  2. BASELINE: Run .\run.ps1 baseline to capture current state.

  3. REPORT: Run .\run.ps1 loop and paste the output to the AI.
     The report shows every test with pass/fail, the gap from
     target, which phase to fix, and a monthly breakdown.

  4. ASK: Tell the AI "suggest constant changes to fix the
     earliest-phase failures". It will know from CONTEXT.md
     which constants to adjust and by how much.

  5. APPLY: Make the suggested change in the source phase file.
     For example, if the AI says to increase NECTAR_PER_FORAGER,
     edit ../phase3_foraging_honey/foraging_sim.py.

  6. VALIDATE SOURCE: Run that phase's own tests first:
       cd ..\phase3_foraging_honey
       python foraging_sim.py
     All tests must still pass. If not, the change was too big.

  7. RE-TEST: Come back and compare:
       cd ..\phase8_full_integration
       .\run.ps1 compare
     This shows which tests improved, regressed, or stayed same.

  8. REPEAT: Paste the new report to the AI. Loop until all 15
     tests pass. Each iteration should fix the earliest failing
     subsystem first (Karpathy method).

WHEN TO STOP
------------
This is the FINAL phase. Work here until all 15 tests pass:

  Population:   Summer peak 40-65k, winter min 8-28k (both hives)
  Honey:        Annual production 150-450 lbs, harvest 40-120 lbs
  Winter:       Consumption 20-45 lbs
  Varroa:       Doubling time 40-70 days
  Divergence:   Two hives differ 8-30%
  Seasonal:     Peak in summer months
  Integrity:    No negative/NaN values
  Health:       Summer avg > 50

CURRENT STATUS: 1/15 tests passing

The individual phases all pass their own tests, but when
combined, calibration between systems needs tuning.
See CONTEXT.md for the specific issues and fix strategy.
