#!/usr/bin/env python3
"""
Smoke & Honey -- Building Sprite Generator v5
Multi-layer compositing with individual tile/stone rendering,
ambient occlusion, architectural detail, and hue-shifted shadows.

Key improvements over v4:
- Individual overlapping roof tiles (not flat gradient + lines)
- Per-stone rendering with mortar and edge highlighting
- Wood planks with grain texture
- Detailed window frames, glass reflections, optional shutters
- Trim/fascia boards at material junctions
- Ambient occlusion at all surface contacts
- Foundation/ground contact details
- Hue-shifted shadows (toward blue/purple) and warm highlights
- Multi-layer compositing: base -> detail -> AO -> highlights
"""
from PIL import Image, ImageDraw, ImageFilter
import random, os, sys, math

# Warm dark brown outline - never pure black
OUTLINE = (72, 37, 16)

# ============================================================
# COLOR UTILITIES
# ============================================================

def rng(seed=42):
    return random.Random(seed)

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def noisy(r, color, variance=8):
    """Per-pixel color noise."""
    return tuple(clamp(c + r.randint(-variance, variance)) for c in color[:3])

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(clamp(c1[i] + (c2[i] - c1[i]) * t) for i in range(min(len(c1), len(c2), 3)))

def hue_shift_shadow(color, amount=0.15):
    """Shift shadows toward cool blue-purple (like professional pixel art)."""
    r, g, b = color[:3]
    r = clamp(r * (1 - amount * 0.3))
    g = clamp(g * (1 - amount * 0.2))
    b = clamp(b * (1 + amount * 0.15))
    return (r, g, b)

def hue_shift_highlight(color, amount=0.12):
    """Shift highlights warm (toward yellow-orange)."""
    r, g, b = color[:3]
    r = clamp(r + amount * 40)
    g = clamp(g + amount * 25)
    b = clamp(b - amount * 10)
    return (r, g, b)

def darken(color, amount=0.3):
    return tuple(clamp(c * (1 - amount)) for c in color[:3])

def lighten(color, amount=0.3):
    return tuple(clamp(c + (255 - c) * amount) for c in color[:3])


# ============================================================
# DRAWING PRIMITIVES WITH LAYERING
# ============================================================

def put_px(img, x, y, color, alpha=255):
    """Safe pixel placement with bounds checking."""
    if 0 <= x < img.width and 0 <= y < img.height:
        if alpha < 255:
            existing = img.getpixel((x, y))
            if existing[3] > 0:
                # Alpha blend
                ea = existing[3] / 255.0
                na = alpha / 255.0
                oa = na + ea * (1 - na)
                if oa > 0:
                    blended = tuple(
                        clamp((color[i] * na + existing[i] * ea * (1 - na)) / oa)
                        for i in range(3)
                    ) + (clamp(oa * 255),)
                    img.putpixel((x, y), blended)
                return
            img.putpixel((x, y), color[:3] + (alpha,))
        else:
            img.putpixel((x, y), color[:3] + (255,))


def gradient_rect(img, x1, y1, x2, y2, c_top, c_bot, r, noise_v=6, direction="v"):
    """Fill rectangle with gradient + noise."""
    if direction == "v":
        h = max(1, y2 - y1)
        for y in range(y1, y2 + 1):
            t = (y - y1) / h
            base = lerp_color(c_top, c_bot, t)
            for x in range(x1, x2 + 1):
                put_px(img, x, y, noisy(r, base, noise_v))
    else:
        w = max(1, x2 - x1)
        for x in range(x1, x2 + 1):
            t = (x - x1) / w
            base = lerp_color(c_top, c_bot, t)
            for y in range(y1, y2 + 1):
                put_px(img, x, y, noisy(r, base, noise_v))


