#!/usr/bin/env python3
"""
Procedural Bee Sprite Generator -- Smoke and Honey "Find the Queen"
=================================================================
Generates high-fidelity top-down bee spritesheets for all 5 in-game breeds,
both worker and queen variants.

Breeds:  Italian, Carniolan, Russian, Buckfast, Caucasian
Roles:   Worker (nurse bee) + Queen per breed
Output:  10 spritesheets + 10 previews + 10 close-ups

Real bee anatomy reference (top-down view):
  - Worker: 12-15mm, compact round body, wings cover abdomen, fuzzy thorax
  - Queen:  18-22mm, elongated abdomen extends well past wings, less fuzzy,
            legs splayed wider, shinier dorsum

Key shape corrections from v1:
  - MUCH wider body -- bees are plump, nearly as wide as they are long
  - Rounder thorax (almost circular from above)
  - Abdomen is a fat teardrop, not a skinny oval
  - Wings only reach halfway down abdomen on queen
  - Worker wings cover most of abdomen
  - Head is wide with very large compound eyes
  - Legs splay outward broadly

Sprite spec:
  - Cell: 48x36 px (wider than v1 to accommodate correct proportions)
  - Directions: 8 (E, NE, N, NW, W, SW, S, SE)
  - Frames: 4 walk cycle + 3 idle = 7
  - Superscale: 5x internal for smooth anti-aliased downscale

Usage:
  python generate_nurse_bee.py                    # all breeds, workers + queens
  python generate_nurse_bee.py --breed italian    # single breed
  python generate_nurse_bee.py --role queen       # queens only
"""

import argparse
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CELL_W, CELL_H = 60, 42          # wide enough for queen abdomen + rotation room
WALK_FRAMES    = 4
IDLE_FRAMES    = 3
TOTAL_FRAMES   = WALK_FRAMES + IDLE_FRAMES
DIRECTIONS     = 8
SUPERSCALE     = 5

DIR_ANGLES = [0, 45, 90, 135, 180, 225, 270, 315]
DIR_NAMES  = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]

# ---------------------------------------------------------------------------
# Breed color palettes
# ---------------------------------------------------------------------------
# Each breed defines the key colors that distinguish it visually.
# Based on real-world honeybee race coloring:
#   Italian:   bright golden-yellow bands, light brown thorax
#   Carniolan: dusky grey-brown bands, dark grey thorax
#   Russian:   very dark brown/black, muted pale bands
#   Buckfast:  warm amber-orange bands, medium brown thorax (variable)
#   Caucasian: silvery-grey bands, dark thorax, slightly blue-grey sheen

