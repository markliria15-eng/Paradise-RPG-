import numpy as np
from PIL import Image
import sys
sys.path.insert(0, "tools/char_sprites")
from generate_player_sheets import largest_parts
root = "assets/sprites/player_frames_caminhada_classes"
for cls in ("guerreiro", "arqueiro"):
    for anim in ("parado", "andar", "ataque", "dano", "morte"):
        im = np.array(Image.open(f"{root}/{cls}/fontes/{cls}_{anim}.png").convert("RGBA"))
        cs = im.shape[0] // 4
        print(cls, anim, "cell", cs)
        for r in range(4):
            row = []
            for c in range(4):
                cell = im[r*cs:(r+1)*cs, c*cs:(c+1)*cs]
                a = cell[:, :, 3] > 40
                ys, xs = np.nonzero(a)
                top, bot = ys.min(), ys.max()
                head = a[top:top + max(4, int((bot - top) * 0.14))]
                _, hx = np.nonzero(head)
                edge = (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any())
                row.append(f"h{bot-top+1:3d} b{bot:3d} hx{hx.mean():5.0f} x{xs.min():3d}-{xs.max():3d}{' EDGE' if edge else ''}")
            print("  ", " | ".join(row))
