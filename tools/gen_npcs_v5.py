#!/usr/bin/env python3
"""
Smoke & Honey -- NPC Sprite Generator v5
3/4 top-down perspective matching the player character.
Hue-shifted shadows, per-pixel noise, individual character detail.

Player reference: 29x57 visible pixels on 120x120 canvas, 71 colors
NPCs: ~24-30px wide, 50-65px tall on 64x80 canvas
"""
from PIL import Image, ImageDraw
import random, os, sys, math

OUTLINE = (72, 37, 16)

def rng(seed=42):
    return random.Random(seed)

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def noisy(r, color, variance=6):
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


def draw_ellipse_filled(img, cx, cy, rx, ry, color_hi, color_lo, r_seed,
                         noise_v=5, outline_color=None):
    """Draw a filled ellipse with gradient shading and noise."""
    r = rng(r_seed)
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            dx = (x - cx) / max(1, rx)
            dy = (y - cy) / max(1, ry)
            dist = dx * dx + dy * dy
            if dist <= 1.0:
                # Shading: upper-left lighter
                lit = (1 - (y - (cy - ry)) / (ry * 2)) * 0.5 + (1 - (x - (cx - rx)) / (rx * 2)) * 0.3
                c = lerp_color(color_lo, color_hi, lit)
                if lit > 0.5:
                    c = hue_shift_highlight(c, 0.06)
                else:
                    c = hue_shift_shadow(c, 0.08)
                a = 255 if dist < 0.8 else int(255 * (1 - (dist - 0.8) / 0.2))
                put_px(img, x, y, noisy(r, c, noise_v), a)

    # Outline
    if outline_color:
        for angle in range(0, 360, 2):
            rad = math.radians(angle)
            ex = int(cx + math.cos(rad) * rx)
            ey = int(cy + math.sin(rad) * ry)
            put_px(img, ex, ey, noisy(r, outline_color, 3))


