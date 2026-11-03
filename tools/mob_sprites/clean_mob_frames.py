"""Limpa e alinha os frames empacotados dos mobs em assets/sprites/mobs/<mob>/.

Problemas que corrige (frames recortados de folhas geradas por IA):
- numeros/rotulos ("1", "2", "WALK", "HIT") e pedacos do frame vizinho;
- frames vazios ou quebrados (descartados e renumerados);
- corpo "pulando" entre frames: todos os frames do mob sao alinhados pela base
  (pes) e pelo centro de massa horizontal, no mesmo canvas, o que elimina o
  efeito de piscar/tremer ao andar.

A arte atual e so lateral (front/back/left/right sao copias). O script le a
direcao `left` de cada animacao e grava o resultado nas 4 direcoes, mantendo o
padrao de caminho lido por scripts/enemy.gd:
  <mob>/<anim>_<dir>/<mob>_<anim>_<dir>_NN.png

Uso (raiz do repo):
  py -I tools/mob_sprites/clean_mob_frames.py --dry-run javali_selvagem
  py -I tools/mob_sprites/clean_mob_frames.py javali_selvagem lobo_selvagem
  # reprocessar a partir dos originais do Git sem tocar no working tree:
  #   git archive HEAD assets/sprites/mobs | tar -x -C <tmp>
  py -I tools/mob_sprites/clean_mob_frames.py --source <tmp>/assets/sprites/mobs lobo_selvagem
Os PNGs originais estao versionados no Git; revise o diff antes de commitar.
"""
import argparse
import glob
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MOBS_DIR = os.path.join(ROOT, "assets", "sprites", "mobs")
SOURCE_DIR = MOBS_DIR  # --source: le frames de outra pasta (ex.: export do HEAD)
DIRECTIONS = ["front", "back", "left", "right"]
ALPHA_MIN = 24
BASELINE_MARGIN = 8  # pixels livres abaixo dos pes no canvas
MIN_AREA_RATIO = 0.4  # frame com corpo menor que isso (vs maior frame da animacao) e descartado


