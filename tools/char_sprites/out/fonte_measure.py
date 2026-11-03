import numpy as np
from PIL import Image
im = np.array(Image.open("assets/maps/eldoria_v2/sheets/eldoria_fonte.png").convert("RGBA"))
for i in range(4):
    r, c = divmod(i, 2)
    a = im[r*512:(r+1)*512, c*512:(c+1)*512, 3] > 40
    ys, xs = np.nonzero(a)
    low = a[int(ys.min() + (ys.max()-ys.min())*0.5):]
    lys, lxs = np.nonzero(low)
    print(i, "bbox", xs.min(), ys.min(), xs.max(), ys.max(), "base x", lxs.min(), lxs.max())
