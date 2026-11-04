"""Icones das bolsas (slot Mochila) recortados de tools/bag_icons/fonte/bolsas.png (fundo transparente).
Esquerda: mochila (+50 slots) -> assets/bags/mochila_viajante.png
Direita:  bolsa de ombro (+20 slots) -> assets/bags/bolsa_ombro.png
uso: python tools/bag_icons/fit_bag_icons.py   (raiz do projeto; Pillow, numpy, scipy)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte/bolsas.png"
SIZE = 128
MARGIN = 0.06


def main():
    img = np.array(Image.open(SRC).convert("RGBA"))
    solid = img[..., 3] > 24
    lab, n = ndimage.label(ndimage.binary_dilation(solid, iterations=3))
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    big = sorted(np.argsort(sizes)[-2:] + 1, key=lambda i: ndimage.center_of_mass(solid, lab, i)[1])
    for i, name in zip(big, ["mochila_viajante", "bolsa_ombro"]):
        piece = img.copy()
        piece[~((lab == i) & solid), 3] = 0
        im = Image.fromarray(piece)
        im = im.crop(im.getbbox())
        side = int(max(im.size) / (1 - 2 * MARGIN))
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
        canvas.resize((SIZE, SIZE), Image.LANCZOS).save(ROOT / f"assets/bags/{name}.png", optimize=True)
    print("bolsas: 2")


if __name__ == "__main__":
    main()
