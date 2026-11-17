"""Desenha as redeas (corda das maos do cocheiro ate a boca do cavalo) nas carrocas de Valdoria.

A arte original do ChatGPT so tinha um toco de redea na mao do cocheiro. Este script le os quadros
ORIGINAIS direto do Git (HEAD), desenha a redea em cada quadro lateral (move/idle, esquerda e
direita) e grava por cima dos PNGs em assets/maps/valdoria_v2/anim/. Rodar de novo da o mesmo
resultado (sempre parte do original do Git).

- mao: ponto fixo por veiculo (medido no quadro 0) que acompanha o balanco do cocheiro;
- boca: achada em cada quadro pela ponta do focinho (pixel mais a esquerda da cabeca);
- redea: curva com leve barriga, 2 px de couro com contorno escuro, desenhada por cima do cavalo.

uso (raiz do projeto): python tools/valdoria_v2/desenhar_redeas.py
"""
import io
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ANIM = "assets/maps/valdoria_v2/anim"
# mao: ponta da redea na mao (px do quadro olhando p/ esquerda); cocheiro: faixa x da cabeca dele;
# cabecas: faixas y onde procurar o focinho de cada cavalo (de cima para baixo)
VEICULOS = {
    "cart_worker": {"mao": (184, 60), "cocheiro": (205, 245), "cabecas": [(55, 95)], "boca": (15, -9)},
    "wagon_cargo": {"mao": (186, 101), "cocheiro": (215, 250), "cabecas": [(105, 135), (140, 175)], "boca": (15, -9)},
    "carriage_luxury": {"mao": (172, 110), "cocheiro": (215, 255), "cabecas": [(110, 140), (140, 170)], "boca": (13, -8)},
}
COURO = (92, 58, 32, 255)
CONTORNO = (38, 24, 14, 255)


def original(rel):
    data = subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def topo_cocheiro(a, faixa):
    cols = a[:, faixa[0]:faixa[1]]
    rows = np.nonzero(cols.any(1))[0]
    return int(rows.min()) if rows.size else 0


def focinho(a, faixa):
    y0, y1 = faixa
    melhor = None
    for y in range(y0, min(y1, a.shape[0])):
        xs = np.nonzero(a[y])[0]
        if xs.size and (melhor is None or xs[0] < melhor[0]):
            melhor = (int(xs[0]), y)
    return melhor


def curva(p0, p1, barriga, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t + barriga * 4 * t * (1 - t)
        pts.append((x, y))
    return pts


def desenhar(im, cfg, topo0):
    a = np.asarray(im)[..., 3] > 40
    dy = topo_cocheiro(a, cfg["cocheiro"]) - topo0
    mao = (cfg["mao"][0], cfg["mao"][1] + dy)
    d = ImageDraw.Draw(im)
    for faixa in cfg["cabecas"]:
        f = focinho(a, faixa)
        if f is None:
            continue
        boca = (f[0] + cfg["boca"][0], f[1] + cfg["boca"][1])
        pts = curva(mao, boca, 6)
        d.line(pts, fill=CONTORNO, width=4)
        d.line(pts, fill=COURO, width=2)
    return im


def main():
    total = 0
    for nome, cfg in VEICULOS.items():
        topo0 = topo_cocheiro(np.asarray(original(f"{ANIM}/{nome}_move_left/0.png"))[..., 3] > 40, cfg["cocheiro"])
        for anim in ("move", "idle"):
            for lado in ("left", "right"):
                pasta = ROOT / ANIM / f"{nome}_{anim}_{lado}"
                for png in sorted(pasta.glob("*.png"), key=lambda p: int(p.stem)):
                    im = original(f"{ANIM}/{nome}_{anim}_{lado}/{png.name}")
                    if lado == "right":
                        im = ImageOps.mirror(im)
                    im = desenhar(im, cfg, topo0)
                    if lado == "right":
                        im = ImageOps.mirror(im)
                    im.save(png, optimize=True)
                    total += 1
    print("quadros com redea:", total)


if __name__ == "__main__":
    main()
