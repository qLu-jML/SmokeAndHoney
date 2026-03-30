[< Core Simulation Scripts](15-Core-Simulation-Architecture) | [Home](Home) | [UI Systems >](17-UI-Systems)

---

# Save / Load System


Persistent save/load is implemented via `SaveManager.gd`, registered as an autoload in `project.godot`. The system serializes all live game state to a single versioned JSON file and restores it on game launch.

### 16.1 SaveManager — Design & Scope


| File location | user://smoke_and_honey_save.json. Uses Godot's user:// path for cross-platform compatibility. File is versioned: a save_version integer guards against loading incompatible saves after structural changes. |
| --- | --- |
| Autoload registration | Added to project.godot as a global autoload. All game systems access it via SaveManager.save_game() and SaveManager.load_game(). |
| Auto-save trigger | Fires automatically when the player accepts the end-of-day sleep summary: hooked into hud.gd _on_summary_accepted(). Manual save also available via the PauseMenu. |
| Load on launch | test_environment.gd _ready() calls SaveManager.load_game() on startup. Falls back to a clean new-game state if no save file exists or the version does not match. |


### 16.2 Serialized State


| System | What is saved |
| --- | --- |
| TimeManager | Current day, hour, season, year. Full calendar position restored exactly. |
| GameData | All fields: dollars, inventory, community_standing, meals_eaten dict, coffee_until_hour, xp_buff_until_day, pending_deliveries array, and all helper-method state. |
| Player | World position (Vector2), inventory contents, current XP and level, active energy value. |
| Hives | Every HiveSimulation's full cell grid serialized as base64-encoded PackedByteArray. Queen state, adult cohorts, congestion flags, stores, last snapshot. All hive data is fully round-tripped. |
| ForageManager | Current forage pool values per location, weekly NU totals, nectar flow calendar position. |
| DandelionSpawner | Annual roll outcome, all tile states (planted/blooming/dormant), mow cooldown timers. Requires DandelionSpawner to be in the "dandelion_spawner" group (fixed bug — see §14.8.4). |
| QuestManager | completed_quests Dictionary (O(1) lookup), active_quests array, quest progress counters. |
| Uncle Bob hint index | Current hint rotation index saved so Uncle Bob does not repeat the same hint after a reload. |


---

[< Core Simulation Scripts](15-Core-Simulation-Architecture) | [Home](Home) | [UI Systems >](17-UI-Systems)