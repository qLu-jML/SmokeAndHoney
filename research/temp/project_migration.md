# Smoke & Honey - Project Migration File

> **Purpose:** Paste this into the first message of your new Cowork project so Claude can restore
> your scheduled tasks, memories, and settings. Once everything is restored, you can delete this file.
>
> **Instructions:**
> 1. Create a new Cowork project
> 2. Select ONLY the SmokeAndHoney folder
> 3. Paste everything below the line into your first message
> 4. Claude will recreate all scheduled tasks and memory files

---

## RESTORE REQUEST

Please restore my project from the old "Smoke and Honey OLD" Cowork session. Recreate all scheduled tasks and memory files listed below exactly as specified.

---

## SCHEDULED TASKS TO RECREATE (14 total, 10 enabled / 4 disabled)

### 1. ks-promo-morning (ENABLED)
- **Description:** Morning Kickstarter promo tweet + indie dev engagement on X
- **Cron:** `30 8 * * *` (daily at 8:32 AM)
- **Jitter:** 111 seconds

### 2. ks-promo-afternoon (DISABLED)
- **Description:** DISABLED -- reduced to 2 promos/day (morning + evening). Disabled 2026-04-02.
- **Cron:** `0 13 * * *` (daily at 1:06 PM)
- **Jitter:** 342 seconds

### 3. ks-promo-evening (ENABLED)
- **Description:** Evening cozy-vibes Kickstarter promo tweet on X
- **Cron:** `0 19 * * *` (daily at 7:08 PM)
- **Jitter:** 475 seconds

### 4. x-daily-dev-update (ENABLED)
- **Description:** Daily dev update tweet with Kickstarter CTA on X
- **Cron:** `0 10 * * *` (daily at 10:10 AM)
- **Jitter:** 593 seconds

