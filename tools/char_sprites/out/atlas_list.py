import json
a = json.load(open("assets/maps/ruinas_v2/sheets/atlas.json", encoding="utf-8"))
print([k for k in a if k != "atlases"])
for at in a["atlases"]:
    print("==", at["file"], at.get("grid"), [k for k in at if k not in ("sprites",)])
    for s in at.get("sprites", []):
        print("  ", s["name"], "frame", s.get("frame"), "pivot", s.get("pivot"), {k: v for k, v in s.items() if k not in ("name", "cell", "frame", "pivot")})
for k in a:
    if k != "atlases":
        print(k, json.dumps(a[k], ensure_ascii=False)[:800])
