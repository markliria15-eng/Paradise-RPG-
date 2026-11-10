"""Corrige o "engorda e emagrece" de pedestres de Valdoria andando de lado.

Na folha de passos para a esquerda do guarda e do menino, o tronco muda de largura de um
quadro para o outro (a bolsa/braco aparece e some). Aqui o tronco de todos os quadros vem
de um quadro de referencia e so as pernas mudam: o boneco anda sem pulsar. O tronco
acompanha a cabeca de cada quadro (balanco natural do passo).

uso: python tools/valdoria_v2/estabilizar_npcs.py   (depois rode generate_valdoria_v2.py)
Le:    tools/valdoria_v2/fonte_anim/originais/valdoria_<npc>_walk_left_8f_128x128.png
Grava: tools/valdoria_v2/fonte_anim/valdoria_<npc>_walk_(left|right)_8f_128x128.png
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps

_FA = Path(__file__).resolve().parent / "fonte_anim"
ORIG, OUT = (Path(sys.argv[1]), Path(sys.argv[2])) if len(sys.argv) > 2 else (_FA / "originais", _FA)
FW = 128
# npc -> (quadro de referencia do tronco, corte do tronco em fracao da altura do corpo)
FIX = {"city_guard": (1, 0.70), "town_boy": (1, 0.60)}


def head_anchor(f):
    a = f[..., 3] > 30
    ys = np.nonzero(a.any(1))[0]
    y0, y1 = ys.min(), ys.max()
    band = a[y0:y0 + max(4, int((y1 - y0) * 0.18))]
    xs = np.nonzero(band.any(0))[0]
    return y0, (xs.min() + xs.max()) / 2, y1


for npc, (ref_i, cut) in FIX.items():
    src = ORIG / f"valdoria_{npc}_walk_left_8f_128x128.png"
    im = np.asarray(Image.open(src).convert("RGBA"))
    frames = [im[:, i * FW:(i + 1) * FW] for i in range(im.shape[1] // FW)]
    ry0, rcx, ry1 = head_anchor(frames[ref_i])
    split = int(ry0 + (ry1 - ry0) * cut)
    ref_top = frames[ref_i][:split]
    out = []
    for f in frames:
        y0, cx, _ = head_anchor(f)
        dx, dy = int(round(cx - rcx)), int(y0 - ry0)
        new = f.copy()
        new[:split + dy] = 0
        top = np.roll(np.roll(ref_top, dx, axis=1), 0, axis=0)
        h = min(split, new.shape[0] - dy) if dy >= 0 else split + dy
        if dy >= 0:
            dst = new[dy:dy + h]
            srcp = top[:h]
        else:
            dst = new[:h]
            srcp = top[-dy:-dy + h]
        m = srcp[..., 3] > 0
        dst[m] = srcp[m]
        out.append(new)
    strip = np.concatenate(out, axis=1)
    left = Image.fromarray(strip, "RGBA")
    left.save(OUT / src.name, optimize=True)
    right = np.concatenate([np.asarray(ImageOps.mirror(Image.fromarray(o, "RGBA"))) for o in out], axis=1)
    Image.fromarray(right, "RGBA").save(OUT / src.name.replace("_left_", "_right_"), optimize=True)
    print(npc, "ok")