def draw_npc(img, cx, base_y, skin, hair_color, shirt_color, pants_color,
             hat_type=None, hat_color=None, hair_style="short",
             has_apron=False, apron_color=None, has_overalls=False,
             overalls_color=None, boot_color=None, seed=42):
    """Draw a 3/4 top-down NPC character.

    In 3/4 view from above:
    - Top of head/hat is most visible
    - Face is partially visible (forehead and upper face)
    - Body is foreshortened (torso shorter, visible from above)
    - Legs shorter, feet barely visible

    cx: center x
    base_y: bottom of feet y
    """
    r = rng(seed)

    skin_hi = hue_shift_highlight(skin, 0.08)
    skin_lo = hue_shift_shadow(skin, 0.12)

    if boot_color is None:
        boot_color = (62, 45, 28)
    boot_hi = lighten(boot_color, 0.1)
    boot_lo = darken(boot_color, 0.15)

    shirt_hi = lighten(shirt_color, 0.1)
    shirt_lo = darken(shirt_color, 0.2)

    pants_hi = lighten(pants_color, 0.08)
    pants_lo = darken(pants_color, 0.18)

    hair_hi = lighten(hair_color, 0.12)
    hair_lo = darken(hair_color, 0.2)

    # === FEET / BOOTS (bottom) ===
    foot_y = base_y - 3
    for foot_cx in [cx - 4, cx + 3]:
        for y in range(foot_y, foot_y + 3):
            t = (y - foot_y) / 3
            for x in range(foot_cx - 3, foot_cx + 3):
                ht = (x - (foot_cx - 3)) / 6
                c = lerp_color(boot_hi, boot_lo, t * 0.4 + ht * 0.3)
                put_px(img, x, y, noisy(r, c, 4))

    # === LEGS / PANTS ===
    leg_top = foot_y - 12
    for y in range(leg_top, foot_y):
        t = (y - leg_top) / 12
        # Two legs visible
        for leg_cx in [cx - 4, cx + 3]:
            hw = 3
            for x in range(leg_cx - hw, leg_cx + hw):
                ht = (x - (leg_cx - hw)) / (hw * 2)
                base_c = pants_color
                if has_overalls and overalls_color:
                    base_c = overalls_color
                c_hi = lighten(base_c, 0.1)
                c_lo = darken(base_c, 0.2)
                c = lerp_color(c_hi, c_lo, ht * 0.4 + t * 0.2)
                c = hue_shift_shadow(c, 0.05) if ht > 0.5 else c
                put_px(img, x, y, noisy(r, c, 5))

    # === TORSO ===
    torso_top = leg_top - 14
    torso_w = 12
    for y in range(torso_top, leg_top):
        t = (y - torso_top) / 14
        hw = torso_w // 2
        for x in range(cx - hw, cx + hw):
            ht = (x - (cx - hw)) / (hw * 2)
            if has_overalls and overalls_color:
                # Overalls bib on front
                if abs(ht - 0.5) < 0.35 and t > 0.3:
                    ov_hi = lighten(overalls_color, 0.08)
                    ov_lo = darken(overalls_color, 0.15)
                    c = lerp_color(ov_hi, ov_lo, ht * 0.3 + t * 0.2)
                else:
                    c = lerp_color(shirt_hi, shirt_lo, ht * 0.35 + t * 0.25)
            elif has_apron and apron_color:
                if abs(ht - 0.5) < 0.4 and t > 0.2:
                    ap_hi = lighten(apron_color, 0.1)
                    ap_lo = darken(apron_color, 0.15)
                    c = lerp_color(ap_hi, ap_lo, t * 0.3 + ht * 0.2)
                else:
                    c = lerp_color(shirt_hi, shirt_lo, ht * 0.35 + t * 0.25)
            else:
                c = lerp_color(shirt_hi, shirt_lo, ht * 0.35 + t * 0.25)

            c = hue_shift_shadow(c, 0.06) if ht > 0.6 else hue_shift_highlight(c, 0.04)
            put_px(img, x, y, noisy(r, c, 5))

    # Overall straps
    if has_overalls and overalls_color:
        strap_c = darken(overalls_color, 0.1)
        for y in range(torso_top + 2, torso_top + 8):
            put_px(img, cx - 3, y, noisy(r, strap_c, 3))
            put_px(img, cx + 2, y, noisy(r, strap_c, 3))

    # === ARMS (simplified, at sides) ===
    arm_top = torso_top + 2
    arm_bot = torso_top + 12
    for y in range(arm_top, arm_bot):
        t = (y - arm_top) / (arm_bot - arm_top)
        for arm_x, side in [(cx - torso_w // 2 - 2, -1), (cx + torso_w // 2 + 1, 1)]:
            for dx in range(3):
                if t < 0.6:
                    c = lerp_color(shirt_hi, shirt_lo, t + dx * 0.15)
                else:
                    c = lerp_color(skin_hi, skin_lo, (t - 0.6) * 2 + dx * 0.2)
                put_px(img, arm_x + dx * side, y, noisy(r, c, 4))

    # === HEAD ===
    head_cy = torso_top - 5
    head_rx = 6
    head_ry = 7

    # Back of head (hair visible from above in 3/4 view)
    for y in range(head_cy - head_ry, head_cy + 2):
        t = (y - (head_cy - head_ry)) / (head_ry + 2)
        hw = int(head_rx * math.sqrt(max(0, 1 - ((y - head_cy) / head_ry) ** 2))) if abs(y - head_cy) <= head_ry else 0
        for x in range(cx - hw, cx + hw + 1):
            ht = (x - (cx - hw)) / max(1, hw * 2)
            if y < head_cy - 2:
                # Hair/top of head
                c = lerp_color(hair_hi, hair_lo, ht * 0.4 + (1 - t) * 0.3)
            else:
                # Face (skin visible)
                c = lerp_color(skin_hi, skin_lo, ht * 0.3 + t * 0.2)
            c = hue_shift_shadow(c, 0.06) if ht > 0.6 else hue_shift_highlight(c, 0.05)
            put_px(img, x, y, noisy(r, c, 4))

    # Face details (eyes, visible from 3/4 above)
    eye_y = head_cy - 1
    for ex in [cx - 3, cx + 2]:
        put_px(img, ex, eye_y, noisy(r, (35, 28, 22), 3))
        put_px(img, ex + 1, eye_y, noisy(r, (25, 20, 15), 3))
        # Eyebrow
        put_px(img, ex, eye_y - 1, noisy(r, darken(hair_color, 0.1), 3))
        put_px(img, ex + 1, eye_y - 1, noisy(r, darken(hair_color, 0.1), 3))

    # Lower face (mouth area, partially visible)
    for x in range(cx - 2, cx + 3):
        face_c = lerp_color(skin, skin_lo, 0.15)
        put_px(img, x, head_cy + 2, noisy(r, face_c, 3))

    # Hair styling
    if hair_style == "short":
        # Hair on top and sides
        for y in range(head_cy - head_ry - 1, head_cy - 3):
            hw = int(head_rx * 0.9 * math.sqrt(max(0, 1 - ((y - head_cy) / head_ry) ** 2)))
            for x in range(cx - hw - 1, cx + hw + 2):
                c = lerp_color(hair_hi, hair_lo, r.random() * 0.4 + 0.3)
                put_px(img, x, y, noisy(r, c, 4))
    elif hair_style == "long":
        # Hair extends down past shoulders
        for y in range(head_cy - head_ry - 1, torso_top + 4):
            hw_base = head_rx + 1
            if y > head_cy:
                t = (y - head_cy) / (torso_top + 4 - head_cy)
                hw = int(hw_base * (1 - t * 0.3))
            else:
                hw = hw_base
            for x in range(cx - hw, cx + hw + 1):
                c = lerp_color(hair_hi, hair_lo, r.random() * 0.35 + 0.3)
                put_px(img, x, y, noisy(r, c, 5))
    elif hair_style == "bald":
        pass  # Just show scalp (skin color on top)

    # === HAT ===
    if hat_type and hat_color:
        hat_hi = lighten(hat_color, 0.12)
        hat_lo = darken(hat_color, 0.2)

        if hat_type == "straw":
            # Wide brim straw hat (seen from above, brim dominates)
            brim_rx = 10
            brim_ry = 5
            hat_top = head_cy - head_ry - 4
            # Crown
            for y in range(hat_top, hat_top + 5):
                t = (y - hat_top) / 5
                hw = 5
                for x in range(cx - hw, cx + hw + 1):
                    ht = (x - (cx - hw)) / (hw * 2)
                    c = lerp_color(hat_hi, hat_lo, ht * 0.35 + t * 0.25)
                    # Straw texture
                    if r.random() < 0.15:
                        c = darken(c, 0.08)
                    put_px(img, x, y, noisy(r, c, 5))
            # Brim (wide, elliptical)
            brim_y = hat_top + 4
            for y in range(brim_y, brim_y + brim_ry * 2):
                t = (y - brim_y) / (brim_ry * 2)
                hw = int(brim_rx * math.sqrt(max(0, 1 - ((t - 0.5) * 2) ** 2)))
                for x in range(cx - hw, cx + hw + 1):
                    ht = (x - (cx - hw)) / max(1, hw * 2)
                    c = lerp_color(hat_hi, hat_lo, ht * 0.3 + t * 0.2)
                    if r.random() < 0.12:
                        c = darken(c, 0.06)
                    put_px(img, x, y, noisy(r, c, 5))
            # Hat band
            for x in range(cx - 5, cx + 6):
                put_px(img, x, brim_y + 1, noisy(r, darken(hat_color, 0.3), 3))

        elif hat_type == "cap":
            cap_top = head_cy - head_ry - 2
            # Cap dome
            for y in range(cap_top, cap_top + 5):
                t = (y - cap_top) / 5
                hw = int(5 + t * 2)
                for x in range(cx - hw, cx + hw + 1):
                    ht = (x - (cx - hw)) / (hw * 2)
                    c = lerp_color(hat_hi, hat_lo, ht * 0.4 + t * 0.2)
                    put_px(img, x, y, noisy(r, c, 4))
            # Bill
            for y in range(cap_top + 4, cap_top + 7):
                for x in range(cx - 7, cx + 8):
                    t = (y - cap_top - 4) / 3
                    ht = (x - (cx - 7)) / 14
                    c = lerp_color(hat_hi, darken(hat_lo, 0.1), t * 0.4 + ht * 0.2)
                    put_px(img, x, y, noisy(r, c, 4))

        elif hat_type == "wide":
            # Cowboy/wide brim
            brim_rx = 11
            hat_top = head_cy - head_ry - 3
            for y in range(hat_top, hat_top + 4):
                hw = 4
                for x in range(cx - hw, cx + hw + 1):
                    ht = (x - (cx - hw)) / (hw * 2)
                    c = lerp_color(hat_hi, hat_lo, ht * 0.35)
                    put_px(img, x, y, noisy(r, c, 4))
            # Brim
            brim_y = hat_top + 3
            for y in range(brim_y, brim_y + 6):
                t = (y - brim_y) / 6
                hw = int(brim_rx * (0.6 + t * 0.4))
                for x in range(cx - hw, cx + hw + 1):
                    ht = (x - (cx - hw)) / max(1, hw * 2)
                    c = lerp_color(hat_hi, hat_lo, ht * 0.3 + t * 0.15)
                    put_px(img, x, y, noisy(r, c, 4))

    # === SHADOW ===
    for sx in range(cx - 6, cx + 7):
        dist = abs(sx - cx) / 7
        a = int((1 - dist) * 30)
        put_px(img, sx + 1, base_y, (20, 15, 25), a)
        put_px(img, sx + 1, base_y + 1, (20, 15, 25), a // 2)

    # === BODY OUTLINE (subtle warm brown) ===
    # Scan and add outline to any opaque pixel at a transparent boundary
    temp = img.copy()
    for y in range(1, img.height - 1):
        for x in range(1, img.width - 1):
            p = temp.getpixel((x, y))
            if p[3] > 200:
                # Check neighbors
                for nx, ny in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                    if 0 <= nx < img.width and 0 <= ny < img.height:
                        np_val = temp.getpixel((nx, ny))
                        if np_val[3] < 50:
                            put_px(img, x, y, noisy(r, OUTLINE, 3))
                            break


# ============================================================
# NPC DEFINITIONS
# ============================================================

# Skin tones
SKIN_LIGHT = (215, 178, 148)
SKIN_MEDIUM = (192, 152, 118)
SKIN_WARM = (195, 155, 112)
SKIN_TAN = (178, 138, 105)
SKIN_DARK = (142, 98, 68)

# Hair
HAIR_BROWN = (82, 58, 35)
HAIR_DARK = (42, 32, 22)
HAIR_GRAY = (142, 138, 132)
HAIR_WHITE = (192, 188, 182)
HAIR_RED = (145, 65, 32)
HAIR_BLONDE = (185, 158, 95)
HAIR_AUBURN = (115, 55, 28)


def make_uncle_bob(out_dir):
    """Uncle Bob: elderly, overalls, straw hat, friendly mentor."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_WARM, HAIR_WHITE,
             shirt_color=(142, 118, 88),  # tan work shirt
             pants_color=(72, 82, 98),     # blue
             hat_type="straw", hat_color=(195, 178, 128),
             has_overalls=True, overalls_color=(72, 82, 105),
             boot_color=(72, 52, 32),
             seed=100)
    img.save(os.path.join(out_dir, "uncle_bob.png"))
    print(f"  uncle_bob.png")


def make_frank_fischbach(out_dir):
    """Frank Fischbach: market vendor, cap, friendly."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_MEDIUM, HAIR_BROWN,
             shirt_color=(85, 115, 72),   # green shirt
             pants_color=(82, 72, 55),     # khaki
             hat_type="cap", hat_color=(62, 85, 52),
             boot_color=(68, 48, 28),
             seed=200)
    img.save(os.path.join(out_dir, "frank_fischbach.png"))
    print(f"  frank_fischbach.png")


def make_walt_harmon(out_dir):
    """Walt Harmon: older farmer, wide hat, plaid-ish shirt."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_TAN, HAIR_GRAY,
             shirt_color=(128, 95, 72),    # brown flannel
             pants_color=(72, 68, 58),     # dark work pants
             hat_type="wide", hat_color=(115, 88, 58),
             boot_color=(72, 52, 32),
             seed=300)
    img.save(os.path.join(out_dir, "walt_harmon.png"))
    print(f"  walt_harmon.png")


def make_rose_waitress(out_dir):
    """Rose: young waitress at Crossroads Diner, apron."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_LIGHT, HAIR_RED,
             shirt_color=(165, 55, 45),    # red diner uniform
             pants_color=(42, 42, 45),     # black pants
             hair_style="long",
             has_apron=True, apron_color=(225, 218, 205),
             boot_color=(45, 35, 28),
             seed=400)
    img.save(os.path.join(out_dir, "rose_waitress.png"))
    print(f"  rose_waitress.png")


def make_june_postmaster(out_dir):
    """June: postmaster, neat appearance, professional."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_LIGHT, HAIR_AUBURN,
             shirt_color=(58, 68, 98),     # navy blue uniform
             pants_color=(52, 55, 62),     # dark slacks
             hair_style="short",
             boot_color=(42, 32, 22),
             seed=500)
    img.save(os.path.join(out_dir, "june_postmaster.png"))
    print(f"  june_postmaster.png")


def make_lloyd_petersen(out_dir):
    """Lloyd Petersen: feed store owner, stocky, cap."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_MEDIUM, HAIR_BROWN,
             shirt_color=(155, 118, 78),   # tan shirt
             pants_color=(62, 58, 48),     # dark brown
             hat_type="cap", hat_color=(115, 85, 55),
             has_apron=True, apron_color=(142, 115, 78),  # work apron
             boot_color=(68, 48, 28),
             seed=600)
    img.save(os.path.join(out_dir, "lloyd_petersen.png"))
    print(f"  lloyd_petersen.png")


