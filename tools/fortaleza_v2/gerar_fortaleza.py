"""Gera a Fortaleza de Cinzas (ember_fortress, kit igual ao Pantano) a partir do projeto do ChatGPT.

Entradas: tools/fortaleza_v2/projeto_chatgpt.json (zonas, lava, cinza grossa, caminhos, objetos com
          "porte" e "pe_px", NPCs, portais, arena do chefe)
          tools/fortaleza_v2/terrenos/*.png e assets/maps/fortaleza_v2/objetos/*.png (recortar.py)
Saidas:   assets/maps/fortaleza_v2/chunks/*.png (8x9 pedacos de 400x320, escala 2 -> 6400x5760;
          transparentes na lava) e assets/maps/fortaleza_v2/lava/lava_*.png (lava viva, por baixo)
          assets/maps/fortaleza_v2/fortaleza_v2_walkable.png e _lento.png (mascaras, celula 16 px)
          assets/maps/fortaleza_v2/fortaleza_v2_minimap.png, data/fortress_kit.json
          tools/fortaleza_v2/out/preview*.png

No projeto, "agua funda" = LAVA (bloqueia) e "agua rasa" = cinza grossa (deixa lento). Onde um
caminho cruza a lava vira ponte de pedra (andavel). A arena do chefe e o portal do norte ficam numa
plataforma recortada da lava.

Regra de colisao (Mark, 2026-11-17) igual ao Pantano (ver tools/pantano_v2/gerar_pantano.py):
baixo/joelho sem colisao; cintura solido so no terco da frente da faixa do pe; portao e portal
so com as colunas dos lados solidas (o vao do meio passa).

uso (raiz do projeto): python3 -I tools/fortaleza_v2/gerar_fortaleza.py
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
KIT = ROOT / "assets/maps/fortaleza_v2"
OBJ = KIT / "objetos"
RES = "res://"
DATA_PATH = ROOT / "data/fortress_kit.json"
PREFIXO = "fortaleza_v2"
# 2026-11-23: ampliada por expansao.json (mundo, grade, zonas/caminhos/lava novos)
EXP = json.loads((HERE / "expansao.json").read_text(encoding="utf-8"))
WORLD = tuple(EXP["mundo"])
GS = 2
GROUND = (WORLD[0] // GS, WORLD[1] // GS)
GRID = tuple(EXP["grade"])
CHUNK = (GROUND[0] // GRID[0], GROUND[1] // GRID[1])
CELL = 16
TILE_GROUND = 200
FATOR = {"baixo": 0.3, "joelho": 0.45, "cintura": 0.55}
REDUZ = {"muralha_negra_reta": 0.6, "muralha_negra_canto": 0.6, "corrente_gigante": 0.6, "estandarte_queimado": 0.7,
         "brasa_solta": 0.6, "carroca_destruida": 0.6}

P = json.loads((HERE / "projeto_chatgpt.json").read_text(encoding="utf-8"))
for _k in ("zonas", "caminhos", "agua"):
    P[_k] = P[_k] + EXP[_k]
ZONAS = {z["nome"]: z for z in P["zonas"]}
ARENA = (tuple(P["arena_chefe"]["centro_px"]), float(P["arena_chefe"]["raio_px"]))
PORTAL_NORTE = (6050, 220)
PORTAL_PANTANO = (420, 5350)
TRONO = (5790, 600)
rng = random.Random(4646)
YY, XX = np.mgrid[0:GROUND[1], 0:GROUND[0]].astype(np.float32) * GS


TILE = {"pedra_fortaleza": 120, "lava_incandescente": 150, "obsidiana_polida": 150}  # lajes e lava menores


def textura(nome):
    lado = TILE.get(nome, TILE_GROUND)
    t = np.asarray(Image.open(HERE / "terrenos" / f"{nome}.png").convert("RGB").resize((lado, lado), Image.LANCZOS), np.float32)
    t = np.concatenate([t, t[:, ::-1]], axis=1)
    t = np.concatenate([t, t[::-1]], axis=0)
    reps = (GROUND[1] // t.shape[0] + 1, GROUND[0] // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:GROUND[1], :GROUND[0]]


def ruido(cell, seed, amp=1.0):
    g = np.random.default_rng(seed).random((GROUND[1] // cell + 3, GROUND[0] // cell + 3)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize(((GROUND[0] // cell + 3) * cell, (GROUND[1] // cell + 3) * cell), Image.BICUBIC)
    return (np.asarray(img, np.float32)[:GROUND[1], :GROUND[0]] / 255 - 0.5) * 2 * amp


def suave(mask, r=3):
    return np.asarray(Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def mix(base, layer, a):
    return base * (1 - a[..., None]) + layer * a[..., None]


def poligono(pts, ondula=0):
    im = Image.new("L", GROUND, 0)
    ImageDraw.Draw(im).polygon([(x / GS, y / GS) for x, y in pts], fill=255)
    m = np.asarray(im) > 0
    if ondula:
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


def disco(c, r):
    return (XX - c[0]) ** 2 + (YY - c[1]) ** 2 <= r * r


def pintar():
    nomes = [t["id"] for t in P["terrenos"]]
    tex = {n: textura(n) for n in nomes}
    img = mix(tex["basalto_frio"], tex["cinzas_finas"], np.clip(ruido(120, 1) + 0.3, 0, 1))
    for i, z in enumerate(P["zonas"]):
        x, y, w, h = z["retangulo_px"]
        m = (XX >= x) & (XX < x + w) & (YY >= y) & (YY < y + h)
        t = z["terreno"] if z["terreno"] in tex else "basalto_frio"
        borda = suave(m.astype(np.float32), 40) * np.clip(ruido(60, 10 + i) + 0.9, 0, 1)
        if t == "pedra_fortaleza":  # piso de construcao em manchas grandes, nao o retangulo inteiro
            borda *= np.clip(ruido(110, 30 + i) + 0.85, 0, 1)
        img = mix(img, tex[t], np.clip(borda, 0, 1))
    # cinza grossa (lenta) e lava
    lento = np.zeros(XX.shape, bool)
    lava = np.zeros(XX.shape, bool)
    for a in P["agua"]:
        m = poligono(a["poligono_px"], ondula=18)
        if a["tipo"] == "funda":
            lava |= m
        else:
            lento |= m
    # plataforma da arena, do trono e do portal do norte (recortadas da lava)
    plataforma = disco(ARENA[0], ARENA[1]) | disco(PORTAL_NORTE, 210) | disco(TRONO, 170)
    plataforma |= linha([(ARENA[0][0], ARENA[0][1] - ARENA[1] + 60), PORTAL_NORTE], 240)
    for n in P["npcs"]:  # NPC nunca fica ilhado na lava (o Orven caia dentro do rio de lava)
        plataforma |= disco(tuple(n["onde_px"]), 170)
    lava &= ~plataforma
    lento &= ~lava
    img = mix(img, tex["cinzas_grossas"], suave(lento, 8))
    # caminhos: estrada de pedra / trilha de cinzas; cruzando lava vira ponte
    estrada = np.zeros(XX.shape, bool)
    trilha = np.zeros(XX.shape, bool)
    ponte = np.zeros(XX.shape, bool)
    for c in P["caminhos"]:
        m = linha(c["pontos_px"], c["largura_px"])
        if "ponte" in c["tipo"]:
            ponte |= m & ndimage.binary_dilation(lava, iterations=30)
            estrada |= m
        elif "trilha" in c["tipo"]:
            trilha |= m
        else:
            estrada |= m
    ponte |= (estrada | trilha) & lava
    lento &= ~(estrada | trilha)
    claro = tex["cinzas_finas"] * np.array([1.25, 1.18, 1.1], np.float32)
    img = mix(img, claro, np.clip(suave(trilha & ~lava, 4) * np.clip(ruido(25, 77) + 1.1, 0, 1), 0, 1))
    # estrada: lajes mais claras com meio-fio escuro (se le como rua mesmo em zona de pedra)
    est = estrada & ~lava
    meio_fio = ndimage.binary_dilation(est, iterations=3) & ~est
    img = mix(img, img * 0.45, suave(meio_fio, 1))
    img = mix(img, tex["pedra_fortaleza"] * np.array([1.3, 1.24, 1.18], np.float32), np.clip(suave(est, 1.5), 0, 1))
    # lava: textura + brilho laranja em volta (luz da lava no chao)
    brilho = suave(lava, 22) * 0.55
    img = img + brilho[..., None] * np.array([150, 60, 0], np.float32)
    calor = np.clip(1.0 + ruido(70, 91, 0.25), 0.75, 1.25)[..., None]
    img = mix(img, tex["lava_incandescente"] * calor, suave(lava, 2))
    # arena de obsidiana com aro de brilho
    arena = disco(ARENA[0], ARENA[1])
    img = mix(img, tex["obsidiana_polida"], suave(arena | disco(TRONO, 150) | disco(PORTAL_NORTE, 180), 3))
    aro = disco(ARENA[0], ARENA[1]) & ~disco(ARENA[0], ARENA[1] - 26)
    img = img + suave(aro, 3)[..., None] * np.array([120, 45, 10], np.float32)
    # pontes: pedra escura com sombra na lava e mureta
    img *= (1 - suave(ndimage.binary_dilation(ponte, iterations=5) & ~ponte, 3) * 0.6)[..., None]
    img = mix(img, tex["pedra_fortaleza"] * np.array([1.25, 1.18, 1.1], np.float32), ponte.astype(np.float32))
    mureta = ponte & ~ndimage.binary_erosion(ponte, iterations=6)
    img = mix(img, tex["basalto_frio"] * 1.35, mureta.astype(np.float32))
    img = mix(img, img * 0.35, (mureta & ~ndimage.binary_erosion(ponte, iterations=2)).astype(np.float32))
    # borda do mapa escurecida
    borda = np.minimum.reduce([XX, YY, WORLD[0] - XX, WORLD[1] - YY])
    img *= np.clip(0.55 + borda / 260, 0.55, 1.0)[..., None]
    andavel = (~lava | ponte | plataforma) & (borda > 40)
    # lava viva: o chunk fica transparente na lava (sem ponte) e a lava animada passa por baixo
    alfa = 1.0 - suave(lava & ~ponte, 1.5)
    return np.clip(img, 0, 255).astype(np.uint8), andavel, lento, lava, estrada | trilha | ponte, alfa


ONDE = {  # id -> zonas do projeto (None = todas) e onde
    "rocha_basalto_pequena": (None, "terra"),
    "brasa_solta": (None, "margem"),
    "cinzas_espalhadas": (None, "terra"),
    "ossos_guerreiro": (["Campos de Basalto", "Estrada dos Condenados"], "terra"),
    "capacete_derretido": (["Campos de Basalto", "Forjas da Guerra", "Patio das Correntes"], "terra"),
    "espada_quebrada": (["Estrada dos Condenados", "Campos de Basalto"], "terra"),
    "rocha_vulcanica_media": (["Campos de Basalto", "Ninho dos Dracos", "Rios de Sangue da Montanha"], "terra"),
    "escombro_muralha": (["Estrada dos Condenados", "Forjas da Guerra", "Patio das Correntes"], "terra"),
    "degrau_basalto": (["Forjas da Guerra", "Patio das Correntes", "Cidadela do General Infernal"], "caminho"),
    "escudo_caido": (["Estrada dos Condenados", "Patio das Correntes"], "terra"),
    "rocha_basalto_grande": (["Campos de Basalto", "Rios de Sangue da Montanha", "Ninho dos Dracos"], "terra"),
    "coluna_obsidiana": (["Forjas da Guerra", "Patio das Correntes", "Cidadela do General Infernal"], "caminho"),
    "coluna_quebrada": (["Estrada dos Condenados", "Patio das Correntes", "Cidadela do General Infernal"], "caminho"),
    "muralha_negra_reta": (["Forjas da Guerra", "Patio das Correntes", "Cidadela do General Infernal"], "terra"),
    "muralha_negra_canto": (["Forjas da Guerra", "Patio das Correntes", "Cidadela do General Infernal"], "terra"),
    "torre_vigia_destruida": (["Estrada dos Condenados", "Patio das Correntes", "Campos de Basalto"], "terra"),
    "torre_infernal": (["Cidadela do General Infernal", "Patio das Correntes"], "terra"),
    "estandarte_queimado": (["Estrada dos Condenados", "Forjas da Guerra", "Patio das Correntes"], "caminho"),
    "forja_guerra": (["Forjas da Guerra"], "terra"),
    "bigorna_negra": (["Forjas da Guerra"], "terra"),
    "caldeirao_metal_fundido": (["Forjas da Guerra", "Patio das Correntes"], "terra"),
    "corrente_gigante": (["Patio das Correntes", "Cidadela do General Infernal"], "terra"),
    "jaula_prisioneiro": (["Forjas da Guerra", "Patio das Correntes"], "terra"),
    "carroca_destruida": (["Refugio das Cinzas", "Estrada dos Condenados", "Forjas da Guerra"], "terra"),
    "fogueira_refugio": (["Refugio das Cinzas"], "terra"),
    "estatua_guerreiro_caido": (["Forjas da Guerra", "Patio das Correntes", "Cidadela do General Infernal"], "caminho"),
    "altar_infernal": (["Cidadela do General Infernal", "Ninho dos Dracos"], "terra"),
    "ninho_draco": (["Ninho dos Dracos"], "terra"),
    "ovo_draco": (["Ninho dos Dracos"], "terra"),
    "cristal_enxofre": (["Campos de Basalto", "Ninho dos Dracos", "Rios de Sangue da Montanha"], "margem"),
    "esqueleto_criatura_gigante": (["Campos de Basalto", "Ninho dos Dracos"], "terra"),
    "braseiro_infernal": (["Cidadela do General Infernal", "Patio das Correntes"], "caminho"),
}
for _oid, _zs in EXP["onde_extra"].items():
    if ONDE[_oid][0] is not None:
        ONDE[_oid] = (ONDE[_oid][0] + _zs, ONDE[_oid][1])
FIXOS = {"portal_pantano_estrutura": [PORTAL_PANTANO], "portal_proxima_regiao_estrutura": [PORTAL_NORTE],
         "trono_general": [TRONO], "barraca_sobrevivente": [(1250, 5000), (300, 4800)],
         "portao_fortaleza": [(4840, 2700)],  # so um: o portao perto da arena tapava a luta com o chefe
         "braseiro_infernal": [(5700, 760), (6300, 760), (5730, 1050), (6270, 1050)]}
PORTAO = {"portao_fortaleza", "portal_pantano_estrutura", "portal_proxima_regiao_estrutura"}
SEM_SPRITE = {"ponte_basalto_antiga", "ponte_obsidiana"}  # viraram pontes pintadas no chao


def info_obj(o):
    im = Image.open(OBJ / f"{o['id']}.png")
    alvo_w, alvo_h = o["tamanho_na_tela_px"]
    s = min(alvo_h / im.height, alvo_w / im.width * 1.15)
    return im, s


def entrada(o, im, s, x, y, flip=False):
    w, h = im.size
    porte = o["porte"]
    e = {"name": o["id"], "texture": f"{RES}assets/maps/fortaleza_v2/objetos/{o['id']}.png", "pos": [round(x), round(y)],
         "offset": [-w / 2, -h], "scale": round(s, 4), "flip_h": flip, "porte": porte}
    if porte in ("baixo", "joelho"):
        e["layer"] = "ground"
        e["collisions"] = []
    else:
        pw, pd = o["pe_px"]
        frente = max(14.0, pd / 3.0)
        if o["id"] in PORTAO:  # so as colunas dos lados; o vao do meio passa
            lado = pw * 0.24
            e["collisions"] = [[round(-pw / 2, 1), round(-frente, 1), round(lado, 1), round(frente, 1)],
                               [round(pw / 2 - lado, 1), round(-frente, 1), round(lado, 1), round(frente, 1)]]
        else:
            e["collisions"] = [[round(-pw / 2, 1), round(-frente, 1), round(pw, 1), round(frente, 1)]]
        e["base"] = 0.0
    return e


def espalhar(mapas):
    andavel, lava, lento, caminho = mapas
    terra = andavel & ~lava & ~caminho
    margem = ndimage.binary_dilation(lava, iterations=45) & ~ndimage.binary_dilation(lava, iterations=12) & ~caminho & andavel
    lugares = {"terra": terra, "margem": margem,
               "caminho": ndimage.binary_dilation(caminho, iterations=75) & ~ndimage.binary_dilation(caminho, iterations=52) & terra}
    perto_caminho = ndimage.binary_dilation(caminho, iterations=55)
    proibido = [(tuple(P["spawn_px"]), 280)] + [(tuple(n["onde_px"]), 180) for n in P["npcs"]] + \
               [(PORTAL_PANTANO, 260), (PORTAL_NORTE, 260)]
    props, solidos = [], []
    por_id = {o["id"]: o for o in P["objetos"]}
    for oid, pts in FIXOS.items():
        o = por_id[oid]
        im, s = info_obj(o)
        for x, y in pts:
            e = entrada(o, im, s, x, y)
            if oid.startswith("portal"):
                e["collisions"] = []
                e["layer"] = "ground"
            props.append(e)
            solidos.append((x, y, o["pe_px"][0] * 0.7))
    ordem = sorted(P["objetos"], key=lambda o: {"cintura": 0, "joelho": 1, "baixo": 2}[o["porte"]])
    for o in ordem:
        oid = o["id"]
        if oid in SEM_SPRITE or oid not in ONDE or (oid in FIXOS and oid != "braseiro_infernal"):
            continue
        zonas, onde = ONDE[oid]
        n = max(1, round(o["quantidade"] * FATOR[o["porte"]] * REDUZ.get(oid, 1.0) * EXP.get("fator_quantidade", 1.0)))
        im, s = info_obj(o)
        mask = lugares[onde].copy()
        if zonas:
            zm = np.zeros(XX.shape, bool)
            for zn in zonas:
                x, y, w, h = ZONAS[zn]["retangulo_px"]
                zm |= (XX >= x) & (XX < x + w) & (YY >= y) & (YY < y + h)
            mask &= zm
        if o["porte"] == "cintura" and onde != "caminho":
            mask &= ~perto_caminho
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
            if o["porte"] == "cintura" and math.hypot(x - ARENA[0][0], y - ARENA[0][1]) < ARENA[1] + 120:
                continue
            if o["porte"] == "cintura":
                if any(math.hypot(x - sx, y - sy) < raio + sr for sx, sy, sr in solidos):
                    continue
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
        print(f"{oid:30s} {o['porte']:8s} {postos}/{n}")
    return props


LAVA_QUADROS = 8
LAVA_TILE = 512  # px do mundo; repete pelo mapa todo por baixo dos chunks


def lava_animada():
    """Quadros da lava viva: a textura de lava (espelhada = emenda sem costura) ondulando e com os
    veios pulsando. Deslocamento senoidal com periodo que divide o tile -> cada quadro emenda nas
    bordas, e a fase da volta inteira em LAVA_QUADROS -> o loop emenda no tempo."""
    t = np.asarray(Image.open(HERE / "terrenos" / "lava_incandescente.png").convert("RGB").resize(
        (LAVA_TILE // 2, LAVA_TILE // 2), Image.LANCZOS), np.float32)
    t = np.concatenate([t, t[:, ::-1]], axis=1)
    t = np.concatenate([t, t[::-1]], axis=0)
    n = LAVA_TILE
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    lum = t.mean(axis=2) / 255.0
    quente = np.clip((lum - 0.45) * 2.2, 0, 1)
    pasta = KIT / "lava"
    pasta.mkdir(parents=True, exist_ok=True)
    saida = []
    for k in range(LAVA_QUADROS):
        fase = 2 * math.pi * k / LAVA_QUADROS
        dx = 7 * np.sin(2 * math.pi * yy / (n / 2) + fase) + 4 * np.sin(2 * math.pi * (xx + yy) / n + fase)
        dy = 6 * np.sin(2 * math.pi * xx / (n / 2) - fase) + 3 * np.cos(2 * math.pi * (xx - yy) / n + fase)
        q = np.stack([ndimage.map_coordinates(t[..., c], [(yy + dy) % n, (xx + dx) % n], order=1, mode="grid-wrap")
                      for c in range(3)], axis=2)
        pulso = 1.0 + 0.22 * np.sin(fase + 2 * math.pi * (xx * 2 + yy) / n)[..., None] * quente[..., None]
        q = np.clip(q * pulso + quente[..., None] * np.array([18, 6, 0]) * (1 + np.sin(fase)), 0, 255).astype(np.uint8)
        nome = f"lava_{k}.png"
        Image.fromarray(q, "RGB").save(pasta / nome, optimize=True)
        saida.append(f"{RES}assets/maps/fortaleza_v2/lava/{nome}")
    return saida


def main():
    (KIT / "chunks").mkdir(parents=True, exist_ok=True)
    (HERE / "out").mkdir(exist_ok=True)
    rgb, andavel, lento, lava, caminho, alfa = pintar()
    quadros_lava = lava_animada()
    props = espalhar((andavel, lava, lento, caminho))
    full = np.dstack([rgb, (alfa * 255).astype(np.uint8)])
    for gy in range(GRID[1]):
        for gx in range(GRID[0]):
            part = full[gy * CHUNK[1]:(gy + 1) * CHUNK[1], gx * CHUNK[0]:(gx + 1) * CHUNK[0]]
            modo = "RGBA" if part[..., 3].min() < 255 else "RGB"
            Image.fromarray(part if modo == "RGBA" else part[..., :3], modo).save(
                KIT / "chunks" / f"{PREFIXO}_chunk_{gx:02d}_{gy:02d}.png", optimize=True)
    h, w = WORLD[1] // CELL, WORLD[0] // CELL
    k = CELL // GS
    walk = ndimage.binary_erosion(andavel, iterations=2)
    small = walk[: h * k, : w * k].reshape(h, k, w, k).mean(axis=(1, 3)) > 0.6
    slow = lento[: h * k, : w * k].reshape(h, k, w, k).mean(axis=(1, 3)) > 0.5
    Image.fromarray((small * 255).astype(np.uint8)).save(KIT / f"{PREFIXO}_walkable.png")
    Image.fromarray((slow * 255).astype(np.uint8)).save(KIT / f"{PREFIXO}_lento.png")
    pontos = {"spawn": P["spawn_px"], "arena": list(ARENA[0])} | {n["nome"]: n["onde_px"] for n in P["npcs"]} | \
             {"portal_pantano": list(PORTAL_PANTANO), "portal_norte": [PORTAL_NORTE[0], PORTAL_NORTE[1] + 60]}
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
        "chunks_dir": f"{RES}assets/maps/fortaleza_v2/chunks", "chunk_prefix": f"{PREFIXO}_chunk",
        "walkable_mask": {"path": f"{RES}assets/maps/fortaleza_v2/{PREFIXO}_walkable.png", "cell": CELL},
        "slow_mask": {"path": f"{RES}assets/maps/fortaleza_v2/{PREFIXO}_lento.png", "cell": CELL, "fator": 0.7},
        "minimap": f"{RES}assets/maps/fortaleza_v2/{PREFIXO}_minimap.png",
        "chao_animado": {"rect": [0, 0, WORLD[0], WORLD[1]], "frames": quadros_lava, "z": -101},
        "spawn": P["spawn_px"], "npcs": {n["nome"]: n["onde_px"] for n in P["npcs"]},
        "portais": {"swamp_almas": list(PORTAL_PANTANO), "proxima_regiao": list(PORTAL_NORTE)},
        "solids": [], "props": props, "vehicles": [],
    }
    DATA_PATH.write_text(json.dumps(kit, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    q = 4
    opaco = np.dstack([rgb, np.full(rgb.shape[:2], 255, np.uint8)])  # preview/minimapa com a lava pintada
    pv = Image.fromarray(opaco, "RGBA").resize((WORLD[0] // q, WORLD[1] // q), Image.LANCZOS)
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
    pv.resize((1600, 1408), Image.LANCZOS).save(KIT / f"{PREFIXO}_minimap.png")
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
