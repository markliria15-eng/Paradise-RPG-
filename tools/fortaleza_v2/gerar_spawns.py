"""Coloca os grupos de inimigos e os coletaveis da Fortaleza de Cinzas (ember_fortress) em data/maps.json.
(Copia de tools/pantano_v2/gerar_spawns.py com as constantes da fortaleza.)

Le as zonas do projeto do ChatGPT (projeto_chatgpt.json -> zonas[].inimigos), a mascara de chao
andavel do kit, os numeros (numeros_inimigos.json -> respawn_s, grupo) e os coletaveis
(missoes_chatgpt.json -> coletaveis). So troca maps.json -> ember_fortress -> spawns e
collectibles; o resto do arquivo fica igual.

Regras: grupo so em chao andavel ligado ao ponto de chegada (o heroi alcanca), longe da zona
segura, dos NPCs, dos portais e da arena do chefe; o General Infernal fica sozinho na arena.

uso (raiz do repo): python3 -I tools/fortaleza_v2/gerar_spawns.py
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
PASTA = ROOT / "tools" / "fortaleza_v2"
MAPA = "ember_fortress"
CELL = 16
ARENA = ((6000, 850), 350)
BOSS = "General Infernal"
NOMES = {"Cavaleiro Sombrio", "Draco Jovem", "Cinzeiro Errante"}
PASSO = 980          # distancia entre grupos (floresta: 25 grupos / 51 bichos num mapa maior)
CAIXA = (220, 170)   # area de cada grupo (zone do maps.json)
LONGE_NPC = 340
# volta da grade onde procurar chao livre (zona com agua no meio: lago)
OFFSETS = [(0, 0)] + [(round(r * math.cos(a * math.pi / 4)), round(r * math.sin(a * math.pi / 4)))
                      for r in (140, 280, 420) for a in range(8)]
LONGE_PORTAL = 380
LONGE_SEGURA = 260   # alem do raio da zona segura


def coletaveis(projeto, alcance, perto):
    """Itens no chao (missoes_chatgpt.json -> coletaveis: item, quantidade, zona) em chao alcancavel."""
    arq = PASTA / "missoes_chatgpt.json"
    pedido = json.loads(arq.read_text(encoding="utf-8")).get("coletaveis", []) if arq.exists() else []
    zonas = {z["nome"]: z["retangulo_px"] for z in projeto["zonas"]}
    rng = np.random.default_rng(7)
    saida, usados = [], []
    for c in pedido:
        x, y, w, h = zonas[c["zona"]]
        postos = 0
        for _ in range(4000):
            if postos >= int(c["quantidade_no_mapa"]):
                break
            px, py = float(rng.uniform(x + 60, x + w - 60)), float(rng.uniform(y + 60, y + h - 60))
            cy, cx = int(py // CELL), int(px // CELL)
            if not alcance[cy - 1:cy + 2, cx - 1:cx + 2].all():
                continue
            # zona segura pode (perto da entrada); so longe de NPC/portal e de outro item
            if any(math.hypot(px - qx, py - qy) < 150 for qx, qy in usados):
                continue
            if any(math.hypot(px - ax, py - ay) < 120 for (ax, ay), _r in perto[-len(perto):] if _r < 400):
                continue
            usados.append((px, py))
            saida.append({"item": c["item"], "amount": 1, "pos": [int(px), int(py)]})
            postos += 1
        print(f"coletavel {c['item']} em {c['zona']}: {postos}/{c['quantidade_no_mapa']}")
    return saida


def main():
    projeto = json.loads((PASTA / "projeto_chatgpt.json").read_text(encoding="utf-8"))
    exp = json.loads((PASTA / "expansao.json").read_text(encoding="utf-8"))  # areas novas (2026-11-23)
    projeto["zonas"] = projeto["zonas"] + exp["zonas"]
    numeros = json.loads((PASTA / "numeros_inimigos.json").read_text(encoding="utf-8"))["inimigos"]
    maps_path = ROOT / "data" / "maps.json"
    maps = json.loads(maps_path.read_text(encoding="utf-8"))
    mapa = maps[MAPA]
    walk = np.asarray(Image.open(ROOT / "assets/maps/fortaleza_v2/fortaleza_v2_walkable.png").convert("L")) > 127
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
    spawns.append({"enemy": BOSS, "count": 1, "boss": True, "respawn": 300, "zone": [ax - 100, ay - 230, 200, 160]})
    mapa["spawns"] = spawns
    mapa["collectibles"] = coletaveis(projeto, alcance, perto)
    maps_path.write_text(json.dumps(maps, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = {}
    for s in spawns:
        total[s["enemy"]] = total.get(s["enemy"], 0) + s["count"]
    print(f"{len(spawns)} grupos, {sum(total.values())} inimigos: {total}")


if __name__ == "__main__":
    main()
