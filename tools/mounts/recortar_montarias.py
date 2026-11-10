"""Recorta a folha de montarias gerada no ChatGPT (5 montarias lado a lado, de lado, viradas
para a esquerda) em uma imagem por montaria: assets/sprites/mounts/<code>.png.

Corta nas colunas mais vazias perto de cada quinto da folha, apara a sobra transparente e
reduz todas pelo MESMO fator (a maior fica com ALTURA px), para manter o tamanho relativo.
main.gd (_mount_icon_path) usa esses arquivos na loja e embaixo do heroi montado.

uso: python tools/mounts/recortar_montarias.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / "montarias_chatgpt_5.png"
OUT = HERE.parent.parent / "assets" / "sprites" / "mounts"
CODES = ["brown_horse", "gray_wolf", "war_boar", "shadow_panther", "crystal_stag"]
ALTURA = 200

im = Image.open(SRC).convert("RGBA")
a = np.asarray(im)[..., 3]
occ = (a > 12).sum(0)
w = im.width
n = len(CODES)
cuts = [0]
for k in range(1, n):
    nom = round(k * w / n)
    lo, hi = nom - 120, nom + 120
    seg = occ[lo:hi]
    best = np.flatnonzero(seg == seg.min())
    cuts.append(lo + int(best[np.argmin(np.abs(best + lo - nom))]))
cuts.append(w)
pieces = [im.crop((cuts[i], 0, cuts[i + 1], im.height)) for i in range(n)]
# apara pelo alfa > 12: a folha tem pixels quase invisiveis espalhados que inflavam a caixa
pieces = [p.crop(p.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()) for p in pieces]
k = ALTURA / max(p.height for p in pieces)
OUT.mkdir(parents=True, exist_ok=True)
for code, p in zip(CODES, pieces):
    q = p.resize((max(1, round(p.width * k)), max(1, round(p.height * k))), Image.LANCZOS)
    q.save(OUT / f"{code}.png", optimize=True)
    print(code, q.size)
