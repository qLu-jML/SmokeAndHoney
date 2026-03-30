#!/usr/bin/env python3
"""
High-fidelity pixel art flower generator v3 for Smoke & Honey.
Major quality increase: multi-layered petals, rich color ramps, 
proper shading, species-specific detail.
"""
from PIL import Image, ImageDraw
import math, random, os

random.seed(42)

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def make_ramp(shadow, mid, highlight, steps=5):
    ramp = []
    for i in range(steps):
        t = i / (steps - 1)
        if t <= 0.5:
            ramp.append(lerp_color(shadow, mid, t * 2))
        else:
            ramp.append(lerp_color(mid, highlight, (t - 0.5) * 2))
    return ramp


PALETTES = {
    'aster': {
        'petal': make_ramp((85, 40, 105), (155, 80, 165), (200, 140, 215)),
        'petal2': make_ramp((95, 50, 115), (170, 95, 180), (215, 155, 225)),  # outer petals lighter
        'center': make_ramp((140, 110, 20), (195, 165, 45), (235, 210, 85)),
        'stem': make_ramp((35, 58, 25), (55, 90, 40), (82, 125, 62)),
        'leaf': make_ramp((30, 62, 20), (50, 98, 38), (78, 132, 58)),
        'outline': (55, 30, 70),
    },
    'bergamot': {
        'petal': make_ramp((120, 25, 40), (190, 55, 70), (225, 100, 120)),
        'petal2': make_ramp((135, 35, 50), (205, 65, 85), (235, 115, 135)),
        'center': make_ramp((130, 35, 45), (175, 60, 80), (215, 110, 130)),
        'stem': make_ramp((35, 58, 25), (55, 90, 40), (82, 125, 62)),
        'leaf': make_ramp((30, 68, 22), (50, 104, 38), (75, 135, 56)),
        'outline': (80, 18, 30),
    },
    'clover': {
        'petal': make_ramp((140, 70, 100), (200, 130, 160), (230, 178, 200)),
        'petal2': make_ramp((155, 85, 115), (215, 145, 175), (240, 190, 210)),
        'center': make_ramp((120, 62, 85), (180, 115, 142), (215, 158, 178)),
        'stem': make_ramp((30, 58, 25), (48, 88, 38), (72, 118, 55)),
        'leaf': make_ramp((25, 65, 20), (45, 100, 36), (70, 135, 55)),
        'outline': (95, 48, 68),
    },
    'coneflower': {
        'petal': make_ramp((140, 50, 90), (195, 92, 138), (225, 142, 175)),
        'petal2': make_ramp((155, 65, 105), (208, 105, 150), (235, 158, 188)),
        'center': make_ramp((90, 48, 15), (140, 78, 30), (185, 115, 50)),
        'stem': make_ramp((35, 58, 25), (55, 90, 40), (82, 125, 62)),
        'leaf': make_ramp((30, 62, 22), (50, 98, 38), (75, 130, 58)),
        'outline': (95, 35, 60),
    },
    'dandelion': {
        'petal': make_ramp((175, 135, 15), (225, 185, 35), (248, 222, 75)),
        'petal2': make_ramp((185, 145, 20), (235, 195, 42), (252, 232, 85)),
        'center': make_ramp((155, 115, 10), (195, 155, 28), (228, 192, 55)),
        'stem': make_ramp((35, 62, 22), (55, 98, 38), (80, 130, 55)),
        'leaf': make_ramp((30, 68, 18), (50, 105, 35), (75, 135, 52)),
        'outline': (120, 92, 8),
    },
    'goldenrod': {
        'petal': make_ramp((165, 125, 10), (215, 170, 28), (242, 212, 62)),
        'petal2': make_ramp((175, 135, 15), (225, 180, 35), (248, 218, 68)),
        'center': make_ramp((145, 108, 8), (190, 150, 22), (225, 190, 52)),
        'stem': make_ramp((38, 62, 25), (58, 98, 42), (85, 132, 62)),
        'leaf': make_ramp((32, 66, 22), (52, 102, 38), (78, 135, 58)),
        'outline': (112, 85, 5),
    },
    'lavender': {
        'petal': make_ramp((72, 42, 112), (122, 82, 162), (168, 132, 205)),
        'petal2': make_ramp((82, 52, 122), (135, 95, 172), (178, 142, 212)),
        'center': make_ramp((85, 55, 105), (132, 95, 148), (172, 138, 190)),
        'stem': make_ramp((48, 62, 38), (72, 92, 58), (102, 122, 82)),
        'leaf': make_ramp((42, 65, 35), (68, 98, 55), (98, 128, 78)),
        'outline': (48, 28, 75),
    },
    'phacelia': {
        'petal': make_ramp((52, 42, 132), (92, 82, 182), (142, 132, 222)),
        'petal2': make_ramp((62, 52, 142), (105, 95, 192), (155, 145, 228)),
        'center': make_ramp((175, 155, 42), (215, 195, 72), (242, 225, 115)),
        'stem': make_ramp((35, 60, 28), (55, 95, 42), (82, 128, 65)),
        'leaf': make_ramp((30, 65, 22), (50, 100, 38), (75, 132, 58)),
        'outline': (35, 28, 88),
    },
    'sunflower': {
        'petal': make_ramp((185, 135, 5), (235, 185, 25), (252, 228, 65)),
        'petal2': make_ramp((195, 145, 10), (242, 195, 32), (255, 235, 72)),
        'center': make_ramp((52, 30, 12), (88, 55, 22), (125, 80, 35)),
        'stem': make_ramp((38, 65, 24), (58, 102, 40), (85, 135, 62)),
        'leaf': make_ramp((32, 70, 20), (52, 106, 38), (78, 138, 58)),
        'outline': (128, 92, 2),
    },
}