BREED_PALETTES = {
    "italian": {
        "name":           "Italian",
        "head":           (70, 48, 25),
        "eye":            (18, 12, 8),
        "eye_highlight":  (95, 80, 60),
        "thorax":         (85, 60, 32),
        "thorax_hair":    (130, 105, 65),
        "abdomen_dark":   (60, 40, 18),
        "abdomen_band1":  (215, 170, 55),     # bright golden
        "abdomen_band2":  (195, 150, 45),
        "abdomen_tip":    (70, 50, 28),
        "leg":            (65, 48, 30),
        "leg_joint":      (90, 68, 42),
        "antenna":        (60, 42, 25),
        "antenna_tip":    (90, 70, 40),
        "wing_fill":      (95, 98, 108),      # dark translucent grey
        "wing_edge":      (78, 82, 94),
        "wing_vein":      (62, 66, 80),
    },
    "carniolan": {
        "name":           "Carniolan",
        "head":           (45, 38, 32),
        "eye":            (15, 10, 8),
        "eye_highlight":  (75, 65, 55),
        "thorax":         (55, 48, 40),
        "thorax_hair":    (95, 85, 72),
        "abdomen_dark":   (40, 34, 28),
        "abdomen_band1":  (140, 120, 90),     # dusky grey-brown
        "abdomen_band2":  (120, 105, 80),
        "abdomen_tip":    (50, 42, 35),
        "leg":            (50, 42, 35),
        "leg_joint":      (72, 62, 48),
        "antenna":        (48, 40, 32),
        "antenna_tip":    (70, 60, 45),
        "wing_fill":      (90, 94, 105),
        "wing_edge":      (74, 78, 92),
        "wing_vein":      (60, 64, 78),
    },
    "russian": {
        "name":           "Russian",
        "head":           (35, 25, 18),
        "eye":            (12, 8, 5),
        "eye_highlight":  (65, 55, 42),
        "thorax":         (40, 30, 22),
        "thorax_hair":    (75, 62, 48),
        "abdomen_dark":   (30, 22, 15),
        "abdomen_band1":  (110, 90, 60),      # muted pale
        "abdomen_band2":  (95, 78, 52),
        "abdomen_tip":    (38, 28, 20),
        "leg":            (42, 32, 22),
        "leg_joint":      (62, 50, 36),
        "antenna":        (38, 28, 20),
        "antenna_tip":    (60, 48, 32),
        "wing_fill":      (85, 90, 102),
        "wing_edge":      (70, 75, 88),
        "wing_vein":      (56, 62, 76),
    },
    "buckfast": {
        "name":           "Buckfast",
        "head":           (62, 42, 22),
        "eye":            (16, 11, 7),
        "eye_highlight":  (88, 72, 55),
        "thorax":         (72, 52, 28),
        "thorax_hair":    (115, 92, 58),
        "abdomen_dark":   (52, 36, 18),
        "abdomen_band1":  (200, 145, 50),     # warm amber-orange
        "abdomen_band2":  (180, 128, 42),
        "abdomen_tip":    (62, 45, 25),
        "leg":            (58, 42, 28),
        "leg_joint":      (82, 62, 40),
        "antenna":        (55, 38, 24),
        "antenna_tip":    (82, 64, 38),
        "wing_fill":      (92, 96, 108),
        "wing_edge":      (76, 80, 94),
        "wing_vein":      (62, 68, 82),
    },
    "caucasian": {
        "name":           "Caucasian",
        "head":           (48, 42, 38),
        "eye":            (14, 10, 8),
        "eye_highlight":  (78, 70, 62),
        "thorax":         (58, 52, 46),
        "thorax_hair":    (100, 92, 82),
        "abdomen_dark":   (42, 38, 32),
        "abdomen_band1":  (150, 140, 120),    # silvery grey
        "abdomen_band2":  (130, 122, 105),
        "abdomen_tip":    (52, 46, 40),
        "leg":            (52, 46, 38),
        "leg_joint":      (75, 66, 55),
        "antenna":        (50, 44, 36),
        "antenna_tip":    (72, 64, 52),
        "wing_fill":      (88, 92, 104),
        "wing_edge":      (72, 77, 90),
        "wing_vein":      (58, 64, 78),
    },
}

# Shadow color (shared)
SHADOW = (0, 0, 0, 28)

# ---------------------------------------------------------------------------
# Rendering helpers
# ---------------------------------------------------------------------------

def _ss(v):
    """Scale a value to superscale resolution."""
    if isinstance(v, (list, tuple)):
        return tuple(int(round(x * SUPERSCALE)) for x in v)
    return int(round(v * SUPERSCALE))


def draw_ellipse(draw, cx, cy, rx, ry, fill, outline=None):
    """Draw an ellipse at logical coordinates, rendered at superscale."""
    scx, scy, srx, sry = _ss(cx), _ss(cy), _ss(rx), _ss(ry)
    bbox = [scx - srx, scy - sry, scx + srx, scy + sry]
    draw.ellipse(bbox, fill=fill, outline=outline)


def draw_line(draw, x1, y1, x2, y2, fill, width=1):
    """Draw a line at logical coordinates, rendered at superscale."""
    draw.line([_ss(x1), _ss(y1), _ss(x2), _ss(y2)],
              fill=fill, width=max(1, _ss(width)))


def draw_poly(draw, points, fill, outline=None):
    """Draw a polygon at logical coordinates."""
    scaled = [(_ss(x), _ss(y)) for x, y in points]
    draw.polygon(scaled, fill=fill, outline=outline)


# ---------------------------------------------------------------------------
# Bee body renderers -- correct top-down proportions
# ---------------------------------------------------------------------------
# Real bee from above: head is wide (big eyes bulge out), thorax is nearly
# circular and very fuzzy, abdomen is a fat rounded teardrop widest near
# the thorax junction and tapering to the tip.
#
# Queen differences: abdomen is ~40% longer, extends well past wing tips,
# slightly less fuzzy (shinier), legs splay wider, moves more deliberately.
# ---------------------------------------------------------------------------

