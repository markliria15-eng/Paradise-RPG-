import numpy as np
from PIL import Image
for n in ("pisos", "muralha", "objetos", "fonte"):
    im = Image.open(f"assets/maps/eldoria_v2/sheets/eldoria_{n}.png").convert("RGBA")
    a = np.array(im)
    print(n, im.size, "transp", round(float((a[:, :, 3] < 20).mean()), 2))
    bg = Image.new("RGBA", im.size, (255, 0, 255, 255) if n != "pisos" else (0, 0, 0, 255)); bg.alpha_composite(im)
    bg.convert("RGB").resize((900, 900)).save(f"tools/char_sprites/out/eld_{n}.jpg", quality=88)
