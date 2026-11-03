"""Recorta os sprites (arvores, pedras, arbustos, blocos) dos sheets da Floresta v2.

Entrada: assets/maps/floresta_v2/sheets/sheet_*.png (fundo transparente).
Saida: tools/forest_kit/out/slices.json + contact sheet para revisao.
Nao sobrescreve nada fora de tools/forest_kit/out/.
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SHEETS = ROOT / "assets/maps/floresta_v2/sheets"
OUT = Path(__file__).resolve().parent / "out"


def components(alpha: np.ndarray, min_area: int = 40) -> list[tuple[int, int, int, int, int]]:
    h, w = alpha.shape
    mask = alpha > 24
    seen = np.zeros_like(mask)
    boxes = []
    for y in range(h):
        row = mask[y]
        for x in np.flatnonzero(row & ~seen[y]):
            if seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            x0 = x1 = x
            y0 = y1 = y
            area = 0
            while q:
                cy, cx = q.popleft()
                area += 1
                x0 = min(x0, cx); x1 = max(x1, cx); y0 = min(y0, cy); y1 = max(y1, cy)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if area >= min_area:
                boxes.append((int(x0), int(y0), int(x1) + 1, int(y1) + 1, area))
    return boxes


def merge_close(boxes, gap=6, big_area=600):
    """Junta pedacos pequenos (petalas, folhas soltas) ao sprite grande mais proximo."""
    big = [list(b) for b in boxes if b[4] >= big_area]
    for s in (b for b in boxes if b[4] < big_area):
        for g in big:
            if g[0] - gap <= s[2] and s[0] - gap <= g[2] and g[1] - gap <= s[3] and s[1] - gap <= g[3]:
                g[0] = min(g[0], s[0]); g[1] = min(g[1], s[1])
                g[2] = max(g[2], s[2]); g[3] = max(g[3], s[3]); g[4] += s[4]
                break
    return big


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    result = {}
    for sheet in sorted(SHEETS.glob("sheet_*.png")):
        im = Image.open(sheet).convert("RGBA")
        alpha = np.array(im)[:, :, 3]
        # Remove componentes minusculos (petalas soltas) e junta pedacos vizinhos.
        boxes = merge_close(components(alpha))
        boxes = [b for b in boxes if b[4] >= 150]
        boxes.sort(key=lambda b: (round(b[1] / 40), b[0]))
        result[sheet.stem] = [b[:4] for b in boxes]
        sheet_img = im.copy()
        draw = ImageDraw.Draw(sheet_img)
        for i, b in enumerate(boxes):
            draw.rectangle(b[:4], outline=(255, 0, 0, 255))
            draw.text((b[0] + 2, b[1] + 1), str(i), fill=(255, 0, 0, 255))
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(sheet_img)
        bg.resize((im.width * 2, im.height * 2), Image.NEAREST).save(OUT / f"{sheet.stem}_labels.png")
    (OUT / "slices.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    print({k: len(v) for k, v in result.items()})


if __name__ == "__main__":
    sys.exit(main())
