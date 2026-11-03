from PIL import Image
names = ["sarah_curandeira", "arion_mestre_classes", "bakka_ferreiro", "borin_mercador", "guarda_doran"]
out = Image.new("RGB", (256 * len(names), 256), (70, 110, 70))
for i, n in enumerate(names):
    im = Image.open(f"assets/characters/npcs/npc_{n}_idle_4f_128.png").convert("RGBA")
    print(n, im.size)
    f = im.crop((0, 0, im.width // 4, im.height)).resize((256, 256 * im.height * 4 // im.width), Image.NEAREST)
    out.paste(f, (i * 256, 0), f)
out.save("tools/char_sprites/out/npcs_atuais.png")
