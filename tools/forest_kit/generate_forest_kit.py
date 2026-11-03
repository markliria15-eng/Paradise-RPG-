"""Gerador da Floresta dos Javalis v2.

Monta o mapa novo a partir dos sheets em assets/maps/floresta_v2/sheets/:
- chao pintado (grama, trilhas, clareiras, lago, arena do chefe) em chunks 10x10;
- arvores/pedras/arbustos como sprites separados (y-sort no Godot);
- colisao: mascara de area andavel + retangulos no pe das arvores e nas pedras;
- minimapa e previews de revisao.

Unidades:
- "D" (dados) = unidade de data/maps.json da floresta; mundo = D * 4.
- chao: 1 pixel = 2 px de mundo (D * 2).
- mascara: 1 celula = 16 px de mundo (D / 4).

Arquivos escritos (somente estes):
- assets/maps/floresta_v2/props/*.png
- assets/maps/floresta_v2/chunks/floresta_v2_chunk_XX_YY.png
- assets/maps/floresta_v2/floresta_v2_minimap.png
- assets/maps/floresta_v2/floresta_v2_walkable.png
- assets/maps/floresta_v2/floresta_v2_lake_overlay.png
- data/forest_kit.json
- tools/forest_kit/out/* (previews)
"""
from __future__ import annotations

import json
import math
import random
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "assets/maps/floresta_v2"
SHEETS = KIT / "sheets"
PROPS_DIR = KIT / "props"
CHUNKS_DIR = KIT / "chunks"
OUT = Path(__file__).resolve().parent / "out"
DATA_PATH = ROOT / "data/forest_kit.json"
# Pecas premium de Eldoria v2 usadas na arena do chefe (so leitura).
ELDORIA_PROPS = ROOT / "assets/maps/eldoria_v2/props"
ELDORIA_TILES = ROOT / "assets/maps/eldoria_v2/tiles"
TORCH_SCALE = 0.42   # tocha com ~230 px de mundo
STATUE_SCALE = 1.25  # estatua com ~300 px de mundo

