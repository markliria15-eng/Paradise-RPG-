"""Gera o Pantano das Almas Perdidas (kit, igual Valdoria v2) a partir do projeto do ChatGPT.

Entradas: tools/pantano_v2/projeto_chatgpt.json (zonas, agua, caminhos, objetos com "porte" e "pe_px")
          tools/pantano_v2/terrenos/*.png e assets/maps/pantano_v2/objetos/*.png (recortar.py)
Saidas:   assets/maps/pantano_v2/chunks/*.png (8x9 pedacos de 400x320, escala 2 -> 6400x5760)
          assets/maps/pantano_v2/pantano_v2_walkable.png e _lento.png (mascaras, celula 16 px)
          assets/maps/pantano_v2/pantano_v2_minimap.png, data/swamp_kit.json
          tools/pantano_v2/out/preview*.png

Regra de colisao (Mark, 2026-11-17), pelo "porte" de cada objeto:
  baixo   -> sem colisao, desenhado no chao (o heroi passa por cima);
  joelho  -> sem colisao, desenhado no chao (o heroi "sobe" e passa por cima);
  cintura -> solido so no TERCO DA FRENTE da faixa do pe (pe_px): de frente o pe esbarra no pe do
             objeto e o heroi fica por cima; pela lateral, passando 1/3 da profundidade para tras,
             ele contorna e fica desenhado atras (ordem de desenho pela linha do pe).

uso (raiz do projeto): python tools/pantano_v2/gerar_pantano.py
"""
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
KIT = ROOT / "assets/maps/pantano_v2"
OBJ = KIT / "objetos"
RES = "res://"
DATA_PATH = ROOT / "data/swamp_kit.json"
WORLD = (6400, 5760)
GS = 2
GROUND = (WORLD[0] // GS, WORLD[1] // GS)
GRID = (8, 9)
CHUNK = (GROUND[0] // GRID[0], GROUND[1] // GRID[1])
CELL = 16
TILE_GROUND = 200  # textura de 416 px vira 200 px de chao (400 px de mundo)
# quantos do projeto entram de verdade (o projeto pede ~1900 objetos; o jogo fica leve com ~700)
FATOR = {"baixo": 0.32, "joelho": 0.5, "cintura": 0.62}
REDUZ = {"barril_velho": 0.4, "caixote_madeira": 0.4, "cerca_quebrada": 0.5, "lapide_antiga": 0.75, "coluna_ruina": 0.7,
         "nevoa_pantanosa": 0.6}
ARENA = ((900, 700), 520)  # clareira do chefe na Ilha do Rei Afogado (sem objetos solidos)

P = json.loads((HERE / "projeto_chatgpt.json").read_text(encoding="utf-8"))
ZONAS = {z["nome"]: z for z in P["zonas"]}
rng = random.Random(1717)
YY, XX = np.mgrid[0:GROUND[1], 0:GROUND[0]].astype(np.float32) * GS


def textura(nome):
    t = np.asarray(Image.open(HERE / "terrenos" / f"{nome}.png").convert("RGB").resize((TILE_GROUND, TILE_GROUND), Image.LANCZOS), np.float32)
    # emenda: espelha para a textura repetir sem costura
    t = np.concatenate([t, t[:, ::-1]], axis=1)
    t = np.concatenate([t, t[::-1]], axis=0)
    reps = (GROUND[1] // t.shape[0] + 1, GROUND[0] // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:GROUND[1], :GROUND[0]]


def ruido(cell, seed, amp=1.0):
    g = np.random.default_rng(seed).random((GROUND[1] // cell + 3, GROUND[0] // cell + 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(((GROUND[0] // cell + 3) * cell, (GROUND[1] // cell + 3) * cell), Image.BICUBIC)
    return (np.asarray(img, np.float32)[:GROUND[1], :GROUND[0]] / 255 - 0.5) * 2 * amp


def suave(mask, r=3):
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def mix(base, layer, a):
    return base * (1 - a[..., None]) + layer * a[..., None]


def poligono(pts, ondula=0):
    im = Image.new("L", GROUND, 0)
    ImageDraw.Draw(im).polygon([(x / GS, y / GS) for x, y in pts], fill=255)
    m = np.asarray(im) > 0
    if ondula:
        # borda organica: desfoca e corta com ruido
        f = suave(m, ondula) + ruido(30, len(pts), 0.18)
        m = f > 0.5
    return m


def linha(pts, largura):
    im = Image.new("L", GROUND, 0)
    d = ImageDraw.Draw(im)
    w = max(1, int(largura / GS))
    d.line([(x / GS, y / GS) for x, y in pts], fill=255, width=w, joint="curve")
    for x, y in pts:
        d.ellipse([x / GS - w / 2, y / GS - w / 2, x / GS + w / 2, y / GS + w / 2], fill=255)
    return np.asarray(im) > 0


def pintar():
    tex = {n: textura(n) for n in ["terra_firme", "grama_pantanosa", "lama_rasa", "agua_rasa", "agua_funda",
                                   "madeira_passarela", "pedra_antiga", "terra_corrompida"]}
    # base: grama pantanosa misturada com terra
    img = mix(tex["grama_pantanosa"], tex["terra_firme"], np.clip(ruido(110, 1) + 0.35, 0, 1))
    zona_terreno = {"terra_firme": "terra_firme", "grama_pantanosa": "grama_pantanosa", "lama_rasa": "lama_rasa",
                    "agua_rasa": "lama_rasa", "agua_funda": "grama_pantanosa", "pedra_antiga": "pedra_antiga",
                    "terra_corrompida": "terra_corrompida"}
    lento = np.zeros(XX.shape, bool)
    for i, z in enumerate(P["zonas"]):
        x, y, w, h = z["retangulo_px"]
        m = (XX >= x) & (XX < x + w) & (YY >= y) & (YY < y + h)
        t = zona_terreno.get(z["terreno"], "grama_pantanosa")
        borda = suave(m.astype(np.float32), 40) * np.clip(ruido(60, 10 + i) + 0.9, 0, 1)
        # pedra antiga/terra corrompida em manchas (nao o retangulo inteiro)
        if t in ("pedra_antiga", "terra_corrompida"):
            borda *= np.clip(ruido(90, 30 + i) + 0.75, 0, 1)
        img = mix(img, tex[t], np.clip(borda, 0, 1))
        if t == "lama_rasa":
            lento |= m & (ruido(70, 50 + i) > -0.3)
    # agua rasa e funda
    rasa = np.zeros(XX.shape, bool)
    funda = np.zeros(XX.shape, bool)
    for j, a in enumerate(P["agua"]):
        m = poligono(a["poligono_px"], ondula=18)
        if a["tipo"] == "funda":
            funda |= m
        else:
            rasa |= m
    rasa &= ~funda
    img = mix(img, tex["agua_rasa"], suave(rasa, 6))
    img = mix(img, mix(tex["agua_rasa"], tex["agua_funda"], suave(funda, 14)), suave(funda, 4))
    lento |= rasa
    # caminhos: trilha de terra; passarela/ponte de tabuas (andavel ate sobre a agua funda)
    trilha = np.zeros(XX.shape, bool)
    tabua = np.zeros(XX.shape, bool)
    for c in P["caminhos"]:
        m = linha(c["pontos_px"], c["largura_px"])
        if c["tipo"] == "trilha":
            trilha |= m
        else:
            tabua |= m
    trilha_suave = suave(trilha & ~funda, 4) * np.clip(ruido(25, 77) + 1.1, 0, 1)
    terra_clara = tex["terra_firme"] * np.array([1.35, 1.22, 1.0], np.float32)  # trilha batida, mais clara
    img = mix(img, terra_clara, np.clip(trilha_suave, 0, 1))
    # tabuas: sombra na agua + madeira
    img *= (1 - suave(ndimage.binary_dilation(tabua, iterations=4) & ~tabua, 3) * 0.45)[..., None]
    img = mix(img, tex["madeira_passarela"], tabua.astype(np.float32))
    lento &= ~(trilha | tabua)
    # escurece a beira do mapa (borda e mata fechada)
    borda = np.minimum.reduce([XX, YY, WORLD[0] - XX, WORLD[1] - YY])
    img *= np.clip(0.55 + borda / 260, 0.55, 1.0)[..., None]
    andavel = ~funda | tabua
    andavel &= borda > 70
    return np.clip(img, 0, 255).astype(np.uint8), andavel, lento, funda, rasa, trilha | tabua


# --- objetos -----------------------------------------------------------------------------------
ONDE = {  # id -> zonas (nomes do projeto) e onde no terreno
    "arvore_pantanosa_grande": (["Bosque das Raizes", "Lago das Sombras", "Ilha do Rei Afogado"], "terra"),
    "arvore_pantanosa_media": (None, "terra"),
    "arvore_morta": (["Cemiterio Esquecido", "Ruinas do Culto"], "terra"),
    "arvore_raiz_gigante": (["Bosque das Raizes", "Ilha do Rei Afogado"], "terra"),
    "raiz_exposta": (["Bosque das Raizes", "Charco dos Venenos"], "terra"),
    "raiz_elevada": (["Bosque das Raizes"], "terra"),
    "tronco_caido": (["Bosque das Raizes", "Charco dos Venenos", "Lago das Sombras"], "terra"),
    "pedra_musgosa_pequena": (None, "terra"),
    "pedra_musgosa_media": (["Bosque das Raizes", "Ruinas do Culto", "Cemiterio Esquecido"], "terra"),
    "pedra_musgosa_grande": (["Lago das Sombras", "Cemiterio Esquecido", "Ilha do Rei Afogado"], "terra"),
    "capim_pantanoso": (None, "terra"),
    "junco_alto": (None, "margem"),
    "lirio_agua": (None, "agua"),
    "cogumelo_venenoso": (["Charco dos Venenos", "Cemiterio Esquecido"], "terra"),
    "cogumelo_luminoso": (["Bosque das Raizes", "Ruinas do Culto", "Ilha do Rei Afogado"], "terra"),
    "flor_pantanosa": (["Bosque das Raizes", "Charco dos Venenos"], "terra"),
    "bolhas_lama": (["Charco dos Venenos", "Aldeia Afundada"], "lama"),
    "nevoa_pantanosa": (None, "qualquer"),
    "cabana_abandonada": (["Aldeia Afundada"], "terra"),
    "barco_quebrado": (["Aldeia Afundada", "Lago das Sombras"], "margem"),
    "cerca_quebrada": (["Aldeia Afundada", "Entrada de Valdoria"], "terra"),
    "barril_velho": (["Aldeia Afundada", "Entrada de Valdoria"], "terra"),
    "caixote_madeira": (["Aldeia Afundada", "Entrada de Valdoria"], "terra"),
    "lapide_antiga": (["Cemiterio Esquecido"], "terra"),
    "mausoleu_destruido": (["Cemiterio Esquecido"], "terra"),
    "estatua_partida": (["Ruinas do Culto", "Ilha do Rei Afogado"], "terra"),
    "coluna_ruina": (["Ruinas do Culto"], "terra"),
    "altar_corrompido": (["Ruinas do Culto", "Ilha do Rei Afogado"], "terra"),
    "totem_pantanoso": (["Charco dos Venenos", "Ruinas do Culto", "Ilha do Rei Afogado"], "terra"),
    "tocha_verde": (["Entrada de Valdoria", "Ruinas do Culto", "Cemiterio Esquecido"], "caminho"),
    "lanterna_espiritual": (["Cemiterio Esquecido", "Ruinas do Culto"], "caminho"),
    "carcaca_animal": (["Charco dos Venenos", "Aldeia Afundada"], "terra"),
    "ossos_espalhados": (["Cemiterio Esquecido", "Ruinas do Culto", "Ilha do Rei Afogado"], "terra"),
}
FIXOS = {"cabana_pescador": [(1250, 4980)], "portal_valdoria": [(380, 5160)], "portal_proxima_regiao": [(3200, 330)],
         "mausoleu_destruido": [(5800, 1750), (4850, 2650)], "altar_corrompido": [(2500, 450), (900, 380)]}
SEM_SPRITE = {"passarela_reta", "passarela_curva", "ponte_madeira"}  # viraram tabuas pintadas no chao


def info_obj(o):
    im = Image.open(OBJ / f"{o['id']}.png")
    alvo_w, alvo_h = o["tamanho_na_tela_px"]
    s = min(alvo_h / im.height, alvo_w / im.width * 1.15)
    return im, s


def entrada(o, im, s, x, y, flip=False):
    w, h = im.size
    porte = o["porte"]
    e = {"name": o["id"], "texture": f"{RES}assets/maps/pantano_v2/objetos/{o['id']}.png", "pos": [round(x), round(y)],
         "offset": [-w / 2, -h], "scale": round(s, 4), "flip_h": flip, "porte": porte}
    if porte in ("baixo", "joelho"):
        e["layer"] = "ground"
        e["collisions"] = []
    else:
        pw, pd = o["pe_px"]
        frente = max(14.0, pd / 3.0)
        e["collisions"] = [[round(-pw / 2, 1), round(-frente, 1), round(pw, 1), round(frente, 1)]]
        e["base"] = 0.0
    return e


def espalhar(mapas):
    andavel, funda, rasa, lama, caminho = mapas
    terra = andavel & ~rasa & ~caminho & ~funda
    margem = ndimage.binary_dilation(funda | rasa, iterations=10) & ~ndimage.binary_erosion(funda | rasa, iterations=6) & ~caminho
    agua = (rasa | funda) & ~ndimage.binary_dilation(caminho, iterations=6)
    qualquer = np.ones(XX.shape, bool)
    lugares = {"terra": terra, "margem": margem, "agua": agua, "lama": lama & ~caminho, "qualquer": qualquer,
               "caminho": ndimage.binary_dilation(caminho, iterations=70) & ~ndimage.binary_dilation(caminho, iterations=50) & terra}
    perto_caminho = ndimage.binary_dilation(caminho, iterations=55)
    proibido = [(tuple(P["spawn_px"]), 260)] + [(tuple(n["onde_px"]), 170) for n in P["npcs"]] + \
               [(xy, 260) for k in ("portal_valdoria", "portal_proxima_regiao") for xy in FIXOS[k]]
    zona_segura = P["regras_adicionais"].get("zona_segura", {})
    props = []
    solidos = []  # (x, y, raio) dos objetos de cintura ja postos
    # fixos primeiro
    por_id = {o["id"]: o for o in P["objetos"]}
    for oid, pts in FIXOS.items():
        o = por_id[oid]
        im, s = info_obj(o)
        for x, y in pts:
            e = entrada(o, im, s, x, y)
            if oid.startswith("portal"):
                e["collisions"] = []  # o portal do jogo ja e um ponto de passagem
                e["layer"] = "ground"
            props.append(e)
            solidos.append((x, y, o["pe_px"][0] * 0.7))
    ordem = sorted(P["objetos"], key=lambda o: {"cintura": 0, "joelho": 1, "baixo": 2}[o["porte"]])
    for o in ordem:
        oid = o["id"]
        if oid in FIXOS or oid in SEM_SPRITE or oid not in ONDE:
            continue
        zonas, onde = ONDE[oid]
        n = max(1, round(o["quantidade"] * FATOR[o["porte"]] * REDUZ.get(oid, 1.0)))
        im, s = info_obj(o)
        mask = lugares[onde].copy()
        if zonas:
            zm = np.zeros(XX.shape, bool)
            for zn in zonas:
                x, y, w, h = ZONAS[zn]["retangulo_px"]
                zm |= (XX >= x) & (XX < x + w) & (YY >= y) & (YY < y + h)
            mask &= zm
        if o["porte"] == "cintura":
            mask &= ~perto_caminho  # caminho principal livre
        ys, xs = np.nonzero(mask)
        if xs.size == 0:
            print("sem lugar para", oid)
            continue
        raio = max(o["pe_px"][0] * 0.75, 60) if o["porte"] == "cintura" else 40
        postos = 0
        for _ in range(n * 40):
            if postos >= n:
                break
            k = rng.randrange(xs.size)
            x, y = float(xs[k] * GS + rng.random() * GS), float(ys[k] * GS + rng.random() * GS)
            if any(math.hypot(x - px, y - py) < r for (px, py), r in proibido):
                continue
            if zona_segura and o["porte"] == "cintura" and math.hypot(x - zona_segura["centro_px"][0], y - zona_segura["centro_px"][1]) < zona_segura["raio_px"] * 0.6:
                continue
            if o["porte"] == "cintura" and math.hypot(x - ARENA[0][0], y - ARENA[0][1]) < ARENA[1]:
                continue
            if o["porte"] == "cintura":
                if any(math.hypot(x - sx, y - sy) < raio + sr for sx, sy, sr in solidos):
                    continue
                # a faixa do pe inteira em chao andavel (nao fica meio dentro da agua)
                pw = o["pe_px"][0] / 2
                ok = all(andavel[min(GROUND[1] - 1, int((y + dy) / GS)), min(GROUND[0] - 1, max(0, int((x + dx) / GS)))]
                         for dx in (-pw, 0, pw) for dy in (-o["pe_px"][1] / 3, 0))
                if not ok:
                    continue
                solidos.append((x, y, raio))
            elif any(math.hypot(x - p["pos"][0], y - p["pos"][1]) < raio for p in props[-60:] if p["name"] == oid):
                continue
            props.append(entrada(o, im, s * rng.uniform(0.9, 1.08), x, y, flip=rng.random() < 0.5))
            postos += 1
        print(f"{oid:26s} {o['porte']:8s} {postos}/{n}")
    return props


def main():
    (KIT / "chunks").mkdir(parents=True, exist_ok=True)
    (HERE / "out").mkdir(exist_ok=True)
    # nevoa semitransparente
    nev = OBJ / "nevoa_pantanosa.png"
    a = np.asarray(Image.open(nev).convert("RGBA")).copy()
    if a[..., 3].max() > 200:
        al = Image.fromarray((a[..., 3].astype(np.float32) * 0.24).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
        a[..., 3] = np.asarray(al)
        Image.fromarray(a, "RGBA").save(nev, optimize=True)
    rgb, andavel, lento, funda, rasa, caminho = pintar()
    props = espalhar((andavel, funda, rasa, lento, caminho))
    full = np.dstack([rgb, np.full(rgb.shape[:2], 255, np.uint8)])
    for gy in range(GRID[1]):
        for gx in range(GRID[0]):
            part = full[gy * CHUNK[1]:(gy + 1) * CHUNK[1], gx * CHUNK[0]:(gx + 1) * CHUNK[0], :3]
            Image.fromarray(part, "RGB").save(KIT / "chunks" / f"pantano_v2_chunk_{gx:02d}_{gy:02d}.png", optimize=True)
    h, w = WORLD[1] // CELL, WORLD[0] // CELL
    k = CELL // GS
    walk = ndimage.binary_erosion(andavel, iterations=2)
    small = walk[: h * k, : w * k].reshape(h, k, w, k).mean(axis=(1, 3)) > 0.6
    slow = lento[: h * k, : w * k].reshape(h, k, w, k).mean(axis=(1, 3)) > 0.5
    Image.fromarray((small * 255).astype(np.uint8)).save(KIT / "pantano_v2_walkable.png")
    Image.fromarray((slow * 255).astype(np.uint8)).save(KIT / "pantano_v2_lento.png")
    # pontos importantes andaveis e ligados entre si
    pontos = {"spawn": P["spawn_px"]} | {n["nome"]: n["onde_px"] for n in P["npcs"]} | \
             {"portal_" + p["para"]: p["onde_px"] for p in P["portais"]}
    livre = small.copy()
    for e in props:
        for c in e.get("collisions", []):
            x0, y0 = e["pos"][0] + c[0], e["pos"][1] + c[1]
            livre[int(y0 // CELL):int((y0 + c[3]) // CELL) + 1, int(x0 // CELL):int((x0 + c[2]) // CELL) + 1] = False
    lab, _ = ndimage.label(livre)
    regiao = {}
    for nome, (x, y) in pontos.items():
        cy, cx = int(y) // CELL, int(x) // CELL
        win = lab[max(0, cy - 3):cy + 4, max(0, cx - 3):cx + 4]
        regiao[nome] = int(np.bincount(win[win > 0]).argmax()) if (win > 0).any() else 0
    principal = regiao["spawn"]
    for nome, r in regiao.items():
        print(("OK " if r == principal and r > 0 else "FORA ") + nome)
    kit = {
        "version": 1, "world_size": list(WORLD), "ground_scale": GS, "chunk_grid": list(GRID), "chunk_px": list(CHUNK),
        "chunks_dir": f"{RES}assets/maps/pantano_v2/chunks", "chunk_prefix": "pantano_v2_chunk",
        "walkable_mask": {"path": f"{RES}assets/maps/pantano_v2/pantano_v2_walkable.png", "cell": CELL},
        "slow_mask": {"path": f"{RES}assets/maps/pantano_v2/pantano_v2_lento.png", "cell": CELL, "fator": 0.72},
        "minimap": f"{RES}assets/maps/pantano_v2/pantano_v2_minimap.png",
        "spawn": P["spawn_px"], "npcs": {n["nome"]: n["onde_px"] for n in P["npcs"]},
        "portais": {p["para"]: p["onde_px"] for p in P["portais"]},
        "solids": [], "props": props, "vehicles": [],
    }
    DATA_PATH.write_text(json.dumps(kit, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    # minimapa e previas
    q = 4
    pv = Image.fromarray(full, "RGBA").resize((WORLD[0] // q, WORLD[1] // q), Image.LANCZOS)
    cache = {}
    for p in sorted(props, key=lambda p: (p.get("layer") != "ground", p["pos"][1])):
        im = cache.setdefault(p["texture"], Image.open(ROOT / p["texture"].replace(RES, "")).convert("RGBA"))
        if p.get("flip_h"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        sc = p["scale"] / q
        ww, hh = max(1, round(im.width * sc)), max(1, round(im.height * sc))
        x = round(p["pos"][0] / q + p["offset"][0] * sc)
        y = round(p["pos"][1] / q + p["offset"][1] * sc)
        pv.alpha_composite(im.resize((ww, hh), Image.LANCZOS), (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
    pv.resize((1600, 1440), Image.LANCZOS).save(KIT / "pantano_v2_minimap.png")
    pv.save(HERE / "out/preview.png")
    dbg = pv.copy()
    dr = ImageDraw.Draw(dbg)
    blk = Image.fromarray(((~small) * 120).astype(np.uint8)).resize(dbg.size)
    dbg.paste(Image.new("RGBA", dbg.size, (255, 0, 0, 255)), (0, 0), blk)
    for p in props:
        for c in p.get("collisions", []):
            x0, y0 = p["pos"][0] + c[0], p["pos"][1] + c[1]
            dr.rectangle([x0 / q, y0 / q, (x0 + c[2]) / q, (y0 + c[3]) / q], outline=(255, 255, 0, 255))
    for nome, (x, y) in pontos.items():
        dr.ellipse([x / q - 7, y / q - 7, x / q + 7, y / q + 7], fill=(0, 255, 255, 255))
    dbg.save(HERE / "out/preview_colisao.png")
    print("objetos", len(props))


if __name__ == "__main__":
    main()
