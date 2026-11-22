"""Golpes especiais e efeitos dos inimigos do Pantano (arte do ChatGPT em tools/pantano_v2/fonte_ataques).

Grava em assets/sprites/mobs/visuais/:
  - poses (golpe especial do mob/chefe): <nome>_8f_192x192.png pelo import_mob_strip.py --tira, na
    mesma escala do idle do mob (--match-height), igual as outras poses do jogo;
  - ataque normal em tira (<slug>_ataque_<N>f_192x192.png, copia dos quadros attack_left) para o
    golpe normal e o especial se alternarem (combat_visuals.json -> actors);
  - efeitos: <nome>_8f_<W>x<H>.png, 8 celulas iguais com o efeito centrado (maior lado <= 280).
Depois troca so as chaves dos 4 mobs do pantano em assets/sprites/combat_visuals.json.

uso (raiz do repo): python3 -I tools/pantano_v2/importar_ataques.py
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTE = os.path.join(ROOT, "tools", "pantano_v2", "fonte_ataques")
TOOL = os.path.join(ROOT, "tools", "mob_sprites", "import_mob_strip.py")
MOBS = os.path.join(ROOT, "assets", "sprites", "mobs")
OUT = os.path.join(MOBS, "visuais")
VISUAIS_JSON = os.path.join(ROOT, "assets", "sprites", "combat_visuals.json")
RES = "res://assets/sprites/mobs/visuais/"
EFEITO_MAX = 280

# arquivo fonte -> (slug do mob, nome da tira, opcoes extras). As versoes _v2 foram pedidas com a
# folha original do mob anexada (sem ela o ChatGPT mudou as cores do sapo, mosquito e afogado).
POSES = {
    "pose_jacare_giro.png": ("jacare_pantano", "jacare_pantano_giro_da_morte", []),
    "pose_sapo_cuspe_v2.png": ("sapo_venenoso", "sapo_venenoso_cuspe", []),
    "pose_mosquito_ferroada_v2.png": ("mosquito_mutante", "mosquito_mutante_ferroada", ["--spill"]),
    "pose_afogado_lodo_v2.png": ("afogado_pantano", "afogado_pantano_abraco_lodo", ["--spill-magenta"]),
    "pose_rei_salto.png": ("rei_afogado", "rei_afogado_salto", ["--spill-magenta"]),
    "pose_rei_conjura.png": ("rei_afogado", "rei_afogado_conjura", ["--spill-magenta"]),
}
EFEITOS = {
    "fx_cuspe_veneno.png": "cuspe_veneno",
    "fx_respingo_lodo.png": "respingo_lodo",
    "fx_poca_lama.png": "poca_lama",
    "fx_onda_abismo.png": "onda_abismo",
    "fx_impacto_agua.png": "impacto_agua",
}
SEM_ROXO = {"respingo_lodo", "poca_lama", "onda_abismo", "impacto_agua"}
# golpe normal + especial se alternam; efeito "" = golpe sem efeito no alvo
ACTORS = {
    "jacare_pantano": (["jacare_pantano_ataque", "jacare_pantano_giro_da_morte"], ["", ""]),
    "sapo_venenoso": (["sapo_venenoso_ataque", "sapo_venenoso_cuspe"], ["", "cuspe_veneno"]),
    "mosquito_mutante": (["mosquito_mutante_ataque", "mosquito_mutante_ferroada"], ["", ""]),
    "afogado_pantano": (["afogado_pantano_ataque", "afogado_pantano_abraco_lodo"], ["", "respingo_lodo"]),
}


def altura_mediana(slug):
    hs = []
    for f in sorted(glob.glob(os.path.join(MOBS, slug, "idle_left", "*.png"))):
        a = np.array(Image.open(f))[:, :, 3]
        ys = np.nonzero(a.any(axis=1))[0]
        hs.append(ys.max() - ys.min() + 1)
    return float(np.median(hs))


def tira_ataque(slug):
    fs = sorted(glob.glob(os.path.join(MOBS, slug, "attack_left", "*.png")))
    tira = Image.new("RGBA", (192 * len(fs), 192), (0, 0, 0, 0))
    for i, f in enumerate(fs):
        tira.alpha_composite(Image.open(f).convert("RGBA"), (i * 192, 0))
    nome = f"{slug}_ataque_{len(fs)}f_192x192.png"
    tira.save(os.path.join(OUT, nome), optimize=True)
    return nome


def sem_fundo(path, sem_roxo=False):
    im = np.array(Image.open(path).convert("RGB")).astype(np.int32)
    bg = np.median(np.array([im[0, 0], im[0, -1], im[-1, 0], im[-1, -1], im[0, im.shape[1] // 2]]), axis=0)
    d = np.abs(im - bg).sum(axis=2)
    alpha = np.clip((d - 120) / 60.0, 0.0, 1.0)
    rgba = np.dstack([im, (alpha * 255).astype(np.int32)]).astype(np.uint8)
    # reflexo do magenta (borda e fumaca que some misturada no fundo): rosa claro vira transparente
    # na proporcao da mistura; roxo escuro de verdade (bolhas do veneno) fica
    rosa = (im[:, :, 0] > 140) & (im[:, :, 2] > 140) & (im[:, :, 1] < np.minimum(im[:, :, 0], im[:, :, 2]) - 50)
    mistura = np.clip((d - 120) / 260.0, 0.0, 1.0)
    rgba[rosa, 3] = (rgba[rosa, 3] * mistura[rosa]).astype(np.uint8)
    rgba[rosa, 0] = np.minimum(im[rosa, 0], im[rosa, 1] + 30).astype(np.uint8)
    rgba[rosa, 2] = np.minimum(im[rosa, 2], im[rosa, 1] + 30).astype(np.uint8)
    if sem_roxo:  # efeito sem nada roxo/rosa de verdade (lama): qualquer tom rosado e reflexo do fundo
        excesso = np.minimum(im[:, :, 0], im[:, :, 2]) - im[:, :, 1]
        r2 = excesso > 30
        rgba[r2, 3] = (rgba[r2, 3] * np.clip(1.0 - (excesso[r2] - 30) / 90.0, 0.0, 1.0)).astype(np.uint8)
        rgba[r2, 0] = np.minimum(im[r2, 0], im[r2, 1] + 25).astype(np.uint8)
        rgba[r2, 2] = np.minimum(im[r2, 2], im[r2, 1]).astype(np.uint8)
    return rgba


def grupos(alpha, n):
    """Colunas com tinta -> n grupos (junta os vaos menores ate sobrar n)."""
    tinta = (alpha > 0.1).sum(axis=0) > 1
    runs, dentro, ini = [], False, 0
    for x, t in enumerate(tinta):
        if t and not dentro:
            dentro, ini = True, x
        elif not t and dentro:
            dentro = False
            runs.append([ini, x])
    if dentro:
        runs.append([ini, len(tinta)])
    while len(runs) > n:
        vaos = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(vaos))
        runs[i] = [runs[i][0], runs[i + 1][1]]
        del runs[i + 1]
    if len(runs) < n:  # efeito colado: divide igual
        w = alpha.shape[1] / n
        runs = [[round(i * w), round((i + 1) * w)] for i in range(n)]
    return runs


def efeito(src, nome, n=8):
    rgba = sem_fundo(src, sem_roxo=nome in SEM_ROXO)
    a = rgba[:, :, 3].astype(np.float32) / 255.0
    cels = []
    for x0, x1 in grupos(a, n):
        part = rgba[:, x0:x1]
        ys = np.nonzero(part[:, :, 3].any(axis=1))[0]
        xs = np.nonzero(part[:, :, 3].any(axis=0))[0]
        if len(ys) == 0:
            cels.append(None)
            continue
        cels.append(part[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    w = max(c.shape[1] for c in cels if c is not None)
    h = max(c.shape[0] for c in cels if c is not None)
    s = min(1.0, EFEITO_MAX / max(w, h))
    cw, ch = max(1, round(w * s)), max(1, round(h * s))
    tira = Image.new("RGBA", (cw * n, ch), (0, 0, 0, 0))
    for i, c in enumerate(cels):
        if c is None:
            continue
        img = Image.fromarray(c, "RGBA")
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        tira.alpha_composite(img, (i * cw + (cw - img.width) // 2, (ch - img.height) // 2))
    arq = f"{nome}_{n}f_{cw}x{ch}.png"
    for velho in glob.glob(os.path.join(OUT, f"{nome}_{n}f_*.png")):
        if os.path.basename(velho) != arq:
            os.remove(velho)
    tira.save(os.path.join(OUT, arq), optimize=True)
    print("efeito", arq)
    return arq


def main():
    os.makedirs(OUT, exist_ok=True)
    feitos = {}
    for src, (slug, nome, extra) in POSES.items():
        caminho = os.path.join(FONTE, src)
        if not os.path.exists(caminho):
            print("falta", src)
            continue
        arq = f"{nome}_8f_192x192.png"
        args = [sys.executable, "-I", TOOL, slug, "attack", caminho, "--frames", "8", "--seams", "--tolerance", "120",
                "--match-height", str(altura_mediana(slug)), "--match", "first", "--tira", os.path.join(OUT, arq)] + extra
        r = subprocess.run(args, capture_output=True, text=True)
        print(r.stdout.strip(), r.stderr.strip())
        if r.returncode != 0:
            sys.exit(r.returncode)
        feitos[nome] = arq
    for slug in ACTORS:
        feitos[f"{slug}_ataque"] = tira_ataque(slug)
    for src, nome in EFEITOS.items():
        caminho = os.path.join(FONTE, src)
        if os.path.exists(caminho):
            feitos[nome] = efeito(caminho, nome)
        else:
            print("falta", src)
    vis = json.load(open(VISUAIS_JSON, encoding="utf-8"))
    for slug, (poses, fxs) in ACTORS.items():
        if all(p in feitos for p in poses) and all(f in feitos for f in fxs if f):
            vis["actors"][slug] = [RES + feitos[p] for p in poses]
            vis["effects"][slug] = [RES + feitos[f] if f else "" for f in fxs]
    with open(VISUAIS_JSON, "w", encoding="utf-8") as f:
        f.write(json.dumps(vis, indent=2, ensure_ascii=False) + "\n")
    with open(os.path.join(FONTE, "feitos.json"), "w", encoding="utf-8") as f:
        json.dump({k: RES + v for k, v in feitos.items()}, f, indent=1, ensure_ascii=False)
    print("ok", len(feitos))


if __name__ == "__main__":
    main()
