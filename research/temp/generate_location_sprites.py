#!/usr/bin/env python3
"""
Smoke & Honey -- Location Sprite Generator
==========================================
Generates all missing environment, building, prop, tree, interior, wildlife,
and seasonal overlay sprites for the game's 18 location maps.

Style: Top-down pixel art, warm muted earthy palette, Cainos-compatible.
All sprites use transparent PNG backgrounds with separate shadow layers where noted.

Output directory: assets/sprites/ (organized by category)
"""

import math
import random
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Base project path
PROJECT = Path("/sessions/fervent-magical-cerf/mnt/SmokeAndHoney")
ASSETS = PROJECT / "assets" / "sprites"

# Palette -- warm, muted, earthy (matching Cainos + GDD Art Direction)
PAL = {
    # Ground
    "grass_light":     (134, 168, 89),
    "grass_mid":       (108, 142, 72),
    "grass_dark":      (82, 116, 55),
    "grass_winter":    (180, 185, 170),
    "dirt_light":      (165, 135, 95),
    "dirt_mid":        (140, 110, 75),
    "dirt_dark":       (110, 85, 60),
    "mud":             (95, 72, 48),
    "gravel_light":    (175, 168, 155),
    "gravel_mid":      (148, 140, 128),
    "gravel_dark":     (120, 112, 100),
    "snow_white":      (235, 238, 242),
    "snow_shadow":     (195, 205, 218),
    "ice_blue":        (195, 215, 235),
    "puddle_blue":     (130, 155, 180),

    # Wood -- buildings and structures
    "wood_white":      (228, 220, 205),   # white clapboard
    "wood_cream":      (215, 200, 175),
    "wood_barn_red":   (145, 52, 38),
    "wood_barn_dark":  (110, 38, 28),
    "wood_brown":      (120, 85, 52),
    "wood_dark":       (80, 55, 35),
    "wood_weathered":  (135, 118, 95),
    "wood_fence":      (155, 130, 98),

    # Roof
    "roof_gray":       (115, 110, 105),
    "roof_dark":       (85, 80, 75),
    "roof_shingle":    (95, 88, 78),
    "roof_gambrel":    (130, 45, 32),

    # Metal / Stone
    "metal_gray":      (140, 145, 148),
    "metal_dark":      (95, 98, 100),
    "metal_rust":      (150, 95, 55),
    "stone_light":     (170, 165, 155),
    "stone_mid":       (140, 135, 125),
    "stone_dark":      (105, 100, 92),
    "brick_red":       (155, 75, 58),
    "brick_dark":      (120, 55, 42),

    # Foliage / Trees
    "leaf_spring":     (115, 165, 72),
    "leaf_summer":     (85, 135, 55),
    "leaf_fall_gold":  (195, 162, 48),
    "leaf_fall_red":   (175, 72, 38),
    "leaf_fall_orange":(195, 118, 38),
    "bark_light":      (115, 88, 58),
    "bark_mid":        (85, 62, 38),
    "bark_dark":       (60, 42, 25),
    "willow_green":    (105, 148, 72),
    "catkin_yellow":   (205, 185, 65),
    "bloom_white":     (235, 228, 218),
    "bloom_pink":      (225, 175, 165),
    "linden_yellow":   (215, 195, 85),

    # Water
    "water_light":     (110, 148, 175),
    "water_mid":       (82, 118, 148),
    "water_dark":      (58, 88, 115),
    "water_spring":    (115, 98, 72),   # turbid brown
    "water_winter":    (155, 172, 188),

    # Interior
    "floor_wood":      (155, 128, 88),
    "floor_dark":      (120, 95, 65),
    "floor_tile":      (168, 162, 148),
    "counter_top":     (145, 118, 82),
    "counter_front":   (115, 88, 58),
    "chair_wood":      (138, 105, 68),
    "fabric_green":    (75, 108, 72),
    "fabric_red":      (148, 58, 48),
    "glass":           (175, 195, 210),
    "glass_glow":      (215, 225, 235),
    "neon_red":        (220, 65, 55),
    "neon_glow":       (255, 120, 100),

    # Wildlife
    "bird_brown":      (118, 85, 52),
    "bird_gray":       (128, 128, 125),
    "bird_blue":       (65, 95, 135),
    "bird_breast":     (185, 105, 58),
    "heron_gray":      (148, 152, 155),
    "heron_white":     (225, 228, 230),
    "dragonfly_blue":  (75, 130, 175),
    "butterfly_orange":(215, 145, 48),
    "firefly_yellow":  (228, 225, 120),
    "firefly_glow":    (245, 242, 165),

    # UI / Misc
    "amber_light":     (225, 185, 85),
    "shadow":          (35, 28, 18),
    "flag_red":        (180, 42, 42),
    "flag_blue":       (42, 65, 130),
    "flag_white":      (230, 230, 230),
    "asphalt":         (72, 70, 65),
    "asphalt_line":    (195, 185, 140),
}

# Superscale for anti-aliased downscale
SS = 4

def new_img(w, h):
    """Create transparent RGBA image at superscale."""
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

def draw_for(img):
    return ImageDraw.Draw(img)

