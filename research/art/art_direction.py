"""
Smoke & Honey - Art Direction & Master Palette
================================================
Visual references: Stardew Valley (detail/richness), Harvest Moon SNES (charm),
Graveyard Keeper (muted tones), Kynseed (British countryside warmth),
Eastward (atmospheric lighting)

Direction: Muted Midwest farmland. Dusty golden hour light. Weathered wood.
Aged brick. Iowa in late summer. Think Andrew Wyeth meets pixel art.
Not the candy-bright Stardew look -- more like sun-faded photographs.

Technical: 16px base tile. Characters ~32x60px. Buildings 2.5-3x character height.
Light source: upper-left (NW). Strong outlines in dark warm brown, not black.
Dithering for wood grain, brick texture, metal patina. Selective outlining.
"""

# ============================================================
# MASTER PALETTE - 48 colors, strict usage
# Each material has 4 values: highlight, mid, shadow, deep shadow
# ============================================================

PALETTE = {
    # -- Outlines & Darkest --
    "outline":      (58, 42, 32),     # warm dark brown, never pure black
    "outline_soft":  (78, 60, 48),     # softer outline for lit edges

    # -- Wood (weathered clapboard, barns, fences) --
    "wood_hi":      (178, 152, 118),
    "wood_mid":     (148, 120, 88),
    "wood_sha":     (118, 92, 64),
    "wood_deep":    (82, 62, 44),

    # -- Dark Wood (aged, stained) --
    "dkwood_hi":    (138, 108, 76),
    "dkwood_mid":   (108, 82, 56),
    "dkwood_sha":   (78, 58, 40),
    "dkwood_deep":  (54, 38, 26),

    # -- Brick (aged red, Iowa small-town) --
    "brick_hi":     (168, 98, 78),
    "brick_mid":    (142, 76, 60),
    "brick_sha":    (112, 58, 46),
    "brick_deep":   (82, 42, 34),

    # -- Stone / Concrete (sidewalks, foundations) --
    "stone_hi":     (178, 172, 158),
    "stone_mid":    (152, 146, 132),
    "stone_sha":    (122, 116, 104),
    "stone_deep":   (92, 86, 76),

    # -- Cream / White paint (farmhouses, trim) --
    "cream_hi":     (232, 222, 204),
    "cream_mid":    (212, 200, 182),
    "cream_sha":    (188, 176, 158),
    "cream_deep":   (162, 150, 134),

    # -- Green (dusty, muted -- shutters, awnings, foliage) --
    "green_hi":     (118, 148, 98),
    "green_mid":    (88, 118, 68),
    "green_sha":    (62, 88, 48),
    "green_deep":   (42, 62, 32),

    # -- Blue-gray (sky tint, glass, metal) --
    "blue_hi":      (142, 168, 182),
    "blue_mid":     (112, 138, 152),
    "blue_sha":     (82, 108, 122),
    "blue_deep":    (58, 78, 92),

    # -- Warm Red (barn red, awning stripe) --
    "red_hi":       (172, 72, 56),
    "red_mid":      (142, 52, 40),
    "red_sha":      (112, 38, 30),
    "red_deep":     (82, 28, 22),

    # -- Gold / Honey (accent, signs, warm light) --
    "gold_hi":      (218, 182, 98),
    "gold_mid":     (188, 148, 68),
    "gold_sha":     (152, 118, 48),
    "gold_deep":    (118, 88, 34),

    # -- Skin (warm, Iowa farmer) --
    "skin_hi":      (218, 192, 158),
    "skin_mid":     (198, 168, 132),
    "skin_sha":     (168, 138, 102),
    "skin_deep":    (132, 102, 72),

    # -- Metal (galvanized, tin roof, water tower) --
    "metal_hi":     (182, 178, 168),
    "metal_mid":    (158, 152, 142),
    "metal_sha":    (128, 122, 112),
    "metal_deep":   (98, 92, 82),

    # -- Dirt / Road --
    "dirt_hi":      (168, 148, 118),
    "dirt_mid":     (142, 122, 96),
    "dirt_sha":     (112, 94, 72),
    "dirt_deep":    (82, 68, 52),

    # -- Sky / Atmosphere --
    "sky_hi":       (192, 198, 202),
    "sky_mid":      (168, 178, 186),
}

# Interior warm glow color for windows at night/dusk
WINDOW_GLOW = (198, 168, 98, 120)
# Dithering helper: checkerboard pattern at (x,y)
def dither(x, y):
    return (x + y) % 2 == 0

print("Art direction palette defined: %d entries" % len(PALETTE))
