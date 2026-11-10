"""Recorta as folhas de habilidades dos pets (2172x724, 8 estagios com espacamento irregular)
quadro a quadro e remonta em 8 celulas iguais com a mesma origem.

Por que: a largura 2172 nao e divisivel por 8 e os estagios nao ficam em oitavos exatos;
dividir em partes iguais cortava pedacos do efeito (aviso do LEIA_ME do pacote).

Como: para cada uma das 7 divisas, procura perto do oitavo nominal (+-80 px) a coluna com
menos pixels opacos e corta ali. Cada estagio mantem a posicao em relacao ao centro do seu
oitavo e a altura original; a celula final tem o tamanho do maior estagio + margem.

uso: python tools/pets/recortar_efeitos_pets.py assets/sprites/pets/generated_strips assets/sprites/pets/effects
Grava <saida>/<nome>_8f_<W>x<H>.png (lido por scripts/combat_visuals.gd pelo "_8f_").
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

N, SEARCH, MARGIN = 8, 80, 6


def cuts(alpha):
    w = alpha.shape[1]
    occ = (alpha > 12).sum(0)
    out = [0]
    for k in range(1, N):
        nom = round(k * w / N)
        lo, hi = max(out[-1] + 20, nom - SEARCH), min(w - 20, nom + SEARCH)
        seg = occ[lo:hi]
        best = np.flatnonzero(seg == seg.min())
        # entre colunas igualmente vazias, a mais perto do oitavo nominal
        out.append(lo + int(best[np.argmin(np.abs(best + lo - nom))]))
    out.append(w)
    return out


def process(path, dest_dir):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)
    alpha = a[..., 3]
    w, h = im.size
    cs = cuts(alpha)
    stages = []
    for k in range(N):
        x0, x1 = cs[k], cs[k + 1]
        sub = alpha[:, x0:x1] > 12
        if not sub.any():
            stages.append(None)
            continue
        ys, xs = np.nonzero(sub)
        bx0, bx1, by0, by1 = x0 + xs.min(), x0 + xs.max() + 1, ys.min(), ys.max() + 1
        center = (k + 0.5) * w / N
        stages.append((bx0, bx1, by0, by1, center, x0, x1))
    valid = [s for s in stages if s]
    half = max(max(c - bx0, bx1 - c) for bx0, bx1, _, _, c, _, _ in valid)
    top = min(s[2] for s in valid)
    bottom = max(s[3] for s in valid)
    cw = int(np.ceil(2 * half)) + 2 * MARGIN
    ch = int(bottom - top) + 2 * MARGIN
    sheet = Image.new("RGBA", (cw * N, ch), (0, 0, 0, 0))
    for k, s in enumerate(stages):
        if not s:
            continue
        bx0, bx1, by0, by1, c, x0, x1 = s
        piece = im.crop((bx0, by0, bx1, by1))
        # so os pixels deste estagio (o recorte pode pegar pontas do vizinho fora de [x0,x1))
        px = round(k * cw + cw / 2 + (bx0 - c))
        py = round(MARGIN + by0 - top)
        sheet.alpha_composite(piece, (px, py))
    name = f"{Path(path).stem}_8f_{cw}x{ch}.png"
    sheet.save(Path(dest_dir) / name, optimize=True)
    return name, cs


if __name__ == "__main__":
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for p in sorted(src.glob("*/*.png")):
        if p.stem[:2].isdigit():  # folhas do corpo do pet (01_mini_lobo.png...), nao sao efeitos
            continue
        name, cs = process(p, dst)
        print(name, "cortes", cs[1:-1])
