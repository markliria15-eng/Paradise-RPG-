import json, collections
m = json.load(open("data/maps.json", encoding="utf-8"))["forest_boars"]
c = collections.Counter((s["enemy"], s.get("respawn")) for s in m.get("spawns", []))
for k, v in sorted(c.items()): print(k, v)
print("total grupos", len(m.get("spawns", [])), "mobs", sum(s.get("count", 1) for s in m["spawns"]))
