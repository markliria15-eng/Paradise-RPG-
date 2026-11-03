import json
kit = json.load(open("data/eldoria_house_kit.json", encoding="utf-8"))
print("kit keys", list(kit.keys()))
for h in kit.get("houses", []):
    print(h.get("id"), h.get("texture_path"), h.get("world_position"), h.get("anchor"), h.get("visual_scale"), len(h.get("collision_rects", [])))
maps = json.load(open("data/maps.json", encoding="utf-8"))
m = maps["maps"]["city_eldoria"] if "maps" in maps else maps["city_eldoria"]
print(json.dumps({k: v for k, v in m.items() if k not in ("enemies",)}, ensure_ascii=False)[:2500])