def save_sprite(img, rel_path, target_w=None, target_h=None):
    """Downscale from superscale and save."""
    if target_w and target_h:
        out = img.resize((target_w, target_h), Image.LANCZOS)
    else:
        w, h = img.size
        out = img.resize((w // SS, h // SS), Image.LANCZOS)
    path = ASSETS / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(str(path), "PNG")
    return path

def rect(d, x, y, w, h, color, alpha=255):
    """Draw filled rectangle with optional alpha."""
    if w <= 0 or h <= 0:
        return
    c = color + (alpha,) if len(color) == 3 else color
    d.rectangle([x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1], fill=c)

def ellipse(d, cx, cy, rx, ry, color, alpha=255):
    """Draw filled ellipse."""
    c = color + (alpha,) if len(color) == 3 else color
    d.ellipse([
        (cx - rx) * SS, (cy - ry) * SS,
        (cx + rx) * SS, (cy + ry) * SS
    ], fill=c)

def rounded_rect(d, x, y, w, h, r, color, alpha=255):
    """Draw rounded rectangle."""
    c = color + (alpha,) if len(color) == 3 else color
    d.rounded_rectangle([x * SS, y * SS, (x + w) * SS, (y + h) * SS], radius=r * SS, fill=c)

def pixel_noise(img, region, colors, density=0.15):
    """Add pixel noise within a region for texture."""
    x0, y0, w, h = region
    d = draw_for(img)
    for _ in range(int(w * h * density * SS)):
        px = random.randint(x0 * SS, (x0 + w) * SS - 1)
        py = random.randint(y0 * SS, (y0 + h) * SS - 1)
        c = random.choice(colors)
        d.point((px, py), fill=c + (180,))

def vary(color, amount=15):
    """Slight random color variation."""
    amount = abs(amount)
    if amount == 0:
        return color
    return tuple(max(0, min(255, c + random.randint(-amount, amount))) for c in color)

# ---------------------------------------------------------------------------
# CATEGORY 1: Ground Tiles (16x16 each)
# ---------------------------------------------------------------------------

def gen_ground_tiles():
    """Generate all ground tile variants."""
    print("Generating ground tiles...")
    tiles = {}

    # Grass variants
    for name, base in [("grass_short", PAL["grass_mid"]),
                       ("grass_medium", PAL["grass_dark"]),
                       ("grass_long", PAL["grass_dark"])]:
        img = new_img(16, 16)
        d = draw_for(img)
        # Base fill
        rect(d, 0, 0, 16, 16, base, 255)
        # Texture
        pixel_noise(img, (0, 0, 16, 16), [vary(base), PAL["grass_light"], vary(PAL["grass_dark"])], 0.25)
        if "long" in name:
            # Taller grass blades
            for _ in range(6):
                bx = random.randint(1, 14)
                by = random.randint(2, 10)
                d.line([(bx*SS, by*SS), ((bx+random.randint(-1,1))*SS, (by-3)*SS)],
                       fill=PAL["grass_dark"] + (200,), width=SS)
        tiles[name] = save_sprite(img, f"environment/tiles/{name}.png")

    # Mud tile
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["mud"], 255)
    pixel_noise(img, (0, 0, 16, 16), [PAL["dirt_dark"], vary(PAL["mud"]), PAL["dirt_mid"]], 0.3)
    tiles["mud"] = save_sprite(img, "environment/tiles/mud_tile.png")

    # Snow tile
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["snow_white"], 255)
    pixel_noise(img, (0, 0, 16, 16), [PAL["snow_shadow"], vary(PAL["snow_white"])], 0.2)
    tiles["snow"] = save_sprite(img, "environment/tiles/snow_tile.png")

    # Leaf litter tile (fall)
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["grass_mid"], 255)
    for _ in range(8):
        lx = random.randint(0, 14)
        ly = random.randint(0, 14)
        lc = random.choice([PAL["leaf_fall_gold"], PAL["leaf_fall_orange"], PAL["leaf_fall_red"]])
        ellipse(d, lx + 1, ly + 1, 1.5, 1, lc, 180)
    tiles["leaf_litter"] = save_sprite(img, "environment/tiles/leaf_litter_tile.png")

    # Puddle overlay
    img = new_img(16, 16)
    d = draw_for(img)
    ellipse(d, 8, 8, 6, 5, PAL["puddle_blue"], 140)
    ellipse(d, 7, 7, 4, 3, PAL["water_light"], 100)
    tiles["puddle"] = save_sprite(img, "environment/tiles/puddle_overlay.png")

    # Spring mud patches
    img = new_img(16, 16)
    d = draw_for(img)
    ellipse(d, 8, 9, 7, 5, PAL["mud"], 200)
    ellipse(d, 7, 8, 5, 3, PAL["dirt_dark"], 160)
    pixel_noise(img, (2, 4, 12, 10), [PAL["dirt_mid"], PAL["mud"]], 0.15)
    tiles["mud_patch"] = save_sprite(img, "environment/tiles/mud_patch_overlay.png")

    # Frost overlay (fall mornings)
    img = new_img(16, 16)
    d = draw_for(img)
    for _ in range(12):
        fx = random.randint(0, 15)
        fy = random.randint(0, 15)
        d.point((fx * SS, fy * SS), fill=(220, 228, 235, 80))
    tiles["frost"] = save_sprite(img, "environment/tiles/frost_overlay.png")

    # Cracked blacktop tile (town street)
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["asphalt"], 255)
    pixel_noise(img, (0, 0, 16, 16), [vary(PAL["asphalt"]), (80, 78, 72)], 0.2)
    # Cracks
    d.line([(4*SS, 0), (6*SS, 8*SS), (5*SS, 16*SS)], fill=(55, 52, 48, 150), width=SS)
    tiles["blacktop"] = save_sprite(img, "environment/tiles/blacktop_tile.png")

    # Concrete sidewalk tile
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["stone_light"], 255)
    # Slab lines
    d.line([(0, 8*SS), (16*SS, 8*SS)], fill=PAL["stone_mid"] + (120,), width=SS)
    d.line([(8*SS, 0), (8*SS, 16*SS)], fill=PAL["stone_mid"] + (100,), width=SS)
    pixel_noise(img, (0, 0, 16, 16), [PAL["stone_mid"], vary(PAL["stone_light"])], 0.15)
    tiles["sidewalk"] = save_sprite(img, "environment/tiles/sidewalk_tile.png")

    # Water tile (river)
    for season, color, name in [
        ("summer", PAL["water_mid"], "water_summer"),
        ("spring", PAL["water_spring"], "water_spring"),
        ("winter", PAL["water_winter"], "water_winter"),
    ]:
        img = new_img(16, 16)
        d = draw_for(img)
        rect(d, 0, 0, 16, 16, color, 220)
        # Ripple highlights
        for _ in range(3):
            rx = random.randint(2, 13)
            ry = random.randint(2, 13)
            d.line([(rx*SS, ry*SS), ((rx+2)*SS, ry*SS)], fill=(200, 210, 220, 60), width=SS)
        tiles[name] = save_sprite(img, f"environment/tiles/{name}_tile.png")

    # Flood water overlay (standing water)
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["water_spring"], 150)
    for _ in range(4):
        rx = random.randint(1, 14)
        ry = random.randint(1, 14)
        d.line([(rx*SS, ry*SS), ((rx+3)*SS, ry*SS)], fill=(140, 120, 90, 80), width=SS)
    tiles["flood"] = save_sprite(img, "environment/tiles/flood_water_overlay.png")

    # Gravel bar (exposed river rocks)
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 0, 0, 16, 16, PAL["gravel_mid"], 255)
    for _ in range(10):
        rx, ry = random.randint(0, 14), random.randint(0, 14)
        c = random.choice([PAL["gravel_light"], PAL["gravel_dark"], PAL["stone_mid"]])
        ellipse(d, rx + 1, ry + 1, 1.2, 0.8, c)
    tiles["gravel_bar"] = save_sprite(img, "environment/tiles/gravel_bar_tile.png")

    print(f"  Generated {len(tiles)} ground tiles")
    return tiles


# ---------------------------------------------------------------------------
# CATEGORY 2: Building Exteriors
# ---------------------------------------------------------------------------

def gen_building(name, w, h, body_color, roof_color, details_fn=None):
    """Generate a building sprite with body, roof, and optional details."""
    img = new_img(w, h)
    d = draw_for(img)

    roof_h = int(h * 0.3)
    body_h = h - roof_h

    # Body
    rect(d, 1, roof_h, w - 2, body_h, body_color)
    # Slight shade on right side
    rect(d, w - 4, roof_h, 3, body_h, vary(body_color, -15), 180)
    # Body texture
    pixel_noise(img, (1, roof_h, w - 2, body_h), [vary(body_color, 8), vary(body_color, -8)], 0.1)

    # Roof (slightly wider)
    rounded_rect(d, 0, 0, w, roof_h + 2, 2, roof_color)
    rect(d, 0, roof_h - 1, w, 3, vary(roof_color, -20))

    if details_fn:
        details_fn(d, img, w, h, roof_h)

    return img

