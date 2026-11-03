import numpy as np
from PIL import Image
im = Image.open("assets/maps/eldoria_v2/sheets/eldoria_tiles_v1.png")
a = np.array(im.convert("RGBA"))
print(im.size, im.mode, "transp", round(float((a[:, :, 3] < 20).mean()), 2), "corner", tuple(int(v) for v in a[2, 2]))
w = 1600
im.convert("RGB").resize((w, round(im.height * w / im.width))).save("tools/char_sprites/out/eldoria_sheet_view.jpg", quality=88)
