"""Recorta as pranchas de Eldoria v2 (assets/maps/eldoria_v2/sheets) em pecas.

Uso: py tools/eldoria_v2/slice_sheets.py

Saida (so dentro de assets/maps/eldoria_v2/):
  tiles/<piso>.png        16 texturas 256x256 de eldoria_pisos.png
  props/<nome>.png        muralha, objetos e os 4 quadros da fonte, recortados
  props/index.json        tamanho de cada peca
Nao toca no Eldoria atual (assets/maps/eldoria).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "char_sprites"))
from generate_player_sheets import label_parts  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "assets/maps/eldoria_v2"
SHEETS = KIT / "sheets"
TILES = KIT / "tiles"
PROPS = KIT / "props"

PISOS = [
    ["grass", "grass_var", "grass_flowers", "grass_dark"],
    ["cobble", "stone_light", "brick", "stone_moss"],
    ["dirt", "sand", "gravel", "plaza"],
    ["water_0", "water_1", "water_2", "water_3"],
]
MURALHA = [
    ["wall_h", "wall_h_banner", "wall_v", "wall_v_alt"],
    ["corner_ul", "corner_ur", "corner_ll", "corner_lr"],
    ["tower", "gate", "bridge_h", "bridge_v"],
]
OBJETOS = [
    ["tree_pink", "tree_yellow", "tree_blue", "tree_white", "bed_pink"],
    ["bed_mixed", "bush", "bush_flower", "bench", "lamp"],
    ["well", "statue", "barrel", "crate", "cart"],
    ["stall", "sign", "pot", None, None],
]


def split_grid(path: Path, names: list[list[str | None]]) -> dict[str, Image.Image]:
    """Cada pedaco conectado vai para a celula da grade onde fica seu centro."""
    arr = np.array(Image.open(path).convert("RGBA"))
    alpha = arr[:, :, 3] > 40
    h, w = alpha.shape
    rows, cols = len(names), len(names[0])
    labels, sizes = label_parts(alpha)
    ys, xs = np.nonzero(labels)
    lab = labels[ys, xs]
    count = np.bincount(lab, minlength=len(sizes))
    cy = np.bincount(lab, weights=ys, minlength=len(sizes)) / np.maximum(count, 1)
    cx = np.bincount(lab, weights=xs, minlength=len(sizes)) / np.maximum(count, 1)
    cell_of = np.full(len(sizes), -1)
    for i in range(1, len(sizes)):
        if sizes[i] >= 40:
            cell_of[i] = min(rows - 1, int(cy[i] * rows / h)) * cols + min(cols - 1, int(cx[i] * cols / w))
    owner = np.full((h, w), -1)
    owner[ys, xs] = cell_of[lab]
    out = {}
    for r in range(rows):
        for c in range(cols):
            name = names[r][c]
            if name is None:
                continue
            sel = owner == r * cols + c
            py, px = np.nonzero(sel)
            if len(py) == 0:
                print("vazio:", name)
                continue
            y0, y1, x0, x1 = py.min(), py.max() + 1, px.min(), px.max() + 1
            piece = arr[y0:y1, x0:x1].copy()
            piece[~sel[y0:y1, x0:x1]] = 0
            out[name] = Image.fromarray(piece, "RGBA")
    return out


def _water_mask(arr: np.ndarray) -> np.ndarray:
    r, g, b = (arr[:, :, i].astype(int) for i in range(3))
    visible = arr[:, :, 3] > 40
    turquoise = (b > 160) & (g > 130) & (b >= r + 25)
    foam = (r > 205) & (g > 215) & (b > 215) & (b >= r - 4)
    return visible & (turquoise | foam)


def _flame_mask(arr: np.ndarray) -> np.ndarray:
    r, g, b = (arr[:, :, i].astype(int) for i in range(3))
    visible = arr[:, :, 3] > 40
    orange = (r > 190) & (g > 50) & (b < 150) & (r >= g + 20)
    core = (r > 230) & (g > 200) & (b < 215) & (r >= b + 40)
    return visible & (orange | core)


def fountain_frames(path: Path) -> dict[str, Image.Image]:
    """Fonte: so a agua anima; acima da bacia (jato) a agua do quadro 0 sai."""
    def clear_zone(stone0):
        widths = stone0.sum(axis=1)
        basin_top = int(np.nonzero(widths > widths.max() * 0.4)[0].min())
        zone = np.zeros(stone0.shape, bool)
        zone[:basin_top] = True
        return zone
    return stable_frames(path, "fountain", _water_mask, clear_zone)


def torch_frames(path: Path) -> dict[str, Image.Image]:
    """Tocha: o suporte fica parado e so o fogo anima."""
    return stable_frames(path, "torch", _flame_mask, lambda solid0: np.ones(solid0.shape, bool))


def stable_frames(path: Path, prefix: str, moving_mask, clear_zone) -> dict[str, Image.Image]:
    """O ChatGPT redesenha a parte fixa em cada quadro (deslocada ate ~20 px), o
    que faz o objeto tremer. Aqui a parte fixa vem sempre do quadro 0; de cada
    quadro so a parte animada (agua/fogo) e copiada, depois de alinhar o quadro
    a parte fixa do quadro 0. Grade 2x2."""
    sheet = np.array(Image.open(path).convert("RGBA"))
    half = sheet.shape[0] // 2
    cells = [sheet[r * half:(r + 1) * half, c * half:(c + 1) * half] for r in range(2) for c in range(2)]
    base = cells[0]
    stone0 = (base[:, :, 3] > 40) & ~moving_mask(base)
    zone = clear_zone(stone0)
    out = {}
    for i, cell in enumerate(cells):
        best, best_err = (0, 0), None
        if i:
            stone = (cell[:, :, 3] > 40) & ~moving_mask(cell)
            for dy in range(-24, 25, 2):
                for dx in range(-28, 29, 2):
                    err = np.count_nonzero(np.roll(stone, (dy, dx), (0, 1)) ^ stone0)
                    if best_err is None or err < best_err:
                        best, best_err = (dy, dx), err
            fine = best
            for dy in range(best[0] - 1, best[0] + 2):
                for dx in range(best[1] - 1, best[1] + 2):
                    err = np.count_nonzero(np.roll(stone, (dy, dx), (0, 1)) ^ stone0)
                    if err < best_err:
                        fine, best_err = (dy, dx), err
            best = fine
        moved = np.roll(cell, best, (0, 1))
        frame = base.copy()
        # Na zona de limpeza a parte animada do quadro 0 sai (nao acumula gotas/
        # chamas); fora dela fica de fundo e a do quadro i vai por cima.
        frame[moving_mask(base) & zone] = 0
        anim = moving_mask(moved)
        frame[anim] = moved[anim]
        out[f"{prefix}_{i}"] = frame
        print(prefix, "quadro", i, "deslocamento", best)
    # recorte comum aos 4 quadros
    alpha_any = np.any([f[:, :, 3] > 40 for f in out.values()], axis=0)
    ys, xs = np.nonzero(alpha_any)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return {name: Image.fromarray(f, "RGBA").crop(box) for name, f in out.items()}


def main() -> None:
    TILES.mkdir(parents=True, exist_ok=True)
    PROPS.mkdir(parents=True, exist_ok=True)
    pisos = Image.open(SHEETS / "eldoria_pisos.png").convert("RGBA")
    cell = pisos.width // 4
    for r, row in enumerate(PISOS):
        for c, name in enumerate(row):
            pisos.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell)).save(TILES / f"{name}.png")
    index = {}
    pieces = {}
    pieces.update(split_grid(SHEETS / "eldoria_muralha.png", MURALHA))
    pieces.update(split_grid(SHEETS / "eldoria_objetos.png", OBJETOS))
    pieces.update(fountain_frames(SHEETS / "eldoria_fonte.png"))
    pieces.update(torch_frames(SHEETS / "tochas.png"))
    for name, im in pieces.items():
        im.save(PROPS / f"{name}.png")
        index[name] = list(im.size)
    (PROPS / "index.json").write_text(json.dumps(index, indent=1), encoding="utf-8")
    for name, size in index.items():
        print(f"{name:16s} {size}")


if __name__ == "__main__":
    main()
