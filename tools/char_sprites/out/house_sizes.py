import json
import numpy as np
from PIL import Image
kit = json.load(open("data/eldoria_house_kit.json", encoding="utf-8"))
seen = set()
for h in kit["houses"]:
    p = h["texture_path"].replace("res://", "")
    if p in seen:
        continue
    seen.add(p)
    im = Image.open(p).convert("RGBA")
    a = np.array(im)[:, :, 3] > 40
    ys, xs = np.nonzero(a)
    s = h["visual_scale"]; ax, ay = h["anchor"]
    cr = h["collision_rects"]
    cx0 = min(r["x"] for r in cr); cx1 = max(r["x"] + r["w"] for r in cr)
    cy0 = min(r["y"] for r in cr); cy1 = max(r["y"] + r["h"] for r in cr)
    print(h["id"], im.size, "scale", s, "anchor", (ax, ay),
          "visivel rel anchor x", round((xs.min()-ax)*s), round((xs.max()-ax)*s), "y", round((ys.min()-ay)*s), round((ys.max()-ay)*s),
          "colisao x", round((cx0-ax)*s), round((cx1-ax)*s), "y", round((cy0-ay)*s), round((cy1-ay)*s))