def gen_buildings():
    """Generate all building exterior sprites."""
    print("Generating building exteriors...")
    buildings = {}

    # --- Uncle Bob's Farmhouse (white clapboard) ---
    def farmhouse_details(d, img, w, h, rh):
        # Porch
        rect(d, 4, h - 12, w - 8, 12, PAL["wood_brown"], 200)
        rect(d, 4, h - 12, w - 8, 2, PAL["wood_dark"])
        # Door
        rect(d, w//2 - 4, rh + 8, 8, h - rh - 20, PAL["wood_dark"])
        rect(d, w//2 - 3, rh + 9, 6, h - rh - 22, PAL["wood_brown"])
        # Windows
        for wx in [12, w - 20]:
            rect(d, wx, rh + 6, 8, 8, PAL["glass"], 200)
            rect(d, wx + 1, rh + 7, 6, 6, PAL["glass_glow"], 150)
            # Curtain hint
            rect(d, wx + 1, rh + 7, 2, 6, PAL["fabric_red"], 80)
        # Chimney
        rect(d, w - 16, 0, 6, rh - 2, PAL["brick_red"])
        # Flower box
        rect(d, 10, rh + 14, 12, 3, PAL["wood_brown"])
        for fx in range(11, 21, 3):
            ellipse(d, fx + 1, rh + 13, 1.5, 1.5, PAL["bloom_pink"], 200)
        # Porch steps
        rect(d, w//2 - 6, h - 4, 12, 4, PAL["wood_weathered"])
        rect(d, w//2 - 6, h - 2, 12, 2, PAL["wood_brown"])

    img = gen_building("farmhouse", 80, 64, PAL["wood_white"], PAL["roof_gray"], farmhouse_details)
    buildings["farmhouse"] = save_sprite(img, "buildings/farmhouse.png")

    # --- Shed (weathered red-brown) ---
    def shed_details(d, img, w, h, rh):
        # Sliding barn door
        rect(d, w//2 - 8, rh + 4, 16, h - rh - 8, PAL["wood_barn_dark"])
        rect(d, w//2 - 7, rh + 5, 7, h - rh - 10, PAL["wood_barn_red"])
        rect(d, w//2, rh + 5, 7, h - rh - 10, vary(PAL["wood_barn_red"], 10))
        # Door slightly ajar
        rect(d, w//2 + 6, rh + 5, 2, h - rh - 10, (0, 0, 0), 120)
        # Rain gauge
        rect(d, w - 8, rh + 8, 2, 12, PAL["glass"], 180)
        # Tools on wall
        d.line([(6*SS, (rh+8)*SS), (6*SS, (rh+18)*SS)], fill=PAL["metal_gray"]+(200,), width=2*SS)

    img = gen_building("shed", 48, 40, PAL["wood_barn_red"], PAL["roof_shingle"], shed_details)
    buildings["shed"] = save_sprite(img, "buildings/shed_exterior.png")

    # --- Harmon Farmhouse (2-story white) ---
    def harmon_details(d, img, w, h, rh):
        # Two stories of windows
        for row in [rh + 6, rh + 22]:
            for wx in [10, 28, 50, 68]:
                rect(d, wx, row, 8, 8, PAL["glass"], 200)
                rect(d, wx + 1, row + 1, 6, 6, PAL["glass_glow"], 140)
        # Wraparound porch
        rect(d, 0, h - 14, w, 14, PAL["wood_cream"], 220)
        rect(d, 0, h - 14, w, 2, PAL["wood_brown"])
        # Columns
        for cx in [4, 20, 40, 60, w - 8]:
            rect(d, cx, h - 14, 3, 12, PAL["wood_white"])
        # Door
        rect(d, w//2 - 5, h - 14, 10, 12, PAL["wood_dark"])
        # Mudroom extension
        rect(d, w - 18, rh + 14, 16, h - rh - 28, PAL["wood_cream"])
        rect(d, w - 18, rh + 12, 16, 4, PAL["roof_gray"])
        # Flag pole
        d.line([(4*SS, 2*SS), (4*SS, (h-14)*SS)], fill=PAL["metal_gray"]+(220,), width=2*SS)
        # Flag
        rect(d, 5, 2, 8, 5, PAL["flag_red"], 200)

    img = gen_building("harmon_farmhouse", 88, 72, PAL["wood_white"], PAL["roof_gray"], harmon_details)
    buildings["harmon_farmhouse"] = save_sprite(img, "buildings/harmon_farmhouse.png")

    # --- Harmon Barn (red gambrel) ---
    def barn_details(d, img, w, h, rh):
        # Gambrel roof shape (extra peak)
        d.polygon([
            (0, rh * SS), (w//2 * SS, 0), (w * SS, rh * SS)
        ], fill=PAL["roof_gambrel"])
        # Barn door
        rect(d, w//2 - 10, rh + 4, 20, h - rh - 6, PAL["wood_barn_dark"])
        rect(d, w//2 - 9, rh + 5, 9, h - rh - 8, PAL["wood_barn_red"])
        rect(d, w//2, rh + 5, 9, h - rh - 8, vary(PAL["wood_barn_red"], 8))
        # Hay loft window
        rect(d, w//2 - 4, rh - 6, 8, 6, PAL["wood_dark"])
        rect(d, w//2 - 3, rh - 5, 6, 4, (180, 155, 85, 150))  # hay visible
        # Swallow nests (tiny dots near roofline)
        for nx in [15, 25, w-15, w-25]:
            ellipse(d, nx, rh + 2, 2, 1.5, PAL["mud"])

    img = gen_building("harmon_barn", 72, 56, PAL["wood_barn_red"], PAL["roof_gambrel"], barn_details)
    buildings["harmon_barn"] = save_sprite(img, "buildings/harmon_barn.png")

    # --- Machine Shed (metal pole building) ---
    def machine_shed_details(d, img, w, h, rh):
        # Roll-up door
        rect(d, 4, rh + 2, w - 8, h - rh - 4, (0, 0, 0), 140)
        # Door tracks
        rect(d, 4, rh + 2, 2, h - rh - 4, PAL["metal_gray"])
        rect(d, w - 6, rh + 2, 2, h - rh - 4, PAL["metal_gray"])
        # Corrugated texture
        for cy in range(rh, h, 3):
            d.line([(4*SS, cy*SS), ((w-4)*SS, cy*SS)], fill=vary(PAL["metal_gray"], 8)+(100,), width=SS)

    img = gen_building("machine_shed", 64, 44, PAL["metal_gray"], PAL["metal_dark"], machine_shed_details)
    buildings["machine_shed"] = save_sprite(img, "buildings/machine_shed.png")

    # --- Grain Bins (background element) ---
    img = new_img(48, 56)
    d = draw_for(img)
    for bx, bw in [(4, 16), (22, 18), (38, 8)]:
        ellipse(d, bx + bw//2, 14, bw//2, 12, PAL["metal_gray"])
        rect(d, bx, 14, bw, 38, PAL["metal_gray"])
        rect(d, bx, 52, bw, 4, PAL["metal_dark"])
        # Corrugation
        for cy in range(16, 50, 4):
            d.line([(bx*SS, cy*SS), ((bx+bw)*SS, cy*SS)], fill=vary(PAL["metal_gray"], 6)+(80,), width=SS)
    # Conveyor leg
    d.line([(40*SS, 8*SS), (44*SS, 40*SS)], fill=PAL["metal_dark"]+(200,), width=3*SS)
    buildings["grain_bins"] = save_sprite(img, "buildings/grain_bins.png")

    # --- Water Tower (far background) ---
    img = new_img(24, 48)
    d = draw_for(img)
    # Legs
    for lx in [6, 18]:
        d.line([(lx*SS, 20*SS), (lx*SS, 48*SS)], fill=PAL["metal_gray"]+(200,), width=3*SS)
    d.line([(6*SS, 34*SS), (18*SS, 34*SS)], fill=PAL["metal_gray"]+(180,), width=2*SS)
    # Tank
    ellipse(d, 12, 12, 10, 10, PAL["metal_gray"])
    ellipse(d, 12, 10, 9, 8, vary(PAL["metal_gray"], 8))
    # Top cap
    ellipse(d, 12, 4, 5, 3, PAL["metal_dark"])
    buildings["water_tower"] = save_sprite(img, "buildings/water_tower.png")

    # --- Dr. Harwick's Office (brick institutional) ---
    def harwick_details(d, img, w, h, rh):
        # Brick texture
        for by in range(rh + 2, h - 4, 4):
            offset = 3 if (by // 4) % 2 else 0
            for bx in range(2 + offset, w - 2, 8):
                rect(d, bx, by, 6, 3, vary(PAL["brick_red"], 8))
        # Window
        rect(d, w//2 - 6, rh + 6, 12, 10, PAL["glass"], 200)
        rect(d, w//2 - 5, rh + 7, 10, 8, PAL["glass_glow"], 140)
        # Door
        rect(d, 8, rh + 8, 8, h - rh - 12, PAL["wood_dark"])
        # Extension banner
        rect(d, w - 20, rh + 4, 18, 6, PAL["fabric_green"])
        # Garden bed in front
        rect(d, 6, h - 6, 20, 4, PAL["dirt_mid"])
        for fx in range(8, 24, 4):
            ellipse(d, fx, h - 7, 1.5, 2, PAL["leaf_spring"], 200)

    img = gen_building("harwick_office", 64, 48, PAL["brick_red"], PAL["roof_gray"], harwick_details)
    buildings["harwick_office"] = save_sprite(img, "buildings/harwick_office.png")

    # --- Fairgrounds Gate (wooden arch) ---
    img = new_img(80, 48)
    d = draw_for(img)
    # Posts
    rect(d, 4, 12, 6, 36, PAL["wood_brown"])
    rect(d, 70, 12, 6, 36, PAL["wood_brown"])
    # Arch
    d.arc([(4*SS, 2*SS), (76*SS, 32*SS)], 180, 0, fill=PAL["wood_brown"]+(230,), width=4*SS)
    # Cross beam
    rect(d, 4, 12, 72, 4, PAL["wood_brown"])
    # Text area
    rect(d, 14, 4, 52, 10, PAL["wood_white"], 200)
    # Ticket booths
    for bx in [8, 62]:
        rect(d, bx, 28, 10, 18, PAL["wood_cream"])
        rect(d, bx, 26, 10, 4, PAL["roof_gray"])
    # Banners (colored when active)
    for fx, c in [(20, PAL["flag_red"]), (35, PAL["flag_blue"]), (50, PAL["leaf_fall_gold"])]:
        d.polygon([
            (fx*SS, 16*SS), ((fx+6)*SS, 16*SS), ((fx+3)*SS, 26*SS)
        ], fill=c + (180,))
    buildings["fairgrounds_gate"] = save_sprite(img, "buildings/fairgrounds_gate.png")

    # --- Picket Fence Section ---
    img = new_img(32, 16)
    d = draw_for(img)
    # Rail
    rect(d, 0, 6, 32, 2, PAL["wood_white"])
    rect(d, 0, 12, 32, 2, PAL["wood_white"])
    # Pickets
    for px in range(2, 30, 5):
        rect(d, px, 2, 3, 14, PAL["wood_white"])
        rect(d, px, 1, 3, 2, PAL["wood_cream"])  # cap
    buildings["picket_fence"] = save_sprite(img, "environment/props/picket_fence.png")

    # --- Wire Fence + Gate ---
    img = new_img(32, 16)
    d = draw_for(img)
    # Posts
    rect(d, 2, 2, 2, 14, PAL["metal_gray"])
    rect(d, 14, 2, 2, 14, PAL["metal_gray"])
    rect(d, 28, 2, 2, 14, PAL["metal_gray"])
    # Wire lines
    for wy in [5, 8, 11]:
        d.line([(2*SS, wy*SS), (30*SS, wy*SS)], fill=PAL["metal_gray"]+(160,), width=SS)
    buildings["wire_fence"] = save_sprite(img, "environment/props/wire_fence.png")

    # Farm gate
    img = new_img(32, 20)
    d = draw_for(img)
    rect(d, 0, 2, 3, 18, PAL["metal_gray"])
    rect(d, 29, 2, 3, 18, PAL["metal_gray"])
    rect(d, 3, 4, 26, 2, PAL["metal_gray"])
    rect(d, 3, 14, 26, 2, PAL["metal_gray"])
    rect(d, 3, 9, 26, 2, PAL["metal_gray"])
    # Diagonal brace
    d.line([(3*SS, 4*SS), (29*SS, 16*SS)], fill=PAL["metal_gray"]+(200,), width=2*SS)
    buildings["farm_gate"] = save_sprite(img, "environment/props/farm_gate.png")

    print(f"  Generated {len(buildings)} building sprites")
    return buildings


# ---------------------------------------------------------------------------
# CATEGORY 3: Trees (with seasonal variants)
# ---------------------------------------------------------------------------

def gen_tree(trunk_w, trunk_h, crown_w, crown_h, crown_colors, trunk_color=None, extras_fn=None):
    """Generate a tree with trunk and crown."""
    tc = trunk_color or PAL["bark_mid"]
    w = max(crown_w, trunk_w) + 8
    h = trunk_h + crown_h + 4
    img = new_img(w, h)
    d = draw_for(img)
    cx = w // 2

    # Trunk
    rect(d, cx - trunk_w//2, crown_h, trunk_w, trunk_h, tc)
    rect(d, cx - trunk_w//2 + 1, crown_h, trunk_w - 2, trunk_h, vary(tc, 10))

    # Crown (layered ellipses for organic shape)
    for i, cc in enumerate(crown_colors):
        offset_y = i * 2
        ew = crown_w // 2 - i
        eh = crown_h // 2 - i
        if ew > 0 and eh > 0:
            ellipse(d, cx, crown_h // 2 + offset_y, ew, eh, cc, 230 - i * 20)

    # Crown texture noise
    pixel_noise(img, (cx - crown_w//2, 2, crown_w, crown_h - 2),
                [vary(crown_colors[0], 12)] if crown_colors else [], 0.12)

    if extras_fn:
        extras_fn(d, img, w, h, cx, crown_h)

    return img, w, h

def gen_trees():
    """Generate all tree sprites with seasonal variants."""
    print("Generating tree sprites...")
    trees = {}

    tree_specs = {
        "silver_maple": {
            "trunk_w": 6, "trunk_h": 14, "crown_w": 32, "crown_h": 24,
            "seasons": {
                "spring": [PAL["leaf_spring"], vary(PAL["leaf_spring"], 12)],
                "summer": [PAL["leaf_summer"], vary(PAL["leaf_summer"], 10)],
                "fall": [PAL["leaf_fall_gold"], PAL["leaf_fall_orange"]],
                "winter_bare": [],
            }
        },
        "cottonwood": {
            "trunk_w": 8, "trunk_h": 18, "crown_w": 28, "crown_h": 28,
            "seasons": {
                "spring": [PAL["leaf_spring"], (125, 170, 78)],
                "summer": [PAL["leaf_summer"], (90, 140, 60)],
                "fall": [(205, 180, 55), PAL["leaf_fall_gold"]],
                "winter_bare": [],
            }
        },
        "basswood_linden": {
            "trunk_w": 7, "trunk_h": 15, "crown_w": 36, "crown_h": 26,
            "seasons": {
                "spring": [PAL["leaf_spring"], (120, 162, 75)],
                "summer": [PAL["leaf_summer"], (88, 138, 58)],
                "bloom": [PAL["linden_yellow"], PAL["leaf_summer"], (200, 185, 75)],
                "fall": [PAL["leaf_fall_gold"], (180, 155, 50)],
                "winter_bare": [],
            }
        },
        "willow": {
            "trunk_w": 7, "trunk_h": 16, "crown_w": 34, "crown_h": 30,
            "seasons": {
                "catkin": [PAL["catkin_yellow"], (180, 165, 55)],
                "spring": [PAL["willow_green"], (115, 155, 78)],
                "summer": [PAL["willow_green"], (98, 138, 65)],
                "fall": [PAL["leaf_fall_gold"], (175, 155, 52)],
                "winter_bare": [],
            }
        },
        "wild_plum": {
            "trunk_w": 4, "trunk_h": 10, "crown_w": 20, "crown_h": 16,
            "seasons": {
                "bloom": [PAL["bloom_white"], PAL["bloom_pink"]],
                "spring": [PAL["leaf_spring"], (118, 160, 75)],
                "summer": [PAL["leaf_summer"], (85, 132, 55)],
                "fall": [PAL["leaf_fall_red"], PAL["leaf_fall_orange"]],
                "winter_bare": [],
            }
        },
        "apple_tree": {
            "trunk_w": 5, "trunk_h": 12, "crown_w": 24, "crown_h": 20,
            "seasons": {
                "bloom": [PAL["bloom_white"], PAL["bloom_pink"], PAL["leaf_spring"]],
                "spring": [PAL["leaf_spring"], (120, 165, 75)],
                "summer": [PAL["leaf_summer"], (90, 140, 58)],
                "fruit": [PAL["leaf_summer"], (180, 48, 32)],  # red apples
                "fall": [PAL["leaf_fall_gold"], PAL["leaf_fall_orange"]],
                "winter_bare": [],
            }
        },
        "cherry_tree": {
            "trunk_w": 4, "trunk_h": 11, "crown_w": 22, "crown_h": 18,
            "seasons": {
                "bloom": [PAL["bloom_pink"], (230, 185, 175)],
                "spring": [PAL["leaf_spring"], (115, 158, 72)],
                "summer": [PAL["leaf_summer"], (82, 128, 52)],
                "fall": [PAL["leaf_fall_red"], (165, 65, 35)],
                "winter_bare": [],
            }
        },
        "pear_tree": {
            "trunk_w": 5, "trunk_h": 12, "crown_w": 22, "crown_h": 22,
            "seasons": {
                "bloom": [PAL["bloom_white"], (240, 235, 225)],
                "spring": [PAL["leaf_spring"], (118, 162, 74)],
                "summer": [PAL["leaf_summer"], (88, 135, 56)],
                "fall": [PAL["leaf_fall_gold"], (195, 165, 52)],
                "winter_bare": [],
            }
        },
    }

    # Also generate sapling versions (Year 1-2)
    sapling_scale = 0.4

    for tree_name, spec in tree_specs.items():
        for season, colors in spec["seasons"].items():
            if season == "winter_bare":
                # Bare tree -- trunk only with branch hints
                tw, th = spec["trunk_w"], spec["trunk_h"]
                cw, ch = spec["crown_w"], spec["crown_h"]
                w = max(cw, tw) + 8
                h = th + ch + 4
                img = new_img(w, h)
                d = draw_for(img)
                cx = w // 2
                # Trunk
                rect(d, cx - tw//2, ch, tw, th, PAL["bark_mid"])
                # Bare branches
                for _ in range(5):
                    bx = cx + random.randint(-cw//3, cw//3)
                    by = random.randint(4, ch)
                    d.line([(cx*SS, (ch-2)*SS), (bx*SS, by*SS)], fill=PAL["bark_light"]+(180,), width=2*SS)
                trees[f"{tree_name}_winter"] = save_sprite(img, f"environment/trees/{tree_name}_winter.png")
            else:
                img, w, h = gen_tree(
                    spec["trunk_w"], spec["trunk_h"],
                    spec["crown_w"], spec["crown_h"],
                    colors
                )
                trees[f"{tree_name}_{season}"] = save_sprite(img, f"environment/trees/{tree_name}_{season}.png")

                # Sapling variant (only for main seasons)
                if season in ["spring", "summer"]:
                    sw = int(spec["crown_w"] * sapling_scale)
                    sh = int(spec["crown_h"] * sapling_scale)
                    stw = max(2, int(spec["trunk_w"] * sapling_scale))
                    sth = max(4, int(spec["trunk_h"] * sapling_scale))
                    simg, _, _ = gen_tree(stw, sth, sw, sh, colors)
                    trees[f"{tree_name}_sapling_{season}"] = save_sprite(
                        simg, f"environment/trees/{tree_name}_sapling_{season}.png"
                    )

    # Lilac bush (windbreak)
    for season, colors in [
        ("bloom", [PAL["bloom_pink"], (180, 130, 165), PAL["leaf_spring"]]),
        ("summer", [PAL["leaf_summer"], (90, 135, 58)]),
        ("fall", [PAL["leaf_fall_gold"], (170, 148, 52)]),
    ]:
        img = new_img(20, 18)
        d = draw_for(img)
        rect(d, 8, 12, 4, 6, PAL["bark_light"])
        for i, c in enumerate(colors):
            ellipse(d, 10, 8 - i, 8 - i, 6 - i, c, 220 - i * 20)
        trees[f"lilac_{season}"] = save_sprite(img, f"environment/trees/lilac_{season}.png")

    print(f"  Generated {len(trees)} tree sprites")
    return trees


# ---------------------------------------------------------------------------
# CATEGORY 4: Interior Furniture & Props
# ---------------------------------------------------------------------------

def gen_interior_props():
    """Generate interior furniture and prop sprites."""
    print("Generating interior props...")
    props = {}

    # Workbench
    img = new_img(48, 24)
    d = draw_for(img)
    rect(d, 0, 4, 48, 16, PAL["counter_top"])
    rect(d, 0, 6, 48, 14, PAL["counter_front"])
    rect(d, 2, 0, 44, 6, PAL["wood_brown"])  # top surface
    pixel_noise(img, (2, 0, 44, 6), [vary(PAL["wood_brown"], 8)], 0.15)
    # Vise
    rect(d, 38, 0, 6, 4, PAL["metal_gray"])
    props["workbench"] = save_sprite(img, "interiors/workbench.png")

    # Pegboard with tools
    img = new_img(32, 24)
    d = draw_for(img)
    rect(d, 0, 0, 32, 24, PAL["wood_cream"])
    # Peg holes
    for py in range(4, 22, 4):
        for px in range(4, 30, 4):
            ellipse(d, px, py, 0.8, 0.8, PAL["wood_dark"], 120)
    # Hanging tools silhouettes
    rect(d, 6, 4, 2, 10, PAL["metal_gray"])  # hive tool
    d.line([(14*SS, 6*SS), (14*SS, 14*SS)], fill=PAL["wood_brown"]+(200,), width=3*SS)  # smoker
    ellipse(d, 22, 8, 4, 4, PAL["metal_gray"], 160)  # coil
    props["pegboard"] = save_sprite(img, "interiors/pegboard.png")

    # Honey jar shelf
    img = new_img(32, 20)
    d = draw_for(img)
    rect(d, 0, 4, 32, 2, PAL["wood_brown"])
    rect(d, 0, 12, 32, 2, PAL["wood_brown"])
    # Jars on shelves
    for jx in range(4, 28, 6):
        for jy in [0, 8]:
            rect(d, jx, jy, 4, 4, (210, 165, 45, 200))
            rect(d, jx, jy, 4, 1, PAL["metal_gray"])
    props["honey_shelf"] = save_sprite(img, "interiors/honey_shelf.png")

    # Wood table (Knowledge Log)
    img = new_img(32, 24)
    d = draw_for(img)
    rect(d, 0, 4, 32, 14, PAL["floor_wood"])
    rect(d, 1, 2, 30, 4, PAL["wood_brown"])
    pixel_noise(img, (1, 2, 30, 4), [vary(PAL["wood_brown"], 6)], 0.12)
    # Legs
    rect(d, 2, 18, 3, 6, PAL["wood_dark"])
    rect(d, 27, 18, 3, 6, PAL["wood_dark"])
    # Book/journal on table
    rect(d, 10, 3, 8, 3, (120, 85, 45))
    props["wood_table"] = save_sprite(img, "interiors/wood_table.png")

    # Woodstove
    img = new_img(20, 24)
    d = draw_for(img)
    rect(d, 2, 4, 16, 16, PAL["metal_dark"])
    rect(d, 3, 5, 14, 14, PAL["metal_gray"])
    rect(d, 5, 8, 10, 6, (0, 0, 0), 200)  # fire window
    rect(d, 6, 9, 8, 4, (180, 80, 25, 120))  # fire glow
    # Stovepipe
    rect(d, 8, 0, 4, 6, PAL["metal_dark"])
    # Legs
    rect(d, 4, 20, 3, 4, PAL["metal_dark"])
    rect(d, 13, 20, 3, 4, PAL["metal_dark"])
    props["woodstove"] = save_sprite(img, "interiors/woodstove.png")

    # Coat hooks with gear
    img = new_img(24, 20)
    d = draw_for(img)
    rect(d, 0, 0, 24, 4, PAL["wood_brown"])
    # Hooks
    for hx in [4, 12, 20]:
        d.line([(hx*SS, 4*SS), (hx*SS, 6*SS)], fill=PAL["metal_gray"]+(200,), width=2*SS)
    # Veil hanging
    ellipse(d, 4, 12, 3, 5, PAL["wood_white"], 180)
    # Suit
    rect(d, 10, 7, 6, 12, PAL["wood_white"], 160)
    props["coat_hooks"] = save_sprite(img, "interiors/coat_hooks.png")

    # Extraction equipment (late game)
    img = new_img(32, 32)
    d = draw_for(img)
    # Extractor drum
    ellipse(d, 16, 16, 12, 12, PAL["metal_gray"])
    ellipse(d, 16, 14, 10, 10, vary(PAL["metal_gray"], 8))
    rect(d, 14, 2, 4, 6, PAL["metal_dark"])  # handle
    # Spigot
    rect(d, 26, 20, 4, 3, PAL["metal_dark"])
    props["extractor"] = save_sprite(img, "interiors/extractor.png")

    # Uncapping station
    img = new_img(32, 16)
    d = draw_for(img)
    rect(d, 0, 4, 32, 10, PAL["metal_gray"])
    rect(d, 2, 2, 28, 4, PAL["metal_gray"])
    # Tray
    rect(d, 4, 3, 24, 2, (200, 168, 48, 180))  # wax/honey color
    props["uncapping_station"] = save_sprite(img, "interiors/uncapping_station.png")

    # Bottling station
    img = new_img(32, 20)
    d = draw_for(img)
    rect(d, 0, 6, 32, 14, PAL["counter_front"])
    rect(d, 0, 4, 32, 4, PAL["counter_top"])
    # Jars in process
    for jx in [6, 14, 22]:
        rect(d, jx, 1, 4, 4, (210, 165, 45, 200))
    props["bottling_station"] = save_sprite(img, "interiors/bottling_station.png")

    # Folding chair
    img = new_img(12, 16)
    d = draw_for(img)
    rect(d, 1, 0, 10, 8, PAL["metal_gray"])
    rect(d, 2, 1, 8, 6, PAL["fabric_green"])
    rect(d, 1, 8, 2, 8, PAL["metal_gray"])
    rect(d, 9, 8, 2, 8, PAL["metal_gray"])
    props["folding_chair"] = save_sprite(img, "interiors/folding_chair.png")

    # Lectern/podium
    img = new_img(16, 24)
    d = draw_for(img)
    rect(d, 2, 0, 12, 8, PAL["wood_brown"])
    rect(d, 3, 1, 10, 6, PAL["wood_dark"])
    rect(d, 4, 8, 8, 14, PAL["wood_brown"])
    rect(d, 2, 22, 12, 2, PAL["wood_dark"])
    props["lectern"] = save_sprite(img, "interiors/lectern.png")

    # Microscope (Dr. Harwick's)
    img = new_img(12, 16)
    d = draw_for(img)
    rect(d, 3, 12, 6, 4, PAL["metal_dark"])  # base
    rect(d, 5, 4, 2, 10, PAL["metal_gray"])  # arm
    ellipse(d, 6, 3, 3, 2, PAL["metal_dark"])  # eyepiece
    ellipse(d, 6, 10, 2, 1.5, PAL["glass"], 180)  # lens
    props["microscope"] = save_sprite(img, "interiors/microscope.png")

    # Sample jars (pest specimens)
    img = new_img(24, 12)
    d = draw_for(img)
    for jx, c in [(2, (180, 195, 165)), (10, (195, 178, 140)), (18, (165, 185, 180))]:
        rect(d, jx, 2, 5, 8, c, 180)
        rect(d, jx, 1, 5, 2, PAL["metal_gray"])
    props["specimen_jars"] = save_sprite(img, "interiors/specimen_jars.png")

    # Farm table with records (Harmon kitchen)
    img = new_img(40, 28)
    d = draw_for(img)
    rect(d, 0, 6, 40, 16, PAL["floor_wood"])
    rect(d, 1, 4, 38, 6, PAL["wood_brown"])
    # Papers
    rect(d, 8, 5, 8, 3, PAL["wood_white"], 200)
    rect(d, 20, 5, 6, 4, PAL["wood_white"], 180)
    # Laptop
    rect(d, 28, 4, 8, 5, PAL["metal_dark"])
    rect(d, 29, 5, 6, 3, (120, 165, 195, 180))  # screen glow
    # Legs
    rect(d, 2, 22, 3, 6, PAL["wood_dark"])
    rect(d, 35, 22, 3, 6, PAL["wood_dark"])
    props["farm_table"] = save_sprite(img, "interiors/farm_table.png")

    # Seed calendars on wall
    img = new_img(20, 16)
    d = draw_for(img)
    for cx, c in [(0, (195, 172, 118)), (10, (175, 162, 118))]:
        rect(d, cx, 0, 9, 14, c)
        rect(d, cx, 0, 9, 3, PAL["wood_brown"])
    props["seed_calendars"] = save_sprite(img, "interiors/seed_calendars.png")

    # Stump worktable (Timber)
    img = new_img(20, 16)
    d = draw_for(img)
    ellipse(d, 10, 6, 9, 5, PAL["bark_light"])
    ellipse(d, 10, 5, 8, 4, (155, 128, 88))  # cut surface
    rect(d, 3, 8, 14, 8, PAL["bark_mid"])
    pixel_noise(img, (3, 8, 14, 8), [PAL["bark_dark"], PAL["bark_light"]], 0.15)
    props["stump_worktable"] = save_sprite(img, "interiors/stump_worktable.png")

    # River stone (worktable - River Bottom)
    img = new_img(20, 12)
    d = draw_for(img)
    ellipse(d, 10, 6, 9, 5, PAL["stone_mid"])
    ellipse(d, 10, 5, 8, 4, PAL["stone_light"])
    pixel_noise(img, (2, 2, 16, 8), [PAL["stone_dark"], vary(PAL["stone_mid"])], 0.12)
    props["river_stone"] = save_sprite(img, "environment/props/river_stone.png")

    # Rusted water trough (Timber)
    img = new_img(24, 12)
    d = draw_for(img)
    rect(d, 0, 2, 24, 8, PAL["metal_rust"])
    rect(d, 2, 4, 20, 4, PAL["water_light"], 180)
    rect(d, 0, 2, 24, 2, PAL["metal_dark"])
    props["water_trough"] = save_sprite(img, "environment/props/water_trough.png")

    # Town plaque / bench
    img = new_img(24, 12)
    d = draw_for(img)
    rect(d, 0, 4, 24, 6, PAL["wood_brown"])
    rect(d, 2, 2, 20, 3, PAL["wood_dark"])
    # Legs
    rect(d, 2, 10, 3, 2, PAL["metal_gray"])
    rect(d, 19, 10, 3, 2, PAL["metal_gray"])
    props["park_bench"] = save_sprite(img, "environment/props/park_bench.png")

    # Town Garden plaque
    img = new_img(16, 12)
    d = draw_for(img)
    rect(d, 2, 0, 12, 8, PAL["wood_dark"])
    rect(d, 3, 1, 10, 6, (148, 120, 72))
    # Post
    rect(d, 7, 8, 2, 4, PAL["wood_brown"])
    props["garden_plaque"] = save_sprite(img, "environment/props/garden_plaque.png")

    # Low stone wall (Town Garden border)
    img = new_img(32, 8)
    d = draw_for(img)
    for sx in range(0, 32, 6):
        w = random.randint(5, 7)
        rect(d, sx, 2, min(w, 32 - sx), 6, vary(PAL["stone_mid"], 10))
        rect(d, sx, 0, min(w, 32 - sx), 3, vary(PAL["stone_light"], 8))
    props["stone_wall"] = save_sprite(img, "environment/props/stone_wall.png")

    # Small gear shed (Town Garden)
    img = new_img(20, 16)
    d = draw_for(img)
    rect(d, 0, 4, 20, 12, PAL["wood_weathered"])
    rounded_rect(d, 0, 0, 20, 6, 1, PAL["roof_shingle"])
    rect(d, 7, 8, 6, 8, PAL["wood_dark"])
    props["small_gear_shed"] = save_sprite(img, "environment/props/small_gear_shed.png")

    # Old fence posts (remnant)
    img = new_img(16, 16)
    d = draw_for(img)
    rect(d, 6, 2, 4, 14, PAL["wood_weathered"])
    pixel_noise(img, (6, 2, 4, 14), [PAL["wood_dark"], PAL["bark_light"]], 0.2)
    props["old_fence_post"] = save_sprite(img, "environment/props/old_fence_post.png")

    # Tree planting stake
    img = new_img(8, 12)
    d = draw_for(img)
    d.line([(4*SS, 0), (4*SS, 12*SS)], fill=PAL["wood_brown"]+(200,), width=2*SS)
    rect(d, 2, 0, 4, 2, PAL["flag_red"], 180)
    props["planting_stake"] = save_sprite(img, "environment/props/planting_stake.png")

    # Tractor (Harmon)
    img = new_img(40, 28)
    d = draw_for(img)
    # Body
    rect(d, 8, 6, 24, 14, (55, 115, 55))  # green
    rect(d, 8, 4, 24, 4, (45, 95, 45))  # hood
    # Cab
    rect(d, 16, 0, 12, 8, PAL["glass"], 160)
    rect(d, 16, 0, 12, 2, (50, 100, 50))
    # Wheels
    ellipse(d, 10, 22, 6, 6, (30, 30, 30))
    ellipse(d, 10, 22, 4, 4, (50, 48, 45))
    ellipse(d, 32, 22, 8, 8, (30, 30, 30))
    ellipse(d, 32, 22, 5, 5, (50, 48, 45))
    # Open door hint
    rect(d, 27, 2, 2, 6, PAL["glass"], 100)
    props["tractor"] = save_sprite(img, "environment/props/tractor.png")

    # Crop sprayer
    img = new_img(36, 20)
    d = draw_for(img)
    rect(d, 4, 2, 28, 12, PAL["metal_gray"])
    rect(d, 4, 14, 28, 4, PAL["metal_dark"])
    ellipse(d, 8, 16, 4, 4, (30, 30, 30))
    ellipse(d, 28, 16, 4, 4, (30, 30, 30))
    # Spray arms (folded)
    rect(d, 0, 6, 6, 2, PAL["metal_gray"])
    rect(d, 30, 6, 6, 2, PAL["metal_gray"])
    props["crop_sprayer"] = save_sprite(img, "environment/props/crop_sprayer.png")

    # Hay bales
    img = new_img(16, 12)
    d = draw_for(img)
    rounded_rect(d, 0, 0, 16, 12, 2, (180, 155, 85))
    pixel_noise(img, (1, 1, 14, 10), [(195, 168, 92), (165, 140, 78)], 0.2)
    # String bands
    d.line([(0, 4*SS), (16*SS, 4*SS)], fill=(120, 95, 55, 140), width=SS)
    d.line([(0, 8*SS), (16*SS, 8*SS)], fill=(120, 95, 55, 140), width=SS)
    props["hay_bales"] = save_sprite(img, "environment/props/hay_bales.png")

    # Barn cat
    img = new_img(10, 8)
    d = draw_for(img)
    ellipse(d, 5, 5, 4, 3, (145, 105, 62))
    ellipse(d, 3, 3, 2, 2, (145, 105, 62))  # head
    d.point((2*SS, 2*SS), fill=(30, 28, 25, 200))  # eye
    props["barn_cat"] = save_sprite(img, "environment/props/barn_cat.png")

    # Wooden ladder
    img = new_img(8, 24)
    d = draw_for(img)
    rect(d, 0, 0, 2, 24, PAL["wood_brown"])
    rect(d, 6, 0, 2, 24, PAL["wood_brown"])
    for ry in range(3, 22, 4):
        rect(d, 0, ry, 8, 2, PAL["wood_weathered"])
    props["wooden_ladder"] = save_sprite(img, "environment/props/wooden_ladder.png")

    # Elevated hive stand (River Bottom flood-safe)
    img = new_img(20, 16)
    d = draw_for(img)
    rect(d, 2, 0, 16, 4, PAL["wood_brown"])
    rect(d, 2, 4, 3, 12, PAL["wood_brown"])
    rect(d, 15, 4, 3, 12, PAL["wood_brown"])
    rect(d, 2, 10, 16, 2, PAL["wood_weathered"])
    props["elevated_stand"] = save_sprite(img, "environment/props/elevated_hive_stand.png")

    # Destination signpost
    img = new_img(12, 24)
    d = draw_for(img)
    rect(d, 5, 6, 2, 18, PAL["wood_brown"])
    rect(d, 0, 2, 12, 5, PAL["wood_weathered"])
    rect(d, 0, 8, 12, 5, PAL["wood_weathered"])
    props["signpost"] = save_sprite(img, "environment/props/signpost.png")

    print(f"  Generated {len(props)} interior/prop sprites")
    return props


# ---------------------------------------------------------------------------
# CATEGORY 5: Wildlife & Particles
# ---------------------------------------------------------------------------

def gen_wildlife():
    """Generate ambient wildlife and particle sprites."""
    print("Generating wildlife sprites...")
    wildlife = {}

    # Robin
    img = new_img(10, 8)
    d = draw_for(img)
    ellipse(d, 5, 4, 4, 3, PAL["bird_brown"])
    ellipse(d, 5, 5, 3.5, 2.5, PAL["bird_breast"])
    ellipse(d, 3, 3, 2, 1.5, PAL["bird_brown"])
    d.point((2*SS, 2*SS), fill=(20, 18, 15, 200))
    wildlife["robin"] = save_sprite(img, "environment/wildlife/robin.png")

    # Starling
    img = new_img(10, 8)
    d = draw_for(img)
    ellipse(d, 5, 4, 4, 3, (45, 42, 38))
    ellipse(d, 3, 3, 2, 1.5, (40, 38, 35))
    d.point((2*SS, 2*SS), fill=(20, 18, 15, 200))
    # Iridescent speckles
    for _ in range(4):
        sx, sy = random.randint(2, 7), random.randint(2, 6)
        d.point((sx*SS, sy*SS), fill=(120, 140, 100, 140))
    wildlife["starling"] = save_sprite(img, "environment/wildlife/starling.png")

    # Sparrow
    img = new_img(8, 6)
    d = draw_for(img)
    ellipse(d, 4, 3, 3, 2.5, (135, 110, 78))
    ellipse(d, 2, 2, 1.5, 1.2, (125, 100, 68))
    d.point((1*SS, 1*SS), fill=(20, 18, 15, 200))
    wildlife["sparrow"] = save_sprite(img, "environment/wildlife/sparrow.png")

    # Heron (large, background)
    img = new_img(16, 24)
    d = draw_for(img)
    # Body
    ellipse(d, 8, 14, 5, 6, PAL["heron_gray"])
    ellipse(d, 8, 15, 4, 5, PAL["heron_white"])
    # Long neck
    d.line([(8*SS, 10*SS), (7*SS, 4*SS)], fill=PAL["heron_white"]+(200,), width=3*SS)
    # Head
    ellipse(d, 7, 3, 2, 1.5, PAL["heron_gray"])
    # Beak
    d.line([(7*SS, 3*SS), (3*SS, 2*SS)], fill=(165, 145, 45, 200), width=2*SS)
    # Legs
    d.line([(7*SS, 20*SS), (6*SS, 24*SS)], fill=(145, 135, 42, 180), width=2*SS)
    d.line([(9*SS, 20*SS), (10*SS, 24*SS)], fill=(145, 135, 42, 180), width=2*SS)
    wildlife["heron"] = save_sprite(img, "environment/wildlife/heron.png")

    # Kingfisher (small, fast)
    img = new_img(8, 6)
    d = draw_for(img)
    ellipse(d, 4, 3, 3, 2.5, PAL["bird_blue"])
    ellipse(d, 4, 4, 2, 1.5, PAL["bird_breast"])
    d.line([(2*SS, 2*SS), (0, 2*SS)], fill=(55, 50, 42, 200), width=2*SS)  # beak
    wildlife["kingfisher"] = save_sprite(img, "environment/wildlife/kingfisher.png")

    # Red-winged blackbird
    img = new_img(10, 8)
    d = draw_for(img)
    ellipse(d, 5, 4, 4, 3, (25, 22, 20))
    ellipse(d, 3, 3, 2, 1.5, (25, 22, 20))
    # Red + yellow wing patch
    ellipse(d, 6, 3, 2, 1.5, (180, 42, 32))
    ellipse(d, 7, 4, 1.5, 1, (195, 175, 48))
    wildlife["redwing_blackbird"] = save_sprite(img, "environment/wildlife/redwing_blackbird.png")

    # Butterfly
    img = new_img(10, 8)
    d = draw_for(img)
    # Body
    d.line([(5*SS, 1*SS), (5*SS, 7*SS)], fill=(40, 35, 28, 200), width=2*SS)
    # Wings
    ellipse(d, 3, 3, 2.5, 3, PAL["butterfly_orange"], 200)
    ellipse(d, 7, 3, 2.5, 3, PAL["butterfly_orange"], 200)
    # Wing spots
    d.point((3*SS, 3*SS), fill=(30, 25, 18, 150))
    d.point((7*SS, 3*SS), fill=(30, 25, 18, 150))
    wildlife["butterfly"] = save_sprite(img, "environment/wildlife/butterfly.png")

    # Dragonfly
    img = new_img(12, 6)
    d = draw_for(img)
    # Body
    d.line([(2*SS, 3*SS), (10*SS, 3*SS)], fill=PAL["dragonfly_blue"]+(220,), width=2*SS)
    # Wings (transparent)
    ellipse(d, 4, 2, 3, 1.5, (175, 195, 215, 100))
    ellipse(d, 4, 4, 3, 1.5, (175, 195, 215, 100))
    ellipse(d, 7, 2, 2.5, 1.2, (175, 195, 215, 80))
    ellipse(d, 7, 4, 2.5, 1.2, (175, 195, 215, 80))
    # Head
    ellipse(d, 2, 3, 1.5, 1, PAL["dragonfly_blue"])
    wildlife["dragonfly"] = save_sprite(img, "environment/wildlife/dragonfly.png")

    # Firefly
    img = new_img(6, 6)
    d = draw_for(img)
    ellipse(d, 3, 3, 2, 2, (60, 55, 42))
    ellipse(d, 3, 4, 1.5, 1, PAL["firefly_yellow"], 220)
    # Glow halo
    ellipse(d, 3, 4, 3, 2, PAL["firefly_glow"], 40)
    wildlife["firefly"] = save_sprite(img, "environment/wildlife/firefly.png")

    # Cottonwood seed particle (white fluffy)
    img = new_img(6, 6)
    d = draw_for(img)
    ellipse(d, 3, 3, 2, 2, (240, 238, 232, 160))
    ellipse(d, 3, 3, 1, 1, (250, 248, 242, 200))
    wildlife["cottonwood_seed"] = save_sprite(img, "environment/wildlife/cottonwood_seed.png")

    # Dew sparkle particle
    img = new_img(4, 4)
    d = draw_for(img)
    ellipse(d, 2, 2, 1.5, 1.5, (220, 228, 240, 140))
    d.point((2*SS, 1*SS), fill=(245, 248, 255, 200))
    wildlife["dew_sparkle"] = save_sprite(img, "environment/wildlife/dew_sparkle.png")

    # Heat shimmer (shader hint texture)
    img = new_img(16, 4)
    d = draw_for(img)
    for x in range(16):
        y_off = math.sin(x * 0.8) * 1.5
        d.point((x*SS, int((2 + y_off)*SS)), fill=(255, 255, 255, 30))
    wildlife["heat_shimmer"] = save_sprite(img, "environment/fx/heat_shimmer.png")

    # Chimney smoke particle
    img = new_img(8, 8)
    d = draw_for(img)
    ellipse(d, 4, 4, 3, 3, (180, 175, 165, 80))
    ellipse(d, 4, 3, 2, 2, (200, 195, 185, 50))
    wildlife["chimney_smoke"] = save_sprite(img, "environment/fx/chimney_smoke.png")

    # Dust trail particle (county road)
    img = new_img(8, 8)
    d = draw_for(img)
    ellipse(d, 4, 4, 3.5, 3, (165, 155, 135, 60))
    ellipse(d, 4, 3, 2, 2, (185, 175, 155, 40))
    wildlife["dust_trail"] = save_sprite(img, "environment/fx/dust_trail.png")

    print(f"  Generated {len(wildlife)} wildlife/particle sprites")
    return wildlife


# ---------------------------------------------------------------------------
# CATEGORY 6: Crop Field Variants
# ---------------------------------------------------------------------------

def gen_crop_tiles():
    """Generate crop field tiles for Harmon Farm."""
    print("Generating crop field tiles...")
    crops = {}

    crop_specs = [
        ("corn_bare", PAL["dirt_mid"], None),
        ("corn_young", PAL["dirt_mid"], (85, 145, 55)),
        ("corn_full", (55, 105, 42), (65, 125, 45)),
        ("corn_harvest", (155, 130, 72), (135, 110, 62)),
        ("corn_stubble", PAL["dirt_mid"], (120, 100, 65)),
        ("soybean_bare", PAL["dirt_mid"], None),
        ("soybean_young", PAL["dirt_mid"], (75, 130, 52)),
        ("soybean_mid", (65, 115, 48), (72, 125, 52)),
        ("soybean_yellow", (165, 155, 62), (145, 135, 55)),
        ("soybean_stubble", PAL["dirt_mid"], (115, 95, 58)),
        ("cover_crop", PAL["dirt_mid"], (95, 145, 62)),
    ]

    for name, ground, plant_color in crop_specs:
        img = new_img(16, 16)
        d = draw_for(img)
        rect(d, 0, 0, 16, 16, ground)
        pixel_noise(img, (0, 0, 16, 16), [vary(ground, 8)], 0.15)
        if plant_color:
            # Row pattern
            for ry in range(2, 15, 4):
                d.line([(0, ry*SS), (16*SS, ry*SS)], fill=plant_color+(200,), width=2*SS)
                pixel_noise(img, (0, ry-1, 16, 3), [vary(plant_color, 12)], 0.2)
        crops[name] = save_sprite(img, f"environment/tiles/crop_{name}.png")

    print(f"  Generated {len(crops)} crop tile sprites")
    return crops


# ---------------------------------------------------------------------------
# CATEGORY 7: NPC Placeholder Sprites (missing characters)
# ---------------------------------------------------------------------------

def gen_npc_placeholder(name, body_color, detail_color, hair_color, extra_fn=None):
    """Generate a simple top-down NPC placeholder sprite."""
    img = new_img(16, 20)
    d = draw_for(img)
    # Body
    ellipse(d, 8, 12, 5, 6, body_color)
    # Head
    ellipse(d, 8, 5, 4, 4, (195, 165, 135))  # skin tone
    # Hair
    ellipse(d, 8, 3, 4, 3, hair_color)
    # Shirt detail
    rect(d, 5, 10, 6, 4, detail_color, 180)
    if extra_fn:
        extra_fn(d, img)
    return img

def gen_npc_placeholders():
    """Generate placeholder sprites for NPCs that lack full spritesheets."""
    print("Generating NPC placeholders...")
    npcs = {}

    # Darlene Kowalski
    img = gen_npc_placeholder("darlene", (110, 85, 55), (75, 95, 68), (155, 125, 85))
    npcs["darlene"] = save_sprite(img, "npc/darlene_kowalski.png")

    # Lloyd Petersen (elderly, canvas hat)
    def lloyd_extras(d, img):
        ellipse(d, 8, 2, 5, 2, (135, 118, 82))  # canvas hat
    img = gen_npc_placeholder("lloyd", (95, 82, 58), (85, 95, 72), (175, 172, 165), lloyd_extras)
    npcs["lloyd"] = save_sprite(img, "npc/lloyd_petersen.png")

    # Terri Vogel (experienced beekeeper)
    def terri_extras(d, img):
        # Veil pushed back
        ellipse(d, 8, 2, 4.5, 2, PAL["wood_white"], 140)
    img = gen_npc_placeholder("terri", PAL["wood_white"], (120, 105, 78), (115, 72, 42), terri_extras)
    npcs["terri"] = save_sprite(img, "npc/terri_vogel.png")

    # Additional pedestrians (d, e, f)
    for i, (bc, dc, hc) in enumerate([
        ((85, 105, 125), (65, 85, 105), (55, 42, 28)),
        ((125, 95, 72), (105, 78, 55), (175, 155, 128)),
        ((95, 115, 88), (78, 95, 72), (82, 58, 38)),
    ], start=4):
        letter = chr(96 + i)  # d, e, f
        img = gen_npc_placeholder(f"ped_{letter}", bc, dc, hc)
        npcs[f"pedestrian_{letter}"] = save_sprite(img, f"npc/pedestrian_{letter}.png")

    print(f"  Generated {len(npcs)} NPC placeholder sprites")
    return npcs


# ---------------------------------------------------------------------------
# CATEGORY 8: Map Overlay & UI
# ---------------------------------------------------------------------------

def gen_map_overlay():
    """Generate the hand-drawn county map overlay."""
    print("Generating map overlay...")
    maps = {}

    # Map background (parchment)
    img = new_img(240, 180)
    d = draw_for(img)
    rounded_rect(d, 0, 0, 240, 180, 8, (225, 210, 175))
    pixel_noise(img, (0, 0, 240, 180), [(215, 198, 162), (235, 220, 185)], 0.08)
    # Border
    rect(d, 4, 4, 232, 1, PAL["wood_brown"], 120)
    rect(d, 4, 175, 232, 1, PAL["wood_brown"], 120)
    rect(d, 4, 4, 1, 172, PAL["wood_brown"], 120)
    rect(d, 235, 4, 1, 172, PAL["wood_brown"], 120)
    maps["map_bg"] = save_sprite(img, "ui/map_overlay_bg.png")

    # Location pins
    for pname, color in [
        ("pin_home", PAL["amber_light"]),
        ("pin_town", PAL["brick_red"]),
        ("pin_timber", PAL["leaf_summer"]),
        ("pin_harmon", PAL["leaf_fall_gold"]),
        ("pin_river", PAL["water_mid"]),
        ("pin_garden", PAL["bloom_pink"]),
        ("pin_locked", PAL["metal_gray"]),
    ]:
        img = new_img(8, 12)
        d = draw_for(img)
        ellipse(d, 4, 4, 3, 3, color)
        d.polygon([
            (2*SS, 6*SS), (6*SS, 6*SS), (4*SS, 12*SS)
        ], fill=color + (220,))
        ellipse(d, 4, 4, 1.5, 1.5, (255, 255, 255, 140))
        maps[pname] = save_sprite(img, f"ui/{pname}.png")

    # Padlock icon
    img = new_img(8, 10)
    d = draw_for(img)
    d.arc([(1*SS, 0), (7*SS, 6*SS)], 180, 0, fill=PAL["metal_gray"]+(200,), width=2*SS)
    rounded_rect(d, 1, 4, 6, 6, 1, PAL["metal_gray"])
    ellipse(d, 4, 6, 1, 1, PAL["metal_dark"])
    maps["padlock"] = save_sprite(img, "ui/padlock_icon.png")

    print(f"  Generated {len(maps)} map/UI sprites")
    return maps


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    random.seed(42)  # Reproducible output

    print("=" * 60)
    print("Smoke & Honey -- Location Sprite Generator")
    print("=" * 60)

    all_sprites = {}

    tiles = gen_ground_tiles()
    all_sprites.update(tiles)

    buildings = gen_buildings()
    all_sprites.update(buildings)

    trees = gen_trees()
    all_sprites.update(trees)

    props = gen_interior_props()
    all_sprites.update(props)

    wildlife = gen_wildlife()
    all_sprites.update(wildlife)

    crops = gen_crop_tiles()
    all_sprites.update(crops)

    npcs = gen_npc_placeholders()
    all_sprites.update(npcs)

    maps = gen_map_overlay()
    all_sprites.update(maps)

    print()
    print("=" * 60)
    print(f"TOTAL SPRITES GENERATED: {len(all_sprites)}")
    print("=" * 60)

    # Print summary by category
    categories = {
        "Ground Tiles": tiles,
        "Buildings": buildings,
        "Trees": trees,
        "Interior Props": props,
        "Wildlife/FX": wildlife,
        "Crop Tiles": crops,
        "NPC Placeholders": npcs,
        "Map/UI": maps,
    }
    for cat_name, cat_sprites in categories.items():
        print(f"  {cat_name}: {len(cat_sprites)}")

    return all_sprites

if __name__ == "__main__":
    main()
