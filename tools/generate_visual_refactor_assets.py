from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math
import random


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"


def rgba(hex_color, alpha=255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def save(img, name):
    SPRITES.mkdir(parents=True, exist_ok=True)
    img.save(SPRITES / name)


def pixel_noise_tile(base, accents, name, seed):
    random.seed(seed)
    img = Image.new("RGBA", (32, 32), rgba(base))
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = random.randrange(32), random.randrange(32)
        c = rgba(random.choice(accents), random.randrange(38, 92))
        d.rectangle((x, y, x + random.randrange(1, 3), y + random.randrange(1, 3)), fill=c)
    for _ in range(6):
        x, y = random.randrange(0, 30), random.randrange(0, 30)
        d.point((x, y), fill=rgba("#ffffff", 28))
    save(img, name)


def make_tiles():
    palettes = {
        "tile_grass_01.png": ("#4f8a42", ["#6ba955", "#3f7437", "#7bbf67", "#2f5d2e"]),
        "tile_grass_02.png": ("#477f3f", ["#5f9d50", "#396e37", "#75b95c", "#2d542b"]),
        "tile_grass_03.png": ("#538f48", ["#6daa5c", "#3e743b", "#83be67", "#315e30"]),
        "tile_grass_04.png": ("#4a8540", ["#6aa45a", "#3c7035", "#7ab85f", "#2d572c"]),
        "tile_path_01.png": ("#9a7b4d", ["#b08d59", "#7b5e3c", "#c0a06a", "#6f5234"]),
        "tile_path_02.png": ("#8f7148", ["#ad8c5b", "#765938", "#bd9a65", "#6a5033"]),
        "tile_path_03.png": ("#a27f4c", ["#c19a5d", "#7b5e3a", "#d0aa70", "#705439"]),
        "tile_stone_01.png": ("#5d6470", ["#76808e", "#454b55", "#8b94a2", "#343a43"]),
        "tile_stone_02.png": ("#555e69", ["#6d7682", "#404852", "#8d95a1", "#303640"]),
        "tile_ruin_01.png": ("#4b4d66", ["#636685", "#383a50", "#7e819d", "#2f3144"]),
        "tile_ruin_02.png": ("#41445c", ["#5f6281", "#33354b", "#747896", "#292b3d"]),
        "tile_cave_floor_01.png": ("#3a3540", ["#514b58", "#282530", "#5d5664", "#211f28"]),
        "tile_cave_floor_02.png": ("#332f3a", ["#4a4552", "#25222b", "#5b5362", "#1f1d25"]),
        "tile_cave.png": ("#24232b", ["#34333d", "#191922", "#42404a", "#101017"]),
        "tile_arcane_01.png": ("#32304c", ["#4a4771", "#25243b", "#635fa0", "#17172b"]),
        "tile_arcane_02.png": ("#2d2b45", ["#47456d", "#222137", "#5a5693", "#17162b"]),
        "tile_sand_01.png": ("#c7b783", ["#dcc994", "#a89765", "#efe0aa", "#927f55"]),
    }
    for i, (name, (base, accents)) in enumerate(palettes.items()):
        pixel_noise_tile(base, accents, name, 4400 + i)


def shadow(w, h, alpha=80):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((4, h * 0.45, w - 4, h - 4), fill=(0, 0, 0, alpha))
    return img.filter(ImageFilter.GaussianBlur(4))


def make_fountain():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    img.alpha_composite(shadow(128, 128, 70), (0, 8))
    d = ImageDraw.Draw(img)
    d.ellipse((18, 44, 110, 114), fill=rgba("#3d4350"), outline=rgba("#8b91a2"), width=4)
    d.ellipse((27, 50, 101, 104), fill=rgba("#2e6d91"), outline=rgba("#b6bfd0"), width=3)
    for y in range(55, 98, 8):
        d.arc((31, y - 16, 99, y + 18), 10, 170, fill=rgba("#55c5f0", 160), width=2)
    d.rectangle((56, 24, 72, 67), fill=rgba("#5b6272"), outline=rgba("#aab0bf"))
    d.ellipse((49, 18, 79, 38), fill=rgba("#8291a7"), outline=rgba("#d4d8e0"), width=2)
    d.line((64, 15, 64, 50), fill=rgba("#78d8ff"), width=2)
    d.line((55, 31, 43, 52), fill=rgba("#78d8ff", 190), width=2)
    d.line((73, 31, 85, 52), fill=rgba("#78d8ff", 190), width=2)
    save(img, "decor_fountain.png")


def make_tree(name, dark=False):
    img = Image.new("RGBA", (96, 112), (0, 0, 0, 0))
    img.alpha_composite(shadow(96, 112, 65), (0, 4))
    d = ImageDraw.Draw(img)
    d.rectangle((42, 62, 55, 96), fill=rgba("#6b3f22"), outline=rgba("#3b2418"))
    colors = ["#2f6f37", "#3f8742", "#5ca85a", "#244f2c"] if not dark else ["#21485a", "#2c5b69", "#3e7182", "#172f3c"]
    blobs = [(16, 24, 58, 66), (34, 12, 84, 62), (8, 44, 54, 84), (38, 42, 90, 88), (20, 0, 70, 50)]
    for idx, box in enumerate(blobs):
        d.ellipse(box, fill=rgba(colors[idx % len(colors)]), outline=rgba("#17261c" if not dark else "#101f29"))
    for _ in range(45):
        x, y = random.randrange(14, 82), random.randrange(10, 82)
        d.point((x, y), fill=rgba("#9dd37b" if not dark else "#7bc0d6", 90))
    save(img, name)


def make_object_assets():
    make_fountain()
    make_tree("decor_tree.png", False)
    make_tree("decor_tree_dark.png", True)
    crate = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(crate)
    d.rectangle((3, 4, 29, 29), fill=rgba("#8a5a2e"), outline=rgba("#3c2415"), width=2)
    d.line((5, 6, 27, 27), fill=rgba("#3f2616"), width=2)
    d.line((27, 6, 5, 27), fill=rgba("#3f2616"), width=2)
    d.rectangle((7, 8, 25, 25), outline=rgba("#c48b48"), width=1)
    save(crate, "decor_crate.png")
    barrel = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(barrel)
    d.ellipse((6, 3, 26, 10), fill=rgba("#a26a37"), outline=rgba("#3e2514"))
    d.rectangle((6, 7, 26, 26), fill=rgba("#8b5629"), outline=rgba("#3e2514"), width=2)
    d.ellipse((6, 20, 26, 30), fill=rgba("#6e421f"), outline=rgba("#3e2514"))
    d.line((8, 13, 24, 13), fill=rgba("#cfa16a"), width=2)
    d.line((8, 22, 24, 22), fill=rgba("#cfa16a"), width=2)
    save(barrel, "decor_barrel.png")


def radial_glow(size, colors, name):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pix = img.load()
    c0, c1, c2 = [rgba(c) for c in colors]
    center = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x - center, y - center
            dist = math.sqrt(dx * dx + dy * dy) / center
            if dist > 0.96:
                continue
            if dist < 0.32:
                c = c2
            elif dist < 0.66:
                c = c1
            else:
                c = c0
            alpha = int(255 * max(0, 1 - dist) ** 0.55)
            pix[x, y] = c[:3] + (alpha,)
    save(img, name)


def make_effect_assets():
    fire = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(fire)
    for box, col in [((4, 24, 54, 54), "#b92b17"), ((10, 18, 58, 46), "#ff751d"), ((18, 22, 48, 42), "#ffd45a"), ((25, 26, 40, 37), "#fff3ad")]:
        d.ellipse(box, fill=rgba(col, 225))
    d.polygon([(9, 31), (1, 27), (12, 23)], fill=rgba("#ff9c26", 180))
    d.polygon([(19, 21), (25, 5), (32, 24)], fill=rgba("#ff5b19", 210))
    fire = fire.filter(ImageFilter.GaussianBlur(0.45))
    save(fire, "effect_fireball_projectile.png")
    radial_glow(64, ["#102a77", "#20a8ff", "#e6fbff"], "effect_blue_meteor_projectile.png")
    radial_glow(64, ["#2e1e73", "#8d6dff", "#f4eaff"], "effect_arcane_projectile.png")
    arrow = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(arrow)
    d.line((8, 32, 48, 32), fill=rgba("#d6b16b"), width=4)
    d.polygon([(48, 21), (60, 32), (48, 43)], fill=rgba("#e5e9ef"), outline=rgba("#6f7781"))
    d.polygon([(10, 24), (2, 19), (8, 32), (2, 45), (10, 40)], fill=rgba("#3f8d55"))
    save(arrow, "effect_arrow_projectile.png")
    slash = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(slash)
    d.arc((6, 6, 58, 58), 205, 330, fill=rgba("#fff4c7"), width=7)
    d.arc((10, 10, 54, 54), 205, 330, fill=rgba("#d8edf8"), width=3)
    save(slash, "effect_slash_projectile.png")
    radial_glow(64, ["#822414", "#ff6a24", "#fff0a0"], "effect_impact_fire.png")
    radial_glow(64, ["#10256e", "#3aaeff", "#ecfbff"], "effect_impact_blue.png")
    radial_glow(64, ["#1f5832", "#65d97d", "#f1fff1"], "effect_impact_arrow.png")
    radial_glow(64, ["#7d6b34", "#fff0a1", "#ffffff"], "effect_impact_slash.png")


def icon_frame(symbol, bg, accent, name):
    img = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((3, 3, 53, 53), radius=8, fill=rgba(bg, 235), outline=rgba("#c99a2e"), width=2)
    d.rounded_rectangle((8, 8, 48, 48), radius=6, outline=rgba("#ffffff", 45), width=1)
    if symbol == "bag":
        d.rectangle((18, 23, 39, 42), fill=rgba(accent), outline=rgba("#241510"), width=2)
        d.arc((20, 12, 37, 30), 200, 340, fill=rgba("#f2d59b"), width=3)
        d.rectangle((15, 29, 42, 33), fill=rgba("#c75935"))
    elif symbol == "skills":
        d.line((16, 42, 42, 16), fill=rgba("#d7e8ff"), width=5)
        d.line((19, 17, 43, 41), fill=rgba("#d7e8ff"), width=5)
        d.line((16, 42, 42, 16), fill=rgba("#6a89b8"), width=2)
        d.line((19, 17, 43, 41), fill=rgba("#6a89b8"), width=2)
    elif symbol == "quest":
        d.rectangle((18, 13, 39, 43), fill=rgba("#ead9b5"), outline=rgba("#6d4b2d"), width=2)
        for y in [20, 26, 32]:
            d.line((22, y, 35, y), fill=rgba("#6d4b2d"), width=1)
        d.rectangle((16, 11, 41, 17), fill=rgba(accent))
    save(img, name)


def make_icons():
    icon_frame("bag", "#111821", "#c98b45", "icon_ui_bag_premium.png")
    icon_frame("skills", "#111821", "#8ec5ff", "icon_ui_skills_premium.png")
    icon_frame("quest", "#111821", "#ba7a32", "icon_ui_quests_premium.png")


def shifted_copy(src, dst, dx, dy):
    if not src.exists():
        return
    img = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (dx, dy))
    out.save(dst)


def extend_player_motion_frames():
    classes = ["guerreiro", "mago", "arqueiro"]
    dirs = ["front", "back", "side"]
    shifts = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    for cls in classes:
        for direction in dirs:
            base = SPRITES / f"player_{cls}_art_{direction}_walk_"
            for index, (dx, dy) in enumerate(shifts, start=9):
                source = SPRITES / f"player_{cls}_art_{direction}_walk_{((index - 1) % 8) + 1}.png"
                shifted_copy(source, SPRITES / f"player_{cls}_art_{direction}_walk_{index}.png", dx, dy)
        for index in range(3, 7):
            source = SPRITES / f"player_{cls}_art_attack_{1 if index % 2 else 2}.png"
            shifted_copy(source, SPRITES / f"player_{cls}_art_attack_{index}.png", 0, 0)


if __name__ == "__main__":
    make_tiles()
    make_object_assets()
    make_effect_assets()
    make_icons()
    extend_player_motion_frames()
