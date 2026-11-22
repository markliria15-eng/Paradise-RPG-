"""Recorta as folhas de pontos de coleta/bancadas do ChatGPT (tools/profissoes/fonte, fundo magenta,
grade 4x3) para assets/sprites/coleta/<nome>.png (recorte justo, maior lado <= 256 px).
Usa o mesmo tirar fundo/achar manchas dos icones (tools/itens_arte/recortar_icones.py).
uso (raiz do repo): python3 -I tools/profissoes/recortar_pontos.py
"""
import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ri", ROOT / "tools" / "itens_arte" / "recortar_icones.py")
ri = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ri)

SAIDA = ROOT / "assets" / "sprites" / "coleta"
MAX = 256
FOLHAS = {
    "prof_rochas_arvores.png": ["carvao", "ferro", "titanio", "mithril", "cristal", "obsidiana", "pedras_quebradas",
                                "arvore", "arvore_antiga", "toco", "mesa_alquimia", "fogao"],
    "prof_ervas.png": ["erva_curativa", "folha_floresta", "erva_vermelha", "cogumelo", "flor_medicinal", "musgo",
                       "erva_caverna", "fungo", "erva_especial", "planta_rara", "broto"],
}


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    for arq, nomes in FOLHAS.items():
        rgba = ri.tirar_fundo(np.asarray(Image.open(ROOT / "tools" / "profissoes" / "fonte" / arq).convert("RGB")), "magenta")
        caixas = ri.manchas(rgba[:, :, 3], len(nomes), 4, 3)
        for nome, caixa in zip(nomes, caixas):
            if caixa is None:
                print("FALTOU", nome)
                continue
            y0, y1, x0, x1 = caixa
            peca = Image.fromarray(rgba[y0:y1, x0:x1])
            s = min(1.0, MAX / max(peca.size))
            if s < 1.0:
                peca = peca.resize((round(peca.width * s), round(peca.height * s)), Image.LANCZOS)
            peca.save(SAIDA / f"{nome}.png", optimize=True)
            print(nome, peca.size)


if __name__ == "__main__":
    main()
