"""Anima por codigo os efeitos que vieram quase parados no pacote de Valdoria.

- Fonte de Poseidon: a agua da concha cai (rola para baixo) e o espelho d'agua ondula
  a partir do ponto em que a cascata bate. 6 quadros, volta sem emenda.
- Lampiao e forno: a chama/brasa pulsa de brilho (os quadros do pacote quase nao mudavam).

uso: python animar_efeitos.py <pasta_do_pacote>/animacoes <pasta_saida>
Grava (nomes no padrao de tools/valdoria_v2/fonte_anim):
  valdoria_fountain_flow_none_6f_512x512.png
  valdoria_gas_lamp_flicker_none_4f_128x320.png
  valdoria_furnace_glow_none_4f_480x480.png
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

# ---------- fonte ----------
f0 = np.asarray(Image.open(src / "valdoria-fountain-animation-fixed.png").convert("RGBA").crop((0, 0, 512, 512))).astype(np.float32)
r, g, b, a = f0[..., 0], f0[..., 1], f0[..., 2], f0[..., 3]
water = (a > 40) & (g > r + 25) & (b > r + 20)
H, W = water.shape
yy, xx = np.mgrid[0:H, 0:W]
col = water & (yy < 318) & (xx > 190) & (xx < 290)      # cascata
basin = water & ~col                                      # espelho d'agua
IMPACT = (238, 330)
N = 6
frames = []
for i in range(N):
    fr = f0.copy()
    # cascata: rola a textura para baixo dentro da faixa de agua de cada coluna
    for x in range(191, 290):
        ys = np.nonzero(col[:, x])[0]
        if len(ys) < 6:
            continue
        y0, y1 = ys.min(), ys.max() + 1
        L = y1 - y0
        s = int(round(i * L / N))
        seg = f0[y0:y1, x].copy()
        rolled = np.roll(seg, s, axis=0)
        m = col[y0:y1, x]
        fr[y0:y1, x][m] = rolled[m]
    # espelho d'agua: aneis de brilho saindo do ponto de impacto
    d = np.hypot(xx - IMPACT[0], (yy - IMPACT[1]) * 1.9)
    k = 1.0 + 0.16 * np.sin(d / 7.0 - 2 * np.pi * i / N)
    for c in range(3):
        ch = fr[..., c]
        ch[basin] = np.clip(ch[basin] * k[basin], 0, 255)
    frames.append(fr.astype(np.uint8))
sheet = np.concatenate(frames, axis=1)
Image.fromarray(sheet, "RGBA").save(out / "valdoria_fountain_flow_none_6f_512x512.png", optimize=True)

# ---------- brilho de lampiao e forno ----------
def pulse(name, n, fw, fh, factors, test):
    im = np.asarray(Image.open(src / name).convert("RGBA")).astype(np.float32)
    outf = []
    for i in range(n):
        fr = im[:, i * fw:(i + 1) * fw].copy()
        m = test(fr)
        for c in range(3):
            ch = fr[..., c]
            ch[m] = np.clip(ch[m] * factors[i], 0, 255)
        outf.append(fr.astype(np.uint8))
    Image.fromarray(np.concatenate(outf, axis=1), "RGBA").save(out / name, optimize=True)

warm = lambda fr: (fr[..., 3] > 40) & (fr[..., 0] > 190) & (fr[..., 1] > 120) & (fr[..., 0] > fr[..., 2] + 60)
ember = lambda fr: (fr[..., 3] > 40) & (fr[..., 0] > 170) & (fr[..., 0] > fr[..., 2] + 80)
pulse("valdoria_gas_lamp_flicker_none_4f_128x320.png", 4, 128, 320, [1.0, 0.8, 1.1, 0.88], warm)
pulse("valdoria_furnace_glow_none_4f_480x480.png", 4, 480, 480, [1.0, 0.82, 1.12, 0.9], ember)
print("ok", int(col.sum()), "px de cascata,", int(basin.sum()), "px de espelho")
