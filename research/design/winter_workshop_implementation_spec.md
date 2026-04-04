# Winter Workshop - Implementation Spec
**Status:** APPROVED - ready for implementation
**Date:** April 4, 2026
**Scope:** Only items marked SETTLED below. Items marked PENDING require further design and must NOT be implemented yet.
---
## How to use this document
Each section has a status: SETTLED (implement now) or PENDING (do not implement). Cowork should work through SETTLED items in the order listed. Each item includes the specific files/systems affected and the expected behavior.
**CRITICAL: Every code change must be accompanied by updates to the three guiding documents.** After implementing each section, update the relevant portions of:
1. `Smoke_and_Honey_GDD.html` - game systems, mechanics, item tables, quest definitions
2. `story_bible.html` - NPC quest chains, dialogue references, narrative beats
3. The art asset spreadsheet in the project root - new sprites, UI elements, animation states
See Section 8 below for specific documentation requirements per section.
---
## 1. SETTLED - Transition month clarification
Each season has two months. The first is the **transition month** (shift from previous season), the second is the **true season month**.
| Season | Month 1 (Transition) | Month 2 (True) |
|--------|---------------------|----------------|
| Spring | Quickening (Days 1-28) - transition from winter | Greening (Days 29-56) - true spring |
| Summer | Wide-Clover (Days 57-84) - transition from spring | High-Sun (Days 85-112) - true summer |
| Fall | Full-Earth (Days 113-140) - transition from summer | Reaping (Days 141-168) - true fall |
| Winter | Deepcold (Days 169-196) - transition from fall | Kindlemonth (Days 197-224) - true winter |
### Action items
- [ ] Update `scripts/autoloads/TimeManager.gd` to include a `is_transition_month() -> bool` helper function and a `get_season_phase() -> String` that returns "early" or "true"
- [ ] Audit all NPC dialogue files for month/season references and update to use the correct transition/true terminology where it matters narratively
- [ ] Update notification text that references seasons to be aware of the distinction where relevant
- [ ] No gameplay mechanical changes - this is a narrative/flavor distinction, not a system gate
