"""Recorta as folhas dos pets (8 colunas x 4 linhas, 1774x887, de lado virados para a esquerda)
em quadros 192x192 para assets/sprites/pets/<pet>/<anim>_<dir>/<pet>_<anim>_<dir>_NN.png.

O recorte antigo dividia a folha em celulas iguais, e caudas/asas que passavam da celula
ficavam cortadas (o pedaco aparecia solto no quadro vizinho). Aqui cada quadro e montado
pelas manchas conectadas: o corpo inteiro vai junto, com a cauda, mesmo que passe da celula.
Fagulhas soltas vao para o corpo mais proximo.

Linhas da folha: 0 idle, 1 walk (tambem dash_run), 2 attack, 3 death; hit repete o idle.
As 4 direcoes recebem o mesmo quadro (o jogo espelha em runtime, como antes).
Escala: a mesma altura que o idle ja tinha no jogo, para os pets nao mudarem de tamanho.

uso: python tools/pets/recortar_pets.py <pasta_das_folhas>
     (pets_e_habilidades/ do pacote pets_habilidades_e_mobs_das_conversas.zip)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
PETS = ROOT / "assets" / "sprites" / "pets"
OUT = PETS  # trocado em testes para nao sobrescrever
SHEETS = {
    "mini_lobo": "01_mini_lobo.png",
    "javali_bebe": "02_javali_bebe.png",
    "espirito_da_floresta": "03_espirito_floresta.png",
    "fada_arcana": "04_fada_arcana.png",
    "morcego_sombrio": "05_morcego_sombrio.png",
    "diabrete_de_brasa": "06_diabrete_brasa.png",
    "fagulha_gelida": "07_fagulha_gelida.png",
    "tartaruga_de_pedra": "08_tartaruga_pedra.png",
    "aranha_venenosa_filhote": "09_aranha_filhote.png",
    "draco_dourado": "10_draco_dourado_corrigido.png",
}
ANIMS = {"idle": 0, "walk": 1, "dash_run": 1, "attack": 2, "hit": 0, "death": 3}
DIRS = ["left", "right", "front", "back"]
CANVAS = 192
BASE = 184
ALPHA = 12


def frames_of(sheet: Image.Image):
    """Devolve {(linha, coluna): mascara booleana na folha inteira}."""
    a = np.asarray(sheet)[..., 3] > ALPHA
    cw, ch = sheet.width / 8, sheet.height / 4
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=2))
    idx = range(1, n + 1)
    mass = ndimage.sum(a, lab, idx)
    centers = ndimage.center_of_mass(a, lab, idx)
    boxes = ndimage.find_objects(lab)
    bodies = {}
    small = []
    big = np.median(sorted(mass)[-32:])
    rows = {r: [] for r in range(4)}
    for k in range(n):
        if mass[k] >= big * 0.25:
            if mass[k] > big * 1.7:
                raise SystemExit(f"mancha grande demais (pets grudados?) em {centers[k]}")
            rows[min(3, int(centers[k][0] // ch))].append(k)
        else:
            small.append(k)
    # algumas folhas tem 7 poses numa linha (a morte do draco corrigido): a 8a repete a ultima
    row_w = {}
    for r, ks in rows.items():
        ks.sort(key=lambda k: centers[k][1])
        if len(ks) not in (7, 8):
            raise SystemExit(f"linha {r}: esperava 8 poses, achei {len(ks)}")
        row_w[r] = sheet.width / len(ks)
        for c, k in enumerate(ks):
            bodies[(r, c)] = [k + 1]
    for k in small:
        sy, sx = boxes[k]
        cy, cx = (sy.start + sy.stop) / 2, (sx.start + sx.stop) / 2
        def dist(cell):
            by, bx = boxes[bodies[cell][0] - 1]
            dy = max(by.start - cy, 0, cy - by.stop)
            dx = max(bx.start - cx, 0, cx - bx.stop)
            return dx * dx + dy * dy
        bodies[min(bodies, key=dist)].append(k + 1)
    alpha_any = np.asarray(sheet)[..., 3] > 0
    return {cell: np.isin(lab, ids) & alpha_any for cell, ids in bodies.items()}, row_w


def current_idle_height(pet: str) -> float:
    hs = []
    for f in sorted((PETS / pet / "idle_left").glob("*.png")):
        bb = Image.open(f).getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if bb:
            hs.append(bb[3] - bb[1])
    return float(np.median(hs))


def build(pet: str, path: Path) -> None:
    sheet = Image.open(path).convert("RGBA")
    ch = sheet.height / 4
    masks, row_w = frames_of(sheet)
    rgba = np.asarray(sheet)
    boxes, full = {}, {}
    for cell, m in masks.items():
        ys, xs = np.nonzero(m & (rgba[..., 3] > 40))
        boxes[cell] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        ys, xs = np.nonzero(m)
        full[cell] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    idle_h = np.median([boxes[(0, c)][3] - boxes[(0, c)][1] for c in range(8)])
    s = current_idle_height(pet) / idle_h
    # cada pose fica onde estava em relacao ao centro da sua celula (animacao no lugar)
    def center(r, c):
        return (c + 0.5) * row_w[r]
    # cada linha e centralizada sozinha; a escala so encolhe se a linha mais larga nao couber
    ext = {}
    for row in range(4):
        rel = [(b[0] - center(r, c), b[2] - center(r, c)) for (r, c), b in boxes.items() if r == row]
        ext[row] = (min(x for x, _ in rel), max(x for _, x in rel))
    s0 = s
    widest = max(b[2] - b[0] for b in boxes.values())
    if widest * s > CANVAS - 4:
        s = (CANVAS - 4) / widest
    # linha que nao cabe inteira (pose deitada que anda pela celula): centraliza pose a pose
    loose = {row for row, (lo, hi) in ext.items() if (hi - lo) * s > CANVAS - 4}
    out = {}
    for row in range(4):
        cols = sorted(c for (r, c) in masks if r == row)
        bottoms = [boxes[(row, c)][3] - row * ch for c in cols]
        tops = [boxes[(row, c)][1] - row * ch for c in cols]
        base = float(np.median(bottoms))
        shift_x = CANVAS / 2 - (ext[row][0] + ext[row][1]) / 2 * s
        # pes da linha no BASE; se alguma pose passar do topo ou do chao, ajusta a linha toda
        off_y = BASE - base * s
        off_y = max(off_y, 2 - min(tops) * s)
        off_y = min(off_y, CANVAS - 1 - max(bottoms) * s)
        for col in cols:
            x0, y0, x1, y1 = full[(row, col)]
            piece = rgba[y0:y1, x0:x1].copy()
            piece[..., 3] = np.where(masks[(row, col)][y0:y1, x0:x1], piece[..., 3], 0)
            im = Image.fromarray(piece)
            fx, fy = (x0 - center(row, col)) * s + shift_x, (y0 - row * ch) * s + off_y
            if row in loose:
                b = boxes[(row, col)]
                fx = CANVAS / 2 - (b[2] - b[0]) * s / 2 + (x0 - b[0]) * s
            # reamostra ja na posicao fracionaria para nao tremer 1 px entre quadros
            big = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
            canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            canvas.paste(big, (round(fx), round(fy)), big)
            out[(row, col)] = canvas
        for col in range(len(cols), 8):
            out[(row, col)] = out[(row, len(cols) - 1)]
    for anim, row in ANIMS.items():
        for d in DIRS:
            folder = OUT / pet / f"{anim}_{d}"
            folder.mkdir(parents=True, exist_ok=True)
            for col in range(8):
                out[(row, col)].save(folder / f"{pet}_{anim}_{d}_{col + 1:02d}.png", optimize=True)
    print(pet, "escala", round(s, 3), "(sem limite", round(s0, 3), ") largura", round(widest * s), "poses", [len([1 for (r, _) in masks if r == k]) for k in range(4)], "soltas", sorted(loose))


if __name__ == "__main__":
    src = Path(sys.argv[1])
    only = sys.argv[2:] or list(SHEETS)
    for pet in only:
        build(pet, src / SHEETS[pet])
