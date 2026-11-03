"""Monta as Ruinas Arcanas v2 a partir de assets/maps/ruinas_v2/sheets (atlas.json).

Uso: py tools/ruins_v2/generate_ruins_v2.py

Grava (somente estes):
  assets/maps/ruinas_v2/tiles/*.png, props/*.png      recortes das pranchas
  assets/maps/ruinas_v2/chunks/ruinas_v2_chunk_XX_YY.png  chao 9x9 (agua transparente)
  assets/maps/ruinas_v2/ruinas_v2_walkable.png         mascara andavel (1 px = 16 mundo)
  assets/maps/ruinas_v2/ruinas_v2_minimap.png
  data/ruins_kit.json                                  props, colisoes, lago, mascara
  tools/ruins_v2/out/*                                 previews e map_patch.json
Escala: a arte ja vem em 1:1 com o personagem (coluna quebrada = 100 px = uma pessoa).
"""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "assets/maps/ruinas_v2"
SHEETS = KIT / "sheets"
TILES, PROPS, CHUNKS = KIT / "tiles", KIT / "props", KIT / "chunks"
OUT = Path(__file__).resolve().parent / "out"
DATA_PATH = ROOT / "data/ruins_kit.json"
RES = "res://assets/maps/ruinas_v2"

WORLD = (7200, 5760)
GS = 2  # chao na metade da resolucao
GROUND = (WORLD[0] // GS, WORLD[1] // GS)
CHUNK_GRID = (9, 9)
CHUNK_PX = (GROUND[0] // CHUNK_GRID[0], GROUND[1] // CHUNK_GRID[1])
MASK_CELL = 16
BORDER = 260
rng = random.Random(20261029)

# ---------------------------------------------------------------- layout (mundo)
CAMP = dict(c=(3600, 5050), r=(760, 430))
PORTAL = (3600, 5300)
SPAWN = (3600, 4980)
PLAZA = (2900, 2380, 4300, 3420)  # x0, y0, x1, y1
LIBRARY = (620, 2150, 1960, 3650)
CRYSTAL = dict(c=(5900, 3000), r=(880, 1050))
POND = dict(c=(1750, 1150), r=(720, 440))
POND_SHORE = dict(c=(1750, 1150), r=(900, 600))
SANCTUARY = dict(c=(3600, 1080), r=(960, 620))
SEAL = (3600, 1120)
ROADS = [  # (pontos, meia largura)
    ([(3600, 4720), (3600, 3420)], 150),
    ([(2900, 2900), (1960, 2900)], 125),
    ([(4300, 2900), (5050, 2900)], 125),
    ([(3600, 2380), (3600, 1640)], 140),
    ([(2950, 2420), (2200, 1550)], 105),
    ([(3600, 4250), (2200, 4500), (1500, 4300)], 95),
    ([(3600, 4250), (5000, 4550), (5600, 4150)], 95),
]
GLADES = [dict(c=(1500, 4300), r=(420, 300)), dict(c=(5600, 4150), r=(400, 320))]


# ---------------------------------------------------------------- recortes
def slice_sheets() -> dict[str, dict]:
    atlas = json.loads((SHEETS / "atlas.json").read_text(encoding="utf-8"))
    TILES.mkdir(parents=True, exist_ok=True)
    PROPS.mkdir(parents=True, exist_ok=True)
    terrain = atlas["terrain"]
    sheet = Image.open(SHEETS / terrain["file"]).convert("RGBA")
    cw, ch = terrain["cell_size"]
    for i, name in enumerate(terrain["names"]):
        r, c = divmod(i, terrain["grid"][0])
        sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)).save(TILES / f"{name}.png")
    info = {}
    for at in atlas["atlases"]:
        im = Image.open(SHEETS / at["file"]).convert("RGBA")
        for s in at["sprites"]:
            x, y, w, h = s["frame"]
            px, py = s["pivot"]
            im.crop((x, y, x + w, y + h)).save(PROPS / f"{s['name']}.png")
            info[s["name"]] = {"size": (w, h), "pivot": (px - x, py - y)}
    seal = atlas["seal"]
    sim = Image.open(SHEETS / seal["file"]).convert("RGBA")
    sw, sh = seal["cell_size"]
    for i in range(4):
        r, c = divmod(i, 2)
        sim.crop((c * sw, r * sh, (c + 1) * sw, (r + 1) * sh)).save(PROPS / f"seal_{i}.png")
    info["seal"] = {"size": (sw, sh), "pivot": (sw / 2, sh / 2)}
    return info