MAP_D = (2000, 1600)
WORLD_PER_D = 4
GROUND_PER_D = 2
GROUND_SIZE = (MAP_D[0] * GROUND_PER_D, MAP_D[1] * GROUND_PER_D)
CHUNK_GRID = (10, 10)
CHUNK_PX = (GROUND_SIZE[0] // CHUNK_GRID[0], GROUND_SIZE[1] // CHUNK_GRID[1])
MASK_CELL_WORLD = 16
MASK_SIZE = (MAP_D[0] * WORLD_PER_D // MASK_CELL_WORLD, MAP_D[1] * WORLD_PER_D // MASK_CELL_WORLD)
PROP_SCALE = 2.0
BORDER_D = 70

rng = random.Random(20261028)
np_rng = np.random.default_rng(20261028)

# ---------------------------------------------------------------- layout (D)
ENTRY = (200, 190)
CAVE_PORTAL = (1815, 1185)
ARENA = {"c": (1640, 1265), "r": (235, 190)}
LAKE = {"c": (225, 1010), "r": (150, 108)}
WATERFALL_FOOT = (215, 912)

CLEARINGS = {
    "entry": {"c": ENTRY, "r": (105, 90)},
    "a_javalis": {"c": (560, 420), "r": (140, 105)},
    "glade_norte": {"c": (515, 150), "r": (85, 62)},
    "hub": {"c": (950, 620), "r": (170, 130)},
    "lago_margem": {"c": (360, 1000), "r": (120, 130)},
    "lago_bosque": {"c": (470, 1150), "r": (120, 95)},
    "d_aranhas": {"c": (820, 1060), "r": (130, 100)},
    "sul_fim": {"c": (650, 1390), "r": (95, 75)},
    "c_brutos": {"c": (1320, 290), "r": (130, 95)},
    "crista_fim": {"c": (1730, 230), "r": (110, 80)},
    "k_lobos": {"c": (1440, 590), "r": (95, 75)},
    "e_alfas": {"c": (1330, 920), "r": (140, 105)},
    "arena": ARENA,
}

GATE = (1490, 1075)
PATHS = [
    {"pts": [ENTRY, (330, 250), (470, 320), (560, 420)]},
    {"pts": [(470, 320), (500, 235), (515, 150)]},
    {"pts": [(560, 420), (700, 470), (830, 560), (950, 620)]},
    {"pts": [(560, 420), (520, 530), (470, 640), (380, 820), (395, 960), (470, 1150)]},
    {"pts": [(950, 620), (900, 820), (820, 1060), (740, 1220), (650, 1390)]},
    {"pts": [(950, 620), (1080, 470), (1200, 350), (1320, 290), (1500, 250), (1730, 230)]},
    {"pts": [(1320, 290), (1400, 440), (1440, 590), (1390, 770), (1330, 920)]},
    {"pts": [(950, 620), (1120, 780), (1330, 920), GATE, (1570, 1175)], "walk_hw": 44},
]
PATH_DIRT_HW = 22
PATH_WALK_HW = 50

# Grupos nas clareiras (respawn em segundos).
SPAWNS = [
    {"enemy": "Javali Selvagem", "count": 4, "respawn": 8, "zone": [480, 355, 170, 130]},
    {"enemy": "Lobo Cinzento", "count": 3, "respawn": 12, "zone": [860, 540, 180, 150]},
    {"enemy": "Javali Selvagem", "count": 3, "respawn": 9, "zone": [880, 640, 150, 90]},
    {"enemy": "Aranha Venenosa", "count": 3, "respawn": 14, "zone": [380, 1085, 170, 130]},
    {"enemy": "Aranha Venenosa", "count": 3, "respawn": 15, "zone": [740, 990, 165, 140]},
    {"enemy": "Javali Bruto", "count": 3, "respawn": 20, "zone": [590, 1330, 120, 110]},
    {"enemy": "Javali Bruto", "count": 3, "respawn": 19, "zone": [1235, 225, 175, 130]},
    {"enemy": "Lobo Alfa", "count": 3, "respawn": 26, "zone": [1640, 175, 170, 115]},
    {"enemy": "Lobo Cinzento", "count": 2, "respawn": 13, "zone": [1375, 535, 135, 110]},
    {"enemy": "Lobo Alfa", "count": 3, "respawn": 28, "zone": [1245, 850, 175, 135]},
    {"enemy": "Javali Bruto", "count": 2, "respawn": 22, "zone": [1260, 900, 140, 90]},
    {"enemy": "Rei Javali", "count": 1, "boss": True, "respawn": 180, "zone": [1590, 1230, 100, 70]},
]
# Mobs soltos pelas trilhas: o tipo depende da distancia ate a entrada.
PATH_MOB_TIERS = [
    (650, [("Javali Selvagem", 10), ("Lobo Cinzento", 13)]),
    (1150, [("Lobo Cinzento", 13), ("Aranha Venenosa", 15), ("Javali Selvagem", 10)]),
    (99999, [("Javali Bruto", 20), ("Lobo Alfa", 26), ("Aranha Venenosa", 15)]),
]
PATH_MOB_STEP = 150

COLLECTIBLES = [
    ("Erva Curativa", (300, 240)), ("Flor Medicinal", (480, 130)), ("Flor Medicinal", (560, 170)),
    ("Planta Rara", (520, 115)), ("Erva Curativa", (640, 470)), ("Cogumelo", (470, 470)),
    ("Erva Curativa", (1000, 700)), ("Flor Medicinal", (860, 690)), ("Cogumelo", (420, 1000)),
    ("Planta Rara", (330, 1100)), ("Erva Especial", (530, 1190)), ("Flor Medicinal", (450, 1215)),
    ("Cogumelo", (880, 1110)), ("Erva Curativa", (760, 1010)), ("Erva Especial", (640, 1420)),
    ("Planta Rara", (700, 1360)), ("Cogumelo", (1260, 330)), ("Flor Medicinal", (1380, 260)),
    ("Planta Rara", (1780, 260)), ("Erva Especial", (1690, 200)), ("Erva Curativa", (1470, 610)),
    ("Cogumelo", (1300, 980)), ("Flor Medicinal", (1400, 880)), ("Erva Curativa", (1100, 500)),
    ("Erva Especial", (1480, 1260)), ("Planta Rara", (1800, 1330)),
]

# Sprites escolhidos dos sheets (indices de slice_sheets.py).
CATALOG = {
    "tree_big": [("a", i) for i in (22, 23, 24, 25, 26, 27)] + [("b", i) for i in (24, 25, 26, 27, 28, 29)] + [("c", i) for i in (35, 37, 38)],
    "tree_small": [("a", i) for i in (28, 29, 30, 31)] + [("b", i) for i in (30, 32, 33, 34)] + [("c", i) for i in (39, 40, 41, 44, 45, 46)],
    "bush": [("a", i) for i in (32, 33, 34, 35, 36)] + [("b", 31)] + [("c", i) for i in (42, 43, 49, 50, 51, 52)],
    "rock_small": [("a", i) for i in (42, 43, 44, 45)] + [("b", i) for i in (38, 39, 40, 41, 42, 43, 44)] + [("c", i) for i in (56, 63, 64, 65, 66)],
    "rock_big": [("a", i) for i in (37, 38, 39, 40, 46)] + [("b", i) for i in (35, 36, 37)] + [("c", i) for i in (59, 53)],
    "waterfall": [("c", 76)],
}
# Arvores "de cor" aparecem menos para a floresta continuar majoritariamente verde.
COLORFUL = {("a", 25), ("a", 26), ("a", 27), ("b", 27), ("b", 29), ("c", 37), ("a", 30), ("a", 31), ("b", 34), ("a", 24), ("b", 25), ("b", 28)}


# ---------------------------------------------------------------- slicing
def components(alpha: np.ndarray):
    h, w = alpha.shape
    mask = alpha > 24
    labels = np.zeros((h, w), dtype=np.int32)
    comps = []
    for y in range(h):
        for x in np.flatnonzero(mask[y] & (labels[y] == 0)):
            if labels[y, x]:
                continue
            lab = len(comps) + 1
            q = deque([(y, x)])
            labels[y, x] = lab
            x0 = x1 = x
            y0 = y1 = y
            area = 0
            while q:
                cy, cx = q.popleft()
                area += 1
                x0 = min(x0, cx); x1 = max(x1, cx); y0 = min(y0, cy); y1 = max(y1, cy)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = lab
                        q.append((ny, nx))
            comps.append({"labels": [lab], "box": [int(x0), int(y0), int(x1) + 1, int(y1) + 1], "area": area})
    return labels, comps


def slice_sheet(path: Path):
    im = np.array(Image.open(path).convert("RGBA"))
    labels, comps = components(im[:, :, 3])
    big = [c for c in comps if c["area"] >= 600]
    gap = 6
    for s in (c for c in comps if c["area"] < 600):
        sb = s["box"]
        for g in big:
            gb = g["box"]
            if gb[0] - gap <= sb[2] and sb[0] - gap <= gb[2] and gb[1] - gap <= sb[3] and sb[1] - gap <= gb[3]:
                g["labels"] += s["labels"]
                gb[0] = min(gb[0], sb[0]); gb[1] = min(gb[1], sb[1]); gb[2] = max(gb[2], sb[2]); gb[3] = max(gb[3], sb[3])
                g["area"] += s["area"]
                break
    big = [b for b in big if b["area"] >= 150]
    big.sort(key=lambda b: (round(b["box"][1] / 40), b["box"][0]))
    return im, labels, big


def extract(im, labels, comp) -> Image.Image:
    x0, y0, x1, y1 = comp["box"]
    region = im[y0:y1, x0:x1].copy()
    keep = np.isin(labels[y0:y1, x0:x1], comp["labels"])
    region[~keep] = 0
    return Image.fromarray(region, "RGBA")


def is_brown(px: np.ndarray) -> np.ndarray:
    r, g, b = px[..., 0].astype(int), px[..., 1].astype(int), px[..., 2].astype(int)
    return (r > g + 8) & (g > b) & (r > 70) & (r < 210) & (r - b > 35)


def analyse_prop(img: Image.Image, kind: str) -> dict:
    arr = np.array(img)
    a = arr[:, :, 3] > 40
    h, w = a.shape
    ys, xs = np.nonzero(a)
    bottom = int(ys.max())
    if kind.startswith("tree"):
        band_top = int(h * 0.5)
        brown = is_brown(arr) & a
        brown[:band_top] = False
        cols = brown.sum(axis=0)
        cx = w // 2
        lo = max(0, int(w * 0.25)); hi = min(w, int(w * 0.75))
        cand = np.flatnonzero(cols[lo:hi] >= max(3, cols[lo:hi].max() * 0.35)) + lo
        if cand.size:
            tx0, tx1 = int(cand.min()), int(cand.max())
        else:
            tx0, tx1 = cx - w // 10, cx + w // 10
        tw = tx1 - tx0
        min_w, max_w = int(w * 0.14), int(w * 0.26)
        if tw < min_w or tw > max_w:
            mid = (tx0 + tx1) // 2
            tw = max(min_w, min(max_w, tw))
            tx0 = mid - tw // 2
            tx1 = tx0 + tw
        band = brown[:, tx0:tx1 + 1]
        bys = np.nonzero(band)[0]
        foot_y = int(np.percentile(bys, 88)) if bys.size else int(bottom - h * 0.12)
        foot_y = min(foot_y, bottom - int(h * 0.05))
        foot_x = (tx0 + tx1) / 2
        rect_h = max(10, int(h * 0.08))
        coll = [tx0 - foot_x, -rect_h, tx1 - tx0, rect_h + int(h * 0.02)]
        return {"anchor": [foot_x, foot_y], "collision": coll}
    if kind.startswith("rock"):
        x0, x1 = int(xs.min()), int(xs.max())
        top = int(ys.min())
        ph = bottom - top
        foot_y = bottom - int(ph * 0.1)
        foot_x = (x0 + x1) / 2
        cw = (x1 - x0) * 0.82
        ch = ph * (0.42 if kind == "rock_big" else 0.5)
        coll = [-cw / 2, -ch, cw, ch + ph * 0.06]
        return {"anchor": [foot_x, foot_y], "collision": coll}
    if kind == "waterfall":
        x0, x1 = int(xs.min()), int(xs.max())
        return {"anchor": [(x0 + x1) / 2, bottom - h * 0.18], "collision": None}
    return {"anchor": [(int(xs.min()) + int(xs.max())) / 2, bottom - h * 0.12], "collision": None}


def build_props() -> dict:
    PROPS_DIR.mkdir(parents=True, exist_ok=True)
    sheets = {}
    for key in ("a", "b", "c"):
        sheets[key] = slice_sheet(SHEETS / f"sheet_{key}.png")
    catalog = {}
    for kind, entries in CATALOG.items():
        for sheet_key, idx in entries:
            im, labels, comps = sheets[sheet_key]
            img = extract(im, labels, comps[idx])
            name = f"{kind}_{sheet_key}{idx:02d}"
            img.save(PROPS_DIR / f"{name}.png")
            info = analyse_prop(img, kind)
            info.update({"name": name, "kind": kind, "size": list(img.size), "colorful": (sheet_key, idx) in COLORFUL,
                         "texture": f"res://assets/maps/floresta_v2/props/{name}.png", "image": img})
            catalog[name] = info
    # Tocha animada e estatua de cavaleiro de Eldoria v2 (tools/eldoria_v2/slice_sheets.py).
    torch = Image.open(ELDORIA_PROPS / "torch_0.png").convert("RGBA")
    catalog["torch"] = {"name": "torch", "kind": "torch", "size": list(torch.size), "colorful": False,
                        "texture": "res://assets/maps/eldoria_v2/props/torch_0.png", "image": torch,
                        "frames": [f"res://assets/maps/eldoria_v2/props/torch_{i}.png" for i in range(4)],
                        "anchor": [torch.width / 2, float(torch.height)],
                        "scale": TORCH_SCALE, "collision": [-48, -62, 96, 62]}
    statue = Image.open(ELDORIA_PROPS / "statue.png").convert("RGBA")
    catalog["statue"] = {"name": "statue", "kind": "statue", "size": list(statue.size), "colorful": False,
                         "texture": "res://assets/maps/eldoria_v2/props/statue.png", "image": statue,
                         "anchor": [statue.width / 2, float(statue.height)],
                         "scale": STATUE_SCALE, "collision": [-58, -46, 116, 46]}
    return catalog


# ---------------------------------------------------------------- geometry
def seg_dist(px, py, a, b):
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    denom = max(1e-6, dx * dx + dy * dy)
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / denom, 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def path_distance(px, py, scale):
    d = np.full(px.shape, 1e9, dtype=np.float32)
    for p in PATHS:
        pts = [(x * scale, y * scale) for x, y in p["pts"]]
        for a, b in zip(pts, pts[1:]):
            d = np.minimum(d, seg_dist(px, py, a, b))
    return d


def ellipse_value(px, py, e, scale, grow=0.0):
    cx, cy = e["c"]; rx, ry = e["r"]
    return ((px - cx * scale) / ((rx + grow) * scale)) ** 2 + ((py - cy * scale) / ((ry + grow) * scale)) ** 2


def value_noise(shape, cell, seed):
    gen = np.random.default_rng(seed)
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    grid = gen.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[: shape[0], : shape[1]] / 255.0


def fbm(shape, base_cell, seed, octaves=4):
    total = np.zeros(shape, dtype=np.float32)
    amp, norm = 1.0, 0.0
    cell = base_cell
    for o in range(octaves):
        total += value_noise(shape, max(2, cell), seed + o * 101) * amp
        norm += amp
        amp *= 0.5
        cell //= 2
    return total / norm


def walk_field(px, py, scale, noise):
    """Valor <= 0 => andavel. Usado pela mascara e pelo chao (mesma geometria)."""
    best = np.full(px.shape, 1e9, dtype=np.float32)
    for p in PATHS:
        hw = p.get("walk_hw", PATH_WALK_HW)
        pts = [(x * scale, y * scale) for x, y in p["pts"]]
        for a, b in zip(pts, pts[1:]):
            best = np.minimum(best, seg_dist(px, py, a, b) / (hw * scale) - 1.0)
    for e in CLEARINGS.values():
        best = np.minimum(best, np.sqrt(ellipse_value(px, py, e, scale)) - 1.0)
    best = best + (noise - 0.5) * 0.22
    lake = np.sqrt(ellipse_value(px, py, LAKE, scale)) - 1.0 + (noise - 0.5) * 0.12
    best = np.where(lake < 0.04, 1.0, best)
    b = BORDER_D * scale
    w, h = MAP_D[0] * scale, MAP_D[1] * scale
    border = (px < b) | (py < b) | (px > w - b) | (py > h - b)
    return np.where(border, 1.0, best), lake


# ---------------------------------------------------------------- palettes
def hexes(*codes):
    return np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in codes], dtype=np.float32)


