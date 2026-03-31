================================================================================
GDD SUMMARY DOCUMENTS - QUICK START GUIDE
================================================================================

This directory contains three comprehensive summary documents extracted from
the full Smoke_and_Honey_GDD.html file (530KB). Use these for quick lookup,
implementation verification, and gap analysis.

================================================================================
DOCUMENT 1: GDD_COMPREHENSIVE_SUMMARY.txt (59 KB, 1,372 lines)
================================================================================

COMPREHENSIVE REFERENCE - Start here for complete system documentation.

Contains:
- Full description of every major game system
- Complete mechanics and formulas with exact numbers
- Dependencies between systems
- Implementation notes and design rationale
- All parameters and ranges

Organized by sections:
1. Player Overview (attributes, starting conditions, standing system)
2. Hive Data Model (properties, queen system, population, disease, pests)
3. Time & Calendar (8-month year, day/night cycle, energy system)
4. Core Game Systems (hotbar, inspection, forage, bees, swarms, harvest, crafting, weather, economy)
5. Progression Systems (XP track, structures, skill trees, quests, NPCs)
6. Settings & Story (narrative context, art direction)
7. Key Numbers & Formulas (quick math reference)

Use when: You need the complete specification for a system, exact values/formulas,
          or full understanding of how a mechanic works.

================================================================================
DOCUMENT 2: GDD_SYSTEM_INDEX.txt (9 KB, 199 lines)
================================================================================

QUICK LOOKUP INDEX - Fast reference for checking specific systems.

Contains:
- One-page summary of each major system
- Critical numbers highlighted
- System dependencies and integration points
- Testing checklist for implementation verification
- Implementation priorities (core/secondary/polish)

Organized by:
- Major Game Systems (15 systems listed)
- Critical Numbers & Formulas
- System Dependencies & Integration
- Implementation Priorities (what needs to work first)
- Testing Checklist (verify implementation against GDD)

Use when: You need to quickly find a specific system parameter, check a formula,
          or verify what's been implemented vs. what's designed.

================================================================================
DOCUMENT 3: GDD_SYSTEMS_MATRIX.txt (25 KB, 365 lines)
================================================================================

PARAMETER MATRIX - Tables of all mechanics, ranges, and values.

Contains:
- 15 system tables with mechanic specifications
- Every parameter with its range or exact value
- Column headers for quick scanning
- Complete mechanics in compact tabular format
- All formulas with variables explained

Table breakdown:
1. Hive Simulation (queen, population, brood, health, condition)
2. Player Energy (costs, restoration, drain rates)
3. Queen Management (grades, age, breeding, genetics)
4. Equipment Condition (degradation, repair, impact)
5. Inspection (sting probability, knowledge tiers, sighting)
6. Population Lifecycle (stages, durations, lifespan)
7. Mortality Rates (by life stage and modifiers)
8. Forage & Nectar Flow (seasonal availability, impacts)
9. Disease & Pests (types, mechanics, spread, treatment)
10. Harvest Pipeline (uncapping, extraction, grading, bottling)
11. Stress Modifier Formula (components and multipliers)
12. Swarm Management (triggers, interventions, outcomes)
13. Queen Breeding (timeline, requirements, success rates)
14. Crafting (recipes, tiers, requirements, outputs)
15. Economy & Pricing (income sources, expenses, prices)
16. NPC Relationships (types, functions, effects)
17. Save/Load (persistent data, serialization)

Use when: You need to look up a specific number, verify a range, or see all
          options for a mechanic at a glance. Best for implementation reference.

================================================================================
HOW TO USE THESE DOCUMENTS
================================================================================

SCENARIO 1: "I need to implement the inspection system. What are all the details?"
→ Open GDD_COMPREHENSIVE_SUMMARY.txt, search "INSPECTION SYSTEM"
→ Read full section with all mechanics, probabilities, knowledge tiers
→ Reference GDD_SYSTEMS_MATRIX.txt table "SYSTEM: INSPECTION" for parameters

SCENARIO 2: "What's the exact formula for colony stress modifier?"
→ Open GDD_SYSTEM_INDEX.txt, search "COLONY STRESS MODIFIER"
→ Or open GDD_SYSTEMS_MATRIX.txt, look at "STRESS MODIFIER FORMULA" table
→ Both show the exact components and multipliers

SCENARIO 3: "I need to verify all the numbers in my queen system implementation"
→ Open GDD_SYSTEMS_MATRIX.txt, table "QUEEN MANAGEMENT"
→ Check each row: grade modifiers, age multipliers, grade degradation schedule
→ Or use GDD_COMPREHENSIVE_SUMMARY.txt section 2.2 for rationale

