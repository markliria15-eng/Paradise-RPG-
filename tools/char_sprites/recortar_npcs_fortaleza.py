"""Recorta a folha dos NPCs da Fortaleza de Cinzas (ChatGPT: 4 linhas x 4 quadros de
respiracao, de frente; o fundo veio como xadrez branco/cinza desenhado, tirado aqui) em tiras 512x128 iguais as dos NPCs de Valdoria.

Cada quadro e a celula da grade 4x4 (pega vara de pesca, lanca e lampiao inteiros, mesmo
quando a ponta fica solta do corpo).

uso: python3 tools/char_sprites/recortar_npcs_fortaleza.py
Le:    tools/char_sprites/fontes_fortaleza/npcs_fortaleza_v1.png
Grava: assets/characters/npcs/npc_<id>_idle_4f_128.png (so os 4 NPCs abaixo)
"""
from pathlib import Path

import numpy as np
from scipy import ndimage
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fontes_fortaleza" / "npcs_fortaleza_v1.png"
OUT = ROOT / "assets" / "characters" / "npcs"
ROWS = ["bram_ferreiro", "corvin_soldado", "lyra_exploradora", "orven_sentinela"]
COLS = 4
CELL = 128
FEET_Y = 119
ALTURA = 108  # como os NPCs de Valdoria (cabeca ao pe, sem chapeu/lanca alem disso)


def faixas(tinta, n):
    """Faixas com tinta separadas por vao; junta os vaos menores ate sobrar n."""
    runs, dentro, ini = [], False, 0
    for i, t in enumerate(tinta):
        if t and not dentro:
            dentro, ini = True, i
        elif not t and dentro:
            dentro = False
            runs.append([ini, i])
    if dentro:
        runs.append([ini, len(tinta)])
    runs = [r for r in runs if r[1] - r[0] > 6]
    while len(runs) > n:
        vaos = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(vaos))
        runs[i] = [runs[i][0], runs[i + 1][1]]
        del runs[i + 1]
    return runs


def sem_xadrez(rgba):
    """Fundo xadrez claro (branco/cinza, sem cor) ligado a borda vira transparente."""
    rgb = rgba[..., :3].astype(np.int32)
    claro = (rgb.min(axis=2) > 196) & (rgb.max(axis=2) - rgb.min(axis=2) < 22)
    lab, _ = ndimage.label(claro)
    borda = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fundo = np.isin(lab, list(borda))
    # buracos de xadrez fechados (entre braco e corpo, lanca e perna): manchas claras grandes
    areas = np.bincount(lab.ravel())
    fundo |= claro & (areas[lab] > 150)
    # contorno claro misturado (anti-alias) colado no fundo tambem sai
    fundo |= ndimage.binary_dilation(fundo, iterations=1) & (rgb.min(axis=2) > 170) & (rgb.max(axis=2) - rgb.min(axis=2) < 30)
    rgba[fundo, 3] = 0
    return rgba


def main():
    rgba = sem_xadrez(np.asarray(Image.open(SRC).convert("RGBA")).copy())
    rgba[rgba[..., 3] < 16] = 0
    linhas = faixas((rgba[..., 3] > 16).sum(axis=1) > 2, len(ROWS))
    for (y0, y1), name in zip(linhas, ROWS):
        banda = rgba[y0:y1]
        pieces = []
        for x0, x1 in faixas((banda[..., 3] > 16).sum(axis=0) > 2, COLS):
            cell = banda[:, x0:x1].copy()
            a = cell[..., 3] > 16
            # so o corpo e o que encosta nele (sem cisco solto)
            lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
            maior = np.argmax(np.bincount(lab[a])[1:]) + 1 if n else 0
            cell[(lab != maior)] = 0
            ys, xs = np.nonzero(cell[..., 3] > 16)
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
