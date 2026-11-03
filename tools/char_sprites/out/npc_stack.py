from PIL import Image
names = ["sarah_curandeira", "arion_mestre_classes", "bakka_ferreiro", "borin_mercador", "guarda_doran"]
out = Image.new("RGBA", (1024, 256 * len(names)))
for i, n in enumerate(names):
    out.paste(Image.open(f"tools/char_sprites/out/preview_npc_{n}.png"), (0, i * 256))
out.convert("RGB").resize((768, 960)).save("tools/char_sprites/out/npc_novos.png")
