from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
HOUSE_SOURCE = (
    ROOT
    / ".codex-remote-attachments"
    / "019e6909-fb5c-7630-898c-c76543251c71"
    / "bdd5f067-30dc-433b-9502-1f68c8943907"
)


def remove_light_checker_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    data = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = data[x, y]
            spread = max(r, g, b) - min(r, g, b)
            if r > 212 and g > 212 and b > 212 and spread < 48:
                data[x, y] = (r, g, b, 0)
            else:
                data[x, y] = (r, g, b, a)
    return rgba


def crop_to_alpha(image: Image.Image, padding: int = 18) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    return image.crop((left, top, right, bottom))


def export_house(source_name: str, output_name: str) -> None:
    source = Image.open(HOUSE_SOURCE / source_name)
    transparent = crop_to_alpha(remove_light_checker_background(source))
    canvas_size = 320
    target_fit = 306
    scale = min(target_fit / transparent.width, target_fit / transparent.height)
    resized = transparent.resize(
        (max(1, round(transparent.width * scale)), max(1, round(transparent.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((canvas_size - resized.width) // 2, (canvas_size - resized.height) // 2),
    )
    canvas.save(SPRITES / output_name)


def shifted_frame(source: Path, dest: Path, offset_x: int, offset_y: int, scale_boost: int = 0) -> None:
    src = Image.open(source).convert("RGBA")
    width, height = src.size
    canvas = Image.new("RGBA", src.size, (0, 0, 0, 0))
    draw_width = width + scale_boost
    draw_height = height + scale_boost
    frame = src.resize((draw_width, draw_height), Image.Resampling.NEAREST)
    canvas.alpha_composite(
        frame,
        ((width - draw_width) // 2 + offset_x, (height - draw_height) // 2 + offset_y),
    )
    canvas.save(dest)


def expand_player_walk(prefix: str, direction: str) -> None:
    base = SPRITES / f"player_{prefix}_art_{direction}"
    frame_map = {
        5: (3, 0, 18, 0),
        6: (2, 10, 8, 0),
        7: (1, 0, -8, 0),
        8: (2, -10, 8, 0),
    }
    if direction == "side":
        frame_map = {
            5: (3, 18, 8, 0),
            6: (2, 9, 2, 0),
            7: (1, -12, -4, 0),
            8: (2, -5, 3, 0),
        }
    for frame_id, (src_id, ox, oy, scale_boost) in frame_map.items():
        src = Path(f"{base}_walk_{src_id}.png")
        dest = Path(f"{base}_walk_{frame_id}.png")
        if src.exists():
            shifted_frame(src, dest, ox, oy, scale_boost)


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    houses = {
        "1-Photo-1.jpg": "decor_house_guild_hall.png",
        "2-Photo-2.jpg": "decor_house_cottage_blue.png",
        "3-Photo-3.jpg": "decor_house_forge_reference.png",
        "4-Photo-4.jpg": "decor_house_market_reference.png",
        "5-Photo-5.jpg": "decor_house_noble_blue.png",
    }
    for source_name, output_name in houses.items():
        export_house(source_name, output_name)
    for prefix in ("guerreiro", "mago", "arqueiro"):
        for direction in ("front", "back", "side"):
            expand_player_walk(prefix, direction)
    print("House references processed and player walk frames expanded.")


if __name__ == "__main__":
    main()
