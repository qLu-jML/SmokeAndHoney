# Smoke & Honey — Claude Working Rules

## Pre-Authorized Actions
Nathan grants blanket pre-authorization for all routine operations. Do NOT ask before:
- Git operations (commit, push, branch, merge, pull — any branch)
- Firebase CLI deploys
- File reads, writes, edits, moves, copies within the project
- Running npm, pip, or other package manager commands
- Downloading from trusted sources (Leonardo.ai, Firebase, GitHub)
- Executing bash commands in service of a task

Just do it and report what was done. Only ask if the action is irreversible AND outside the current task scope, or involves financial transactions, account creation, or sharing access with third parties.

## After Every Task
1. Update changelog.txt with what was done
2. Keep main branch current and playable — Nathan should be able to hit Play immediately
3. Verify protected files are intact: wc -c Smoke_and_Honey_GDD.html Smoke_and_Honey_DevPlan.html

## Protected Documents
Smoke_and_Honey_GDD.html and Smoke_and_Honey_DevPlan.html must NEVER be:
- Deleted, emptied, or overwritten
- Modified without an explicit instruction from Nathan
- Used as a destination in any cp command
- Touched during file operations unless the sole purpose is editing them

Only add or change what is specifically requested. Never restructure, reformat, or remove existing content without explicit instruction.

## Guiding Documents
Before starting any task, check in this order:
1. changelog.txt — recent context and what has already been done
2. Smoke_and_Honey_GDD.html — design intent and systems specification
3. Smoke_and_Honey_DevPlan.html — roadmap position and business strategy

Do not improvise systems that are already specified in the GDD.

## Document Boundaries
- GDD — game design only: systems, simulation, art direction, quests, world
- DevPlan — all business content: LLC, grants, revenue, platform strategy
- story_bible.html — narrative reference: characters, lore, quest chains, themes
- If asked to add business content to the GDD, refuse and redirect to DevPlan

## Project Directory Structure
Root contains only game-essential files:
- project.godot, icon.svg — Godot engine files
- CLAUDE.md, changelog.txt — project management
- Smoke_and_Honey_GDD.html, Smoke_and_Honey_DevPlan.html — protected docs
- story_bible.html — narrative reference
- assets/, scenes/, scripts/, resources/, tools/ — game code and assets

All non-game files go in research/:
- research/design/ — design docs, quest design, story docs
- research/art/ — art guides, style guides, asset tracking
- research/reports/ — daily and morning reports
- research/archive/ — deprecated docs and old versions
- research/reference/ — external research and learning resources
- research/queenFinder/ — Queen Finder minigame R&D
- research/temp/ — scratch files, cleaned periodically

## ASCII-Only GDScript
All .gd files MUST contain only ASCII characters (bytes 0-127). Godot 4.6 silently
fails to parse non-ASCII. This includes comments. Never use:
- Em-dashes, en-dashes, box-drawing characters
- Unicode arrows, multiplication signs, section signs
- Smart quotes, ellipsis characters, bullet points

Use only: dashes (-), equals (=), pipes (|), asterisks (*), standard quotes (" and ')

## No := With Ternary or as Casts
Godot 4.6 cannot infer types from ternary expressions or as casts. Always use
explicit type annotation instead:

BROKEN:
  var x := value_a if condition else value_b
  var node := get_node_or_null("Path") as Sprite2D

CORRECT:
  var x: int = value_a if condition else value_b
  var node: Sprite2D = get_node_or_null("Path") as Sprite2D

## Git Workflow
- Commit when a feature or fix is complete, before/after risky refactors, at
  natural stopping points
- Keep commits atomic with descriptive messages
- Never commit broken code

Godot lock file handling — Godot holds .git/HEAD.lock and .git/index.lock while
open. When a commit fails due to lock files:
1. Do NOT delete lock files directly — Godot recreates them instantly
2. Use tools/safe_commit.ps1 or tools/safe_commit.bat
3. Run: powershell -ExecutionPolicy Bypass -File tools/safe_commit.ps1 "message"
4. If the sandbox cannot reach Nathan's processes, ask Nathan to run it manually
   or close Godot briefly

## Art Assets
All art uses Leonardo AI exclusively:
- Reference the "Smoke and Honey" collection for visual consistency
- Follow GDD style guide (section 10.1) and Master Prompt Block
- Correct perspective: front-facing, camera directly in front, facade faces viewer,
  NO side walls, NOT isometric, roof extends away from viewer
- 32x32 tile grid for all assets
- Show Nathan every asset for approval before adding to project
- Credits are limited — get perspective and style right on the first attempt
- Never create placeholder art — flag as pending art task if Leonardo unavailable