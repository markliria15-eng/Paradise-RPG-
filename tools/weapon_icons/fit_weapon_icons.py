"""Icones das armas (7 tiers x espada/cajado/arco) recortados da prancha e ajustados aos quadrados.

Fonte: tools/weapon_icons/fonte/armas_7_tiers.png (3 colunas x 7 linhas, fundo transparente).
Colunas: espada (Guerreiro), cajado (Mago), arco (Arqueiro). Linhas na ordem da prancha:
couro/comum, ferro, ouro, mithril, obsidiana, aco sombrio (=titanio no jogo), cristal.
Cada arma e separada pelo contorno real (componentes conectados + pedacos soltos como
corda do arco e brilhos juntados a arma mais proxima), centralizada com margem igual e
salva em 128x128. Sobrescreve somente:
  assets/weapons/<tier>/<tier>_<sword|staff|bow>.png   (21 arquivos)

uso: python tools/weapon_icons/fit_weapon_icons.py   (raiz do projeto; Pillow, numpy, scipy)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte/armas_7_tiers.png"
OUT = ROOT / "assets/weapons"
ROWS = ["leather", "iron", "gold", "mithril", "obsidian", "titanium", "crystal"]
COLS = ["sword", "staff", "bow"]
SIZE = 128
MARGIN = 0.06


def main():
    img = np.array(Image.open(SRC).convert("RGBA"))
    h, w = img.shape[:2]
    alpha = img[..., 3] > 24
    col_w = w / 3
    count = 0
    for ci, col in enumerate(COLS):
        x0, x1 = int(ci * col_w), int((ci + 1) * col_w)
        strip = alpha[:, x0:x1]
        lab, n = ndimage.label(ndimage.binary_dilation(strip, iterations=3))
        idx = range(1, n + 1)
        sizes = ndimage.sum(strip, lab, idx)
        cent = ndimage.center_of_mass(strip, lab, idx)
        big = sorted([i for i in idx if sizes[i - 1] > 3000], key=lambda i: cent[i - 1][0])
        assert len(big) == len(ROWS), (col, len(big))
        owner = {}
        for i in idx:
            if i in big:
                owner[i] = i
                continue
            cy = cent[i - 1][0]
            owner[i] = min(big, key=lambda b: abs(cent[b - 1][0] - cy))
        for ri, b in enumerate(big):
            mask = np.isin(lab, [i for i in idx if owner[i] == b]) & strip
            piece = img[:, x0:x1].copy()
            piece[~mask, 3] = 0
            im = Image.fromarray(piece)
            im = im.crop(im.getbbox())
            side = int(max(im.size) / (1 - 2 * MARGIN))
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
            dst = OUT / ROWS[ri] / f"{ROWS[ri]}_{col}.png"
            dst.parent.mkdir(parents=True, exist_ok=True)
            canvas.resize((SIZE, SIZE), Image.LANCZOS).save(dst, optimize=True)
            count += 1
    print("icones:", count)


if __name__ == "__main__":
    main()
