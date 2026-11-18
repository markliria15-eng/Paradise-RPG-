"""Pre-corta os golpes especiais e efeitos dos mobs (assets/sprites/combat_visuals.json).

Antes o jogo abria a folha bruta do ChatGPT (2172x724, ~6 MB na placa de video cada) e cortava na
hora da luta. Este script faz o mesmo corte AGORA e grava tiras prontas e pequenas em
assets/sprites/mobs/visuais/, no formato "<nome>_<N>f_<W>x<H>.png" que o CombatVisuals ja entende:
  - poses de mob (actors): celulas 192x192 com os pes na linha 184, UMA escala para a tira toda
    (a da 1a pose) -- igual ao CombatVisuals.frames(actor=true);
  - efeitos: as mesmas celulas da folha, so reduzidas (o jogo ajusta o tamanho na tela pela celula,
    entao o efeito aparece do mesmo tamanho).
Depois troca os caminhos no combat_visuals.json. As folhas brutas ficam em generated_strips/
(fonte para recortar de novo) e saem do APK pelo export_presets.cfg.

uso (raiz do projeto): python tools/mob_sprites/precortar_visuais.py
"""
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
JSON_PATH = ROOT / "assets/sprites/combat_visuals.json"
OUT = ROOT / "assets/sprites/mobs/visuais"
EFEITO_MAX = 280  # maior lado da celula do efeito (o jogo mostra ~140 px)


def grade(img, path):
    m = re.search(r"_(\d+)f_\d+x\d+\.png$", path)
    if m:
        return int(m.group(1)), 1
    if img.height != 724:
        return 4, 2
    return 8, 1


def celulas(img, cols, rows):
    w = img.width / cols
    h = img.height / rows
    out = []
    for r in range(rows):
        for c in range(cols):
            out.append(img.crop((round(c * w), round(r * h), round(c * w) + round(w), round(r * h) + round(h))))
    return out


def pose(cells):
    corpos = []
    for cell in cells:
        bb = cell.getbbox()
        if bb is None:
            continue
        corpos.append(cell.crop(bb))
    if not corpos:
        return []
    f = 120.0 / corpos[0].height
    for c in corpos:
        f = min(f, 184.0 / c.height, 192.0 / c.width)
    frames = []
    for c in corpos:
        c = c.resize((max(1, round(c.width * f)), max(1, round(c.height * f))), Image.LANCZOS)
        canvas = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
        canvas.alpha_composite(c, ((192 - c.width) // 2, 184 - c.height))
        frames.append(canvas)
    return frames


def main():
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    feitos = {}
    antes = depois = 0
    for categoria, actor in (("actors", True), ("effects", False)):
        for chave, lista in data.get(categoria, {}).items():
            for i, path in enumerate(lista):
                if "/mobs/visuais/" in path:
                    continue
                src = ROOT / path.replace("res://", "")
                img = Image.open(src).convert("RGBA")
                cols, rows = grade(img, path)
                pronta = actor and img.width / cols == 192 and img.height / rows == 192
                cells = celulas(img, cols, rows)
                if actor and not pronta:
                    frames = pose(cells)
                else:
                    frames = cells
                    if not actor:
                        w, h = frames[0].size
                        k = min(1.0, EFEITO_MAX / max(w, h))
                        if k < 1.0:
                            frames = [c.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS) for c in frames]
                if not frames:
                    continue
                fw, fh = frames[0].size
                nome = re.sub(r"(_\d+f_\d+x\d+)?\.png$", "", src.name)
                dest = OUT / f"{nome}_{len(frames)}f_{fw}x{fh}.png"
                if dest not in feitos.values():
                    tira = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
                    for j, fr in enumerate(frames):
                        tira.alpha_composite(fr.resize((fw, fh)) if fr.size != (fw, fh) else fr, (j * fw, 0))
                    tira.save(dest, optimize=True)
                    antes += img.width * img.height
                    depois += tira.width * tira.height
                feitos[path] = dest
                lista[i] = "res://" + dest.relative_to(ROOT).as_posix()
    texto = JSON_PATH.read_text(encoding="utf-8")
    indent = 2 if '\n  "' in texto else (4 if '\n    "' in texto else None)
    JSON_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + ("\n" if texto.endswith("\n") else ""), encoding="utf-8")
    print(f"tiras pre-cortadas: {len(set(feitos.values()))}")
    print(f"memoria de video (RGBA): {antes * 4 / 1e6:.0f} MB -> {depois * 4 / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
