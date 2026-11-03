import numpy as np
from PIL import Image
names = ["sarah_curandeira", "arion_mestre_classes", "bakka_ferreiro", "borin_mercador", "guarda_doran"]
tiles = []
for n in names:
    im = Image.open(f"assets/characters/npcs/fontes/npc_{n}_parado.png").convert("RGBA")
    a = np.array(im)
    print(n, im.size, "transp", round(float((a[:, :, 3] < 20).mean()), 2), "corner", tuple(int(v) for v in a[2, 2]))
    bg = Image.new("RGBA", im.size, (70, 110, 70, 255)); bg.alpha_composite(im)
    tiles.append(bg.convert("RGB").resize((400, 400)))
out = Image.new("RGB", (400 * len(tiles), 400))
for i, t in enumerate(tiles):
    out.paste(t, (i * 400, 0))
out.save("tools/char_sprites/out/npc_fontes.jpg", quality=85)
