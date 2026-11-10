"""Recorta as folhas de animacao das montarias (ChatGPT: 8 colunas x 2 linhas, linha 1 parado,
linha 2 andando, de lado, viradas para a esquerda) em quadros soltos para o jogo.

Para cada quadro: corta na coluna/linha mais vazia perto da divisa nominal, apara pelo alfa,
alinha todos pelo chao (casco mais baixo) e pelo centro do tronco (parte de cima do corpo),
e reduz pelo mesmo fator para a montaria ter ALTURA_MUNDO px no jogo.

uso: python tools/mounts/recortar_animacao_montarias.py
Le:    tools/mounts/anim/<code>.png
Grava: assets/sprites/mounts/<code>/(idle|walk)/<0..7>.png
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "sprites" / "mounts"
COLS, ROWS = 8, 2
# altura (px no mundo) de cada montaria; o heroi tem ~119 px
ALTURA_MUNDO = {"brown_horse": 205, "gray_wolf": 175, "war_boar": 175, "shadow_panther": 170, "crystal_stag": 235}


def cut_positions(occ, n, search):
    size = len(occ)
    out = [0]
    for k in range(1, n):
        nom = round(k * size / n)
        lo, hi = max(out[-1] + 10, nom - search), min(size - 10, nom + search)
        seg = occ[lo:hi]
        best = np.flatnonzero(seg == seg.min())
        out.append(lo + int(best[np.argmin(np.abs(best + lo - nom))]))
    out.append(size)
    return out


def frames_of(sheet):
    a = np.asarray(sheet)[..., 3] > 12
    rows = cut_positions(a.sum(1), ROWS, sheet.height // 4)
    result = []
    for r in range(ROWS):
        band = a[rows[r]:rows[r + 1]]
        cols = cut_positions(band.sum(0), COLS, sheet.width // (COLS * 3))
        row = []
        for c in range(COLS):
            box = (cols[c], rows[r], cols[c + 1], rows[r + 1])
            cell = sheet.crop(box)
            m = np.asarray(cell)[..., 3] > 12
            ys, xs = np.nonzero(m)
            cell = cell.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            row.append(cell)
        result.append(row)
    return result


def seat_of(img):
    """Assento: centro e topo do pano azul da sela (azul bem saturado) no quadro parado."""
    a = np.asarray(img).astype(int)
    blue = (a[..., 3] > 100) & (a[..., 2] > a[..., 0] + 40) & (a[..., 2] > a[..., 1] + 15) & (a[..., 2] > 70)
    ys, xs = np.nonzero(blue)
    if len(xs) < 20:
        return None
    # so a mancha maior (o pano), sem o cabresto azul da cabeca: colunas perto da mediana
    med = np.median(xs)
    keep = np.abs(xs - med) < img.width * 0.2
    xs, ys = xs[keep], ys[keep]
    return float(np.median(xs)), float(np.percentile(ys, 5))


def anchor(img):
    """(x do centro do tronco, y do chao) dentro do quadro aparado."""
    m = np.asarray(img)[..., 3] > 12
    h = m.shape[0]
    top = m[: int(h * 0.6)]
    ys, xs = np.nonzero(top)
    return float(xs.mean()), float(h)


def main():
    rig = {}
    for src in sorted((HERE / "anim").glob("*.png")):
        code = src.stem
        sheet = Image.open(src).convert("RGBA")
        rows = frames_of(sheet)
        all_frames = [f for row in rows for f in row]
        ref_h = max(f.height for f in rows[0])  # altura parado
        k = ALTURA_MUNDO.get(code, 150) / ref_h
        scaled = [[f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.LANCZOS) for f in row] for row in rows]
        anchors = [[anchor(f) for f in row] for row in scaled]
        left = max(ax for row in anchors for ax, _ in row)
        right = max(f.width - ax for row, arow in zip(scaled, anchors) for f, (ax, _) in zip(row, arow))
        height = max(f.height for row in scaled for f in row)
        W, H = int(np.ceil(left + right)) + 4, height + 4
        for name, row, arow in zip(("idle", "walk"), scaled, anchors):
            d = OUT / code / name
            d.mkdir(parents=True, exist_ok=True)
            for i, (f, (ax, ay)) in enumerate(zip(row, arow)):
                canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                canvas.alpha_composite(f, (int(round(2 + left - ax)), int(H - 2 - ay)))
                canvas.save(d / f"{i}.png", optimize=True)
        rig[code] = {"frame": [W, H], "feet_y": H - 2, "center_x": round(2 + left, 1)}
        idle0 = Image.open(OUT / code / "idle" / "0.png")
        seat = seat_of(idle0)
        if seat:
            rig[code]["seat_auto"] = [round(seat[0], 1), round(seat[1], 1)]
        print(code, "quadro", W, "x", H)
    old = {}
    rig_path = OUT / "mounts_rig.json"
    if rig_path.exists():
        old = json.loads(rig_path.read_text(encoding="utf-8"))
    for code, data in rig.items():
        merged = old.get(code, {})
        merged.update(data)
        merged.setdefault("seat", data.get("seat_auto"))  # "seat" ajustado a mao tem prioridade
        old[code] = merged
    rig_path.write_text(json.dumps(old, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
