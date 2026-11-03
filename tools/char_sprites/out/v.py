import sys
from PIL import Image
src, dst, w = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGBA")
bg = Image.new("RGBA", im.size, (40, 70, 40, 255)); bg.alpha_composite(im)
bg.convert("RGB").resize((w, round(im.height * w / im.width))).save(dst, quality=88)