GRASS = hexes("#2f6a22", "#3d7f28", "#4c9530", "#5ca937", "#6dba40", "#83c94c", "#9bd85c")
THICKET = hexes("#17361a", "#1e4420", "#265226", "#2e602b", "#376d31")
DIRT = hexes("#8f6a40", "#a77c4b", "#bb8f58", "#cba066", "#d8b277", "#e4c48d")
SAND = hexes("#c9a96f", "#d9bb82", "#e7cd98")
WATER = hexes("#154da8", "#1b61c4", "#2378d8", "#2f90e6", "#46a9f0", "#79c9f7", "#b9e8ff")
STONE = hexes("#5e5d63", "#77767c", "#8f8e93", "#a9a8ac", "#c2c1c3")
ARENA_DIRT = hexes("#6e5236", "#806040", "#93704a", "#a58055", "#b48f61")
FLOWERS = hexes("#f4a3c8", "#fff4dc", "#ffd84a", "#8fd0ff", "#ff8f8f")


def pick(palette, t):
    idx = np.clip((t * (len(palette) - 1e-3)).astype(int), 0, len(palette) - 1)
    return palette[idx]


# ---------------------------------------------------------------- ground
def eldoria_tiled(name: str, shape) -> np.ndarray:
    """Textura de piso de Eldoria v2 repetida no chao (256 px de mundo = 128 px de chao)."""
    size = 256 // (WORLD_PER_D // GROUND_PER_D)
    t = np.array(Image.open(ELDORIA_TILES / f"{name}.png").convert("RGB").resize((size, size), Image.LANCZOS), np.float32)
    reps = (math.ceil(shape[0] / size), math.ceil(shape[1] / size), 1)
    return np.tile(t, reps)[:shape[0], :shape[1]]


