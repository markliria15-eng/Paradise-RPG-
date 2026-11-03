import json
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOL_ROOT = Path(__file__).resolve().parent
SOURCE_MAP = PROJECT_ROOT / "assets/maps/eldoria/eldoria_7x7_minimap.png"
SOURCE_HOUSES_DIR = TOOL_ROOT / "source/houses"
GUIDES_DIR = TOOL_ROOT / "collision_guides"
HOUSES_DIR = PROJECT_ROOT / "assets/maps/eldoria/houses"
CHUNKS_DIR = PROJECT_ROOT / "assets/maps/eldoria/chunks_9x9"
MINIMAP_PATH = PROJECT_ROOT / "assets/maps/eldoria/eldoria_9x9_minimap.png"
COLLISION_DATA_PATH = PROJECT_ROOT / "data/eldoria_house_kit.json"
GENERATED_DIR = TOOL_ROOT / "generated"
BASE_PATH = GENERATED_DIR / "eldoria_9x9_base.png"
PREVIEW_PATH = GENERATED_DIR / "eldoria_9x9_house_kit_preview.png"

CHUNK_SIZE = (200, 160)
GRID_SIZE = (9, 9)
WORLD_SCALE = 4.0
COLLISION_CELL_SIZE = 24

HOUSE_DEFINITIONS = [
    {
        "id": "master_house",
        "name": "Casa dos Mestres",
        "texture": "01_Master_House.png",
        "guide": "01_Master_House_Collision_Guide.png",
        "world_position": [1780.0, 1620.0],
        "visual_scale": 0.84,
    },
    {
        "id": "healer_house",
        "name": "Casa da Curandeira",
        "texture": "02_Healer_House.png",
        "guide": "02_Healer_House_Collision_Guide.png",
        "world_position": [1780.0, 3600.0],
        "visual_scale": 0.84,
    },
    {
        "id": "merchant_house",
        "name": "Armazem do Mercador",
        "texture": "03_Merchant_House.png",
        "guide": "03_Merchant_House_Collision_Guide.png",
        "world_position": [5400.0, 3600.0],
        "visual_scale": 0.84,
    },
    {
        "id": "blacksmith_house",
        "name": "Ferraria de Bakka",
        "texture": "04_Blacksmith_House.png",
        "guide": "04_Blacksmith_House_Collision_Guide.png",
        "world_position": [5360.0, 1580.0],
        "visual_scale": 0.84,
    },
    {
        "id": "villager_house_a",
        "name": "Casa de Aldeao Norte 1",
        "texture": "05_Villager_House_A.png",
        "guide": "05_Villager_House_A_Collision_Guide.png",
        "world_position": [2600.0, 1120.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_b",
        "name": "Casa de Aldeao Norte 2",
        "texture": "06_Villager_House_B.png",
        "guide": "06_Villager_House_B_Collision_Guide.png",
        "world_position": [4320.0, 1120.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_west",
        "name": "Casa de Aldeao Oeste",
        "texture": "05_Villager_House_A.png",
        "guide": "05_Villager_House_A_Collision_Guide.png",
        "world_position": [1320.0, 2200.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_east",
        "name": "Casa de Aldeao Leste",
        "texture": "06_Villager_House_B.png",
        "guide": "06_Villager_House_B_Collision_Guide.png",
        "world_position": [5780.0, 2200.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_midwest",
        "name": "Casa de Aldeao Centro-Oeste",
        "texture": "06_Villager_House_B.png",
        "guide": "06_Villager_House_B_Collision_Guide.png",
        "world_position": [2700.0, 3350.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_mideast",
        "name": "Casa de Aldeao Centro-Leste",
        "texture": "05_Villager_House_A.png",
        "guide": "05_Villager_House_A_Collision_Guide.png",
        "world_position": [4500.0, 3350.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_southwest",
        "name": "Casa de Aldeao Sudoeste",
        "texture": "05_Villager_House_A.png",
        "guide": "05_Villager_House_A_Collision_Guide.png",
        "world_position": [1350.0, 4670.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_southwest_inner",
        "name": "Casa de Aldeao Sul-Oeste",
        "texture": "06_Villager_House_B.png",
        "guide": "06_Villager_House_B_Collision_Guide.png",
        "world_position": [2700.0, 4670.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_southeast_inner",
        "name": "Casa de Aldeao Sul-Leste",
        "texture": "05_Villager_House_A.png",
        "guide": "05_Villager_House_A_Collision_Guide.png",
        "world_position": [4500.0, 4670.0],
        "visual_scale": 0.46,
    },
    {
        "id": "villager_house_southeast",
        "name": "Casa de Aldeao Sudeste",
        "texture": "06_Villager_House_B.png",
        "guide": "06_Villager_House_B_Collision_Guide.png",
        "world_position": [5850.0, 4670.0],
        "visual_scale": 0.46,
    },
]


def is_red(pixel):
    red, green, blue, alpha = pixel
    return alpha > 80 and red > 150 and red > green * 2 and red > blue * 2


def red_mask(image):
    return [[is_red(image.getpixel((x, y))) for x in range(image.width)] for y in range(image.height)]


def mask_bbox(mask):
    xs = []
    ys = []
    for y, row in enumerate(mask):
        for x, value in enumerate(row):
            if value:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise ValueError("Collision guide has no red area")
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def collision_rects(mask, cell_size):
    height = len(mask)
    width = len(mask[0])
    grid_rows = []
    for top in range(0, height, cell_size):
        runs = []
        active_start = None
        for left in range(0, width, cell_size):
            right = min(left + cell_size, width)
            bottom = min(top + cell_size, height)
            total = (right - left) * (bottom - top)
            red_count = sum(
                1
                for y in range(top, bottom)
                for x in range(left, right)
                if mask[y][x]
            )
            filled = red_count / total >= 0.25
            if filled and active_start is None:
                active_start = left
            if active_start is not None and (not filled or right == width):
                run_end = left if not filled else right
                runs.append((active_start, run_end))
                active_start = None
        grid_rows.append(runs)

    active = {}
    rectangles = []
    for row_index, runs in enumerate(grid_rows + [[]]):
        top = row_index * cell_size
        current = set(runs)
        for run, vertical in list(active.items()):
            if run not in current:
                rectangles.append(
                    {
                        "x": run[0],
                        "y": vertical[0],
                        "w": run[1] - run[0],
                        "h": vertical[1] - vertical[0],
                    }
                )
                del active[run]
        for run in current:
            if run in active:
                active[run] = (active[run][0], top + cell_size)
            else:
                active[run] = (top, top + cell_size)
    return rectangles


def remove_description_label(image):
    alpha = image.getchannel("A")
    row_counts = [
        sum(1 for value in alpha.crop((0, y, image.width, y + 1)).get_flattened_data() if value > 20)
        for y in range(image.height)
    ]
    segments = []
    start = None
    for y, count in enumerate(row_counts + [0]):
        if count > 0 and start is None:
            start = y
        elif count == 0 and start is not None:
            segments.append((start, y))
            start = None
    if len(segments) >= 2 and segments[-1][0] > image.height * 0.75:
        pixels = image.load()
        for y in range(segments[-1][0], image.height):
            for x in range(image.width):
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return image


def prepare_house_assets():
    HOUSES_DIR.mkdir(parents=True, exist_ok=True)
    for source_path in sorted(SOURCE_HOUSES_DIR.glob("*.png")):
        image = Image.open(source_path).convert("RGBA")
        remove_description_label(image).save(HOUSES_DIR / source_path.name)


def build_collision_data():
    houses = []
    for definition in HOUSE_DEFINITIONS:
        guide = Image.open(GUIDES_DIR / definition["guide"]).convert("RGBA")
        mask = red_mask(guide)
        red_left, red_top, red_right, red_bottom = mask_bbox(mask)
        entry = dict(definition)
        entry["texture_path"] = f'res://assets/maps/eldoria/houses/{definition["texture"]}'
        entry["source_size"] = [guide.width, guide.height]
        entry["anchor"] = [guide.width / 2.0, float(red_top)]
        entry["red_bbox"] = [red_left, red_top, red_right - red_left, red_bottom - red_top]
        entry["collision_rects"] = collision_rects(mask, COLLISION_CELL_SIZE)
        entry.pop("guide")
        entry.pop("texture")
        houses.append(entry)
    return {
        "version": 1,
        "collision_cell_size": COLLISION_CELL_SIZE,
        "houses": houses,
    }


def add_houses_to_minimap(base, collision_data):
    result = base.convert("RGBA")
    for house in collision_data["houses"]:
        texture = Image.open(PROJECT_ROOT / house["texture_path"].replace("res://", "")).convert("RGBA")
        minimap_scale = house["visual_scale"] / WORLD_SCALE
        size = (
            max(1, round(texture.width * minimap_scale)),
            max(1, round(texture.height * minimap_scale)),
        )
        texture = texture.resize(size, Image.Resampling.LANCZOS)
        anchor_x, anchor_y = house["anchor"]
        world_x, world_y = house["world_position"]
        paste_x = round(world_x / WORLD_SCALE - anchor_x * minimap_scale)
        paste_y = round(world_y / WORLD_SCALE - anchor_y * minimap_scale)
        result.alpha_composite(texture, (paste_x, paste_y))
    return result.convert("RGB")


def write_chunks(base):
    CHUNKS_DIR.mkdir(parents=True, exist_ok=True)
    for grid_y in range(GRID_SIZE[1]):
        for grid_x in range(GRID_SIZE[0]):
            left = grid_x * CHUNK_SIZE[0]
            top = grid_y * CHUNK_SIZE[1]
            chunk = base.crop((left, top, left + CHUNK_SIZE[0], top + CHUNK_SIZE[1]))
            chunk.save(CHUNKS_DIR / f"eldoria_chunk_{grid_x:02d}_{grid_y:02d}.png")


def main():
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    prepare_house_assets()
    source = Image.open(SOURCE_MAP).convert("RGB")
    expected_size = (CHUNK_SIZE[0] * GRID_SIZE[0], CHUNK_SIZE[1] * GRID_SIZE[1])
    if source.size != expected_size:
        raise ValueError(f"Unexpected Eldoria source size: {source.size}")

    collision_data = build_collision_data()
    base = source.copy()
    minimap = add_houses_to_minimap(base, collision_data)

    BASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    base.save(BASE_PATH)
    minimap.save(MINIMAP_PATH)
    minimap.save(PREVIEW_PATH)
    write_chunks(base)
    COLLISION_DATA_PATH.write_text(
        json.dumps(collision_data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    collision_count = sum(len(house["collision_rects"]) for house in collision_data["houses"])
    print(f"Generated {len(collision_data['houses'])} Eldoria houses and {collision_count} collision shapes")


if __name__ == "__main__":
    main()
