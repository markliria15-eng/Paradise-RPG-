"""Valdoria v2 (city_valdoria): cidade portuaria montada com os 9 predios de tools/valdoria_v2/fonte.

Le:  tools/valdoria_v2/fonte/valdoria_*.png  (predios 1254x1254, fundo transparente)
     assets/maps/eldoria_v2/tiles e props    (pisos, agua, muralha e enfeites reaproveitados)
     tools/cave_v2/fonte/tiles/12.png        (tabuas do cais)
Grava (sobrescreve so estes):
  assets/maps/valdoria_v2/chunks/valdoria_v2_chunk_XX_YY.png   (8x9 chunks, chao; mar transparente)
  assets/maps/valdoria_v2/buildings/<predio>.png               (predio recortado no contorno)
  assets/maps/valdoria_v2/valdoria_v2_walkable.png             (mascara, celula 16)
  assets/maps/valdoria_v2/valdoria_v2_minimap.png
  data/valdoria_kit.json
  tools/valdoria_v2/out/preview.png, preview_colisao.png

Layout (mundo 6400x5760): muralha ao norte/oeste/leste, porto ao sul.
  linha 1: Casa A | Templo (Liora) | Casa B
  linha 2: Forja rara (Durnan) | praca com fonte | Salao do mercado (Varek)
  linha 3: Pets (Mira) | Casa C | avenida | feira | Estabulos (Torin)
  porto: calcadao de tabuas, pier central e pier leste ate o farol.
Portal das Ruinas na rua oeste, logo dentro da muralha.

uso: python tools/valdoria_v2/generate_valdoria_v2.py   (raiz do projeto; Pillow, numpy, scipy)
"""
from __future__ import annotations

import importlib.util
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SRC = HERE / "fonte"
KIT = ROOT / "assets/maps/valdoria_v2"
RES = "res://"
DATA_PATH = ROOT / "data/valdoria_kit.json"

_spec = importlib.util.spec_from_file_location("eld", ROOT / "tools/eldoria_v2/generate_eldoria_v2.py")
eld = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(eld)  # so constantes e funcoes (main() nao roda)