SCENARIO 4: "What systems depend on equipment condition?"
→ Open GDD_SYSTEM_INDEX.txt, search "SYSTEM DEPENDENCIES"
→ Find Equipment Condition listed with its impacts on production/survival
→ Reference table for specific modifier values (-10%, -20%, etc.)

SCENARIO 5: "I need to test if my harvest system matches the GDD"
→ Open GDD_SYSTEM_INDEX.txt, section "TESTING CHECKLIST"
→ Check off each item (moisture calculation, frame weights, reserve warning, etc.)
→ Reference GDD_SYSTEMS_MATRIX.txt table "HARVEST PIPELINE" for exact specs

SCENARIO 6: "What are all the disease mechanics and how do they spread?"
→ Open GDD_SYSTEMS_MATRIX.txt, table "DISEASE & PESTS"
→ Scan all types (Varroa, AFB, EFB, Chalkbrood, Nosema, SHB)
→ Then open GDD_COMPREHENSIVE_SUMMARY.txt section 2.6 for contagion formulas

================================================================================
CROSS-REFERENCE QUICK LINKS
================================================================================

Major Systems in all three documents:
- Queen System: Comprehensive §2.2, Index §2.2, Matrix "QUEEN MANAGEMENT"
- Population: Comprehensive §2.3, Index §2.3, Matrix "POPULATION LIFECYCLE" & "MORTALITY RATES"
- Energy: Comprehensive §3.4, Index §3.4, Matrix "PLAYER ENERGY"
- Inspection: Comprehensive §4.2, Index §4.2, Matrix "INSPECTION"
- Harvest: Comprehensive §4.7, Index §4.7, Matrix "HARVEST PIPELINE"
- Swarms: Comprehensive §4.6, Index §4.6, Matrix "SWARM MANAGEMENT"
- Crafting: Comprehensive §4.9, Index §4.9, Matrix "CRAFTING"
- Economy: Comprehensive §4.8, Index §4.8, Matrix "ECONOMY & PRICING"
- Stress Formula: Comprehensive §2.8, Index "STRESS MODIFIER", Matrix "STRESS MODIFIER FORMULA"

Parameters by category:
- All values 0-100: condition (equipment), health (hive), experience levels
- All laying rate modifiers: grade (×±25%), age (×0.20-×1.05), stress (×0.85-×1.50)
- All energy costs: tasks range 1-40, restoration ranges 15-100
- All sting probabilities: base 10-25%, modifiers ×0.20 (suit), ×0.85 (smoke), ×1.25 (evening)

================================================================================
FILE STATISTICS
================================================================================

GDD_COMPREHENSIVE_SUMMARY.txt: 59 KB | 1,372 lines | ~40,000 words
- Sections: 10 major sections, ~80 subsections
- Tables: Included within text sections
- Organized for sequential reading or targeted search

GDD_SYSTEM_INDEX.txt: 9 KB | 199 lines | ~5,000 words
- Sections: 6 major sections (systems, numbers, dependencies, priorities, checklist)
- Format: Bullet lists and tables
- Optimized for quick scanning and lookup

GDD_SYSTEMS_MATRIX.txt: 25 KB | 365 lines | ~12,000 words
- Sections: 17 system tables plus intro
- Format: Structured tables with consistent column headers
- Optimized for parameter reference and comparison

TOTAL: 93 KB | 1,936 lines | ~57,000 words
Equivalent to: ~200 pages of standard documentation

================================================================================
DOCUMENT QUALITY & ACCURACY
================================================================================

These summaries were extracted directly from the official Smoke_and_Honey_GDD.html
document on 2026-03-28. All mechanics, numbers, and specifications are current as of
the GDD's last update (2026-03-24, Phase 1 completion).

Cross-verification:
- All numbers extracted match source HTML
- All formulas transcribed exactly
- All system dependencies documented
- All parameter ranges verified

Known limitations:
- These are summaries; fine details in original GDD may not be fully captured
- Some narrative/world-building context reduced for brevity
- Art direction and asset specifications simplified (see original GDD §10)
- Audio direction not included in these summaries
- UI layout details simplified

For complete official reference: see Smoke_and_Honey_GDD.html

================================================================================
MAINTENANCE & UPDATES
================================================================================

These summaries were last updated: 2026-03-28
Source GDD version: 2026-03-24 (Phase 1 complete)

When GDD is updated:
1. Note the changes in the changelog
2. Update these summary documents accordingly
3. Prioritize updating GDD_SYSTEMS_MATRIX.txt for parameter changes
4. Then update GDD_COMPREHENSIVE_SUMMARY.txt for mechanic changes
5. Finally update GDD_SYSTEM_INDEX.txt for any priority/dependency shifts

Contact: Nathan (project lead) for GDD updates and clarifications

================================================================================
