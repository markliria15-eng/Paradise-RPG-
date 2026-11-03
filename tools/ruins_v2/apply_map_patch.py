"""Aplica tools/ruins_v2/out/map_patch.json em data/maps.json (arcane_ruins) e
liga Eldoria <-> Ruinas por portal na ilhota de Eldoria.

Uso: py tools/ruins_v2/apply_map_patch.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "data/maps.json"
PATCH = Path(__file__).resolve().parent / "out/map_patch.json"
ELDORIA_FOREST_PORTAL = [3830, 5590]
ELDORIA_RUINS_PORTAL = [3370, 5590]
ELDORIA_ARRIVAL = [3600, 5450]

maps = json.loads(MAPS.read_text(encoding="utf-8"))
patch = json.loads(PATCH.read_text(encoding="utf-8"))
ruins = maps["arcane_ruins"]
ruins["size"] = patch["size"]
ruins["spawn"] = patch["spawn"]
ruins["spawns"] = patch["spawns"]
ruins["safe_zones"] = patch["safe_zones"]
ruins["portals"] = [{"label": "Eldoria", "target": "city_eldoria", "pos": patch["portal"], "spawn": ELDORIA_ARRIVAL}]
eld = maps["city_eldoria"]
portals = [p for p in eld["portals"] if p.get("target") != "arcane_ruins"]
for p in portals:
    if p.get("target") == "forest_boars":
        p["pos"] = ELDORIA_FOREST_PORTAL
portals.append({"label": "Ruinas Arcanas", "target": "arcane_ruins", "pos": ELDORIA_RUINS_PORTAL,
                "spawn": [patch["spawn"][0], patch["spawn"][1]]})
eld["portals"] = portals
MAPS.write_text(json.dumps(maps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("ok", len(ruins["spawns"]), "grupos;", [p["label"] for p in eld["portals"]])
