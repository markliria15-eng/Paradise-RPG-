import sys
from PIL import Image
root = r"assets/sprites/player_frames_caminhada_classes"
for cls in ("guerreiro", "arqueiro"):
    for anim in ("parado", "andar", "ataque", "dano", "morte"):
        im = Image.open(f"{root}/{cls}/fontes/{cls}_{anim}.png").convert("RGBA")
        bg = Image.new("RGBA", im.size, (70, 110, 70, 255)); bg.alpha_composite(im)
        bg.convert("RGB").resize((640, 640)).save(f"tools/char_sprites/out/view_{cls}_{anim}.jpg", quality=80)