WITHER_RAMP = make_ramp((62, 48, 30), (102, 82, 52), (138, 115, 78))
WITHER_STEM = make_ramp((48, 40, 25), (78, 65, 40), (108, 90, 58))

def px(img, x, y, color, alpha=255):
    """Safe pixel set with alpha blending."""
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        if len(color) == 3:
            color = color + (alpha,)
        ex = img.getpixel((x, y))
        if ex[3] > 0 and alpha < 255:
            a = alpha / 255.0
            blended = tuple(int(ex[i]*(1-a) + color[i]*a) for i in range(3)) + (min(255, ex[3]+alpha),)
            img.putpixel((x, y), blended)
        else:
            img.putpixel((x, y), color)

def ellipse_shadow(img, cx, cy, rx, ry, intensity=55):
    for dy in range(-ry-1, ry+2):
        for dx in range(-rx-1, rx+2):
            d = (dx/max(rx,1))**2 + (dy/max(ry,1))**2
            if d <= 1.0:
                a = int(intensity * (1.0 - d * 0.7))
                px(img, cx+dx, cy+dy, (20, 16, 8), a)

def thick_stem(img, x, bot_y, top_y, pal, w=2, curve_amt=0):
    """Shaded stem with width and optional S-curve."""
    for y in range(top_y, bot_y+1):
        t = (y - top_y) / max(1, bot_y - top_y)
        cx_off = int(curve_amt * math.sin(t * math.pi)) if curve_amt else 0
        for dx in range(w):
            # Left edge darker, right lighter, middle mid
            if dx == 0:
                shade = pal[0]
            elif dx == w-1:
                shade = pal[3] if len(pal) > 3 else pal[-1]
            else:
                shade = pal[2]
            # Slightly darker at bottom
            if t > 0.8:
                shade = lerp_color(shade, pal[0], (t-0.8)*2)
            px(img, x+dx+cx_off, y, shade)

