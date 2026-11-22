"""Recorta a folha dos NPCs do Pantano das Almas Perdidas (ChatGPT: 4 linhas x 4 quadros de
respiracao, de frente, fundo transparente) em tiras 512x128 iguais as dos NPCs de Valdoria.

Cada quadro e a celula da grade 4x4 (pega vara de pesca, lanca e lampiao inteiros, mesmo
quando a ponta fica solta do corpo).

uso: python3 tools/char_sprites/recortar_npcs_pantano.py
Le:    tools/char_sprites/fontes_pantano/npcs_pantano_v1.png
Grava: assets/characters/npcs/npc_<id>_idle_4f_128.png (so os 4 NPCs abaixo)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fontes_pantano" / "npcs_pantano_v1.png"
OUT = ROOT / "assets" / "characters" / "npcs"
ROWS = ["darian_explorador", "mirta_herbalista", "oren_pescador", "nadia_guardia"]
COLS = 4
CELL = 128
FEET_Y = 119
ALTURA = 108  # como os NPCs de Valdoria (cabeca ao pe, sem chapeu/lanca alem disso)


def main():
    rgba = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    rgba[rgba[..., 3] < 16] = 0
    h, w = rgba.shape[:2]
    ch, cw = h / len(ROWS), w / COLS
    for r, name in enumerate(ROWS):
        pieces = []
        for c in range(COLS):
            cell = rgba[round(r * ch):round((r + 1) * ch), round(c * cw):round((c + 1) * cw)]
            a = cell[..., 3] > 16
            ys, xs = np.nonzero(a)
            pieces.append(Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]))
        # escala pela altura do corpo (mediana), igual para os 4 quadros
        s = ALTURA / float(np.median([p.height for p in pieces]))
        strip = Image.new("RGBA", (CELL * COLS, CELL), (0, 0, 0, 0))
        for i, p in enumerate(pieces):
            small = p.resize((max(1, round(p.width * s)), max(1, round(p.height * s))), Image.LANCZOS)
            a = np.asarray(small)[..., 3] > 40
            # centro pelo tronco (faixa do meio, sem vara/lanca de um lado so)
            faixa = a[int(a.shape[0] * 0.25): int(a.shape[0] * 0.6)]
            ys, xs = np.nonzero(faixa)
            cx = float(np.median(xs))
            x = round(i * CELL + CELL / 2 - cx)
            y = FEET_Y + 1 - small.height
            x = max(i * CELL, min(x, (i + 1) * CELL - small.width))
            strip.alpha_composite(small, (x, max(0, y)))
        strip.save(OUT / f"npc_{name}_idle_4f_128.png", optimize=True)
        print(name, "escala", round(s, 3), "largura", max(round(p.width * s) for p in pieces))


if __name__ == "__main__":
    main()
