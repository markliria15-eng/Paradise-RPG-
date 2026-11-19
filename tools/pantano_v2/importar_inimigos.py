"""Recorta as folhas dos inimigos do Pantano (tools/pantano_v2/fonte_mobs) para assets/sprites/mobs/<slug>/.

Grava SO nas pastas dos 5 mobs novos (jacare_pantano, sapo_venenoso, mosquito_mutante,
afogado_pantano, rei_afogado). Idle primeiro (altura no canvas = ALTURA), as outras
animacoes com --match-height para ficarem do mesmo tamanho do idle.

uso (raiz do repo): python3 -I tools/pantano_v2/importar_inimigos.py
"""
import glob
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTE = os.path.join(ROOT, "tools", "pantano_v2", "fonte_mobs")
TOOL = os.path.join(ROOT, "tools", "mob_sprites", "import_mob_strip.py")
MOBS = os.path.join(ROOT, "assets", "sprites", "mobs")

# slug: altura do idle no canvas 192 (menor nos bichos largos para o golpe/morte caberem sem
# encolher), quadros de cada folha (conferidos a olho) e opcoes extras do import_mob_strip
MOBS_NOVOS = {
    "jacare_pantano": {"altura": 58, "frames": {"idle": 6, "walk": 8, "attack": 6, "death": 8}, "extra": []},
    "sapo_venenoso": {"altura": 110, "frames": {"idle": 6, "walk": 8, "attack": 6, "death": 8}, "extra": []},
    "mosquito_mutante": {"altura": 130, "frames": {"idle": 6, "walk": 8, "attack": 6, "death": 8}, "extra": ["--spill"]},
    "afogado_pantano": {"altura": 150, "frames": {"idle": 6, "walk": 8, "attack": 6, "death": 8}, "extra": ["--spill-magenta"]},
    "rei_afogado": {"altura": 150, "frames": {"idle": 6, "walk": 8, "attack": 6, "death": 8}, "extra": ["--spill-magenta"]},
}
ORDEM = ["idle", "walk", "attack", "death"]


def contar_poses(path):
    """Quantas poses ha na folha (colunas com tinta separadas por vazio)."""
    im = np.array(Image.open(path).convert("RGB")).astype(np.int32)
    bg = np.median(np.array([im[0, 0], im[0, -1], im[-1, 0], im[-1, -1]]), axis=0)
    tinta = (np.abs(im - bg).sum(axis=2) > 120).sum(axis=0) > 2
    runs, dentro, ini = [], False, 0
    for x, t in enumerate(tinta):
        if t and not dentro:
            dentro, ini = True, x
        elif not t and dentro:
            dentro = False
            runs.append((ini, x))
    if dentro:
        runs.append((ini, len(tinta)))
    # junta pedacos muito perto (perna/asa solta)
    juntos = []
    for r in runs:
        if juntos and r[0] - juntos[-1][1] < 18:
            juntos[-1] = (juntos[-1][0], r[1])
        else:
            juntos.append(r)
    return len([r for r in juntos if r[1] - r[0] > 30])


def altura_mediana(slug, anim):
    hs = []
    for f in sorted(glob.glob(os.path.join(MOBS, slug, f"{anim}_left", "*.png"))):
        a = np.array(Image.open(f))[:, :, 3]
        ys = np.nonzero(a.any(axis=1))[0]
        hs.append(ys.max() - ys.min() + 1)
    return float(np.median(hs))


def main():
    for slug, cfg in MOBS_NOVOS.items():
        altura_idle = None
        for anim in ORDEM:
            src = os.path.join(FONTE, f"{slug}_{anim}.png")
            n = contar_poses(src)
            esperado = cfg["frames"][anim]
            if n != esperado:
                print(f"aviso {slug} {anim}: contagem automatica {n}, usando {esperado} (conferido a olho)", file=sys.stderr)
            args = [sys.executable, "-I", TOOL, slug, anim, src, "--frames", str(esperado), "--seams",
                    "--tolerance", "120"] + cfg["extra"]
            if anim == "idle":
                args += ["--body-height", str(cfg["altura"])]
            else:
                args += ["--match-height", str(altura_idle), "--match", "median" if anim == "walk" else "first"]
            r = subprocess.run(args, capture_output=True, text=True)
            print(r.stdout.strip(), r.stderr.strip())
            if r.returncode != 0:
                sys.exit(r.returncode)
            if anim == "idle":
                altura_idle = altura_mediana(slug, "idle")


if __name__ == "__main__":
    main()
