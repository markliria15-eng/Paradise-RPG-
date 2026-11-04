"""Icones das bijuterias (7 tiers x joia/amuleto/anel) ajustados aos quadrados.

Fontes em tools/jewel_icons/fonte/:
  bijus_7_tiers.png            prancha original (fundo claro, 3 colunas x 7 linhas)
  bijus_7_tiers_sem_fundo.png  mesma prancha com fundo removido (rembg isnet-general-use
                               por celula + furos dos aneis limpos a mao) -> usada aqui
Colunas: joia, amuleto, anel. Linhas: couro/comum, ferro, ouro, mithril, obsidiana,
aco sombrio (=titanio no jogo), cristal.
Cada peca e centralizada com margem igual e salva em 128x128. Sobrescreve somente:
  assets/jewelry/<tier>/<tier>_<jewel|amulet|ring>.png   (21 arquivos)

uso: python tools/jewel_icons/fit_jewel_icons.py   (raiz do projeto; Pillow, numpy, scipy)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte/bijus_7_tiers_sem_fundo.png"
OUT = ROOT / "assets/jewelry"
ROWS = ["leather", "iron", "gold", "mithril", "obsidian", "titanium", "crystal"]
COLS = ["jewel", "amulet", "ring"]
SIZE = 128
MARGIN = 0.06


def main():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    count = 0
    for ri, row in enumerate(ROWS):
        for ci, col in enumerate(COLS):
            cell = np.array(img.crop((int(ci * w / 3), int(ri * h / 7), int((ci + 1) * w / 3), int((ri + 1) * h / 7))))
            solid = cell[..., 3] > 40
            lab, n = ndimage.label(solid)
            if n > 1:  # descarta poeira solta
                sizes = ndimage.sum(solid, lab, range(1, n + 1))
                keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(40, sizes.max() * 0.02)])
                cell[~ndimage.binary_dilation(keep, iterations=2), 3] = 0
            cell[cell[..., 3] <= 12, 3] = 0
            im = Image.fromarray(cell)
            im = im.crop(im.getbbox())
            side = int(max(im.size) / (1 - 2 * MARGIN))
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
            dst = OUT / row / f"{row}_{col}.png"
            dst.parent.mkdir(parents=True, exist_ok=True)
            canvas.resize((SIZE, SIZE), Image.LANCZOS).save(dst, optimize=True)
            count += 1
    print("icones:", count)


if __name__ == "__main__":
    main()
