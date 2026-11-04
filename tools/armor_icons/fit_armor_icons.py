"""Icones das armaduras (7 sets x 10 pecas) ajustados aos quadrados do equipamento/bolsa.

As pranchas originais (pacote "armaduras_paradise_codex_corrigido_v4") ficam em
tools/armor_icons/fonte/ (com .gdignore). Cada peca vem num canvas 512x512 com muita
borda vazia; aqui ela e recortada no contorno real, centralizada num quadrado com margem
igual e reduzida para 128x128. Sobrescreve somente:
  assets/armor_sets/<set>/<set>_<peca>.png   (70 arquivos, mesmos caminhos de data/items.json)

Tambem remove o xadrez escuro "gravado" embaixo das botas do set Cristal (07_divino).

uso: python tools/armor_icons/fit_armor_icons.py   (raiz do projeto; precisa de Pillow e numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte"
OUT = ROOT / "assets/armor_sets"
SIZE = 128
MARGIN = 0.06  # margem em cada lado, em fracao do quadrado

SETS = {  # pasta do pacote -> id do set no jogo (data/armor_sets_manifest.json)
    "01_comum/set_01_couro_do_aventureiro": "leather",
    "02_incomum/set_02_ferro_do_guarda": "iron",
    "03_raro/set_03_ouro_real": "gold",
    "04_epico/set_04_mithril_arcano": "mithril",
    "05_lendario/set_05_obsidiana_demonica": "obsidian",
    "06_mitico/set_06_aco_sombrio_azul": "titanium",
    "07_divino/set_07_cristal_celeste": "crystal",
}
PIECES = {
    "helmet": "helmet", "chest": "chest", "shoulder_left": "shoulder_l", "shoulder_right": "shoulder_r",
    "glove_left": "glove_l", "glove_right": "glove_r", "belt": "belt", "legs": "legs",
    "boot_left": "boot_l", "boot_right": "boot_r",
}


def remove_checker(a):
    """Xadrez escuro sob as botas do set 07: linhas de baixo sao so xadrez."""
    rgb = a[..., :3].astype(int)
    neutral_dark = (rgb.max(-1) < 75) & ((rgb.max(-1) - rgb.min(-1)) < 25)
    a[398:, :, 3] = 0
    band = np.zeros(a.shape[:2], bool)
    band[384:398, :] = True
    a[band & neutral_dark, 3] = 0
    return a


def fit(path, checker=False):
    a = np.array(Image.open(path).convert("RGBA"))
    if checker:
        a = remove_checker(a)
    solid = a[..., 3] > 24
    lab, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(60, sizes.max() * 0.01)])
        a[~keep & (a[..., 3] > 0), 3] = 0
    a[a[..., 3] <= 24, 3] = 0
    im = Image.fromarray(a)
    box = im.getbbox()
    im = im.crop(box)
    side = int(max(im.size) / (1 - 2 * MARGIN))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    count = 0
    for folder, set_id in SETS.items():
        for src_name, dst_name in PIECES.items():
            src = SRC / folder / f"{src_name}.png"
            dst = OUT / set_id / f"{set_id}_{dst_name}.png"
            dst.parent.mkdir(parents=True, exist_ok=True)
            fit(src, checker=(set_id == "crystal" and src_name.startswith("boot"))).save(dst, optimize=True)
            count += 1
    print("icones:", count)


if __name__ == "__main__":
    main()
