"""Deixa as texturas dos kits de mapa (casas, objetos, carrocas, pedestres) do tamanho que aparecem.

Muitas artes do ChatGPT vem num quadro grande com borda vazia e o kit encolhe na hora de desenhar
("scale" 0.6-0.9). A placa de video guardava a imagem inteira. Este script, para cada textura usada
pelos kits (data/*_kit.json):
  1. corta a borda vazia (a mesma caixa para todos os quadros de uma animacao, para nao tremer);
  2. reduz a imagem para a maior escala em que ela e desenhada (nunca aumenta);
  3. corrige "offset" e "scale" no kit para o desenho cair exatamente no mesmo lugar.
Colisoes, "corpo" e "base" sao em px do mundo e nao mudam.

Rodar de novo nao muda nada (a borda ja foi cortada e a escala ja e 1).
Texturas citadas fora dos kits (codigo, outros JSONs) ficam como estao.

uso (raiz do projeto): python tools/kits/otimizar_texturas_kit.py [--dry-run]
"""
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
KITS = ["data/eldoria_kit.json", "data/valdoria_kit.json", "data/cave_kit.json", "data/ruins_kit.json", "data/forest_kit.json"]
ALPHA = 8
DRY = "--dry-run" in sys.argv


def fs(path):
    return ROOT / path.replace("res://", "")


def caixa(paths):
    """Caixa (x0, y0, x1, y1) que cobre o desenho de todos os quadros."""
    box = None
    size = None
    for p in paths:
        im = Image.open(fs(p)).convert("RGBA")
        size = size or im.size
        if im.size != size:
            return None, None  # quadros de tamanhos diferentes: deixa como esta
        a = np.asarray(im)[..., 3] > ALPHA
        ys, xs = np.nonzero(a)
        if xs.size == 0:
            continue
        b = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    return box, size


def citadas_fora_dos_kits():
    """Caminhos res:// citados em codigo/cenas/outros JSONs (essas texturas nao mexemos)."""
    out = subprocess.run(
        ["grep", "-rhoE", r"res://assets/[^\"' ,)]+\.png", "scripts", "client", "scenes", "data", "--include=*.gd",
         "--include=*.tscn", "--include=*.tres", "--include=*.json"],
        cwd=ROOT, capture_output=True, text=True).stdout.split()
    kits_text = {k: (ROOT / k).read_text(encoding="utf-8") for k in KITS}
    fora = set()
    for p in set(out):
        n_total = sum(1 for _ in out if _ == p)
        n_kits = sum(t.count('"%s"' % p) for t in kits_text.values())
        if n_total > n_kits:
            fora.add(p)
    return fora


def main():
    fora = citadas_fora_dos_kits()
    dados = {k: json.loads((ROOT / k).read_text(encoding="utf-8")) for k in KITS if (ROOT / k).exists()}
    # grupos: tupla de quadros -> lista de usuarios (dict, tipo)
    grupos = defaultdict(list)
    for kit, d in dados.items():
        for prop in d.get("props", []):
            frames = prop.get("frames") or ([prop["texture"]] if prop.get("texture") else [])
            if frames:
                grupos[tuple(frames)].append(("prop", prop, None))
        for v in d.get("vehicles", []):
            for nome, anim in v.get("anims", {}).items():
                if anim.get("frames"):
                    grupos[tuple(anim["frames"])].append(("veiculo", v, nome))
    # uma textura em dois grupos diferentes (ex.: quadro 0 de uma animacao usado como prop parado): pula
    conta = defaultdict(int)
    for frames in grupos:
        for f in set(frames):
            conta[f] += 1
    antes = depois = 0
    mexidas = 0
    for frames, usuarios in grupos.items():
        if any(conta[f] > 1 or f in fora for f in frames) or not all(fs(f).exists() for f in frames):
            continue
        escalas = [float(u[1].get("scale", 1.0)) for u in usuarios]
        k = min(1.0, max(escalas))
        box, size = caixa(sorted(set(frames)))
        if box is None:
            continue
        w, h = size
        x0, y0, x1, y1 = box
        nw, nh = max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))
        if (nw, nh) == (w, h):
            continue
        antes += w * h * len(set(frames))
        depois += nw * nh * len(set(frames))
        mexidas += 1
        if DRY:
            continue
        for f in sorted(set(frames)):
            im = Image.open(fs(f)).convert("RGBA").crop(box)
            if k < 1.0:
                im = im.resize((nw, nh), Image.LANCZOS)
            im.save(fs(f), optimize=True)
        for tipo, alvo, nome in usuarios:
            s = float(alvo.get("scale", 1.0))
            if tipo == "prop":
                ox, oy = (float(v) for v in alvo.get("offset", [0.0, 0.0]))
                # Sprite2D sem centralizar: mundo = pos + (offset + px) * scale
                left = (w - x1) if alvo.get("flip_h") else x0
                alvo["offset"] = [round((ox + left) * k, 2), round((oy + y0) * k, 2)]
                alvo["scale"] = round(s / k, 4)
            else:
                anim = alvo["anims"][nome]
                ox, oy = (float(v) for v in anim.get("offset", [0.0, 0.0]))
                anim["offset"] = [round((ox + x0) * k, 2), round((oy + y0) * k, 2)]
                if "pe_largura" not in alvo:
                    alvo["pe_largura"] = round(w * s, 1)  # area de esbarrao igual a de antes
        for tipo, alvo, nome in usuarios:
            if tipo == "veiculo":
                alvo["_k"] = k
    if not DRY:
        for kit, d in dados.items():
            for v in d.get("vehicles", []):
                if "_k" in v:
                    v["scale"] = round(float(v.get("scale", 1.0)) / v.pop("_k"), 4)
            texto = (ROOT / kit).read_text(encoding="utf-8")
            (ROOT / kit).write_text(json.dumps(d, ensure_ascii=False, indent=1) + ("\n" if texto.endswith("\n") else ""), encoding="utf-8")
    print(f"grupos de textura otimizados: {mexidas}")
    print(f"memoria de video (RGBA): {antes * 4 / 1e6:.0f} MB -> {depois * 4 / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
