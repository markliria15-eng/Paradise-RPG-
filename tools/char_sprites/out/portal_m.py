import numpy as np
from PIL import Image
for t in ("floresta", "caverna", "ruina"):
    for l in ("base", "magia", "aura_tras", "aura_frente"):
        a = np.array(Image.open(f"assets/portals_v2/{t}/{l}.png").convert("RGBA"))[:, :, 3] > 30
        ys, xs = np.nonzero(a)
        print(t, l, "x", xs.min(), xs.max(), "y", ys.min(), ys.max())
