[< Glossary](18-Glossary) | [Home](Home)

---

# Development Changelog


## Development Changelog

A complete record of all development activity logged during the Smoke & Honey project. Entries are sourced from `changelog.txt` in the project root and are appended as work is completed. Entries marked **†** were identified during cross-reference and were not yet in `changelog.txt` at time of GDD update.

### 2026-03-20 — Inventory & Input Fixes


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 22:29 | UI — Inventory HUD | Implemented dynamically generated Inventory UI inside scripts/ui/hud.gd: 10×2 grid toggled with the "O" key, rescaled to 16×16 pixel-art tiles, fitted within 320×180 resolution with zero border separation. |
| 22:37 | Core — Player | Rewrote targeter tile-coordinates logic in scripts/core/player.gd to use strict integer tile snapping from the player's current map cell, resolving offset inaccuracies and matching classical farm-sim momentum. |
| 22:40 | UI — Inventory HUD | Fixed Inventory UI invisibility by replacing implicit CanvasLayer anchor presets in hud.gd with explicit Vector2 size and centering coordinates. |


### 2026-03-24 — Phase 1 Complete · Phase 4 Complete · Test Environment · Code Audit · Save/Load · UI Systems

#### Phase 1 — Simulation Pipeline


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 09:00 | Simulation — HiveSimulation | Phase 1 complete ("Quarter Loop It's Alive"). Wired 10-script simulation pipeline in HiveSimulation.gd: tick() now calls NurseSystem → CellStateTransition → PopulationCohortManager → ForagerSystem → CongestionDetector → HiveHealthCalculator → SnapshotWriter in sequence. |
| 09:15 | World — Cedar Bend | Cedar Bend rename complete: created cedar_bend.gd and cedar_bend.tscn, updated map_overlay.gd to reference new scene, deprecated calders_bluff.gd. |
| 09:30 | NPC — Uncle Bob | Added Uncle Bob NPC stub at scripts/npc/uncle_bob.gd: 6 rotating tutorial hints, +2 XP per talk interaction, auto-dismissing speech bubble, wired into player.gd E-key interaction chain. |
| 09:45 | Mechanic — Inspection | Implemented queen sighting mechanic in InspectionOverlay.gd: 60% base chance + 1% per level (capped at 80%), awards +15 XP on success, displays animated "👑 Queen confirmed!" notification. |
| 10:00 | Project — TASKS.md | Synced TASKS.md: marked Phases 2 and 3 complete (work was already done in code) and updated phase status to reflect current project state. |


#### Phase 4 — World & Navigation (Interior Scenes)


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 10:30 | World — Diner Interior | Phase 4 complete. Built Crossroads Diner interior (diner_interior.tscn + diner_interior.gd): full meal system with 5 menu items, time-gated availability, Uncle Bob Tuesdays special, Darlene Friday mornings special. |
| 10:45 | Assets — Diner Sprites | Added 6 new diner sprites: rose_waitress.png, chalkboard_menu.png, pie_case.png, diner_stool.png, diner_floor.png, weather_icons.png. |
| 11:00 | World — Feed & Supply | Built Feed & Supply interior (feed_supply_interior.tscn + feed_supply_interior.gd): 11 purchasable items with seasonal availability, dynamic bulletin board displaying Grange notices. |
| 11:15 | World — Post Office | Built Post Office interior (post_office_interior.tscn + post_office_interior.gd): June the postmaster NPC, package collection UI, spring-only "LIVE BEES" delivery mechanic, new pigeonholes.png sprite. |
| 11:30 | Data — GameData.gd | Extended GameData.gd with new fields and helpers: meals_eaten dict, coffee_until_hour, xp_buff_until_day, pending_deliveries array, and associated accessor methods. |


#### Test Environment & Dandelion System (GDD §14.8.4)


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 12:00 | Scene — TestEnvironment | Expanded TestEnvironment.tscn from 21 to 72 nodes: Uncle Bob at (380, 140), 5 hive spot markers, 4 garden beds (clover, phacelia, lavender, sunflower), 14 wildflower patches, DandelionSpawner node. |
| 12:15 | Assets — Environment Sprites | Added 10 new pixel-art sprites: lavender.png, sunflower.png, aster.png, phacelia.png, clover_plant.png, willow.png, wildflower_tile.png, dandelion_tile.png, hive_spot_marker.png, garden_bed.png. |
| 12:30 | Mechanic — Dandelion Spawner | Implemented dandelion spring mechanic (dandelion_spawner.gd, 279 lines): annual bloom quality roll (POOR / AVERAGE / GOOD / EXCEPTIONAL), per-quality density ranges, timing shifts, edge-tile bias, mow API, and signals. |
| 12:45 | Simulation — ForageManager | Updated ForageManager.gd to integrate dandelion nectar unit (NU) values from DandelionSpawner signals. |
| 13:00 | GDD — §14.8.4 | Added GDD §14.8.4 documenting the full dandelion spring mechanic: bloom quality tiers, density logic, timing windows, and mow API contract. |


