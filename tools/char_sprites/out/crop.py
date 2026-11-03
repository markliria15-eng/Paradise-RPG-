import sys
from PIL import Image
src, dst, x0, y0, x1, y1 = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
Image.open(src).convert("RGB").crop((x0, y0, x1, y1)).save(dst, quality=92)
