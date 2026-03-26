#!/usr/bin/env python3
"""
Smoke & Honey -- Environment Sprite Generator v5
Trees, props, and tiles with quality matching the v5 buildings.
Multi-layer compositing, hue-shifted shadows, per-pixel noise,
individual detail rendering.
"""
from PIL import Image, ImageDraw, ImageFilter
import random, os, sys, math

OUTLINE = (72, 37, 16)

def rng(seed=42):
    return random.Random(seed)

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def noisy(r, color, variance=8):
    return tuple(clamp(c + r.randint(-variance, variance)) for c in color[:3])

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(clamp(c1[i] + (c2[i] - c1[i]) * t) for i in range(min(len(c1), len(c2), 3)))

def hue_shift_shadow(color, amount=0.15):
    r, g, b = color[:3]
    return (clamp(r * (1 - amount * 0.3)), clamp(g * (1 - amount * 0.2)), clamp(b * (1 + amount * 0.15)))

def hue_shift_highlight(color, amount=0.12):
    r, g, b = color[:3]
    return (clamp(r + amount * 40), clamp(g + amount * 25), clamp(b - amount * 10))

def darken(color, amount=0.3):
    return tuple(clamp(c * (1 - amount)) for c in color[:3])

def lighten(color, amount=0.3):
    return tuple(clamp(c + (255 - c) * amount) for c in color[:3])

def put_px(img, x, y, color, alpha=255):
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


# ============================================================
# TREES
# ============================================================