#### Code Efficiency Audit


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 14:00 | Perf — HiveSimulation.tick() | Collapsed 7 passes to 2; cell reads per tick reduced from ~245,000 to ~70,000 — ~3.5× faster. |
| 14:10 | Perf — SnapshotWriter | Refactored hot path to reuse pre-computed counts, eliminating all redundant cell reads in SnapshotWriter.gd. |
| 14:20 | Perf — HUD (_process) | Removed redundant _process() override from hud.gd; added string cache to avoid per-frame allocations. |
| 14:30 | Perf — Grid Overlay | Guarded queue_redraw() behind a visibility check in grid_overlay.gd so it only fires when the overlay is visible. |
| 14:40 | Perf — hive.gd | Cached player node reference at scene entry in hive.gd, replacing per-frame get_tree group traversal. |
| 14:50 | Perf — player.gd | Removed debug print spam and fixed add_item() triggering a double HUD refresh on every pickup. |
| 15:00 | Perf — QuestManager | Changed completed_quests storage from Array (O(n) lookup) to Dictionary (O(1) lookup) in QuestManager.gd. |


#### Save / Load System † cross-referenced, not yet in changelog.txt


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 15:30 † | System — SaveManager | Implemented SaveManager.gd as an autoload singleton: serialises full game state to disk, triggers auto-save on player sleep, loads save data on game launch. Fixed a bug where the dandelion group was not included in save snapshots, causing bloom state to reset on reload. |


#### UI Systems † cross-referenced, not yet in changelog.txt


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 16:00 † | UI — Full Suite | Completed UI system build: NotificationManager (toast queue), DialogueUI (branching conversation display), PauseMenu, MainMenu, and full HUD rebuild. Added 38 UI sprites covering buttons, panels, icons, and overlays. |


#### Project Refactoring & Bug Fixes


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 16:00 | Project — Refactoring | Full project restructuring: consolidated all .gd scripts under scripts/ hierarchy (autoloads/, core/, simulation/, ui/, npc/, world/), updated all .tscn scene references. |
| 16:15–16:30 | Bug Fixes | Fixed NotificationManager show()→notify(), added _is_ui_blocking() guard to player.gd, fixed InspectionOverlay Engine.has_singleton() check, fixed TimeManager autoload path in project.godot. |
| 17:00 | Simulation — Science Fixes | Realistic starting populations (24k bees), exponential varroa growth model, corrected nurse:larva ratios (1.2), winter consumption x3.5, nectar-to-honey 0.20 factor. |
| 17:30–17:35 | Simulation — CongestionDetector/NurseSystem | Updated CongestionDetector: 4-arg evaluate() returning dict with swarm_prep flag, science-based thresholds (honey 0.62, brood 0.65, swarm 0.78). NurseSystem: capping_delay return, IDEAL_NURSE_RATIO 1.2. |
| 18:00 | Bug Fix — Parse Errors | Fixed 5 parse errors blocking game launch: class_name conflict, ambiguous 'not' syntax, stale Godot caches. |
| 19:00 | Scene — TestEnvironment | Fixed grass tile coverage: replaced 1099 edge/transition tiles with solid grass, filled 464 empty cells. 100% coverage (4770/4770). |
| 19:30–20:15 | Bug Fixes — Type Inference | Fixed Variant type inference errors across project (min→mini, abs→absi/absf), MainMenu (mouse_filter, load_game→load_from_disk, save path), PauseMenu, map_overlay resize, stale caches. |
| 20:00 | Project — Cleanup | Moved research files to research/, removed Antigravity/, backups/, TASKS.md, stale lock file. |


#### UI Visual Identity Redesign & Langstroth Theme


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 21:00 | Art — UI Sprites | Regenerated all 38 UI sprite assets with Langstroth hive frame theme (wooden borders, honeycomb cell fill bars, wax-cream interiors, warm amber palette). |
| 21:05 | Art — UI Previews | Generated 6 UI composite preview images (HUD, toasts, dialogue, speech bubble, pause menu, main menu) at 860x620. |
| 21:10 | GDD — §10.1.4 | Added §10.1.4 Langstroth Frame UI Design System (palette tokens, component specs, button states, fill bar animation, font treatment, PixelLab prompt block). |
| 21:15 | Docs — Style Guide | Updated PIXELLAB_STYLE_GUIDE.md with UI Asset Direction section: Langstroth palette table, master prompt block, per-element prompt templates. |