def nice_leaf(img, ox, oy, pal, direction=1, length=4, width=2):
    """Draw a detailed leaf with midrib and shading."""
    for i in range(length):
        # Taper width
        w = max(1, int(width * (1 - i/(length*1.2))))
        lx = ox + direction * (i+1)
        ly = oy - (i * 0.4)
        # Fill
        for j in range(-w, w+1):
            shade_idx = 3 if abs(j) < w//2+1 else 1
            if j < 0:
                shade_idx = max(0, shade_idx - 1)
            px(img, lx, ly+j, pal[min(shade_idx, len(pal)-1)])
        # Midrib highlight
        px(img, lx, ly, pal[4] if len(pal) > 4 else pal[-1])

def fill_circle(img, cx, cy, r, color, alpha=255):
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            if dx*dx + dy*dy <= r*r:
                px(img, cx+dx, cy+dy, color, alpha)

def outline_circle(img, cx, cy, r, color, alpha=255):
    for angle in range(360):
        rad = math.radians(angle)
        x = cx + r * math.cos(rad)
        y = cy + r * math.sin(rad)
        px(img, x, y, color, alpha)


# ============ MATURE FLOWERS (32x32) ============

def draw_aster_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 13
    ellipse_shadow(img, 16, 28, 7, 2)
    thick_stem(img, 15, 27, 17, p['stem'], w=2)
    nice_leaf(img, 14, 24, p['leaf'], -1, length=5, width=2)
    nice_leaf(img, 16, 21, p['leaf'], 1, length=4, width=2)
    # Outer petal ring (elongated star petals)
    for a in range(0, 360, 30):
        rad = math.radians(a)
        for r in [4, 5, 6, 7]:
            fx = cx + r * math.cos(rad)
            fy = cy + r * math.sin(rad) * 0.82
            s = p['petal2'][3 if r < 5 else (2 if r < 6 else 1)]
            if a > 150 and a < 330:
                s = p['petal'][1]  # shadow side
            px(img, fx, fy, s)
            # width - perpendicular
            px(img, fx + 0.5*math.sin(rad), fy - 0.5*math.cos(rad), 
               p['petal2'][2 if r < 6 else 0])
    # Inner petal ring
    for a in range(15, 360, 30):
        rad = math.radians(a)
        for r in [3, 4, 5]:
            fx = cx + r * math.cos(rad)
            fy = cy + r * math.sin(rad) * 0.82
            px(img, fx, fy, p['petal'][3 if r < 4 else 2])
    # Center disc with texture
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            d2 = dx*dx+dy*dy
            if d2 <= 6:
                s = p['center'][4 if dy < 0 else (3 if d2 <= 2 else 2)]
                if (dx+dy) % 2 == 0:
                    s = p['center'][min(4, 3 + (1 if dy<0 else 0))]
                px(img, cx+dx, cy+dy, s)
    # Outline hints
    for a in range(0, 360, 30):
        rad = math.radians(a)
        fx = cx + 7.5 * math.cos(rad)
        fy = cy + 7.5 * math.sin(rad) * 0.82
        px(img, fx, fy, p['outline'], 180)
    return img

def draw_bergamot_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 11
    ellipse_shadow(img, 16, 28, 7, 2)
    thick_stem(img, 15, 27, 16, p['stem'], w=2)
    nice_leaf(img, 14, 25, p['leaf'], -1, length=5, width=2)
    nice_leaf(img, 16, 22, p['leaf'], 1, length=5, width=2)
    # Spiky tubular flower head - multiple rings of spiky petals
    for ring in range(3):
        r_base = 2 + ring * 2
        for a in range(0, 360, 18):
            rad = math.radians(a + ring * 9)
            for r in range(r_base, r_base+3):
                fx = cx + r * math.cos(rad)
                fy = cy + r * math.sin(rad) * 0.7
                pal = p['petal2'] if ring > 0 else p['petal']
                shade = 4 if r == r_base else (2 if r < r_base+2 else 0)
                px(img, fx, fy, pal[shade])
            # Spiky tip
            fx = cx + (r_base+3) * math.cos(rad)
            fy = cy + (r_base+3) * math.sin(rad) * 0.7
            px(img, fx, fy, p['petal2'][4])
    # Dense center
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if dx*dx + dy*dy <= 5:
                px(img, cx+dx, cy+dy, p['center'][3 if dy < 0 else 2])
    return img

