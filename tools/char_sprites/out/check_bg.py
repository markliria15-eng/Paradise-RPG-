import numpy as np
from PIL import Image
for n in ("parado", "andar", "ataque", "dano", "morte"):
    a = np.array(Image.open(f"assets/sprites/player_frames_caminhada_classes/maga_de_fogo/fontes/maga_de_fogo_{n}.png").convert("RGBA"))
    print(n, a.shape, "transp", round(float((a[:, :, 3] < 20).mean()), 2), "corner", tuple(int(v) for v in a[2, 2]))
