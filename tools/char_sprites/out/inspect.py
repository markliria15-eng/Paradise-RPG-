import glob
import numpy as np
from PIL import Image

for f in sorted(glob.glob(r"C:\Users\markl\Documents\Codex\2026-05-27\1-ideia-central-do-jogo-o\assets\sprites\player_frames_caminhada_classes\*\fontes\*.png")):
    im = Image.open(f)
    a = np.array(im.convert("RGBA"))
    transp = (a[:, :, 3] < 20).mean()
    print(f.split("\\")[-1], im.size, im.mode, "corner", tuple(a[2, 2]), "transp", round(float(transp), 2))
