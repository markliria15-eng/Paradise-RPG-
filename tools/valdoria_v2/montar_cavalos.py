"""Troca os cavalos desenhados dentro das folhas de veiculos de Valdoria pelos cavalos
avulsos do mesmo pacote, que tem trote/passo de verdade (patas sobem e descem).

Os cavalos embutidos nas folhas valdoria_<veiculo>_move_* so ondulavam as pernas.
Para cada quadro: apaga a regiao dos cavalos antigos do veiculo, redimensiona o
quadro correspondente da folha de cavalos para o mesmo tamanho dos antigos
(mesma linha dos cascos e mesma frente) e junta os dois.

uso: python tools/valdoria_v2/montar_cavalos.py      (depois rode generate_valdoria_v2.py)
Le:    tools/valdoria_v2/fonte_anim/originais/valdoria_<veiculo>_(move|idle)_<dir>_*.png (pacote)
       tools/valdoria_v2/fonte_anim/cavalos/valdoria_horses_<time>_(trot|walk|idle)_<dir>_*.png (pacote)
Grava: tools/valdoria_v2/fonte_anim/valdoria_<veiculo>_(move|idle)_<dir>_*.png (lidas pelo gerador)
"""
import re
import sys
from pathlib import Path
import numpy as np
from PIL import Image

_FA = Path(__file__).resolve().parent / "fonte_anim"
ORIG, HORSES, OUT = (Path(p) for p in sys.argv[1:4]) if len(sys.argv) > 3 else (_FA / "originais", _FA / "cavalos", _FA)
OUT.mkdir(parents=True, exist_ok=True)

# veiculo -> (time de cavalos, passo usado em move, corte por direcao)
# corte: left = x a partir do qual fica so o veiculo; down/up = y que separa cavalos e veiculo
VEHICLES = {
    "carriage_luxury": ("carriage", "trot", {"left": 372, "down": 579, "up": 285}),
    "cart_worker": ("cart", "trot", {"left": 398, "down": 377, "up": 285}),
    "wagon_cargo": ("wagon", "walk", {"left": 402, "down": 638, "up": 285}),
}


OVERLAP = 14  # px que a traseira entra por baixo do veiculo
UP_TUCK = 110  # vista de costas: px dos cascos escondidos atras do veiculo


def sheet(folder, pattern):
    path = next(folder.glob(pattern + "_*f_*x*.png"))
    n, fw, fh = map(int, re.search(r"_(\d+)f_(\d+)x(\d+)\.png$", path.name).groups())
    im = Image.open(path).convert("RGBA")
    return path.name, [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(n)], (fw, fh)


def steady(frames):
    """Tira o pulinho de 1-2 px do veiculo entre quadros (alinha cada quadro ao primeiro)."""
    ref = np.asarray(frames[0]).astype(np.float32)
    rc = ref[..., :3] * ref[..., 3:] / 255
    out = []
    for fr in frames:
        a = np.asarray(fr)
        best = min(range(-3, 4), key=lambda dy: np.abs(rc - (lambda b: b[..., :3] * b[..., 3:] / 255)(np.roll(a, dy, 0).astype(np.float32))).mean())
        out.append(Image.fromarray(np.roll(a, best, 0), "RGBA"))
    return out


