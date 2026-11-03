from PIL import Image
import sys
p = sys.argv[1] if len(sys.argv) > 1 else "fountain"
fr = [Image.open(f"assets/maps/eldoria_v2/props/{p}_{i}.png").convert("RGBA") for i in range(4)]
w, h = fr[0].size
out = Image.new("RGBA", (w * 4, h), (70, 110, 70, 255))
for i, f in enumerate(fr):
    out.alpha_composite(f, (i * w, 0))
out.convert("RGB").resize((w * 2, h // 2)).save(f"tools/char_sprites/out/{p}_strip.jpg", quality=90)
