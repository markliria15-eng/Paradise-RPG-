"""Recorta a folha dos NPCs novos de Valdoria (ChatGPT: 3 linhas x 4 quadros de respiracao,
de frente, fundo transparente) em tiras 512x128 iguais as dos outros NPCs de Valdoria.

uso: python tools/char_sprites/recortar_npcs_valdoria.py
Le:    tools/char_sprites/fontes_valdoria/paradise_npcs_valdoria_v1.png
Grava: assets/characters/npcs/npc_<id>_idle_4f_128.png (so os 3 NPCs abaixo)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fontes_valdoria" / "paradise_npcs_valdoria_v1.png"
OUT = ROOT / "assets" / "characters" / "npcs"
ROWS = ["borin_pescador", "kael_guarda_porto", "elira_cartografa"]
CELL = 128
FEET_Y = 119
ALTURA = 108  # como Varek/Maren/Liora (~104-117 px)


def main():
    sheet = Image.open(SRC).convert("RGBA")
    rgba = np.asarray(sheet)
    alpha = rgba[..., 3] > 16
    lab, n = ndimage.label(ndimage.binary_dilation(alpha, iterations=4))
    mass = ndimage.sum(alpha, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    big = [k for k in range(n) if mass[k] > mass.max() * 0.25]
    if len(big) != 12:
        raise SystemExit(f"esperava 12 quadros, achei {len(big)}")
    rows = {}
    for k in big:
        sy, sx = objs[k]
        r = int(((sy.start + sy.stop) / 2) // (sheet.height / 3))
        rows.setdefault(r, []).append(k)
    for r, name in enumerate(ROWS):
        ks = sorted(rows[r], key=lambda k: objs[k][1].start)
        if len(ks) != 4:
            raise SystemExit(f"linha {r}: esperava 4 quadros, achei {len(ks)}")
        pieces = []
        for k in ks:
            sy, sx = objs[k]
            piece = rgba[sy, sx].copy()
            piece[..., 3] = np.where(lab[sy, sx] == k + 1, piece[..., 3], 0)
            pieces.append(Image.fromarray(piece))
        s = ALTURA / max(p.height for p in pieces)
        strip = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
        for i, p in enumerate(pieces):
            small = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
            a = np.asarray(small)[..., 3] > 40
            # centro pelo tronco (metade de cima sem a rede/escudo largo de um lado so)
            ys, xs = np.nonzero(a[: int(a.shape[0] * 0.35)])
            cx = float(xs.mean())
            x = round(i * CELL + CELL / 2 - cx)
            y = FEET_Y + 1 - small.height
            strip.alpha_composite(small, (max(i * CELL, min(x, (i + 1) * CELL - small.width)), y))
        strip.save(OUT / f"npc_{name}_idle_4f_128.png", optimize=True)
        print(name, "escala", round(s, 3), "largura", max(round(p.width * s) for p in pieces))


if __name__ == "__main__":
    main()