#### Inventory Items & Hive Interaction Mechanics


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 21:25 | UI — HUD Fixes | Fixed NextDayButton visibility (dev mode only) and hotbar inventory slot population in _refresh_all(). |
| 22:00 | Mechanic — Hive Tool | Added ITEM_HIVE_TOOL: inspection now requires Hive Tool selected. Removed bottom UI bar (only hotbar remains). Context-sensitive hive prompts based on held item. |
| 22:10–22:20 | UI — Hotbar | Re-added selected item name label (lower-left, amber text). Fixed label not updating on slot change. Context-sensitive prompts refresh every frame while in range. |
| 22:30 | Mechanic — Package Bees | Added ITEM_PACKAGE_BEES and colony installation mechanic. Empty complete hives require Package Bees + [E] to install. colony_installed flag, context-sensitive prompts, independent per-hive simulation. |
| 22:45 | Mechanic — Colony Establishment | Package colonies: all 10 frames start empty foundation, ~8000 bees, 2 lbs honey, 15 mites, 4-6 day laying_delay, 7-day inspection lockout, progressive center-out comb drawing (~960 cells/day). |


#### Simulation — Comb Drawing & Queen Laying Mechanics


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 23:00 | Simulation — Comb Drawing | Comb drawing scales with forage level. forage_mult 0.05 (dearth) to 1.0 (full flow). Good months ~800-1200 cells/day; poor months ~50-200. Season grade display in dev mode (S/A/B/C/D/F, color-coded). |
| 23:15 | Simulation — Queen Laying | Implemented _cell_walled_in() hex adjacency check: queen can only lay in drawn-empty cells where all 6 hex neighbours are drawn comb. Wax cost 0.0004 lbs/cell with store thresholds. |
| 23:30 | Simulation — 3D Geometry | Rewrote comb drawing and queen laying to use 3D ellipsoid geometry. _cell_3d_dist() from hive center (frame 4.5, col 35, row 15). Ellipsoid radii RZ=5, RX=38, RY=42. Natural dome expansion. Nuc brood seeding converted to 3D (BROOD_RADIUS=0.55). |
| 23:45 | Simulation — Three Fixes | Greyscale foundation atlas (increased contrast), comb building starts day 1 (honey threshold 3.0→1.0 lbs, three-tier speed), dandelions sprout day 1 of spring (removed bloom delay). |
| 00:00 | Bug Fix — HiveSimulation._ready() | Critical fix: _ready() was auto-registering ALL hives including empty ones. Now only creates empty foundation. New init_as_nuc() and init_as_package() handle explicit initialization + registration. |


#### Visual Polish & Foundation Rendering


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 00:15 | Art — Cell Atlas | Darkened foundation cells: fill (18,16,14) nearly black, outlines (75,70,62) medium grey. LOD palette state 0 updated. Unmistakable contrast against drawn comb. |
| 00:20 | UI — Dev Tooltip | Dev mode cell tooltip shows wax status [WAX/NO WAX] and 3D distance from hive center (d3d=0.XX). |
| 00:35 | Mechanic — Nuc Hive | Complete hives (ITEM_BEEHIVE) spawn with active nuc colony: center 5 frames drawn with brood (3D ellipsoid dome), outer 5 blank foundation. Pre-established, ticks immediately. |
| 00:40 | Mechanic — Nuc Inspection | Nuc hives bypass 7-day establishment lockout. colony_install_day set to 0 (epoch). Inspectable from placement. |
| 00:50 | Bug Fix — FrameRenderer | Fixed magenta atlas crash: _ensure_atlas() now loads PNG via Image.load_from_file() bypassing Godot import cache. External edits picked up immediately. |


#### Item Sprites & Hotbar Icons


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 01:15 | Art — Item Sprites | Generated 20 new item sprites. Hotbar now shows TextureRect icons. _load_item_textures() preloads 25 item-to-sprite mappings. Color fallback for unmapped items. |
| 01:30 | Art — Sprite Regen | Regenerated all 20 item sprites at 32x32 (was 16x16) for detail fidelity. Fixed right-side hotbar rendering mismatch. |


