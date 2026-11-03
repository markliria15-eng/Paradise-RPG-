from PIL import Image
for cls in ("maga_de_fogo",):
    im = Image.open(f"tools/char_sprites/out/preview_folhas_{cls}.png").convert("RGB")
    w = im.width // 5
    for i, n in enumerate(("parado", "andar", "ataque", "dano", "morte")):
        im.crop((i * w, 0, (i + 1) * w, im.height)).save(f"tools/char_sprites/out/pv_{cls}_{n}.png")
