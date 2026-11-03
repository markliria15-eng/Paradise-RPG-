import json
items = json.load(open("data/items.json", encoding="utf-8"))
items = items.get("items", items)
rows = []
for name, it in (items.items() if isinstance(items, dict) else [(i.get("name"), i) for i in items]):
    if not isinstance(it, dict):
        continue
    lvl = it.get("level", it.get("nivel", it.get("required_level", 0)))
    st = {k: it[k] for k in ("ataque", "defesa", "vida", "ataque_magico", "ataque_distancia") if k in it}
    stats = it.get("stats", {})
    if stats: st.update(stats)
    if st:
        rows.append((lvl or 0, name, it.get("type", it.get("slot", "")), st))
for r in sorted(rows, key=lambda r: (r[0] if isinstance(r[0], (int, float)) else 0))[:45]:
    print(r)
