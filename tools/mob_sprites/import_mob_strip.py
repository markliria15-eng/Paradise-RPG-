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
from clean_mob_frames import label_components, ALPHA_MIN, DIRECTIONS, MOBS_DIR, frame_anchor, isolate_body, place  # noqa: E402

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


def drop_border_bits(cell):
    """Tira pedacos do quadro vizinho: partes soltas que encostam na borda esquerda/direita da celula
    (o corpo principal, a maior parte, sempre fica)."""
    mask = cell[:, :, 3] >= ALPHA_MIN
    if not mask.any():
        return cell
    labels, count = label_components(mask)
    areas = np.bincount(labels.ravel())[1:]
    main = int(np.argmax(areas)) + 1
    out = cell.copy()
    for comp in range(1, count + 1):
        if comp == main:
            continue
        xs = np.nonzero((labels == comp).any(0))[0]
        if xs.min() <= 1 or xs.max() >= cell.shape[1] - 2:
            out[labels == comp] = 0
    return out


def seam_edges(sheet, n):
    """Divisas entre poses: em vez da grade fixa, a coluna com menos tinta perto de cada divisa
    (janela de 40% da celula). Poses que a IA nao centralizou na celula deixam de ser cortadas."""
    ink = (sheet[:, :, 3] >= ALPHA_MIN).sum(axis=0).astype(np.float64)
    w = sheet.shape[1]
    col_w = w / float(n)
    edges = [0]
    for i in range(1, n):
        center = i * col_w
        a = int(max(edges[-1] + col_w * 0.3, center - col_w * 0.4))
        b = int(min(w - 1, center + col_w * 0.4))
        window = ink[a:b]
        best = np.flatnonzero(window == window.min())
        # entre as colunas mais vazias, a mais perto da divisa original
        pick = best[np.argmin(np.abs(best + a - center))] + a
        edges.append(int(pick))
    edges.append(w)
    return edges


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
    parser.add_argument("--match-height", type=float,
                        help="altura (px no canvas) que a pose de referencia deve ter: deixa esta tira do mesmo "
                             "tamanho do idle mesmo que a IA tenha desenhado maior/menor")
    parser.add_argument("--match", choices=["median", "first"], default="median",
                        help="pose de referencia para --match-height (first: morte/golpe que comecam parados)")
    parser.add_argument("--tira", help="em vez das pastas do mob, grava uma tira <nome>_<N>f_192x192.png "
                                         "(golpe especial do CombatVisuals, ja no tamanho do idle)")
    parser.add_argument("--despill", action="store_true",
                        help="apaga a franja verde do fundo chroma (so para arte sem verde: lobo, mago...)")
    parser.add_argument("--spill", action="store_true",
                        help="tira o reflexo do fundo verde sem apagar nada (asa transparente de inseto fica cinza)")
    parser.add_argument("--spill-magenta", action="store_true",
                        help="tira o reflexo do fundo magenta (so para arte SEM roxo/rosa: brilho e borda ficam limpos)")
    parser.add_argument("--seams", action="store_true",
                        help="corta nas colunas mais vazias perto de cada divisa (pose fora da grade nao e cortada)")
    args = parser.parse_args()

    sheet = np.array(Image.open(args.strip).convert("RGBA"))
    sheet = remove_background(sheet, args.tolerance)
    if args.despill:
        rgb = sheet[:, :, :3].astype(np.int32)
        verde = (rgb[:, :, 1] > rgb[:, :, 0] + 40) & (rgb[:, :, 1] > rgb[:, :, 2] + 40)
        sheet[verde, 3] = 0
        # cor do fundo some tambem dos pixels transparentes (senao o redimensionamento traz o verde de volta)
        sheet[sheet[:, :, 3] == 0, :3] = 30
    if args.spill:
        rgb = sheet[:, :, :3].astype(np.int32)
        sheet[:, :, 1] = np.minimum(rgb[:, :, 1], np.maximum(rgb[:, :, 0], rgb[:, :, 2]) + 12).astype(np.uint8)
    if args.spill_magenta:
        rgb = sheet[:, :, :3].astype(np.int32)
        excesso = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
        rosa = excesso > 40
        fade = np.clip(1.0 - (excesso - 40) / 120.0, 0.0, 1.0)
        sheet[rosa, 3] = (sheet[rosa, 3] * fade[rosa]).astype(np.uint8)
        sheet[rosa, 0] = np.minimum(rgb[rosa, 0], rgb[rosa, 1] + 25).astype(np.uint8)
        sheet[rosa, 2] = np.minimum(rgb[rosa, 2], rgb[rosa, 1] + 40).astype(np.uint8)
    col_w = sheet.shape[1] / float(args.frames)
    edges = [int(round(i * col_w)) for i in range(args.frames + 1)]
    if args.seams:
        edges = seam_edges(sheet, args.frames)
    bodies = []
    for i in range(args.frames):
        cell = sheet[:, edges[i]:edges[i + 1]]
        if args.seams:
            cell = drop_border_bits(cell)
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
    if args.match_height:
        ref = bodies[0].shape[0] if args.match == "first" else float(np.median([b.shape[0] for b in bodies]))
        scale = args.match_height / float(ref)
    # nada pode passar do canvas (senao o place() corta a pose)
    scale = min(scale, (CANVAS - 8) / float(widest), (CANVAS - 8) / float(tallest))
    frames = []
    for body in bodies:
        img = Image.fromarray(body, "RGBA")
        if args.flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        size = (max(1, int(round(img.width * scale))), max(1, int(round(img.height * scale))))
        img = np.array(img.resize(size, Image.NEAREST if scale >= 1 else Image.LANCZOS))
        frames.append(place(img, *frame_anchor(img), CANVAS, CANVAS))

    if args.tira:
        tira = Image.new("RGBA", (CANVAS * len(frames), CANVAS), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            tira.alpha_composite(Image.fromarray(frame, "RGBA"), (i * CANVAS, 0))
        tira.save(args.tira, optimize=True)
        print(f"{args.tira}: {len(frames)} frames (escala {scale:.3f})")
        return
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
