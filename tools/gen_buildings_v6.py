#!/usr/bin/env python3
"""
Smoke & Honey -- Building Sprite Generator v6
Block-level fidelity overhaul. Every 32x32 block should read as rich
as the Cainos Village Pack reference.

Key improvements over v5:
- Larger individual roof tiles with 5-6 color shades per tile
- Wider mortar gaps (2-3px) with visible depth
- Bigger stones with rounded highlight curves (beveled look)
- Wood planks with visible knots, deeper grain, plank-gap shadows
- Bricks with wide color variation between individual bricks
- Stronger contrast range (highlight to shadow) within each element
- Outline color derived from local material hue (not uniform brown)
"""
from PIL import Image, ImageDraw, ImageFilter
import random, os, sys, math

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
    """Shift shadows toward cool blue-purple."""
    r, g, b = color[:3]
    r = clamp(r * (1 - amount * 0.4))
    g = clamp(g * (1 - amount * 0.25))
    b = clamp(b * (1 + amount * 0.2))
    return (r, g, b)

def hue_shift_highlight(color, amount=0.12):
    """Shift highlights warm (toward yellow-orange)."""
    r, g, b = color[:3]
    r = clamp(r + amount * 50)
    g = clamp(g + amount * 30)
    b = clamp(b - amount * 15)
    return (r, g, b)

def darken(color, amount=0.3):
    return tuple(clamp(c * (1 - amount)) for c in color[:3])

def lighten(color, amount=0.3):
    return tuple(clamp(c + (255 - c) * amount) for c in color[:3])

def outline_from_hue(color, amount=0.55):
    """Derive outline from the darkest shade of the local material hue."""
    return hue_shift_shadow(darken(color, amount), 0.2)


# ============================================================
# DRAWING PRIMITIVES
# ============================================================

def put_px(img, x, y, color, alpha=255):
    """Safe pixel placement with bounds checking and alpha blending."""
    if 0 <= x < img.width and 0 <= y < img.height:
        if alpha < 255:
            existing = img.getpixel((x, y))
            if existing[3] > 0:
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


