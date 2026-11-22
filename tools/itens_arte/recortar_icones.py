"""Recorta as folhas de icones de itens desenhadas pelo ChatGPT e liga cada icone ao seu item.

Entrada: tools/itens_arte/folhas.json (lista de folhas: arquivo, fundo, itens [[nome, descricao]], colunas/linhas
opcionais, padrao 4x3) e as imagens em tools/itens_arte/fonte/<arquivo>.
Saida: assets/items/icones/<slug>.png (128x128, fundo transparente) e o campo "icon" de cada item em
data/items.json (so esse campo muda; o resto do arquivo fica igual).

Nome comecando com "-" = desenho descartado (refeito em outra folha).
Cada folha tem os itens na ordem da grade (esquerda->direita, cima->baixo). O recorte acha as manchas
(fora do fundo verde #00FF00 ou magenta #FF00FF), junta pedacos soltos da mesma celula e ordena por linha.

uso (raiz do repo): python3 -I tools/itens_arte/recortar_icones.py [--so-previa] [arquivo.png ...]
"""
import json
import sys
import unicodedata
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
PASTA = ROOT / "tools" / "itens_arte"
SAIDA = ROOT / "assets" / "items" / "icones"
RES = "res://assets/items/icones/"
LADO = 128
MARGEM = 6


def slug(nome):
    s = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode().lower()
    return "".join(c if c.isalnum() else "_" for c in s).strip("_")


def tirar_fundo(rgb, fundo):
    r, g, b = [rgb[:, :, i].astype(np.int32) for i in range(3)]
    if "verde" in fundo:
        chave = g - np.maximum(r, b)          # quanto "mais verde" que o resto
        spill = g > np.maximum(r, b)
    else:
        chave = np.minimum(r, b) - g          # magenta: r e b altos, g baixo
        spill = np.minimum(r, b) > g
    alfa = np.clip((150 - chave) / 90.0, 0, 1)  # chave >=150: fundo; <=60: objeto
    out = rgb.astype(np.float32).copy()
    # tira o reflexo do fundo nas bordas
    if "verde" in fundo:
        lim = np.maximum(out[:, :, 0], out[:, :, 2])
        out[:, :, 1] = np.where(spill, np.minimum(out[:, :, 1], lim + 8), out[:, :, 1])
    else:
        # tira so o excesso comum de vermelho+azul (vermelho puro e azul puro ficam intactos)
        excesso = np.where(spill, np.minimum(out[:, :, 0], out[:, :, 2]) - out[:, :, 1] - 8, 0).clip(0)
        out[:, :, 0] -= excesso
        out[:, :, 2] -= excesso
    rgba = np.dstack([np.clip(out, 0, 255), alfa * 255]).astype(np.uint8)
    return rgba


def manchas(alfa, n, colunas, linhas):
    """Caixas dos n icones, na ordem da grade."""
    h, w = alfa.shape
    solido = alfa > 40
    # junta pedacos do mesmo icone (brilhos, gotas) sem juntar icones vizinhos
    lab, k = ndimage.label(ndimage.binary_dilation(solido, iterations=max(4, w // 160)))
    caixas = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        area = int((solido[sl] & (lab[sl] == i + 1)).sum())
        if area > (w * h) / (colunas * linhas) * 0.01:
            caixas.append((sl[0].start, sl[0].stop, sl[1].start, sl[1].stop, area))
    # cada celula da grade fica com a maior mancha cujo centro cai nela (+ as menores da mesma celula)
    celulas = {}
    for y0, y1, x0, x1, area in caixas:
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        c = (min(linhas - 1, int(cy / h * linhas)), min(colunas - 1, int(cx / w * colunas)))
        celulas.setdefault(c, []).append((y0, y1, x0, x1, area))
    saida = []
    for lin in range(linhas):
        for col in range(colunas):
            grupo = celulas.get((lin, col), [])
            if not grupo:
                saida.append(None)
                continue
            saida.append((min(g[0] for g in grupo), max(g[1] for g in grupo),
                          min(g[2] for g in grupo), max(g[3] for g in grupo)))
    return saida[:n]


def icone(rgba, caixa):
    y0, y1, x0, x1 = caixa
    peca = Image.fromarray(rgba[y0:y1, x0:x1])
    lado = LADO - 2 * MARGEM
    esc = lado / max(peca.width, peca.height)
    peca = peca.resize((max(1, round(peca.width * esc)), max(1, round(peca.height * esc))), Image.LANCZOS)
    tela = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    tela.alpha_composite(peca, ((LADO - peca.width) // 2, (LADO - peca.height) // 2))
    return tela


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    so_previa = "--so-previa" in sys.argv
    folhas = json.loads((PASTA / "folhas.json").read_text(encoding="utf-8"))
    itens_path = ROOT / "data" / "items.json"
    itens = json.loads(itens_path.read_text(encoding="utf-8"))
    SAIDA.mkdir(parents=True, exist_ok=True)
    feitos, faltas = 0, []
    for f in folhas:
        if args and f["arquivo"] not in args:
            continue
        fonte = PASTA / "fonte" / f["arquivo"]
        if not fonte.exists():
            print("sem folha:", f["arquivo"])
            continue
        cols, lins = int(f.get("colunas", 4)), int(f.get("linhas", 3))
        rgba = tirar_fundo(np.asarray(Image.open(fonte).convert("RGB")), f["fundo"])
        caixas = manchas(rgba[:, :, 3], len(f["itens"]), cols, lins)
        previa = Image.new("RGBA", (cols * (LADO + 8), lins * (LADO + 8)), (40, 40, 48, 255))
        for i, ((nome, _desc), caixa) in enumerate(zip(f["itens"], caixas)):
            if nome.startswith("-"):
                continue  # desenho descartado (refeito em outra folha)
            if caixa is None:
                faltas.append(nome)
                continue
            ic = icone(rgba, caixa)
            previa.alpha_composite(ic, ((i % cols) * (LADO + 8), (i // cols) * (LADO + 8)))
            if so_previa:
                continue
            ic.save(SAIDA / f"{slug(nome)}.png", optimize=True)
            if nome in itens:
                itens[nome]["icon"] = RES + f"{slug(nome)}.png"
                feitos += 1
            else:
                faltas.append(nome + " (nao existe em items.json)")
        previa.save(PASTA / "out" / f"previa_{f['arquivo']}") if (PASTA / "out").exists() else None
        print(f["arquivo"], "->", sum(c is not None for c in caixas), "/", len(f["itens"]))
    if not so_previa:
        itens_path.write_text(json.dumps(itens, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("icones ligados:", feitos, "| faltando:", faltas)


if __name__ == "__main__":
    main()