def label_components(mask):
    """Rotula componentes 8-conectados (sem scipy)."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    current = 0
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if labels[sy, sx]:
            continue
        current += 1
        stack = [(sy, sx)]
        labels[sy, sx] = current
        while stack:
            y, x = stack.pop()
            for dy in (-1, 0, 1):
                ny = y + dy
                if ny < 0 or ny >= h:
                    continue
                for dx in (-1, 0, 1):
                    nx = x + dx
                    if 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = current
                        stack.append((ny, nx))
    return labels, current


def isolate_body(rgba):
    """Mantem o maior componente e as partes soltas que o tocam (pelos, cauda)."""
    alpha = rgba[:, :, 3]
    mask = alpha >= ALPHA_MIN
    if not mask.any():
        return None, 0
    labels, count = label_components(mask)
    areas = np.bincount(labels.ravel())[1:]
    main = int(np.argmax(areas)) + 1
    main_ys, main_xs = np.nonzero(labels == main)
    top, bottom = main_ys.min(), main_ys.max()
    left, right = main_xs.min(), main_xs.max()
    keep = labels == main
    main_area = int(areas[main - 1])
    for comp in range(1, count + 1):
        if comp == main:
            continue
        cys, cxs = np.nonzero(labels == comp)
        inside = cys.min() >= top and cys.max() <= bottom and cxs.min() >= left and cxs.max() <= right
        touches = not (cys.max() < top or cys.min() > bottom or cxs.max() < left or cxs.min() > right)
        # Numeros embaixo, rotulos e pedacos do frame vizinho ficam fora da caixa
        # do corpo; so partes soltas dentro dela (ou grandes e encostadas) ficam.
        if inside or (touches and areas[comp - 1] >= main_area * 0.03 and cys.mean() <= bottom):
            keep |= labels == comp
    out = rgba.copy()
    out[~keep] = 0
    # Remove franja semi-transparente isolada fora do corpo.
    out[(out[:, :, 3] < ALPHA_MIN)] = 0
    return out, int(areas[main - 1])


def frame_anchor(rgba):
    ys, xs = np.nonzero(rgba[:, :, 3] >= ALPHA_MIN)
    weights = rgba[ys, xs, 3].astype(np.float64)
    cx = float((xs * weights).sum() / weights.sum())
    return cx, int(ys.max())


def place(rgba, cx, bottom, canvas_w, canvas_h):
    canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    dx = int(round(canvas_w / 2.0 - cx))
    dy = (canvas_h - 1 - BASELINE_MARGIN) - bottom
    h, w = rgba.shape[:2]
    src_y0, src_x0 = max(0, -dy), max(0, -dx)
    dst_y0, dst_x0 = max(0, dy), max(0, dx)
    hh = min(h - src_y0, canvas_h - dst_y0)
    ww = min(w - src_x0, canvas_w - dst_x0)
    if hh > 0 and ww > 0:
        canvas[dst_y0:dst_y0 + hh, dst_x0:dst_x0 + ww] = rgba[src_y0:src_y0 + hh, src_x0:src_x0 + ww]
    return canvas


def animations_for(mob):
    names = set()
    for d in glob.glob(os.path.join(SOURCE_DIR, mob, "*_left")):
        if os.path.isdir(d):
            names.add(os.path.basename(d)[: -len("_left")])
    return sorted(names)


def load_frames(mob, anim):
    pattern = os.path.join(SOURCE_DIR, mob, f"{anim}_left", f"{mob}_{anim}_left_*.png")
    return [np.array(Image.open(p).convert("RGBA")) for p in sorted(glob.glob(pattern))]


def process_mob(mob, dry_run):
    report = []
    cleaned = {}
    canvas_w = canvas_h = None
    for anim in animations_for(mob):
        frames = load_frames(mob, anim)
        if not frames:
            continue
        canvas_h, canvas_w = frames[0].shape[:2]
        bodies = [isolate_body(f) for f in frames]
        areas = [a for _, a in bodies if a > 0]
        largest = float(max(areas)) if areas else 0.0
        kept = [b for b, a in bodies if b is not None and a >= largest * MIN_AREA_RATIO]
        cleaned[anim] = kept
        report.append(f"  {anim}: {len(frames)} -> {len(kept)} frames")
    if not cleaned:
        return [f"{mob}: nenhuma animacao encontrada"]
    # Todo frame vai para a mesma base (pes) e o mesmo centro de massa horizontal,
    # em todas as animacoes: trocar idle/walk/attack nao faz o mob pular.
    for anim, kept in cleaned.items():
        if not kept:
            report.append(f"  AVISO {anim}: todos os frames descartados; mantendo originais")
            continue
        cleaned[anim] = [place(f, *frame_anchor(f), canvas_w, canvas_h) for f in kept]
    if dry_run:
        return [f"{mob} (dry-run):"] + report
    for anim, frames in cleaned.items():
        if not frames:
            continue
        for direction in DIRECTIONS:
            folder = os.path.join(MOBS_DIR, mob, f"{anim}_{direction}")
            if not os.path.isdir(folder):
                continue
            old = sorted(glob.glob(os.path.join(folder, f"{mob}_{anim}_{direction}_*.png")))
            for i, frame in enumerate(frames, start=1):
                Image.fromarray(frame, "RGBA").save(os.path.join(folder, f"{mob}_{anim}_{direction}_{i:02d}.png"))
            for path in old[len(frames):]:
                os.remove(path)
                if os.path.exists(path + ".import"):
                    os.remove(path + ".import")
    return [f"{mob}:"] + report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mobs", nargs="+")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--source", help="pasta equivalente a assets/sprites/mobs com os frames originais")
    args = parser.parse_args()
    global SOURCE_DIR
    if args.source:
        SOURCE_DIR = os.path.abspath(args.source)
    for mob in args.mobs:
        if not os.path.isdir(os.path.join(MOBS_DIR, mob)):
            print(f"{mob}: pasta nao encontrada", file=sys.stderr)
            continue
        print("\n".join(process_mob(mob, args.dry_run)))


if __name__ == "__main__":
    main()