def draw_ao_edge(img, x1, y1, x2, y2, side, depth=4, base_alpha=60):
    """Ambient occlusion darkening along an edge - deeper than v5."""
    for d in range(depth):
        a = base_alpha - d * (base_alpha // depth)
        if a <= 0:
            break
        if side == "top":
            for x in range(x1, x2 + 1):
                put_px(img, x, y1 + d, (15, 10, 25), a)
        elif side == "bottom":
            for x in range(x1, x2 + 1):
                put_px(img, x, y2 - d, (15, 10, 25), a)
        elif side == "left":
            for y in range(y1, y2 + 1):
                put_px(img, x1 + d, y, (15, 10, 25), a)
        elif side == "right":
            for y in range(y1, y2 + 1):
                put_px(img, x2 - d, y, (15, 10, 25), a)


# ============================================================
# ROOF RENDERING - Larger tiles, more color depth
# ============================================================

def draw_roof_tiles_3q(img, x1, wall_top, x2, peak_y, roof_hi, roof_lo, seed=42):
    """3/4 top-down roof with larger, more defined tiles.
    Each tile has 5-6 shades with visible overlap shadow."""
    r = rng(seed)
    mid_x = (x1 + x2) // 2
    width = x2 - x1
    roof_h = wall_top - peak_y

    ridge_y = peak_y + int(roof_h * 0.28)

    # v6: LARGER tiles for clearer per-tile definition
    tile_w = max(10, width // 10)
    tile_h = max(7, roof_h // 8)

    # Derive outline from roof color
    roof_outline = outline_from_hue(roof_lo, 0.5)

    # === FAR SLOPE (top portion, darker, compressed) ===
    for ty in range(peak_y, ridge_y, max(2, tile_h - 2)):
        t_row = (ty - peak_y) / max(1, ridge_y - peak_y)
        half_w = int(4 + t_row * (width // 2 - 4))
        row_x1 = mid_x - half_w
        row_x2 = mid_x + half_w

        stagger = (tile_w // 2) if ((ty - peak_y) // tile_h) % 2 else 0

        for tx in range(row_x1 + stagger, row_x2, tile_w):
            tw = min(tile_w, row_x2 - tx)
            th = min(tile_h - 1, ridge_y - ty)
            if tw < 4 or th < 3:
                continue

            # v6: wider color range per tile (5-6 shades)
            t_val = r.random() * 0.4 + 0.25
            tile_base = lerp_color(roof_lo, roof_hi, t_val)
            tile_deep_shadow = hue_shift_shadow(darken(tile_base, 0.25), 0.25)
            tile_shadow = hue_shift_shadow(tile_base, 0.18)
            tile_mid = tile_base
            tile_light = hue_shift_highlight(tile_base, 0.15)
            tile_highlight = hue_shift_highlight(lighten(tile_base, 0.12), 0.1)

            for dy in range(th):
                for dx in range(tw):
                    if tx + dx < row_x1 or tx + dx > row_x2:
                        continue
                    vy = dy / max(1, th - 1)
                    hx = dx / max(1, tw - 1)
                    # v6: stronger directional light from upper-left
                    lit = (1 - vy) * 0.5 + (1 - hx) * 0.35 + r.random() * 0.15
                    if lit > 0.75:
                        c = lerp_color(tile_light, tile_highlight, (lit - 0.75) * 4)
                    elif lit > 0.4:
                        c = lerp_color(tile_mid, tile_light, (lit - 0.4) / 0.35)
                    else:
                        c = lerp_color(tile_deep_shadow, tile_shadow, lit / 0.4)
                    put_px(img, tx + dx, ty + dy, noisy(r, c, 5))

            # v6: 2px overlap shadow at bottom (was 1px)
            for dx in range(tw):
                if tx + dx >= row_x1 and tx + dx <= row_x2:
                    put_px(img, tx + dx, ty + th - 1,
                           noisy(r, tile_deep_shadow, 4))
                    if th > 3:
                        put_px(img, tx + dx, ty + th - 2,
                               noisy(r, tile_shadow, 3))
            # v6: 2px right edge shadow
            if tx + tw - 1 <= row_x2:
                for dy in range(th):
                    put_px(img, tx + tw - 1, ty + dy,
                           noisy(r, darken(tile_base, 0.2), 4))
                    if tw > 4:
                        put_px(img, tx + tw - 2, ty + dy,
                               noisy(r, darken(tile_base, 0.1), 3))

    # === RIDGE LINE (highlight) ===
    ridge_hi = hue_shift_highlight(lerp_color(roof_hi, (215, 205, 190), 0.3), 0.2)
    half_w = width // 2 - 2
    for x in range(mid_x - half_w, mid_x + half_w):
        for dy in range(-1, 3):
            t = abs(dy - 0.5) / 2.0
            c = lerp_color(ridge_hi, roof_hi, t)
            put_px(img, x, ridge_y + dy, noisy(r, c, 3))

    # === NEAR SLOPE (bottom, larger, lighter/warmer) ===
    near_tile_h = tile_h + 2
    for ty in range(ridge_y + 3, wall_top, max(2, near_tile_h - 2)):
        t_row = (ty - ridge_y) / max(1, wall_top - ridge_y)
        half_w = width // 2 + int(t_row * 6)
        row_x1 = mid_x - half_w
        row_x2 = mid_x + half_w

        stagger = (tile_w // 2) if ((ty - ridge_y) // near_tile_h) % 2 else 0

        for tx in range(row_x1 + stagger, row_x2, tile_w):
            tw = min(tile_w, row_x2 - tx)
            th = min(near_tile_h, wall_top - ty)
            if tw < 4 or th < 3:
                continue

            t_val = r.random() * 0.35 + 0.45
            tile_base = lerp_color(roof_lo, roof_hi, t_val)
            tile_base = hue_shift_highlight(tile_base, 0.1)
            tile_deep_shadow = hue_shift_shadow(darken(tile_base, 0.22), 0.2)
            tile_shadow = hue_shift_shadow(tile_base, 0.15)
            tile_mid = tile_base
            tile_light = hue_shift_highlight(tile_base, 0.12)
            tile_highlight = hue_shift_highlight(lighten(tile_base, 0.15), 0.12)

            for dy in range(th):
                for dx in range(tw):
                    if tx + dx < row_x1 or tx + dx > row_x2:
                        continue
                    vy = dy / max(1, th - 1)
                    hx = dx / max(1, tw - 1)
                    lit = (1 - vy) * 0.5 + (1 - hx) * 0.35 + r.random() * 0.15
                    if lit > 0.75:
                        c = lerp_color(tile_light, tile_highlight, (lit - 0.75) * 4)
                    elif lit > 0.4:
                        c = lerp_color(tile_mid, tile_light, (lit - 0.4) / 0.35)
                    else:
                        c = lerp_color(tile_deep_shadow, tile_shadow, lit / 0.4)
                    put_px(img, tx + dx, ty + dy, noisy(r, c, 6))

            # v6: 2-3px overlap shadow
            for dx in range(tw):
                if tx + dx >= row_x1 and tx + dx <= row_x2:
                    put_px(img, tx + dx, ty + th - 1,
                           noisy(r, tile_deep_shadow, 4))
                    if th > 4:
                        put_px(img, tx + dx, ty + th - 2,
                               noisy(r, tile_shadow, 3))
            if tx + tw - 1 <= row_x2:
                for dy in range(th):
                    put_px(img, tx + tw - 1, ty + dy,
                           noisy(r, darken(tile_base, 0.18), 4))
                    if tw > 5:
                        put_px(img, tx + tw - 2, ty + dy,
                               noisy(r, darken(tile_base, 0.08), 3))

    # === EAVE ===
    eave_y = wall_top
    half_w = width // 2 + 5
    for x in range(mid_x - half_w, mid_x + half_w + 1):
        put_px(img, x, eave_y - 2, noisy(r, darken(roof_lo, 0.15), 3))
        put_px(img, x, eave_y - 1, noisy(r, darken(roof_lo, 0.25), 3))
        put_px(img, x, eave_y, noisy(r, darken(roof_lo, 0.4), 3))
        # v6: deeper eave shadow (3px)
        put_px(img, x, eave_y + 1, (30, 22, 20), 100)
        put_px(img, x, eave_y + 2, (30, 22, 20), 60)
        put_px(img, x, eave_y + 3, (30, 22, 20), 30)

    # === ROOF OUTLINE (hue-derived) ===
    for y in range(peak_y, ridge_y):
        t = (y - peak_y) / max(1, ridge_y - peak_y)
        hw = int(4 + t * (width // 2 - 4))
        put_px(img, mid_x - hw, y, noisy(r, roof_outline, 3))
        put_px(img, mid_x + hw, y, noisy(r, roof_outline, 3))
        put_px(img, mid_x - hw - 1, y, noisy(r, roof_outline, 3), 100)
        put_px(img, mid_x + hw + 1, y, noisy(r, roof_outline, 3), 100)

    for y in range(ridge_y, wall_top):
        t = (y - ridge_y) / max(1, wall_top - ridge_y)
        hw = width // 2 + int(t * 6)
        put_px(img, mid_x - hw, y, noisy(r, roof_outline, 3))
        put_px(img, mid_x + hw, y, noisy(r, roof_outline, 3))
        put_px(img, mid_x - hw - 1, y, noisy(r, roof_outline, 3), 80)
        put_px(img, mid_x + hw + 1, y, noisy(r, roof_outline, 3), 80)

    for x in range(mid_x - 3, mid_x + 4):
        put_px(img, x, peak_y, noisy(r, roof_outline, 3))


def draw_flat_roof_3q(img, x1, wall_top, x2, peak_y, roof_hi, roof_lo, seed=42):
    """Flat/low-slope roof with visible tile grid pattern."""
    r = rng(seed)
    w = x2 - x1
    h = wall_top - peak_y
    roof_outline = outline_from_hue(roof_lo, 0.5)

    for y in range(peak_y, wall_top):
        t = (y - peak_y) / max(1, h)
        for x in range(x1 - 2, x2 + 3):
            ht = (x - x1) / max(1, w) if w > 0 else 0
            base = lerp_color(
                hue_shift_shadow(roof_lo, 0.1),
                hue_shift_highlight(roof_hi, 0.1),
                t * 0.6 + 0.2
            )
            base = lerp_color(
                hue_shift_highlight(base, 0.08),
                hue_shift_shadow(base, 0.08),
                ht
            )
            # v6: larger tile grid pattern (8x10 instead of 6x8)
            row_in = (y - peak_y) % 10
            col_in = (x - x1) % 8
            if row_in < 2 and r.random() < 0.6:
                base = darken(base, 0.12)
            elif row_in == 2:
                base = lighten(base, 0.04)
            if col_in < 1 and r.random() < 0.4:
                base = darken(base, 0.08)
            put_px(img, x, y, noisy(r, base, 6))

    for x in range(x1 - 2, x2 + 3):
        put_px(img, x, peak_y, noisy(r, roof_outline, 3))
        put_px(img, x, peak_y + 1, noisy(r, lighten(roof_hi, 0.12), 3))

    for x in range(x1 - 2, x2 + 3):
        put_px(img, x, wall_top, noisy(r, darken(roof_lo, 0.35), 3))
        put_px(img, x, wall_top + 1, (30, 22, 20, 100))
        put_px(img, x, wall_top + 2, (30, 22, 20, 50))


# ============================================================
# WALL RENDERING - Block-level fidelity overhaul
# ============================================================

def draw_stone_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Individual stones with wider mortar, beveled/rounded highlight curves.
    v6: Larger stones, 3px mortar, rounded per-stone shading, chips/cracks."""
    r = rng(seed)
    mortar = lerp_color(wall_hi, (185, 180, 170), 0.45)
    mortar_dark = darken(mortar, 0.25)
    wall_outline = outline_from_hue(wall_lo, 0.5)

    # Fill mortar base - v6: add subtle variation to mortar
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            mv = r.random()
            mc = lerp_color(mortar_dark, mortar, mv * 0.6 + 0.2)
            put_px(img, x, y, noisy(r, mc, 4))

    # v6: LARGER stones with WIDER gaps
    block_h = max(6, (y2 - y1) // 3)
    mortar_gap = 3
    row = 0
    y = y1 + 2
    while y < y2 - 2:
        bh = min(block_h + r.randint(-1, 2), y2 - y - mortar_gap)
        if bh < 4:
            break
        block_w = max(14, (x2 - x1) // 4) + r.randint(-4, 4)
        x_off = (block_w // 2 + r.randint(-3, 3)) if row % 2 else 0
        x = x1 + 2 - x_off

        while x < x2 - 2:
            bw = block_w + r.randint(-3, 4)
            bx1 = max(x, x1 + 2)
            bx2 = min(x + bw - 1, x2 - 2)
            by1 = y
            by2 = min(y + bh - 1, y2 - 2)

            if bx2 - bx1 >= 5 and by2 - by1 >= 3:
                # v6: wider per-stone color variation
                stone_t = r.random() * 0.55 + 0.2
                stone_base = lerp_color(wall_hi, wall_lo, stone_t)
                # Occasional warm or cool stone
                if r.random() < 0.15:
                    stone_base = hue_shift_highlight(stone_base, 0.08)
                elif r.random() < 0.15:
                    stone_base = hue_shift_shadow(stone_base, 0.08)

                stone_deep = hue_shift_shadow(darken(stone_base, 0.2), 0.15)
                stone_dark = hue_shift_shadow(stone_base, 0.12)
                stone_mid = stone_base
                stone_bright = hue_shift_highlight(stone_base, 0.12)
                stone_hi = hue_shift_highlight(lighten(stone_base, 0.15), 0.1)

                sw = bx2 - bx1
                sh = by2 - by1

                for py in range(by1, by2 + 1):
                    for px in range(bx1, bx2 + 1):
                        # v6: ROUNDED/BEVELED shading (distance from edges)
                        dy_norm = (py - by1) / max(1, sh)
                        dx_norm = (px - bx1) / max(1, sw)

                        # Distance from nearest edge (creates beveled look)
                        edge_dist_y = min(dy_norm, 1.0 - dy_norm) * 2
                        edge_dist_x = min(dx_norm, 1.0 - dx_norm) * 2
                        edge_dist = min(edge_dist_y, edge_dist_x)

                        # Directional light from upper-left
                        dir_light = (1 - dy_norm) * 0.4 + (1 - dx_norm) * 0.3

                        # Combined: center is lit, edges are shadowed, upper-left brighter
                        lit = edge_dist * 0.5 + dir_light * 0.5

                        if lit > 0.7:
                            c = lerp_color(stone_bright, stone_hi, (lit - 0.7) / 0.3)
                        elif lit > 0.4:
                            c = lerp_color(stone_mid, stone_bright, (lit - 0.4) / 0.3)
                        elif lit > 0.2:
                            c = lerp_color(stone_dark, stone_mid, (lit - 0.2) / 0.2)
                        else:
                            c = lerp_color(stone_deep, stone_dark, lit / 0.2)

                        put_px(img, px, py, noisy(r, c, 6))

                # v6: 2px highlight on top and left edges
                for px in range(bx1, bx2):
                    put_px(img, px, by1, noisy(r, stone_hi, 4))
                    put_px(img, px, by1 + 1, noisy(r, stone_bright, 3))
                for py in range(by1, by2):
                    put_px(img, bx1, py, noisy(r, lighten(stone_base, 0.12), 4))
                    put_px(img, bx1 + 1, py, noisy(r, lighten(stone_base, 0.06), 3))

                # v6: 2px shadow on bottom and right edges
                for px in range(bx1 + 1, bx2 + 1):
                    put_px(img, px, by2, noisy(r, stone_deep, 4))
                    if by2 - 1 > by1 + 1:
                        put_px(img, px, by2 - 1, noisy(r, stone_dark, 3))
                for py in range(by1 + 1, by2 + 1):
                    put_px(img, bx2, py, noisy(r, darken(stone_base, 0.18), 4))
                    if bx2 - 1 > bx1 + 1:
                        put_px(img, bx2 - 1, py, noisy(r, darken(stone_base, 0.08), 3))

                # v6: occasional chip/crack detail
                if r.random() < 0.2 and sw > 8 and sh > 5:
                    cx = bx1 + r.randint(3, max(3, sw - 3))
                    cy = by1 + r.randint(2, max(2, sh - 2))
                    crack_len = r.randint(2, 4)
                    for ci in range(crack_len):
                        put_px(img, cx + ci, cy, noisy(r, stone_deep, 3))
                        if r.random() < 0.5:
                            cy += r.choice([-1, 1])

            x += bw + mortar_gap
        y += bh + mortar_gap
        row += 1


def draw_wood_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Horizontal wood planks with visible grain, knots, and gap shadows.
    v6: Wider planks, deeper grain lines, visible knots, 2px gaps."""
    r = rng(seed)
    # v6: larger planks
    plank_h = max(7, (y2 - y1) // 4)
    gap_size = 2
    y = y1

    while y < y2:
        ph = min(plank_h + r.randint(-1, 2), y2 - y)
        if ph < 3:
            break

        # v6: per-plank color with wider variation
        plank_t = r.random() * 0.5 + 0.25
        plank_base = lerp_color(wall_hi, wall_lo, plank_t)
        # Occasional warm/cool plank
        if r.random() < 0.2:
            plank_base = hue_shift_highlight(plank_base, 0.06)
        elif r.random() < 0.2:
            plank_base = hue_shift_shadow(plank_base, 0.06)

        plank_deep = hue_shift_shadow(darken(plank_base, 0.2), 0.12)
        plank_dark = darken(plank_base, 0.1)
        plank_light = hue_shift_highlight(plank_base, 0.1)
        plank_hi = hue_shift_highlight(lighten(plank_base, 0.1), 0.08)

        for dy in range(ph):
            for dx in range(x1, x2 + 1):
                vy = dy / max(1, ph - 1)
                hx = (dx - x1) / max(1, x2 - x1)

                # v6: plank has slight barrel curve (center brighter)
                center_dist = abs(vy - 0.4) * 2
                lit = (1 - center_dist * 0.4) + (1 - hx) * 0.15

                if lit > 0.8:
                    c = lerp_color(plank_light, plank_hi, (lit - 0.8) * 5)
                elif lit > 0.5:
                    c = lerp_color(plank_base, plank_light, (lit - 0.5) / 0.3)
                else:
                    c = lerp_color(plank_dark, plank_base, lit / 0.5)

                # v6: VISIBLE grain lines (darker streaks along plank)
                grain_seed = (dx * 7 + seed) & 0xFFFF
                grain_r = random.Random(grain_seed)
                if grain_r.random() < 0.12:
                    c = darken(c, 0.1)
                # Horizontal grain pattern
                grain_val = math.sin(dx * 0.3 + dy * 0.05 + r.random() * 0.5)
                if grain_val > 0.7:
                    c = darken(c, 0.06)
                elif grain_val < -0.7:
                    c = lighten(c, 0.03)

                put_px(img, dx, y + dy, noisy(r, c, 5))

        # v6: top edge highlight (wood plank lip)
        for dx in range(x1, x2 + 1):
            put_px(img, dx, y, noisy(r, plank_hi, 3))

        # v6: VISIBLE KNOTS (1-2 per plank)
        num_knots = r.randint(0, 2)
        for _ in range(num_knots):
            kx = r.randint(x1 + 5, max(x1 + 6, x2 - 5))
            ky = y + r.randint(2, max(2, ph - 3))
            knot_r_size = r.randint(2, 3)
            knot_dark = darken(plank_base, 0.3)
            knot_ring = darken(plank_base, 0.15)
            # Draw concentric rings
            for kdy in range(-knot_r_size, knot_r_size + 1):
                for kdx in range(-knot_r_size, knot_r_size + 1):
                    dist = math.sqrt(kdx * kdx + kdy * kdy)
                    if dist <= knot_r_size:
                        if dist < knot_r_size * 0.4:
                            c = knot_dark
                        elif dist < knot_r_size * 0.7:
                            c = knot_ring
                        else:
                            c = darken(plank_base, 0.08)
                        put_px(img, kx + kdx, ky + kdy, noisy(r, c, 4))

        # v6: 2px gap shadow between planks
        if y + ph < y2:
            for dx in range(x1, x2 + 1):
                put_px(img, dx, y + ph, noisy(r, plank_deep, 3))
                if ph > 3:
                    put_px(img, dx, y + ph - 1, noisy(r, plank_dark, 3))

        y += ph + gap_size


def draw_brick_wall(img, x1, y1, x2, y2, wall_hi, wall_lo, seed=42):
    """Brick wall with wide color variation per brick and visible mortar.
    v6: Each brick has unique color, wider mortar, beveled shading."""
    r = rng(seed)
    mortar = lerp_color(wall_hi, (190, 185, 175), 0.5)
    mortar_dark = darken(mortar, 0.2)

    # Fill mortar base with variation
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            mc = lerp_color(mortar_dark, mortar, r.random() * 0.5 + 0.25)
            put_px(img, x, y, noisy(r, mc, 3))

    # v6: larger bricks with 2-3px mortar gaps
    brick_w = max(12, (x2 - x1) // 8)
    brick_h = max(6, (y2 - y1) // 5)
    mortar_gap = 2
    row = 0
    y = y1 + 1

    while y + brick_h < y2:
        stagger = (brick_w // 2) if row % 2 else 0
        x = x1 + 1 + stagger

        while x + brick_w < x2:
            bw = min(brick_w, x2 - x - 1)
            bh = brick_h
            if bw < 5:
                break

            # v6: WIDE per-brick color variation
            brick_t = r.random() * 0.6 + 0.2
            brick_base = lerp_color(wall_hi, wall_lo, brick_t)
            # Random warm/cool shift per brick
            shift = r.random()
            if shift < 0.15:
                brick_base = hue_shift_highlight(brick_base, 0.1)
            elif shift < 0.3:
                brick_base = hue_shift_shadow(brick_base, 0.08)
            elif shift < 0.4:
                # Occasional darker brick
                brick_base = darken(brick_base, 0.12)

            brick_deep = hue_shift_shadow(darken(brick_base, 0.2), 0.12)
            brick_dark = darken(brick_base, 0.08)
            brick_light = hue_shift_highlight(brick_base, 0.1)
            brick_hi = hue_shift_highlight(lighten(brick_base, 0.1), 0.08)

            for dy in range(bh):
                for dx in range(bw):
                    vy = dy / max(1, bh - 1)
                    vx = dx / max(1, bw - 1)

                    # v6: beveled brick - edges are darker
                    edge_y = min(vy, 1.0 - vy) * 2
                    edge_x = min(vx, 1.0 - vx) * 2
                    edge = min(edge_y, edge_x)

                    # Directional light
                    dir_lit = (1 - vy) * 0.35 + (1 - vx) * 0.25
                    lit = edge * 0.4 + dir_lit * 0.6

                    if lit > 0.65:
                        c = lerp_color(brick_light, brick_hi, (lit - 0.65) / 0.35)
                    elif lit > 0.35:
                        c = lerp_color(brick_base, brick_light, (lit - 0.35) / 0.3)
                    else:
                        c = lerp_color(brick_deep, brick_dark, lit / 0.35)

                    put_px(img, x + dx, y + dy, noisy(r, c, 5))

            # v6: highlight top edge
            for dx in range(bw):
                put_px(img, x + dx, y, noisy(r, brick_hi, 3))
            # v6: shadow bottom edge
            for dx in range(bw):
                put_px(img, x + dx, y + bh - 1, noisy(r, brick_deep, 3))

            x += bw + mortar_gap

        y += bh + mortar_gap
        row += 1


# ============================================================
# DETAIL ELEMENTS
# ============================================================

def draw_window(img, x, y, w, h, seed=42, has_shutters=False, shutter_color=None):
    """Window with glass reflections, frame detail, and optional shutters.
    v6: Thicker frame, more glass detail, better shutter rendering."""
    r = rng(seed)
    frame_color = (95, 78, 58)
    frame_hi = lighten(frame_color, 0.15)
    frame_lo = darken(frame_color, 0.2)
    frame_outline = outline_from_hue(frame_color, 0.5)

    # v6: thicker frame (2px instead of 1px)
    # Frame fill
    for fy in range(y, y + h):
        for fx in range(x, x + w):
            t = (fy - y) / h
            ht = (fx - x) / w
            c = lerp_color(frame_hi, frame_lo, t * 0.5 + ht * 0.3)
            put_px(img, fx, fy, noisy(r, c, 4))

    # Glass area (inset by 3px for thicker frame)
    gx1 = x + 3
    gy1 = y + 3
    gx2 = x + w - 3
    gy2 = y + h - 3

    # Glass fill with reflection
    glass_dark = (55, 65, 82)
    glass_light = (110, 125, 145)
    glass_reflect = (155, 168, 185)

    for gy in range(gy1, gy2):
        for gx in range(gx1, gx2):
            t_v = (gy - gy1) / max(1, gy2 - gy1)
            t_h = (gx - gx1) / max(1, gx2 - gx1)

            # v6: diagonal reflection streak
            diag = (t_v + t_h) / 2
            if 0.2 < diag < 0.45:
                reflect_t = 1.0 - abs(diag - 0.325) / 0.125
                c = lerp_color(glass_dark, glass_reflect, reflect_t * 0.6)
            else:
                c = lerp_color(glass_dark, glass_light, (1 - t_v) * 0.4 + (1 - t_h) * 0.2)

            put_px(img, gx, gy, noisy(r, c, 3))

    # v6: mullions (cross bars) - thicker
    if w > 12:
        mid_x = x + w // 2
        for gy in range(gy1, gy2):
            put_px(img, mid_x, gy, noisy(r, frame_color, 3))
            put_px(img, mid_x - 1, gy, noisy(r, frame_hi, 3))
    if h > 14:
        mid_y = y + h // 2
        for gx in range(gx1, gx2):
            put_px(img, gx, mid_y, noisy(r, frame_color, 3))
            put_px(img, gx, mid_y - 1, noisy(r, frame_hi, 3))

    # v6: inner shadow at glass edges (recessed look)
    for gx in range(gx1, gx2):
        put_px(img, gx, gy1, noisy(r, (35, 40, 50), 3))
    for gy in range(gy1, gy2):
        put_px(img, gx1, gy, noisy(r, (35, 40, 50), 3))

    # Frame outline
    for fx in range(x, x + w):
        put_px(img, fx, y, noisy(r, frame_outline, 3))
        put_px(img, fx, y + h - 1, noisy(r, frame_outline, 3))
    for fy in range(y, y + h):
        put_px(img, x, fy, noisy(r, frame_outline, 3))
        put_px(img, x + w - 1, fy, noisy(r, frame_outline, 3))

    # v6: window sill (3px ledge below window)
    sill_c = lighten(frame_color, 0.1)
    for sx in range(x - 1, x + w + 1):
        put_px(img, sx, y + h, noisy(r, sill_c, 3))
        put_px(img, sx, y + h + 1, noisy(r, frame_color, 3))
        put_px(img, sx, y + h + 2, noisy(r, frame_lo, 3))

    if has_shutters and shutter_color:
        sw = max(4, w // 3)
        sh_hi = lighten(shutter_color, 0.15)
        sh_lo = darken(shutter_color, 0.2)
        sh_outline = outline_from_hue(shutter_color, 0.5)

        for side_x in [x - sw - 1, x + w + 1]:
            for sy in range(y, y + h):
                for sx in range(side_x, side_x + sw):
                    t = (sy - y) / h
                    ht = (sx - side_x) / max(1, sw)
                    base = lerp_color(sh_hi, sh_lo, t * 0.4 + ht * 0.3)
                    put_px(img, sx, sy, noisy(r, base, 5))

                    # v6: horizontal louver lines (every 3px)
                    if (sy - y) % 3 == 0:
                        put_px(img, sx, sy, noisy(r, darken(base, 0.15), 3))

            # Shutter outline
            for sx in range(side_x, side_x + sw):
                put_px(img, sx, y, noisy(r, sh_outline, 3))
                put_px(img, sx, y + h - 1, noisy(r, sh_outline, 3))
            for sy in range(y, y + h):
                put_px(img, side_x, sy, noisy(r, sh_outline, 3))
                put_px(img, side_x + sw - 1, sy, noisy(r, sh_outline, 3))


def draw_door(img, x, y, w, h, seed=42, has_steps=True, step_color=None):
    """Door with recessed panels, hardware, and optional steps.
    v6: Better panel depth, visible hinges, thicker frame."""
    r = rng(seed)
    door_hi = (128, 95, 62)
    door_lo = (72, 52, 35)
    door_outline = outline_from_hue(door_lo, 0.5)

    # Door fill with gradient
    for dy in range(y, y + h):
        for dx in range(x, x + w):
            t = (dy - y) / h
            ht = (dx - x) / w
            c = lerp_color(
                hue_shift_highlight(door_hi, 0.06),
                hue_shift_shadow(door_lo, 0.08),
                t * 0.5 + ht * 0.3
            )
            put_px(img, dx, dy, noisy(r, c, 5))

    # v6: recessed panels with visible depth
    panel_inset = 3
    panel_gap = 3
    pw = w - panel_inset * 2
    num_panels = 2
    panel_h = (h - panel_inset * 2 - panel_gap * (num_panels - 1)) // num_panels

    for pi in range(num_panels):
        px = x + panel_inset
        py = y + panel_inset + pi * (panel_h + panel_gap)
        # Panel base (recessed = darker)
        panel_base = darken(door_hi, 0.08)
        for pdy in range(py, py + panel_h):
            for pdx in range(px, px + pw):
                tv = (pdy - py) / max(1, panel_h)
                th = (pdx - px) / max(1, pw)
                c = lerp_color(
                    lighten(panel_base, 0.06),
                    darken(panel_base, 0.06),
                    tv * 0.4 + th * 0.3
                )
                put_px(img, pdx, pdy, noisy(r, c, 4))
        # v6: panel shadow (top and left = dark, bottom and right = light)
        for pdx in range(px, px + pw):
            put_px(img, pdx, py, noisy(r, darken(panel_base, 0.2), 3))
        for pdy in range(py, py + panel_h):
            put_px(img, px, pdy, noisy(r, darken(panel_base, 0.15), 3))
        for pdx in range(px, px + pw):
            put_px(img, pdx, py + panel_h - 1, noisy(r, lighten(panel_base, 0.08), 3))
        for pdy in range(py, py + panel_h):
            put_px(img, px + pw - 1, pdy, noisy(r, lighten(panel_base, 0.06), 3))

    # Door outline
    for dx in range(x, x + w):
        put_px(img, dx, y, noisy(r, door_outline, 3))
        put_px(img, dx, y + h - 1, noisy(r, door_outline, 3))
    for dy in range(y, y + h):
        put_px(img, x, dy, noisy(r, door_outline, 3))
        put_px(img, x + w - 1, dy, noisy(r, door_outline, 3))

    # v6: Doorknob with highlight
    kx = x + w - 5
    ky = y + h // 2
    knob_c = (195, 170, 90)
    knob_hi = lighten(knob_c, 0.25)
    knob_lo = darken(knob_c, 0.3)
    put_px(img, kx, ky, noisy(r, knob_hi, 3))
    put_px(img, kx + 1, ky, noisy(r, knob_c, 3))
    put_px(img, kx, ky + 1, noisy(r, knob_lo, 3))
    put_px(img, kx + 1, ky + 1, noisy(r, darken(knob_c, 0.2), 3))

    # Steps
    if has_steps:
        sc = step_color or (155, 148, 135)
        sc_hi = lighten(sc, 0.12)
        sc_lo = darken(sc, 0.15)
        for step_i in range(2):
            sy = y + h + step_i * 4
            sw = w + 6 + step_i * 6
            sx = x - 3 - step_i * 3
            for sdy in range(sy, sy + 4):
                for sdx in range(sx, sx + sw):
                    t = (sdy - sy) / 4
                    c = lerp_color(sc_hi, sc_lo, t)
                    put_px(img, sdx, sdy, noisy(r, c, 4))
            # Step top edge highlight
            for sdx in range(sx, sx + sw):
                put_px(img, sdx, sy, noisy(r, lighten(sc, 0.2), 3))


def draw_chimney(img, x, y, w, h, seed=42):
    """Chimney with individual stones rendered at block-level quality."""
    r = rng(seed)
    stone_hi = (152, 144, 128)
    stone_lo = (85, 80, 68)
    mortar = lerp_color(stone_hi, (178, 172, 162), 0.4)
    chimney_outline = outline_from_hue(stone_lo, 0.5)

    # Mortar base
    for dy in range(y, y + h):
        for dx in range(x, x + w):
            put_px(img, dx, dy, noisy(r, mortar, 4))

    # Individual stones with beveled shading
    sh = 5
    gap = 2
    row = 0
    sy = y + 1
    while sy + sh < y + h:
        sw = max(6, w // 2) + r.randint(-1, 2)
        x_off = (sw // 2) if row % 2 else 0
        sx = x + 1 - x_off
        while sx < x + w - 1:
            actual_sw = min(sw, x + w - 1 - sx)
            if actual_sw < 4:
                break
            bx1 = max(sx, x + 1)
            bx2 = min(sx + actual_sw - 1, x + w - 2)
            by1 = sy
            by2 = min(sy + sh - 1, y + h - 2)

            st = r.random() * 0.45 + 0.25
            sc = lerp_color(stone_hi, stone_lo, st)
            sc_hi = hue_shift_highlight(lighten(sc, 0.12), 0.08)
            sc_lo = hue_shift_shadow(darken(sc, 0.15), 0.1)

            for py in range(by1, by2 + 1):
                for px in range(bx1, bx2 + 1):
                    vy = (py - by1) / max(1, by2 - by1)
                    hx = (px - bx1) / max(1, bx2 - bx1)
                    edge_y = min(vy, 1.0 - vy) * 2
                    edge_x = min(hx, 1.0 - hx) * 2
                    lit = min(edge_y, edge_x) * 0.4 + (1 - vy) * 0.35 + (1 - hx) * 0.25
                    c = lerp_color(sc_lo, sc_hi, min(1, lit))
                    put_px(img, px, py, noisy(r, c, 5))

            sx += actual_sw + gap
        sy += sh + gap
        row += 1

    # Cap
    for dx in range(x - 1, x + w + 1):
        put_px(img, dx, y, noisy(r, lighten(stone_hi, 0.12), 3))
        put_px(img, dx, y + 1, noisy(r, stone_hi, 3))

    # Dark interior opening
    for dx in range(x + 2, x + w - 2):
        put_px(img, dx, y + 2, noisy(r, (25, 18, 14), 3))
        put_px(img, dx, y + 3, noisy(r, (20, 14, 10), 3))

    # Outline
    for dx in range(x, x + w):
        put_px(img, dx, y, noisy(r, chimney_outline, 3))
        put_px(img, dx, y + h - 1, noisy(r, chimney_outline, 3))
    for dy in range(y, y + h):
        put_px(img, x, dy, noisy(r, chimney_outline, 3))
        put_px(img, x + w - 1, dy, noisy(r, chimney_outline, 3))


def draw_trim_board(img, x1, y, x2, thickness, color, seed=42):
    """Horizontal trim/fascia board at material junctions - v6: more depth."""
    r = rng(seed)
    hi = lighten(color, 0.15)
    lo = darken(color, 0.2)
    outline = outline_from_hue(color, 0.45)
    for ty in range(y, y + thickness):
        t = (ty - y) / max(1, thickness)
        for tx in range(x1, x2 + 1):
            c = lerp_color(hi, lo, t)
            put_px(img, tx, ty, noisy(r, c, 4))
    # v6: top highlight + bottom shadow
    for tx in range(x1, x2 + 1):
        put_px(img, tx, y, noisy(r, lighten(hi, 0.1), 3))
        put_px(img, tx, y + thickness - 1, noisy(r, outline, 3), 150)


def draw_sign(img, x, y, w, h, text_lines, bg_color, text_color, seed=42):
    """Simple rectangular sign."""
    r = rng(seed)
    bg_hi = lighten(bg_color, 0.08)
    bg_lo = darken(bg_color, 0.1)
    sign_outline = outline_from_hue(bg_color, 0.5)

    for sy in range(y, y + h):
        for sx in range(x, x + w):
            t = (sy - y) / max(1, h)
            c = lerp_color(bg_hi, bg_lo, t)
            put_px(img, sx, sy, noisy(r, c, 4))
    # Border
    for sx in range(x, x + w):
        put_px(img, sx, y, noisy(r, sign_outline, 3))
        put_px(img, sx, y + h - 1, noisy(r, sign_outline, 3))
    for sy in range(y, y + h):
        put_px(img, x, sy, noisy(r, sign_outline, 3))
        put_px(img, x + w - 1, sy, noisy(r, sign_outline, 3))
    # Text simulation
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
    """Striped awning over storefront - v6: deeper stripes, scalloped edge."""
    r = rng(seed)
    aw_h = 12
    stripe_w = 4  # wider stripes
    for ay in range(y, y + aw_h):
        t = (ay - y) / aw_h
        for ax in range(x1, x2 + 1):
            stripe = ((ay - y) // stripe_w) % 2
            if stripe:
                c = noisy(r, lerp_color(stripe_c1, darken(stripe_c1, 0.2), t), 5)
            else:
                c = noisy(r, lerp_color(stripe_c2, darken(stripe_c2, 0.15), t), 4)
            put_px(img, ax, ay, c)
    # Scalloped bottom
    for ax in range(x1, x2 + 1):
        wave = int(math.sin((ax - x1) * 0.4) * 2) + aw_h
        put_px(img, ax, y + min(wave, aw_h + 1), noisy(r, darken(stripe_c1, 0.35), 3))
    # v6: deeper shadow below awning
    for ax in range(x1, x2 + 1):
        put_px(img, ax, y + aw_h + 1, (25, 18, 15, 90))
        put_px(img, ax, y + aw_h + 2, (25, 18, 15, 55))
        put_px(img, ax, y + aw_h + 3, (25, 18, 15, 25))


def draw_foundation(img, x1, y, x2, h, seed=42):
    """Stone foundation strip at ground level - v6: individual stone texture."""
    r = rng(seed)
    found_hi = (132, 126, 115)
    found_lo = (78, 74, 66)

    for fy in range(y, y + h):
        t = (fy - y) / max(1, h)
        for fx in range(x1, x2 + 1):
            # v6: subtle stone-block pattern
            block_phase = (fx // 8 + fy // 4) % 3
            base_t = t * 0.5 + block_phase * 0.08
            c = lerp_color(found_hi, found_lo, base_t)
            if fx % 8 < 1 and r.random() < 0.3:
                c = darken(c, 0.1)  # mortar line
            put_px(img, fx, fy, noisy(r, c, 5))
    # Top edge highlight
    for fx in range(x1, x2 + 1):
        put_px(img, fx, y, noisy(r, lighten(found_hi, 0.15), 3))


def draw_bush(img, x, y, w, h, seed=42):
    """Small decorative bush - v6: more leaf cluster detail."""
    r = rng(seed)
    bush_hi = (72, 100, 52)
    bush_lo = (35, 55, 25)
    cx, cy = x + w // 2, y + h // 2

    for by in range(y, y + h):
        for bx in range(x, x + w):
            dx = (bx - cx) / max(1, w / 2)
            dy = (by - cy) / max(1, h / 2)
            dist = dx * dx + dy * dy
            if dist < 1.0:
                lit = (1 - (by - y) / h) * 0.45 + (1 - (bx - x) / w) * 0.3
                c = lerp_color(bush_lo, bush_hi, lit + r.random() * 0.25)
                a = 255 if dist < 0.65 else int(255 * (1 - (dist - 0.65) / 0.35))
                put_px(img, bx, by, noisy(r, c, 7), a)

    # v6: more highlight dots (leaf clusters)
    for _ in range(5):
        hx = x + r.randint(2, max(2, w - 3))
        hy = y + r.randint(1, max(1, h // 2))
        put_px(img, hx, hy, noisy(r, lighten(bush_hi, 0.25), 4))
        put_px(img, hx + 1, hy, noisy(r, lighten(bush_hi, 0.15), 4))


def add_ground_shadow(img, alpha=60):
    """Soft drop shadow - v6: slightly larger and softer."""
    bb = img.getbbox()
    if not bb:
        return img
    result = img.copy()
    shadow_offset_x = 4
    shadow_offset_y = 3

    for x in range(bb[0], bb[2]):
        for y in range(bb[3] - 1, bb[3] + 7):
            dy = y - bb[3] + 1
            a = max(0, alpha - dy * 10)
            if a > 0:
                put_px(result, x + shadow_offset_x, y + shadow_offset_y,
                       (15, 10, 20), a)
    return result


# ============================================================
# COLOR PALETTES (same as v5)
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
# BUILDING DEFINITIONS (same layouts as v5, using v6 rendering)
# ============================================================

def make_crossroads_diner(out_dir):
    """Crossroads Diner: large commercial building, flat roof, awning."""
    W, H = 260, 210
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    wx1, wy1, wx2, wy2 = 22, 142, 238, 190

    draw_foundation(img, wx1 - 2, wy2, wx2 + 2, 5, seed=1001)
    draw_brick_wall(img, wx1, wy1, wx2, wy2, WALL_BRICK[0], WALL_BRICK[1], seed=1002)
    draw_trim_board(img, wx1 - 2, wy1 - 3, wx2 + 2, 3, (115, 88, 58), seed=1003)
    draw_flat_roof_3q(img, wx1, wy1 - 3, wx2, 18, ROOF_SLATE[0], ROOF_SLATE[1], seed=1004)
    draw_awning(img, wx1 + 5, wy1 + 2, wx2 - 5, (175, 58, 42), (232, 225, 210), seed=1005)

    for wx in [wx1 + 14, wx1 + 44, wx2 - 56, wx2 - 26]:
        draw_window(img, wx, wy1 + 16, 16, 20, seed=1010 + wx)

    draw_door(img, (wx1 + wx2) // 2 - 9, wy1 + 14, 18, 32,
              seed=1020, step_color=(155, 148, 135))

    draw_sign(img, (wx1 + wx2) // 2 - 30, wy1 - 14, 60, 10,
              ["CROSSROADS", "DINER"], (42, 35, 28), (215, 195, 145), seed=1030)

    draw_chimney(img, wx2 - 30, 8, 16, 24, seed=1040)

    draw_bush(img, wx1 + 5, wy2 + 2, 14, 8, seed=1050)
    draw_bush(img, wx2 - 18, wy2 + 2, 14, 8, seed=1051)

    wall_outline = outline_from_hue(WALL_BRICK[1], 0.5)
    r = rng(1060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 2, wx2, wy1 + 7, "top", 5, 55)

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
    draw_roof_tiles_3q(img, wx1, wy1 - 2, wx2, 14, ROOF_BROWN[0], ROOF_BROWN[1], seed=2004)

    draw_window(img, wx1 + 14, wy1 + 8, 14, 18, seed=2010,
                has_shutters=True, shutter_color=SHUTTER_GREEN)
    draw_window(img, wx2 - 28, wy1 + 8, 14, 18, seed=2011,
                has_shutters=True, shutter_color=SHUTTER_GREEN)

    draw_door(img, (wx1 + wx2) // 2 - 8, wy1 + 6, 16, 30, seed=2020)

    draw_sign(img, (wx1 + wx2) // 2 - 35, wy1 + 1, 70, 8,
              ["FEED & SUPPLY"], (62, 48, 32), (195, 178, 135), seed=2030)

    draw_bush(img, wx1 - 2, wy2 + 1, 12, 7, seed=2050)
    draw_bush(img, wx2 - 10, wy2 + 1, 12, 7, seed=2051)

    wall_outline = outline_from_hue(WALL_WOOD[1], 0.5)
    r = rng(2060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 4, 50)

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

    # Flag pole
    r = rng(3070)
    pole_x = wx1 + 8
    for py in range(wy1 - 30, wy1 + 2):
        put_px(img, pole_x, py, noisy(r, (145, 140, 132), 3))
    for fy in range(wy1 - 28, wy1 - 18):
        for fx in range(pole_x + 1, pole_x + 10):
            t = (fx - pole_x) / 10
            c = lerp_color((165, 42, 38), (180, 55, 48), t)
            put_px(img, fx, fy, noisy(r, c, 4))

    draw_bush(img, wx1 - 3, wy2 + 1, 10, 6, seed=3050)
    draw_bush(img, wx2 - 8, wy2 + 1, 10, 6, seed=3051)

    wall_outline = outline_from_hue(WALL_STONE[1], 0.5)
    r = rng(3060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 4, 50)

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

    win_positions = [wx1 + 12, wx1 + 40, wx1 + 68, wx2 - 80, wx2 - 52, wx2 - 24]
    for i, wx in enumerate(win_positions):
        draw_window(img, wx, wy1 + 6, 14, 18, seed=4010 + i,
                    has_shutters=True, shutter_color=SHUTTER_GREEN)

    draw_door(img, (wx1 + wx2) // 2 - 12, wy1 + 4, 10, 32, seed=4020, has_steps=False)
    draw_door(img, (wx1 + wx2) // 2 + 2, wy1 + 4, 10, 32, seed=4021, has_steps=False)
    # Shared steps
    r = rng(4025)
    step_x = (wx1 + wx2) // 2 - 16
    step_w = 32
    for si in range(3):
        sy = wy1 + 36 + si * 4
        sw = step_w + si * 6
        sx = step_x - si * 3
        for sdy in range(sy, sy + 4):
            for sdx in range(sx, sx + sw):
                t = (sdy - sy) / 4
                c = lerp_color((165, 158, 145), (125, 118, 108), t)
                put_px(img, sdx, sdy, noisy(r, c, 4))
        for sdx in range(sx, sx + sw):
            put_px(img, sdx, sy, noisy(r, lighten((165, 158, 145), 0.15), 3))

    draw_bush(img, wx1 - 4, wy2 + 2, 14, 8, seed=4050)
    draw_bush(img, wx1 + 14, wy2 + 2, 12, 7, seed=4052)
    draw_bush(img, wx2 - 24, wy2 + 2, 14, 8, seed=4051)
    draw_bush(img, wx2 - 6, wy2 + 2, 12, 7, seed=4053)

    wall_outline = outline_from_hue(WALL_CREAM[1], 0.5)
    r = rng(4060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 5, 55)

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

    wall_outline = outline_from_hue(WALL_CREAM[1], 0.5)
    r = rng(5060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 4, 50)

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

    wall_outline = outline_from_hue(WALL_CREAM[1], 0.5)
    r = rng(6060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 5, 55)

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
    for bdy in range(dy, dy + dh):
        for bdx in range(dx, dx + door_w):
            t = (bdy - dy) / dh
            c = lerp_color((35, 25, 18), (18, 12, 8), t)
            put_px(img, bdx, bdy, noisy(r, c, 3))
    # Door frame
    frame_c = (92, 68, 42)
    frame_hi = lighten(frame_c, 0.1)
    for bdx in range(dx - 2, dx + door_w + 2):
        put_px(img, bdx, dy - 1, noisy(r, frame_hi, 3))
        put_px(img, bdx, dy - 2, noisy(r, frame_c, 3))
    for bdy in range(dy, dy + dh):
        put_px(img, dx - 1, bdy, noisy(r, frame_c, 3))
        put_px(img, dx - 2, bdy, noisy(r, frame_hi, 3))
        put_px(img, dx + door_w, bdy, noisy(r, frame_c, 3))
        put_px(img, dx + door_w + 1, bdy, noisy(r, darken(frame_c, 0.15), 3))

    # Sliding door track
    for bdx in range(dx - 4, dx + door_w + 4):
        put_px(img, bdx, dy - 3, noisy(r, (75, 72, 68), 3))
        put_px(img, bdx, dy - 4, noisy(r, lighten((75, 72, 68), 0.1), 3))

    # X-brace on wall
    for i in range(min(wy2 - wy1, wx2 - wx1) // 3):
        lx = wx1 + 5 + i
        ly = wy1 + 5 + i
        put_px(img, lx, ly, noisy(r, darken(WALL_RED_BARN[0], 0.25), 3))
        rx = wx2 - 5 - i
        put_px(img, rx, ly, noisy(r, darken(WALL_RED_BARN[0], 0.25), 3))

    wall_outline = outline_from_hue(WALL_RED_BARN[1], 0.5)
    r = rng(7060)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 6, "top", 4, 50)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, "harmon_barn.png"))
    print(f"  harmon_barn.png ({W}x{H})")


def make_background_strip(out_dir):
    """Background silhouette buildings - faded for depth."""
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

    counter_y = H - 35
    # v6: wood-grain counter
    for y in range(counter_y, counter_y + 18):
        t = (y - counter_y) / 18
        for x in range(18, W - 18):
            base = lerp_color((155, 125, 88), (92, 72, 48), t)
            ht = (x - 18) / (W - 36)
            base = lerp_color(hue_shift_highlight(base, 0.06),
                              hue_shift_shadow(base, 0.06), ht)
            # Grain
            grain = math.sin(x * 0.25 + y * 0.03)
            if grain > 0.6:
                base = darken(base, 0.06)
            put_px(img, x, y, noisy(r, base, 5))

    for x in range(16, W - 16):
        put_px(img, x, counter_y, noisy(r, lighten((155, 125, 88), 0.18), 3))

    # Posts with grain
    for px_pos in [16, W - 20]:
        for y in range(20, H - 12):
            for dx_off in range(4):
                t = dx_off / 4
                base = lerp_color((135, 105, 75), (82, 62, 42), t)
                if r.random() < 0.1:
                    base = darken(base, 0.12)
                put_px(img, px_pos + dx_off, y, noisy(r, base, 5))

    draw_awning(img, 12, 14, W - 12, (172, 55, 40), (228, 220, 205), seed=9005)

    # Display items
    item_data = [
        ((200, 162, 65), 3),
        ((118, 148, 78), 4),
        ((180, 85, 58), 3),
        ((165, 145, 95), 3),
    ]
    ix = 25
    for color, count in item_data:
        for c in range(count):
            iy = counter_y - 10
            iw = 8 + r.randint(-1, 2)
            ih = 6 + r.randint(-1, 2)
            for dy in range(iy, iy + ih):
                for dx_off in range(ix, ix + iw):
                    t = (dy - iy) / ih
                    c_item = lerp_color(lighten(color, 0.12), darken(color, 0.12), t)
                    put_px(img, dx_off, dy, noisy(r, c_item, 5))
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

    for px_pos in [mid - 30, mid + 22]:
        for y in range(22, H - 12):
            for dx_off in range(10):
                t = dx_off / 10
                base = lerp_color((145, 115, 78), (78, 58, 38), t)
                if r.random() < 0.1:
                    base = darken(base, 0.12)
                put_px(img, px_pos + dx_off, y, noisy(r, base, 5))
        for y in range(18, 24):
            for dx_off in range(-2, 13):
                c = lerp_color((158, 132, 95), (112, 88, 62), (y - 18) / 6)
                put_px(img, px_pos + dx_off, y, noisy(r, c, 4))

    for y in range(12, 22):
        t = (y - 12) / 10
        for x in range(mid - 34, mid + 34):
            ht = (x - (mid - 34)) / 68
            base = lerp_color(
                lerp_color((152, 122, 85), (92, 72, 48), t),
                lerp_color((138, 112, 78), (85, 65, 42), t),
                ht
            )
            put_px(img, x, y, noisy(r, base, 5))

    draw_sign(img, mid - 28, 5, 56, 8, ["FAIRGROUNDS"],
              (55, 42, 28), (205, 188, 138), seed=10030)

    for section in [(8, mid - 34), (mid + 36, W - 8)]:
        sx, ex = section
        for fy in [42, 62, H - 22]:
            for fx in range(sx, ex):
                put_px(img, fx, fy, noisy(r, (115, 92, 65), 5))
                put_px(img, fx, fy + 1, noisy(r, (95, 75, 52), 4))
        for fx in range(sx, ex, 6):
            for fy in range(38, H - 15):
                put_px(img, fx, fy, noisy(r, (128, 102, 72), 5))
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

    for y in range(ty1, ty2):
        t_v = (y - ty1) / tank_h
        for x in range(tx1, tx1 + tank_w):
            t_h = (x - tx1) / tank_w
            cyl = 1.0 - math.exp(-((t_h - 0.35) ** 2) * 8)
            base = lerp_color(
                hue_shift_highlight((182, 175, 165), 0.1),
                hue_shift_shadow((98, 94, 86), 0.12),
                min(1, cyl * 0.8 + t_v * 0.2)
            )
            put_px(img, x, y, noisy(r, base, 5))

    for by in [ty1 + 8, ty1 + 22, ty1 + 36]:
        for x in range(tx1, tx1 + tank_w):
            t_h = (x - tx1) / tank_w
            cyl = abs(t_h - 0.35) * 1.5
            band_c = lerp_color((112, 108, 100), (68, 64, 58), min(1, cyl))
            put_px(img, x, by, noisy(r, band_c, 3))
            put_px(img, x, by + 1, noisy(r, darken(band_c, 0.12), 3))

    for x in range(tx1 + 3, tx1 + tank_w - 3):
        for dy in range(3):
            t = (x - tx1) / tank_w
            c = lerp_color((172, 165, 155), (125, 118, 108), t)
            put_px(img, x, ty1 - dy, noisy(r, c, 3))

    leg_bot = H - 10
    leg_data = [
        (cx - 22, cx - 16), (cx - 8, cx - 5),
        (cx + 5, cx + 5), (cx + 18, cx + 16)
    ]
    for bot_x, top_x in leg_data:
        for y in range(ty2, leg_bot):
            t = (y - ty2) / (leg_bot - ty2)
            x = int(top_x + (bot_x - top_x) * t)
            for dx_off in range(3):
                lt = dx_off / 3
                c = lerp_color((118, 112, 105), (75, 72, 65), lt)
                put_px(img, x + dx_off, y, noisy(r, c, 4))

    for y in range(ty2 + 15, ty2 + 18):
        for x in range(cx - 18, cx + 18):
            put_px(img, x, y, noisy(r, (98, 92, 85), 4))

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

        for y in range(st, sb):
            t_v = (y - st) / (sb - st)
            for x in range(sx, sx + sw):
                t_h = (x - sx) / sw
                cyl = 1.0 - math.exp(-((t_h - 0.35) ** 2) * 8)
                base = lerp_color(
                    hue_shift_highlight((178, 172, 162), 0.08),
                    hue_shift_shadow((96, 92, 84), 0.1),
                    min(1, cyl * 0.75 + t_v * 0.15)
                )
                put_px(img, x, y, noisy(r, base, 5))

        for by in range(st + 6, sb, 10):
            for x in range(sx, sx + sw):
                t_h = (x - sx) / sw
                cyl = abs(t_h - 0.35) * 1.5
                band = lerp_color((85, 82, 75), (58, 55, 48), min(1, cyl))
                put_px(img, x, by, noisy(r, band, 3))

        mid_val = sx + sw // 2
        cone_h = 14
        for y in range(st - cone_h, st):
            t = (y - (st - cone_h)) / cone_h
            hw = int(t * sw // 2)
            for x in range(mid_val - hw, mid_val + hw + 1):
                t_h = (x - (mid_val - hw)) / max(1, hw * 2)
                base = lerp_color((165, 160, 150), (102, 98, 88), t_h * 0.6 + (1-t) * 0.3)
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

    draw_window(img, wx1 + 10, wy1 + 6, 12, 16, seed=seed + 10,
                has_shutters=True, shutter_color=SHUTTER_BROWN)
    draw_window(img, wx2 - 22, wy1 + 6, 12, 16, seed=seed + 11,
                has_shutters=True, shutter_color=SHUTTER_BROWN)

    draw_door(img, (wx1 + wx2) // 2 - 7, wy1 + 5, 14, 26, seed=seed + 20)

    draw_bush(img, wx1 - 2, wy2 + 1, 10, 6, seed=seed + 50)
    draw_bush(img, wx2 - 8, wy2 + 1, 10, 6, seed=seed + 51)

    wall_outline = outline_from_hue(wall[1], 0.5)
    r = rng(seed + 60)
    for x in range(wx1, wx2 + 1):
        put_px(img, x, wy2, noisy(r, wall_outline, 3))
    for y in range(wy1, wy2 + 1):
        put_px(img, wx1, y, noisy(r, wall_outline, 3))
        put_px(img, wx2, y, noisy(r, wall_outline, 3))

    draw_ao_edge(img, wx1, wy1 + 1, wx2, wy1 + 5, "top", 4, 50)

    img = add_ground_shadow(img)
    img.save(os.path.join(out_dir, filename))
    print(f"  {filename} ({w}x{h})")


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/buildings_v6"
    os.makedirs(out_dir, exist_ok=True)

    print("Generating v6 buildings (block-level fidelity overhaul)...")
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

    print("Done! All v6 buildings generated.")
