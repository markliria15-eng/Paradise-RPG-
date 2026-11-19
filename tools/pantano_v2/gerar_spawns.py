"""Coloca os grupos de inimigos do Pantano (swamp_almas) em data/maps.json.

Le as zonas do projeto do ChatGPT (projeto_chatgpt.json -> zonas[].inimigos), a mascara de chao
andavel do kit e os numeros (numeros_inimigos.json -> respawn_s, grupo). So troca
maps.json -> swamp_almas -> spawns; o resto do arquivo fica igual.

Regras: grupo so em chao andavel ligado ao ponto de chegada (o heroi alcanca), longe da zona
segura, dos NPCs, dos portais e da arena do chefe; o Rei Afogado fica sozinho no centro da arena.

uso (raiz do repo): python3 -I tools/pantano_v2/gerar_spawns.py
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
PASTA = ROOT / "tools" / "pantano_v2"
MAPA = "swamp_almas"
CELL = 16
ARENA = ((900, 700), 520)
BOSS = "Rei Afogado"
NOMES = {"Jacare do Pantano", "Sapo Venenoso Gigante", "Mosquito Mutante", "Afogado do Pantano"}
PASSO = 980          # distancia entre grupos (floresta: 25 grupos / 51 bichos num mapa maior)
CAIXA = (220, 170)   # area de cada grupo (zone do maps.json)
LONGE_NPC = 340
# volta da grade onde procurar chao livre (zona com agua no meio: lago)
OFFSETS = [(0, 0)] + [(round(r * math.cos(a * math.pi / 4)), round(r * math.sin(a * math.pi / 4)))
                      for r in (140, 280, 420) for a in range(8)]
LONGE_PORTAL = 380
LONGE_SEGURA = 260   # alem do raio da zona segura


def main():
    projeto = json.loads((PASTA / "projeto_chatgpt.json").read_text(encoding="utf-8"))
    numeros = json.loads((PASTA / "numeros_inimigos.json").read_text(encoding="utf-8"))["inimigos"]
    maps_path = ROOT / "data" / "maps.json"
    maps = json.loads(maps_path.read_text(encoding="utf-8"))
    mapa = maps[MAPA]
    walk = np.asarray(Image.open(ROOT / "assets/maps/pantano_v2/pantano_v2_walkable.png").convert("L")) > 127
    lab, _ = ndimage.label(walk)
    sx, sy = mapa["spawn"]
    alvo = lab[sy // CELL, sx // CELL]
    alcance = lab == alvo

    def livre(cx, cy):
        w, h = CAIXA
        x0, y0 = int((cx - w / 2) // CELL), int((cy - h / 2) // CELL)
        x1, y1 = int((cx + w / 2) // CELL), int((cy + h / 2) // CELL)
        if x0 < 0 or y0 < 0 or y1 >= alcance.shape[0] or x1 >= alcance.shape[1]:
            return False
        return alcance[y0:y1 + 1, x0:x1 + 1].mean() > 0.75

    perto = []
    for z in mapa.get("safe_zones", []):
        perto.append((z["pos"], z["radius"] + LONGE_SEGURA))
    for n in mapa.get("npcs", []):
        perto.append((n["pos"], LONGE_NPC))
    for p in mapa.get("portals", []):
        perto.append((p["pos"], LONGE_PORTAL))
    perto.append((ARENA[0], ARENA[1] + 140))

    def longe(cx, cy, usados):
        for (px, py), r in perto:
            if math.hypot(cx - px, cy - py) < r:
                return False
        return all(math.hypot(cx - ux, cy - uy) >= PASSO * 0.85 for ux, uy in usados)

    spawns, usados = [], []
    for zona in projeto["zonas"]:
        lista = [n for n in zona.get("inimigos", []) if n in NOMES]
        if not lista:
            continue
        x, y, w, h = zona["retangulo_px"]
        pontos = []
        for cy in np.arange(y + PASSO / 2, y + h, PASSO):
            for cx in np.arange(x + PASSO / 2, x + w, PASSO):
                # procura chao livre perto do ponto da grade (agua funda no meio da zona)
                for dx, dy in OFFSETS:
                    px, py = float(cx + dx), float(cy + dy)
                    if x <= px <= x + w and y <= py <= y + h and livre(px, py) and longe(px, py, usados + pontos):
                        pontos.append((px, py))
                        break
        for i, (px, py) in enumerate(pontos):
            nome = lista[i % len(lista)]
            n = numeros[nome]
            spawns.append({
                "enemy": nome,
                "count": int(n.get("grupo", 2)),
                "respawn": int(n.get("respawn_s", 60)),
                "zone": [int(px - CAIXA[0] / 2), int(py - CAIXA[1] / 2), CAIXA[0], CAIXA[1]],
            })
        usados += pontos
        print(f"{zona['nome']}: {len(pontos)} grupos ({', '.join(lista)})")
    (ax, ay), _ = ARENA
    if not alcance[ay // CELL, ax // CELL]:
        raise SystemExit("centro da arena do chefe nao e alcancavel")
    spawns.append({"enemy": BOSS, "count": 1, "boss": True, "respawn": 300, "zone": [ax - 100, ay - 80, 200, 160]})
    mapa["spawns"] = spawns
    maps_path.write_text(json.dumps(maps, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = {}
    for s in spawns:
        total[s["enemy"]] = total.get(s["enemy"], 0) + s["count"]
    print(f"{len(spawns)} grupos, {sum(total.values())} inimigos: {total}")


if __name__ == "__main__":
    main()