### 5. fc-daily-briefing (DISABLED)
- **Description:** DISABLED -- merged into fc-daily-report (yesterday summary + today's goals). Disabled 2026-04-02.
- **Cron:** `0 6 * * *` (daily at 6:08 AM)
- **Jitter:** 466 seconds

### 6. fc-daily-cleanup (ENABLED)
- **Description:** End-of-day cleanup, file integrity check, and Godot engine health check
- **Cron:** `45 23 * * *` (daily at 11:53 PM)
- **Jitter:** 478 seconds

### 7. fc-daily-report (ENABLED)
- **Description:** Daily development report for Five Cats Studios + auto-email via Buttondown to 5 addresses
- **Cron:** `0 8 * * *` (daily at 8:03 AM)
- **Jitter:** 172 seconds

### 8. fc-newsletter (ENABLED)
- **Description:** Weekly Five Cats Studios newsletter via Buttondown (Mondays)
- **Cron:** `0 9 * * 1` (Mondays at 9:02 AM)
- **Jitter:** 146 seconds

### 9. nfai-morning-engagement (ENABLED)
- **Description:** NearFutureAI morning engagement on X
- **Cron:** `0 9 * * *` (daily at 9:05 AM)
- **Jitter:** 282 seconds

### 10. nfai-afternoon-content (ENABLED)
- **Description:** NearFutureAI afternoon content post on X
- **Cron:** `0 13 * * *` (daily at 1:02 PM)
- **Jitter:** 134 seconds

### 11. nfai-evening-engagement (DISABLED)
- **Description:** DISABLED -- reduced to 2 posts/day (morning + afternoon). Disabled 2026-04-02.
- **Cron:** `0 19 * * *` (daily at 7:05 PM)
- **Jitter:** 290 seconds

### 12. nfai-weekly-analytics (ENABLED)
- **Description:** NearFutureAI weekly analytics review (Sundays)
- **Cron:** `0 10 * * 0` (Sundays at 10:00 AM)
- **Jitter:** 5 seconds

### 13. sh-daily-content (ENABLED)
- **Description:** SpaceHistorian daily space history content creation
- **Cron:** `0 8 * * *` (daily at 8:03 AM)
- **Jitter:** 208 seconds

### 14. fc-website-update (ENABLED)
- **Description:** Daily website devlog update + Firebase deploy for Five Cats Studios
- **Cron:** `30 7 * * *` (daily at 7:38 AM)
- **Jitter:** 505 seconds

---

## MEMORY FILES TO RECREATE (7 total)

### Memory 1: user_role.md
```markdown
---
name: user_role
description: Nathan is a hospice chaplain considering going full-time on game development. Wife works and would continue working.
type: user
---

Nathan is a hospice chaplain by profession. He is considering leaving his chaplaincy role to go full-time on Smoke & Honey game development. His wife works and would continue her job to provide household income during the transition. He has deep domain knowledge in beekeeping (intermediate-to-advanced level). He is a self-taught game developer using Godot 4.6 and GDScript. His development pace is extremely high-intensity (137 changelog entries in 3 days, 15,400+ lines of code in 6 days).
```

### Memory 2: project_game_name.md
```markdown
---
name: Game name decision
description: The game has been renamed from "BeeKeeper Pro" to "Smoke & Honey" for marketing/branding advantage
type: project
---

Game renamed from "BeeKeeper Pro" to **Smoke & Honey** on 2026-03-24.

**Why:** "BeeKeeper Pro" conflicted with existing Steam titles (Beekeeper, Beekeeper Simulator, Boss Beek) and sounded like productivity software. "Smoke & Honey" is unique on Steam, evocative, and signals craft/authenticity. The bee smoker is the most iconic beekeeping tool and honey is the universal reward.

**How to apply:** Use "Smoke & Honey" as the game title in all references, UI, branding, and marketing materials. Update title screens, window titles, and any in-game references to the game name. Tagline candidates: "Tend. Harvest. Thrive." / "Every frame tells a story." / "The craft of keeping bees."
```

### Memory 3: project_repo_migration.md
```markdown
---
name: project_repo_migration
description: Project migrated to SmokeAndHoney GitHub repo with reorganized file structure
type: project
---

Project moved from beekeeperPro/ to SmokeAndHoney/ GitHub repository (qLu-jML/SmokeAndHoney) on 2026-03-25.

**Why:** Full rebrand from "BeeKeeper Pro" to "Smoke & Honey" with proper version control via GitHub.

**How to apply:**
- The working directory is now SmokeAndHoney/, not beekeeperPro/
- Git commits should be made at natural stopping points (features, fixes, before risky refactors)
- Non-game files go in research/ subdirectories: design/, art/, reports/, archive/, reference/, queenFinder/, temp/
- Project root should only contain game-essential files (project.godot, assets/, scenes/, scripts/, resources/, tools/, CLAUDE.md, changelog.txt, and the two protected HTML docs)
- Protected docs are now Smoke_and_Honey_GDD.html and Smoke_and_Honey_DevPlan.html
- "The Beekeeper" NPC name and skill names ("Beekeeper", "Master Beekeeper") are intentionally kept
```

### Memory 4: feedback_file_organization.md
```markdown
---
name: feedback_file_organization
description: Nathan wants non-game files in research/ and temp files in research/temp/
type: feedback
---

Keep the project root clean -- only game-essential files belong there. All research, reports, design docs, art references, and temporary files should go in the appropriate research/ subdirectory.

**Why:** Nathan explicitly asked for this organization on 2026-03-25 to keep the game project clean and professional.

**How to apply:** When creating any file that isn't directly part of the Godot game (scripts, scenes, assets, resources), place it in the correct research/ subfolder. Use research/temp/ for scratch/temporary files.
```

### Memory 5: project_grid_size.md
```markdown
---
name: project_grid_size
description: Smoke & Honey now uses 32x32 tile grid (upgraded from 16x16)
type: project
---

The project tile grid has been upgraded from 16x16 to 32x32.

**Why:** Allows more detail per tile while maintaining the pixel art style.

**How to apply:** All art generation prompts, sprite references, and tile-related work should reference 32x32 grid. The GDD master prompt block still says 16x16 -- the actual working value is 32x32.
```

### Memory 6: feedback_leonardo_workflow.md
```markdown
---
name: feedback_leonardo_workflow
description: Leonardo AI workflow preferences - reference collection for cohesion, get perspective right first try, use GDD style guide
type: feedback
---

When generating art in Leonardo AI for Smoke & Honey:
1. Always reference the "Smoke and Honey" collection to maintain visual cohesiveness across generated assets
2. Get the perspective correct from the FIRST prompt - use the GDD style guide (section 10.1) for palette and art direction
3. Use 32x32 tile grid (not 16x16) in prompts
4. The correct perspective keywords: "front-facing view with camera directly in front, facade faces viewer straight on, NO side walls visible, NOT isometric, roof extends away from viewer toward top of image showing shingle texture from above, front wall is a flat strip at bottom of sprite"
5. Show each generation for Nathan's approval before he adds to collection
6. Use the GDD Master Prompt Block as the base template

**Why:** Credits are limited (free tier), so getting it right the first time matters. Nathan curates what goes into the collection himself.

**How to apply:** Before every Leonardo generation, load the master prompt template with GDD-accurate palette terms. Reference the collection for style consistency. Present each result for approval.
```

### Memory 7: user_ollama_setup.md
```markdown
---
name: Local Ollama models
description: Nathan runs Ollama locally with qwen2.5-coder:7b and llama3.2:3b for local AI tasks
type: user
---

Nathan has Ollama installed locally with two models:
- qwen2.5-coder:7b (4.7 GB) -- code-focused model, good for code analysis
- llama3.2:3b (2.0 GB) -- general lightweight model

These are available for local inference tasks alongside the project work.
```

### Memory 8: project_harvest_loop_design.md
```markdown
---
name: Level 1 Harvest Loop Design
description: Nathan's confirmed design for the Level 1 harvest pipeline - batch spinner, no grading, new station names
type: project
---

Level 1 harvest loop confirmed by Nathan (2026-03-28). Differs from GDD in several ways:

**Flow:**
1. Player removes marked super from hive -> ITEM_FULL_SUPER
2. Takes super to **Super Prep Area** (NEW station in honey house) - breaks super into individual frames, loads into Frame Holder
3. **Frame Holder** (NEW station) - holds frames ready for uncapping
4. **Uncapping Station** - de-cap each frame with tool, flip to do both sides. When satisfied, click button to drop into spinner
5. **Honey Spinner** - batch extractor, holds 10 frames (full super). Player repeatedly presses E for 20 seconds to extract honey into white bucket
6. **Canning Table** (NEW station name, was "Bottling Station") - player has empty jars in inventory, presses E to fill jars. Produces 1 lb honey jars

**Key design decisions:**
- Batch spinner (all 10 frames at once) instead of GDD's 1-at-a-time
- No grading at Level 1 - all honey is Standard grade. Grading unlocks later
- Super Prep Area and Frame Holder are new dedicated stations (not just renaming existing GDD concepts)
- "Canning Table" replaces "Bottling Station" terminology
- 1 lb jars to start

**Why:** Nathan wants a streamlined, physical-feeling loop for Level 1 without the complexity of moisture grading. Grading comes later as progression.

**How to apply:** When implementing Phase 2 harvest pipeline, follow this flow instead of the GDD's Tier 0 manual equipment flow. The GDD's grading system, moisture calculations, and varietal tracking still apply but unlock at higher levels.
```

---

## MEMORY INDEX (MEMORY.md)

```markdown
# Memory Index

- [user_role.md](user_role.md) -- Nathan is a hospice chaplain, wife works, considering full-time game dev

- [project_game_name.md](project_game_name.md) -- Game renamed from "BeeKeeper Pro" to "Smoke & Honey" (2026-03-24)
- [project_repo_migration.md](project_repo_migration.md) -- Project migrated to SmokeAndHoney GitHub repo with reorganized file structure (2026-03-25)
- [feedback_file_organization.md](feedback_file_organization.md) -- Non-game files go in research/, temp files in research/temp/
- [project_grid_size.md](project_grid_size.md) -- Tile grid upgraded from 16x16 to 32x32
- [feedback_leonardo_workflow.md](feedback_leonardo_workflow.md) -- Leonardo AI workflow: reference collection, GDD style guide, 32x32 grid, approve before adding
- [user_ollama_setup.md](user_ollama_setup.md) -- Nathan runs Ollama locally with qwen2.5-coder:7b and llama3.2:3b
- [project_harvest_loop_design.md](project_harvest_loop_design.md) -- Level 1 harvest loop: batch spinner, no grading, new stations (super prep, frame holder, canning table)
```