def draw_clover_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 13
    ellipse_shadow(img, 16, 28, 6, 2)
    thick_stem(img, 15, 27, 18, p['stem'], w=2)
    # Three-part clover leaves
    for lx, ly, d in [(-3, 25, -1), (3, 25, 1), (0, 23, 1)]:
        nice_leaf(img, 15+lx, ly, p['leaf'], d, length=3, width=2)
    # Puffy spherical flower head - many tiny overlapping florets
    for ring_r in [4, 3, 2]:
        for a in range(0, 360, 22):
            rad = math.radians(a)
            fx = cx + ring_r * math.cos(rad)
            fy = cy + ring_r * math.sin(rad) * 0.85
            pal = p['petal2'] if ring_r > 3 else p['petal']
            shade = 3 if ring_r < 3 else (2 if a < 180 else 1)
            # Each floret is a tiny cluster
            px(img, fx, fy, pal[shade])
            px(img, fx+1, fy, pal[min(4, shade+1)])
            px(img, fx, fy-1, pal[min(4, shade+1)])
    # Top highlight
    for dx in range(-2, 3):
        for dy in range(-2, 0):
            if dx*dx+dy*dy <= 4:
                px(img, cx+dx, cy+dy-1, p['petal2'][4], 120)
    # Subtle outline
    outline_circle(img, cx, cy, 5, p['outline'], 100)
    return img

def draw_coneflower_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 14
    ellipse_shadow(img, 16, 28, 7, 2)
    thick_stem(img, 15, 27, 19, p['stem'], w=2)
    nice_leaf(img, 14, 25, p['leaf'], -1, length=5, width=2)
    nice_leaf(img, 16, 22, p['leaf'], 1, length=4, width=2)
    # Drooping petals - each petal is a separate elongated shape that droops
    for a_deg in range(0, 360, 35):
        rad = math.radians(a_deg)
        droop = 0.3 if a_deg < 90 or a_deg > 270 else 0.6
        for r in range(3, 8):
            fx = cx + r * math.cos(rad)
            fy = cy + r * math.sin(rad) * 0.55 + r * droop
            pal = p['petal'] if r < 6 else p['petal2']
            shade = 3 if r < 5 else (2 if r < 6 else 1)
            if a_deg > 140 and a_deg < 320:
                shade = max(0, shade - 1)
            px(img, fx, fy, pal[shade])
            # Width
            px(img, fx, fy+1, pal[max(0, shade-1)])
            if r < 6:
                px(img, fx+0.5*math.sin(rad), fy-0.4*math.cos(rad), pal[shade])
    # Raised dome center
    for dy in range(-3, 2):
        for dx in range(-3, 4):
            d2 = dx*dx + dy*dy
            if d2 <= 10:
                # Dome shading - brighter on top
                shade = 4 if dy < -2 else (3 if dy < -1 else (2 if dy < 0 else 1))
                if (dx+dy) % 2 == 0:
                    shade = min(4, shade + 1)
                px(img, cx+dx, cy+dy-1, p['center'][shade])
    return img

