"""Importa uma tira de animacao gerada (1 linha, N frames) para o formato do jogo.

Entrada: PNG com N poses lado a lado, em colunas de mesma largura, fundo
transparente ou de cor solida (o fundo e removido pela cor dos cantos).
Saida:   assets/sprites/mobs/<mob>/<anim>_<dir>/<mob>_<anim>_<dir>_NN.png
         nas 4 direcoes (arte lateral olhando para a esquerda), canvas 192x192,
         mesma escala em todos os frames da tira e pes na mesma linha de base.

Uso (raiz do repo):
  py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa idle  <tira_idle.png>   --frames 6
  py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa walk  <tira_walk.png>   --frames 8 --scale <escala do idle>
  py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa attack <tira_attack.png> --frames 6 --scale <escala do idle>
  py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa death <tira_death.png>  --frames 8 --scale <escala do idle>
Importe o idle primeiro: ele imprime a escala usada. Passe essa mesma escala
em --scale nas outras animacoes do mob para o tamanho nao mudar entre elas.
Depois abra o editor Godot (ou rode `--headless --import`) para gerar os .import.
"""
import argparse
import glob
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from clean_mob_frames import ALPHA_MIN, DIRECTIONS, MOBS_DIR, frame_anchor, isolate_body, place  # noqa: E402

CANVAS = 192


def remove_background(rgba, tolerance):
    if (rgba[:, :, 3] < 250).mean() > 0.2:
        return rgba  # ja tem transparencia
    corners = np.array([rgba[0, 0, :3], rgba[0, -1, :3], rgba[-1, 0, :3], rgba[-1, -1, :3]], dtype=np.int32)
    bg = np.median(corners, axis=0)
    dist = np.abs(rgba[:, :, :3].astype(np.int32) - bg).sum(axis=2)
    out = rgba.copy()
    out[dist <= tolerance, 3] = 0
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mob", help="slug da pasta, ex.: aranha_venenosa")
    parser.add_argument("animation", choices=["idle", "walk", "run", "fly", "attack", "hit", "death"])
    parser.add_argument("strip")
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--body-height", type=int, default=120, help="altura (px) do maior frame no canvas 192")
    parser.add_argument("--scale", type=float, help="escala fixa (copie a impressa no import do idle)")
    parser.add_argument("--tolerance", type=int, default=60, help="tolerancia da cor de fundo (soma RGB)")
    parser.add_argument("--flip", action="store_true", help="use se a arte gerada olha para a direita")
    args = parser.parse_args()

    sheet = np.array(Image.open(args.strip).convert("RGBA"))
    sheet = remove_background(sheet, args.tolerance)
    col_w = sheet.shape[1] / float(args.frames)
    bodies = []
    for i in range(args.frames):
        cell = sheet[:, int(round(i * col_w)):int(round((i + 1) * col_w))]
        body, area = isolate_body(cell)
        if body is None or area == 0:
            print(f"AVISO frame {i + 1}: vazio, ignorado", file=sys.stderr)
            continue
        ys, xs = np.nonzero(body[:, :, 3] >= ALPHA_MIN)
        bodies.append(body[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    if not bodies:
        sys.exit("nenhum frame valido na tira")
    tallest = max(b.shape[0] for b in bodies)
    widest = max(b.shape[1] for b in bodies)
    scale = args.scale or min(args.body_height / float(tallest), (CANVAS - 8) / float(widest))
    frames = []
    for body in bodies:
        img = Image.fromarray(body, "RGBA")
        if args.flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        size = (max(1, int(round(img.width * scale))), max(1, int(round(img.height * scale))))
        img = np.array(img.resize(size, Image.NEAREST if scale >= 1 else Image.LANCZOS))
        frames.append(place(img, *frame_anchor(img), CANVAS, CANVAS))

    for direction in DIRECTIONS:
        folder = os.path.join(MOBS_DIR, args.mob, f"{args.animation}_{direction}")
        os.makedirs(folder, exist_ok=True)
        old = sorted(glob.glob(os.path.join(folder, f"{args.mob}_{args.animation}_{direction}_*.png")))
        for i, frame in enumerate(frames, start=1):
            Image.fromarray(frame, "RGBA").save(os.path.join(folder, f"{args.mob}_{args.animation}_{direction}_{i:02d}.png"))
        for path in old[len(frames):]:
            os.remove(path)
            if os.path.exists(path + ".import"):
                os.remove(path + ".import")
    print(f"{args.mob} {args.animation}: {len(frames)} frames (escala {scale:.3f})")


if __name__ == "__main__":
    main()