# ---------------------------------------------------------------- geometria
GY, GX = np.mgrid[0:GROUND[1], 0:GROUND[0]].astype(np.float32)
WX, WY = GX * GS, GY * GS


def value_noise(shape, cell, seed):
    g = np.random.default_rng(seed)
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    img = Image.fromarray((g.random((gh, gw)) * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, np.float32)[:shape[0], :shape[1]] / 255.0


def fbm(shape, cell, seed, octaves=3):
    total, amp, norm = np.zeros(shape, np.float32), 1.0, 0.0
    for o in range(octaves):
        total += value_noise(shape, max(2, cell >> o), seed + o * 7) * amp
        norm += amp
        amp *= 0.5
    return total / norm


N_EDGE = fbm(GROUND[::-1], 40, 5)
N_BIG = fbm(GROUND[::-1], 96, 9)
N_FINE = np.random.default_rng(3).random(GROUND[::-1]).astype(np.float32)


def ell(e, X=WX, Y=WY):
    return np.hypot((X - e["c"][0]) / e["r"][0], (Y - e["c"][1]) / e["r"][1]) - 1.0


def rect_sd(r, X=WX, Y=WY):
    x0, y0, x1, y1 = r
    dx = np.maximum(x0 - X, X - x1)
    dy = np.maximum(y0 - Y, Y - y1)
    return np.hypot(np.maximum(dx, 0), np.maximum(dy, 0)) + np.minimum(np.maximum(dx, dy), 0)


def seg_sd(pts, hw, X=WX, Y=WY):
    best = np.full(X.shape, 1e9, np.float32)
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        vx, vy = bx - ax, by - ay
        t = np.clip(((X - ax) * vx + (Y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
        best = np.minimum(best, np.hypot(X - (ax + t * vx), Y - (ay + t * vy)))
    return best - hw


def walk_sd(X=WX, Y=WY, noise=None):
    """< 0 = andavel (mesma geometria no chao e na mascara)."""
    n = 0 if noise is None else (noise - 0.5) * 70
    parts = [ell(CAMP, X, Y) * 400, rect_sd(PLAZA, X, Y) - 30, rect_sd(LIBRARY, X, Y) - 40,
             ell(CRYSTAL, X, Y) * 700, ell(POND_SHORE, X, Y) * 500, ell(SANCTUARY, X, Y) * 600]
    parts += [ell(g, X, Y) * 300 for g in GLADES]
    parts += [seg_sd(p, hw, X, Y) for p, hw in ROADS]
    sd = np.minimum.reduce(parts) + n
    water = ell(POND, X, Y) * 500 + n * 0.6 < 0
    border = (X < BORDER) | (Y < BORDER) | (X > WORLD[0] - BORDER) | (Y > WORLD[1] - BORDER)
    return np.where(water | border, 1e3, sd), water


# ---------------------------------------------------------------- pintura
def tiled(name):
    t = np.array(Image.open(TILES / f"{name}.png").convert("RGB").resize((128, 128), Image.LANCZOS), np.float32)
    reps = (math.ceil(GROUND[1] / 128), math.ceil(GROUND[0] / 128), 1)
    return np.tile(t, reps)[:GROUND[1], :GROUND[0]]


def paint():
    sd, water = walk_sd(noise=N_EDGE)
    img = np.where((N_BIG > 0.55)[..., None], tiled("dead_grass"), tiled("twilight_grass"))
    flowers = (N_BIG < 0.3) | ((ell(POND_SHORE) < 0.15) & (N_EDGE > 0.45))
    img = np.where(flowers[..., None], tiled("night_flower_grass"), img)

    def put(mask, tex, rim=0.6):
        nonlocal img
        img = np.where(mask[..., None], tex, img)
        if rim:
            inner = mask & np.roll(mask, 2, 0) & np.roll(mask, -2, 0) & np.roll(mask, 2, 1) & np.roll(mask, -2, 1)
            img = np.where((mask & ~inner)[..., None], img * rim, img)

    wob = (N_EDGE - 0.5) * 40
    camp = ell(CAMP) * 400 + wob < -60
    put(camp & (N_BIG > 0.45), tiled("rubble_dirt"), 0)
    for pts, hw in ROADS:
        put(seg_sd(pts, hw * 0.78) + wob * 0.5 < 0, tiled("broken_paving"))
    plaza = rect_sd(PLAZA) + wob * 0.4 < -20
    put(plaza, np.where((N_BIG > 0.5)[..., None], tiled("mossy_cracked_slabs"), tiled("stone_slabs")))
    put(rect_sd(LIBRARY) < -60, tiled("library_planks"))
    crystal = ell(CRYSTAL) * 700 + wob < -40
    put(crystal, tiled("violet_cracked_earth"), 0.7)
    put(crystal & (ell(dict(c=CRYSTAL["c"], r=(380, 420))) < 0), tiled("cyan_rune_slabs"))
    sanct = ell(SANCTUARY) * 600 + wob * 0.3 < -30
    put(sanct, tiled("stone_slabs"))
    put(ell(dict(c=SANCTUARY["c"], r=(SANCTUARY["r"][0] - 140, SANCTUARY["r"][1] - 110))) < 0, tiled("violet_gold_mosaic"), 0.5)
    shore = (ell(POND) * 500 + (N_EDGE - 0.5) * 42 < 70) & ~water
    put(shore, tiled("wet_stone"), 0)
    img = np.where(((ell(POND) * 500 + (N_EDGE - 0.5) * 42 > -6) & ~water & shore & (ell(POND) * 500 + (N_EDGE - 0.5) * 42 < 10))[..., None], img * 0.5, img)
    # fora da area andavel: mais escuro (mata morta)
    dark = np.clip(sd / 160, 0, 1)[..., None]
    img = img * (1 - dark * 0.38)
    img = img * (0.94 + N_FINE[..., None] * 0.06)
    alpha = np.where(water, 0, 255).astype(np.uint8)
    return np.dstack([np.clip(img, 0, 255).astype(np.uint8), alpha]), water


def mask_grid():
    mx, my = WORLD[0] // MASK_CELL, WORLD[1] // MASK_CELL
    yy, xx = np.mgrid[0:my, 0:mx].astype(np.float32)
    X, Y = xx * MASK_CELL + MASK_CELL / 2, yy * MASK_CELL + MASK_CELL / 2
    noise = N_EDGE[np.clip((Y / GS).astype(int), 0, GROUND[1] - 1), np.clip((X / GS).astype(int), 0, GROUND[0] - 1)]
    sd, _ = walk_sd(X, Y, noise)
    return sd < 0


# ---------------------------------------------------------------- props
INFO: dict = {}
FOOT = {  # colisao no pe: (fracao da largura, altura em px de mundo)
    "intact_column": (0.7, 30), "broken_column": (0.75, 26), "fallen_column": (0.85, 34),
    "headless_mage_statue": (0.8, 40), "cyan_obelisk": (0.7, 44), "bookshelf": (0.9, 36),
    "books_scrolls": (0.7, 26), "lectern": (0.6, 24), "dry_fountain": (0.85, 70), "dead_tree": (0.2, 28),
    "small_dead_tree": (0.24, 20), "floating_crystal_pedestal": (0.6, 30), "broken_astrolabe": (0.6, 36),
    "small_rubble": (0.6, 16), "mossy_boulder": (0.86, 60), "torn_tent": (0.8, 56), "cold_campfire": (0.7, 26),
    "supply_crates": (0.85, 40), "night_flower_bush": (0.6, 24), "violet_brazier": (0.55, 28),
    "violet_obelisk_a": (0.7, 44), "violet_obelisk_b": (0.7, 44), "broken_throne": (0.85, 90),
    "tall_violet_brazier": (0.55, 30), "floating_three_crystals": (0.6, 30), "gold_rune_portal": (1.0, 40),
    "kneeling_mage_statue": (0.8, 40), "gold_trimmed_debris": (0.7, 24), "collapsed_wall": (0.9, 36),
    "broken_archway": (1.0, 40), "wall_horizontal": (1.0, 44), "wall_horizontal_rune": (1.0, 44),
    "corner_upper_left": (1.0, 44), "corner_upper_right": (1.0, 44), "corner_lower_left": (1.0, 44),
    "corner_lower_right": (1.0, 44),
}
SOLID_EXTRA = []  # retangulos de colisao extras (paredes verticais, pilares de arco)
ANIM = {"seal": [f"seal_{i}" for i in range(4)]}


def prop(name, x, y, scale=1.0, collide=True, flip=False, ground=False):
    w, h = INFO[name]["size"]
    px, py = INFO[name]["pivot"]
    entry = {"name": name, "texture": f"{RES}/props/{ANIM.get(name, [name])[0]}.png", "pos": [round(x, 1), round(y, 1)],
             "offset": [-(w - px) if flip else -px, -py], "scale": scale, "flip_h": flip}
    if name in ANIM:
        entry["frames"] = [f"{RES}/props/{f}.png" for f in ANIM[name]]
        entry["fps"] = 1000 / 180
    if ground:
        entry["layer"] = "ground"
    if collide and name in FOOT:
        fw, fh = FOOT[name]
        hw = w * scale * fw / 2
        entry["collisions"] = [[-hw, -fh, hw * 2, fh]]
    return entry


def place() -> list[dict]:
    props = []
    add = lambda *a, **k: props.append(prop(*a, **k))  # noqa: E731
    # acampamento da entrada
    add("torn_tent", 3270, 4930); add("torn_tent", 3950, 4900, flip=True)
    add("cold_campfire", 3600, 5080); add("supply_crates", 3330, 5150); add("supply_crates", 3880, 5160, flip=True)
    add("violet_brazier", 3420, 5320); add("violet_brazier", 3780, 5320)
    add("books_scrolls", 3740, 5020)
    # praca central: fonte seca, colunas, estatuas
    cx, cy = (PLAZA[0] + PLAZA[2]) / 2, (PLAZA[1] + PLAZA[3]) / 2
    add("dry_fountain", cx, cy + 80)
    for i, (dx, dy) in enumerate([(-600, -440), (-200, -460), (200, -460), (600, -440), (-640, 0), (640, 0), (-600, 450), (600, 450)]):
        add("intact_column" if i % 3 else "broken_column", cx + dx, cy + dy)
    add("fallen_column", cx - 430, cy + 330); add("small_rubble", cx + 300, cy - 280)
    add("headless_mage_statue", cx - 330, cy - 20); add("headless_mage_statue", cx + 330, cy - 20, flip=True)
    add("collapsed_wall", PLAZA[0] + 120, PLAZA[1] + 90); add("collapsed_wall", PLAZA[2] - 140, PLAZA[3] - 70)
    # arco e escada para o santuario
    add("broken_archway", 3600, 2330)
    add("staircase", 3600, 1760, collide=False, ground=True)
    # biblioteca em ruinas (oeste): paredes, estantes, atris
    lx0, ly0, lx1, ly1 = LIBRARY
    add("corner_upper_left", lx0 + 80, ly0 + 200); add("corner_upper_right", lx1 - 88, ly0 + 200)
    add("corner_lower_left", lx0 + 88, ly1); add("corner_lower_right", lx1 - 82, ly1)
    for x in range(lx0 + 260, lx1 - 200, 190):
        add("wall_horizontal_rune" if (x // 190) % 3 == 0 else "wall_horizontal", x, ly0 + 200)
        if abs(x - (lx0 + lx1) / 2) > 200:
            add("wall_horizontal", x, ly1)
    for y in range(ly0 + 400, ly1 - 200, 190):
        for wx in (lx0 + 27, lx1 - 27):
            if wx > lx0 + 100 and abs(y - 2900) < 220:
                continue  # porta leste
            add("wall_vertical_ivy" if (y // 190) % 2 else "wall_vertical", wx, y, collide=False)
            SOLID_EXTRA.append([wx - 27, y - 150, 54, 150])
    for row, y in enumerate((2560, 2900, 3250)):
        for x in (900, 1150, 1400, 1650):
            if row == 1 and x > 1500:
                continue
            add("bookshelf", x, y)
    add("lectern", 1270, 2730); add("lectern", 1270, 3080); add("books_scrolls", 980, 3420)
    add("books_scrolls", 1700, 2420); add("collapsed_wall", 1500, 3460)
    # campo de cristais (leste)
    ccx, ccy = CRYSTAL["c"]
    add("broken_astrolabe", ccx, ccy + 40)
    for ang in range(0, 360, 45):
        a = math.radians(ang + 22)
        add("cyan_obelisk" if ang % 90 else "floating_crystal_pedestal", ccx + math.cos(a) * 560, ccy + math.sin(a) * 640)
    for ang in (30, 150, 210, 330):
        a = math.radians(ang)
        add("floating_three_crystals", ccx + math.cos(a) * 300, ccy + math.sin(a) * 330)
    # lago magico (noroeste)
    for ang in range(0, 360, 26):
        a = math.radians(ang + rng.uniform(-6, 6))
        x = POND["c"][0] + math.cos(a) * POND["r"][0] * 1.06
        y = POND["c"][1] + math.sin(a) * POND["r"][1] * 1.08
        add(rng.choice(["night_flower_bush", "small_rubble", "mossy_boulder", "night_flower_bush"]), x, y, collide=False)
    add("dead_tree", 1050, 820, collide=False); add("dead_tree", 2480, 1380, collide=False, flip=True)
    # santuario do Arquimago (norte)
    scx, scy = SANCTUARY["c"]
    add("seal", SEAL[0], SEAL[1], scale=1.5, collide=False, ground=True)
    add("broken_throne", scx, scy - 430)
    add("gold_rune_portal", scx - 360, scy - 400); add("gold_rune_portal", scx + 360, scy - 400)
    for i, ang in enumerate(range(200, 341, 28)):
        a = math.radians(ang)
        add("violet_obelisk_a" if i % 2 else "violet_obelisk_b", scx + math.cos(a) * 760, scy + math.sin(a) * 470 + 40)
    for ang in (20, 160):
        a = math.radians(ang)
        add("tall_violet_brazier", scx + math.cos(a) * 700, scy + math.sin(a) * 430)
    for ang in (55, 125):
        a = math.radians(ang)
        add("tall_violet_brazier", scx + math.cos(a) * 520, scy + math.sin(a) * 470)
    add("kneeling_mage_statue", scx - 520, scy - 120); add("kneeling_mage_statue", scx + 520, scy - 120, flip=True)
    add("gold_trimmed_debris", scx - 640, scy + 260); add("gold_trimmed_debris", scx + 610, scy + 300)
    # clareiras do sul
    for g in GLADES:
        add("dead_tree", g["c"][0] - 180, g["c"][1] - 120, collide=True)
        side = -1 if g["c"][0] < 3600 else 1  # longe da trilha, que chega pelo lado do centro
        add("mossy_boulder", g["c"][0] + 230 * side, g["c"][1] + 140)
        add("night_flower_bush", g["c"][0] - 40, g["c"][1] + 160, collide=False)
    return props


def wild_fill(mask, props):
    """Mata morta fora da area andavel (sem colisao: a mascara ja bloqueia)."""
    taken = [(p["pos"][0], p["pos"][1]) for p in props]
    step = 150
    for gy in range(BORDER // 2, WORLD[1], step):
        for gx in range(BORDER // 2, WORLD[0], step):
            x = gx + rng.uniform(-50, 50) + (step / 2 if (gy // step) % 2 else 0)
            y = gy + rng.uniform(-40, 40)
            cxm, cym = int(x / MASK_CELL), int(y / MASK_CELL)
            if not (0 <= cxm < mask.shape[1] and 0 <= cym < mask.shape[0]):
                continue
            near = mask[max(0, cym - 5):cym + 6, max(0, cxm - 5):cxm + 6]
            if near.any():
                continue
            if ell(POND, np.array(x), np.array(y)) < 0.25:
                continue
            roll = rng.random()
            name = "dead_tree" if roll < 0.58 else "small_dead_tree" if roll < 0.82 else "mossy_boulder" if roll < 0.88 else "night_flower_bush"
            props.append(prop(name, x, y, scale=rng.uniform(1.0, 1.35) if name == "dead_tree" else 1.0, collide=False, flip=rng.random() < 0.5))
    # detalhes dentro da area andavel
    placed = 0
    while placed < 70:
        x, y = rng.uniform(BORDER, WORLD[0] - BORDER), rng.uniform(BORDER, WORLD[1] - BORDER)
        cxm, cym = int(x / MASK_CELL), int(y / MASK_CELL)
        if not mask[max(0, cym - 6):cym + 7, max(0, cxm - 6):cxm + 7].all():
            continue
        if any(math.hypot(x - tx, y - ty) < 180 for tx, ty in taken):
            continue
        if math.hypot(x - SEAL[0], y - SEAL[1]) < 520 or math.hypot(x - PORTAL[0], y - PORTAL[1]) < 300:
            continue
        if min(float(seg_sd(p, hw, np.array(x), np.array(y))) for p, hw in ROADS) < 40:
            continue
        name = rng.choice(["small_rubble", "small_rubble", "small_dead_tree", "night_flower_bush", "gold_trimmed_debris", "mossy_boulder"])
        props.append(prop(name, x, y, collide=name in ("small_dead_tree", "mossy_boulder")))
        taken.append((x, y))
        placed += 1


SPAWNS = [  # (inimigo, centro, quantidade, respawn base)
    ("Espirito Fraco", (2380, 1500), 2, 12), ("Espirito Fraco", (1250, 1550), 2, 12), ("Espirito Fraco", (1300, 700), 2, 12),
    ("Espirito Fraco", (1500, 4300), 2, 12), ("Espirito Fraco", (5600, 4150), 2, 12),
    ("Aprendiz Corrompido", (1000, 2700), 2, 16), ("Aprendiz Corrompido", (1500, 3100), 2, 16), ("Aprendiz Corrompido", (1600, 2450), 1, 16),
    ("Espectro Arcano", (5500, 2600), 2, 18), ("Espectro Arcano", (6300, 3300), 2, 18), ("Espectro Arcano", (5900, 3700), 1, 18),
    ("Sentinela Arcano", (3300, 1550), 1, 22), ("Sentinela Arcano", (3900, 1550), 1, 22),
    ("Arquimago Corrompido", SEAL, 1, 300),
]


def render(ground, props, solids, mask, q=4, debug=False):
    water = Image.open(TILES / "magic_water_0.png").convert("RGBA").resize((256 // q, 256 // q))
    full = Image.new("RGBA", (WORLD[0] // q, WORLD[1] // q))
    for y in range(0, full.height, water.height):
        for x in range(0, full.width, water.width):
            full.paste(water, (x, y))
    full.alpha_composite(Image.fromarray(ground, "RGBA").resize(full.size, Image.LANCZOS))
    cache = {}
    for p in sorted(props, key=lambda p: (p.get("layer") != "ground", p["pos"][1])):
        path = ROOT / p["texture"].replace("res://", "")
        im = cache.setdefault(path, Image.open(path).convert("RGBA"))
        if p["flip_h"]:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        sc = p["scale"] / q
        w, h = max(1, round(im.width * sc)), max(1, round(im.height * sc))
        x, y = round(p["pos"][0] / q + p["offset"][0] * sc), round(p["pos"][1] / q + p["offset"][1] * sc)
        full.alpha_composite(im.resize((w, h), Image.LANCZOS), (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
    if debug:
        dr = ImageDraw.Draw(full)
        red = Image.fromarray(np.where(mask[..., None], 0, np.array([255, 0, 0, 60], np.uint8)).astype(np.uint8), "RGBA").resize(full.size)
        full.alpha_composite(red)
        for r in solids:
            dr.rectangle([r[0] / q, r[1] / q, (r[0] + r[2]) / q, (r[1] + r[3]) / q], outline=(255, 255, 0, 255))
        for p in props:
            for c in p.get("collisions", []):
                x0, y0 = p["pos"][0] + c[0], p["pos"][1] + c[1]
                dr.rectangle([x0 / q, y0 / q, (x0 + c[2]) / q, (y0 + c[3]) / q], outline=(255, 255, 0, 255))
        for name, c, *_ in SPAWNS:
            dr.ellipse([c[0] / q - 8, c[1] / q - 8, c[0] / q + 8, c[1] / q + 8], fill=(255, 60, 255, 255))
        for c in (SPAWN, PORTAL):
            dr.ellipse([c[0] / q - 8, c[1] / q - 8, c[0] / q + 8, c[1] / q + 8], fill=(0, 255, 255, 255))
    return full


def main():
    global INFO
    INFO = slice_sheets()
    CHUNKS.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    ground, water = paint()
    for gy in range(CHUNK_GRID[1]):
        for gx in range(CHUNK_GRID[0]):
            part = ground[gy * CHUNK_PX[1]:(gy + 1) * CHUNK_PX[1], gx * CHUNK_PX[0]:(gx + 1) * CHUNK_PX[0]]
            Image.fromarray(part, "RGBA").save(CHUNKS / f"ruinas_v2_chunk_{gx:02d}_{gy:02d}.png", optimize=True)
    mask = mask_grid()
    Image.fromarray((mask * 255).astype(np.uint8), "L").save(KIT / "ruinas_v2_walkable.png")
    props = place()
    wild_fill(mask, props)
    solids = [[round(v, 1) for v in r] for r in SOLID_EXTRA]
    # pilares do arco quebrado (o vao do meio fica livre)
    ax, ay = 3600, 2330
    solids += [[ax - 92, ay - 40, 44, 40], [ax + 48, ay - 40, 44, 40]]
    for p in props:
        if p["name"] == "broken_archway":
            p.pop("collisions", None)
    py_, px_ = np.nonzero(water)
    lake_rect = [int(px_.min()) * GS - 64, int(py_.min()) * GS - 64, int(px_.max() - px_.min()) * GS + 128, int(py_.max() - py_.min()) * GS + 128]
    data = {
        "version": 1,
        "world_size": list(WORLD),
        "ground_scale": GS,
        "chunk_grid": list(CHUNK_GRID),
        "chunk_px": list(CHUNK_PX),
        "chunks_dir": f"{RES}/chunks",
        "chunk_prefix": "ruinas_v2_chunk",
        "walkable_mask": {"path": f"{RES}/ruinas_v2_walkable.png", "cell": MASK_CELL},
        "lake": {"rect": lake_rect, "water_frames": [f"{RES}/tiles/magic_water_{i}.png" for i in range(4)]},
        "minimap": f"{RES}/ruinas_v2_minimap.png",
        "solids": solids,
        "props": props,
    }
    DATA_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    view = render(ground, props, solids, mask)
    view.save(OUT / "preview.png")
    view.resize((1800, 1440), Image.LANCZOS).save(KIT / "ruinas_v2_minimap.png")
    render(ground, props, solids, mask, debug=True).save(OUT / "preview_colisao.png")
    spawns = [{"enemy": e, "count": n, "respawn": r, "zone": [c[0] - 90, c[1] - 70, 180, 140], **({"boss": True} if e == "Arquimago Corrompido" else {})} for e, c, n, r in SPAWNS]
    patch = {"size": list(WORLD), "spawn": list(SPAWN), "portal": list(PORTAL), "spawns": spawns,
             "safe_zones": [{"pos": list(CAMP["c"]), "radius": 520}]}
    (OUT / "map_patch.json").write_text(json.dumps(patch, ensure_ascii=False, indent=1), encoding="utf-8")
    blocked = [(s["enemy"], s["zone"][:2]) for s in spawns if not mask[int((s["zone"][1] + 70) / MASK_CELL), int((s["zone"][0] + 90) / MASK_CELL)]]
    print(f"props={len(props)} andavel={mask.mean():.1%} spawns bloqueados={blocked}")


if __name__ == "__main__":
    main()