def make_oak_tree(out_dir):
    """Large oak tree - 3/4 top-down view. Canopy is a large, irregular cluster
    of leaf masses with individual leaf cluster rendering."""
    W, H = 110, 150
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(100)
    cx = W // 2

    # Trunk (visible below canopy)
    trunk_top = 85
    trunk_bot = H - 8
    trunk_w = 12
    tx1 = cx - trunk_w // 2
    bark_hi = (115, 88, 58)
    bark_lo = (62, 45, 28)

    for y in range(trunk_top, trunk_bot):
        t = (y - trunk_top) / (trunk_bot - trunk_top)
        # Trunk widens slightly at base
        tw = trunk_w + int(t * 4)
        for x in range(cx - tw // 2, cx + tw // 2):
            ht = (x - (cx - tw // 2)) / max(1, tw)
            # Cylindrical shading
            cyl = 1.0 - math.exp(-((ht - 0.4) ** 2) * 6)
            base = lerp_color(
                hue_shift_highlight(bark_hi, 0.06),
                hue_shift_shadow(bark_lo, 0.1),
                min(1, cyl * 0.7 + t * 0.2)
            )
            # Bark texture
            if r.random() < 0.15:
                base = darken(base, 0.12)
            put_px(img, x, y, noisy(r, base, 5))

    # Trunk outline
    for y in range(trunk_top, trunk_bot):
        t = (y - trunk_top) / (trunk_bot - trunk_top)
        tw = trunk_w + int(t * 4)
        put_px(img, cx - tw // 2, y, noisy(r, OUTLINE, 3))
        put_px(img, cx + tw // 2 - 1, y, noisy(r, OUTLINE, 3))

    # Root flare at base
    for rx in range(-3, 4):
        root_x = cx + rx * 3
        for ry in range(trunk_bot - 3, trunk_bot + 2):
            put_px(img, root_x, ry, noisy(r, bark_lo, 4), 180)

    # Ground shadow (elliptical)
    for sy in range(trunk_bot, trunk_bot + 5):
        t = (sy - trunk_bot) / 5
        sw = int((1 - t) * 25 + 5)
        for sx in range(cx - sw, cx + sw):
            dist = abs(sx - cx) / max(1, sw)
            a = int((1 - dist) * (1 - t) * 45)
            if a > 0:
                put_px(img, sx, sy, (20, 15, 25), a)

    # Canopy - multiple overlapping leaf clusters
    leaf_hi = (72, 108, 52)
    leaf_mid = (55, 85, 42)
    leaf_lo = (35, 58, 25)
    leaf_shadow = (28, 42, 22)

    # Define cluster centers (irregular arrangement)
    clusters = [
        (cx, 38, 28, 22),       # center top
        (cx - 20, 48, 24, 20),  # left
        (cx + 22, 45, 26, 21),  # right
        (cx - 8, 55, 22, 18),   # center-left lower
        (cx + 12, 58, 24, 19),  # center-right lower
        (cx - 25, 60, 20, 16),  # far left lower
        (cx + 28, 55, 20, 17),  # far right
        (cx, 65, 26, 18),       # center bottom
        (cx - 15, 68, 20, 14),  # left bottom
        (cx + 18, 70, 22, 15),  # right bottom
        (cx, 30, 20, 16),       # very top
    ]

    # Draw clusters back to front
    for ci, (ccx, ccy, cw, ch) in enumerate(clusters):
        # Each cluster is an irregular ellipse of leaf pixels
        for y in range(ccy - ch, ccy + ch):
            for x in range(ccx - cw, ccx + cw):
                dx = (x - ccx) / max(1, cw)
                dy = (y - ccy) / max(1, ch)
                dist = dx * dx + dy * dy
                # Irregular edge
                edge_noise = r.random() * 0.3
                if dist < 0.85 + edge_noise:
                    # Shading: top-left lit, bottom-right shadow
                    lit = (1 - (y - (ccy - ch)) / (ch * 2)) * 0.45 + (1 - (x - (ccx - cw)) / (cw * 2)) * 0.35
                    lit += r.random() * 0.15  # random variation

                    if lit > 0.65:
                        c = lerp_color(leaf_mid, leaf_hi, (lit - 0.65) * 3)
                    elif lit > 0.35:
                        c = lerp_color(leaf_lo, leaf_mid, (lit - 0.35) * 3.3)
                    else:
                        c = lerp_color(leaf_shadow, leaf_lo, lit * 2.8)

                    # Hue shift
                    if lit > 0.5:
                        c = hue_shift_highlight(c, 0.06)
                    else:
                        c = hue_shift_shadow(c, 0.08)

                    # Individual leaf detail: small color pops
                    if r.random() < 0.08:
                        c = lighten(c, 0.15)
                    elif r.random() < 0.06:
                        c = darken(c, 0.12)

                    a = 255 if dist < 0.6 else int(255 * max(0, 1 - (dist - 0.6) / 0.35))
                    put_px(img, x, y, noisy(r, c, 6), a)

        # Cluster edge outline (subtle)
        for angle in range(0, 360, 3):
            rad = math.radians(angle)
            ex = int(ccx + math.cos(rad) * cw * 0.88)
            ey = int(ccy + math.sin(rad) * ch * 0.88)
            if r.random() < 0.4:
                put_px(img, ex, ey, noisy(r, darken(leaf_lo, 0.2), 3), 150)

    img.save(os.path.join(out_dir, "oak_tree.png"))
    print(f"  oak_tree.png ({W}x{H})")


def make_pine_tree(out_dir):
    """Conical pine/fir tree - 3/4 top-down view."""
    W, H = 60, 120
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(200)
    cx = W // 2

    # Trunk
    trunk_top = 80
    trunk_bot = H - 6
    for y in range(trunk_top, trunk_bot):
        t = (y - trunk_top) / (trunk_bot - trunk_top)
        tw = 5 + int(t * 2)
        for x in range(cx - tw // 2, cx + tw // 2):
            ht = (x - (cx - tw // 2)) / max(1, tw)
            cyl = abs(ht - 0.4) * 2
            base = lerp_color((105, 78, 48), (58, 40, 25), min(1, cyl))
            put_px(img, x, y, noisy(r, base, 4))

    # Shadow
    for sy in range(trunk_bot, trunk_bot + 4):
        t = (sy - trunk_bot) / 4
        sw = int((1 - t) * 15 + 3)
        for sx in range(cx - sw, cx + sw):
            dist = abs(sx - cx) / max(1, sw)
            a = int((1 - dist) * (1 - t) * 35)
            if a > 0:
                put_px(img, sx, sy, (20, 15, 25), a)

    # Foliage tiers (layered cone shape)
    pine_hi = (52, 82, 42)
    pine_mid = (38, 62, 32)
    pine_lo = (25, 45, 22)

    tiers = [
        (10, 18, 8),   # top (y, half_width, height)
        (22, 14, 12),
        (32, 19, 14),
        (44, 23, 16),
        (58, 26, 18),
        (72, 22, 14),
    ]

    for ty, hw, th in tiers:
        for y in range(ty, ty + th):
            t_row = (y - ty) / max(1, th)
            row_hw = int(hw * (0.3 + t_row * 0.7))
            for x in range(cx - row_hw, cx + row_hw + 1):
                dx = (x - cx) / max(1, row_hw)
                lit = (1 - t_row) * 0.5 + (1 - abs(dx)) * 0.3 + r.random() * 0.15
                if lit > 0.55:
                    c = lerp_color(pine_mid, pine_hi, (lit - 0.55) * 2.2)
                else:
                    c = lerp_color(pine_lo, pine_mid, lit * 1.8)
                c = hue_shift_shadow(c, 0.06) if lit < 0.4 else hue_shift_highlight(c, 0.04)
                # Edge irregularity
                edge_dist = abs(abs(dx) - 1.0)
                if edge_dist < 0.15 and r.random() < 0.4:
                    continue  # skip pixel for irregular edge
                put_px(img, x, y, noisy(r, c, 5))

        # Bottom edge shadow for tier overlap
        for x in range(cx - hw, cx + hw + 1):
            if r.random() < 0.7:
                put_px(img, x, ty + th - 1, noisy(r, darken(pine_lo, 0.2), 3))

    img.save(os.path.join(out_dir, "pine_tree.png"))
    print(f"  pine_tree.png ({W}x{H})")


# ============================================================
# PROPS
# ============================================================

def make_lamppost(out_dir):
    """Street lamppost - 3/4 top-down view."""
    W, H = 28, 62
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(300)
    cx = W // 2

    pole_hi = (68, 72, 68)
    pole_lo = (38, 42, 38)

    # Pole
    for y in range(12, H - 4):
        for dx in range(-1, 2):
            t = dx / 2
            c = lerp_color(pole_hi, pole_lo, abs(t))
            put_px(img, cx + dx, y, noisy(r, c, 3))

    # Lamp housing (top)
    lamp_hi = (55, 58, 55)
    lamp_lo = (32, 35, 32)
    for y in range(5, 14):
        t = (y - 5) / 9
        hw = 4 if y < 10 else 3
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / (hw * 2)
            base = lerp_color(lamp_hi, lamp_lo, ht * 0.5 + t * 0.3)
            put_px(img, x, y, noisy(r, base, 3))

    # Glass (warm glow)
    for y in range(7, 12):
        for x in range(cx - 2, cx + 3):
            c = lerp_color((225, 205, 145), (195, 165, 95), (y - 7) / 5)
            put_px(img, x, y, noisy(r, c, 4))

    # Cap
    for x in range(cx - 4, cx + 5):
        put_px(img, x, 5, noisy(r, (45, 48, 45), 3))
    for x in range(cx - 3, cx + 4):
        put_px(img, x, 4, noisy(r, (52, 55, 52), 3))

    # Base
    for y in range(H - 4, H):
        hw = 4 + (y - (H - 4))
        for x in range(cx - hw, cx + hw + 1):
            t = (x - (cx - hw)) / (hw * 2)
            c = lerp_color(pole_hi, pole_lo, t)
            put_px(img, x, y, noisy(r, c, 3))

    # Light glow around lamp (subtle)
    for dy in range(-3, 8):
        for dx in range(-5, 6):
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 6 and dist > 2:
                a = int((1 - dist / 6) * 25)
                put_px(img, cx + dx, 9 + dy, (245, 225, 165), a)

    img.save(os.path.join(out_dir, "lamppost.png"))
    print(f"  lamppost.png ({W}x{H})")


def make_bench(out_dir):
    """Wooden park bench - 3/4 top-down."""
    W, H = 42, 26
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(400)

    wood_hi = (142, 112, 75)
    wood_lo = (82, 62, 38)
    metal = (72, 75, 72)

    # Seat slats
    for slat in range(4):
        sy = 6 + slat * 4
        for y in range(sy, sy + 3):
            t = (y - sy) / 3
            for x in range(4, W - 4):
                ht = (x - 4) / (W - 8)
                base = lerp_color(wood_hi, wood_lo, slat * 0.12 + ht * 0.2 + t * 0.15)
                if r.random() < 0.1:
                    base = darken(base, 0.08)
                put_px(img, x, y, noisy(r, base, 5))

    # Legs/supports
    for lx in [4, W - 6]:
        for y in range(4, H - 2):
            for dx in range(2):
                c = lerp_color(metal, darken(metal, 0.3), dx / 2)
                put_px(img, lx + dx, y, noisy(r, c, 3))

    # Backrest (top, seen from above as thin strip)
    for x in range(4, W - 4):
        for dy in range(3):
            t = dy / 3
            c = lerp_color(lighten(wood_hi, 0.05), wood_lo, t * 0.3)
            put_px(img, x, 3 + dy, noisy(r, c, 4))

    # Armrests
    for lx in [3, W - 7]:
        for y in range(2, 22):
            for dx in range(3):
                c = lerp_color(metal, darken(metal, 0.2), dx / 3)
                put_px(img, lx + dx, y, noisy(r, c, 3))

    # Shadow
    for x in range(6, W - 4):
        put_px(img, x + 1, H - 2, (20, 15, 25, 30))
        put_px(img, x + 2, H - 1, (20, 15, 25, 15))

    img.save(os.path.join(out_dir, "bench.png"))
    print(f"  bench.png ({W}x{H})")


def make_mailbox(out_dir):
    """USPS-style mailbox on post."""
    W, H = 18, 32
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(500)
    cx = W // 2

    # Post
    for y in range(16, H - 2):
        for dx in range(-1, 2):
            c = lerp_color((115, 88, 58), (72, 52, 32), abs(dx) / 2)
            put_px(img, cx + dx, y, noisy(r, c, 4))

    # Mailbox body (blue, rounded top)
    box_hi = (48, 68, 108)
    box_lo = (28, 38, 68)
    for y in range(4, 17):
        t = (y - 4) / 13
        hw = 6 if y > 6 else int(3 + (y - 4) * 1.5)
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            cyl = abs(ht - 0.4) * 1.8
            base = lerp_color(
                hue_shift_highlight(box_hi, 0.06),
                hue_shift_shadow(box_lo, 0.08),
                min(1, cyl * 0.6 + t * 0.3)
            )
            put_px(img, x, y, noisy(r, base, 4))

    # Flag (on right side)
    for y in range(6, 12):
        put_px(img, cx + 7, y, noisy(r, (185, 55, 38), 4))
    for y in range(6, 9):
        put_px(img, cx + 8, y, noisy(r, (175, 48, 32), 4))

    # Door line
    for x in range(cx - 5, cx + 5):
        put_px(img, x, 10, noisy(r, darken(box_lo, 0.2), 3))

    img.save(os.path.join(out_dir, "mailbox.png"))
    print(f"  mailbox.png ({W}x{H})")


def make_barrel(out_dir):
    """Wooden barrel - 3/4 top-down."""
    W, H = 22, 26
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(600)
    cx, cy = W // 2, H // 2

    barrel_hi = (145, 112, 72)
    barrel_lo = (78, 55, 32)
    band_c = (82, 78, 72)

    # Barrel body (cylindrical)
    for y in range(4, H - 3):
        t = (y - 4) / (H - 7)
        # Barrel bulges in middle
        bulge = 1.0 - abs(t - 0.5) * 0.8
        hw = int(8 * bulge + 2)
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            cyl = 1.0 - math.exp(-((ht - 0.38) ** 2) * 6)
            base = lerp_color(
                hue_shift_highlight(barrel_hi, 0.06),
                hue_shift_shadow(barrel_lo, 0.08),
                min(1, cyl * 0.65 + t * 0.2)
            )
            # Wood grain
            if r.random() < 0.1:
                base = darken(base, 0.08)
            put_px(img, x, y, noisy(r, base, 5))

    # Metal bands
    for by in [6, 12, H - 8]:
        t = (by - 4) / (H - 7)
        bulge = 1.0 - abs(t - 0.5) * 0.8
        hw = int(8 * bulge + 2)
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            cyl = abs(ht - 0.38) * 1.5
            c = lerp_color(lighten(band_c, 0.1), darken(band_c, 0.15), min(1, cyl))
            put_px(img, x, by, noisy(r, c, 3))

    # Top ellipse (visible from 3/4 view)
    for x in range(cx - 7, cx + 8):
        for dy in range(-2, 1):
            dx = (x - cx) / 7
            if dx * dx + (dy / 2) ** 2 < 1:
                t = (x - (cx - 7)) / 14
                c = lerp_color(lighten(barrel_hi, 0.1), barrel_lo, t * 0.4)
                put_px(img, x, 3 + dy, noisy(r, c, 4))

    img.save(os.path.join(out_dir, "barrel.png"))
    print(f"  barrel.png ({W}x{H})")


def make_crate(out_dir):
    """Wooden crate - 3/4 top-down."""
    W, H = 24, 24
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(700)

    wood_hi = (155, 128, 88)
    wood_lo = (88, 68, 42)

    # Front face
    for y in range(8, H - 2):
        t = (y - 8) / (H - 10)
        for x in range(3, W - 3):
            ht = (x - 3) / (W - 6)
            base = lerp_color(wood_hi, wood_lo, t * 0.3 + ht * 0.25)
            if r.random() < 0.08:
                base = darken(base, 0.1)
            put_px(img, x, y, noisy(r, base, 5))

    # Top face (visible in 3/4 view)
    for y in range(2, 9):
        t = (y - 2) / 7
        for x in range(3, W - 3):
            ht = (x - 3) / (W - 6)
            base = lerp_color(lighten(wood_hi, 0.1), wood_lo, t * 0.2 + ht * 0.15)
            put_px(img, x, y, noisy(r, base, 4))

    # Cross brace
    for i in range(min(W - 6, H - 10)):
        x1 = 3 + i
        y1 = 8 + int(i * (H - 10) / (W - 6))
        if x1 < W - 3 and y1 < H - 2:
            put_px(img, x1, y1, noisy(r, darken(wood_lo, 0.15), 3))

    # Outline
    for x in range(3, W - 3):
        put_px(img, x, 2, noisy(r, OUTLINE, 3))
        put_px(img, x, H - 3, noisy(r, OUTLINE, 3))
    for y in range(2, H - 2):
        put_px(img, 3, y, noisy(r, OUTLINE, 3))
        put_px(img, W - 4, y, noisy(r, OUTLINE, 3))

    # Edge between top and front face
    for x in range(3, W - 3):
        put_px(img, x, 8, noisy(r, darken(wood_lo, 0.2), 3))

    img.save(os.path.join(out_dir, "crate.png"))
    print(f"  crate.png ({W}x{H})")


def make_fire_hydrant(out_dir):
    """Fire hydrant - 3/4 top-down."""
    W, H = 16, 22
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(800)
    cx = W // 2

    body_hi = (195, 62, 42)
    body_lo = (118, 35, 22)

    # Body (cylindrical)
    for y in range(4, H - 3):
        t = (y - 4) / (H - 7)
        hw = 4 if 6 < y < H - 6 else 5
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            cyl = 1.0 - math.exp(-((ht - 0.38) ** 2) * 8)
            base = lerp_color(
                hue_shift_highlight(body_hi, 0.08),
                hue_shift_shadow(body_lo, 0.1),
                min(1, cyl * 0.65 + t * 0.2)
            )
            put_px(img, x, y, noisy(r, base, 5))

    # Cap (top)
    for x in range(cx - 3, cx + 4):
        for dy in range(3):
            c = lerp_color((165, 52, 35), (105, 32, 20), dy / 3)
            put_px(img, x, 3 + dy, noisy(r, c, 3))

    # Nozzles (sides)
    for nx in [cx - 5, cx + 4]:
        for y in range(9, 13):
            put_px(img, nx, y, noisy(r, body_hi, 4))
            put_px(img, nx + (1 if nx < cx else -1), y, noisy(r, body_lo, 4))

    # Chains/bolts
    for bx in [cx - 2, cx + 2]:
        put_px(img, bx, 7, noisy(r, (180, 160, 90), 4))

    img.save(os.path.join(out_dir, "fire_hydrant.png"))
    print(f"  fire_hydrant.png ({W}x{H})")


def make_flower_planter(out_dir):
    """Stone flower planter with flowers."""
    W, H = 32, 28
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = rng(900)
    cx = W // 2

    # Stone pot (trapezoidal in 3/4 view)
    pot_hi = (158, 152, 138)
    pot_lo = (98, 92, 80)
    for y in range(12, H - 2):
        t = (y - 12) / (H - 14)
        hw = int(10 + t * 3)
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            base = lerp_color(pot_hi, pot_lo, ht * 0.4 + t * 0.3)
            put_px(img, x, y, noisy(r, base, 5))

    # Pot rim
    for x in range(cx - 11, cx + 12):
        put_px(img, x, 12, noisy(r, lighten(pot_hi, 0.12), 3))
        put_px(img, x, 13, noisy(r, pot_hi, 3))

    # Soil visible
    for x in range(cx - 9, cx + 10):
        for y in range(10, 13):
            put_px(img, x, y, noisy(r, (72, 55, 38), 4))

    # Flowers/leaves
    flower_colors = [(215, 85, 75), (225, 185, 65), (185, 75, 135), (255, 255, 255)]
    leaf_c = (55, 82, 38)
    for fx in range(cx - 8, cx + 9, 4):
        # Leaves
        for ly in range(6, 12):
            for lx in range(fx - 2, fx + 3):
                if r.random() < 0.6:
                    put_px(img, lx, ly, noisy(r, leaf_c, 5))
        # Flower
        fc = r.choice(flower_colors)
        for dy in range(-2, 2):
            for dx in range(-2, 2):
                if abs(dx) + abs(dy) <= 2:
                    put_px(img, fx + dx, 5 + dy, noisy(r, fc, 5))
        # Center
        put_px(img, fx, 5, noisy(r, (225, 195, 65), 4))

    img.save(os.path.join(out_dir, "flower_planter.png"))
    print(f"  flower_planter.png ({W}x{H})")


# ============================================================
# TILES
# ============================================================

def make_grass_tile(out_dir):
    """Grass tile with blade detail and color variation."""
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = rng(1000)

    grass_hi = (88, 125, 62)
    grass_mid = (72, 105, 52)
    grass_lo = (58, 88, 42)

    # Base fill with noise
    for y in range(S):
        for x in range(S):
            t = r.random()
            if t < 0.33:
                base = grass_hi
            elif t < 0.66:
                base = grass_mid
            else:
                base = grass_lo
            put_px(img, x, y, noisy(r, base, 8))

    # Grass blade highlights
    for _ in range(80):
        bx = r.randint(0, S - 1)
        by = r.randint(0, S - 1)
        blen = r.randint(2, 5)
        bc = lighten(grass_hi, r.random() * 0.15)
        for i in range(blen):
            put_px(img, bx + r.randint(-1, 1), by - i, noisy(r, bc, 4))

    # Dark patches (soil showing through)
    for _ in range(8):
        px = r.randint(2, S - 3)
        py = r.randint(2, S - 3)
        put_px(img, px, py, noisy(r, darken(grass_lo, 0.15), 4))

    img.save(os.path.join(out_dir, "grass_tile.png"))
    print(f"  grass_tile.png ({S}x{S})")


def make_dirt_tile(out_dir):
    """Dirt path tile with pebble detail."""
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = rng(1100)

    dirt_hi = (158, 135, 105)
    dirt_mid = (135, 112, 82)
    dirt_lo = (112, 92, 65)

    for y in range(S):
        for x in range(S):
            t = r.random()
            if t < 0.3:
                base = dirt_hi
            elif t < 0.65:
                base = dirt_mid
            else:
                base = dirt_lo
            put_px(img, x, y, noisy(r, base, 7))

    # Small pebbles
    for _ in range(15):
        px = r.randint(1, S - 2)
        py = r.randint(1, S - 2)
        pc = lerp_color(dirt_hi, (175, 168, 155), 0.3)
        put_px(img, px, py, noisy(r, pc, 4))
        put_px(img, px + 1, py, noisy(r, darken(pc, 0.1), 4))

    img.save(os.path.join(out_dir, "dirt_tile.png"))
    print(f"  dirt_tile.png ({S}x{S})")


def make_road_tile(out_dir):
    """Asphalt road tile with texture."""
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = rng(1200)

    road_hi = (105, 102, 95)
    road_mid = (88, 85, 78)
    road_lo = (72, 68, 62)

    for y in range(S):
        for x in range(S):
            base = lerp_color(road_mid, road_lo, r.random() * 0.5)
            # Aggregate texture
            if r.random() < 0.05:
                base = lighten(base, 0.12)
            put_px(img, x, y, noisy(r, base, 5))

    img.save(os.path.join(out_dir, "road_tile.png"))
    print(f"  road_tile.png ({S}x{S})")


def make_sidewalk_tile(out_dir):
    """Concrete sidewalk tile with crack detail."""
    S = 64
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = rng(1300)

    side_hi = (178, 172, 162)
    side_mid = (162, 155, 148)
    side_lo = (145, 138, 130)

    for y in range(S):
        for x in range(S):
            base = lerp_color(side_mid, side_lo, r.random() * 0.4)
            put_px(img, x, y, noisy(r, base, 4))

    # Expansion joints (grid lines)
    for jx in [0, S // 2, S - 1]:
        for y in range(S):
            put_px(img, jx, y, noisy(r, darken(side_lo, 0.15), 3))
    for jy in [0, S // 2, S - 1]:
        for x in range(S):
            put_px(img, x, jy, noisy(r, darken(side_lo, 0.15), 3))

    # Small cracks
    cx = r.randint(10, S - 10)
    cy = r.randint(10, S - 10)
    for i in range(8):
        cx += r.randint(-1, 1)
        cy += 1
        if 0 <= cx < S and 0 <= cy < S:
            put_px(img, cx, cy, noisy(r, darken(side_lo, 0.2), 3))

    img.save(os.path.join(out_dir, "sidewalk_tile.png"))
    print(f"  sidewalk_tile.png ({S}x{S})")


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/environment_v5"
    os.makedirs(out_dir, exist_ok=True)

    print("Generating v5 environment sprites...")

    # Trees
    make_oak_tree(out_dir)
    make_pine_tree(out_dir)

    # Props
    make_lamppost(out_dir)
    make_bench(out_dir)
    make_mailbox(out_dir)
    make_barrel(out_dir)
    make_crate(out_dir)
    make_fire_hydrant(out_dir)
    make_flower_planter(out_dir)

    # Tiles
    make_grass_tile(out_dir)
    make_dirt_tile(out_dir)
    make_road_tile(out_dir)
    make_sidewalk_tile(out_dir)

    print("Done! All v5 environment sprites generated.")
