"""Recorta o Cinzeiro Errante (inimigo novo da Fortaleza de Cinzas; folhas do ChatGPT em
tools/fortaleza_v2/fonte_mobs) para assets/sprites/mobs/cinzeiro_errante/ e grava as tiras do golpe
normal e do especial "Nuvem de Cinzas" em assets/sprites/mobs/visuais/ (combat_visuals.json ->
actors["cinzeiro_errante"], alternando os dois).

Mesmo caminho dos mobs do Pantano (tools/pantano_v2/importar_inimigos.py e importar_ataques.py).
uso (raiz do repo): python3 -I tools/fortaleza_v2/importar_inimigos.py
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTE = os.path.join(ROOT, "tools", "fortaleza_v2", "fonte_mobs")
TOOL = os.path.join(ROOT, "tools", "mob_sprites", "import_mob_strip.py")
MOBS = os.path.join(ROOT, "assets", "sprites", "mobs")
VIS = os.path.join(MOBS, "visuais")
SLUG = "cinzeiro_errante"
FRAMES = {"idle": 6, "walk": 8, "attack": 6, "death": 8}
EXTRA = ["--spill-magenta"]  # nada roxo no Cinzeiro: o reflexo do fundo sai da fumaca
ALTURA = 150


def altura_mediana(anim):
    hs = []
    for f in sorted(glob.glob(os.path.join(MOBS, SLUG, f"{anim}_left", "*.png"))):
        a = np.array(Image.open(f))[:, :, 3]
        ys = np.nonzero(a.any(axis=1))[0]
        hs.append(ys.max() - ys.min() + 1)
    return float(np.median(hs))


def rodar(args):
    r = subprocess.run([sys.executable, "-I", TOOL] + args, capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode != 0:
        sys.exit(r.returncode)


def main():
    altura = None
    for anim, n in FRAMES.items():
        args = [SLUG, anim, os.path.join(FONTE, f"{SLUG}_{anim}.png"), "--frames", str(n), "--seams", "--tolerance", "120"] + EXTRA
        args += ["--body-height", str(ALTURA)] if anim == "idle" else ["--match-height", str(altura), "--match", "median" if anim == "walk" else "first"]
        rodar(args)
        if anim == "idle":
            altura = altura_mediana("idle")
    especial = f"{SLUG}_nuvem_de_cinzas_8f_192x192.png"
    rodar([SLUG, "attack", os.path.join(FONTE, f"{SLUG}_nuvem.png"), "--frames", "8", "--seams", "--tolerance", "120",
           "--match-height", str(altura), "--match", "first", "--tira", os.path.join(VIS, especial)] + EXTRA)
    fs = sorted(glob.glob(os.path.join(MOBS, SLUG, "attack_left", "*.png")))
    normal = f"{SLUG}_ataque_{len(fs)}f_192x192.png"
    tira = Image.new("RGBA", (192 * len(fs), 192), (0, 0, 0, 0))
    for i, f in enumerate(fs):
        tira.alpha_composite(Image.open(f).convert("RGBA"), (i * 192, 0))
    tira.save(os.path.join(VIS, normal), optimize=True)
    path = os.path.join(ROOT, "assets", "sprites", "combat_visuals.json")
    vis = json.load(open(path, encoding="utf-8"))
    res = "res://assets/sprites/mobs/visuais/"
    vis["actors"][SLUG] = [res + normal, res + especial]
    vis["effects"][SLUG] = ["", ""]
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(vis, indent=2, ensure_ascii=False) + "\n")
    print("ok")


if __name__ == "__main__":
    main()
