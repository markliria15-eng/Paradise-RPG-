"""Recorta as folhas de montaria DE FRENTE e DE COSTAS (ChatGPT: 2 linhas x 8 colunas,
linha 1 de frente vindo para a camera, linha 2 de costas indo embora, sela vazia).

Cada pose e separada por mancha conectada (nada fica cortado), alinhada pelo centro e pelo
chao, e reduzida para a montaria ter a mesma altura no jogo que a vista de lado.

uso: python tools/mounts/recortar_montarias_frente_costas.py
Le:    tools/mounts/anim_fc/<code>.png
Grava: assets/sprites/mounts/<code>/walk_front/0-7.png, walk_back/0-7.png e
       idle_front/0.png, idle_back/0.png; em mounts_rig.json, <code>.front e <code>.back
       com frame, feet_y e seat (o "seat" ajustado a mao em SEAT_FC tem prioridade).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "sprites" / "mounts"
# mesma altura da vista de lado (recortar_animacao_montarias.py); de frente/costas a montaria
# fica um pouco mais baixa porque o corpo encurta na perspectiva
ALTURA_MUNDO = {"brown_horse": 205, "gray_wolf": 175, "war_boar": 175, "shadow_panther": 170, "crystal_stag": 235}
ENCURTA = 0.9
# assento (fracao da altura a partir do topo) de frente e de costas, ajustado olhando a arte
# de frente o cavaleiro fica atras da cabeca: o quadril dele vai perto do topo da cabeca/pescoco
SEAT_FC = {
    "brown_horse": {"front": 0.20, "back": 0.36},
    "gray_wolf": {"front": 0.22, "back": 0.36},
    "war_boar": {"front": 0.20, "back": 0.36},
    "shadow_panther": {"front": 0.24, "back": 0.36},
    "crystal_stag": {"front": 0.36, "back": 0.42},
}


def poses(sheet):
    try:
        return poses_by_blobs(sheet, 12)
    except SystemExit:
        # fumaca/brilho ligando as poses (pantera): acha os corpos so pelo pixel bem opaco e
        # corta cada linha nas colunas mais vazias entre eles
        return poses_by_cuts(sheet)


def poses_by_cuts(sheet):
    rgba = np.asarray(sheet)
    a = rgba[..., 3] > 12
    strong = rgba[..., 3] > 200
    out = {}
    half = sheet.height // 2
    for r, (y0, y1) in enumerate(((0, half), (half, sheet.height))):
        lab, n = ndimage.label(ndimage.binary_opening(strong[y0:y1], iterations=2))
        mass = ndimage.sum(strong[y0:y1], lab, range(1, n + 1))
        cents = ndimage.center_of_mass(strong[y0:y1], lab, range(1, n + 1))
        bodies = sorted([c[1] for c, m in zip(cents, mass) if m > max(mass) * 0.3])
        if len(bodies) != 8:
            raise SystemExit(f"linha {r}: esperava 8 corpos, achei {len(bodies)}")
        occ = a[y0:y1].sum(0)
        cuts = [0]
        for k in range(7):
            lo, hi = int(bodies[k]), int(bodies[k + 1])
            mid = lo + (hi - lo) // 4 + int(np.argmin(occ[lo + (hi - lo) // 4: hi - (hi - lo) // 4]))
            cuts.append(mid)
        cuts.append(sheet.width)
        for c in range(8):
            cell = rgba[y0:y1, cuts[c]:cuts[c + 1]]
            m = cell[..., 3] > 12
            ys, xs = np.nonzero(m)
            out[(r, c)] = Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy())
    return out


def poses_by_blobs(sheet, thr):
    a = np.asarray(sheet)[..., 3] > thr
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
    idx = range(1, n + 1)
    mass = ndimage.sum(a, lab, idx)
    centers = ndimage.center_of_mass(a, lab, idx)
    big = np.median(sorted(mass)[-16:])
    rows = {0: [], 1: []}
    small = []
    for k in range(n):
        if mass[k] >= big * 0.3:
            rows[0 if centers[k][0] < sheet.height / 2 else 1].append(k)
        else:
            small.append(k)
    for r in rows:
        rows[r].sort(key=lambda k: centers[k][1])
        if len(rows[r]) != 8:
            raise SystemExit(f"linha {r}: esperava 8 poses, achei {len(rows[r])}")
    ids = {(r, c): [k + 1] for r in rows for c, k in enumerate(rows[r])}
    for k in small:  # pedacinho solto (ponta de orelha, cauda) vai para a pose mais perto
        cy, cx = centers[k]
        best = min(ids, key=lambda rc: (centers[ids[rc][0] - 1][0] - cy) ** 2 + (centers[ids[rc][0] - 1][1] - cx) ** 2)
        ids[best].append(k + 1)
    rgba = np.asarray(sheet)
    out = {}
    for rc, labels in ids.items():
        m = np.isin(lab, labels) & (rgba[..., 3] > 0)
        ys, xs = np.nonzero(m)
        piece = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
        piece[..., 3] = np.where(m[ys.min():ys.max() + 1, xs.min():xs.max() + 1], piece[..., 3], 0)
        out[rc] = Image.fromarray(piece)
    return out


def remove_flat_background(sheet):
    """Algumas folhas vem com fundo branco/cinza em vez de transparente: apaga o fundo ligado
    as bordas (cor proxima da do canto) por preenchimento."""
    rgba = np.asarray(sheet).copy()
    if rgba[0, 0, 3] < 250:
        return sheet
    corner = rgba[:4, :4, :3].reshape(-1, 3).mean(0)
    diff = np.abs(rgba[..., :3].astype(int) - corner).max(-1)
    near = diff < 28
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # meia transparencia na borda do desenho para nao ficar serrilhado claro
    edge = ndimage.binary_dilation(bg) & ~bg & (diff < 60)
    rgba[..., 3] = np.where(bg, 0, np.where(edge, 128, rgba[..., 3]))
    return Image.fromarray(rgba)


def main():
    rig_path = OUT / "mounts_rig.json"
    rig = json.loads(rig_path.read_text(encoding="utf-8"))
    for src in sorted((HERE / "anim_fc").glob("*.png")):
        code = src.stem
        frames = poses(remove_flat_background(Image.open(src).convert("RGBA")))
        for r, view in ((0, "front"), (1, "back")):
            row = [frames[(r, c)] for c in range(8)]
            k = ALTURA_MUNDO.get(code, 170) * ENCURTA / max(f.height for f in row)
            row = [f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.LANCZOS) for f in row]
            # centro de cada pose pela metade de cima (cabeca/garupa), pes no chao
            centers = []
            for f in row:
                m = np.asarray(f)[..., 3] > 12
                ys, xs = np.nonzero(m[: int(m.shape[0] * 0.6)])
                centers.append(float(xs.mean()))
            left = max(centers)
            right = max(f.width - c for f, c in zip(row, centers))
            H = max(f.height for f in row) + 4
            W = int(np.ceil(left + right)) + 4
            frames_out = []
            for f, c in zip(row, centers):
                canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                canvas.alpha_composite(f, (int(round(2 + left - c)), H - 2 - f.height))
                frames_out.append(canvas)
            for anim, items in ((f"walk_{view}", frames_out), (f"idle_{view}", frames_out[:1])):
                d = OUT / code / anim
                d.mkdir(parents=True, exist_ok=True)
                for i, im in enumerate(items):
                    im.save(d / f"{i}.png", optimize=True)
            entry = rig.setdefault(code, {}).get(view, {})
            entry.update({"frame": [W, H], "feet_y": H - 2})
            frac = SEAT_FC.get(code, {}).get(view)
            if frac is not None:
                entry["seat"] = [round(2 + left, 1), round(H * frac, 1)]
            else:
                entry.setdefault("seat", [round(2 + left, 1), round(H * (0.42 if view == "front" else 0.36), 1)])
            rig[code][view] = entry
            print(code, view, W, "x", H, "seat", entry["seat"])
    rig_path.write_text(json.dumps(rig, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
