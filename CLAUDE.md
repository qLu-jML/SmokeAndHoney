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

### Git Version Control
This project uses git (GitHub remote: SmokeAndHoney). Commit when:
- A meaningful feature or fix is complete
- Before and after risky refactors
- At natural stopping points in multi-step work
Keep commits atomic and descriptive. Do not commit broken code.
