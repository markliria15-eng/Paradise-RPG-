"""Refaz os sprites da Tita de Cristal (folhas novas do ChatGPT em tools/mob_sprites/fonte_tita, fundo verde).

Grava assets/sprites/mobs/tita_cristal/<anim>_<dir>/ (idle 6, walk 8, attack 6, death 8) e a tira do golpe
especial assets/sprites/mobs/visuais/tita_cristal_arremesso_8f_192x192.png (combat_visuals.json ja aponta para ela).
uso (raiz do repo): python3 -I tools/mob_sprites/importar_tita.py
"""
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTE = os.path.join(ROOT, "tools", "mob_sprites", "fonte_tita")
TOOL = os.path.join(ROOT, "tools", "mob_sprites", "import_mob_strip.py")
MOBS = os.path.join(ROOT, "assets", "sprites", "mobs")
SLUG = "tita_cristal"
FRAMES = {"idle": 6, "walk": 8, "attack": 6, "death": 8}
EXTRA = ["--spill"]
ALTURA = 120  # mesma altura do corpo de antes (ENEMY_SIZE 2.4 e a regra de tamanhos continuam valendo)


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
    rodar([SLUG, "attack", os.path.join(FONTE, f"{SLUG}_arremesso.png"), "--frames", "8", "--seams", "--tolerance", "120",
           "--match-height", str(altura), "--match", "first",
           "--tira", os.path.join(MOBS, "visuais", f"{SLUG}_arremesso_8f_192x192.png")] + EXTRA)
    print("ok")


if __name__ == "__main__":
    main()