def draw_ao_edge(img, x1, y1, x2, y2, side, depth=3, base_alpha=50):
    """Draw ambient occlusion darkening along an edge."""
    for d in range(depth):
        a = base_alpha - d * (base_alpha // depth)
        if a <= 0:
            break
        if side == "top":
            for x in range(x1, x2 + 1):
                put_px(img, x, y1 + d, (20, 15, 30), a)
        elif side == "bottom":
            for x in range(x1, x2 + 1):
                put_px(img, x, y2 - d, (20, 15, 30), a)
        elif side == "left":
            for y in range(y1, y2 + 1):
                put_px(img, x1 + d, y, (20, 15, 30), a)
        elif side == "right":
            for y in range(y1, y2 + 1):
                put_px(img, x2 - d, y, (20, 15, 30), a)


# ============================================================
# ROOF RENDERING - Individual overlapping tiles
# ============================================================

def draw_roof_tiles_3q(img, x1, wall_top, x2, peak_y, roof_hi, roof_lo, seed=42):
    """Draw 3/4 top-down roof with individually rendered overlapping tiles.
    Each tile is a small quadrilateral with its own gradient."""
    r = rng(seed)
    mid_x = (x1 + x2) // 2
    width = x2 - x1
    roof_h = wall_top - peak_y

    # Ridge at ~30% from top
    ridge_y = peak_y + int(roof_h * 0.28)

    # Tile dimensions
    tile_w = max(8, width // 14)
    tile_h = max(5, roof_h // 12)

    # === FAR SLOPE (top portion, darker, compressed) ===
    for ty in range(peak_y, ridge_y, max(2, tile_h - 2)):
        t_row = (ty - peak_y) / max(1, ridge_y - peak_y)
        # Row width expands
        half_w = int(4 + t_row * (width // 2 - 4))
        row_x1 = mid_x - half_w
        row_x2 = mid_x + half_w

        # Stagger every other row
        stagger = (tile_w // 2) if ((ty - peak_y) // tile_h) % 2 else 0

        for tx in range(row_x1 + stagger, row_x2, tile_w):
            tw = min(tile_w, row_x2 - tx)
            th = min(tile_h - 1, ridge_y - ty)
            if tw < 3 or th < 2:
                continue

            # Per-tile color variation
            t_val = r.random() * 0.3 + 0.35  # darker for far slope
            tile_base = lerp_color(roof_lo, roof_hi, t_val)
            tile_shadow = hue_shift_shadow(tile_base, 0.2)
            tile_light = hue_shift_highlight(tile_base, 0.15)

            for dy in range(th):
                for dx in range(tw):
                    if tx + dx < row_x1 or tx + dx > row_x2:
                        continue
                    # Per-pixel shading: top of tile lighter, bottom darker
                    vy = dy / max(1, th - 1)
                    hx = dx / max(1, tw - 1)
                    # Light from upper-left
                    lit = (1 - vy) * 0.6 + (1 - hx) * 0.4
                    c = lerp_color(tile_shadow, tile_light, lit * 0.7)
                    put_px(img, tx + dx, ty + dy, noisy(r, c, 4))

            # Bottom edge of tile (shadow line for overlap effect)
            for dx in range(tw):
                if tx + dx >= row_x1 and tx + dx <= row_x2:
                    put_px(img, tx + dx, ty + th - 1,
                           noisy(r, darken(tile_base, 0.25), 3))
            # Right edge shadow
            if tx + tw - 1 <= row_x2:
                for dy in range(th):
                    put_px(img, tx + tw - 1, ty + dy,
                           noisy(r, darken(tile_base, 0.15), 3))

    # === RIDGE LINE (highlight) ===
    ridge_hi = hue_shift_highlight(lerp_color(roof_hi, (210, 200, 185), 0.3), 0.2)
    half_w = width // 2 - 2
    for x in range(mid_x - half_w, mid_x + half_w):
        for dy in range(-1, 2):
            t = abs(dy) / 1.5
            c = lerp_color(ridge_hi, roof_hi, t)
            put_px(img, x, ridge_y + dy, noisy(r, c, 3))

    # === NEAR SLOPE (bottom, larger, lighter/warmer, more visible) ===
    near_tile_h = tile_h + 1  # tiles look taller on near slope (perspective)
    for ty in range(ridge_y + 2, wall_top, max(2, near_tile_h - 2)):
        t_row = (ty - ridge_y) / max(1, wall_top - ridge_y)
        half_w = width // 2 + int(t_row * 5)  # slight overhang expansion
        row_x1 = mid_x - half_w
        row_x2 = mid_x + half_w

        stagger = (tile_w // 2) if ((ty - ridge_y) // near_tile_h) % 2 else 0

        for tx in range(row_x1 + stagger, row_x2, tile_w):
            tw = min(tile_w, row_x2 - tx)
            th = min(near_tile_h, wall_top - ty)
            if tw < 3 or th < 2:
                continue

            t_val = r.random() * 0.3 + 0.5  # lighter for near slope
            tile_base = lerp_color(roof_lo, roof_hi, t_val)
            # Near slope gets warmer (more lit)
            tile_base = hue_shift_highlight(tile_base, 0.08)
            tile_shadow = hue_shift_shadow(tile_base, 0.18)
            tile_light = hue_shift_highlight(tile_base, 0.12)

            for dy in range(th):
                for dx in range(tw):
                    if tx + dx < row_x1 or tx + dx > row_x2:
                        continue
                    vy = dy / max(1, th - 1)
                    hx = dx / max(1, tw - 1)
                    lit = (1 - vy) * 0.55 + (1 - hx) * 0.45
                    c = lerp_color(tile_shadow, tile_light, lit * 0.75)
                    put_px(img, tx + dx, ty + dy, noisy(r, c, 5))

            # Bottom edge overlap shadow
            for dx in range(tw):
                if tx + dx >= row_x1 and tx + dx <= row_x2:
                    put_px(img, tx + dx, ty + th - 1,
                           noisy(r, darken(tile_base, 0.3), 3))
            # Right edge
            if tx + tw - 1 <= row_x2:
                for dy in range(th):
                    put_px(img, tx + tw - 1, ty + dy,
                           noisy(r, darken(tile_base, 0.12), 3))

    # === EAVE (bottom edge of roof, overhang shadow) ===
    eave_y = wall_top
    half_w = width // 2 + 4
    for x in range(mid_x - half_w, mid_x + half_w + 1):
        # Fascia board
        put_px(img, x, eave_y - 1, noisy(r, darken(roof_lo, 0.2), 3))
        put_px(img, x, eave_y, noisy(r, darken(roof_lo, 0.35), 3))
        # Shadow below eave
        put_px(img, x, eave_y + 1, noisy(r, (40, 30, 25), 3), 90)
        put_px(img, x, eave_y + 2, noisy(r, (40, 30, 25), 3), 50)

    # === ROOF OUTLINE (warm brown, anti-aliased) ===
    # Far slope edges
    for y in range(peak_y, ridge_y):
        t = (y - peak_y) / max(1, ridge_y - peak_y)
        hw = int(4 + t * (width // 2 - 4))
        put_px(img, mid_x - hw, y, noisy(r, OUTLINE, 3))
        put_px(img, mid_x + hw, y, noisy(r, OUTLINE, 3))
        # AA pixel
        put_px(img, mid_x - hw - 1, y, noisy(r, OUTLINE, 3), 100)
        put_px(img, mid_x + hw + 1, y, noisy(r, OUTLINE, 3), 100)

    # Near slope edges
    for y in range(ridge_y, wall_top):
        t = (y - ridge_y) / max(1, wall_top - ridge_y)
        hw = width // 2 + int(t * 5)
        put_px(img, mid_x - hw, y, noisy(r, OUTLINE, 3))
        put_px(img, mid_x + hw, y, noisy(r, OUTLINE, 3))
        put_px(img, mid_x - hw - 1, y, noisy(r, OUTLINE, 3), 80)
        put_px(img, mid_x + hw + 1, y, noisy(r, OUTLINE, 3), 80)

    # Peak outline
    for x in range(mid_x - 3, mid_x + 4):
        put_px(img, x, peak_y, noisy(r, OUTLINE, 3))


def draw_flat_roof_3q(img, x1, wall_top, x2, peak_y, roof_hi, roof_lo, seed=42):
    """Flat/low-slope roof for commercial buildings."""
    r = rng(seed)
    w = x2 - x1
    h = wall_top - peak_y

    for y in range(peak_y, wall_top):
        t = (y - peak_y) / max(1, h)
        for x in range(x1 - 2, x2 + 3):
            ht = (x - x1) / max(1, w) if w > 0 else 0
            base = lerp_color(
                hue_shift_shadow(roof_lo, 0.1),
                hue_shift_highlight(roof_hi, 0.08),
                t * 0.6 + 0.2
            )
            # Horizontal light variation
            base = lerp_color(
                hue_shift_highlight(base, 0.06),
                hue_shift_shadow(base, 0.06),
                ht
            )
            # Tile texture: subtle grid
            if (y - peak_y) % 6 < 1 and r.random() < 0.7:
                base = darken(base, 0.08)
            if (x - x1) % 8 < 1 and r.random() < 0.5:
                base = darken(base, 0.05)
            put_px(img, x, y, noisy(r, base, 5))

    # Parapet edge
    for x in range(x1 - 2, x2 + 3):
        put_px(img, x, peak_y, noisy(r, darken(roof_lo, 0.2), 3))
        put_px(img, x, peak_y + 1, noisy(r, lighten(roof_hi, 0.1), 3))

    # Eave
    for x in range(x1 - 2, x2 + 3):
        put_px(img, x, wall_top, noisy(r, darken(roof_lo, 0.3), 3))
        put_px(img, x, wall_top + 1, (40, 30, 25, 80))
        put_px(img, x, wall_top + 2, (40, 30, 25, 40))


# ============================================================
# WALL RENDERING
# ============================================================

def draw_stone_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Individual stone blocks with mortar, highlight edges, AO at contacts."""
    r = rng(seed)
    mortar = lerp_color(wall_hi, (180, 175, 165), 0.4)
    mortar_shadow = darken(mortar, 0.2)

    # Fill mortar base first
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            put_px(img, x, y, noisy(r, mortar, 3))

    # Draw individual stones
    block_h = max(4, (y2 - y1) // 4)
    row = 0
    y = y1 + 1
    while y < y2 - 1:
        bh = min(block_h + r.randint(-1, 1), y2 - y - 1)
        if bh < 3:
            break
        block_w = max(10, (x2 - x1) // 5) + r.randint(-3, 3)
        x_off = (block_w // 2 + r.randint(-2, 2)) if row % 2 else 0
        x = x1 + 1 - x_off

        while x < x2 - 1:
            bw = block_w + r.randint(-2, 3)
            bx1 = max(x, x1 + 1)
            bx2 = min(x + bw - 1, x2 - 1)
            by1 = y
            by2 = min(y + bh - 1, y2 - 1)

            if bx2 - bx1 >= 3 and by2 - by1 >= 2:
                # Per-stone color variation
                stone_t = r.random() * 0.4 + 0.3
                stone_base = lerp_color(wall_hi, wall_lo, stone_t)

                for py in range(by1, by2 + 1):
                    for px in range(bx1, bx2 + 1):
                        # Light from upper-left
                        vy = (py - by1) / max(1, by2 - by1)
                        hx = (px - bx1) / max(1, bx2 - bx1)
                        lit = (1 - vy) * 0.4 + (1 - hx) * 0.3
                        c = lerp_color(
                            hue_shift_shadow(stone_base, 0.12),
                            hue_shift_highlight(stone_base, 0.1),
                            lit
                        )
                        put_px(img, px, py, noisy(r, c, 5))

                # Top-left highlight edge
                for px in range(bx1, bx2):
                    put_px(img, px, by1, noisy(r, lighten(stone_base, 0.15), 3))
                for py in range(by1, by2):
                    put_px(img, bx1, py, noisy(r, lighten(stone_base, 0.1), 3))

                # Bottom-right shadow edge
                for px in range(bx1 + 1, bx2 + 1):
                    put_px(img, px, by2, noisy(r, darken(stone_base, 0.15), 3))
                for py in range(by1 + 1, by2 + 1):
                    put_px(img, bx2, py, noisy(r, darken(stone_base, 0.1), 3))

            x += bw + 1
        y += bh + 1
        row += 1


def draw_wood_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Horizontal wood planks with grain texture."""
    r = rng(seed)
    plank_h = max(5, (y2 - y1) // 5)
    y = y1

    while y < y2:
        ph = min(plank_h + r.randint(-1, 1), y2 - y)
        if ph < 3:
            break

        # Per-plank base color
        pt = r.random() * 0.35 + 0.3
        plank_base = lerp_color(wall_hi, wall_lo, pt)

        # Generate grain pattern for this plank
        grain_offsets = [r.gauss(0, 3) for _ in range(x2 - x1 + 1)]

        for py in range(y, y + ph):
            vy = (py - y) / max(1, ph - 1)
            for px in range(x1, x2 + 1):
                hx = (px - x1) / max(1, x2 - x1)
                # Vertical curvature (plank is slightly rounded)
                curve = abs(vy - 0.5) * 2
                # Light from upper-left
                lit = (1 - vy) * 0.3 + (1 - hx) * 0.25 + (1 - curve) * 0.15
                c = lerp_color(
                    hue_shift_shadow(plank_base, 0.1),
                    hue_shift_highlight(plank_base, 0.08),
                    lit
                )
                # Wood grain: darken along grain lines
                gi = px - x1
                if gi < len(grain_offsets):
                    grain = grain_offsets[gi]
                    if abs(grain) > 2.5:
                        c = darken(c, 0.08)
                # Knot (rare)
                if r.random() < 0.002:
                    c = darken(c, 0.15)
                put_px(img, px, py, noisy(r, c, 5))

        # Top highlight of plank
        for px in range(x1, x2 + 1):
            put_px(img, px, y, noisy(r, lighten(plank_base, 0.12), 3))

        # Gap between planks (dark groove)
        gap_c = darken(wall_lo, 0.3)
        for px in range(x1, x2 + 1):
            put_px(img, px, y + ph, noisy(r, gap_c, 3))

        y += ph + 1


def draw_brick_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Brick pattern with mortar joints."""
    r = rng(seed)
    mortar = lerp_color(wall_hi, (195, 190, 178), 0.5)
    brick_w = 12
    brick_h = 6

    # Mortar base
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            put_px(img, x, y, noisy(r, mortar, 3))

    row = 0
    y = y1 + 1
    while y + brick_h < y2:
        x_off = (brick_w // 2) if row % 2 else 0
        x = x1 + 1 - x_off
        while x + brick_w < x2:
            bx1 = max(x, x1 + 1)
            bx2 = min(x + brick_w - 2, x2 - 1)
            by1 = y
            by2 = y + brick_h - 2

            bt = r.random() * 0.35 + 0.3
            brick_c = lerp_color(wall_hi, wall_lo, bt)

            for py in range(by1, by2 + 1):
                for px in range(bx1, bx2 + 1):
                    vy = (py - by1) / max(1, by2 - by1)
                    hx = (px - bx1) / max(1, bx2 - bx1)
                    lit = (1 - vy) * 0.3 + (1 - hx) * 0.2
                    c = lerp_color(
                        hue_shift_shadow(brick_c, 0.1),
                        hue_shift_highlight(brick_c, 0.08),
                        lit
                    )
                    put_px(img, px, py, noisy(r, c, 6))

            x += brick_w
        y += brick_h
        row += 1


# ============================================================
# ARCHITECTURAL DETAILS
# ============================================================

def draw_window(img, x, y, w, h, seed=42, has_shutters=False, shutter_color=None):
    """Detailed window with frame, glass, reflection, optional shutters."""
    r = rng(seed)

    frame_c = (95, 72, 50)
    frame_hi = lighten(frame_c, 0.15)
    sill_c = lighten(frame_c, 0.2)

    # Outer frame
    for fy in range(y, y + h):
        for fx in range(x, x + w):
            edge = (fx == x or fx == x + w - 1 or fy == y or fy == y + h - 1)
            if edge:
                put_px(img, fx, fy, noisy(r, OUTLINE, 3))
            else:
                vy = (fy - y) / max(1, h)
                put_px(img, fx, fy, noisy(r, lerp_color(frame_hi, frame_c, vy), 4))

    # Glass panes
    gx1, gy1 = x + 2, y + 2
    gx2, gy2 = x + w - 3, y + h - 3
    glass_top = (110, 130, 155)  # sky reflection at top
    glass_bot = (75, 60, 45)     # warm interior glow at bottom

    for gy in range(gy1, gy2 + 1):
        t = (gy - gy1) / max(1, gy2 - gy1)
        for gx in range(gx1, gx2 + 1):
            ht = (gx - gx1) / max(1, gx2 - gx1)
            base = lerp_color(glass_top, glass_bot, t * 0.7 + ht * 0.3)
            put_px(img, gx, gy, noisy(r, base, 4))

    # Bright reflection spot (upper-left)
    put_px(img, gx1, gy1, noisy(r, (200, 210, 220), 3))
    put_px(img, gx1 + 1, gy1, noisy(r, (175, 188, 198), 3), 200)
    put_px(img, gx1, gy1 + 1, noisy(r, (175, 188, 198), 3), 180)

    # Mullion (vertical divider)
    mid_gx = (gx1 + gx2) // 2
    for gy in range(gy1, gy2 + 1):
        put_px(img, mid_gx, gy, noisy(r, frame_c, 3))

    # Horizontal divider if tall enough
    if h > 12:
        mid_gy = (gy1 + gy2) // 2
        for gx in range(gx1, gx2 + 1):
            put_px(img, gx, mid_gy, noisy(r, frame_c, 3))

    # Window sill (bottom ledge, protruding)
    for sx in range(x - 1, x + w + 1):
        put_px(img, sx, y + h, noisy(r, sill_c, 3))
        put_px(img, sx, y + h + 1, noisy(r, darken(sill_c, 0.15), 3))
    # Sill shadow
    for sx in range(x, x + w):
        put_px(img, sx, y + h + 2, noisy(r, (40, 30, 25), 3), 50)

    # Shutters
    if has_shutters and shutter_color:
        sw = max(3, w // 3)
        sh_hi = shutter_color
        sh_lo = darken(shutter_color, 0.25)
        for sy in range(y + 1, y + h - 1):
            t = (sy - y) / max(1, h)
            # Left shutter
            for sx in range(x - sw - 1, x - 1):
                ht = (sx - (x - sw - 1)) / max(1, sw)
                c = lerp_color(sh_hi, sh_lo, ht * 0.5 + t * 0.3)
                put_px(img, sx, sy, noisy(r, c, 4))
            # Right shutter
            for sx in range(x + w + 1, x + w + sw + 1):
                ht = (sx - (x + w + 1)) / max(1, sw)
                c = lerp_color(sh_lo, sh_hi, ht * 0.5 - t * 0.2 + 0.3)
                put_px(img, sx, sy, noisy(r, c, 4))

        # Shutter slats (horizontal lines)
        for sy in range(y + 3, y + h - 2, 3):
            for sx in range(x - sw, x - 1):
                put_px(img, sx, sy, noisy(r, darken(sh_lo, 0.15), 3))
            for sx in range(x + w + 1, x + w + sw):
                put_px(img, sx, sy, noisy(r, darken(sh_lo, 0.15), 3))


def draw_door(img, x, y, w, h, seed=42, has_steps=True, step_color=None):
    """Detailed door with panels, frame, hardware, optional steps."""
    r = rng(seed)
    door_hi = (135, 105, 68)
    door_lo = (78, 55, 32)
    frame_c = (72, 52, 32)

    # Door frame (recessed)
    for fy in range(y - 1, y + h + 1):
        put_px(img, x - 1, fy, noisy(r, frame_c, 3))
        put_px(img, x + w, fy, noisy(r, frame_c, 3))
    for fx in range(x - 1, x + w + 1):
        put_px(img, fx, y - 1, noisy(r, frame_c, 3))

    # Door body
    for dy in range(y, y + h):
        t = (dy - y) / max(1, h)
        for dx in range(x, x + w):
            ht = (dx - x) / max(1, w)
            base = lerp_color(door_hi, door_lo, t * 0.35 + ht * 0.25)
            # Hue shift
            if t > 0.5:
                base = hue_shift_shadow(base, 0.05)
            put_px(img, dx, dy, noisy(r, base, 5))

    # Panel detail (upper and lower recessed panels)
    pw = w - 6
    ph_upper = h // 3 - 2
    ph_lower = h // 2 - 2
    if pw > 4 and ph_upper > 3:
        px = x + 3
        # Upper panel
        py = y + 3
        panel_c = darken(door_lo, 0.1)
        for pdy in range(py, py + ph_upper):
            for pdx in range(px, px + pw):
                put_px(img, pdx, pdy, noisy(r, panel_c, 4))
            # Panel edge highlight
            put_px(img, px, pdy, noisy(r, lighten(door_hi, 0.1), 3))
        for pdx in range(px, px + pw):
            put_px(img, pdx, py, noisy(r, lighten(door_hi, 0.08), 3))

        # Lower panel
        py2 = py + ph_upper + 3
        if py2 + ph_lower < y + h - 2:
            for pdy in range(py2, py2 + ph_lower):
                for pdx in range(px, px + pw):
                    put_px(img, pdx, pdy, noisy(r, panel_c, 4))
                put_px(img, px, pdy, noisy(r, lighten(door_hi, 0.1), 3))
            for pdx in range(px, px + pw):
                put_px(img, pdx, py2, noisy(r, lighten(door_hi, 0.08), 3))

    # Door outline
    for dx in range(x, x + w):
        put_px(img, dx, y, noisy(r, OUTLINE, 3))
        put_px(img, dx, y + h - 1, noisy(r, OUTLINE, 3))
    for dy in range(y, y + h):
        put_px(img, x, dy, noisy(r, OUTLINE, 3))
        put_px(img, x + w - 1, dy, noisy(r, OUTLINE, 3))

    # Doorknob
    kx = x + w - 5
    ky = y + h // 2
    knob_c = (195, 170, 90)
    put_px(img, kx, ky, noisy(r, knob_c, 4))
    put_px(img, kx + 1, ky, noisy(r, darken(knob_c, 0.2), 4))
    put_px(img, kx, ky + 1, noisy(r, darken(knob_c, 0.15), 4))

    # Steps
    if has_steps:
        sc = step_color or (155, 148, 135)
        for step_i in range(2):
            sy = y + h + step_i * 3
            sw = w + 4 + step_i * 4
            sx = x - 2 - step_i * 2
            for sdy in range(sy, sy + 3):
                for sdx in range(sx, sx + sw):
                    t = (sdy - sy) / 3
                    c = lerp_color(lighten(sc, 0.08), darken(sc, 0.1), t)
                    put_px(img, sdx, sdy, noisy(r, c, 4))
            # Step edge
            for sdx in range(sx, sx + sw):
                put_px(img, sdx, sy, noisy(r, lighten(sc, 0.15), 3))


def draw_chimney(img, x, y, w, h, seed=42):
    """Chimney with individual stone rendering."""
    r = rng(seed)
    stone_hi = (148, 140, 125)
    stone_lo = (90, 84, 72)
    mortar = lerp_color(stone_hi, (175, 170, 160), 0.4)

    # Mortar base
    for dy in range(y, y + h):
        for dx in range(x, x + w):
            put_px(img, dx, dy, noisy(r, mortar, 3))

    # Individual stones
    sh = 4
    row = 0
    sy = y + 1
    while sy + sh < y + h:
        sw = max(5, w // 2) + r.randint(-1, 2)
        x_off = (sw // 2) if row % 2 else 0
        sx = x + 1 - x_off
        while sx < x + w - 1:
            actual_sw = min(sw, x + w - 1 - sx)
            if actual_sw < 3:
                break
            bx1 = max(sx, x + 1)
            bx2 = min(sx + actual_sw - 1, x + w - 2)
            by1 = sy
            by2 = min(sy + sh - 1, y + h - 2)

            st = r.random() * 0.35 + 0.3
            sc = lerp_color(stone_hi, stone_lo, st)
            for py in range(by1, by2 + 1):
                for px in range(bx1, bx2 + 1):
                    vy = (py - by1) / max(1, by2 - by1)
                    hx = (px - bx1) / max(1, bx2 - bx1)
                    lit = (1 - vy) * 0.3 + (1 - hx) * 0.25
                    c = lerp_color(darken(sc, 0.1), lighten(sc, 0.1), lit)
                    put_px(img, px, py, noisy(r, c, 4))

            sx += actual_sw + 1
        sy += sh + 1
        row += 1

    # Cap
    for dx in range(x - 1, x + w + 1):
        put_px(img, dx, y, noisy(r, lighten(stone_hi, 0.1), 3))
        put_px(img, dx, y + 1, noisy(r, stone_hi, 3))

    # Dark interior opening
    for dx in range(x + 2, x + w - 2):
        put_px(img, dx, y + 2, noisy(r, (30, 22, 18), 3))
        put_px(img, dx, y + 3, noisy(r, (25, 18, 15), 3))

    # Outline
    for dx in range(x, x + w):
        put_px(img, dx, y, noisy(r, OUTLINE, 3))
        put_px(img, dx, y + h - 1, noisy(r, OUTLINE, 3))
    for dy in range(y, y + h):
        put_px(img, x, dy, noisy(r, OUTLINE, 3))
        put_px(img, x + w - 1, dy, noisy(r, OUTLINE, 3))


def draw_trim_board(img, x1, y, x2, thickness, color, seed=42):
    """Horizontal trim/fascia board at material junctions."""
    r = rng(seed)
    hi = lighten(color, 0.12)
    lo = darken(color, 0.15)
    for ty in range(y, y + thickness):
        t = (ty - y) / max(1, thickness)
        for tx in range(x1, x2 + 1):
            c = lerp_color(hi, lo, t)
            put_px(img, tx, ty, noisy(r, c, 4))
    # Outline top and bottom
    for tx in range(x1, x2 + 1):
        put_px(img, tx, y, noisy(r, OUTLINE, 3), 150)


def draw_sign(img, x, y, w, h, text_lines, bg_color, text_color, seed=42):
    """Simple rectangular sign (no font rendering, just colored block)."""
    r = rng(seed)
    # Sign background
    for sy in range(y, y + h):
        for sx in range(x, x + w):
            put_px(img, sx, sy, noisy(r, bg_color, 4))
    # Border
    for sx in range(x, x + w):
        put_px(img, sx, y, noisy(r, darken(bg_color, 0.3), 3))
        put_px(img, sx, y + h - 1, noisy(r, darken(bg_color, 0.3), 3))
    for sy in range(y, y + h):
        put_px(img, x, sy, noisy(r, darken(bg_color, 0.3), 3))
        put_px(img, x + w - 1, sy, noisy(r, darken(bg_color, 0.3), 3))
    # Text simulation: horizontal bars
    ty = y + 3
    for line in text_lines:
        line_w = min(len(line) * 2, w - 6)
        lx = x + (w - line_w) // 2
        for sx in range(lx, lx + line_w):
            put_px(img, sx, ty, noisy(r, text_color, 3))
            if h > 10:
                put_px(img, sx, ty + 1, noisy(r, text_color, 3))
        ty += 4


def draw_awning(img, x1, y, x2, stripe_c1, stripe_c2, seed=42):
    """Striped awning over storefront."""
    r = rng(seed)
    aw_h = 10
    for ay in range(y, y + aw_h):
        t = (ay - y) / aw_h
        stripe = ((ay - y) // 3) % 2
        for ax in range(x1, x2 + 1):
            if stripe:
                c = noisy(r, lerp_color(stripe_c1, darken(stripe_c1, 0.15), t), 5)
            else:
                c = noisy(r, lerp_color(stripe_c2, darken(stripe_c2, 0.1), t), 4)
            put_px(img, ax, ay, c)
    # Scalloped bottom edge
    for ax in range(x1, x2 + 1):
        wave = int(math.sin((ax - x1) * 0.5) * 1.5) + aw_h
        put_px(img, ax, y + min(wave, aw_h + 1), noisy(r, darken(stripe_c1, 0.3), 3))
    # Shadow below awning
    for ax in range(x1, x2 + 1):
        put_px(img, ax, y + aw_h + 1, (30, 22, 18, 70))
        put_px(img, ax, y + aw_h + 2, (30, 22, 18, 35))


def draw_foundation(img, x1, y, x2, h, seed=42):
    """Stone foundation strip at ground level."""
    r = rng(seed)
    found_hi = (128, 122, 112)
    found_lo = (82, 78, 70)
    for fy in range(y, y + h):
        t = (fy - y) / max(1, h)
        for fx in range(x1, x2 + 1):
            c = lerp_color(found_hi, found_lo, t * 0.6)
            put_px(img, fx, fy, noisy(r, c, 4))
    # Top edge highlight
    for fx in range(x1, x2 + 1):
        put_px(img, fx, y, noisy(r, lighten(found_hi, 0.1), 3))


def draw_bush(img, x, y, w, h, seed=42):
    """Small decorative bush at building base."""
    r = rng(seed)
    bush_hi = (68, 95, 48)
    bush_lo = (38, 58, 28)
    cx, cy = x + w // 2, y + h // 2

    for by in range(y, y + h):
        for bx in range(x, x + w):
            # Elliptical shape
            dx = (bx - cx) / max(1, w / 2)
            dy = (by - cy) / max(1, h / 2)
            dist = dx * dx + dy * dy
            if dist < 1.0:
                # Shading
                lit = (1 - (by - y) / h) * 0.4 + (1 - (bx - x) / w) * 0.3
                c = lerp_color(bush_lo, bush_hi, lit + r.random() * 0.2)
                a = 255 if dist < 0.7 else int(255 * (1 - (dist - 0.7) / 0.3))
                put_px(img, bx, by, noisy(r, c, 6), a)

    # Highlight dots (leaf clusters)
    for _ in range(3):
        hx = x + r.randint(2, w - 3)
        hy = y + r.randint(1, h // 2)
        put_px(img, hx, hy, noisy(r, lighten(bush_hi, 0.2), 4))


def add_ground_shadow(img, alpha=55):
    """Soft drop shadow extending below and to the right of the building."""
    bb = img.getbbox()
    if not bb:
        return img
    result = img.copy()
    shadow_offset_x = 3
    shadow_offset_y = 2

    for x in range(bb[0], bb[2]):
        for y in range(bb[3] - 1, bb[3] + 5):
            dy = y - bb[3] + 1
            a = max(0, alpha - dy * 12)
            if a > 0:
                put_px(result, x + shadow_offset_x, y + shadow_offset_y,
                       (20, 15, 25), a)
    return result


# ============================================================
# COLOR PALETTES
# ============================================================

ROOF_SLATE = ((145, 138, 128), (82, 75, 68))
ROOF_BROWN = ((158, 118, 78), (88, 62, 42))
ROOF_RED = ((162, 92, 65), (92, 52, 35))
ROOF_GRAY = ((152, 148, 142), (92, 88, 82))
ROOF_GREEN = ((88, 108, 72), (48, 62, 38))

WALL_STONE = ((168, 160, 145), (112, 105, 92))
WALL_WOOD = ((162, 132, 92), (92, 68, 45))
WALL_CREAM = ((202, 195, 178), (148, 142, 128))
WALL_BRICK = ((162, 98, 75), (98, 58, 42))
WALL_RED_BARN = ((155, 65, 45), (88, 38, 25))

SHUTTER_GREEN = (62, 85, 52)
SHUTTER_BLUE = (58, 72, 95)
SHUTTER_BROWN = (92, 68, 45)


# ============================================================
# BUILDING DEFINITIONS
# ============================================================

def make_crossroads_diner(out_dir):
    """Crossroads Diner: large commercial building, flat roof, awning, big windows."""
    W, H = 260, 210
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # Wall area
    wx1, wy1, wx2, wy2 = 22, 142, 238, 190

    # Foundation
    draw_foundation(img, wx1 - 2, wy2, wx2 + 2, 5, seed=1001)

    # Wall (brick)
    draw_brick_wall(img, wx1, wy1, wx2, wy2, WALL_BRICK[0], WALL_BRICK[1], seed=1002)

    # Trim board at roof-wall junction
    draw_trim_board(img, wx1 - 2, wy1 - 3, wx2 + 2, 3, (115, 88, 58), seed=1003)

    # Flat roof
    draw_flat_roof_3q(img, wx1, wy1 - 3, wx2, 18, ROOF_SLATE[0], ROOF_SLATE[1], seed=1004)

    # Awning over wall
    draw_awning(img, wx1 + 5, wy1 + 2, wx2 - 5, (175, 58, 42), (232, 225, 210), seed=1005)

    # Windows (large diner windows)
    for wx in [wx1 + 14, wx1 + 44, wx2 - 56, wx2 - 26]:
        draw_window(img, wx, wy1 + 16, 16, 20, seed=1010 + wx)

    # Door
    draw_door(img, (wx1 + wx2) // 2 - 9, wy1 + 14, 18, 32,
              seed=1020, step_color=(155, 148, 135))

    # Sign above awning
    draw_sign(img, (wx1 + wx2) // 2 - 30, wy1 - 14, 60, 10,
              ["CROSSROADS", "DINER"], (42, 35, 28), (215, 195, 145), seed=1030)

    # Chimney
    draw_chimney(img, wx2 - 30, 8, 16, 24, seed=1040)

    # Bushes at base
    draw_bush(img, wx1 + 5, wy2 + 2, 14, 8, seed=1050)
    draw_bush(img, wx2 - 18, wy2 + 2, 14, 8, seed=1051)

    # Wall outline
    r = rng(1060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    # AO at roof-wall junction
    draw_ao_edge(img, wx1, wy1 + 2, wx2, wy1 + 6, "top", 4, 45)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "crossroads_diner.png"))
    print(f"  crossroads_diner.png ({W}x{H})")


def make_feed_supply(out_dir):
    """Peterson's Feed & Supply: wood building, peaked brown roof."""
    W, H = 220, 200
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 18, 135, 202, 182

    draw_foundation(img, wx1 - 1, wy2, wx2 + 1, 4, seed=2001)
    draw_wood_wall(img, wx1, wy1, wx2, wy2, WALL_WOOD[0], WALL_WOOD[1], seed=2002)
    draw_trim_board(img, wx1 - 1, wy1 - 2, wx2 + 1, 2, (105, 82, 52), seed=2003)

    # Peaked roof with tiles
    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 14, ROOF_BROWN[0], ROOF_BROWN[1], seed=2004)

    # Windows with shutters
    draw_window(img, wx1 + 14, wy1 + 8, 14, 18, seed=2010,
                has_shutters=True, shutter_color=SHUTTER_GREEN)
    draw_window(img, wx2 - 28, wy1 + 8, 14, 18, seed=2011,
                has_shutters=True, shutter_color=SHUTTER_GREEN)

    # Door
    draw_door(img, (wx1 + wx2) // 2 - 8, wy1 + 6, 16, 30, seed=2020)

    # Sign
    draw_sign(img, (wx1 + wx2) // 2 - 35, wy1 + 1, 70, 8,
              ["FEED & SUPPLY"], (62, 48, 32), (195, 178, 135), seed=2030)

    draw_bush(img, wx1 - 2, wy2 + 1, 12, 7, seed=2050)
    draw_bush(img, wx2 - 10, wy2 + 1, 12, 7, seed=2051)

    r = rng(2060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 3, 40)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "feed_supply.png"))
    print(f"  feed_supply.png ({W}x{H})")


def make_post_office(out_dir):
    """Cedar Bend Post Office: stone walls, gray peaked roof, flag."""
    W, H = 200, 180
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 18, 122, 182, 162

    draw_foundation(img, wx1 - 1, wy2, wx2 + 1, 4, seed=3001)
    draw_stone_wall(img, wx1, wy1, wx2, wy2, WALL_STONE[0], WALL_STONE[1], seed=3002)
    draw_trim_board(img, wx1 - 1, wy1 - 2, wx2 + 1, 2, (118, 112, 98), seed=3003)

    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 16, ROOF_GRAY[0], ROOF_GRAY[1], seed=3004)

    draw_window(img, wx1 + 12, wy1 + 6, 14, 18, seed=3010,
                has_shutters=True, shutter_color=SHUTTER_BLUE)
    draw_window(img, wx2 - 26, wy1 + 6, 14, 18, seed=3011,
                has_shutters=True, shutter_color=SHUTTER_BLUE)

    draw_door(img, (wx1 + wx2) // 2 - 8, wy1 + 5, 16, 28, seed=3020)

    draw_chimney(img, wx2 - 24, 8, 14, 20, seed=3040)

    # Flag pole (simple)
    r = rng(3070)
    pole_x = wx1 + 8
    for py in range(wy1 - 30, wy1 + 2):
        put_px(img, pole_x, py, noisy(r, (145, 140, 132), 3))
    # Flag
    for fy in range(wy1 - 28, wy1 - 18):
        for fx in range(pole_x + 1, pole_x + 10):
            t = (fx - pole_x) / 10
            c = lerp_color((165, 42, 38), (180, 55, 48), t)
            put_px(img, fx, fy, noisy(r, c, 4))

    draw_bush(img, wx1 - 3, wy2 + 1, 10, 6, seed=3050)
    draw_bush(img, wx2 - 8, wy2 + 1, 10, 6, seed=3051)

    r = rng(3060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 3, 40)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "post_office.png"))
    print(f"  post_office.png ({W}x{H})")


def make_grange_hall(out_dir):
    """Cedar Valley Grange: large community hall, cream walls, red roof."""
    W, H = 260, 210
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 16, 142, 244, 190

    draw_foundation(img, wx1 - 2, wy2, wx2 + 2, 5, seed=4001)
    draw_stone_wall(img, wx1, wy1, wx2, wy2, WALL_CREAM[0], WALL_CREAM[1], seed=4002)
    draw_trim_board(img, wx1 - 2, wy1 - 3, wx2 + 2, 3, (128, 108, 78), seed=4003)

    draw_roof_tiles_3q(img, wx1, wy1 - 3, wx2, 12, ROOF_RED[0], ROOF_RED[1], seed=4004)

    # Multiple windows
    win_positions = [wx1 + 12, wx1 + 40, wx1 + 68, wx2 - 80, wx2 - 52, wx2 - 24]
    for i, wx in enumerate(win_positions):
        draw_window(img, wx, wy1 + 6, 14, 18, seed=4010 + i,
                    has_shutters=True, shutter_color=SHUTTER_GREEN)

    # Double doors
    draw_door(img, (wx1 + wx2) // 2 - 12, wy1 + 4, 10, 32, seed=4020, has_steps=False)
    draw_door(img, (wx1 + wx2) // 2 + 2, wy1 + 4, 10, 32, seed=4021, has_steps=False)
    # Shared steps
    r = rng(4025)
    step_x = (wx1 + wx2) // 2 - 16
    step_w = 32
    for si in range(3):
        sy = wy1 + 36 + si * 3
        sw = step_w + si * 4
        sx = step_x - si * 2
        for sdy in range(sy, sy + 3):
            for sdx in range(sx, sx + sw):
                t = (sdy - sy) / 3
                c = lerp_color((162, 155, 142), (128, 122, 110), t)
                put_px(img, sdx, sdy, noisy(r, c, 4))

    draw_bush(img, wx1 - 4, wy2 + 2, 14, 8, seed=4050)
    draw_bush(img, wx1 + 14, wy2 + 2, 12, 7, seed=4052)
    draw_bush(img, wx2 - 24, wy2 + 2, 14, 8, seed=4051)
    draw_bush(img, wx2 - 6, wy2 + 2, 12, 7, seed=4053)

    r = rng(4060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 4, 45)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "grange_hall.png"))
    print(f"  grange_hall.png ({W}x{H})")


def make_farmhouse(out_dir):
    """Player's farmhouse: cream clapboard, gray roof, porch."""
    W, H = 230, 195
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 16, 130, 214, 175

    draw_foundation(img, wx1 - 1, wy2, wx2 + 1, 4, seed=5001)
    draw_wood_wall(img, wx1, wy1, wx2, wy2, WALL_CREAM[0], WALL_CREAM[1], seed=5002)
    draw_trim_board(img, wx1 - 1, wy1 - 2, wx2 + 1, 2, (138, 128, 108), seed=5003)

    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 12, ROOF_GRAY[0], ROOF_GRAY[1], seed=5004)

    draw_window(img, wx1 + 14, wy1 + 8, 14, 18, seed=5010,
                has_shutters=True, shutter_color=SHUTTER_BLUE)
    draw_window(img, wx2 - 28, wy1 + 8, 14, 18, seed=5011,
                has_shutters=True, shutter_color=SHUTTER_BLUE)

    draw_door(img, (wx1 + wx2) // 2 - 8, wy1 + 6, 16, 30, seed=5020)
    draw_chimney(img, wx1 + 18, 5, 14, 20, seed=5040)

    draw_bush(img, wx1 - 3, wy2 + 1, 12, 7, seed=5050)
    draw_bush(img, wx1 + 12, wy2 + 1, 10, 6, seed=5052)
    draw_bush(img, wx2 - 20, wy2 + 1, 12, 7, seed=5051)

    r = rng(5060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 3, 40)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "farmhouse.png"))
    print(f"  farmhouse.png ({W}x{H})")


def make_harmon_farmhouse(out_dir):
    """Larger two-story farmhouse with porch."""
    W, H = 260, 210
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 14, 138, 246, 190

    draw_foundation(img, wx1 - 2, wy2, wx2 + 2, 5, seed=6001)
    draw_stone_wall(img, wx1, wy1, wx2, wy2, WALL_CREAM[0], WALL_CREAM[1], seed=6002)
    draw_trim_board(img, wx1 - 2, wy1 - 3, wx2 + 2, 3, (128, 115, 88), seed=6003)

    draw_roof_tiles_3q(img, wx1, wy1 - 3, wx2, 10, ROOF_RED[0], ROOF_RED[1], seed=6004)

    for i, wx in enumerate([wx1 + 16, wx1 + 52, wx2 - 66, wx2 - 30]):
        draw_window(img, wx, wy1 + 7, 16, 20, seed=6010 + i,
                    has_shutters=True, shutter_color=SHUTTER_GREEN)

    draw_door(img, (wx1 + wx2) // 2 - 9, wy1 + 5, 18, 34, seed=6020)
    draw_chimney(img, wx2 - 32, 2, 16, 22, seed=6040)

    draw_bush(img, wx1 - 4, wy2 + 2, 14, 8, seed=6050)
    draw_bush(img, wx2 - 12, wy2 + 2, 14, 8, seed=6051)

    r = rng(6060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 4, 45)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "harmon_farmhouse.png"))
    print(f"  harmon_farmhouse.png ({W}x{H})")


def make_harmon_barn(out_dir):
    """Red barn with large sliding doors."""
    W, H = 240, 200
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 14, 132, 226, 182

    draw_foundation(img, wx1 - 2, wy2, wx2 + 2, 5, seed=7001)
    draw_wood_wall(img, wx1, wy1, wx2, wy2, WALL_RED_BARN[0], WALL_RED_BARN[1], seed=7002)
    draw_trim_board(img, wx1 - 2, wy1 - 2, wx2 + 2, 2, (112, 82, 55), seed=7003)

    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 10, ROOF_SLATE[0], ROOF_SLATE[1], seed=7004)

    # Large barn door opening
    r = rng(7020)
    door_w = 36
    dx = (wx1 + wx2) // 2 - door_w // 2
    dy = wy1 + 3
    dh = wy2 - dy - 2
    # Dark interior
    for bdy in range(dy, dy + dh):
        for bdx in range(dx, dx + door_w):
            t = (bdy - dy) / dh
            c = lerp_color((35, 25, 18), (22, 15, 10), t)
            put_px(img, bdx, bdy, noisy(r, c, 3))
    # Door frame
    for bdx in range(dx - 1, dx + door_w + 1):
        put_px(img, bdx, dy - 1, noisy(r, (92, 68, 42), 3))
    for bdy in range(dy, dy + dh):
        put_px(img, dx - 1, bdy, noisy(r, (92, 68, 42), 3))
        put_px(img, dx + door_w, bdy, noisy(r, (92, 68, 42), 3))

    # Sliding door track
    for bdx in range(dx - 3, dx + door_w + 3):
        put_px(img, bdx, dy - 2, noisy(r, (75, 72, 68), 3))

    # X-brace on wall (barn detail)
    for i in range(min(wy2 - wy1, wx2 - wx1) // 3):
        # Left X
        lx = wx1 + 5 + i
        ly = wy1 + 5 + i
        put_px(img, lx, ly, noisy(r, darken(WALL_RED_BARN[0], 0.2), 3))
        # Right X
        rx = wx2 - 5 - i
        put_px(img, rx, ly, noisy(r, darken(WALL_RED_BARN[0], 0.2), 3))

    r = rng(7060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 3, 40)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "harmon_barn.png"))
    print(f"  harmon_barn.png ({W}x{H})")


def make_background_strip(out_dir):
    """Background silhouette buildings - faded/desaturated for depth."""
    W, H = 440, 120
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(8000)

    buildings = [
        (10, 55, 65, 70, 105, ROOF_GRAY, WALL_CREAM, "peaked"),
        (80, 50, 145, 65, 105, ROOF_BROWN, WALL_STONE, "peaked"),
        (160, 45, 210, 60, 105, ROOF_RED, WALL_WOOD, "peaked"),
        (225, 50, 295, 65, 105, ROOF_SLATE, WALL_STONE, "flat"),
        (310, 40, 360, 55, 105, ROOF_GRAY, WALL_CREAM, "peaked"),
        (375, 48, 430, 62, 105, ROOF_BROWN, WALL_WOOD, "peaked"),
    ]

    for i, (bx1, peak, bx2, wt, wb, roof, wall, style) in enumerate(buildings):
        bw = bx2 - bx1 + 20
        bh = wb - peak + 20
        b = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))

        bwx1, bwy1, bwx2, bwy2 = 5, wt - peak + 5, bw - 5, bh - 5
        bpeak = 5

        if style == "peaked":
            draw_roof_tiles_3q(b, bwx1, bwy1, bwx2, bpeak,
                               roof[0], roof[1], seed=8100 + i * 100)
        else:
            draw_flat_roof_3q(b, bwx1, bwy1, bwx2, bpeak,
                              roof[0], roof[1], seed=8100 + i * 100)

        draw_stone_wall(b, bwx1, bwy1, bwx2, bwy2,
                        wall[0], wall[1], seed=8200 + i * 100)

        # Desaturate for atmospheric depth
        for y in range(b.height):
            for x in range(b.width):
                p = b.getpixel((x, y))
                if p[3] > 0:
                    # Fade toward sky blue
                    sky = (178, 188, 198)
                    faded = lerp_color(p[:3], sky, 0.35)
                    b.putpixel((x, y), faded + (p[3],))

        img.paste(b, (bx1, peak - 5), b)

    img.save(os.path.join(out_dir, "background_strip.png"))
    print(f"  background_strip.png ({W}x{H})")


