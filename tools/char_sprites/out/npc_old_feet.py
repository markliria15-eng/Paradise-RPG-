import numpy as np
from PIL import Image
a = np.array(Image.open("assets/characters/npcs/npc_bakka_ferreiro_idle_4f_128.png").convert("RGBA"))[:, :128, 3] > 40
ys = np.nonzero(a.any(axis=1))[0]; print("old top", ys.min(), "bot", ys.max())