def bbox(a, mask_cols=None):
    al = a[..., 3] > 30
    if mask_cols is not None:
        al = al & mask_cols
    ys, xs = np.nonzero(al)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def side(vehicle, team, gait, cut, anim, flip):
    """anim: 'move' ou 'idle'. Monta a folha virada para a esquerda e espelha se flip."""
    name, frames, (fw, fh) = sheet(ORIG, f"valdoria_{vehicle}_{anim}_left")
    frames = steady(frames)
    _, hfr, _ = sheet(HORSES, f"valdoria_horses_{team}_{gait if anim == 'move' else 'idle'}_left")
    a0 = np.asarray(frames[0])
    cols = np.zeros(a0.shape[:2], bool)
    cols[:, : cut - 60] = True
    ox0, oy0, ox1, oy1 = bbox(a0, cols)           # cavalos antigos (sem as redeas perto do cocheiro)
    h0 = np.asarray(hfr[0])
    hx0, hy0, hx1, hy1 = bbox(h0)
    s = (oy1 - oy0) / (hy1 - hy0)
    # traseira do corpo dos cavalos (sem os varais finos): colunas com bastante pixel opaco
    colsum = (h0[..., 3] > 30).sum(axis=0)
    body_cols = np.nonzero(colsum > 0.18 * (hy1 - hy0))[0]
    rear = body_cols.max() + 1
    out = []
    for i, fr in enumerate(frames):
        body = np.asarray(fr).copy()
        body[:, :cut] = 0
        hf = hfr[i % len(hfr)]
        hs = hf.resize((max(1, round(hf.width * s)), max(1, round(hf.height * s))), Image.LANCZOS)
        canvas = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        # traseira dos cavalos encostada na frente do veiculo e mesma linha dos cascos
        px = round(cut + OVERLAP - rear * s)
        py = round(oy1 - hy1 * s)
        canvas.alpha_composite(hs, (max(0, px), max(0, py)), (max(0, -px), max(0, -py)))
        canvas.alpha_composite(Image.fromarray(body, "RGBA"))
        out.append(canvas.transpose(Image.FLIP_LEFT_RIGHT) if flip else canvas)
    dest = name.replace("_left_", "_right_") if flip else name
    save(out, fw, fh, dest)
    return dest, s


def save(frames, fw, fh, dest):
    strip = Image.new("RGBA", (fw * len(frames), fh))
    for i, c in enumerate(frames):
        strip.paste(c, (i * fw, 0))
    strip.save(OUT / dest, optimize=True)


def vertical(vehicle, team, gait, cut, direction, s):
    """Vista de frente (down: cavalos na frente, por cima) ou de costas (up: cavalos atras).
    Usa a mesma escala da vista lateral; centraliza no time antigo."""
    name, frames, (fw, fh) = sheet(ORIG, f"valdoria_{vehicle}_move_{direction}")
    frames = steady(frames)
    _, hfr, _ = sheet(HORSES, f"valdoria_horses_{team}_{gait}_{direction}")
    a0 = np.asarray(frames[0])
    # espaco extra em cima para as cabecas dos cavalos maiores nao serem cortadas (so na vista de costas)
    hs0 = hfr[0]
    pad = 0 if direction == "down" else max(0, round(hs0.height * s) - (cut + UP_TUCK) + 8)
    rows = np.zeros(a0.shape[:2], bool)
    if direction == "down":
        rows[cut:] = True
    else:
        rows[:cut] = True
    ox0, oy0, ox1, oy1 = bbox(a0, rows)
    cx = (ox0 + ox1) / 2
    h0 = np.asarray(hfr[0])
    hx0, hy0, hx1, hy1 = bbox(h0)
    out = []
    for i, fr in enumerate(frames):
        body = np.asarray(fr).copy()
        hf = hfr[i % len(hfr)]
        hs = hf.resize((max(1, round(hf.width * s)), max(1, round(hf.height * s))), Image.LANCZOS)
        px = round(cx - (hx0 + hx1) / 2 * s)
        canvas = Image.new("RGBA", (fw, fh + pad), (0, 0, 0, 0))
        if direction == "down":
            body[cut:] = 0
            py = round(oy1 - hy1 * s) + pad      # cascos na mesma linha
            canvas.alpha_composite(Image.fromarray(body, "RGBA"), (0, pad))
            canvas.alpha_composite(hs, (max(0, px), max(0, py)), (max(0, -px), max(0, -py)))
        else:
            body[:cut] = 0
            py = round(cut + UP_TUCK - hy1 * s) + pad   # cascos escondidos atras do veiculo
            canvas.alpha_composite(hs, (max(0, px), max(0, py)), (max(0, -px), max(0, -py)))
            canvas.alpha_composite(Image.fromarray(body, "RGBA"), (0, pad))
        out.append(canvas)
    dest = re.sub(r"_\d+x\d+\.png$", f"_{fw}x{fh + pad}.png", name)
    save(out, fw, fh + pad, dest)
    return dest


if __name__ == "__main__":
    for vehicle, (team, gait, cuts) in VEHICLES.items():
        for anim in ("move", "idle"):
            for flip in (False, True):
                dest, s = side(vehicle, team, gait, cuts["left"], anim, flip)
                print(dest)
        for direction in ("down", "up"):
            print(vertical(vehicle, team, gait, cuts[direction], direction, s))