def make_market_stall(out_dir):
    """Market stall with awning and display goods."""
    W, H = 150, 120
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(9000)

    # Counter
    counter_y = H - 35
    for y in range(counter_y, counter_y + 18):
        t = (y - counter_y) / 18
        for x in range(18, W - 18):
            base = lerp_color((152, 122, 85), (95, 75, 50), t)
            ht = (x - 18) / (W - 36)
            base = lerp_color(hue_shift_highlight(base, 0.05),
                              hue_shift_shadow(base, 0.05), ht)
            put_px(img, x, y, noisy(r, base, 5))

    # Counter top edge
    for x in range(16, W - 16):
        put_px(img, x, counter_y, noisy(r, lighten((152, 122, 85), 0.15), 3))

    # Posts with grain
    for px_pos in [16, W - 20]:
        for y in range(20, H - 12):
            for dx in range(4):
                t = dx / 4
                base = lerp_color((132, 102, 72), (85, 65, 45), t)
                put_px(img, px_pos + dx, y, noisy(r, base, 4))

    # Awning
    draw_awning(img, 12, 14, W - 12, (172, 55, 40), (228, 220, 205), seed=9005)

    # Display items (jars, produce, honey)
    item_data = [
        ((200, 162, 65), 3),   # honey jars
        ((118, 148, 78), 4),   # produce
        ((180, 85, 58), 3),    # preserves
        ((165, 145, 95), 3),   # bread
    ]
    ix = 25
    for color, count in item_data:
        for c in range(count):
            iy = counter_y - 10
            iw = 8 + r.randint(-1, 2)
            ih = 6 + r.randint(-1, 2)
            for dy in range(iy, iy + ih):
                for dx in range(ix, ix + iw):
                    t = (dy - iy) / ih
                    c_item = lerp_color(lighten(color, 0.1), darken(color, 0.1), t)
                    put_px(img, dx, dy, noisy(r, c_item, 5))
            ix += iw + 3
        ix += 5

    img.save(os.path.join(out_dir, "market_stall.png"))
    print(f"  market_stall.png ({W}x{H})")


