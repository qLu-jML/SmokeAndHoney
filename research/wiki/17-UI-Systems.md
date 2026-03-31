[< Save / Load System](16-Save-Load-System) | [Home](Home) | [Glossary >](18-Glossary)

---

# UI Systems


The following UI systems were implemented as Godot autoloads or standalone scenes during the Phase 1 sprint. They define the player-facing interface layer for all game feedback, navigation, and dialogue. All use the **Langstroth Frame UI Design System** defined in §10.1.4 — thick wooden frame borders, honeycomb cell interiors, warm amber/beeswax palette. Sprite assets are in `assets/sprites/ui/`; composite previews in `assets/sprites/ui/previews/`.

### 17.1 NotificationManager — Global Toast Notifications


| Autoload | NotificationManager.gd, registered in project.godot. CanvasLayer order 50 (renders above all game content). |
| --- | --- |
| Function | Global toast notification system. Any script calls NotificationManager.show("message") to display a timed notification. Notifications stack vertically up to a maximum of 5 simultaneous toasts. Oldest toast is removed when the stack is full. |
| Animation | Each toast slides in from the right edge and fades out on expiry. Uses Godot Tween for smooth animation. |
| Auto-triggers | NotificationManager automatically fires toasts on: player level-up, XP gain milestones, season transitions, and month changes. These are wired directly into the relevant system signals. |
| Consumers | InspectionOverlay.gd fires "👑 Queen confirmed!" on successful queen sighting. uncle_bob.gd fires hint acknowledgement toasts. Any future system can call the autoload directly. |


### 17.2 DialogueUI — NPC Speech & Dialogue


| Autoload | DialogueUI.gd, registered in project.godot. CanvasLayer order 40 (renders above world but below notifications). |
| --- | --- |
| Speech bubble mode | Floating world-space speech bubble anchored above an NPC's position. Auto-dismisses after a configurable delay. Used by uncle_bob.gd for tutorial hints. |
| Dialogue box mode | Full screen-bottom dialogue box with NPC portrait, speaker name, and dialogue text. Advances on player input. Designed for branching dialogue trees when those are authored in Phase 2. |
| Portrait system | NPC portrait is a 64×64px image displayed in the dialogue box. Uncle Bob's portrait placeholder is included. All portrait assets follow the GDD §10.1.3 PixelLab generation guidelines. |


### 17.3 PauseMenu — In-Game Pause Screen

`PauseMenu.gd` + `PauseMenu.tscn`. A slide-in panel that appears over the game world when the player presses the pause key. Buttons: **Resume** (close panel), **Map** (open world map — Phase 3), **Save** (calls SaveManager directly), **Main Menu** (return to title with confirmation). The panel slides in from the right edge using a Tween animation consistent with the NotificationManager aesthetic.

### 17.4 MainMenu — Title Screen

`MainMenu.gd` + `MainMenu.tscn`. Animated title screen shown at game launch. Buttons: **New Game** (calls SaveManager to initialize fresh state, then loads TestEnvironment), **Continue** (calls SaveManager.load\_game(), only enabled when a valid save file exists), **Quit**. The title screen uses the game's warm amber palette and a simple parallax background.

### 17.5 HUD — Heads-Up Display

`hud.gd` was fully rebuilt during this sprint. The HUD uses programmatically constructed top and bottom bars rather than a scene-tree-defined layout, making it easier to extend without restructuring the scene. Key design decisions:


| Signal-driven updates | All HUD values update via signals from TimeManager, player, and GameData. The _process() polling loop was removed entirely — the HUD is now idle between signal fires. |
| --- | --- |
| Energy bar | Fills left-to-right as a colored bar. Color shifts from green (full) toward amber (low) toward red (critical). Wired to player energy signal. |
| XP bar | Fills left-to-right. Pulses briefly on XP gain. Level number shown beside the bar. Level-up animation fires the NotificationManager toast. |
| String cache | A string cache was added to avoid allocating new label strings every signal fire — important for performance on repeated fast-firing signals (e.g., energy drain ticks). |
| Bug fix | The add_item() function previously caused a double-fire of the HUD refresh signal, producing a visible flicker. Fixed by consolidating the signal emit to a single call site. |


---

[< Save / Load System](16-Save-Load-System) | [Home](Home) | [Glossary >](18-Glossary)