"""Monta a Eldoria v2 a partir das pecas de slice_sheets.py.

Uso: py tools/eldoria_v2/generate_eldoria_v2.py

Le:  assets/maps/eldoria_v2/tiles/*.png, assets/maps/eldoria_v2/props/*.png,
     casas existentes em assets/maps/eldoria/houses (so leitura) e
     data/eldoria_house_kit.json (ancora/colisao das casas, so leitura).
Grava (sobrescreve so estes):
  assets/maps/eldoria_v2/chunks/eldoria_v2_chunk_XX_YY.png  (9x9, chao sem agua)
  assets/maps/eldoria_v2/eldoria_v2_minimap.png
  data/eldoria_kit.json                                     (props, colisoes, npcs)
  tools/eldoria_v2/out/preview.png                          (conferencia)

Unidades: coordenadas de mundo (7200x5760). O chao e pintado na metade da
resolucao (3600x2880) e desenhado com escala 2, como a floresta v2.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "assets/maps/eldoria_v2"
TILES = KIT / "tiles"
PROPS = KIT / "props"
CHUNKS = KIT / "chunks"
OUT = Path(__file__).resolve().parent / "out"
DATA_PATH = ROOT / "data/eldoria_kit.json"
HOUSE_KIT = ROOT / "data/eldoria_house_kit.json"
RES = "res://"

WORLD = (7200, 5760)
GROUND_SCALE = 2
GROUND = (WORLD[0] // GROUND_SCALE, WORLD[1] // GROUND_SCALE)
CHUNK_GRID = (9, 9)
CHUNK_PX = (GROUND[0] // CHUNK_GRID[0], GROUND[1] // CHUNK_GRID[1])
TILE_WORLD = 256  # cada textura de 256 px cobre 256 px de mundo

# Muralha (bordas externas) e cidade
WALL_L, WALL_R, WALL_T, WALL_B = 560, 6640, 480, 5040
WALL_SCALE = 1.48
CX = 3600
PLAZA = (CX, 2750)
AVENUE_NS_HW = 160
AVENUE_EW_Y, AVENUE_EW_HW = 2750, 150
STREET_A_Y, STREET_C_Y, STREET_HW = 1700, 4000, 110
LANE_D_Y, LANE_D_HW = 4700, 70
LANDING = (2980, 5400, 4220, 5760)  # ilhota com dois portais (floresta e ruinas)
PORTAL = (3830, 5590)  # floresta (data/maps.json)
RUINS_PORTAL = (3370, 5590)
SPAWN = (CX, 3150)
FOREST_RETURN_SPAWN = (CX, 5450)

HOUSES = [
    # id da casa no house kit, posicao (ancora) no mundo
    ("master_house", (2100, 1100)),
    ("blacksmith_house", (5100, 1150)),
    ("healer_house", (2100, 3450)),
    ("merchant_house", (5100, 3450)),
    ("villager_house_a", (1150, 1300)),
    ("villager_house_b", (3000, 1300)),
    ("villager_house_a", (4200, 1300)),
    ("villager_house_b", (6050, 1300)),
    ("villager_house_b", (1150, 2350)),
    ("villager_house_a", (6050, 2350)),
    ("villager_house_a", (1150, 3550)),
    ("villager_house_b", (6050, 3550)),
    ("villager_house_b", (1150, 4500)),
    ("villager_house_a", (6050, 4500)),
]
NPCS = {
    "arion_mestre_classes": (2230, 1650),
    "bakka_ferreiro": (5330, 1640),
    "sarah_curandeira": (2310, 3960),
    "borin_mercador": (5330, 3960),
}

# Props soltos: nome, pe (x, y), altura alvo no mundo (ou largura com "w")
PROP_SIZE = {
    "tree_pink": 360, "tree_yellow": 360, "tree_blue": 360, "tree_white": 360,
    "bed_pink": 120, "bed_mixed": 120, "bush": 125, "bush_flower": 95,
    "bench": ("w", 190), "lamp": 190, "well": 210, "statue": 240,
    "barrel": 80, "crate": 72, "cart": ("w", 200), "stall": ("w", 270),
    "sign": 150, "pot": 95, "fountain": ("w", 600), "torch": 230,
}
# colisao no pe: (meia largura relativa a largura visivel, altura em px de mundo)
PROP_FOOT = {
    "tree": (0.16, 46), "bed": (0.42, 40), "bush": (0.38, 40), "bench": (0.45, 34),
    "lamp": (0.2, 26), "well": (0.42, 70), "statue": (0.4, 60), "barrel": (0.4, 34),
    "crate": (0.42, 34), "cart": (0.42, 46), "stall": (0.45, 60), "sign": (0.15, 22),
    "pot": (0.36, 30), "fountain": (0.44, 230), "torch": (0.32, 30),
}


def tile(name: str) -> np.ndarray:
    im = Image.open(TILES / f"{name}.png").convert("RGBA")
    size = TILE_WORLD // GROUND_SCALE
    return np.array(im.resize((size, size), Image.LANCZOS))[:, :, :3].astype(np.float32)


def tiled(name: str) -> np.ndarray:
    t = tile(name)
    reps = (math.ceil(GROUND[1] / t.shape[0]), math.ceil(GROUND[0] / t.shape[1]), 1)
    return np.tile(t, reps)[:GROUND[1], :GROUND[0]]


def value_noise(shape, cell, seed):
    rng = np.random.default_rng(seed)
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    grid = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8)).resize((gw * cell, gh * cell), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[:shape[0], :shape[1]] / 255.0


def fbm(shape, cell, seed, octaves=3):
    total, amp, norm = np.zeros(shape, np.float32), 1.0, 0.0
    for o in range(octaves):
        total += value_noise(shape, max(2, cell >> o), seed + o) * amp
        norm += amp
        amp *= 0.5
    return total / norm


GY, GX = np.mgrid[0:GROUND[1], 0:GROUND[0]].astype(np.float32)
WX, WY = GX * GROUND_SCALE, GY * GROUND_SCALE
NOISE = fbm(GROUND[::-1], 48, 11)


def rect_sd(x0, y0, x1, y1):
    """Distancia com sinal (negativa dentro) ate o retangulo, em px de mundo."""
    dx = np.maximum(x0 - WX, WX - x1)
    dy = np.maximum(y0 - WY, WY - y1)
    outside = np.hypot(np.maximum(dx, 0), np.maximum(dy, 0))
    return outside + np.minimum(np.maximum(dx, dy), 0)


def rounded_sd(x0, y0, x1, y1, r):
    return rect_sd(x0 + r, y0 + r, x1 - r, y1 - r) - r


def ellipse_sd(cx, cy, rx, ry):
    return (np.hypot((WX - cx) / rx, (WY - cy) / ry) - 1.0) * min(rx, ry)


def shape(sd, wobble=10.0):
    return sd + (NOISE - 0.5) * 2 * wobble < 0


def paint() -> tuple[np.ndarray, np.ndarray]:
    grass = np.where((fbm(GROUND[::-1], 64, 3) > 0.55)[..., None], tiled("grass_var"), tiled("grass"))
    img = grass.copy()
    dark = shape(np.minimum.reduce([
        rect_sd(WALL_L, WALL_T, WALL_R, WALL_T + 420),
        rect_sd(WALL_L, WALL_T, WALL_L + 360, WALL_B),
        rect_sd(WALL_R - 360, WALL_T, WALL_R, WALL_B),
    ]) + 60 * fbm(GROUND[::-1], 32, 5), 30)
    img[dark] = tiled("grass_dark")[dark]
    layers: list[tuple[np.ndarray, str, float]] = []

    def add(mask, name, rim=0.72):
        layers.append((mask, name, rim))

    # jardins floridos
    flowers = np.zeros(GX.shape, bool)
    for (x0, y0, x1, y1) in [(3220, 880, 3980, 1540), (2600, 3000, 3360, 3800), (3840, 3950, 4650, 4560),
                             (2560, 3950, 3360, 4560), (1500, 2050, 2700, 2520), (4500, 2050, 5700, 2520)]:
        flowers |= shape(rounded_sd(x0, y0, x1, y1, 160), 40)
    add(flowers, "grass_flowers", 1.0)
    # trilhas de terra ate as portas e caminho junto a muralha sul
    dirt = shape(rect_sd(WALL_L + 200, LANE_D_Y - LANE_D_HW, WALL_R - 200, LANE_D_Y + LANE_D_HW), 14)
    for name, (hx, hy) in HOUSES:
        if name.startswith("villager"):
            door_y = hy + 150
            target = STREET_A_Y if hy < 1600 else AVENUE_EW_Y if hy < 2600 else STREET_C_Y if hy < 4000 else LANE_D_Y
            y0, y1 = sorted((door_y, target))
            dirt |= shape(rect_sd(hx - 55, y0, hx + 55, y1), 8)
    add(dirt, "dirt")
    # quintal de cascalho da ferraria
    add(shape(rounded_sd(4600, 1480, 5650, 1600, 50), 12), "gravel")
    # ruas de pedra clara
    streets = shape(rect_sd(WALL_L + 260, STREET_A_Y - STREET_HW, WALL_R - 260, STREET_A_Y + STREET_HW), 6)
    streets |= shape(rect_sd(WALL_L + 260, STREET_C_Y - STREET_HW, WALL_R - 260, STREET_C_Y + STREET_HW), 6)
    add(streets, "stone_light")
    # pedra com musgo na frente das casas grandes
    moss = np.zeros(GX.shape, bool)
    for name, (hx, hy) in HOUSES[:4]:
        moss |= shape(rounded_sd(hx - 300, hy + 330, hx + 300, hy + 520, 60), 10)
    add(moss, "stone_moss")
    # feira de tijolos
    add(shape(rounded_sd(3880, 3230, 4700, 3880, 90), 10), "brick")
    # avenidas de paralelepipedo
    ave = shape(rect_sd(CX - AVENUE_NS_HW, STREET_A_Y, CX + AVENUE_NS_HW, WALL_B), 5)
    ave |= shape(rect_sd(WALL_L + 160, AVENUE_EW_Y - AVENUE_EW_HW, WALL_R - 160, AVENUE_EW_Y + AVENUE_EW_HW), 5)
    add(ave, "cobble")
    # praca
    add(shape(rounded_sd(PLAZA[0] - 620, PLAZA[1] - 460, PLAZA[0] + 620, PLAZA[1] + 480, 260), 4), "plaza")
    # ilhota do portal
    add(shape(rounded_sd(*LANDING, 140) - 0, 18), "sand")
    add(shape(rounded_sd(CX - 480, 5470, CX + 480, 5720, 120), 6), "plaza")

    for mask, name, rim in layers:
        tex = tiled(name)
        img[mask] = tex[mask]
        if rim < 1.0:
            # contorno de 1 px (meio-fio) por dentro da borda
            edge = mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))
            img[edge] *= rim
    # agua: fora da muralha, menos uma faixa de grama/rocha no pe dela e a ilhota
    city = rect_sd(WALL_L - 40, WALL_T - 40, WALL_R + 40, WALL_B + 30)
    land = shape(city, 26) | shape(rounded_sd(*LANDING, 140), 18) | shape(rect_sd(CX - 110, WALL_B, CX + 110, LANDING[1] + 40), 2)
    alpha = np.where(land, 255, 0).astype(np.uint8)
    shore = land & ~(np.roll(land, 2, 0) & np.roll(land, -2, 0) & np.roll(land, 2, 1) & np.roll(land, -2, 1))
    img[shore] = img[shore] * 0.55 + np.array([196, 176, 120], np.float32) * 0.45
    return np.clip(img, 0, 255).astype(np.uint8), alpha


def load_prop(name: str) -> Image.Image:
    return Image.open(PROPS / f"{name}.png").convert("RGBA")


def prop_entry(name: str, foot: tuple[float, float], scale: float, collision=None, ground=False, frames=None, flip=False) -> dict:
    im = load_prop(frames[0] if frames else name)
    entry = {
        "name": name,
        "texture": f"{RES}assets/maps/eldoria_v2/props/{(frames[0] if frames else name)}.png",
        "pos": [round(foot[0], 1), round(foot[1], 1)],
        "offset": [-im.width / 2, -im.height],
        "scale": round(scale, 4),
        "flip_h": flip,
    }
    if frames:
        entry["frames"] = [f"{RES}assets/maps/eldoria_v2/props/{f}.png" for f in frames]
        entry["fps"] = 6
    if collision is not None:
        entry["collisions"] = collision
    if ground:
        entry["layer"] = "ground"  # desenhado junto do chao, sempre por baixo de quem anda
    return entry


def deco(name: str, foot, flip=False) -> dict:
    animated = name in ("fountain", "torch")  # props com 4 quadros (_0.._3)
    base = f"{name}_0" if animated else name
    im = load_prop(base)
    size = PROP_SIZE[name]
    scale = size[1] / im.width if isinstance(size, tuple) else size / im.height
    kind = next(k for k in PROP_FOOT if name.startswith(k))
    hw_ratio, h = PROP_FOOT[kind]
    hw = im.width * scale * hw_ratio
    col = [[-hw, -h, hw * 2, h]]
    frames = [f"{name}_{i}" for i in range(4)] if animated else None
    return prop_entry(name, foot, scale, col, frames=frames, flip=flip)


def gate_opening(im: Image.Image) -> tuple[float, float]:
    """Vao livre do portao (fracao da largura), medido nas linhas de baixo."""
    a = np.array(im)[:, :, 3] > 40
    band = a[int(im.height * 0.72):int(im.height * 0.95)]
    free = ~band.any(axis=0)
    mid = im.width // 2
    left = mid
    while left > 0 and free[left - 1]:
        left -= 1
    right = mid
    while right < im.width - 1 and free[right + 1]:
        right += 1
    return left / im.width, (right + 1) / im.width


def walls() -> tuple[list[dict], list[list[float]]]:
    props, solids = [], []
    s = WALL_SCALE
    wh, whb, wv = load_prop("wall_h"), load_prop("wall_h_banner"), load_prop("wall_v")
    cul, cll = load_prop("corner_ul"), load_prop("corner_ll")
    gate, tower, bridge = load_prop("gate"), load_prop("tower"), load_prop("bridge_v")
    seg_w, seg_h = wh.width * s, wh.height * s
    corner_w, corner_h = cul.width * s, cul.height * s
    vw, vh = wv.width * s, wv.height * s

    def row(y_base, x0, x1, banner_every=3):
        n = max(1, math.ceil((x1 - x0) / (seg_w * 0.94)))
        step = (x1 - x0) / n
        for i in range(n):
            name = "wall_h_banner" if i % banner_every == 1 else "wall_h"
            props.append(prop_entry(name, (x0 + step * (i + 0.5), y_base), s))

    def column(x_center, y0, y1, flip=False):
        n = max(1, math.ceil((y1 - y0) / (vh * 0.95)))
        step = (y1 - y0) / n
        for i in range(n):
            name = "wall_v_alt" if i % 2 else "wall_v"
            props.append(prop_entry(name, (x_center, y0 + step * (i + 1)), s, flip=flip))

    top_base = WALL_T + seg_h
    row(top_base, WALL_L + corner_w * 0.9, WALL_R - corner_w * 0.9)
    gate_w, gate_h = gate.width * s, gate.height * s
    row(WALL_B, WALL_L + corner_w * 0.9, CX - gate_w * 0.48)
    row(WALL_B, CX + gate_w * 0.48, WALL_R - corner_w * 0.9)
    column(WALL_L + vw / 2, WALL_T + corner_h * 0.9, WALL_B - corner_h * 0.9)
    column(WALL_R - vw / 2, WALL_T + corner_h * 0.9, WALL_B - corner_h * 0.9, flip=False)
    for name, x, y in [("corner_ul", WALL_L + corner_w / 2, WALL_T + corner_h), ("corner_ur", WALL_R - corner_w / 2, WALL_T + corner_h),
                       ("corner_ll", WALL_L + corner_w / 2, WALL_B), ("corner_lr", WALL_R - corner_w / 2, WALL_B)]:
        props.append(prop_entry(name, (x, y), s))
    tw, th = tower.width * s, tower.height * s
    for x, y in [(WALL_L + vw / 2, 2600), (WALL_R - vw / 2, 2600), (2600, top_base + 50), (4600, top_base + 50)]:
        props.append(prop_entry("tower", (x, y), s, [[-tw * 0.42, -th * 0.55, tw * 0.84, th * 0.55]]))
    props.append(prop_entry("gate", (CX, WALL_B + 6), s))
    bw, bh = bridge.width * s, bridge.height * s
    props.append(prop_entry("bridge_v", (CX, WALL_B + bh - 10), s, ground=True))
    # colisoes da muralha (corpo inteiro: e borda do mapa, nada passa por tras)
    solids += [
        [WALL_L, WALL_T, WALL_R - WALL_L, seg_h],
        [WALL_L, WALL_T, vw, WALL_B - WALL_T],
        [WALL_R - vw, WALL_T, vw, WALL_B - WALL_T],
    ]
    g0, g1 = gate_opening(gate)
    gap_l, gap_r = CX - gate_w / 2 + gate_w * g0, CX - gate_w / 2 + gate_w * g1
    solids += [
        [WALL_L, WALL_B - seg_h, gap_l - WALL_L, seg_h],
        [gap_r, WALL_B - seg_h, WALL_R - gap_r, seg_h],
    ]
    # agua ao sul: so a ponte e a ilhota sao passaveis
    walk_hw = bw * 0.3
    solids += [
        [0, WALL_B, CX - walk_hw, LANDING[1] + 30 - WALL_B],
        [CX + walk_hw, WALL_B, WORLD[0] - CX - walk_hw, LANDING[1] + 30 - WALL_B],
        [0, LANDING[1] + 30, LANDING[0] + 30, WORLD[1] - LANDING[1]],
        [LANDING[2] - 30, LANDING[1] + 30, WORLD[0] - LANDING[2] + 30, WORLD[1] - LANDING[1]],
    ]
    return props, solids


def houses() -> list[dict]:
    kit = {h["id"]: h for h in json.loads(HOUSE_KIT.read_text(encoding="utf-8"))["houses"]}
    out = []
    for i, (hid, pos) in enumerate(HOUSES):
        h = kit[hid]
        s = float(h["visual_scale"])
        ax, ay = h["anchor"]
        cols = [[(r["x"] - ax) * s, (r["y"] - ay) * s, r["w"] * s, r["h"] * s] for r in h["collision_rects"] if r["w"] > 0 and r["h"] > 0]
        out.append({
            "name": f"{hid}_{i:02d}",
            "texture": h["texture_path"],
            "pos": list(pos),
            "offset": [-ax, -ay],
            "scale": s,
            "flip_h": False,
            "collisions": cols,
        })
    return out


def decorations() -> list[dict]:
    d = [deco("fountain", (PLAZA[0], PLAZA[1] + 170))]
    for dx in (-470, 470):
        for dy in (-330, 360):
            d.append(deco("torch", (PLAZA[0] + dx, PLAZA[1] + dy)))
    for dx in (-360, 360):
        d.append(deco("bench", (PLAZA[0] + dx, PLAZA[1] - 360)))
        d.append(deco("bench", (PLAZA[0] + dx, PLAZA[1] + 440)))
    for dx, name in ((-560, "bed_pink"), (560, "bed_mixed")):
        d.append(deco(name, (PLAZA[0] + dx, PLAZA[1] - 90)))
        d.append(deco(name, (PLAZA[0] + dx, PLAZA[1] + 200)))
    # lampioes nas avenidas
    for y in (2100, 3500, 4300):
        d += [deco("torch", (CX - 230, y)), deco("torch", (CX + 230, y))]
    for x in (1500, 2600, 4600, 5700):
        d += [deco("torch", (x, AVENUE_EW_Y - 210))]
    # jardim real ao norte com a estatua
    d.append(deco("statue", (CX, 1330)))
    d += [deco("tree_white", (3330, 1100)), deco("tree_white", (3870, 1100)), deco("bed_mixed", (3420, 1450)), deco("bed_mixed", (3780, 1450))]
    d += [deco("pot", (3460, 1580)), deco("pot", (3740, 1580))]
    # feira
    for x in (4060, 4330, 4600):
        d.append(deco("stall", (x, 3500)))
    d += [deco("cart", (4180, 3830)), deco("barrel", (4430, 3800)), deco("barrel", (4500, 3830)),
          deco("crate", (4600, 3790)), deco("crate", (3960, 3790)), deco("sign", (3880, 3300))]
    # ferraria
    d += [deco("barrel", (5720, 1520)), deco("barrel", (5790, 1560)), deco("crate", (4640, 1530)), deco("crate", (4710, 1575))]
    # curandeira: jardim e poco
    d += [deco("well", (2980, 3500)), deco("bed_pink", (2780, 3150)), deco("bed_mixed", (3200, 3150)),
          deco("pot", (1560, 3760)), deco("pot", (2640, 3760)), deco("bush_flower", (1500, 3300))]
    # arvores floridas
    trees = [
        ("tree_pink", 1650, 2450), ("tree_yellow", 2650, 2450), ("tree_blue", 4550, 2450), ("tree_pink", 5550, 2450),
        ("tree_blue", 2700, 3820), ("tree_yellow", 3300, 3700), ("tree_white", 3950, 4520), ("tree_pink", 4550, 4520),
        ("tree_yellow", 2650, 4520), ("tree_white", 3250, 4520), ("tree_blue", 1650, 4300), ("tree_pink", 5550, 4300),
        ("tree_white", 900, 1850), ("tree_yellow", 6300, 1850), ("tree_pink", 900, 3200), ("tree_blue", 6300, 3200),
        ("tree_yellow", 1480, 1000), ("tree_pink", 4950, 2150), ("tree_white", 2250, 2200),
    ]
    for name, x, y in trees:
        d.append(deco(name, (x, y), flip=(x * 7 + y) % 2 == 1))
    bushes = [(1000, 900), (6200, 900), (2400, 900), (4800, 900), (900, 4100), (6300, 4100), (2000, 4600), (5200, 4600)]
    for i, (x, y) in enumerate(bushes):
        d.append(deco("bush" if i % 2 else "bush_flower", (x, y)))
    d += [deco("sign", (CX + 260, WALL_B - 260)), deco("sign", (CX, LANDING[3] - 70))]
    return d


def main() -> None:
    CHUNKS.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    rgb, alpha = paint()
    ground = np.dstack([rgb, alpha])
    for gy in range(CHUNK_GRID[1]):
        for gx in range(CHUNK_GRID[0]):
            part = ground[gy * CHUNK_PX[1]:(gy + 1) * CHUNK_PX[1], gx * CHUNK_PX[0]:(gx + 1) * CHUNK_PX[0]]
            Image.fromarray(part, "RGBA").save(CHUNKS / f"eldoria_v2_chunk_{gx:02d}_{gy:02d}.png")
    wall_props, solids = walls()
    props = wall_props + houses() + decorations()
    data = {
        "version": 1,
        "world_size": list(WORLD),
        "ground_scale": GROUND_SCALE,
        "chunk_grid": list(CHUNK_GRID),
        "chunk_px": list(CHUNK_PX),
        "chunks_dir": f"{RES}assets/maps/eldoria_v2/chunks",
        "water_frames": [f"{RES}assets/maps/eldoria_v2/tiles/water_{i}.png" for i in range(4)],
        "minimap": f"{RES}assets/maps/eldoria_v2/eldoria_v2_minimap.png",
        "spawn": list(SPAWN),
        "portal": list(PORTAL),
        "ruins_portal": list(RUINS_PORTAL),
        "forest_return_spawn": list(FOREST_RETURN_SPAWN),
        "npcs": {k: list(v) for k, v in NPCS.items()},
        "solids": [[round(v, 1) for v in r] for r in solids],
        "props": props,
    }
    DATA_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    # preview do mundo inteiro (1/4) com agua, props e colisoes
    q = 4
    water = Image.open(TILES / "water_0.png").convert("RGBA").resize((TILE_WORLD // q, TILE_WORLD // q))
    full = Image.new("RGBA", (WORLD[0] // q, WORLD[1] // q))
    for y in range(0, full.height, water.height):
        for x in range(0, full.width, water.width):
            full.paste(water, (x, y))
    g = Image.fromarray(ground, "RGBA").resize(full.size, Image.LANCZOS)
    full.alpha_composite(g)
    order = sorted(props, key=lambda p: (p.get("layer") != "ground", p["pos"][1]))
    cache = {}
    for p in order:
        path = ROOT / p["texture"].replace(RES, "")
        if path not in cache:
            cache[path] = Image.open(path).convert("RGBA")
        im = cache[path]
        if p.get("flip_h"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        sc = p["scale"] / q
        w, h = max(1, round(im.width * sc)), max(1, round(im.height * sc))
        x = round(p["pos"][0] / q + p["offset"][0] * sc)
        y = round(p["pos"][1] / q + p["offset"][1] * sc)
        full.alpha_composite(im.resize((w, h), Image.LANCZOS), (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
    minimap = full.resize((1800, 1440), Image.LANCZOS)
    minimap.save(KIT / "eldoria_v2_minimap.png")
    dbg = full.copy()
    from PIL import ImageDraw
    dr = ImageDraw.Draw(dbg)
    for r in solids:
        dr.rectangle([r[0] / q, r[1] / q, (r[0] + r[2]) / q, (r[1] + r[3]) / q], outline=(255, 0, 0, 255))
    for p in props:
        for c in p.get("collisions", []):
            x0, y0 = p["pos"][0] + c[0], p["pos"][1] + c[1]
            dr.rectangle([x0 / q, y0 / q, (x0 + c[2]) / q, (y0 + c[3]) / q], outline=(255, 255, 0, 255))
    for name, (x, y) in list(NPCS.items()) + [("spawn", SPAWN), ("portal", PORTAL), ("volta", FOREST_RETURN_SPAWN)]:
        dr.ellipse([x / q - 6, y / q - 6, x / q + 6, y / q + 6], fill=(0, 255, 255, 255))
    full.save(OUT / "preview.png")
    dbg.save(OUT / "preview_colisao.png")
    print("ok props", len(props), "solids", len(solids))


if __name__ == "__main__":
    main()