def render_abdomen(draw, pal, cx, cy, frame_idx, is_idle, is_queen):
    """
    Fat teardrop abdomen with 4-5 alternating stripe bands.
    Queen abdomen: longer, slightly narrower relative to length, tapers more.
    Worker abdomen: rounder, plumper, wings cover most of it.
    """
    bob = 0
    if not is_idle:
        bob = [0, -0.4, 0, 0.4][frame_idx % 4]

    if is_queen:
        # Queen: subtly longer abdomen -- just enough to notice if you're looking
        # Not dramatically different; the real tell is wings ending early
        # Shifted left slightly so tip stays well inside cell boundary
        ax = cx + 9.0
        ay = cy + bob
        rx = 14.5    # ~45% longer than worker, subtle at sprite scale
        ry = 9.2     # slightly narrower ratio gives elongated look
    else:
        # Worker: short and FAT -- bees are very round from above
        ax = cx + 6.5
        ay = cy + bob
        rx = 10.0
        ry = 10.0    # as wide as long -- proper chonky bee

    # Shadow
    draw_ellipse(draw, ax + 0.6, ay + 1.2, rx + 0.3, ry + 0.3, SHADOW)

    # Base dark fill
    draw_ellipse(draw, ax, ay, rx, ry, pal["abdomen_dark"])

    # Tapered tip overlay (makes teardrop shape)
    tip_x = ax + rx * 0.7
    tip_rx = rx * 0.35
    tip_ry = ry * 0.55
    draw_ellipse(draw, tip_x, ay, tip_rx, tip_ry, pal["abdomen_tip"])

    # Stripe bands across abdomen
    num_bands = 5 if is_queen else 4
    band_start = ax - rx * 0.55
    band_spacing = (rx * 1.0) / num_bands
    colors = [pal["abdomen_band1"], pal["abdomen_band2"]]

    for i in range(num_bands):
        bx = band_start + i * band_spacing
        color = colors[i % 2]
        band_rx = 1.6

        # Band height follows ellipse contour
        t = (bx - (ax - rx)) / (2 * rx)
        t = max(0.05, min(0.95, t))
        band_ry = ry * math.sin(math.pi * t) * 0.82
        if band_ry > 1.0:
            draw_ellipse(draw, bx, ay, band_rx, band_ry, color)

    # Fine hair dots along the body edge
    rng = random.Random(42 + frame_idx + (100 if is_queen else 0))
    hair_count = 6 if is_queen else 10  # queen is shinier/less fuzzy
    for _ in range(hair_count):
        angle = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.65, 0.92)
        hx = ax + math.cos(angle) * rx * dist
        hy = ay + math.sin(angle) * ry * dist
        draw_ellipse(draw, hx, hy, 0.45, 0.45, pal["thorax_hair"])


def render_thorax(draw, pal, cx, cy, is_queen):
    """
    Nearly circular thorax -- bees have a very round midsection from above.
    Covered in dense fuzzy hair (more on workers, less on queens).
    """
    tx = cx - 2.5
    ty = cy

    if is_queen:
        trx = 6.5
        try_ = 7.0
    else:
        # Worker thorax is big and round -- bees look like fuzzy balls
        trx = 7.0
        try_ = 7.5

    # Shadow
    draw_ellipse(draw, tx + 0.4, ty + 1.0, trx + 0.2, try_ + 0.2, SHADOW)

    # Main thorax body
    draw_ellipse(draw, tx, ty, trx, try_, pal["thorax"])

    # Dense fuzzy hair tufts -- the thorax is notably furry from above
    rng = random.Random(999)
    hair_count = 18 if not is_queen else 12   # queen less fuzzy
    for _ in range(hair_count):
        angle = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.3, 0.88)
        hx = tx + math.cos(angle) * trx * dist
        hy = ty + math.sin(angle) * try_ * dist
        size = rng.uniform(0.6, 1.1)
        draw_ellipse(draw, hx, hy, size, size * 0.85, pal["thorax_hair"])


