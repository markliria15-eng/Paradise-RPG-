"""Caverna Profunda v2 (bat_cave) a partir das pranchas em tools/cave_v2/fonte.

Gera (sobrescreve somente estes caminhos):
  assets/maps/caverna_v2/chunks/caverna_v2_chunk_XX_YY.png   (6x6 chunks de 800x640)
  assets/maps/caverna_v2/caverna_v2_walkable.png             (mascara, celula 16px)
  assets/maps/caverna_v2/caverna_v2_minimap.png
  assets/maps/caverna_v2/props/*.png                         (sprites ja na escala do mundo)
  assets/maps/caverna_v2/tiles/water_0..3.png
  data/cave_kit.json

Ordem do mundo: Eldoria -> Floresta -> Caverna -> Ruinas.
A entrada (portal da Floresta) fica no sudoeste; a saida para as Ruinas fica no
covil da Matriarca, no nordeste, sob o arco runico.

uso: python tools/cave_v2/generate_cave_v2.py   (raiz do projeto; precisa de Pillow, numpy e scipy)
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte"
OUT = ROOT / "assets/maps/caverna_v2"
RES = "res://assets/maps/caverna_v2"

W, H = 4800, 3840
GRID = (6, 6)
CHUNK = (800, 640)
CELL = 16
TILE = 128          # pisos de 256px desenhados em 128px no mundo
FACE_H = 84         # altura do paredao (face frontal) em px do mundo
SEED = 4207

rng = random.Random(SEED)
np_rng = np.random.default_rng(SEED)

# ---------------------------------------------------------------- layout
# Saloes (cx, cy, rx, ry) e corredores (pontos, largura) em px do mundo.
ROOMS = {
    "entrada": (760, 3180, 560, 400),
    "ossos": (1960, 3260, 400, 300),
    "cristais": (930, 1280, 640, 500),
    "lago": (2560, 1900, 720, 560),
    "mina": (3560, 3080, 660, 430),
    "covil": (3880, 1120, 760, 560),
}
CORRIDORS = [
    ([(820, 2860), (960, 2350), (860, 1760)], 300),            # entrada -> cristais
    ([(1180, 3240), (1600, 3260)], 250),                        # entrada -> ossos
    ([(1480, 1260), (1900, 1500), (2240, 1700)], 320),          # cristais -> lago
    ([(2880, 2330), (3150, 2760), (3330, 2900)], 300),          # lago -> mina
    ([(3960, 2760), (4120, 2250), (3960, 1650)], 300),          # mina -> covil
]
LAKE = (2700, 1800, 330, 210)                                    # agua (cx, cy, rx, ry)
MINE_DECK = (3370, 2980, 384, 256)                               # tablado de madeira
RUNE_FLOOR = (3940, 760, 300, 150)                               # piso runico na saida

SPAWN = (760, 3300)
PORTAL_FOREST = (640, 3330)
PORTAL_RUINS = (3950, 720)
ROUTE = [PORTAL_FOREST, (820, 2860), (960, 2350), (860, 1760), (930, 1280), (1480, 1260),
         (1900, 1500), (2240, 1700), (2560, 2100), (2880, 2330), (3150, 2760), (3560, 3080),
         (3960, 2760), (4120, 2250), (3960, 1650), (3880, 1120), PORTAL_RUINS]


def value_noise(scale, amp, seed):
    """Ruido suave: grade aleatoria ampliada com interpolacao bicubica."""
    g = np.random.default_rng(seed).random((H // scale + 3, W // scale + 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(((W // scale + 3) * scale, (H // scale + 3) * scale), Image.BICUBIC)
    a = np.asarray(img, dtype=np.float32)[:H, :W] / 255.0
    return (a - 0.5) * 2 * amp


YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def ellipse_sd(cx, cy, rx, ry):
    q = np.sqrt(((XX - cx) / rx) ** 2 + ((YY - cy) / ry) ** 2)
    return (q - 1.0) * min(rx, ry)


def polyline_sd(points, width):
    d = np.full((H, W), 1e9, np.float32)
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        vx, vy = bx - ax, by - ay
        t = np.clip(((XX - ax) * vx + (YY - ay) * vy) / (vx * vx + vy * vy), 0, 1)
        d = np.minimum(d, np.hypot(XX - (ax + t * vx), YY - (ay + t * vy)))
    return d - width / 2


def build_masks():
    sd = np.full((H, W), 1e9, np.float32)
    for room in ROOMS.values():
        sd = np.minimum(sd, ellipse_sd(*room))
    for points, width in CORRIDORS:
        sd = np.minimum(sd, polyline_sd(points, width))
    edge = value_noise(180, 46, 11) + value_noise(48, 14, 12)
    floor = (sd + edge) < 0
    floor[:64, :] = False
    floor[-48:, :] = False
    floor[:, :48] = False
    floor[:, -48:] = False
    # remove ilhas soltas
    lab, n = ndimage.label(floor)
    sizes = ndimage.sum(floor, lab, range(1, n + 1))
    floor = lab == (int(np.argmax(sizes)) + 1)
    floor = ndimage.binary_fill_holes(floor)
    water = (ellipse_sd(*LAKE) + value_noise(90, 22, 13)) < 0
    water &= floor
    return floor, water


# ---------------------------------------------------------------- texturas
def tile_img(name, size=TILE):
    return Image.open(SRC / "tiles" / f"{name}.png").convert("RGB").resize((size, size), Image.LANCZOS)


def tiled(name):
    t = np.asarray(tile_img(name), dtype=np.float32)
    reps = (H // TILE + 1, W // TILE + 1, 1)
    return np.tile(t, reps)[:H, :W]


def smooth01(a, lo, hi):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def region_weight(cx, cy, rx, ry, soft=0.35):
    q = np.sqrt(((XX - cx) / rx) ** 2 + ((YY - cy) / ry) ** 2)
    return 1.0 - smooth01(q, 1.0 - soft, 1.0 + soft * 0.3)


def mix(base, layer, alpha):
    a = alpha[..., None]
    return base * (1 - a) + layer * a


def render_ground(floor, water):
    img = tiled("01")
    img = mix(img, tiled("02"), smooth01(value_noise(260, 1, 21), 0.15, 0.55))
    img = mix(img, tiled("03"), smooth01(value_noise(220, 1, 22), 0.25, 0.65) * 0.9)
    r = ROOMS["cristais"]
    w = region_weight(*r)
    img = mix(img, tiled("07"), w * smooth01(value_noise(150, 1, 23), -0.2, 0.3))
    img = mix(img, tiled("08"), w * smooth01(value_noise(150, 1, 24), 0.0, 0.5))
    img = mix(img, tiled("05"), region_weight(*ROOMS["ossos"]) * 0.95)
    c = ROOMS["covil"]
    wc = region_weight(c[0], c[1] + 40, c[2] * 0.8, c[3] * 0.75)
    img = mix(img, tiled("06"), wc * smooth01(value_noise(140, 1, 25), -0.5, 0.1))
    img = mix(img, tiled("09"), region_weight(c[0], c[1] + 60, 300, 200) * 0.85)
    shore = (ndimage.distance_transform_edt(~water) < 70) & ~water
    shore_a = np.asarray(Image.fromarray((shore * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    img = mix(img, tiled("04"), np.clip(shore_a * 1.6, 0, 1))
    # tablado da mina e piso runico (bordas retas)
    mx, my, mw, mh = MINE_DECK
    deck = np.zeros((H, W), np.float32)
    deck[my:my + mh, mx:mx + mw] = 1
    plank = np.tile(np.asarray(tile_img("12"), np.float32), (H // TILE + 1, W // TILE + 1, 1))[:H, :W]
    img = mix(img, plank, deck)
    rx, ry, rw, rh = RUNE_FLOOR
    rune = np.zeros((H, W), np.float32)
    rune[ry - rh // 2: ry + rh // 2, rx - rw // 2: rx + rw // 2] = 1
    rune = np.asarray(Image.fromarray((rune * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)), np.float32) / 255
    img = mix(img, tiled("10"), rune)

    # oclusao: chao escurece perto da rocha
    dist_void = ndimage.distance_transform_edt(floor)
    ao = 0.45 + 0.55 * smooth01(dist_void, 0, 150)
    img = img * ao[..., None]
    # luz ambiente fria + brilhos de cristal/cogumelo pintados no chao
    img *= 0.92
    return img, dist_void


def add_glow(img, x, y, radius, color, strength):
    x0, x1 = max(0, int(x - radius)), min(W, int(x + radius))
    y0, y1 = max(0, int(y - radius)), min(H, int(y + radius))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d = np.hypot(xx - x, (yy - y) * 1.35) / radius
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    img[y0:y1, x0:x1] += a[..., None] * np.array(color, np.float32)


def face_texture():
    wall = np.asarray(Image.open(SRC / "sprites/walls/01_wall_horizontal.png").convert("RGBA"), np.float32)
    face = wall[64:112, :, :3]                       # face frontal 48px
    stacked = np.concatenate([face, face], axis=0)   # 2 fileiras de pedras = paredao
    img = Image.fromarray(stacked.astype(np.uint8)).resize((int(192 * FACE_H / 96), FACE_H), Image.LANCZOS)
    f = np.asarray(img, np.float32)
    shade = np.linspace(0.55, 1.0, FACE_H)[:, None, None]
    return f * shade


def render_rock(floor, img):
    top = tiled("11") * 0.42 + tiled("02") * 0.18
    rock_noise = 1 + value_noise(120, 0.12, 31)
    top *= rock_noise[..., None]
    void = ~floor
    out = np.where(void[..., None], top, img)
    # paredao: pixels de rocha imediatamente acima do chao recebem a face frontal
    face = face_texture()
    fw = face.shape[1]
    dist_down = np.zeros((H, W), np.int32)
    run = void.copy()
    for k in range(1, FACE_H + 1):
        below = np.zeros_like(floor)
        below[:-k, :] = floor[k:, :]
        sel = run & below & (dist_down == 0)
        dist_down[sel] = k
        nxt = np.zeros_like(void)
        nxt[:-k, :] = void[k:, :]
        run &= nxt | sel
    ys, xs = np.nonzero(dist_down)
    rows = FACE_H - dist_down[ys, xs]
    out[ys, xs] = face[rows, xs % fw]
    # borda clara no topo do paredao e contorno escuro nas laterais
    rim = ndimage.binary_dilation(floor, iterations=3) & void & (dist_down == 0)
    out[rim] *= 0.55
    lip = np.zeros_like(void)
    lip[ys, xs] = dist_down[ys, xs] == FACE_H
    out[ndimage.binary_dilation(lip, iterations=2) & void & (dist_down == 0)] *= 1.35
    # sombra no chao logo abaixo do paredao
    edge = floor & np.roll(void, 1, axis=0)
    sh_img = Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))
    sh = np.asarray(sh_img, np.float32) / 255
    sh = np.roll(sh, 10, axis=0)
    out[floor] *= (1 - np.clip(sh * 1.4, 0, 0.55))[floor][..., None]
    return out, dist_down


# ---------------------------------------------------------------- props
MANIFEST = {(s["sheet"], s["index"]): s for s in json.load(open(SRC / "atlas_manifest.json"))["sprites"]}
PROP_FILES = {}


def prop_source(group, fname, sheet, index):
    s = MANIFEST[(sheet, index)]
    sx, sy, sw, sh = s["sprite"]
    fx, fy = s["foot"]
    return SRC / "sprites" / group / fname, (fx - sx, fy - sy)


PROP_DEFS = {
    # nome: (grupo, arquivo, prancha, indice, escala, colisao(fracao larg, altura px) ou None, camada)
    "tall_stalagmite": ("props", "01_tall_stalagmite.png", "deep_cave_props.png", 0, 0.62, (0.55, 22), ""),
    "small_stalagmites": ("props", "02_small_stalagmites.png", "deep_cave_props.png", 1, 0.6, (0.6, 16), ""),
    "purple_crystals": ("props", "03_purple_crystals.png", "deep_cave_props.png", 2, 0.6, (0.6, 22), ""),
    "teal_crystals": ("props", "04_teal_crystals.png", "deep_cave_props.png", 3, 0.6, (0.6, 22), ""),
    "crystal_shards": ("props", "05_crystal_shards.png", "deep_cave_props.png", 4, 0.6, None, ""),
    "tall_teal_mushroom": ("props", "06_tall_teal_mushroom.png", "deep_cave_props.png", 5, 0.62, (0.3, 16), ""),
    "small_mushrooms": ("props", "07_small_mushrooms.png", "deep_cave_props.png", 6, 0.6, None, ""),
    "bones_skull": ("props", "08_bones_skull.png", "deep_cave_props.png", 7, 0.6, None, ""),
    "animal_ribcage": ("props", "09_animal_ribcage.png", "deep_cave_props.png", 8, 0.62, (0.6, 16), ""),
    "broken_mine_cart": ("props", "10_broken_mine_cart.png", "deep_cave_props.png", 9, 0.62, (0.75, 24), ""),
    "mine_support": ("props", "11_mine_support.png", "deep_cave_props.png", 10, 0.7, "posts", ""),
    "unlit_torch": ("props", "12_unlit_torch.png", "deep_cave_props.png", 11, 0.6, (0.4, 12), ""),
    "rotten_barrels": ("props", "13_rotten_barrels.png", "deep_cave_props.png", 12, 0.6, (0.75, 22), ""),
    "large_boulder": ("props", "14_large_boulder.png", "deep_cave_props.png", 13, 0.65, (0.8, 30), ""),
    "small_boulders": ("props", "15_small_boulders.png", "deep_cave_props.png", 14, 0.6, (0.7, 16), ""),
    "large_spider_web": ("props", "16_large_spider_web.png", "deep_cave_props.png", 15, 0.66, "posts", ""),
    "silk_cocoon": ("props", "17_silk_cocoon.png", "deep_cave_props.png", 16, 0.6, (0.4, 14), ""),
    "green_spider_eggs": ("props", "18_green_spider_eggs.png", "deep_cave_props.png", 17, 0.6, (0.7, 18), ""),
    "webbed_skeleton": ("props", "19_webbed_skeleton.png", "deep_cave_props.png", 18, 0.62, (0.7, 22), ""),
    "root_curtain": ("props", "20_root_curtain.png", "deep_cave_props.png", 19, 0.62, None, ""),
    "rock_pillar": ("walls", "09_rock_pillar.png", "deep_cave_walls.png", 8, 0.8, (0.7, 34), ""),
    "cave_arch": ("walls", "10_cave_arch.png", "deep_cave_walls.png", 9, 1.25, "posts", ""),
    "silk_pillar": ("boss_lair", "01_silk_pillar.png", "deep_cave_boss_lair.png", 0, 0.7, (0.65, 30), ""),
    "web_canopy": ("boss_lair", "02_web_canopy.png", "deep_cave_boss_lair.png", 1, 0.75, "posts", ""),
    "egg_sac_mound": ("boss_lair", "03_egg_sac_mound.png", "deep_cave_boss_lair.png", 2, 0.7, (0.75, 28), ""),
    "bones_armor": ("boss_lair", "04_bones_armor.png", "deep_cave_boss_lair.png", 3, 0.62, (0.6, 18), ""),
    "hanging_cocoons": ("boss_lair", "05_hanging_cocoons.png", "deep_cave_boss_lair.png", 4, 0.7, (0.75, 24), ""),
    "shield_sword_web": ("boss_lair", "06_shield_sword_web.png", "deep_cave_boss_lair.png", 5, 0.62, (0.65, 20), ""),
    "toxic_puddle": ("boss_lair", "07_toxic_puddle.png", "deep_cave_boss_lair.png", 6, 0.7, None, "ground"),
    "webbed_boulder": ("boss_lair", "08_webbed_boulder.png", "deep_cave_boss_lair.png", 7, 0.66, (0.8, 30), ""),
    "ruins_exit_arch": ("boss_lair", "09_ruins_exit_arch.png", "deep_cave_boss_lair.png", 8, 1.45, "posts", ""),
    "broken_rune_pillars": ("boss_lair", "10_broken_rune_pillars.png", "deep_cave_boss_lair.png", 9, 0.7, (0.75, 26), ""),
    "floor_web_patches": ("boss_lair", "11_floor_web_patches.png", "deep_cave_boss_lair.png", 10, 0.75, None, "ground"),
}
CRYSTAL_SCALE = 0.6


def export_props():
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    info = {}
    for name, (group, fname, sheet, index, scale, _col, _layer) in PROP_DEFS.items():
        path, foot = prop_source(group, fname, sheet, index)
        im = Image.open(path).convert("RGBA")
        size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
        im.resize(size, Image.LANCZOS).save(OUT / "props" / f"{name}.png")
        info[name] = {"size": size, "foot": (round(foot[0] * scale), round(foot[1] * scale))}
    frames = []
    s = MANIFEST[("deep_cave_crystal_animation.png", 0)]
    foot = (s["foot"][0] - s["sprite"][0], s["foot"][1] - s["sprite"][1])
    for i in range(4):
        im = Image.open(SRC / f"sprites/crystal_animation/frame_{i}.png").convert("RGBA")
        size = (round(im.width * CRYSTAL_SCALE), round(im.height * CRYSTAL_SCALE))
        im.resize(size, Image.LANCZOS).save(OUT / "props" / f"crystal_glow_{i}.png")
        frames.append(f"{RES}/props/crystal_glow_{i}.png")
    info["crystal_glow"] = {"size": size, "foot": (round(foot[0] * CRYSTAL_SCALE), round(foot[1] * CRYSTAL_SCALE)), "frames": frames}
    return info


def prop_entry(info, name, x, y, flip=False):
    meta = info[name]
    w, h = meta["size"]
    fx, fy = meta["foot"]
    if flip:
        fx = w - fx
    entry = {"name": name, "texture": f"{RES}/props/{name}.png", "pos": [int(x), int(y)],
             "offset": [-fx, -fy], "scale": 1.0, "flip_h": flip}
    if name == "crystal_glow":
        entry["texture"] = meta["frames"][0]
        entry["frames"] = meta["frames"]
        entry["fps"] = 5
        entry["collisions"] = [[-int(w * 0.32), -26, int(w * 0.64), 30]]
        return entry
    col = PROP_DEFS[name][5]
    if PROP_DEFS[name][6]:
        entry["layer"] = PROP_DEFS[name][6]
    if col == "posts":
        pw = max(14, int(w * 0.16))
        entry["collisions"] = [[-w // 2 + 4, -18, pw, 20], [w // 2 - 4 - pw, -18, pw, 20]]
    elif col:
        cw = int(w * col[0])
        entry["collisions"] = [[-cw // 2, -col[1], cw, col[1] + 4]]
    return entry


def route_distance(x, y):
    best = 1e9
    for (ax, ay), (bx, by) in zip(ROUTE, ROUTE[1:]):
        vx, vy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy)))
        best = min(best, math.hypot(x - (ax + t * vx), y - (ay + t * vy)))
    return best


def place_props(info, floor, water, dist_void):
    props = []
    taken = []

    def free(x, y, r):
        return all(math.hypot(x - a, y - b) > r + rb for a, b, rb in taken)

    def ok(x, y, need_clear=110, r=40, wall=(0, 9999)):
        xi, yi = int(x), int(y)
        if not (0 <= xi < W and 0 <= yi < H) or not floor[yi, xi] or water[yi, xi]:
            return False
        if not (wall[0] <= dist_void[yi, xi] <= wall[1]):
            return False
        if route_distance(x, y) < need_clear:
            return False
        for px, py in (PORTAL_FOREST, PORTAL_RUINS, SPAWN):
            if math.hypot(x - px, y - py) < 260:
                return False
        return free(x, y, r)

    def put(name, x, y, flip=None, r=40):
        flip = rng.random() < 0.5 if flip is None else flip
        props.append(prop_entry(info, name, x, y, flip))
        taken.append((x, y, r))

    # pecas fixas
    put("cave_arch", PORTAL_FOREST[0], PORTAL_FOREST[1] - 150, False, 0)
    put("ruins_exit_arch", PORTAL_RUINS[0], PORTAL_RUINS[1] - 110, False, 0)
    for dx in (-260, 260):
        put("broken_rune_pillars", PORTAL_RUINS[0] + dx, PORTAL_RUINS[1] + 40, dx > 0, 60)
    mx, my, mw, mh = MINE_DECK
    put("mine_support", mx + 70, my + 60, False, 50)
    put("mine_support", mx + mw - 70, my + 60, False, 50)
    put("broken_mine_cart", mx + mw - 90, my + mh - 30, False, 50)
    put("rotten_barrels", mx + 70, my + mh - 20, False, 50)
    for tx, ty in ((mx - 40, my + 30), (mx + mw + 40, my + 30)):
        put("unlit_torch", tx, ty, False, 30)
    c = ROOMS["covil"]
    for dx, dy, name in ((-430, 60, "silk_pillar"), (430, 80, "silk_pillar"), (-300, 300, "egg_sac_mound"),
                         (320, 310, "hanging_cocoons"), (-520, -120, "web_canopy"), (520, -100, "webbed_boulder"),
                         (-150, 380, "bones_armor"), (190, -260, "shield_sword_web")):
        if ok(c[0] + dx, c[1] + dy, 90, 30):
            put(name, c[0] + dx, c[1] + dy, None, 70)
    for dx, dy in ((-120, 40), (160, 120), (60, -90), (-60, 200), (230, -20)):
        props.append(prop_entry(info, "floor_web_patches", c[0] + dx, c[1] + dy, rng.random() < 0.5))
    for dx, dy in ((-260, 180), (300, 200)):
        props.append(prop_entry(info, "toxic_puddle", c[0] + dx, c[1] + dy, rng.random() < 0.5))

    # espalhados por sala: (sala, [(nome, quantidade)])
    plan = {
        "entrada": [("tall_stalagmite", 5), ("small_stalagmites", 6), ("small_boulders", 4), ("large_boulder", 2), ("small_mushrooms", 4), ("root_curtain", 2)],
        "ossos": [("bones_skull", 6), ("animal_ribcage", 3), ("webbed_skeleton", 2), ("small_stalagmites", 3)],
        "cristais": [("purple_crystals", 6), ("teal_crystals", 6), ("crystal_shards", 8), ("crystal_glow", 4), ("tall_teal_mushroom", 4), ("small_mushrooms", 6), ("rock_pillar", 2)],
        "lago": [("tall_teal_mushroom", 5), ("small_mushrooms", 8), ("teal_crystals", 3), ("large_boulder", 3), ("small_boulders", 5), ("rock_pillar", 2), ("crystal_glow", 2), ("silk_cocoon", 2)],
        "mina": [("rotten_barrels", 2), ("broken_mine_cart", 1), ("small_boulders", 4), ("large_boulder", 2), ("bones_skull", 2), ("large_spider_web", 2), ("tall_stalagmite", 3)],
        "covil": [("silk_cocoon", 5), ("green_spider_eggs", 5), ("large_spider_web", 3), ("bones_skull", 3), ("webbed_skeleton", 2)],
    }
    flat = {"crystal_shards", "small_mushrooms", "bones_skull"}
    for room, items in plan.items():
        cx, cy, rx, ry = ROOMS[room]
        for name, count in items:
            placed = 0
            for _ in range(500):
                if placed >= count:
                    break
                a = rng.random() * math.tau
                rr = math.sqrt(rng.random()) * 1.05
                x, y = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
                wall = (20, 230) if name not in flat else (10, 9999)
                if ok(x, y, 90 if name in flat else 140, 34 if name in flat else 52, wall):
                    put(name, x, y)
                    placed += 1
    # corredores: estalagmites e pedras encostadas na parede
    for points, _w in CORRIDORS:
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            for t in np.linspace(0.1, 0.9, 4):
                x, y = ax + (bx - ax) * t + rng.uniform(-150, 150), ay + (by - ay) * t + rng.uniform(-150, 150)
                name = rng.choice(["small_stalagmites", "small_boulders", "tall_stalagmite", "root_curtain"])
                if ok(x, y, 110, 46, (14, 120)):
                    put(name, x, y)
    props.sort(key=lambda p: p["pos"][1])
    return props


def glows_for(props, img):
    colors = {
        "purple_crystals": ((70, 20, 110), 130, 0.9), "teal_crystals": ((20, 90, 95), 130, 0.9),
        "crystal_glow": ((60, 30, 120), 190, 1.0), "tall_teal_mushroom": ((15, 85, 90), 150, 0.9),
        "small_mushrooms": ((10, 60, 60), 80, 0.8), "crystal_shards": ((45, 15, 70), 60, 0.8),
        "green_spider_eggs": ((40, 80, 10), 90, 0.8), "toxic_puddle": ((30, 90, 10), 110, 0.8),
    }
    for p in props:
        if p["name"] in colors:
            col, rad, st = colors[p["name"]]
            add_glow(img, p["pos"][0], p["pos"][1] - 10, rad, col, st)
    add_glow(img, PORTAL_RUINS[0], PORTAL_RUINS[1], 260, (15, 45, 90), 1.0)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "chunks").mkdir(exist_ok=True)
    (OUT / "tiles").mkdir(exist_ok=True)
    floor, water = build_masks()
    img, dist_void = render_ground(floor, water)
    info = export_props()
    props = place_props(info, floor, water, dist_void)
    glows_for(props, img)
    img, _ = render_rock(floor, img)
    rgb = np.clip(img, 0, 255).astype(np.uint8)
    alpha = np.full((H, W), 255, np.uint8)
    # agua: chunk transparente (agua animada por baixo) com borda escura de profundidade
    dw = ndimage.distance_transform_edt(water)
    alpha[water] = np.clip(170 - dw[water] * 9, 0, 170).astype(np.uint8)
    rgb[water] = (rgb[water] * 0 + np.array([6, 14, 20])).astype(np.uint8)
    full = np.dstack([rgb, alpha])
    for gy in range(GRID[1]):
        for gx in range(GRID[0]):
            x0, y0 = gx * CHUNK[0], gy * CHUNK[1]
            Image.fromarray(full[y0:y0 + CHUNK[1], x0:x0 + CHUNK[0]], "RGBA").save(OUT / "chunks" / f"caverna_v2_chunk_{gx:02d}_{gy:02d}.png", optimize=True)
    for i in range(4):
        tile_img(f"water_{i}").save(OUT / "tiles" / f"water_{i}.png")
    # mascara andavel (branco = anda): chao sem agua, afastado 10px da rocha
    walk = floor & ~water & (dist_void > 10) & (ndimage.distance_transform_edt(~water) > 8)
    small = walk.reshape(H // CELL, CELL, W // CELL, CELL).mean(axis=(1, 3)) > 0.6
    Image.fromarray((small * 255).astype(np.uint8)).save(OUT / "caverna_v2_walkable.png")
    # minimapa
    mm = Image.fromarray(rgb).resize((480, 384), Image.LANCZOS)
    mm_a = np.asarray(mm, np.float32)
    lake_small = np.asarray(Image.fromarray((water * 255).astype(np.uint8)).resize((480, 384)), np.float32)[..., None] / 255
    mm_a = mm_a * (1 - lake_small) + np.array([30, 110, 130]) * lake_small
    Image.fromarray(np.clip(mm_a * 1.25, 0, 255).astype(np.uint8)).save(OUT / "caverna_v2_minimap.png")

    ys, xs = np.nonzero(water)
    lake_rect = [int(xs.min()) - 8, int(ys.min()) - 8, int(xs.max() - xs.min()) + 16, int(ys.max() - ys.min()) + 16]
    kit = {
        "version": 1,
        "world_size": [W, H],
        "ground_scale": 1,
        "chunk_grid": list(GRID),
        "chunk_px": list(CHUNK),
        "chunks_dir": f"{RES}/chunks",
        "chunk_prefix": "caverna_v2_chunk",
        "walkable_mask": {"path": f"{RES}/caverna_v2_walkable.png", "cell": CELL},
        "lake": {"rect": lake_rect, "water_frames": [f"{RES}/tiles/water_{i}.png" for i in range(4)]},
        "minimap": f"{RES}/caverna_v2_minimap.png",
        "spawn": list(SPAWN),
        "portal_forest": list(PORTAL_FOREST),
        "portal_ruins": list(PORTAL_RUINS),
        "rooms": {k: list(v) for k, v in ROOMS.items()},
        "solids": [],
        "props": props,
    }
    (ROOT / "data/cave_kit.json").write_text(json.dumps(kit, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("props:", len(props), "lake:", lake_rect, "walk cells:", int(small.sum()))
    # checagem: rota toda andavel
    bad = [p for p in ROUTE if not small[int(p[1]) // CELL, int(p[0]) // CELL]]
    print("pontos da rota bloqueados:", bad)


if __name__ == "__main__":
    main()