WORLD = (6400, 5760)
GS = 2
GROUND = (WORLD[0] // GS, WORLD[1] // GS)
GRID = (8, 9)
CHUNK = (GROUND[0] // GRID[0], GROUND[1] // GRID[1])
CELL = 16
WALL_L, WALL_R, WALL_T = 300, 6100, 300
SHORE_Y = 4450                       # inicio do mar (com ondulacao)
BUILD_SCALE = 0.84                   # mesma escala das casas de Eldoria
ROW_Y = (1650, 2950, 4250)           # base (pes) dos predios de cada linha
CX = 3200
PLAZA = (CX, 2560, 430)
AVENUE_HW = 150
STREETS_Y = ((ROW_Y[0] + ROW_Y[1] - 966) / 2 + 40, (ROW_Y[1] + ROW_Y[2] - 966) / 2 + 40)
BOARDWALK = (650, SHORE_Y - 40, 5750, SHORE_Y + 150)
PIER_C = (CX, SHORE_Y, 130, 5320)
PIER_E = (5300, SHORE_Y, 110, 4980)
LIGHT_PLAT = (5300, 5200, 260)
PORTAL = (720, 1840)
SPAWN = (930, 1840)

BUILDINGS = [  # (arquivo, x do centro, linha) ; npc na porta
    ("valdoria_house_a", 1300, 0), ("valdoria_temple", CX, 0), ("valdoria_house_b", 5100, 0),
    ("valdoria_rare_forge", 1300, 1), ("valdoria_market_hall", 5100, 1),
    ("valdoria_pet_shop", 1300, 2), ("valdoria_house_c", 2330, 2), ("valdoria_stables", 5100, 2),
]
LIGHTHOUSE = ("valdoria_lighthouse", LIGHT_PLAT[0], LIGHT_PLAT[1] + 90)
NPC_AT = {"valdoria_temple": "Liora, Curandeira", "valdoria_market_hall": "Varek, Mercador",
          "valdoria_rare_forge": "Durnan, Forja Rara", "valdoria_pet_shop": "Mira, Vendedora de Pets",
          "valdoria_stables": "Torin, Mestre de Montarias"}

rng = random.Random(77)
YY, XX = np.mgrid[0:GROUND[1], 0:GROUND[0]].astype(np.float32) * GS  # coordenadas de mundo


def tiled(name, src=None):
    path = src or (ROOT / f"assets/maps/eldoria_v2/tiles/{name}.png")
    t = np.asarray(Image.open(path).convert("RGB").resize((256 // GS, 256 // GS), Image.LANCZOS), np.float32)
    reps = (GROUND[1] // t.shape[0] + 1, GROUND[0] // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:GROUND[1], :GROUND[0]]


def noise(cell, seed, amp=1.0):
    g = np.random.default_rng(seed).random((GROUND[1] // cell + 3, GROUND[0] // cell + 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(((GROUND[0] // cell + 3) * cell, (GROUND[1] // cell + 3) * cell), Image.BICUBIC)
    return (np.asarray(img, np.float32)[:GROUND[1], :GROUND[0]] / 255 - 0.5) * 2 * amp


def soft(mask, r=3):
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def mix(base, layer, a):
    return base * (1 - a[..., None]) + layer * a[..., None]


def rect(x0, y0, x1, y1):
    return (XX >= x0) & (XX < x1) & (YY >= y0) & (YY < y1)


def building_info(name):
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    box = im.getbbox()
    im = im.crop(box)
    (KIT / "buildings").mkdir(parents=True, exist_ok=True)
    im.save(KIT / "buildings" / f"{name}.png", optimize=True)
    a = np.asarray(im)[..., 3] > 40
    return im.width, im.height, a


def building_entry(name, cx, foot_y, narrow=False):
    w, h, a = building_info(name)
    s = BUILD_SCALE
    # colisao: faixa de baixo do predio (fachada + base), recortada pelo contorno real
    band_top = int(h * (0.62 if narrow else 0.56))
    cols = []
    for y0 in range(band_top, h - 6, 24):
        row = a[y0:min(y0 + 24, h - 6)].any(axis=0)
        xs = np.nonzero(row)[0]
        if xs.size:
            x0, x1 = xs.min() + w * 0.04, xs.max() - w * 0.04
            cols.append([round((x0 - w / 2) * s, 1), round((y0 - h) * s, 1), round((x1 - x0) * s, 1), round(min(24, h - 6 - y0) * s, 1)])
    return {"name": name, "texture": f"{RES}assets/maps/valdoria_v2/buildings/{name}.png", "pos": [cx, foot_y],
            "offset": [-w / 2, -h], "scale": s, "flip_h": False, "collisions": cols}, (w * s, h * s)


def paint(building_boxes):
    grass = mix(tiled("grass"), tiled("grass_var"), np.clip(noise(90, 1) + 0.5, 0, 1))
    img = grass.copy()
    inside = rect(WALL_L, WALL_T, WALL_R, SHORE_Y + 60)
    cob = mix(tiled("cobble"), tiled("stone_moss"), np.clip(noise(70, 2) * 1.2, 0, 0.6))
    img = mix(img, cob, inside.astype(np.float32))
    # jardins (grama com flores) nos quarteiroes livres
    gardens = np.zeros(XX.shape, bool)
    for (x0, y0, x1, y1) in [(1900, 700, 2600, 1600), (3800, 700, 4500, 1600),
                             (3750, 2000, 4500, 2900), (3500, 3350, 4450, 4150), (500, 3380, 760, 4150)]:
        gardens |= rect(x0, y0, x1, y1)
    gardens &= (noise(40, 3) > -0.55)
    img = mix(img, tiled("grass_flowers"), soft(gardens, 6) * 0.95)
    # patio industrial: cascalho com manchas de terra
    yard = rect(1880, 2000, 2700, 2960)
    img = mix(img, mix(tiled("gravel"), tiled("dirt"), np.clip(noise(50, 5) + 0.3, 0, 0.6)), soft(yard, 4))
    # feira: tijolos
    img = mix(img, tiled("brick"), soft(rect(3560, 3420, 4400, 4120), 3) * 0.55)
    # ruas de pedra clara
    streets = np.zeros(XX.shape, bool)
    for sy in STREETS_Y:
        streets |= rect(WALL_L + 120, sy - 115, WALL_R - 120, sy + 115)
    streets |= rect(CX - AVENUE_HW, 700, CX + AVENUE_HW, SHORE_Y)
    streets |= rect(560, 1700, 900, 1980)
    img = mix(img, tiled("stone_light"), soft(streets, 2))
    # praca circular
    pr = np.hypot(XX - PLAZA[0], YY - PLAZA[1])
    img = mix(img, tiled("plaza"), soft(pr < PLAZA[2], 3))
    ring = (pr > PLAZA[2] - 22) & (pr < PLAZA[2])
    img = mix(img, tiled("cobble") * 0.75, soft(ring, 1))
    # areia na beira do mar
    shore = SHORE_Y + noise(60, 4, 26)
    sand = (YY > shore - 150) & (YY < shore)
    img = mix(img, tiled("sand"), soft(sand & ~rect(CX - AVENUE_HW, 0, CX + AVENUE_HW, 9999), 4))
    water = YY >= shore
    # cais de tabuas (por cima da agua)
    pl = tiled(None, ROOT / "tools/cave_v2/fonte/tiles/12.png").mean(axis=2)
    pl = np.clip((pl - pl.mean()) / (pl.std() + 1e-3) * 0.22 + 1.0, 0.45, 1.4)
    planks = np.array([152, 104, 62], np.float32) * pl[..., None]  # tabuas escuras da caverna tingidas de madeira
    deck = rect(*BOARDWALK) | rect(PIER_C[0] - PIER_C[2], PIER_C[1] - 60, PIER_C[0] + PIER_C[2], PIER_C[3]) \
        | rect(PIER_E[0] - PIER_E[2], PIER_E[1] - 60, PIER_E[0] + PIER_E[2], PIER_E[3])
    plat = np.hypot(XX - LIGHT_PLAT[0], YY - LIGHT_PLAT[1]) < LIGHT_PLAT[2]
    img = mix(img, planks, deck.astype(np.float32))
    img = mix(img, tiled("stone_light"), plat.astype(np.float32))
    land = ~water | deck | plat
    # sombra das bordas do cais e da costa sobre a agua
    edge = soft(land, 5)
    alpha = np.where(land, 255, np.clip(edge * 400 - 40, 0, 150)).astype(np.uint8)
    img = np.where(land[..., None], img, img * 0 + np.array([10, 40, 60], np.float32))
    # sombra suave aos pes dos predios
    shadow = np.zeros(XX.shape, bool)
    for (cx, fy, bw) in building_boxes:
        shadow |= rect(cx - bw * 0.46, fy - 40, cx + bw * 0.46, fy + 26)
    img *= (1 - soft(shadow, 10) * 0.28)[..., None]
    return np.clip(img, 0, 255).astype(np.uint8), alpha, land, deck | plat


def walls():
    props, solids = [], []
    s = eld.WALL_SCALE
    wh, wv, cul = eld.load_prop("wall_h"), eld.load_prop("wall_v"), eld.load_prop("corner_ul")
    tower = eld.load_prop("tower")
    seg_w, seg_h = wh.width * s, wh.height * s
    corner_w, corner_h = cul.width * s, cul.height * s
    vw, vh = wv.width * s, wv.height * s
    end_y = SHORE_Y - 20
    top_base = WALL_T + seg_h
    n = max(1, math.ceil((WALL_R - WALL_L - corner_w * 1.8) / (seg_w * 0.94)))
    step = (WALL_R - WALL_L - corner_w * 1.8) / n
    for i in range(n):
        props.append(eld.prop_entry("wall_h_banner" if i % 3 == 1 else "wall_h", (WALL_L + corner_w * 0.9 + step * (i + 0.5), top_base), s))
    for xc in (WALL_L + vw / 2, WALL_R - vw / 2):
        m = max(1, math.ceil((end_y - WALL_T - corner_h * 0.9) / (vh * 0.95)))
        st = (end_y - WALL_T - corner_h * 0.9) / m
        for i in range(m):
            props.append(eld.prop_entry("wall_v_alt" if i % 2 else "wall_v", (xc, WALL_T + corner_h * 0.9 + st * (i + 1)), s))
    props.append(eld.prop_entry("corner_ul", (WALL_L + corner_w / 2, WALL_T + corner_h), s))
    props.append(eld.prop_entry("corner_ur", (WALL_R - corner_w / 2, WALL_T + corner_h), s))
    tw, th = tower.width * s, tower.height * s
    for x, y in [(WALL_L + vw / 2, end_y + 40), (WALL_R - vw / 2, end_y + 40), (2150, top_base + 50), (4250, top_base + 50)]:
        props.append(eld.prop_entry("tower", (x, y), s, [[-tw * 0.42, -th * 0.55, tw * 0.84, th * 0.55]]))
    solids += [[WALL_L, WALL_T, WALL_R - WALL_L, seg_h], [WALL_L, WALL_T, vw, end_y - WALL_T + 40],
               [WALL_R - vw, WALL_T, vw, end_y - WALL_T + 40]]
    return props, solids, (vw, seg_h)


# Pacote "valdoria-industrial-harbor" (tools/valdoria_v2/fonte_industrial): tamanho no mundo
# (("w"|"h"), px) e colisao (fracao da largura, altura em px a partir dos pes; None = sem colisao).
IND_SIZE = {
    "anchor": ("h", 130, 0.5, 30), "anvil": ("h", 110, 0.7, 34), "banner_flagpole": ("h", 330, 0.35, 26),
    "barrels": ("w", 180, 0.85, 60), "cargo_scale": ("h", 150, 0.85, 50), "carriage_luxury_left": ("w", 540, 0.9, 70),
    "carriage_luxury_right": ("w", 540, 0.9, 70), "carriage_luxury_parked": ("w", 320, 0.85, 70),
    "cart_worker_left": ("w", 380, 0.9, 60), "cart_worker_right": ("w", 380, 0.9, 60), "chimney": ("h", 430, 0.7, 60),
    "coal": ("w", 120, 0.8, 30), "cogwheel": ("h", 270, 0.85, 70), "crane": ("h", 580, 0.35, 70),
    "crates": ("w", 190, 0.85, 70), "firewood": ("w", 140, 0.85, 34), "fishing_boat": ("w", 520, None, 0),
    "furnace": ("h", 400, 0.86, 120), "gas_lamp": ("h", 240, 0.3, 22), "grain_sacks": ("w", 150, 0.85, 44),
    "hand_cart": ("w", 180, 0.85, 40), "mine_cart": ("w", 230, 0.85, 50), "mooring_bollard": ("h", 80, 0.7, 30),
    "notice_board": ("h", 210, 0.8, 30), "rail_curved": ("w", 230, None, 0), "rope_coil": ("w", 70, None, 0),
    "rowboat": ("w", 260, None, 0), "ship_docked": ("w", 1300, None, 0), "wagon_cargo": ("w", 560, 0.9, 70),
    "water_wheel": ("h", 320, 0.8, 60), "workbench": ("h", 200, 0.85, 50),
}
IND_SRC = HERE / "fonte_industrial"
_ind_done = set()


def ind(name, foot, ground=False, col_dx=0.0):
    """Prop do pacote industrial, gravado em assets/maps/valdoria_v2/props no tamanho do mundo (escala 1)."""
    axis, size, cw, ch = IND_SIZE[name]
    out = KIT / "props" / f"{name}.png"
    if name not in _ind_done:
        im = Image.open(IND_SRC / f"valdoria_{name}.png").convert("RGBA")
        im = im.crop(im.getbbox())
        k = size / (im.width if axis == "w" else im.height)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out, optimize=True)
        _ind_done.add(name)
    w, h = Image.open(out).size
    e = {"name": name, "texture": f"{RES}assets/maps/valdoria_v2/props/{name}.png", "pos": [round(foot[0], 1), round(foot[1], 1)],
         "offset": [-w / 2, -h], "scale": 1.0, "flip_h": False}
    if cw:
        e["collisions"] = [[round(-w * cw / 2 + w * col_dx, 1), -ch, round(w * cw, 1), ch]]
    if ground:
        e["layer"] = "ground"
    return e


def decorations():
    d = []
    D = eld.deco
    d.append(D("fountain", (PLAZA[0], PLAZA[1] + 170)))
    for dx, dy in ((-330, -250), (330, -250), (-330, 330), (330, 330)):
        d.append(D("bench", (PLAZA[0] + dx, PLAZA[1] + dy), flip=dx > 0))
    for dx in (-520, 520):
        d.append(D("statue", (PLAZA[0] + dx, PLAZA[1] + 60)))
        d.append(D("tree_blue" if dx < 0 else "tree_white", (PLAZA[0] + dx, PLAZA[1] - 330)))
    # postes na avenida e nas ruas
    for y in range(900, SHORE_Y - 100, 430):
        if abs(y - PLAZA[1]) < PLAZA[2] + 80:
            continue
        for x in (CX - AVENUE_HW - 40, CX + AVENUE_HW + 40):
            d.append(ind("gas_lamp", (x, y)))
    for sy in STREETS_Y:
        for x in range(800, 5700, 620):
            if abs(x - CX) < 500:
                continue
            d.append(ind("gas_lamp", (x, sy - 140)))
    # jardins
    for (x0, y0, x1, y1, n) in [(1950, 760, 2550, 1500, 5), (3850, 760, 4450, 1500, 5),
                                (3800, 2100, 4450, 2800, 4)]:
        for _ in range(n):
            nm = rng.choice(["tree_blue", "tree_white", "bush", "bush_flower", "bed_mixed", "tree_white"])
            d.append(D(nm, (rng.uniform(x0, x1), rng.uniform(y0 + 120, y1))))
    # feira
    for i, x in enumerate((3680, 3960, 4240)):
        d.append(D("stall", (x, 3640)))
    d.append(D("cart", (3720, 4020)))
    for p in ((4300, 3980), (4360, 4040), (3600, 3980)):
        d.append(D("crate", p))
    for p in ((4120, 4060), (4180, 4080)):
        d.append(D("barrel", p))
    # cais
    d.append(ind("gas_lamp", (CX - PIER_C[2] + 20, 5250)))
    d.append(ind("gas_lamp", (CX + PIER_C[2] - 20, 5250)))
    # patio industrial ao lado da Forja Rara (antigo jardim da linha 2)
    d += [ind("furnace", (2250, 2420)), ind("chimney", (2560, 2330)), ind("chimney", (1960, 2300)),
          ind("anvil", (2050, 2620)), ind("workbench", (2470, 2640)), ind("coal", (2620, 2520)),
          ind("firewood", (1980, 2780)), ind("cogwheel", (2600, 2860)), ind("mine_cart", (2250, 2870)),
          ind("rail_curved", (2000, 2930), ground=True), ind("hand_cart", (2420, 2900))]
    # carruagens e charretes nas ruas
    d += [ind("carriage_luxury_parked", (3800, 1770)), ind("carriage_luxury_parked", (2600, 1770)),
          ind("carriage_luxury_left", (4400, 1960)), ind("carriage_luxury_right", (2000, 3260)),
          ind("cart_worker_left", (4400, 3270)), ind("cart_worker_right", (1700, 1960)),
          ind("wagon_cargo", (4700, 4380)), ind("hand_cart", (3480, 4100))]
    # bandeiras e mural
    for x, y in ((CX - 470, PLAZA[1] - 430), (CX + 470, PLAZA[1] - 430), (CX - 200, 4380), (CX + 200, 4380)):
        d.append(ind("banner_flagpole", (x, y)))
    d.append(ind("notice_board", (CX + 330, PLAZA[1] + 520)))
    # porto: navio atracado a oeste do pier, pesqueiro a leste, botes junto ao calcadao
    d += [ind("ship_docked", (2420, 5540)), ind("fishing_boat", (3700, 5080)), ind("rowboat", (1250, 4760)),
          ind("rowboat", (4500, 4760)), ind("rowboat", (5000, 4790))]
    d += [ind("crane", (2480, 4590), col_dx=-0.3), ind("cargo_scale", (2700, 4560)), ind("anchor", (3460, 4560)),
          ind("water_wheel", (5660, 4600))]
    for x in (1100, 1700, 2250, 3360, 3600, 4200, 4800, 5400):
        d.append(ind("mooring_bollard", (x, BOARDWALK[3] - 6)))
    for x in (1400, 3900, 5150):
        d.append(ind("rope_coil", (x, BOARDWALK[3] - 30)))
    for x, nm in ((800, "crates"), (1550, "grain_sacks"), (2050, "barrels"), (4050, "crates"), (5420, "barrels")):
        d.append(ind(nm, (x, BOARDWALK[1] + 100)))
    # portal e poco
    d.append(D("sign", (PORTAL[0] + 200, PORTAL[1] - 120)))
    d.append(D("well", (2780, 3320)))
    for p in ((560, 3420), (560, 3900)):
        d.append(D("tree_white", p))
    return d


def main():
    KIT.mkdir(parents=True, exist_ok=True)
    (KIT / "chunks").mkdir(exist_ok=True)
    (HERE / "out").mkdir(exist_ok=True)
    props, boxes, npcs = [], [], {}
    for name, cx, row in BUILDINGS:
        entry, (bw, bh) = building_entry(name, cx, ROW_Y[row])
        props.append(entry)
        boxes.append((cx, ROW_Y[row], bw))
        if name in NPC_AT:
            npcs[NPC_AT[name]] = [cx, ROW_Y[row] + 45]
    lh, (lw, _) = building_entry(LIGHTHOUSE[0], LIGHTHOUSE[1], LIGHTHOUSE[2], narrow=True)
    props.append(lh)
    boxes.append((LIGHTHOUSE[1], LIGHTHOUSE[2], lw))
    rgb, alpha, land, deck = paint(boxes)
    wall_props, solids, (vw, wall_h) = walls()
    props = wall_props + props + decorations()
    full = np.dstack([rgb, alpha])
    for gy in range(GRID[1]):
        for gx in range(GRID[0]):
            part = full[gy * CHUNK[1]:(gy + 1) * CHUNK[1], gx * CHUNK[0]:(gx + 1) * CHUNK[0]]
            Image.fromarray(part, "RGBA").save(KIT / "chunks" / f"valdoria_v2_chunk_{gx:02d}_{gy:02d}.png", optimize=True)
    # mascara: terra/cais dentro da muralha; mar e fora da muralha bloqueados
    walk = land.copy()
    walk &= (XX > WALL_L + vw) & (XX < WALL_R - vw) & (YY > WALL_T + wall_h)
    walk = ndimage.binary_erosion(walk, iterations=3)
    h, w = WORLD[1] // CELL, WORLD[0] // CELL
    small = walk[: h * (CELL // GS), : w * (CELL // GS)].reshape(h, CELL // GS, w, CELL // GS).mean(axis=(1, 3)) > 0.6
    Image.fromarray((small * 255).astype(np.uint8)).save(KIT / "valdoria_v2_walkable.png")
    for p in [SPAWN, PORTAL] + list(npcs.values()):
        assert small[int(p[1]) // CELL, int(p[0]) // CELL], ("ponto bloqueado", p)
    kit = {
        "version": 1, "world_size": list(WORLD), "ground_scale": GS, "chunk_grid": list(GRID), "chunk_px": list(CHUNK),
        "chunks_dir": f"{RES}assets/maps/valdoria_v2/chunks", "chunk_prefix": "valdoria_v2_chunk",
        "walkable_mask": {"path": f"{RES}assets/maps/valdoria_v2/valdoria_v2_walkable.png", "cell": CELL},
        "lake": {"rect": [0, SHORE_Y - 200, WORLD[0], WORLD[1] - SHORE_Y + 200], "water_frames": [f"{RES}assets/maps/eldoria_v2/tiles/water_{i}.png" for i in range(4)]},
        "minimap": f"{RES}assets/maps/valdoria_v2/valdoria_v2_minimap.png",
        "spawn": list(SPAWN), "portal_ruins": list(PORTAL), "npcs": npcs,
        "solids": [[round(v, 1) for v in r] for r in solids], "props": props,
    }
    DATA_PATH.write_text(json.dumps(kit, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    # preview / minimapa
    q = 4
    wt = Image.open(ROOT / "assets/maps/eldoria_v2/tiles/water_0.png").convert("RGBA").resize((64, 64))
    pv = Image.new("RGBA", (WORLD[0] // q, WORLD[1] // q))
    for y in range(0, pv.height, 64):
        for x in range(0, pv.width, 64):
            pv.paste(wt, (x, y))
    pv.alpha_composite(Image.fromarray(full, "RGBA").resize(pv.size, Image.LANCZOS))
    cache = {}
    for p in sorted(props, key=lambda p: (p.get("layer") != "ground", p["pos"][1])):
        path = ROOT / p["texture"].replace(RES, "")
        im = cache.setdefault(path, Image.open(path).convert("RGBA"))
        if p.get("flip_h"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        sc = p["scale"] / q
        ww, hh = max(1, round(im.width * sc)), max(1, round(im.height * sc))
        x = round(p["pos"][0] / q + p["offset"][0] * sc)
        y = round(p["pos"][1] / q + p["offset"][1] * sc)
        pv.alpha_composite(im.resize((ww, hh), Image.LANCZOS), (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
    pv.resize((1600, 1440), Image.LANCZOS).save(KIT / "valdoria_v2_minimap.png")
    pv.save(HERE / "out/preview.png")
    dbg = pv.copy()
    dr = ImageDraw.Draw(dbg)
    for r in solids:
        dr.rectangle([r[0] / q, r[1] / q, (r[0] + r[2]) / q, (r[1] + r[3]) / q], outline=(255, 0, 0, 255))
    for p in props:
        for c in p.get("collisions", []):
            x0, y0 = p["pos"][0] + c[0], p["pos"][1] + c[1]
            dr.rectangle([x0 / q, y0 / q, (x0 + c[2]) / q, (y0 + c[3]) / q], outline=(255, 255, 0, 255))
    for (x, y) in [SPAWN, PORTAL] + list(npcs.values()):
        dr.ellipse([x / q - 6, y / q - 6, x / q + 6, y / q + 6], fill=(0, 255, 255, 255))
    dbg.save(HERE / "out/preview_colisao.png")
    print("props", len(props), "npcs", npcs)


if __name__ == "__main__":
    main()