def paint_ground(props: list, catalog: dict) -> Image.Image:
    W, H = GROUND_SIZE
    py, px = np.mgrid[0:H, 0:W].astype(np.float32)
    s = GROUND_PER_D
    n_big = fbm((H, W), 96, 11)
    n_mid = fbm((H, W), 24, 23, 3)
    n_fine = np_rng.random((H, W)).astype(np.float32)
    n_edge = fbm((H, W), 32, 37, 3)
    walk, lake = walk_field(px, py, s, n_edge)

    # Grama base e chao escuro da mata fechada.
    grass_t = np.clip(0.18 + n_big * 0.45 + (n_mid - 0.5) * 0.45 + (n_fine - 0.5) * 0.22, 0, 0.999)
    img = pick(GRASS, grass_t)
    thick_t = np.clip(0.15 + n_big * 0.5 + (n_mid - 0.5) * 0.5 + (n_fine - 0.5) * 0.25, 0, 0.999)
    thick = pick(THICKET, thick_t)
    blend = np.clip((walk - 0.0) / 0.35, 0, 1)[..., None]
    img = img * (1 - blend) + thick * blend

    # Clareiras mais claras no centro.
    for name, e in CLEARINGS.items():
        if name == "arena":
            continue
        v = ellipse_value(px, py, e, s)
        light = np.clip(1.0 - v, 0, 1)[..., None] * 0.10
        img = img + (GRASS[-1] - img) * light

    # Trilhas de terra com borda irregular e tufos.
    pd = path_distance(px, py, s) / s
    jag = (n_edge - 0.5) * 9 + (n_fine - 0.5) * 2.5
    path_dirt = pd < (PATH_DIRT_HW + jag)
    clearing_dirt = np.zeros_like(path_dirt)
    for name, e in CLEARINGS.items():
        if name in ("arena", "lago_margem"):
            continue
        v = np.sqrt(ellipse_value(px, py, e, s, grow=-e["r"][1] * 0.62))
        clearing_dirt |= v + (n_edge - 0.5) * 0.5 < 1.0
    dirt_mask = path_dirt | clearing_dirt
    dirt_t = np.clip(0.3 + (n_mid - 0.5) * 0.7 + (n_fine - 0.5) * 0.35, 0, 0.999)
    dirt = pick(DIRT, dirt_t)
    edge = path_dirt & (pd > PATH_DIRT_HW + jag - 2.2) & ~clearing_dirt
    img = np.where(dirt_mask[..., None], dirt, img)
    img = np.where(edge[..., None], DIRT[1], img)
    pebble = dirt_mask & (n_fine > 0.985)
    img = np.where(pebble[..., None], STONE[3], img)

    # Lago: a agua em si e animada no jogo (por baixo do chao, ver lake_overlay);
    # aqui so a margem natural: cascalho e areia molhados, borda escura e franja de grama.
    water = lake < 0.04
    fringe = lake + (n_edge - 0.5) * 0.07 + (n_fine - 0.5) * 0.015
    sand = (lake >= 0.04) & (fringe < 0.15)
    bank = np.where((n_mid > 0.47)[..., None], eldoria_tiled("gravel", (H, W)), eldoria_tiled("sand", (H, W)) * 0.86)
    dry_t = np.clip((lake - 0.04) / 0.11, 0, 1)[..., None]
    wet_col = bank * 0.58 + np.array([14, 26, 30], np.float32)
    img = np.where(sand[..., None], wet_col * (1 - dry_t) + bank * dry_t, img)
    img = np.where(((lake >= 0.04) & (lake < 0.052))[..., None], img * 0.55, img)

    # Arena do chefe: piso nobre com as texturas de Eldoria v2 (lajotas, anel de
    # pedra com musgo, borda de paralelepipedo e medalhao central com aro dourado).
    av = np.sqrt(ellipse_value(px, py, ARENA, s))
    av = av + (n_edge - 0.5) * 0.025
    arena_floor = av < 0.95
    img = np.where(arena_floor[..., None], eldoria_tiled("plaza", (H, W)), img)
    ring = (av >= 0.78) & (av < 0.95)
    img = np.where(ring[..., None], eldoria_tiled("stone_moss", (H, W)), img)
    rim = (av >= 0.90) & (av < 0.95)
    img = np.where(rim[..., None], eldoria_tiled("cobble", (H, W)) * 0.9, img)
    for edge_v, shade in ((0.78, 0.62), (0.90, 0.7), (0.95, 0.5)):
        img = np.where((np.abs(av - edge_v) < 0.006)[..., None], img * shade, img)
    medal = av < 0.36
    img = np.where(medal[..., None], eldoria_tiled("cobble", (H, W)), img)
    gold = np.array([214, 170, 74], np.float32)
    img = np.where(((av >= 0.36) & (av < 0.385))[..., None], gold * (0.85 + n_fine[..., None] * 0.15), img)
    img = np.where((np.abs(av - 0.2) < 0.008)[..., None], gold * 0.8, img)
    glow = np.clip(1 - av / 0.36, 0, 1)[..., None] * 0.18
    img = img * (1 - glow) + np.array([120, 30, 20], np.float32) * glow

    # Flores e tufos na grama andavel.
    open_grass = (walk < 0) & ~dirt_mask & ~arena_floor & ~ring & ~water & ~sand
    flower_seed = (n_fine > 0.9965) & open_grass & (n_big > 0.35)
    fy, fx = np.nonzero(flower_seed)
    out = img
    for y, x in zip(fy, fx):
        col = FLOWERS[(x * 7 + y * 13) % len(FLOWERS)]
        out[max(0, y - 1):y + 2, x] = col
        out[y, max(0, x - 1):x + 2] = col
        out[y, x] = FLOWERS[2] if col[2] > 200 else FLOWERS[1]
    tuft = (n_fine > 0.93) & (n_fine < 0.95) & ((walk < 0.3) & ~dirt_mask & ~water & ~arena_floor)
    out = np.where(tuft[..., None], GRASS[-1], out)
    tuft_dark = (n_fine > 0.05) & (n_fine < 0.07) & ~dirt_mask & ~water & ~arena_floor
    out = np.where(tuft_dark[..., None], out * 0.82, out)

    # Sombras suaves sob arvores e pedras.
    shadow = np.zeros((H, W), dtype=np.float32)
    for p in props:
        info = catalog[p["prop"]]
        if info["kind"] in ("torch",):
            continue
        fx, fy = p["x"] * s, p["y"] * s
        sw = info["size"][0] * info.get("scale", PROP_SCALE) / WORLD_PER_D * s * (0.33 if info["kind"].startswith("tree") else 0.42)
        sh = sw * 0.38
        x0, x1 = int(max(0, fx - sw)), int(min(W, fx + sw + 1))
        y0, y1 = int(max(0, fy - sh)), int(min(H, fy + sh + 1))
        if x0 >= x1 or y0 >= y1:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        v = ((xx - fx) / sw) ** 2 + ((yy - fy) / sh) ** 2
        shadow[y0:y1, x0:x1] = np.maximum(shadow[y0:y1, x0:x1], np.clip(1 - v, 0, 1) * 0.42)
    out = out * (1 - shadow[..., None])
    alpha = np.where(water, 0, 255).astype(np.uint8)
    ground = Image.fromarray(np.dstack([np.clip(out, 0, 255).astype(np.uint8), alpha]), "RGBA")
    return ground, lake_overlay(lake, n_edge, n_fine)