def draw_dandelion_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 13
    ellipse_shadow(img, 16, 28, 6, 2)
    thick_stem(img, 15, 27, 18, p['stem'], w=2)
    # Jagged dandelion leaves (rosette at base)
    for side, d in [(-1, -1), (1, 1)]:
        for i in range(6):
            lx = 15 + side * (i+1)
            ly = 26 - i//2
            tooth = 1 if i % 2 == 0 else 0
            px(img, lx, ly - tooth, p['leaf'][2 + (1 if tooth else 0)])
            px(img, lx, ly - tooth - 1, p['leaf'][3])
    # Dense ray florets - many tiny elongated petals radiating outward
    for ring in range(2):
        offset = ring * 12
        for a in range(0, 360, 15):
            rad = math.radians(a + offset)
            for r in range(2+ring, 6+ring):
                fx = cx + r * math.cos(rad)
                fy = cy + r * math.sin(rad) * 0.88
                pal = p['petal'] if ring == 0 else p['petal2']
                shade = 4 if r < 3 else (3 if r < 5 else 2)
                if a > 160 and a < 340:
                    shade = max(0, shade - 1)
                px(img, fx, fy, pal[shade])
    # Bright center
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            px(img, cx+dx, cy+dy, p['center'][4 if dy < 0 else 3])
    return img

def draw_goldenrod_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    ellipse_shadow(img, 16, 29, 6, 2)
    thick_stem(img, 14, 28, 5, p['stem'], w=2, curve_amt=2)
    nice_leaf(img, 14, 26, p['leaf'], -1, length=5, width=2)
    nice_leaf(img, 15, 21, p['leaf'], 1, length=4, width=2)
    nice_leaf(img, 14, 17, p['leaf'], -1, length=3, width=1)
    # Plume of tiny flower clusters cascading
    # Main raceme shape - wider at top, tapering
    for y in range(4, 15):
        t = (y - 4) / 10.0
        spread = int(5 * (1 - t * 0.6))
        density = spread * 2
        curve_x = int(2 * math.sin(t * 2))
        for i in range(density):
            dx = int((i - density/2) * 1.2) + curve_x
            if abs(dx) <= spread:
                # Tiny floret
                pal = p['petal'] if (i+y) % 3 else p['petal2']
                shade = 4 if y < 7 else (3 if y < 10 else 2)
                if dx < 0:
                    shade = max(0, shade - 1)
                px(img, 15+dx, y, pal[shade])
                if y % 2 == 0 and i % 2 == 0:
                    px(img, 15+dx, y-1, pal[min(4, shade+1)], 180)
    return img

def draw_lavender_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx = 16
    ellipse_shadow(img, 16, 29, 6, 2)
    thick_stem(img, 15, 28, 11, p['stem'], w=2)
    # Narrow gray-green leaves
    for ly, d in [(26, -1), (24, 1), (22, -1)]:
        for i in range(4):
            px(img, 15 + d*(i+1), ly - i*0.3, p['leaf'][2])
            px(img, 15 + d*(i+1), ly - i*0.3 - 1, p['leaf'][3])
    # Flower spike - stacked whorls of tiny flowers
    for y in range(4, 16):
        if y < 6:
            w = 1
        elif y < 13:
            w = 2 + (1 if y < 10 else 0)
        else:
            w = 1
        for dx in range(-w, w+1):
            # Alternating floret/gap pattern
            if (y + dx) % 2 == 0:
                shade = 4 if y < 7 else (3 if y < 10 else (2 if y < 13 else 1))
                pal = p['petal'] if abs(dx) < w else p['petal2']
                px(img, cx+dx, y, pal[shade])
            else:
                # Calyx / gap
                if abs(dx) < w:
                    px(img, cx+dx, y, p['center'][2 if y < 10 else 1], 200)
    # Tip
    px(img, cx, 3, p['petal'][4])
    px(img, cx, 4, p['petal'][3])
    return img