def render_head(draw, pal, cx, cy, frame_idx, is_idle, is_queen):
    """
    Wide head with huge bulging compound eyes -- bee heads are very wide
    relative to their length because the eyes protrude sideways.
    """
    hx = cx - 11.5 if not is_queen else cx - 12.0
    hy = cy

    # Antenna twitch on idle
    twitch = 0
    if is_idle:
        twitch = [-0.8, 0, 0.8][frame_idx % 3]

    # Shadow
    draw_ellipse(draw, hx + 0.3, hy + 0.8, 5.2, 6.2, SHADOW)

    # Main head capsule -- wider than tall (eyes bulge out the sides)
    draw_ellipse(draw, hx, hy, 4.8, 5.8, pal["head"])

    # Compound eyes -- LARGE, bulging outward on each side
    # These are the most prominent feature from above
    eye_y_off = 4.0
    eye_rx = 2.4
    eye_ry = 2.8
    draw_ellipse(draw, hx - 0.5, hy - eye_y_off, eye_rx, eye_ry, pal["eye"])
    draw_ellipse(draw, hx - 0.5, hy + eye_y_off, eye_rx, eye_ry, pal["eye"])

    # Eye highlights (specular)
    draw_ellipse(draw, hx - 1.2, hy - eye_y_off - 0.5, 0.6, 0.7, pal["eye_highlight"])
    draw_ellipse(draw, hx - 1.2, hy + eye_y_off - 0.5, 0.6, 0.7, pal["eye_highlight"])

    # Mandibles -- short, angled forward
    draw_line(draw, hx - 4.0, hy - 1.5, hx - 6.0, hy - 0.5, pal["head"], 0.7)
    draw_line(draw, hx - 4.0, hy + 1.5, hx - 6.0, hy + 0.5, pal["head"], 0.7)

    # Antennae -- two segmented feelers extending forward and outward
    # They're elbowed: scape (straight out) then flagellum (angled)
    for side in [-1, 1]:
        base_y = hy + 2.5 * side
        # Scape (first segment, angled forward-outward)
        mid_x = hx - 7.0
        mid_y = base_y + (3.5 * side) + twitch * side
        draw_line(draw, hx - 3.5, base_y, mid_x, mid_y, pal["antenna"], 0.55)
        # Flagellum (second segment, curves further out)
        end_x = hx - 10.0
        end_y = mid_y + (2.5 * side) + twitch * 0.5 * side
        draw_line(draw, mid_x, mid_y, end_x, end_y, pal["antenna"], 0.45)
        # Tip club
        draw_ellipse(draw, end_x, end_y, 0.55, 0.5, pal["antenna_tip"])


def render_legs(draw, pal, cx, cy, frame_idx, is_idle, is_queen):
    """
    3 pairs of legs splaying outward broadly. From above, bee legs spread
    wide -- they're not tucked under. Queen legs splay even wider.
    """
    tx = cx - 2.5  # thorax center

    # Leg pairs: (attach_x, splay_angle_base, reach)
    # splay_angle is degrees from straight-sideways (90 = perpendicular to body)
    leg_defs = [
        (tx - 4.0,  35,  7.5),   # front: angle forward
        (tx - 0.5,  10,  8.5),   # middle: nearly perpendicular
        (tx + 3.5, -20,  7.5),   # rear: angle backward
    ]

    splay_extra = 1.2 if is_queen else 0  # queen legs spread wider

    # Tripod gait
    if is_idle:
        phases = [0, 0, 0]
    else:
        phase = frame_idx % 4
        phases = [phase, (phase + 2) % 4, phase]

    for i, (attach_x, base_angle, reach) in enumerate(leg_defs):
        p = phases[i]
        # Stride offsets for walking animation
        if is_idle:
            stride_angle = 0
            stride_reach = 0
        else:
            stride_angle = [5, -5, -5, 5][p]
            stride_reach = [-0.5, 0.5, 0.5, -0.5][p]

        for side in [-1, 1]:   # -1 = top of sprite, +1 = bottom
            angle_deg = (90 + base_angle + stride_angle) * side
            angle_rad = math.radians(angle_deg)
            total_reach = reach + splay_extra + stride_reach

            # Attachment point on thorax edge
            ax = attach_x
            ay = cy

            # Knee joint (halfway out, slightly bent)
            knee_dist = total_reach * 0.5
            knee_bend = 1.5 * side  # bend direction
            kx = ax + math.cos(angle_rad) * knee_dist * 0.3 + knee_bend * 0.2
            ky = ay + math.sin(angle_rad) * knee_dist

            # Foot (tarsus)
            fx = ax + math.cos(angle_rad) * total_reach * 0.3
            fy = ay + math.sin(angle_rad) * total_reach

            # Draw leg segments
            draw_line(draw, ax, ay, kx, ky, pal["leg"], 0.6)
            draw_line(draw, kx, ky, fx, fy, pal["leg"], 0.5)
            draw_ellipse(draw, kx, ky, 0.5, 0.5, pal["leg_joint"])
            draw_ellipse(draw, fx, fy, 0.4, 0.35, pal["leg"])


