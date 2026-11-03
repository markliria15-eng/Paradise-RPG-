from PIL import Image
for n in ("01_pisos", "02_paredes", "03_objetos", "04_santuario", "05_selo_animado"):
    im = Image.open(f"assets/maps/ruinas_v2/sheets/{n}.png").convert("RGBA")
    bg = Image.new("RGBA", im.size, (60, 120, 60, 255)); bg.alpha_composite(im)
    bg.convert("RGB").resize((800, 800)).save(f"tools/char_sprites/out/ruin_{n}.jpg", quality=86)
