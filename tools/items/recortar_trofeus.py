"""Recorta a folha de icones dos trofeus de chefe (ChatGPT: 6 icones numa linha, fundo branco)
em assets/items/trofeus/<id>.png (quadrado, fundo transparente).

uso: python tools/items/recortar_trofeus.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fontes" / "paradise_trofeus_v1.png"
OUT = ROOT / "assets" / "items" / "trofeus"
IDS = ["trofeu_presa_rei_javali", "trofeu_olho_matriarca", "trofeu_nucleo_arquimago",
       "trofeu_botas_colosso", "trofeu_coroa_tita", "trofeu_lamina_general"]
SIZE = 128


def main():
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im).copy()
    rgb = a[..., :3].astype(int)
    light = (rgb.min(-1) > 225) & (rgb.max(-1) - rgb.min(-1) < 25)
    lab, _ = ndimage.label(light)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    edge = ndimage.binary_dilation(bg, iterations=1) & ~bg & (rgb.min(-1) > 200)
    a[..., 3] = np.where(bg, 0, np.where(edge, 110, 255))
    occ = (a[..., 3] > 0).sum(0)
    # corta nas 5 maiores faixas vazias entre os icones
    empty = occ == 0
    runs, x = [], 0
    while x < len(empty):
        if empty[x]:
            s = x
            while x < len(empty) and empty[x]:
                x += 1
            if s > 0 and x < len(empty):
                runs.append((x - s, s, x))
        else:
            x += 1
    cuts = sorted(sorted(runs, reverse=True)[:5], key=lambda r: r[1])
    if len(cuts) != 5:
        raise SystemExit(f"esperava 5 cortes, achei {len(cuts)}")
    bounds = [0] + [(c[1] + c[2]) // 2 for c in cuts] + [a.shape[1]]
    OUT.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(IDS):
        cell = a[:, bounds[i]:bounds[i + 1]]
        ys, xs = np.nonzero(cell[..., 3] > 0)
        piece = Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
        k = (SIZE - 8) / max(piece.size)
        piece = piece.resize((round(piece.width * k), round(piece.height * k)), Image.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(piece, ((SIZE - piece.width) // 2, (SIZE - piece.height) // 2))
        canvas.save(OUT / f"{name}.png", optimize=True)
        print(name, piece.size)


if __name__ == "__main__":
    main()
