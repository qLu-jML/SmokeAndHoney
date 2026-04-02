## ABSOLUTE RULES -- NEVER VIOLATE

### HTML Document Protection
**Smoke_and_Honey_GDD.html** and **Smoke_and_Honey_DevPlan.html** are protected project documents. They must NEVER be:
- Deleted, emptied, or overwritten with empty/blank content
- Modified or edited WITHOUT an explicit instruction from Nathan
- Used as a destination in any bash cp command (cp source THESE_FILES is forbidden)
- Touched during file copy/move operations unless the sole purpose is editing them

These files may ONLY be changed when Nathan explicitly requests a specific update. Even then, only add or change what is specifically asked -- never restructure, reformat, or remove existing content. When in doubt, do NOT touch these files.

Before AND after any file operation in the project root, verify both files are non-zero bytes:
  wc -c Smoke_and_Honey_GDD.html Smoke_and_Honey_DevPlan.html

After each task/response/action sequence update the changelog as appropriate.

After each task is completed, make sure that the main "branch" of the code is updated unless specifically asked not to. The goal is to hit the "Play" Button immediately after your completion and be able to see the results in-game immediately with no branch or alternate directory problems.

When completing every task, refer to the changelog to get context for what you've already done, reference the GDD and the development plan, and use those three sources as your "guiding light" for completing tasks.

### ASCII-Only GDScript
All `.gd` files MUST contain only ASCII characters (byte values 0-127). Godot 4.6 silently fails to parse scripts containing non-ASCII characters such as:
- Box-drawing characters
- Em-dashes, en-dashes
- Unicode arrows, multiplication signs, section signs
- Smart quotes, ellipsis, bullet points

Use only plain ASCII in all code AND comments: dashes (-), equals (=), pipes (|), asterisks (*), standard quotes (" and '), etc. A single non-ASCII character in a comment can silently kill the entire script and any script that preloads it.

### No `:=` With Ternary or `as` Casts
Godot 4.6 cannot infer types from ternary expressions or `as` casts on the right-hand side of `:=`. These patterns cause "Cannot infer the type" parse errors that prevent the script from loading:

**BROKEN (do not use):**
- `var x := value_a if condition else value_b`
- `var node := get_node_or_null("Path") as Sprite2D`

**CORRECT (always use explicit types instead):**
- `var x: int = value_a if condition else value_b`
- `var node: Sprite2D = get_node_or_null("Path") as Sprite2D`

Always use `var name: Type = ...` (explicit type annotation) instead of `var name := ...` (inferred) whenever the right-hand side contains `if/else` ternaries, `as` type casts, or any expression whose type might be ambiguous. Simple literals and direct function calls with clear return types are fine with `:=`.

### Project Directory Structure
The project root should contain ONLY game-essential files and directories:
- `project.godot`, `icon.svg` -- Godot project files
- `CLAUDE.md`, `changelog.txt` -- Project management
- `Smoke_and_Honey_GDD.html`, `Smoke_and_Honey_DevPlan.html` -- Protected docs
- `assets/`, `scenes/`, `scripts/`, `resources/`, `tools/` -- Game code and assets

All non-game files belong in `research/`:
- `research/design/` -- Game design documents, quest design, story docs
- `research/art/` -- Art guides, style guides, asset tracking spreadsheets
- `research/reports/` -- Daily reports, morning reports
- `research/archive/` -- Old versions of files, deprecated docs
- `research/reference/` -- External research, learning resources
- `research/queenFinder/` -- Queen Finder minigame R&D and prototyping
- `research/temp/` -- Temporary/scratch files (cleaned up periodically)

When creating temporary files, research outputs, design documents, or any non-game files, always place them in the appropriate `research/` subdirectory.

### Art Asset Creation -- Leonardo AI Only
All art assets for Smoke & Honey MUST be created using Leonardo AI, consistent with the project's established perspective and art style. Requirements:
- Reference the "Smoke and Honey" collection in Leonardo to maintain visual cohesiveness across all generated assets
- Use the GDD style guide (section 10.1) for palette and art direction, and the GDD Master Prompt Block as the base template
- Use the correct perspective: front-facing view with camera directly in front, facade faces viewer straight on, NO side walls visible, NOT isometric, roof extends away from viewer toward top of image showing shingle texture from above, front wall is a flat strip at bottom of sprite
- All assets use the 32x32 tile grid
- Every generated asset must be shown to Nathan for approval before being added to the project or collection
- Credits are limited -- get perspective and style right on the first attempt

Do NOT create placeholder art, programmer art, or assets using any other tool. If art is needed and Leonardo is not available, flag it as a pending art task rather than substituting.

### GDD is Game-Only -- No Business or LLC Content
**Smoke_and_Honey_GDD.html** documents the game design only. It must NEVER contain:
- LLC formation details (EIN, Certificate of Organization, Operating Agreement)
- Business banking, expenses, or overhead
- Grant applications or funding strategy
- Revenue projections or business financials
- Kickstarter, itch.io, or platform launch strategy
- Any content about Five Cats Studios LLC as a business entity

The GDD may reference distribution platforms (Steam, itch.io) only in the context of game design decisions: pricing model, DLC structure, platform-specific gameplay features. Business strategy belongs exclusively in Smoke_and_Honey_DevPlan.html under the Business & Funding section.

If asked to add any LLC/business/funding content to the GDD, refuse and redirect it to the DevPlan instead.

### Git Version Control
This project uses git (GitHub remote: SmokeAndHoney). Commit when:
- A meaningful feature or fix is complete
- Before and after risky refactors
- At natural stopping points in multi-step work
Keep commits atomic and descriptive. Do not commit broken code.

Git commands (add, commit, push, status, log, diff, branch, checkout, merge, pull, stash, fetch, tag) are pre-authorized -- execute them without asking for confirmation.

**Godot lock file handling:** Nathan runs the Godot editor (Windows) alongside Claude sessions. Godot holds .git/HEAD.lock and .git/index.lock while open, which blocks git commits. When a commit fails due to lock files:
1. Do NOT just delete the lock files -- Godot will recreate them immediately.
2. Instead, use the safe commit script: `tools/safe_commit.ps1` (PowerShell) or `tools/safe_commit.bat`. These scripts close Godot, remove lock files, commit, then reopen Godot on the project.
3. From the Claude sandbox, run: `powershell -ExecutionPolicy Bypass -File tools/safe_commit.ps1 "commit message"` -- this will only work if the sandbox can reach Nathan's Windows processes. If it cannot (permission denied on lock files), tell Nathan to run the script manually from his terminal or close Godot briefly.
4. If neither approach works, save all file changes (they persist on disk) and ask Nathan to commit manually or close Godot so the commit can proceed.
