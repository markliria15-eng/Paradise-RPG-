"""Recorta o joystick novo do ChatGPT (tools/joystick/joystick_novo.png, fundo magenta: base a esquerda,
botao a direita) para assets/ui/joystick/joystick_base.png (512x512) e joystick_knob.png (256x256),
quadrados e com o circulo no centro exato (o desenho antigo era retangular e cortado).
uso (raiz do repo): python3 -I tools/joystick/recortar_joystick.py
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


def main():
    rgba = ri.tirar_fundo(np.asarray(Image.open(ROOT / "tools" / "joystick" / "joystick_novo.png").convert("RGB")), "magenta")
    solido = rgba[:, :, 3] > 40
    lab, n = ndimage.label(solido)
    areas = ndimage.sum(solido, lab, range(1, n + 1))
    maiores = sorted(range(1, n + 1), key=lambda k: -areas[k - 1])[:2]
    objs = ndimage.find_objects(lab)
    caixas = sorted([objs[k - 1] for k in maiores], key=lambda sl: sl[1].start)
    for nome, sl, lado in [("joystick_base", caixas[0], 512), ("joystick_knob", caixas[1], 256)]:
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        cy, cx = (y0 + y1) / 2.0, (x0 + x1) / 2.0
        r = max(y1 - y0, x1 - x0) / 2.0 + 2
        peca = Image.fromarray(rgba).crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r)))
        peca = peca.resize((lado, lado), Image.LANCZOS)
        peca.save(ROOT / "assets" / "ui" / "joystick" / f"{nome}.png", optimize=True)
        print(nome, peca.size)


if __name__ == "__main__":
    main()