def render_wings(draw, pal, cx, cy, frame_idx, is_idle, is_queen):
    """
    Wings fold back over the abdomen.
    Worker: wings cover most of abdomen -- you see wing texture over the stripes.
    Queen:  wings only reach about halfway -- her long abdomen sticks out past them.
    This is the KEY visual difference for queen-spotting.
    """
    # Wing origin is at thorax-abdomen junction
    wx = cx + 1.5
    wy = cy

    flutter = 0
    if is_idle and frame_idx == 1:
        flutter = 1.0

    if is_queen:
        wing_length = 10.0   # shorter relative to abdomen
        wing_width = 5.5
    else:
        wing_length = 13.0   # covers most of abdomen
        wing_width = 6.5

    for side in [-1, 1]:
        wing_y = wy + 1.8 * side - flutter * side * 0.5

        # Forewing (larger, front)
        fw_points = [
            (wx - 3.0,  wing_y + 0.5 * side),
            (wx - 1.0,  wing_y + wing_width * side),
            (wx + wing_length * 0.6, wing_y + (wing_width + 0.5) * side),
            (wx + wing_length, wing_y + (wing_width * 0.5) * side),
            (wx + wing_length * 0.9, wing_y + 0.3 * side),
        ]
        draw_poly(draw, fw_points, pal["wing_fill"], pal["wing_edge"])

        # Hindwing (smaller, partially behind forewing)
        hw_x = wx + 1.0
        hw_len = wing_length * 0.55
        hw_w = wing_width * 0.7
        hw_points = [
            (hw_x,            wing_y + 1.0 * side),
            (hw_x + 1.0,     wing_y + (hw_w + 1.5) * side),
            (hw_x + hw_len,   wing_y + (hw_w + 1.0) * side),
            (hw_x + hw_len,   wing_y + 0.8 * side),
        ]
        draw_poly(draw, hw_points, pal["wing_fill"])

        # Wing venation on forewing
        # Main longitudinal vein
        draw_line(draw, wx - 1, wing_y + 1.5 * side,
                  wx + wing_length * 0.85, wing_y + 2.0 * side,
                  pal["wing_vein"], 0.3)
        # Cross veins
        for frac in [0.3, 0.55, 0.75]:
            vx = wx + wing_length * frac
            draw_line(draw, vx, wing_y + 0.8 * side,
                      vx + 1.5, wing_y + wing_width * 0.8 * side,
                      pal["wing_vein"], 0.25)


# ---------------------------------------------------------------------------
# Full bee compositor
# ---------------------------------------------------------------------------

def render_bee_frame(pal, frame_idx, is_idle, is_queen):
    """
    Render a single bee frame facing East at superscale, return as RGBA Image
    at final CELL_W x CELL_H resolution.
    """
    sw = CELL_W * SUPERSCALE
    sh = CELL_H * SUPERSCALE
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Center of bee -- offset slightly right so head/antennae have room left
    # Extra room on the right for queen's longer abdomen
    cx = CELL_W / 2 + 0.5
    cy = CELL_H / 2

    # Render back-to-front: legs, abdomen, wings, thorax, head
    render_legs(draw, pal, cx, cy, frame_idx, is_idle, is_queen)
    render_abdomen(draw, pal, cx, cy, frame_idx, is_idle, is_queen)
    render_wings(draw, pal, cx, cy, frame_idx, is_idle, is_queen)
    render_thorax(draw, pal, cx, cy, is_queen)
    render_head(draw, pal, cx, cy, frame_idx, is_idle, is_queen)

    # Downscale with LANCZOS for smooth anti-aliasing
    final = img.resize((CELL_W, CELL_H), Image.LANCZOS)
    return final


def rotate_sprite(img, angle_deg):
    """Rotate sprite and crop back to cell size."""
    if angle_deg == 0:
        return img.copy()

    diag = int(math.ceil(math.sqrt(CELL_W**2 + CELL_H**2)))
    pad = diag // 2 + 6
    padded = Image.new("RGBA", (CELL_W + pad * 2, CELL_H + pad * 2), (0, 0, 0, 0))
    padded.paste(img, (pad, pad), img)

    rotated = padded.rotate(angle_deg, resample=Image.BICUBIC, expand=False)

    rcx = rotated.width // 2
    rcy = rotated.height // 2
    left = rcx - CELL_W // 2
    top = rcy - CELL_H // 2
    return rotated.crop((left, top, left + CELL_W, top + CELL_H))


