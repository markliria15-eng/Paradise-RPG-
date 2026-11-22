"""Recorta as folhas de arte da Fortaleza de Cinzas (fonte/*.png, fundo verde #00FF00) em objetos.

Cada folha tem os objetos na ordem de leitura (linha por linha, da esquerda para a direita) listada
em projeto_chatgpt.json -> folhas_de_arte[].conteudo. O script tira o verde, junta os pedacos de
cada objeto (bolhas, ossos soltos) e salva assets/maps/fortaleza_v2/objetos/<id>.png ja cortado.
A folha de terrenos (8 texturas 4x2) vira tools/fortaleza_v2/terrenos/<id>.png (so as ferramentas
usam; o jogo usa os chunks pintados).

uso: python3 -I tools/fortaleza_v2/recortar.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FONTE = HERE / "fonte"
OUT = ROOT / "assets/maps/fortaleza_v2/objetos"
TERR = HERE / "terrenos"  # fora do jogo (so o gerador usa)
TERRENOS = ["basalto_frio", "cinzas_finas", "cinzas_grossas", "basalto_rachado", "rocha_vulcanica", "pedra_fortaleza",
            "lava_incandescente", "obsidiana_polida"]


def sem_verde(im):
    """Tira o fundo #00FF00 pela distancia de cor (nevoa e chamas verdes de verdade ficam)."""
    a = np.asarray(im.convert("RGBA")).copy()
    rgb = a[..., :3].astype(np.float32)
    dist = np.sqrt(((rgb - np.array([0, 255, 0], np.float32)) ** 2).sum(axis=2))
    fundo = dist < 120
    # franja: pixel quase-chroma encostado no fundo
    franja = (dist < 175) & ndimage.binary_dilation(fundo, iterations=2)
    a[fundo | franja, 3] = 0
    a[a[..., 3] == 0, :3] = 0
    return a


def objetos(a, n):
    mask = a[..., 3] > 0
    for dil in (18, 30, 45, 8, 60, 80):
        lab, k = ndimage.label(ndimage.binary_dilation(mask, iterations=dil))
        areas = ndimage.sum(mask, lab, range(1, k + 1))
        grandes = [i + 1 for i, s in enumerate(areas) if s > 400]
        if len(grandes) == n:
            break
    else:
        raise SystemExit(f"nao achei {n} objetos (achei {len(grandes)})")
    caixas = []
    for i in grandes:
        ys, xs = np.nonzero((lab == i) & mask)
        caixas.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, i))
    # ordem de leitura: agrupa em linhas pelo centro vertical
    caixas.sort(key=lambda c: (c[1] + c[3]) / 2)
    linhas, atual = [], [caixas[0]]
    for c in caixas[1:]:
        if (c[1] + c[3]) / 2 - (atual[-1][1] + atual[-1][3]) / 2 > a.shape[0] * 0.18:
            linhas.append(atual)
            atual = [c]
        else:
            atual.append(c)
    linhas.append(atual)
    ordem = [c for linha in linhas for c in sorted(linha, key=lambda c: c[0])]
    out = []
    for x0, y0, x1, y1, i in ordem:
        parte = a[y0:y1, x0:x1].copy()
        parte[(lab[y0:y1, x0:x1] != i), 3] = 0
        out.append(parte)
    return out


def grade(a):
    """Terrenos 4x2 colados (sem verde entre eles): corta pela grade, tirando borda verde se houver."""
    sem = sem_verde(Image.fromarray(a))
    ys, xs = np.nonzero(sem[..., 3] > 0)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = a.shape[:2]
    out = []
    for r in range(2):
        for c in range(4):
            out.append(a[round(r * h / 2):round((r + 1) * h / 2), round(c * w / 4):round((c + 1) * w / 4)])
    return out


def main():
    proj = json.loads((HERE / "projeto_chatgpt.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    TERR.mkdir(parents=True, exist_ok=True)
    for folha in proj["folhas_de_arte"]:
        if "terrenos" in folha["arquivo"] or "cinzeiro" in folha["arquivo"]:
            continue  # terrenos abaixo; o Cinzeiro e mob (tools/fortaleza_v2/importar_inimigos.py)
        if not (FONTE / folha["arquivo"]).exists():
            print("falta", folha["arquivo"])
            continue
        a = sem_verde(Image.open(FONTE / folha["arquivo"]))
        for oid, parte in zip(folha["conteudo"], objetos(a, len(folha["conteudo"]))):
            Image.fromarray(parte, "RGBA").save(OUT / f"{oid}.png", optimize=True)
            print(oid, parte.shape[1], "x", parte.shape[0])
    # terrenos: 8 quadrados
    a = np.asarray(Image.open(FONTE / "ember_terrenos_01.png").convert("RGBA")).copy()
    for oid, parte in zip(TERRENOS, grade(a)):
        h, w = parte.shape[:2]
        m = int(min(h, w) * 0.04)  # tira a beirada (as vezes vem com sombra)
        Image.fromarray(parte[m:h - m, m:w - m, :3], "RGB").save(TERR / f"{oid}.png")
        print("terreno", oid, w, h)


if __name__ == "__main__":
    main()