def make_fairgrounds_gate(out_dir):
    """Fairgrounds entrance gate with arch."""
    W, H = 220, 150
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(10000)
    mid = W // 2

    # Gate posts (thick, with detail)
    for px_pos in [mid - 30, mid + 22]:
        for y in range(22, H - 12):
            for dx in range(10):
                t = dx / 10
                base = lerp_color((142, 112, 75), (82, 62, 42), t)
                # Vertical grain
                if r.random() < 0.08:
                    base = darken(base, 0.1)
                put_px(img, px_pos + dx, y, noisy(r, base, 5))
        # Post cap
        for y in range(18, 24):
            for dx in range(-2, 13):
                c = lerp_color((155, 128, 92), (112, 88, 62), (y - 18) / 6)
                put_px(img, px_pos + dx, y, noisy(r, c, 4))

    # Arch beam
    for y in range(12, 22):
        t = (y - 12) / 10
        for x in range(mid - 34, mid + 34):
            ht = (x - (mid - 34)) / 68
            base = lerp_color(
                lerp_color((148, 118, 82), (95, 75, 52), t),
                lerp_color((135, 108, 75), (88, 68, 45), t),
                ht
            )
            put_px(img, x, y, noisy(r, base, 5))

    # Sign on arch
    draw_sign(img, mid - 28, 5, 56, 8, ["FAIRGROUNDS"],
              (55, 42, 28), (205, 188, 138), seed=10030)

    # Fence sections
    for section in [(8, mid - 34), (mid + 36, W - 8)]:
        sx, ex = section
        # Horizontal rails
        for fy in [42, 62, H - 22]:
            for fx in range(sx, ex):
                put_px(img, fx, fy, noisy(r, (112, 88, 62), 5))
                put_px(img, fx, fy + 1, noisy(r, (95, 75, 52), 4))
        # Vertical pickets
        for fx in range(sx, ex, 6):
            for fy in range(38, H - 15):
                put_px(img, fx, fy, noisy(r, (125, 98, 68), 5))
                put_px(img, fx + 1, fy, noisy(r, (108, 85, 58), 4))

    img.save(os.path.join(out_dir, "fairgrounds_gate.png"))
    print(f"  fairgrounds_gate.png ({W}x{H})")


