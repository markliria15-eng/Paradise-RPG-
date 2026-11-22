"""Espalha os pontos de coleta (minerio, arvore, erva) nos mapas de caca e as bancadas nas cidades.

Grava so maps.json -> <mapa>.gather_nodes [{tipo, pos}] e <cidade>.gather_stations
[{tipo, perto_npc, offset}] (scripts/profissoes.gd le). Tipos em data/profissoes.json -> pontos.
Regras: chao andavel ligado ao ponto de chegada (mascara do kit), longe de NPC, portal, zona segura e
arena de chefe, e longe um do outro. Semente fixa: rodar de novo da o mesmo resultado.
uso (raiz do repo): python3 -I tools/profissoes/gerar_pontos.py
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
CELL = 16
DIST_MIN = 230
LONGE_NPC = 260
LONGE_PORTAL = 320
LONGE_CHEFE = 700
# maps.json da floresta guarda posicoes /4 (main_mundo._map_data_point: FOREST_WORLD_SCALE)
ESCALA = {"forest_boars": 4.0}

MAPAS = {
    "forest_boars": ("data/forest_kit.json", {"arvore": 14, "arvore_antiga": 4, "ferro": 6, "carvao": 5, "erva_curativa": 8,
                                              "folha_floresta": 7, "cogumelo": 6, "erva_vermelha": 5, "flor_medicinal": 4}),
    "bat_cave": ("data/cave_kit.json", {"ferro": 6, "carvao": 6, "titanio": 5, "cristal": 5, "erva_caverna": 6, "fungo": 5,
                                        "cogumelo": 3}),
    "arcane_ruins": ("data/ruins_kit.json", {"titanio": 5, "cristal": 3, "mithril": 2, "flor_medicinal": 5, "erva_especial": 4,
                                             "erva_vermelha": 4, "arvore": 6, "arvore_antiga": 4}),
    "swamp_almas": ("data/swamp_kit.json", {"musgo": 8, "fungo": 6, "cogumelo": 6, "arvore_antiga": 6, "erva_especial": 3,
                                            "mithril": 4, "titanio": 3, "planta_rara": 1}),
    "ember_fortress": ("data/fortress_kit.json", {"obsidiana": 7, "carvao": 5, "mithril": 5, "titanio": 3, "erva_especial": 3,
                                                  "planta_rara": 3}),
}
# bancadas da cidade ao lado de um NPC (nome comeca com perto_npc); offset em px do mundo
ESTACOES = {
    "city_eldoria": [{"tipo": "mesa_alquimia", "perto_npc": "Sarah", "offset": [150, 40]},
                     {"tipo": "fogao", "perto_npc": "Carlos", "offset": [-160, 40]}],
    "city_valdoria": [{"tipo": "mesa_alquimia", "perto_npc": "Liora", "offset": [170, 60]},
                      {"tipo": "fogao", "perto_npc": "Varek", "offset": [-170, 60]}],
}


def mascara(kit_path, mapa, esc):
    kit = json.loads((ROOT / kit_path).read_text(encoding="utf-8"))
    path = ROOT / kit["walkable_mask"]["path"].replace("res://", "")
    walk = np.asarray(Image.open(path).convert("L")) > 127
    lab, _ = ndimage.label(walk)
    sx, sy = mapa["spawn"][0] * esc, mapa["spawn"][1] * esc
    alvo = lab[int(sy) // CELL, int(sx) // CELL]
    if alvo == 0:  # chegada em cima de borda: maior regiao
        alvo = np.argmax(np.bincount(lab.ravel())[1:]) + 1
    alcance = lab == alvo
    # longe das bordas do chao (o ponto nao fica colado em parede/agua)
    return ndimage.binary_erosion(alcance, iterations=3)


def main():
    maps_path = ROOT / "data" / "maps.json"
    maps = json.loads(maps_path.read_text(encoding="utf-8"))
    defs = json.loads((ROOT / "data" / "profissoes.json").read_text(encoding="utf-8"))["pontos"]
    for mapa_id, (kit, pedido) in MAPAS.items():
        mapa = maps[mapa_id]
        esc = ESCALA.get(mapa_id, 1.0)
        livre = mascara(kit, mapa, esc)
        evitar = []  # (centro em px do mundo, raio em px do mundo)
        for z in mapa.get("safe_zones", []):
            evitar.append(([z["pos"][0] * esc, z["pos"][1] * esc], z["radius"] * esc + 60))
        for n in mapa.get("npcs", []):
            evitar.append(([n["pos"][0] * esc, n["pos"][1] * esc], LONGE_NPC))
        for p in mapa.get("portals", []):
            evitar.append(([p["pos"][0] * esc, p["pos"][1] * esc], LONGE_PORTAL))
        arena = json.loads((ROOT / kit).read_text(encoding="utf-8")).get("boss_arena")
        if arena:  # floresta: arena do Rei Javali (px do mundo)
            r = arena["radius"]
            evitar.append((arena["center"], (max(r) if isinstance(r, list) else r) + 120))
        for s in mapa.get("spawns", []):
            if s.get("boss"):
                x, y, w, h = [v * esc for v in s["zone"]]
                evitar.append(([x + w / 2, y + h / 2], LONGE_CHEFE))
        ys, xs = np.nonzero(livre)
        rng = np.random.default_rng(11)
        usados, saida = [], []
        for tipo, qtd in pedido.items():
            assert tipo in defs, tipo
            postos = 0
            for _ in range(6000):
                if postos >= qtd:
                    break
                i = int(rng.integers(len(xs)))
                px, py = (xs[i] + 0.5) * CELL, (ys[i] + 0.5) * CELL
                if any(math.hypot(px - a[0], py - a[1]) < r for a, r in evitar):
                    continue
                if any(math.hypot(px - ux, py - uy) < DIST_MIN for ux, uy in usados):
                    continue
                usados.append((px, py))
                saida.append({"tipo": tipo, "pos": [int(px / esc), int(py / esc)]})
                postos += 1
            if postos < qtd:
                print(f"  {mapa_id}: {tipo} so {postos}/{qtd}")
        mapa["gather_nodes"] = saida
        print(mapa_id, len(saida), "pontos")
    for cidade, lista in ESTACOES.items():
        maps[cidade]["gather_stations"] = lista
    maps_path.write_text(json.dumps(maps, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
