#!/usr/bin/env python3
"""
Frame Simulation Mockup Generator
===================================
Creates "Find the Queen" mockup images at varying difficulty levels.
Bee sprites scattered on honeycomb frames with one queen hidden.

Difficulty levels:
  - Easy:      fewer bees (35-45), more spacing, lighter breed
  - Medium:    moderate bees (55-65), standard spacing
  - Hard:      many bees (75-85), tighter clustering, darker breed
  - Very Hard: packed frame (90-110), dense clusters, darkest breed
"""

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

import generate_nurse_bee as gen

# ---------------------------------------------------------------------------
# Honeycomb background
# ---------------------------------------------------------------------------

def generate_honeycomb_bg(width, height, cell_state="brood"):
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)

    if cell_state == "brood":
        base_colors = [
            (165, 135, 85),   # capped brood
            (175, 145, 90),
            (155, 125, 78),
            (190, 170, 110),  # open larva
            (200, 180, 130),  # empty drawn
            (210, 175, 80),   # nectar
            (185, 150, 60),   # curing
        ]
        weights = [30, 25, 20, 8, 7, 5, 5]
    else:
        base_colors = [
            (195, 155, 50),
            (210, 170, 60),
            (180, 140, 45),
            (220, 185, 75),
            (200, 165, 55),
        ]
        weights = [30, 25, 20, 15, 10]

    hex_r = 8
    hex_w = int(hex_r * math.sqrt(3))
    row_h = int(hex_r * 2 * 0.75)
    rng = random.Random(42)

    draw.rectangle([0, 0, width, height], fill=(160, 130, 80))

    for row in range(height // row_h + 2):
        for col in range(width // hex_w + 2):
            cx = col * hex_w + (hex_w // 2 if row % 2 else 0)
            cy = row * row_h
            color = rng.choices(base_colors, weights=weights, k=1)[0]
            color = tuple(max(0, min(255, c + rng.randint(-8, 8))) for c in color)
            points = []
            for i in range(6):
                angle = math.radians(60 * i + 30)
                px = cx + hex_r * math.cos(angle)
                py = cy + hex_r * math.sin(angle)
                points.append((px, py))
            draw.polygon(points, fill=color, outline=(140, 115, 70))

    # Frame edge vignette
    for bw in range(15):
        alpha = int(60 * (1 - bw / 15))
        c = (80 - alpha // 2, 60 - alpha // 2, 35 - alpha // 3)
        draw.rectangle([bw, bw, width - 1 - bw, height - 1 - bw], outline=c)

    return img


# ---------------------------------------------------------------------------
# Bee placement
# ---------------------------------------------------------------------------

def place_bees_on_frame(bg_img, breed_key, num_workers, min_spacing, cluster_tightness,
                         include_queen=True, seed=123):
    """
    Scatter bees on a frame.
    cluster_tightness: std dev fraction of frame size (smaller = tighter clusters)
    min_spacing: minimum px between bee centers
    """
    rng = random.Random(seed)
    width, height = bg_img.size
    result = bg_img.copy().convert("RGBA")
    pal = gen.BREED_PALETTES[breed_key]
    queen_pos = None

    total = num_workers + (1 if include_queen else 0)
    positions = []

    for i in range(total):
        is_queen = (i == num_workers) and include_queen
        placed = False
        for _ in range(200):
            x = int(rng.gauss(width * 0.5, width * cluster_tightness))
            y = int(rng.gauss(height * 0.5, height * cluster_tightness))
            margin = 25
            if not (margin < x < width - margin and margin < y < height - margin):
                continue
            too_close = any(math.sqrt((x-px)**2 + (y-py)**2) < min_spacing
                           for px, py, _, _, _ in positions)
            if not too_close:
                placed = True
                break

        if not placed:
            # Force place if we ran out of attempts
            x = rng.randint(30, width - 30)
            y = rng.randint(30, height - 30)

        direction = rng.randint(0, 7)
        frame_idx = rng.randint(0, 6)
        positions.append((x, y, direction, frame_idx, is_queen))
        if is_queen:
            queen_pos = (x, y)

    # Depth sort by y
    positions.sort(key=lambda p: p[1])

    # Render and paste
    bee_scale = 1.3
    for x, y, direction, frame_idx, is_queen in positions:
        is_idle = frame_idx >= gen.WALK_FRAMES
        f_idx = frame_idx if not is_idle else frame_idx - gen.WALK_FRAMES
        bee_img = gen.render_bee_frame(pal, f_idx, is_idle=is_idle, is_queen=is_queen)

        bee_w = int(gen.CELL_W * bee_scale)
        bee_h = int(gen.CELL_H * bee_scale)
        bee_scaled = bee_img.resize((bee_w, bee_h), Image.LANCZOS)

        angle = gen.DIR_ANGLES[direction]
        if angle != 0:
            diag = int(math.ceil(math.sqrt(bee_w**2 + bee_h**2)))
            pad = diag // 2 + 8
            padded = Image.new("RGBA", (bee_w + pad*2, bee_h + pad*2), (0,0,0,0))
            padded.paste(bee_scaled, (pad, pad), bee_scaled)
            bee_scaled = padded.rotate(angle, resample=Image.BICUBIC, expand=False)
            rcx = bee_scaled.width // 2
            rcy = bee_scaled.height // 2
            bee_scaled = bee_scaled.crop((rcx - bee_w//2, rcy - bee_h//2,
                                          rcx + bee_w//2, rcy + bee_h//2))

        result.paste(bee_scaled, (x - bee_w//2, y - bee_h//2), bee_scaled)

    return result, queen_pos


def add_frame_border(img):
    draw = ImageDraw.Draw(img)
    w, h = img.size
    bar_h = 22
    wood = (110, 78, 45)
    hi = (135, 98, 58)
    sh = (85, 58, 32)

    draw.rectangle([0, 0, w, bar_h], fill=wood)
    draw.line([(0, bar_h//3), (w, bar_h//3)], fill=hi, width=2)
    draw.line([(0, bar_h), (w, bar_h)], fill=sh, width=1)
    draw.rectangle([0, h - bar_h, w, h], fill=wood)
    draw.line([(0, h - bar_h), (w, h - bar_h)], fill=sh, width=1)
    draw.line([(0, h - bar_h//3), (w, h - bar_h//3)], fill=hi, width=2)

    side_w = 12
    draw.rectangle([0, 0, side_w, h], fill=wood)
    draw.line([(side_w, 0), (side_w, h)], fill=sh, width=1)
    draw.rectangle([w - side_w, 0, w, h], fill=wood)
    draw.line([(w - side_w, 0), (w - side_w, h)], fill=sh, width=1)
    return img


def add_queen_reveal(img, queen_pos, radius=35):
    reveal = img.copy()
    draw = ImageDraw.Draw(reveal)
    if queen_pos:
        qx, qy = queen_pos
        draw.ellipse([qx-radius, qy-radius, qx+radius, qy+radius],
                     outline=(255, 60, 60), width=2)
        draw.text((qx - radius, qy - radius - 14), "QUEEN", fill=(255, 60, 60))
    return reveal


def add_difficulty_label(img, label):
    draw = ImageDraw.Draw(img)
    draw.rectangle([14, 24, 14 + len(label) * 7 + 10, 40], fill=(0, 0, 0, 180))
    draw.text((19, 26), label, fill=(255, 255, 255, 220))
    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    out_dir = Path(__file__).resolve().parent / "find_the_queen"
    out_dir.mkdir(parents=True, exist_ok=True)
    frame_w, frame_h = 800, 450

    # Difficulty configurations
    # breed, workers, min_spacing, cluster_tightness, label, seed
    sims = [
        # EASY (4) -- fewer bees, more space, lighter breeds
        {
            "breed": "italian", "workers": 35, "min_spacing": 28,
            "cluster": 0.28, "label": "EASY - Italian Brood",
            "seed": 11, "tag": "easy_italian",
        },
        {
            "breed": "buckfast", "workers": 40, "min_spacing": 26,
            "cluster": 0.26, "label": "EASY - Buckfast Brood",
            "seed": 22, "tag": "easy_buckfast",
        },
        {
            "breed": "caucasian", "workers": 30, "min_spacing": 30,
            "cluster": 0.30, "label": "EASY - Caucasian Sparse",
            "seed": 33, "tag": "easy_caucasian",
        },
        {
            "breed": "italian", "workers": 38, "min_spacing": 27,
            "cluster": 0.27, "label": "EASY - Italian Honey",
            "seed": 44, "tag": "easy_italian2",
        },
        # HARD (4) -- more bees, tighter clusters
        {
            "breed": "carniolan", "workers": 75, "min_spacing": 18,
            "cluster": 0.20, "label": "HARD - Carniolan Brood",
            "seed": 55, "tag": "hard_carniolan",
        },
        {
            "breed": "russian", "workers": 80, "min_spacing": 16,
            "cluster": 0.19, "label": "HARD - Russian Brood",
            "seed": 66, "tag": "hard_russian",
        },
        {
            "breed": "buckfast", "workers": 82, "min_spacing": 17,
            "cluster": 0.19, "label": "HARD - Buckfast Dense",
            "seed": 99, "tag": "hard_buckfast",
        },
        {
            "breed": "italian", "workers": 78, "min_spacing": 17,
            "cluster": 0.20, "label": "HARD - Italian Crowded",
            "seed": 111, "tag": "hard_italian",
        },
        # VERY HARD (4) -- packed frame, dark breeds, tight clusters
        {
            "breed": "russian", "workers": 105, "min_spacing": 12,
            "cluster": 0.17, "label": "VERY HARD - Russian Packed",
            "seed": 77, "tag": "vhard_russian",
        },
        {
            "breed": "caucasian", "workers": 100, "min_spacing": 13,
            "cluster": 0.18, "label": "VERY HARD - Caucasian Packed",
            "seed": 88, "tag": "vhard_caucasian",
        },
        {
            "breed": "carniolan", "workers": 110, "min_spacing": 11,
            "cluster": 0.16, "label": "VERY HARD - Carniolan Swarm",
            "seed": 122, "tag": "vhard_carniolan",
        },
        {
            "breed": "russian", "workers": 115, "min_spacing": 10,
            "cluster": 0.15, "label": "VERY HARD - Russian Overflow",
            "seed": 133, "tag": "vhard_russian2",
        },
    ]

    for sim in sims:
        print(f"Generating: {sim['label']}...")
        bg = generate_honeycomb_bg(frame_w, frame_h, "brood")

        frame_img, queen_pos = place_bees_on_frame(
            bg, sim["breed"], sim["workers"], sim["min_spacing"],
            sim["cluster"], include_queen=True, seed=sim["seed"]
        )
        frame_img = add_frame_border(frame_img)
        frame_img = add_difficulty_label(frame_img, sim["label"])

        # Challenge (no marker) -- optimize PNG compression
        path = out_dir / f"sim_{sim['tag']}_challenge.png"
        frame_img.save(str(path), optimize=True)
        print(f"  Challenge: {path.name}")

        # Answer key
        reveal = add_queen_reveal(frame_img, queen_pos)
        rpath = out_dir / f"sim_{sim['tag']}_answer.png"
        reveal.save(str(rpath), optimize=True)
        print(f"  Answer:    {rpath.name} (queen at {queen_pos})")

    print(f"\nDone! {len(sims)} simulations generated at 3 difficulty tiers.")


if __name__ == "__main__":
    main()
