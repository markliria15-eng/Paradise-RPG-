"""Calcula o "corpo" solido de cada casa dos kits de Eldoria e Valdoria.

Regra (pedido do Mark, 2026-11-17): o heroi nunca entra atras de uma casa. Quem vem de frente
esbarra os pes no pe da casa e fica desenhado por cima dela.
  - corpo = retangulo do desenho da casa (colunas com ao menos 10% da altura em parede/telhado, sem fumaca e
    sem pontas finas como chamine), do alto do telhado ate a linha de base (pe da casa);
  - base  = fundo das colisoes que ja existiam (o "pe" que o Mark marcou), em px do mundo,
    relativo ao "pos" da casa. O jogo passa a ordenar o desenho da casa por essa linha.
As colisoes antigas ficam como estao; o corpo e somado a elas.

Escreve so os campos "corpo" e "base" nas casas de data/eldoria_kit.json e data/valdoria_kit.json
(e nada mais nesses arquivos). Uso (raiz do projeto): python tools/casas/gerar_corpo_casas.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
KITS = ["data/eldoria_kit.json", "data/valdoria_kit.json"]
FOLGA_TOPO = 12.0  # px de mundo acima do telhado (pe do heroi atras nao encosta no telhado)


def corpo_da_imagem(path):
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3] > 128
    rows = np.nonzero(a.any(1))[0]
    top, bot = rows.min(), rows.max()
    altura = bot - top + 1
    colunas = a.sum(0)
    corpo_cols = np.nonzero(colunas >= altura * 0.10)[0]
    x0, x1 = corpo_cols.min(), corpo_cols.max() + 1
    # topo do corpo: primeira linha em que o desenho ocupa ao menos 30% da largura do corpo
    larg = a[:, x0:x1].sum(1)
    linhas = np.nonzero(larg >= (x1 - x0) * 0.3)[0]
    return x0, x1, linhas.min()


def main():
    for kit in KITS:
        path = ROOT / kit
        texto = path.read_text(encoding="utf-8")
        data = json.loads(texto)
        n = 0
        for prop in data.get("props", []):
            t = str(prop.get("texture", ""))
            if "/houses/" not in t and "/buildings/" not in t:
                continue
            cols = prop.get("collisions") or ([prop["collision"]] if prop.get("collision") else [])
            if not cols:
                continue
            s = float(prop.get("scale", 1.0))
            ox, oy = (float(v) for v in prop["offset"])
            x0, x1, y0 = corpo_da_imagem(ROOT / t.replace("res://", ""))
            wx0, wx1 = (x0 + ox) * s, (x1 + ox) * s
            if prop.get("flip_h"):
                wx0, wx1 = -wx1, -wx0
            topo = (y0 + oy) * s - FOLGA_TOPO
            base = max(float(c[1]) + float(c[3]) for c in cols)
            prop["corpo"] = [round(wx0, 1), round(topo, 1), round(wx1 - wx0, 1), round(base - topo, 1)]
            prop["base"] = round(base, 1)
            n += 1
        path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + ("\n" if texto.endswith("\n") else ""), encoding="utf-8")
        print(kit, n, "casas")


if __name__ == "__main__":
    main()
