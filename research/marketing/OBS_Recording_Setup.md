# OBS Setup — Smoke and Honey Kickstarter Recording
*One-time setup. Should take about 10 minutes.*

---

## Step 1 — Import the Scene Collection

1. Open OBS
2. Top menu: **Scene Collection > Import**
3. Browse to: `SmokeAndHoney/research/temp/SmokeHoney_OBS_Scene.json`
4. Click Import, then switch to it: **Scene Collection > Smoke and Honey KS Recording**

You should see one scene called "Smoke and Honey - Recording" with a source called "Godot Game Capture."

---

## Step 2 — Fix the Window Capture (30 seconds)

The Game Capture source needs to point at your running Godot window:

1. In the Sources panel, double-click **Godot Game Capture**
2. Set Mode to: **Capture specific window**
3. Window dropdown: select the entry that says **Smoke and Honey** (it appears once Godot is open)
4. Click OK

> If you don't see it yet, launch Godot first, then come back and do this step.

---

## Step 3 — Output Settings

Top menu: **Settings > Output**

Set these:

| Setting | Value |
|---|---|
| Output Mode | Simple |
| Recording Path | `[your SmokeAndHoney folder]\research\temp\` |
| Recording Quality | High Quality, Medium File Size |
| Recording Format | **MKV** (safer — won't corrupt if you stop suddenly) |
| Encoder | Hardware (NVENC) if available, otherwise Software (x264) |

Click **Apply**.

---

## Step 4 — Video Settings

**Settings > Video**

| Setting | Value |
|---|---|
| Base (Canvas) Resolution | 1920x1080 |
| Output (Scaled) Resolution | 1920x1080 |
| Downscale Filter | Lanczos |
| FPS | 60 |

Click **Apply**.

---

## Step 5 — Audio Settings

**Settings > Audio**

| Setting | Value |
|---|---|
| Desktop Audio | Default (picks up game audio automatically) |
| Mic/Auxiliary Audio | Your microphone |

Click **Apply**, then close Settings.

**Audio Mixer levels (bottom of OBS main window):**
- Desktop Audio: set to about **-12 dB** (game sounds in background)
- Mic/Aux: set to about **-6 dB** (your voice is the main track)

Right-click each fader and choose "Set volume" to dial these in.

---

## Step 6 — Test Recording

1. Launch Godot, load the project, hit Play
2. In OBS, confirm the game appears in the preview window
3. Click **Start Recording**
4. Play for 10 seconds, say something into your mic
5. Click **Stop Recording**
6. Open the MKV file and confirm both video and voice are recorded cleanly

---

## Step 7 — You're Ready

When you're set to record for real:

1. Launch Godot, load to a save in **Wide-Clover** (summer) with a healthy hive
2. Start OBS recording
3. Work through the 8 scenes from the recording checklist while narrating
4. Stop recording when done
5. The MKV file will be in `SmokeAndHoney/research/temp/`
6. Tell me the filename and I'll handle the rest

---

## Troubleshooting

**Game doesn't appear in preview:** Make sure Godot is running (not just the editor — hit the Play button first), then re-select the window in the Game Capture source settings.

**No sound from mic:** Check that your mic is selected in Settings > Audio, and that the Mic/Aux fader in the Audio Mixer isn't muted (speaker icon should be green).

**MKV file won't open:** Use VLC. MKV plays in VLC even if Windows Media Player complains.

**Black screen in Game Capture:** Right-click the Game Capture source, click Properties, change the capture mode from "Capture specific window" to "Capture foreground window" as a fallback.