def make_water_tower(out_dir):
    """Water tower: cylindrical tank on legs."""
    W, H = 85, 155
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(11000)
    cx = W // 2
    tank_w, tank_h = 48, 44
    tx1 = cx - tank_w // 2
    ty1 = 8
    ty2 = ty1 + tank_h

    # Tank cylinder with proper cylindrical shading
    for y in range(ty1, ty2):
        t_v = (y - ty1) / tank_h
        for x in range(tx1, tx1 + tank_w):
            t_h = (x - tx1) / tank_w
            # Cylindrical: bright at ~35% from left, dark at edges
            cyl = 1.0 - math.exp(-((t_h - 0.35) ** 2) * 8)
            base = lerp_color(
                hue_shift_highlight((178, 172, 162), 0.08),
                hue_shift_shadow((102, 98, 90), 0.1),
                min(1, cyl * 0.8 + t_v * 0.2)
            )
            put_px(img, x, y, noisy(r, base, 4))

    # Metal bands
    for by in [ty1 + 8, ty1 + 22, ty1 + 36]:
        for x in range(tx1, tx1 + tank_w):
            t_h = (x - tx1) / tank_w
            cyl = abs(t_h - 0.35) * 1.5
            band_c = lerp_color((108, 104, 96), (72, 68, 62), min(1, cyl))
            put_px(img, x, by, noisy(r, band_c, 3))
            put_px(img, x, by + 1, noisy(r, darken(band_c, 0.1), 3))

    # Tank top (elliptical, visible from above)
    for x in range(tx1 + 3, tx1 + tank_w - 3):
        for dy in range(3):
            t = (x - tx1) / tank_w
            c = lerp_color((168, 162, 152), (128, 122, 112), t)
            put_px(img, x, ty1 - dy, noisy(r, c, 3))

    # Legs
    leg_bot = H - 10
    leg_data = [
        (cx - 22, cx - 16), (cx - 8, cx - 5),
        (cx + 5, cx + 5), (cx + 18, cx + 16)
    ]
    for bot_x, top_x in leg_data:
        for y in range(ty2, leg_bot):
            t = (y - ty2) / (leg_bot - ty2)
            x = int(top_x + (bot_x - top_x) * t)
            for dx in range(3):
                lt = dx / 3
                c = lerp_color((115, 110, 102), (78, 75, 68), lt)
                put_px(img, x + dx, y, noisy(r, c, 4))

    # Cross bracing
    for y in range(ty2 + 15, ty2 + 18):
        for x in range(cx - 18, cx + 18):
            put_px(img, x, y, noisy(r, (95, 90, 82), 4))

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "water_tower.png"))
    print(f"  water_tower.png ({W}x{H})")


