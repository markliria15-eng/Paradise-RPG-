"""Processa as folhas de respiracao dos NPCs feitas no ChatGPT.

Uso:
  py tools/char_sprites/process_npcs.py            # todos os NPCs em fontes/
  py tools/char_sprites/process_npcs.py bakka_ferreiro

Entrada: assets/characters/npcs/fontes/npc_<id>_parado.png (grade 2x2, ordem
esquerda->direita, cima->baixo). Saida: assets/characters/npcs/npc_<id>_idle_4f_256.png,
tira 1024x256 com 4 quadros de 256 px; pes em y=248 e corpo (sem cajado/lanca)
com 168 px, a mesma escala dos personagens em frames_192. Os sprites _128 antigos
nao sao tocados.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_player_sheets import largest_parts  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
NPCS = ROOT / "assets/characters/npcs"
OUT = Path(__file__).resolve().parent / "out"
CELL = 256
FEET_Y = 248
BODY_H = 168


def _corpo(alpha: np.ndarray) -> tuple[int, int, float]:
    """(topo do corpo, base dos pes, x do centro da cabeca). Ignora pontas finas
    acima da cabeca (cajado, lanca): o topo e a primeira linha larga de verdade."""
    largura = alpha.sum(axis=1)
    ys = np.nonzero(largura)[0]
    bot = int(ys.max())
    top = int(np.nonzero(largura >= largura.max() * 0.2)[0].min())
    head = alpha[top:top + max(4, (bot - top) // 8)]
    _, hx = np.nonzero(head)
    return top, bot, float(hx.mean())


def processar(npc_id: str) -> None:
    src = Image.open(NPCS / "fontes" / f"npc_{npc_id}_parado.png").convert("RGBA")
    cw, ch = src.width // 2, src.height // 2
    quadros = []
    for i in range(4):
        r, c = divmod(i, 2)
        cell = np.array(src.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)))
        cell[~largest_parts(cell[:, :, 3], 0.06)] = 0
        quadros.append(cell)
    medidas = [_corpo(q[:, :, 3] > 40) for q in quadros]
    scale = BODY_H / float(np.median([bot - top + 1 for top, bot, _ in medidas]))
    tira = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    for i, (cell, (_, bot, hx)) in enumerate(zip(quadros, medidas)):
        img = Image.fromarray(cell, "RGBA")
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
        a = np.array(img)
        a[:, :, 3] = np.where(a[:, :, 3] > 110, 255, 0)
        img = Image.fromarray(a, "RGBA")
        frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        frame.paste(img, (round(CELL / 2 - hx * scale), round(FEET_Y - (bot + 1) * scale)), img)
        tira.alpha_composite(frame, (i * CELL, 0))
    tira.save(NPCS / f"npc_{npc_id}_idle_4f_256.png")
    OUT.mkdir(parents=True, exist_ok=True)
    preview = Image.new("RGBA", tira.size, (70, 110, 70, 255))
    preview.alpha_composite(tira)
    preview.save(OUT / f"preview_npc_{npc_id}.png")
    print("ok", npc_id, "escala", round(scale, 3))


if __name__ == "__main__":
    ids = sys.argv[1:] or sorted(p.stem[len("npc_"):-len("_parado")] for p in (NPCS / "fontes").glob("npc_*_parado.png"))
    for npc_id in ids:
        processar(npc_id)
