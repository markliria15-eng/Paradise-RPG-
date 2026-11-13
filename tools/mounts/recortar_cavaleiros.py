"""Recorta o heroi MONTADO (gerado no ChatGPT: so o cavaleiro, sentado com uma perna de cada
lado, de lado virado para a esquerda, 4 quadros numa linha) para cada classe.

Saida: assets/sprites/mounts/riders/<classe>/0-3.png (ja no tamanho do jogo, escala 1)
       assets/sprites/mounts/riders/riders.json -> {classe: {"frame": [w, h], "seat": [x, y]}}
"seat" e o ponto do quadril que encosta na sela; main.gd (_update_mount_rider) o coloca
sobre o "seat" da montaria (mounts_rig.json).

Os 4 quadros do ChatGPT variam um pouco de tamanho e posicao: cada um e ajustado ao
quadro 1 pelas pernas (escala + deslocamento), assim so o tronco/capa balancam.

uso: python tools/mounts/recortar_cavaleiros.py tools/mounts/cavaleiros
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites" / "mounts" / "riders"
# por classe: arquivo, quadril na sela e topo da cabeca no QUADRO 1 (coordenadas do recorte)
CLASSES = {
    "guerreiro": ("paradise_cavaleiro_guerreiro_v1.png", (185, 370), 5),
    "maga_de_fogo": ("paradise_cavaleiro_maga_v1.png", (160, 425), 45),
    "arqueiro": ("paradise_cavaleiro_arqueiro_v1.png", (195, 415), 40),
}
# de frente e de costas (folha 2 linhas x 4: linha 1 de frente, linha 2 de costas):
# por vista, quadril na sela e topo da cabeca no quadro 1 da linha (coordenadas do recorte)
CLASSES_FC = {
    "guerreiro": ("paradise_cavaleiro_guerreiro_fc_v1.png", {"front": ((150, 270), 5), "back": ((137, 255), 2)}),
    "maga_de_fogo": ("paradise_cavaleiro_maga_fc_v1.png", {"front": ((150, 255), 15), "back": ((153, 250), 22)}),
    "arqueiro": ("paradise_cavaleiro_arqueiro_fc_v1.png", {"front": ((130, 250), 5), "back": ((130, 245), 5)}),
}
# PROVISORIO enquanto a arte de frente/costas montada nao vem do ChatGPT: a metade de cima do
# heroi em pe (de frente/costas), cortada no quadril. De frente o corte fica escondido atras da
# cabeca da montaria; de costas fica sobre a sela. (quadril y, topo da cabeca y no quadro 192)
HERO_TORSO = {
}
HERO_FRAMES = ROOT / "assets" / "sprites" / "player_frames_caminhada_classes"
HEAD_TO_SEAT = 71.0  # px no jogo do topo da cabeca ao quadril (heroi em pe tem ~105 px)
PAD = 2


def clean_background(im: Image.Image) -> Image.Image:
    """Fundo branco, cinza ou xadrez "falso" desenhado: apaga o que e claro e sem cor ligado as bordas."""
    a = np.asarray(im).copy()
    if a[0, 0, 3] < 250:
        return im
    rgb = a[..., :3].astype(int)
    cand = (rgb.max(-1) - rgb.min(-1) < 20) & (rgb.min(-1) > 185)
    lab, _ = ndimage.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    a[..., 3] = np.where(np.isin(lab, list(border)), 0, a[..., 3])
    return Image.fromarray(a)


def pieces(path: Path, rows: int = 1):
    im = clean_background(Image.open(path).convert("RGBA"))
    a = np.asarray(im)[..., 3] > 12
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=3))
    mass = ndimage.sum(a, lab, range(1, n + 1))
    objs = [o for o, m in zip(ndimage.find_objects(lab), mass) if m > 2000]
    if len(objs) != 4 * rows:
        raise SystemExit(f"{path.name}: esperava {4 * rows} quadros, achei {len(objs)}")
    objs.sort(key=lambda o: (int((o[0].start + o[0].stop) / 2 // (im.height / rows)), o[1].start))
    return [im.crop((o[1].start, o[0].start, o[1].stop, o[0].stop)) for o in objs]


def legs_mask(im: Image.Image, k: float, frac: float = 0.45) -> np.ndarray:
    a = np.asarray(im.getchannel("A")) > 40
    a[: int(a.shape[0] * (1 - frac))] = False
    small = Image.fromarray(a.astype(np.uint8) * 255).resize(
        (max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BILINEAR)
    return np.asarray(small) > 127


def register(ref: Image.Image, im: Image.Image):
    """Escala e deslocamento (no espaco do ref) que melhor encaixam as pernas de im nas do ref."""
    q = 0.25
    r = legs_mask(ref, q)
    best = (-1.0, 1.0, 0, 0)
    for sc in np.arange(0.90, 1.105, 0.01):
        m = legs_mask(im, q * sc)
        H, W = r.shape[0] + 40, r.shape[1] + 40
        base = np.zeros((H, W), bool)
        base[20:20 + r.shape[0], 20:20 + r.shape[1]] = r
        for dy in range(-20, 21):
            for dx in range(-20, 21):
                y0 = 20 + dy + (r.shape[0] - m.shape[0])  # alinha pelo pe (base da imagem)
                x0 = 20 + dx
                if y0 < 0 or x0 < 0 or y0 + m.shape[0] > H or x0 + m.shape[1] > W:
                    continue
                inter = (base[y0:y0 + m.shape[0], x0:x0 + m.shape[1]] & m).sum()
                union = r.sum() + m.sum() - inter
                iou = inter / max(1, union)
                if iou > best[0]:
                    best = (iou, sc, dx / q, (dy + (r.shape[0] - m.shape[0])) / q)
    return best


def build_torso(cls: str, view: str):
    hip, head = HERO_TORSO[cls][view]
    im = Image.open(HERO_FRAMES / cls / "frames_192" / f"{cls}_idle_{view}.png").convert("RGBA")
    a = np.asarray(im).copy()
    a[hip + 6:, :, 3] = 0
    for k in range(6):  # some aos poucos no quadril
        a[hip + k, :, 3] = (a[hip + k, :, 3] * (1 - (k + 1) / 7)).astype(np.uint8)
    body = a[head + 30:hip, :, 3] > 40
    cx = float(np.nonzero(body)[1].mean())
    s = HEAD_TO_SEAT / (hip - head)
    torso = Image.fromarray(a)
    bb = torso.getbbox()
    torso = torso.crop(bb)
    small = torso.resize((max(1, round(torso.width * s)), max(1, round(torso.height * s))), Image.LANCZOS)
    W, H = small.width + 2 * PAD, small.height + 2 * PAD + 2
    folder = OUT / cls / view
    folder.mkdir(parents=True, exist_ok=True)
    for i, bob in enumerate((1, 0, 1, 2)):
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.paste(small, (PAD, PAD + bob), small)
        canvas.save(folder / f"{i}.png", optimize=True)
    return {"frame": [W, H], "seat": [round((cx - bb[0]) * s + PAD, 1), round((hip - bb[1]) * s + PAD + 1, 1)],
            "head_y": round((head - bb[1]) * s + PAD + 1, 1), "provisorio": True}


def build(cls: str, src: Path):
    fname, seat, head_top = CLASSES[cls]
    return build_row(cls, pieces(src / fname), seat, head_top, OUT / cls)


def build_row(cls: str, frames, seat, head_top, folder: Path):
    ref = frames[0]
    s = HEAD_TO_SEAT / (seat[1] - head_top)
    placed = [(ref, 1.0, 0.0, 0.0)]
    for im in frames[1:]:
        iou, sc, dx, dy = register(ref, im)
        print(f"  {cls}: encaixe pernas iou={iou:.2f} escala={sc:.2f} dx={dx:.0f} dy={dy:.0f}")
        placed.append((im, sc, dx, dy))
    # caixa comum (no espaco do quadro 1)
    x0 = min(dx for _, _, dx, _ in placed)
    y0 = min(dy for _, _, _, dy in placed)
    x1 = max(dx + im.width * sc for im, sc, dx, _ in placed)
    y1 = max(dy + im.height * sc for im, sc, _, dy in placed)
    W = int(np.ceil((x1 - x0) * s)) + 2 * PAD
    H = int(np.ceil((y1 - y0) * s)) + 2 * PAD
    folder.mkdir(parents=True, exist_ok=True)
    for i, (im, sc, dx, dy) in enumerate(placed):
        k = sc * s
        small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.paste(small, (round((dx - x0) * s) + PAD, round((dy - y0) * s) + PAD), small)
        canvas.save(folder / f"{i}.png", optimize=True)
    seat_out = [round((seat[0] - x0) * s + PAD, 1), round((seat[1] - y0) * s + PAD, 1)]
    head_out = round((head_top - y0) * s + PAD, 1)
    return {"frame": [W, H], "seat": seat_out, "head_y": head_out}


if __name__ == "__main__":
    src = Path(sys.argv[1])
    data = {cls: build(cls, src) for cls in CLASSES}
    for cls, views in HERO_TORSO.items():
        for view in views:
            data[cls][view] = build_torso(cls, view)
    for cls, (fname, views) in CLASSES_FC.items():
        if not (src / fname).exists():
            continue
        frames = pieces(src / fname, rows=2)
        for r, view in enumerate(("front", "back")):
            seat, head_top = views[view]
            data[cls][view] = build_row(cls, frames[r * 4:(r + 1) * 4], seat, head_top, OUT / cls / view)
    (OUT / "riders.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(data))