def make_grain_bins(out_dir):
    """Two metal grain silos."""
    W, H = 150, 165
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(12000)

    for sx, sw, sh in [(15, 52, 130), (80, 56, 140)]:
        st = H - sh
        sb = H - 12

        # Cylinder body
        for y in range(st, sb):
            t_v = (y - st) / (sb - st)
            for x in range(sx, sx + sw):
                t_h = (x - sx) / sw
                cyl = 1.0 - math.exp(-((t_h - 0.35) ** 2) * 8)
                base = lerp_color(
                    hue_shift_highlight((175, 170, 160), 0.06),
                    hue_shift_shadow((100, 96, 88), 0.08),
                    min(1, cyl * 0.75 + t_v * 0.15)
                )
                put_px(img, x, y, noisy(r, base, 4))

        # Bands
        for by in range(st + 6, sb, 10):
            for x in range(sx, sx + sw):
                t_h = (x - sx) / sw
                cyl = abs(t_h - 0.35) * 1.5
                band = lerp_color((88, 84, 78), (62, 58, 52), min(1, cyl))
                put_px(img, x, by, noisy(r, band, 3))

        # Cone top
        mid = sx + sw // 2
        cone_h = 14
        for y in range(st - cone_h, st):
            t = (y - (st - cone_h)) / cone_h
            hw = int(t * sw // 2)
            for x in range(mid - hw, mid + hw + 1):
                t_h = (x - (mid - hw)) / max(1, hw * 2)
                base = lerp_color((162, 158, 148), (105, 100, 92), t_h * 0.6 + (1-t) * 0.3)
                put_px(img, x, y, noisy(r, base, 4))

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "grain_bins.png"))
    print(f"  grain_bins.png ({W}x{H})")


