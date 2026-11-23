"""Animacoes de profissao do heroi (ChatGPT, tools/char_sprites/fontes_profissoes):
  prof_<classe>_golpes.png   5x3: linhas martelo, picareta, machado
  prof_<classe>_agachado.png 5x2: linhas colher, moer
Coluna 1 de cada linha = heroi parado (so para medir a escala); colunas 2-5 = 4 quadros.
Grava assets/sprites/player_frames_caminhada_classes/<classe>/frames_192/<classe>_<anim>_{left,right}_{1..4}.png
em quadros 256x256 com o MESMO centro e escala do pack de 192 (player.gd usa a escala de 192 para 256):
a altura do parado da coluna 1 vira a altura do idle da classe, e pes/centro seguem o idle.
uso (raiz do repo): python3 -I tools/char_sprites/recortar_profissoes.py [classe ...]
"""
import importlib.util
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ri", ROOT / "tools" / "itens_arte" / "recortar_icones.py")
ri = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ri)
FONTE = ROOT / "tools" / "char_sprites" / "fontes_profissoes"
PACK = ROOT / "assets" / "sprites" / "player_frames_caminhada_classes"
CANVAS = 256
DESLOC = (CANVAS - 192) // 2
FUNDO = {"guerreiro": "verde", "maga_de_fogo": "verde", "arqueiro": "magenta"}
FOLHAS = [("golpes", ["martelo", "picareta", "machado"]), ("agachado", ["colher", "moer"])]


def medidas_idle(classe):
    a = np.array(Image.open(PACK / classe / "frames_192" / f"{classe}_idle_left_1.png").convert("RGBA"))[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    return ys.max() - ys.min() + 1, xs.mean() + DESLOC, ys.max() + DESLOC


def cortar_linha(rgba, y0, y1, cols):
    """5 manchas da linha (a maior de cada coluna, mais os pedacos soltos da mesma coluna)."""
    faixa = rgba[y0:y1]
    solido = faixa[:, :, 3] > 40
    lab, _ = ndimage.label(ndimage.binary_dilation(solido, iterations=3))
    w = faixa.shape[1]
    celulas = {}
    for o in ndimage.find_objects(lab):
        area = int(solido[o].sum())
        if area < 150:
            continue
        cx = (o[1].start + o[1].stop) / 2
        celulas.setdefault(min(cols - 1, int(cx / w * cols)), []).append(o)
    pecas = []
    for c in range(cols):
        grupo = celulas.get(c, [])
        if not grupo:
            raise SystemExit(f"coluna {c} vazia")
        ya, yb = min(o[0].start for o in grupo), max(o[0].stop for o in grupo)
        xa, xb = min(o[1].start for o in grupo), max(o[1].stop for o in grupo)
        recorte = faixa[ya:yb, xa:xb].copy()
        pecas.append({"img": recorte, "x": xa, "cell_cx": (c + 0.5) * w / cols, "bottom": yb})
    return pecas


def main():
    classes = sys.argv[1:] or list(FUNDO)
    for classe in classes:
        alt_idle, cx_idle, base_idle = medidas_idle(classe)
        for folha, anims in FOLHAS:
            arq = FONTE / f"prof_{classe}_{folha}.png"
            if not arq.exists():
                print("falta", arq.name)
                continue
            rgba = ri.tirar_fundo(np.asarray(Image.open(arq).convert("RGB")), FUNDO[classe])
            linhas = len(anims)
            h = rgba.shape[0]
            # linhas pela separacao vertical das manchas (vales sem pixel solido)
            perfil = (rgba[:, :, 3] > 40).sum(axis=1)
            cortes = [0]
            for k in range(1, linhas):
                alvo = int(h * k / linhas)
                janela = range(max(0, alvo - h // (linhas * 3)), min(h, alvo + h // (linhas * 3)))
                cortes.append(min(janela, key=lambda y: perfil[y]))
            cortes.append(h)
            for li, anim in enumerate(anims):
                pecas = cortar_linha(rgba, cortes[li], cortes[li + 1], 5)
                ref = pecas[0]
                a = ref["img"][:, :, 3] > 40
                ys, xs = np.nonzero(a)
                escala = alt_idle / float(ys.max() - ys.min() + 1)
                ref_cx = ref["x"] + xs.mean() - ref["cell_cx"]
                for i, p in enumerate(pecas[1:], start=1):
                    img = Image.fromarray(p["img"])
                    img = img.resize((max(1, round(img.width * escala)), max(1, round(img.height * escala))), Image.LANCZOS)
                    ar = np.array(img)[:, :, 3] > 40
                    pys, pxs = np.nonzero(ar)
                    # centro: mesma distancia ao centro da celula que o parado tinha; base: linha do chao
                    off = (p["x"] + (pxs.mean() / escala) - p["cell_cx"] - ref_cx) * escala
                    alvo_cx = cx_idle + off
                    dx = int(round(alvo_cx - pxs.mean()))
                    dy = int(round(base_idle - pys.max()))  # pes (ou joelhos) na linha do chao do idle
                    tela = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
                    tela.paste(img, (dx, dy), img)
                    nome = f"{classe}_{anim}_left_{i}.png"
                    tela.save(PACK / classe / "frames_192" / nome, optimize=True)
                    tela.transpose(Image.FLIP_LEFT_RIGHT).save(PACK / classe / "frames_192" / nome.replace("_left_", "_right_"), optimize=True)
                print(classe, anim, "escala %.3f" % escala)


if __name__ == "__main__":
    main()