#### Modular Hive Sprites & Box Management


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 02:00 | Art — Hive Sprites | Rewrote modular hive sprite system for isometric stacking. 7 components: stand (24x10), base (24x4), deep_empty (24x14), deep (24x14), super (24x10), excluder (24x2), lid (24x7). Bottom-up stacking with configurable overlap. Build phase shows appropriate layers. |
| 02:30 | Mechanic — Box Rotation | Implemented box rotation (R key near hive with hive tool): moves bottom deep body to top. rotate_deep_bodies() in HiveSimulation, try_rotate_deeps() in hive.gd. |
| 02:30 | Mechanic — Multi-Box Inspection | Player navigates between boxes with W/S keys. All boxes (deeps + supers) inspectable with full 10-frame, sides A/B access. Header shows "Deep 1", "Super 2", etc. Progress spans all boxes. |
| 03:00–04:00 | Art — Hive Sprites (iterations) | Multiple redraws to achieve correct 3/4 RPG camera angle (~60% top, ~35% front). Final sizes: stand 24x12, base 24x5, deep 24x18, super 24x14, excluder 24x3, lid 24x12. Top surface prominent. |


#### Gloves & Hive Management UI


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 05:00 | Mechanic — Gloves | Added ITEM_GLOVES: when selected and [E] pressed near colonized hive, opens HiveManagementUI overlay. Actions: Add Deep Body (max 2, permanently locked), Add Honey Super (max 10), Add Queen Excluder, Rotate Deeps. Each consumes inventory items. |
| 05:00 | Mechanic — Starting Inventory | Player starts with minimal hotbar (1 stand, 2 deeps, 4 supers, 1 package bees, 1 gloves, 1 hive tool). Overflow items auto-stocked into pre-placed storage chest. |


### 2026-03-25 — Storage Chest · Unicode Fixes · Type Inference Audit

#### Storage Chest & Critical Bug Fixes


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 23:15 (Mar 24) | Mechanic — Storage Chest | Created chest.gd (50-slot persistent storage, placeable, proximity prompt), chest_storage.gd (10x5 grid + hotbar row, WASD/E transfer, Q focus switch). Pre-placed in TestEnvironment at (200, 220). |
| 23:30 | Bug Fix — Invisible Hives | hive.gd preload() for new modular sprites had no .import files. Replaced with runtime Image.load_from_file(). Added null-texture guards. |
| 23:35 | Bug Fix — Chest UI | chest.gd and chest_storage.gd contained 2100+ Unicode characters preventing Godot 4.6 execution. Rewrote in pure ASCII. |
| 23:50 | Bug Fix — Hive/Chest (round 2) | Replaced const Dictionary and static func in hive.gd (Godot 4.6 parse failure). Changed player.gd preload() for chest.gd to runtime load(). Created hive_stand.png sprite. |
| 01:15 (Mar 25) | Bug Fix — Project-wide ASCII | Cleaned ALL non-ASCII characters from 42 .gd files (27,032 chars replaced). player.gd alone had 1,171 non-ASCII chars preventing ALL interactions. Added ASCII-only rule to CLAUDE.md. |
| 01:30 | Bug Fix — Type Inference | Fixed 90+ ":= ternary" and ":= as Type" parse errors across 23 files. Godot 4.6 cannot infer types from ternary or as-casts. Added ":= prohibition" rule to CLAUDE.md. |
| 02:30 | Bug Fix — Parse Errors | Fixed cedar_bend.gd (get_node_or_null :=), diner_interior.gd (duplicate var "hour"), feed_supply_interior.gd (duplicate var "d" x2). Godot 4.6 strict scoping. |
| 05:00 | Bug Fix — NectarProcessor | Replaced hardcoded CellStateTransition.FRAME_SIZE with frame.grid_size for variable-size frame support (deep 3500 vs super 2450). New static lbs_per_cell(frame) helper. |


#### Queen Finder Asset Overhaul


| Time (CST) | System / Area | Description |
| --- | --- | --- |
| 06:00 | Art — Queen Finder | Dimmed wing colors significantly across all 5 breed palettes for more subdued, realistic appearance. Fixed queen abdomen cutoff by expanding cell size from 56x40 to 60x42 and reducing abdomen rx. Added queen_species_comparison.png (8x closeup of all 5 breeds side-by-side with worker counterpart). Expanded find-the-queen simulations from 6 to 12 images (2 easier, 2 harder, 2 very hard up to 115 bees). Reduced sim frame to 800x450. Deleted old delete/ directory and stale .import files. |
| 01:30 | Art — Item Sprites | Regenerated all 20 item sprites at 32x32 (was 16x16) to match existing art fidelity. Higher resolution for detail: outlines, shading, hex patterns. Removed stale .import files. Fixed right-side hotbar slot rendering. |


Footer

Smoke & Honey -- Game Design Document -- Living Document

---

[< Glossary](18-Glossary) | [Home](Home)