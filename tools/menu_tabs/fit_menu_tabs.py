"""Abas premium do MENU lateral recortadas de tools/menu_tabs/fonte/abas_premium.png (fundo marrom).

2 colunas x 9 linhas, na ordem de UISideMenu.MENU_ITEMS (Batalha, Habilidades, ... VIP).
Fundo removido com rembg (isnet-general-use) por celula, mantendo as pecas grandes (faixa +
icone que sai por cima). Sobrescreve somente assets/ui/menu_tabs/<item>.png (480 px de largura).

uso: python tools/menu_tabs/fit_menu_tabs.py   (raiz do projeto; Pillow, numpy, scipy, rembg)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte/abas_premium.png"
OUT = ROOT / "assets/ui/menu_tabs"
ITEMS = ["Batalha", "Habilidades", "Roupa", "Bolsa", "Banco", "Mapa", "Party", "Guild", "Rank",
         "Missoes", "Profissoes", "Pets", "Montarias", "Dungeon", "Mercado", "Conquistas", "Temporada", "VIP"]
WIDTH = 480


def main():
    from rembg import new_session, remove
    img = Image.open(SRC).convert("RGB")
    arr = np.asarray(img).astype(int)
    dark = arr[:, 300:480].mean(axis=(1, 2)) < 70
    runs, start = [], None
    for y, d in enumerate(dark):
        if d and start is None:
            start = y
        if not d and start is not None:
            if y - start > 40:
                runs.append((start, y))
            start = None
    rows = [(runs[i][0], runs[i + 1][1]) for i in range(0, len(runs), 2)]
    assert len(rows) == 9, rows
    bounds = [0] + [(rows[i][1] + rows[i + 1][0]) // 2 for i in range(8)] + [img.height]
    session = new_session("isnet-general-use")
    OUT.mkdir(parents=True, exist_ok=True)
    for r in range(9):
        for c in range(2):
            box = (c * img.width // 2, bounds[r], (c + 1) * img.width // 2, bounds[r + 1])
            cell = img.crop(box)
            mask = np.asarray(remove(cell, session=session, only_mask=True)).astype(np.uint8)
            # reforco por cor: tudo que nao e o fundo marrom (cor das bordas da celula)
            px = np.asarray(cell).astype(float)
            edge = np.concatenate([px[:3].reshape(-1, 3), px[-3:].reshape(-1, 3), px[:, :3].reshape(-1, 3), px[:, -3:].reshape(-1, 3)])
            bg = np.median(edge, axis=0)
            colour = np.linalg.norm(px - bg, axis=-1) > 48
            colour = ndimage.binary_fill_holes(ndimage.binary_opening(colour, iterations=2))
            mask = np.maximum(mask, np.where(colour, 255, 0).astype(np.uint8))
            solid = mask > 128
            lab, n = ndimage.label(solid)
            if n > 1:
                sizes = ndimage.sum(solid, lab, range(1, n + 1))
                solid = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz >= sizes.max() * 0.05])
            alpha = np.where(ndimage.binary_dilation(solid, iterations=1), mask, 0).astype(np.uint8)
            rgba = cell.convert("RGBA")
            rgba.putalpha(Image.fromarray(alpha))
            rgba = rgba.crop(rgba.getbbox())
            h = round(rgba.height * WIDTH / rgba.width)
            rgba.resize((WIDTH, h), Image.LANCZOS).save(OUT / f"{ITEMS[r * 2 + c]}.png", optimize=True)
    print("abas:", len(ITEMS))


if __name__ == "__main__":
    main()