def draw_phacelia_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 16, 13
    ellipse_shadow(img, 16, 28, 7, 2)
    thick_stem(img, 15, 27, 17, p['stem'], w=2)
    nice_leaf(img, 14, 25, p['leaf'], -1, length=5, width=2)
    nice_leaf(img, 16, 22, p['leaf'], 1, length=4, width=2)
    # Scorpioid cyme - curved clusters of bell-shaped flowers
    for cluster_a in [0, 120, 240]:
        for i in range(6):
            angle = math.radians(cluster_a + i * 18)
            r = 3 + i * 0.7
            fx = cx + r * math.cos(angle)
            fy = cy + r * math.sin(angle) * 0.75
            # Bell-shaped floret (3 pixels each)
            shade = 4 if i < 2 else (3 if i < 4 else 2)
            pal = p['petal'] if i < 3 else p['petal2']
            px(img, fx, fy, pal[shade])
            px(img, fx+1, fy, pal[max(0,shade-1)])
            px(img, fx, fy+1, pal[max(0,shade-1)])
            px(img, fx+1, fy+1, pal[max(0,shade-2)])
            # Protruding stamens
            px(img, fx+0.5, fy-1, p['center'][3], 200)
    return img

def draw_sunflower_mature(p):
    img = Image.new("RGBA", (32, 32), (0,0,0,0))
    cx, cy = 15, 12
    ellipse_shadow(img, 16, 29, 8, 3)
    # Thick stem
    thick_stem(img, 14, 28, 18, p['stem'], w=3)
    # Big serrated leaves
    nice_leaf(img, 13, 25, p['leaf'], -1, length=6, width=3)
    nice_leaf(img, 17, 21, p['leaf'], 1, length=6, width=3)
    # Large outer petals - two overlapping rings
    for ring, r_range in [(1, range(6, 10)), (0, range(4, 8))]:
        offset = 12 * ring
        for a in range(0, 360, 22):
            rad = math.radians(a + offset)
            for r in r_range:
                fx = cx + r * math.cos(rad)
                fy = cy + r * math.sin(rad) * 0.82
                pal = p['petal2'] if ring else p['petal']
                shade = 4 if r < r_range.start+1 else (3 if r < r_range.start+2 else (2 if a < 180 else 1))
                px(img, fx, fy, pal[shade])
                # Width
                px(img, fx + 0.5*math.sin(rad), fy - 0.5*math.cos(rad), pal[max(0,shade-1)])
    # Large textured center disc
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            d2 = dx*dx + dy*dy
            if d2 <= 18:
                # Spiral seed pattern
                angle = math.atan2(dy, dx)
                ring = math.sqrt(d2)
                spiral = int((angle * 3 + ring * 2)) % 3
                shade = [1, 2, 3][spiral]
                if dy < -1:
                    shade = min(4, shade + 1)
                if d2 > 14:
                    shade = max(0, shade - 1)
                px(img, cx+dx, cy+dy, p['center'][shade])
    # Center outline
    outline_circle(img, cx, cy, 4, p['outline'], 120)
    return img


# ============ LIFECYCLE STAGES ============

def draw_seed(p, species):
    img = Image.new("RGBA", (16, 16), (0,0,0,0))
    cx, cy = 8, 11
    seed_pal = make_ramp((72, 48, 25), (112, 78, 40), (148, 108, 58))
    # Ground mark
    for dx in range(-2, 3):
        px(img, cx+dx, cy+2, (40, 32, 18), 35)
    # Seed with highlight
    px(img, cx-1, cy, seed_pal[1])
    px(img, cx, cy, seed_pal[2])
    px(img, cx+1, cy, seed_pal[1])
    px(img, cx, cy-1, seed_pal[3])
    px(img, cx, cy+1, seed_pal[0])
    # Tiny highlight
    px(img, cx, cy-1, seed_pal[4], 180)
    return img

def draw_sprout(p, species):
    img = Image.new("RGBA", (16, 16), (0,0,0,0))
    cx = 8
    ellipse_shadow(img, cx, 13, 2, 1, 30)
    # Stem
    for y in range(8, 13):
        px(img, cx, y, p['stem'][2 if y < 11 else 1])
    # Cotyledon leaves - rounded
    for side in [-1, 1]:
        px(img, cx+side*1, 8, p['leaf'][2])
        px(img, cx+side*2, 8, p['leaf'][3])
        px(img, cx+side*2, 7, p['leaf'][4])
        px(img, cx+side*1, 7, p['leaf'][3])
    # Tiny growing tip
    px(img, cx, 7, p['leaf'][4])
    px(img, cx, 6, p['leaf'][3])
    return img

