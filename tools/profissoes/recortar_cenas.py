"""Recorta a arte das cenas de profissao (tools/profissoes/fonte):
- prof_fogueira.png (fundo verde, 6 quadros numa linha) -> assets/sprites/coleta/fogueira_espeto_6f.png
  (tira horizontal, quadros do mesmo tamanho, base alinhada embaixo)
- prof_objetos.png (fundo magenta: bigorna com espada, muda, tronco caido) -> assets/sprites/coleta/<nome>.png
uso (raiz do repo): python3 -I tools/profissoes/recortar_cenas.py
"""
import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ri", ROOT / "tools" / "itens_arte" / "recortar_icones.py")
ri = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ri)
SAIDA = ROOT / "assets" / "sprites" / "coleta"
FONTE = ROOT / "tools" / "profissoes" / "fonte"


def pecas(arq, fundo, n):
    rgba = ri.tirar_fundo(np.asarray(Image.open(FONTE / arq).convert("RGB")), fundo)
    solido = rgba[:, :, 3] > 40
    lab, _ = ndimage.label(ndimage.binary_dilation(solido, iterations=6))
    objs = ndimage.find_objects(lab)
    areas = [int(solido[o].sum()) for o in objs]
    grandes = sorted(sorted(range(len(objs)), key=lambda i: -areas[i])[:n], key=lambda i: objs[i][1].start)
    return [Image.fromarray(rgba[objs[i]]) for i in grandes]


def main():
    quadros = pecas("prof_fogueira.png", "verde", 6)
    w = max(q.width for q in quadros) + 4
    h = max(q.height for q in quadros) + 4
    tira = Image.new("RGBA", (w * len(quadros), h), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        tira.alpha_composite(q, (i * w + (w - q.width) // 2, h - q.height - 2))
    tira.save(SAIDA / "fogueira_espeto_6f.png", optimize=True)
    print("fogueira", tira.size)
    for nome, peca in zip(["bigorna", "muda", "tronco_caido"], pecas("prof_objetos.png", "magenta", 3)):
        s = min(1.0, 300 / max(peca.size))
        if s < 1.0:
            peca = peca.resize((round(peca.width * s), round(peca.height * s)), Image.LANCZOS)
        peca.save(SAIDA / f"{nome}.png", optimize=True)
        print(nome, peca.size)


if __name__ == "__main__":
    main()