# ---------------------------------------------------------------------------
# Spritesheet assembly
# ---------------------------------------------------------------------------

def generate_spritesheet(pal, is_queen=False):
    """
    Full spritesheet: 8 directions (rows) x 7 frames (cols).
    Cols 0-3: walk, Cols 4-6: idle.
    """
    sheet_w = TOTAL_FRAMES * CELL_W
    sheet_h = DIRECTIONS * CELL_H
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    # Render all frames facing East
    east_frames = []
    for f in range(WALK_FRAMES):
        east_frames.append(render_bee_frame(pal, f, is_idle=False, is_queen=is_queen))
    for f in range(IDLE_FRAMES):
        east_frames.append(render_bee_frame(pal, f, is_idle=True, is_queen=is_queen))

    # Rotate for each direction
    for d, angle in enumerate(DIR_ANGLES):
        for f, base in enumerate(east_frames):
            rotated = rotate_sprite(base, angle)
            sheet.paste(rotated, (f * CELL_W, d * CELL_H), rotated)

    return sheet


def generate_preview(sheet, scale=5):
    """Enlarged preview with grid and labels."""
    pw = sheet.width * scale
    ph = sheet.height * scale
    preview = sheet.resize((pw, ph), Image.NEAREST)
    draw = ImageDraw.Draw(preview)

    grid_color = (100, 100, 100, 100)
    for d in range(DIRECTIONS + 1):
        y = d * CELL_H * scale
        draw.line([(0, y), (pw, y)], fill=grid_color, width=1)
    for f in range(TOTAL_FRAMES + 1):
        x = f * CELL_W * scale
        draw.line([(x, 0), (x, ph)], fill=grid_color, width=1)

    for d, name in enumerate(DIR_NAMES):
        draw.text((4, d * CELL_H * scale + 3), name, fill=(255, 255, 255, 180))
    labels = ["W0", "W1", "W2", "W3", "I0", "I1", "I2"]
    for f, label in enumerate(labels):
        draw.text((f * CELL_W * scale + 4, 3), label, fill=(255, 255, 255, 180))

    return preview


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate bee spritesheets for all breeds")
    parser.add_argument("--breed", type=str, default="all",
                        choices=["all"] + list(BREED_PALETTES.keys()),
                        help="Which breed to generate (default: all)")
    parser.add_argument("--role", type=str, default="all",
                        choices=["all", "worker", "queen"],
                        help="Which role to generate (default: all)")
    parser.add_argument("--scale", type=int, default=3,
                        help="Preview enlargement scale (default: 3)")
    parser.add_argument("--outdir", type=str, default=None,
                        help="Output directory")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    out_dir = Path(args.outdir) if args.outdir else script_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    breeds = list(BREED_PALETTES.keys()) if args.breed == "all" else [args.breed]
    roles = ["worker", "queen"] if args.role == "all" else [args.role]

    print(f"Bee Sprite Generator v2")
    print(f"  Cell size:   {CELL_W}x{CELL_H} px")
    print(f"  Superscale:  {SUPERSCALE}x")
    print(f"  Directions:  {DIRECTIONS}")
    print(f"  Frames:      {WALK_FRAMES} walk + {IDLE_FRAMES} idle = {TOTAL_FRAMES}")
    print(f"  Breeds:      {', '.join(breeds)}")
    print(f"  Roles:       {', '.join(roles)}")
    print(f"  Output:      {out_dir}")
    print()

    for breed_key in breeds:
        pal = BREED_PALETTES[breed_key]
        breed_name = pal["name"]

        for role in roles:
            is_queen = (role == "queen")
            tag = f"{breed_key}_{role}"
            print(f"  [{breed_name} {role.capitalize()}]")

            sheet = generate_spritesheet(pal, is_queen=is_queen)
            sheet_path = out_dir / f"{tag}_spritesheet.png"
            sheet.save(str(sheet_path))
            print(f"    Spritesheet: {sheet_path.name}  ({sheet.width}x{sheet.height})")

            preview = generate_preview(sheet, scale=args.scale)
            preview_path = out_dir / f"{tag}_preview.png"
            preview.save(str(preview_path))
            print(f"    Preview:     {preview_path.name}")

            # 8x close-up of walk frame 0
            closeup = render_bee_frame(pal, 0, is_idle=False, is_queen=is_queen)
            closeup_big = closeup.resize((CELL_W * 8, CELL_H * 8), Image.NEAREST)
            closeup_path = out_dir / f"{tag}_closeup_8x.png"
            closeup_big.save(str(closeup_path))
            print(f"    Close-up:    {closeup_path.name}")

    # Comparison sheet: all workers side by side, then all queens
    print(f"\n  Generating breed comparison sheet...")
    scale_comp = 6
    comp_w = CELL_W * len(breeds)
    comp_h = CELL_H * 2  # row 0: workers, row 1: queens
    comp = Image.new("RGBA", (comp_w * scale_comp, comp_h * scale_comp), (30, 30, 30, 255))
    for i, breed_key in enumerate(BREED_PALETTES.keys()):
        pal = BREED_PALETTES[breed_key]
        worker = render_bee_frame(pal, 0, False, False)
        queen = render_bee_frame(pal, 0, False, True)
        w_big = worker.resize((CELL_W * scale_comp, CELL_H * scale_comp), Image.NEAREST)
        q_big = queen.resize((CELL_W * scale_comp, CELL_H * scale_comp), Image.NEAREST)
        comp.paste(w_big, (i * CELL_W * scale_comp, 0), w_big)
        comp.paste(q_big, (i * CELL_W * scale_comp, CELL_H * scale_comp), q_big)

    comp_draw = ImageDraw.Draw(comp)
    for i, breed_key in enumerate(BREED_PALETTES.keys()):
        name = BREED_PALETTES[breed_key]["name"]
        x = i * CELL_W * scale_comp + 6
        comp_draw.text((x, 4), f"{name} Worker", fill=(255, 255, 255, 220))
        comp_draw.text((x, CELL_H * scale_comp + 4), f"{name} Queen", fill=(255, 200, 200, 220))

    comp_path = out_dir / "breed_comparison.png"
    comp.save(str(comp_path), optimize=True)
    print(f"    Comparison:  {comp_path.name}  ({comp.width}x{comp.height})")

    # Queen-only comparison: all 5 queen breeds side by side with worker below
    # for easy visual comparison of queen differences across species
    print(f"  Generating queen species comparison...")
    qscale = 8
    qcomp_cell_w = CELL_W * qscale
    qcomp_cell_h = CELL_H * qscale
    padding = 8
    label_h = 20
    col_w = qcomp_cell_w + padding
    all_breeds = list(BREED_PALETTES.keys())
    qcomp_w = col_w * len(all_breeds) + padding
    qcomp_h = label_h + qcomp_cell_h + padding + label_h + qcomp_cell_h + padding + label_h
    qcomp = Image.new("RGBA", (qcomp_w, qcomp_h), (25, 22, 18, 255))
    qd = ImageDraw.Draw(qcomp)

    # Header row labels
    for i, bk in enumerate(all_breeds):
        name = BREED_PALETTES[bk]["name"]
        x = padding + i * col_w
        # Queen row
        qd.text((x + 4, 4), f"{name} Queen", fill=(255, 180, 180, 230))
        queen_frame = render_bee_frame(BREED_PALETTES[bk], 0, False, True)
        q_big = queen_frame.resize((qcomp_cell_w, qcomp_cell_h), Image.NEAREST)
        qcomp.paste(q_big, (x, label_h), q_big)
        # Worker row
        y2 = label_h + qcomp_cell_h + padding
        qd.text((x + 4, y2), f"{name} Worker", fill=(200, 220, 255, 230))
        worker_frame = render_bee_frame(BREED_PALETTES[bk], 0, False, False)
        w_big = worker_frame.resize((qcomp_cell_w, qcomp_cell_h), Image.NEAREST)
        qcomp.paste(w_big, (x, y2 + label_h), w_big)

    # Bottom note
    note_y = qcomp_h - label_h + 4
    qd.text((padding, note_y),
            "Queens: longer abdomen past wings, less fuzzy, legs splay wider",
            fill=(180, 170, 150, 200))

    qcomp_path = out_dir / "queen_species_comparison.png"
    qcomp.save(str(qcomp_path), optimize=True)
    print(f"    Queen comp:  {qcomp_path.name}  ({qcomp.width}x{qcomp.height})")

    print(f"\nDone! Output in {out_dir}")


if __name__ == "__main__":
    main()