def draw_growing(p, species):
    img = Image.new("RGBA", (16, 16), (0,0,0,0))
    cx = 8
    ellipse_shadow(img, cx, 14, 3, 1, 30)
    # Taller stem
    for y in range(4, 14):
        px(img, cx, y, p['stem'][2 if y < 9 else (1 if y < 12 else 0)])
    # Better leaves
    for dx in [-3, -2, -1]:
        px(img, cx+dx, 11, p['leaf'][2])
        px(img, cx+dx, 10, p['leaf'][3])
    for dx in [1, 2, 3]:
        px(img, cx+dx, 9, p['leaf'][2])
        px(img, cx+dx, 8, p['leaf'][4])
    # Flower bud - species colored, partially open
    bud_base = lerp_color(p['leaf'][2], p['petal'][1], 0.3)
    bud_tip = lerp_color(p['leaf'][3], p['petal'][2], 0.5)
    px(img, cx-1, 4, p['leaf'][2])
    px(img, cx, 4, bud_base)
    px(img, cx+1, 4, p['leaf'][2])
    px(img, cx, 3, bud_tip)
    px(img, cx, 2, p['petal'][2], 150)
    return img

def draw_withered(p, species):
    img = Image.new("RGBA", (16, 16), (0,0,0,0))
    cx = 8
    ellipse_shadow(img, cx, 14, 3, 1, 25)
    # Drooping bent stem
    for y in range(5, 14):
        t = (y - 5) / 8.0
        curve = int(2.5 * math.sin(t * 1.3))
        px(img, cx+curve, y, WITHER_STEM[2 if y < 8 else (1 if y < 11 else 0)])
    # Dead flower head - drooping to one side
    head_x = cx + 3
    for dx in range(-2, 2):
        for dy in range(0, 2):
            shade = 2 if dy == 0 else 0
            px(img, head_x+dx, 5+dy, WITHER_RAMP[shade])
    px(img, head_x, 4, WITHER_RAMP[3])
    # Dead leaves
    px(img, cx-2, 11, WITHER_RAMP[1])
    px(img, cx-1, 10, WITHER_RAMP[2])
    px(img, cx+2, 9, WITHER_RAMP[1])
    px(img, cx+1, 8, WITHER_RAMP[2])
    return img


# ============ MAIN ============

MATURE_FNS = {
    'aster': draw_aster_mature,
    'bergamot': draw_bergamot_mature,
    'clover': draw_clover_mature,
    'coneflower': draw_coneflower_mature,
    'dandelion': draw_dandelion_mature,
    'goldenrod': draw_goldenrod_mature,
    'lavender': draw_lavender_mature,
    'phacelia': draw_phacelia_mature,
    'sunflower': draw_sunflower_mature,
}

def generate_all(output_dir):
    os.makedirs(output_dir, exist_ok=True)
    count = 0
    for species in PALETTES:
        pal = PALETTES[species]
        print(f"  {species}...")
        for stage, fn in [('seed', draw_seed), ('sprout', draw_sprout), 
                          ('growing', draw_growing), ('withered', draw_withered)]:
            img = fn(pal, species)
            img.save(os.path.join(output_dir, f"{species}_{stage}.png"))
            count += 1
        mature = MATURE_FNS[species](pal)
        mature.save(os.path.join(output_dir, f"{species}_mature.png"))
        mature.save(os.path.join(output_dir, f"{species}.png"))
        count += 2
    print(f"Generated {count} sprites")

if __name__ == "__main__":
    generate_all("/sessions/dreamy-eager-ramanujan/flower_v3")