def make_dr_harwick(out_dir):
    """Dr. Harwick: vet, glasses, professional."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_LIGHT, HAIR_DARK,
             shirt_color=(218, 215, 205),  # white coat
             pants_color=(52, 55, 62),     # dark slacks
             hair_style="short",
             boot_color=(42, 35, 25),
             seed=700)
    img.save(os.path.join(out_dir, "dr_harwick.png"))
    print(f"  dr_harwick.png")


def make_carl_tanner(out_dir):
    """Carl Tanner: mechanic, cap, grease-stained."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_TAN, HAIR_DARK,
             shirt_color=(95, 92, 85),     # gray work shirt
             pants_color=(62, 58, 52),     # dark work pants
             hat_type="cap", hat_color=(72, 68, 62),
             boot_color=(55, 42, 28),
             seed=800)
    img.save(os.path.join(out_dir, "carl_tanner.png"))
    print(f"  carl_tanner.png")


def make_kacey_harmon(out_dir):
    """Kacey Harmon: young woman, Walt's granddaughter."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_LIGHT, HAIR_BLONDE,
             shirt_color=(95, 125, 142),   # light blue
             pants_color=(82, 72, 55),     # tan
             hair_style="long",
             boot_color=(88, 62, 38),
             seed=900)
    img.save(os.path.join(out_dir, "kacey_harmon.png"))
    print(f"  kacey_harmon.png")


def make_darlene_kowalski(out_dir):
    """Darlene Kowalski: older woman, town gossip."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_LIGHT, HAIR_GRAY,
             shirt_color=(138, 82, 95),    # mauve/purple
             pants_color=(62, 58, 52),     # dark
             hair_style="short",
             boot_color=(52, 38, 25),
             seed=1000)
    img.save(os.path.join(out_dir, "darlene_kowalski.png"))
    print(f"  darlene_kowalski.png")


