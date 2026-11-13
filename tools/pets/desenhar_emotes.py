"""Desenha os baloes de emocao dos pets (pixel art 20x20, salvo 2x = 40x40).
Saida: assets/sprites/pets/emotes/<nome>.png
coracao (pet novo / carinho), alerta (pegou item), brilho (pegou ouro),
preocupado (vida baixa), sono (parado ha muito tempo), nota (feliz, subiu de nivel, montou);
pedidos: maca (fome), bola (brincar), espadas (lutar), carinho (quer carinho).
uso: python tools/pets/desenhar_emotes.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "sprites" / "pets" / "emotes"
K, W, L = (34, 28, 40, 255), (255, 255, 255, 255), (214, 222, 232, 255)
BUBBLE = [
    "....############....",
    "...#WWWWWWWWWWWW#...",
    "..#WWWWWWWWWWWWWW#..",
    ".#WWWWWWWWWWWWWWWW#.",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#WWWWWWWWWWWWWWWWWW#",
    "#LWWWWWWWWWWWWWWWWL#",
    ".#LWWWWWWWWWWWWWWL#.",
    "..#LLWWWWWWWWWWLL#..",
    "...####LWWWL####....",
    "......#LWWL#........",
    ".......#WL#.........",
    "........##..........",
    "....................",
    "....................",
]
ICONS = {
    "coracao": ((232, 64, 96, 255), [
        "..##..##..", ".####.####", "##########", "##########", ".########.",
        "..######..", "...####...", "....##....",
    ]),
    "alerta": ((240, 160, 30, 255), [
        "...##...", "...##...", "...##...", "...##...", "...##...", "........", "...##...", "...##...",
    ]),
    "brilho": ((245, 196, 40, 255), [
        "....#....", "....#....", "...###...", "#########", "...###...", "....#....", "....#....",
    ]),
    "preocupado": ((70, 150, 235, 255), [
        "...#....", "..###...", "..###...", ".#####..", ".#####..", ".#####..", "..###...",
    ]),
    "sono": ((90, 100, 140, 255), [
        "#####.....", "...#......", "..#.......", ".#..####..", "#####..#..", "......#...", ".....####.",
    ]),
    "nota": ((150, 90, 220, 255), [
        "...######", "...#....#", "...#....#", "...#....#", ".###..###", "####.####", ".##...##.",
    ]),
    # pedidos do pet (o balao fica ate voce atender): fome, brincar, lutar, carinho
    "maca": ((214, 48, 48, 255), [
        ".....gg..", "....gg...", "..##g##..", ".#######.", "#####w###", "#####w###", "#########", ".#######.", "..##.##..",
    ]),
    "bola": ((40, 120, 230, 255), [
        "...####...", ".##yy####.", ".#yyyy###.", "##yyyy####", "####yy####", "#####yy###", ".####yyyy.", ".#####yy#.", "...####...",
    ]),
    "espadas": ((95, 108, 128, 255), [
        "##........##", "###......###", ".###....###.", "..###..###..", "...######...", "....####....",
        "...######...", "..yy#..#yy..", ".kky....ykk.", "kk........kk",
    ]),
    "carinho": ((240, 140, 170, 255), [
        ".#.#.#....", ".#.#.#.#..", ".#.#.#.#..", ".#######..", ".########.", ".#######..", "..######..", "...####...",
    ]),
}
PALETTE = {"g": (60, 160, 60, 255), "w": (235, 240, 245, 255), "y": (245, 200, 50, 255), "k": (90, 60, 40, 255)}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (color, rows) in ICONS.items():
        im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        for y, row in enumerate(BUBBLE):
            for x, ch in enumerate(row):
                if ch != ".":
                    im.putpixel((x, y), {"#": K, "W": W, "L": L}[ch])
        h, w = len(rows), max(len(r) for r in rows)
        ox, oy = (20 - w) // 2, 2 + (12 - h) // 2
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    im.putpixel((ox + x, oy + y), color)
                elif ch in PALETTE:
                    im.putpixel((ox + x, oy + y), PALETTE[ch])
        im.resize((40, 40), Image.NEAREST).save(OUT / f"{name}.png", optimize=True)
    print("ok", sorted(ICONS))


if __name__ == "__main__":
    main()
