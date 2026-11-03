from math import pi, sin
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CHUNKS_DIR = PROJECT_ROOT / "assets/maps/eldoria/chunks_9x9"
FRAMES_DIR = PROJECT_ROOT / "assets/maps/eldoria/water_frames"
WATER_SHADES = (
    (29, 67, 90),
    (33, 79, 105),
    (39, 92, 120),
    (47, 108, 141),
    (57, 123, 157),
)
WATER_PALETTE = {color: index for index, color in enumerate(WATER_SHADES)}
OLD_FOAM = (112, 170, 202)
CREST = (91, 151, 184)
FRAME_COUNT = 4
CHUNK_WIDTH = 200
CHUNK_HEIGHT = 160


def water_color(color, source_x, source_y, frame_index):
    if color == OLD_FOAM:
        color = WATER_SHADES[-1]
    shade_index = WATER_PALETTE.get(color)
    if shade_index is None:
        return color

    sample_x = source_x // 4 * 4
    sample_y = source_y // 4 * 4
    phase = frame_index * 2 * pi / FRAME_COUNT
    wave = sin(2 * pi * (sample_x / 72 + sample_y / 108) - phase)
    wave += 0.38 * sin(2 * pi * (sample_x / 116 - sample_y / 80) + phase)
    if wave > 1.19:
        return CREST
    if wave > 0.78:
        return WATER_SHADES[min(shade_index + 1, len(WATER_SHADES) - 1)]
    if wave < -1.13:
        return WATER_SHADES[max(shade_index - 1, 0)]
    return color


def main():
    FRAMES_DIR.mkdir(exist_ok=True)
    created = 0
    for chunk_path in sorted(CHUNKS_DIR.glob("eldoria_chunk_??_??.png")):
        grid_x, grid_y = map(int, chunk_path.stem.split("_")[-2:])
        source = Image.open(chunk_path).convert("RGB")
        if source.size != (CHUNK_WIDTH, CHUNK_HEIGHT):
            raise ValueError(f"Unexpected chunk size: {chunk_path}")
        if not any(pixel in WATER_PALETTE or pixel == OLD_FOAM for pixel in source.get_flattened_data()):
            continue

        source_pixels = source.load()
        for frame_index in range(FRAME_COUNT):
            frame = Image.new("RGB", source.size)
            frame_pixels = frame.load()
            for local_y in range(CHUNK_HEIGHT):
                source_y = grid_y * CHUNK_HEIGHT + local_y
                for local_x in range(CHUNK_WIDTH):
                    source_x = grid_x * CHUNK_WIDTH + local_x
                    frame_pixels[local_x, local_y] = water_color(
                        source_pixels[local_x, local_y],
                        source_x,
                        source_y,
                        frame_index,
                    )
            frame.save(
                FRAMES_DIR
                / f"eldoria_water_{grid_x:02d}_{grid_y:02d}_frame_{frame_index:02d}.png"
            )
            created += 1
    print(f"Generated {created} Eldoria water frames")


if __name__ == "__main__":
    main()