def make_simple_building(out_dir, filename, w, h, roof, wall, wall_mat, seed,
                         extra_features=None):
    """Helper for simpler buildings with full detail."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    wx1 = 14
    wy1 = int(h * 0.64)
    wx2 = w - 14
    wy2 = h - 18

    draw_foundation(img, wx1 - 1, wy2, wx2 + 1, 4, seed=seed + 1)

    if wall_mat == "stone":
        draw_stone_wall(img, wx1, wy1, wx2, wy2, wall[0], wall[1], seed=seed + 2)
    elif wall_mat == "wood":
        draw_wood_wall(img, wx1, wy1, wx2, wy2, wall[0], wall[1], seed=seed + 2)
    elif wall_mat == "brick":
        draw_brick_wall(img, wx1, wy1, wx2, wy2, wall[0], wall[1], seed=seed + 2)

    draw_trim_board(img, wx1 - 1, wy1 - 2, wx2 + 1, 2, darken(wall[0], 0.15), seed=seed + 3)
    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 10, roof[0], roof[1], seed=seed + 4)

    # Windows
    draw_window(img, wx1 + 10, wy1 + 6, 12, 16, seed=seed + 10,
                has_shutters=True, shutter_color=SHUTTER_BROWN)
    draw_window(img, wx2 - 22, wy1 + 6, 12, 16, seed=seed + 11,
                has_shutters=True, shutter_color=SHUTTER_BROWN)

    draw_door(img, (wx1 + wx2) // 2 - 7, wy1 + 5, 14, 26, seed=seed + 20)

    draw_bush(img, wx1 - 2, wy2 + 1, 10, 6, seed=seed + 50)
    draw_bush(img, wx2 - 8, wy2 + 1, 10, 6, seed=seed + 51)

    r = rng(seed + 60)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, OUTLINE, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, OUTLINE, 3))
        put_px(img, wx2, y, noisy(r, OUTLINE, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 3, 40)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, filename))
    print(f"  {filename} ({w}x{h})")


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/buildings_v5"
    os.makedirs(out_dir, exist_ok=True)

    print("Generating v5 buildings (multi-layer, individual tiles, AO, details)...")
    make_crossroads_diner(out_dir)
    make_feed_supply(out_dir)
    make_post_office(out_dir)
    make_grange_hall(out_dir)
    make_farmhouse(out_dir)
    make_harmon_farmhouse(out_dir)
    make_harmon_barn(out_dir)
    make_background_strip(out_dir)
    make_market_stall(out_dir)
    make_fairgrounds_gate(out_dir)
    make_water_tower(out_dir)
    make_grain_bins(out_dir)

    make_simple_building(out_dir, "machine_shed.png", 185, 145,
                         ROOF_SLATE, ((152, 148, 140), (95, 92, 85)),
                         "stone", 13000)
    make_simple_building(out_dir, "harwick_office.png", 190, 160,
                         ROOF_GRAY, WALL_STONE, "stone", 14000)
    make_simple_building(out_dir, "shed_exterior.png", 145, 135,
                         ROOF_BROWN, WALL_WOOD, "wood", 15000)

    print("Done! All v5 buildings generated.")