def make_terri_vogel(out_dir):
    """Terri Vogel: fellow beekeeper, neighbor."""
    W, H = 64, 80
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_npc(img, W // 2, H - 8, SKIN_WARM, HAIR_AUBURN,
             shirt_color=(188, 172, 128),  # khaki/beekeeping
             pants_color=(78, 72, 58),     # olive
             hat_type="wide", hat_color=(182, 172, 148),
             boot_color=(72, 55, 35),
             seed=1100)
    img.save(os.path.join(out_dir, "terri_vogel.png"))
    print(f"  terri_vogel.png")


def make_pedestrians(out_dir):
    """6 generic pedestrian NPCs with varied appearances."""
    configs = [
        ("pedestrian_a", SKIN_MEDIUM, HAIR_BROWN, (108, 88, 68), (62, 58, 52),
         "short", "cap", (82, 75, 65), 2000),
        ("pedestrian_b", SKIN_LIGHT, HAIR_BLONDE, (125, 85, 95), (52, 48, 42),
         "long", None, None, 2100),
        ("pedestrian_c", SKIN_TAN, HAIR_DARK, (78, 95, 78), (72, 68, 58),
         "short", "cap", (55, 72, 48), 2200),
        ("pedestrian_d", SKIN_LIGHT, HAIR_RED, (92, 108, 128), (52, 52, 55),
         "long", None, None, 2300),
        ("pedestrian_e", SKIN_DARK, HAIR_DARK, (148, 128, 98), (55, 52, 48),
         "short", None, None, 2400),
        ("pedestrian_f", SKIN_MEDIUM, HAIR_GRAY, (118, 108, 95), (62, 55, 48),
         "short", "straw", (178, 162, 118), 2500),
    ]

    for name, skin, hair, shirt, pants, style, hat, hat_c, seed in configs:
        W, H = 64, 80
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw_npc(img, W // 2, H - 8, skin, hair,
                 shirt_color=shirt, pants_color=pants,
                 hair_style=style,
                 hat_type=hat, hat_color=hat_c,
                 seed=seed)
        img.save(os.path.join(out_dir, f"{name}.png"))
        print(f"  {name}.png")


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/npcs_v5"
    os.makedirs(out_dir, exist_ok=True)

    print("Generating v5 NPCs (3/4 top-down, hue-shifted, detailed)...")
    make_uncle_bob(out_dir)
    make_frank_fischbach(out_dir)
    make_walt_harmon(out_dir)
    make_rose_waitress(out_dir)
    make_june_postmaster(out_dir)
    make_lloyd_petersen(out_dir)
    make_dr_harwick(out_dir)
    make_carl_tanner(out_dir)
    make_kacey_harmon(out_dir)
    make_darlene_kowalski(out_dir)
    make_terri_vogel(out_dir)
    make_pedestrians(out_dir)

    print("Done! All v5 NPCs generated.")