def lake_bbox() -> tuple[int, int, int, int]:
    """Caixa do lago em px de chao (com folga para o ruido da borda)."""
    s = GROUND_PER_D
    cx, cy = LAKE["c"]; rx, ry = LAKE["r"]
    return (int((cx - rx * 1.25) * s), int((cy - ry * 1.25) * s), int((cx + rx * 1.25) * s), int((cy + ry * 1.25) * s))


def lake_overlay(lake: np.ndarray, n_edge: np.ndarray, n_fine: np.ndarray) -> Image.Image:
    """Camada por cima da agua animada: profundidade, espuma na margem, aneis no pe
    da cachoeira, vitorias-regias e brilhos. Transparente fora da agua."""
    x0, y0, x1, y1 = lake_bbox()
    lk = lake[y0:y1, x0:x1]
    ne = n_edge[y0:y1, x0:x1]
    nf = n_fine[y0:y1, x0:x1]
    h, w = lk.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    water = lk < 0.04
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)

    def layer(mask, color, alpha):
        nonlocal rgb, a
        alpha = np.where(mask, alpha, 0.0).astype(np.float32)
        out_a = alpha + a * (1 - alpha)
        safe = np.maximum(out_a, 1e-6)[..., None]
        rgb = (np.array(color, np.float32) * alpha[..., None] + rgb * (a * (1 - alpha))[..., None]) / safe
        a = out_a

    depth = np.clip(-lk / 0.6, 0, 1)
    # beirada rasa esverdeada -> fundo azul-petroleo escuro
    layer(water, (40, 150, 140), 0.35 * (1 - depth) ** 2)
    layer(water, (6, 30, 62), 0.12 + 0.6 * depth ** 1.2 + (ne - 0.5) * 0.08)
    # espuma quebrada colada na margem e uma segunda linha mais fraca
    layer(water & (lk > -0.011) & (ne + nf * 0.3 > 0.55), (214, 238, 240), 0.45)
    layer(water & (np.abs(lk + 0.06) < 0.006) & (ne > 0.5), (200, 235, 240), 0.35)
    # pe da cachoeira: agua revolta e aneis
    fx, fy = WATERFALL_FOOT[0] * GROUND_PER_D - x0, WATERFALL_FOOT[1] * GROUND_PER_D - y0 + 18
    d = np.hypot((xx - fx) / 1.6, yy - fy)
    layer(water & (d < 16) & (nf > 0.25), (236, 248, 250), 0.85)
    for r, al in ((26, 0.6), (40, 0.42), (56, 0.26), (74, 0.14)):
        layer(water & (np.abs(d - r) < 1.6) & (ne > 0.35), (220, 242, 248), al)
    # vitorias-regias em grupinhos perto da margem
    rng_l = random.Random(77)
    pads = []
    for cx_d, cy_d in ((140, 1060), (300, 1080), (320, 960), (110, 980)):
        for _ in range(rng_l.randint(3, 5)):
            px_ = (cx_d + rng_l.uniform(-22, 22)) * GROUND_PER_D - x0
            py_ = (cy_d + rng_l.uniform(-14, 14)) * GROUND_PER_D - y0
            if 0 <= int(py_) < h and 0 <= int(px_) < w and -0.45 < lk[int(py_), int(px_)] < -0.07:
                pads.append((px_, py_, rng_l.uniform(11, 17), rng_l.uniform(0, math.tau), rng_l.random() < 0.35))
    for px_, py_, r, ang, flower in pads:
        dx, dy = xx - px_, (yy - py_) / 0.62
        dist = np.hypot(dx, dy)
        theta = np.arctan2(dy, dx)
        notch = np.abs(((theta - ang + math.pi) % math.tau) - math.pi) < 0.35
        pad = (dist < r) & ~notch
        layer(pad & (dist > r - 1.6), (28, 76, 34), 1.0)
        layer(pad & (dist <= r - 1.6), (62, 132, 52), 1.0)
        layer(pad & (dist <= r * 0.45) & (dx - dy < 0), (104, 170, 74), 1.0)
        if flower:
            fdist = np.hypot(xx - (px_ - r * 0.15), yy - (py_ - r * 0.2))
            layer(pad & (fdist < 3.2), (246, 166, 200), 1.0)
            layer(pad & (fdist < 1.3), (255, 228, 110), 1.0)
    # brilhos pequenos
    layer(water & (nf > 0.9992) & (depth > 0.15), (255, 255, 255), 0.55)
    a = np.where(water | (a > 0) & (lk < 0.045), a, 0)
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8), "RGBA")


