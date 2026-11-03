import json
m = json.load(open("data/maps.json", encoding="utf-8"))
r = m["arcane_ruins"]
print(json.dumps({k: v for k, v in r.items() if k != "spawns"}, ensure_ascii=False)[:1500])
print("spawns", len(r.get("spawns", [])), r.get("spawns", [])[:3])
for mid, md in m.items():
    for p in md.get("portals", []):
        if p.get("target") == "arcane_ruins" or mid == "arcane_ruins":
            print("portal", mid, "->", p.get("target"), p.get("pos"), p.get("spawn"))
e = json.load(open("data/enemies.json", encoding="utf-8"))
print([ (k, v.get("level")) for k, v in e.items()])