def water_under(ground: Image.Image, overlay: Image.Image) -> Image.Image:
    """Chao com a agua por baixo (para minimapa e previews)."""
    water = Image.open(ELDORIA_TILES / "water_0.png").convert("RGBA").resize((128, 128), Image.LANCZOS)
    full = Image.new("RGBA", ground.size)
    x0, y0, x1, y1 = lake_bbox()
    for y in range(y0, y1, 128):
        for x in range(x0, x1, 128):
            full.paste(water, (x, y))
    full.alpha_composite(overlay, (x0, y0))
    full.alpha_composite(ground)
    return full


# ---------------------------------------------------------------- placement
def mask_grid():
    """Mascara andavel na resolucao de colisao (celulas de 16 px de mundo)."""
    W, H = MASK_SIZE
    scale = WORLD_PER_D / MASK_CELL_WORLD  # celulas por D
    py, px = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
    noise = np.asarray(Image.fromarray((fbm((MAP_D[1] * GROUND_PER_D, MAP_D[0] * GROUND_PER_D), 32, 37, 3) * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), dtype=np.float32) / 255.0
    walk, _ = walk_field(px, py, scale, noise)
    return walk < 0, walk


def in_walk(mask, x, y):
    cx = int(x * WORLD_PER_D / MASK_CELL_WORLD)
    cy = int(y * WORLD_PER_D / MASK_CELL_WORLD)
    if cx < 0 or cy < 0 or cx >= mask.shape[1] or cy >= mask.shape[0]:
        return False
    return bool(mask[cy, cx])


def walk_value(walk, x, y):
    cx = min(walk.shape[1] - 1, max(0, int(x * WORLD_PER_D / MASK_CELL_WORLD)))
    cy = min(walk.shape[0] - 1, max(0, int(y * WORLD_PER_D / MASK_CELL_WORLD)))
    return float(walk[cy, cx])


def dist_to_paths(x, y):
    best = 1e9
    for p in PATHS:
        for a, b in zip(p["pts"], p["pts"][1:]):
            best = min(best, float(seg_dist(np.float32(x), np.float32(y), a, b)))
    return best


def choose(catalog, kind, colorful_chance=0.18):
    names = [n for n, i in catalog.items() if i["kind"] == kind]
    plain = [n for n in names if not catalog[n]["colorful"]]
    if plain and rng.random() > colorful_chance:
        return rng.choice(plain)
    return rng.choice(names)


def place_props(catalog, mask, walk):
    props = []
    keepout = [ENTRY, CAVE_PORTAL]

    def near_keepout(x, y, r):
        return any(math.hypot(x - kx, y - ky) < r for kx, ky in keepout)

    def add(name, x, y, collide=True, flip=None, scale=None):
        props.append({"prop": name, "x": x, "y": y, "flip": rng.random() < 0.5 if flip is None else flip, "collide": collide, "scale": scale})

    # Mata fechada: arvores densas fora da area andavel.
    step = 56
    for gy in range(-step // 2, MAP_D[1] + step, step):
        for gx in range(-step // 2, MAP_D[0] + step, step):
            x = gx + rng.uniform(-18, 18) + (step / 2 if (gy // step) % 2 else 0)
            y = gy + rng.uniform(-18, 18)
            if not (-30 < x < MAP_D[0] + 30 and -10 < y < MAP_D[1] + 40):
                continue
            wv = walk_value(walk, x, y)
            if wv < 0.12:
                continue
            lake_v = math.sqrt(((x - LAKE["c"][0]) / LAKE["r"][0]) ** 2 + ((y - LAKE["c"][1]) / LAKE["r"][1]) ** 2)
            if lake_v < 1.25:
                continue
            arena_v = math.sqrt(((x - ARENA["c"][0]) / ARENA["r"][0]) ** 2 + ((y - ARENA["c"][1]) / ARENA["r"][1]) ** 2)
            if arena_v < 1.42:
                continue
            roll = rng.random()
            kind = "tree_big" if roll < 0.62 else "tree_small" if roll < 0.86 else "bush" if roll < 0.95 else "rock_big"
            add(choose(catalog, kind), x, y, collide=False)

    # Arvores e pedras soltas nas margens (com colisao no pe).
    attempts = 0
    placed = []
    while attempts < 6000 and len(placed) < 95:
        attempts += 1
        x = rng.uniform(BORDER_D, MAP_D[0] - BORDER_D)
        y = rng.uniform(BORDER_D, MAP_D[1] - BORDER_D)
        if not in_walk(mask, x, y):
            continue
        wv = walk_value(walk, x, y)
        if wv > -0.05:
            continue
        if dist_to_paths(x, y) < PATH_DIRT_HW + 16:
            continue
        if near_keepout(x, y, 120):
            continue
        arena_v = math.sqrt(((x - ARENA["c"][0]) / ARENA["r"][0]) ** 2 + ((y - ARENA["c"][1]) / ARENA["r"][1]) ** 2)
        if arena_v < 1.05:
            continue
        inside_clearing = any(
            ((x - e["c"][0]) / e["r"][0]) ** 2 + ((y - e["c"][1]) / e["r"][1]) ** 2 < 0.45
            for n, e in CLEARINGS.items() if n != "arena")
        if inside_clearing:
            continue
        if any(math.hypot(x - px_, y - py_) < 55 for px_, py_ in placed):
            continue
        roll = rng.random()
        if roll < 0.32:
            add(choose(catalog, "tree_small", 0.3), x, y)
        elif roll < 0.48:
            add(choose(catalog, "tree_big", 0.25), x, y)
        elif roll < 0.74:
            add(choose(catalog, "rock_small"), x, y)
        else:
            add(choose(catalog, "bush"), x, y, collide=False)
        placed.append((x, y))

    # Cachoeira e rochedos no topo do lago.
    add("waterfall_c76", WATERFALL_FOOT[0], WATERFALL_FOOT[1], collide=False, flip=False, scale=3.0)
    for dx, dy in ((-118, -10), (112, -6), (-185, 26)):
        add(choose(catalog, "rock_big"), WATERFALL_FOOT[0] + dx, WATERFALL_FOOT[1] + dy, collide=False, scale=2.5)
    # Pedras com musgo meio dentro d'agua ao longo da margem (fora da cachoeira).
    for i in range(22):
        ang = i / 22 * math.tau + rng.uniform(-0.08, 0.08)
        r = 0.99 + rng.uniform(-0.03, 0.05)
        x = LAKE["c"][0] + math.cos(ang) * LAKE["r"][0] * r
        y = LAKE["c"][1] + math.sin(ang) * LAKE["r"][1] * r
        if math.hypot(x - WATERFALL_FOOT[0], y - WATERFALL_FOOT[1]) < 120 or x < BORDER_D + 10:
            continue
        if i % 3 == 1:
            continue
        kind = "rock_big" if i % 5 == 0 else "rock_small"
        add(choose(catalog, kind), x, y, collide=False, scale=1.6 if kind == "rock_small" else 1.9)

    # Arena: mata baixa por fora, tochas na borda e estatuas de cavaleiro nas diagonais.
    def free_spot(x, y, gate_r=110, portal_r=70):
        return math.hypot(x - GATE[0], y - GATE[1]) >= gate_r and math.hypot(x - CAVE_PORTAL[0], y - CAVE_PORTAL[1]) >= portal_r
    for i in range(30):
        ang = (i + 0.5) / 30 * math.tau
        r = 1.24 + rng.uniform(-0.02, 0.03)
        x = ARENA["c"][0] + math.cos(ang) * ARENA["r"][0] * r
        y = ARENA["c"][1] + math.sin(ang) * ARENA["r"][1] * r
        if free_spot(x, y):
            add(choose(catalog, ("bush", "tree_small", "bush")[i % 3]), x, y, collide=False)
    for i in range(8):
        ang = (i / 8) * math.tau + math.pi / 8
        x = ARENA["c"][0] + math.cos(ang) * ARENA["r"][0] * 0.99
        y = ARENA["c"][1] + math.sin(ang) * ARENA["r"][1] * 0.99
        if free_spot(x, y, 90, 70):
            add("torch", x, y, collide=True, flip=False)
    for i in range(4):
        ang = (i / 4) * math.tau + math.pi / 4
        x = ARENA["c"][0] + math.cos(ang) * ARENA["r"][0] * 1.09
        y = ARENA["c"][1] + math.sin(ang) * ARENA["r"][1] * 1.09
        if free_spot(x, y, 130, 90):
            add("statue", x, y, collide=True, flip=math.cos(ang) > 0)
    # Entrada da arena guardada por duas estatuas e tochas.
    gdx, gdy = (1570 - 1330), (1175 - 920)
    glen = math.hypot(gdx, gdy)
    perp = (-gdy / glen, gdx / glen)
    for side in (-1, 1):
        add("statue", GATE[0] + perp[0] * 70 * side, GATE[1] + perp[1] * 70 * side, collide=True, flip=side > 0)
        add("torch", GATE[0] + perp[0] * 44 * side + 10, GATE[1] + perp[1] * 44 * side + 14, collide=True, flip=False)
    # Tochas no portal de entrada.
    for side in (-1, 1):
        add("torch", ENTRY[0] + 46 * side, ENTRY[1] + 22, collide=True, flip=False)
    return props


# ---------------------------------------------------------------- export
def path_spawns(mask):
    """Pequenos grupos (1-2) espalhados ao longo das trilhas, fora da entrada, arena e clareiras."""
    result = []
    for path_index, p in enumerate(PATHS):
        pts = p["pts"]
        carry = PATH_MOB_STEP * 0.6
        for a, b in zip(pts, pts[1:]):
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            t = carry
            while t < seg:
                x = a[0] + (b[0] - a[0]) * t / seg
                y = a[1] + (b[1] - a[1]) * t / seg
                t += PATH_MOB_STEP
                if math.hypot(x - ENTRY[0], y - ENTRY[1]) < 260:
                    continue
                if math.sqrt(((x - ARENA["c"][0]) / ARENA["r"][0]) ** 2 + ((y - ARENA["c"][1]) / ARENA["r"][1]) ** 2) < 1.35:
                    continue
                if any(((x - e["c"][0]) / e["r"][0]) ** 2 + ((y - e["c"][1]) / e["r"][1]) ** 2 < 0.8 for e in CLEARINGS.values()):
                    continue
                if not in_walk(mask, x, y):
                    continue
                dist = math.hypot(x - ENTRY[0], y - ENTRY[1])
                tier = next(options for limit, options in PATH_MOB_TIERS if dist < limit)
                enemy, respawn = tier[(len(result) + path_index) % len(tier)]
                count = 2 if (len(result) % 3 == 0) else 1
                result.append({"enemy": enemy, "count": count, "respawn": respawn,
                               "zone": [round(x - 45), round(y - 35), 90, 70]})
            carry = t - seg
    return result


def prop_entry(p, catalog):
    info = catalog[p["prop"]]
    w, h = info["size"]
    ax, ay = info["anchor"]
    flip = bool(p["flip"])
    off_x = -(w - ax) if flip else -ax
    entry = {
        "texture": info["texture"],
        "pos": [round(p["x"] * WORLD_PER_D, 1), round(p["y"] * WORLD_PER_D, 1)],
        "scale": p.get("scale") or info.get("scale", PROP_SCALE),
        "offset": [round(off_x, 1), round(-ay, 1)],
        "flip_h": flip,
    }
    if info.get("frames"):
        entry["frames"] = info["frames"]
        entry["fps"] = 6
    coll = info["collision"]
    if p["collide"] and coll:
        cx, cy, cw, ch = coll
        if flip:
            cx = -(cx + cw)
        sc = entry["scale"]
        entry["collision"] = [round(cx * sc, 1), round(cy * sc, 1), round(cw * sc, 1), round(ch * sc, 1)]
    return entry


def render_preview(ground: Image.Image, entries, catalog_by_tex, factor=0.25, debug=False):
    gw, gh = ground.size
    base = ground.resize((int(MAP_D[0] * WORLD_PER_D * factor), int(MAP_D[1] * WORLD_PER_D * factor)), Image.NEAREST).convert("RGBA")
    for e in sorted(entries, key=lambda e: e["pos"][1]):
        img = catalog_by_tex[e["texture"]]
        sc = e["scale"] * factor
        im = img.transpose(Image.FLIP_LEFT_RIGHT) if e["flip_h"] else img
        im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.NEAREST)
        x = int(e["pos"][0] * factor + e["offset"][0] * sc)
        y = int(e["pos"][1] * factor + e["offset"][1] * sc)
        sx, sy = max(0, -x), max(0, -y)
        if sx >= im.width or sy >= im.height or x >= base.width or y >= base.height:
            continue
        base.alpha_composite(im.crop((sx, sy, im.width, im.height)), (max(0, x), max(0, y)))
    if debug:
        dr = ImageDraw.Draw(base)
        for e in entries:
            if "collision" in e:
                cx, cy, cw, ch = e["collision"]
                x0 = (e["pos"][0] + cx) * factor; y0 = (e["pos"][1] + cy) * factor
                dr.rectangle([x0, y0, x0 + cw * factor, y0 + ch * factor], outline=(255, 0, 255, 255))
    return base


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    CHUNKS_DIR.mkdir(parents=True, exist_ok=True)
    catalog = build_props()
    mask, walk = mask_grid()
    props = place_props(catalog, mask, walk)
    ground, overlay = paint_ground(props, catalog)
    overlay.save(KIT / "floresta_v2_lake_overlay.png", optimize=True)
    ground_view = water_under(ground, overlay)

    for gy in range(CHUNK_GRID[1]):
        for gx in range(CHUNK_GRID[0]):
            box = (gx * CHUNK_PX[0], gy * CHUNK_PX[1], (gx + 1) * CHUNK_PX[0], (gy + 1) * CHUNK_PX[1])
            ground.crop(box).save(CHUNKS_DIR / f"floresta_v2_chunk_{gx:02d}_{gy:02d}.png", optimize=True)

    Image.fromarray((mask * 255).astype(np.uint8), "L").save(KIT / "floresta_v2_walkable.png")

    entries = [prop_entry(p, catalog) for p in props]
    catalog_by_tex = {i["texture"]: i["image"] for i in catalog.values()}
    preview = render_preview(ground_view, entries, catalog_by_tex)
    preview.save(OUT / "preview.png")
    dbg = render_preview(ground_view, entries, catalog_by_tex, debug=True)
    red = Image.fromarray(np.where(mask[..., None], 0, np.array([255, 0, 0, 70], dtype=np.uint8)).astype(np.uint8), "RGBA").resize(dbg.size, Image.NEAREST)
    dbg.alpha_composite(red)
    dbg.save(OUT / "preview_colisao.png")
    for name, box in (("hub", (3200, 1800, 4600, 3100)), ("arena", (5500, 4000, 7700, 6100)), ("lago", (300, 3200, 2400, 5000))):
        crop = render_preview(ground_view, [e for e in entries if box[0] - 600 < e["pos"][0] < box[2] + 600 and box[1] - 600 < e["pos"][1] < box[3] + 900], catalog_by_tex, factor=0.5, debug=True)
        crop.crop(tuple(int(v * 0.5) for v in box)).save(OUT / f"zoom_{name}.png")
    preview.resize((500, 400), Image.LANCZOS).convert("RGB").save(KIT / "floresta_v2_minimap.png")

    data = {
        "version": 1,
        "map_size": [MAP_D[0] * WORLD_PER_D, MAP_D[1] * WORLD_PER_D],
        "chunks": {"dir": "res://assets/maps/floresta_v2/chunks", "prefix": "floresta_v2_chunk",
                   "grid": list(CHUNK_GRID), "chunk_px": list(CHUNK_PX), "scale": WORLD_PER_D / GROUND_PER_D},
        "walkable_mask": {"path": "res://assets/maps/floresta_v2/floresta_v2_walkable.png", "cell": MASK_CELL_WORLD},
        "minimap": "res://assets/maps/floresta_v2/floresta_v2_minimap.png",
        # agua animada por baixo do chao (transparente no lago) + camada de profundidade
        "lake": {"rect": [v * (WORLD_PER_D // GROUND_PER_D) for v in (lake_bbox()[0], lake_bbox()[1], lake_bbox()[2] - lake_bbox()[0], lake_bbox()[3] - lake_bbox()[1])],
                 "water_frames": [f"res://assets/maps/eldoria_v2/tiles/water_{i}.png" for i in range(4)],
                 "overlay": "res://assets/maps/floresta_v2/floresta_v2_lake_overlay.png", "overlay_scale": WORLD_PER_D / GROUND_PER_D},
        "boss_arena": {"center": [ARENA["c"][0] * WORLD_PER_D, ARENA["c"][1] * WORLD_PER_D],
                       "radius": [ARENA["r"][0] * WORLD_PER_D, ARENA["r"][1] * WORLD_PER_D]},
        "props": entries,
    }
    DATA_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    map_patch = {
        "size": data["map_size"],
        "spawn": [ENTRY[0] + 40, ENTRY[1] + 70],
        "portal_entry": list(ENTRY),
        "portal_cave": list(CAVE_PORTAL),
        "spawns": SPAWNS + path_spawns(mask),
        "collectibles": [{"item": n, "amount": 1, "pos": list(p)} for n, p in COLLECTIBLES],
    }
    (OUT / "map_patch.json").write_text(json.dumps(map_patch, ensure_ascii=False, indent=1), encoding="utf-8")
    bad = [c for c in map_patch["collectibles"] if not in_walk(mask, *c["pos"])]
    bad_spawn = [s["enemy"] for s in map_patch["spawns"] if not in_walk(mask, s["zone"][0] + s["zone"][2] / 2, s["zone"][1] + s["zone"][3] / 2)]
    print(f"props={len(entries)} colisoes={sum(1 for e in entries if 'collision' in e)} andavel={mask.mean():.2%}")
    print("coletaveis fora da area andavel:", bad)
    print("spawns com centro bloqueado:", bad_spawn)


if __name__ == "__main__":
    main()
