"""Mobs e golpes refeitos em 2026-11-22 (tinham cortes/pedacos de outros quadros).

Fontes do ChatGPT (fundo verde) em tools/mob_sprites/fonte_refeitos/ (pedidos.json = prompts usados).
- Draco Jovem e Javali (selvagem + rei, mesma arte): animacoes inteiras em assets/sprites/mobs/<slug>/.
  A altura do idle e escolhida para que NENHUMA animacao precise encolher para caber no quadro de 192
  (bicho comprido: o bote/galope e mais largo que o idle). O tamanho no jogo vem de ENEMY_SIZE
  (altura visivel), entao a altura no quadro nao muda o tamanho em jogo.
- Golpes especiais (tiras de 8 quadros em assets/sprites/mobs/visuais/, mesmos nomes de antes:
  combat_visuals.json nao muda).
uso (raiz do repo): python3 -I tools/mob_sprites/importar_refeitos.py [grupo ...]
ATENCAO: os grupos so de ataque (aranhas, lobo) diminuem as outras animacoes do mob quando o ataque
nao cabe; rode cada um UMA vez (rodar de novo diminui de novo). Para refazer, restaure as pastas do
mob pelo git antes.
"""
import glob
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTE = os.path.join(ROOT, "tools", "mob_sprites", "fonte_refeitos")
TOOL = os.path.join(ROOT, "tools", "mob_sprites", "import_mob_strip.py")
MOBS = os.path.join(ROOT, "assets", "sprites", "mobs")
VIS = os.path.join(MOBS, "visuais")
BASE = ["--seams", "--tolerance", "120", "--spill"]
# folhas pedidas em fundo magenta (bicho verde/oliva): tira o reflexo rosa em vez do verde
BASE_MAGENTA = ["--seams", "--tolerance", "120", "--spill-magenta"]
MAGENTA = {"aranha_venenosa_attack.png", "aranha_matriarca_attack.png"}

# grupo -> (slugs que recebem as animacoes, altura inicial do idle, [(anim, fonte, quadros)], [(fonte, tira)])
GRUPOS = {
    "draco": (["draco_jovem"], 96, [("idle", "draco_jovem_idle.png", 6), ("walk", "draco_jovem_walk.png", 8),
                                    ("attack", "draco_jovem_attack.png", 6), ("death", "draco_jovem_death.png", 8)],
              [("draco_ataque_cauda.png", "draco_medieval_ataque_cauda_8f_192x192.png"),
               ("draco_ataque_fogo.png", "draco_medieval_ataque_fogo_8f_192x192.png"),
               ("draco_ataque_mordida.png", "draco_medieval_ataque_mordida_8f_192x192.png")]),
    "javali": (["javali_selvagem", "javali_rei"], 120, [("idle", "javali_idle.png", 6), ("walk", "javali_walk.png", 8),
                                                        ("run", "javali_run.png", 8), ("death", "javali_death.png", 8)], []),
    "aprendiz": (["aprendiz_corrompido"], None, [], [("aprendiz_chute.png", "aprendiz_corrompido_attack_chute_8f_192x192.png"),
                                                     ("aprendiz_cast.png", "aprendiz_corrompido_cast_8f_192x192.png")]),
    "bandido": (["bandido_colinas"], None, [], [("bandido_ilusao.png", "bandido_colinas_ilusao_8f_192x192.png"),
                                                ("bandido_roubo.png", "bandido_colinas_roubo_8f_192x192.png")]),
    "senhor": (["senhor_colinas"], None, [], [("senhor_investida.png", "senhor_colinas_investida_8f_192x192.png"),
                                              ("senhor_lancamento.png", "senhor_colinas_lancamento_8f_192x192.png")]),
    "espectro": (["espectro_arcano"], None, [], [("espectro_mundo_espiritual.png", "espectro_arcano_mundo_espiritual_8f_192x192.png")]),
    "cavaleiro": (["cavaleiro_sombrio"], None, [], [("cavaleiro_corrompido.png", "cavaleiro_sombrio_corrompido_8f_192x192.png", "median")]),
    # ataques com a ponta da pata cortada na borda (arte antiga): so o ataque, na escala do idle atual
    "venenosa": (["aranha_venenosa"], None, [("attack", "aranha_venenosa_attack.png", 6)], []),
    "rainha": (["aranha_rainha"], None, [("attack", "aranha_rainha_attack.png", 6)], []),
    "matriarca": (["aranha_matriarca"], None, [("attack", "aranha_matriarca_attack.png", 6)], []),
    "lobo": (["lobo_selvagem"], None, [("attack", "lobo_attack.png", 6)], []),
    "guardiao": (["guardiao_cristalino"], None, [], [("guardiao_sem_lanca.png", "guardiao_sem_lanca_idle_8f_192x192.png"),
                                                     ("guardiao_criando_lanca.png", "guardiao_criando_lanca_8f_192x192.png")]),
}


# fumaca translucida desenhada sobre o verde sai esverdeada: vira roxa (a fumaca da Ilusao e roxa)
ROXEAR = {"bandido_colinas_ilusao_8f_192x192.png"}


def roxear(path):
    im = np.array(Image.open(path).convert("RGBA")).astype(np.int32)
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    verde = (g > np.maximum(r, b) + 6) & (im[:, :, 3] > 0)
    novo = im.copy()
    novo[:, :, 0] = np.where(verde, (g * 0.78).astype(np.int32), r)
    novo[:, :, 1] = np.where(verde, np.minimum(r, b), g)
    novo[:, :, 2] = np.where(verde, np.minimum(255, (g * 1.05).astype(np.int32)), b)
    Image.fromarray(novo.clip(0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)


# forma espiritual translucida sobre o verde sai ciano-esverdeada: puxa para azul claro
AZULAR = {"espectro_arcano_mundo_espiritual_8f_192x192.png"}


def azular(path):
    im = np.array(Image.open(path).convert("RGBA")).astype(np.int32)
    g, b = im[:, :, 1], im[:, :, 2]
    im[:, :, 1] = np.where(im[:, :, 3] > 0, np.minimum(g, (b * 0.82).astype(np.int32)), g)
    Image.fromarray(im.clip(0, 255).astype(np.uint8), "RGBA").save(path, optimize=True)


def altura_mediana(slug):
    hs = []
    for f in sorted(glob.glob(os.path.join(MOBS, slug, "idle_left", "*.png"))):
        a = np.array(Image.open(f))[:, :, 3]
        ys = np.nonzero(a.any(axis=1))[0]
        hs.append(ys.max() - ys.min() + 1)
    return float(np.median(hs))


def rodar(args):
    r = subprocess.run([sys.executable, "-I", TOOL] + args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(r.stdout + r.stderr)
    m = re.search(r"ENCOLHEU ([0-9.]+)->([0-9.]+)", r.stderr)
    global ULTIMA_RAZAO
    ULTIMA_RAZAO = float(m.group(2)) / float(m.group(1)) if m else 1.0
    return r.stdout.strip(), m is not None


ULTIMA_RAZAO = 1.0


def diminuir_resto(slug, anim_nova, razao):
    """O ataque novo so cabe no quadro menor: diminui as outras animacoes do mob na mesma razao
    (pes no mesmo chao), assim o bicho nao muda de tamanho ao atacar. ENEMY_SIZE usa a altura
    visivel, entao o tamanho no jogo continua o mesmo."""
    for pasta in sorted(glob.glob(os.path.join(MOBS, slug, "*_*"))):
        nome = os.path.basename(pasta)
        if not os.path.isdir(pasta) or nome.startswith(anim_nova + "_"):
            continue
        for f in sorted(glob.glob(os.path.join(pasta, "*.png"))):
            im = Image.open(f).convert("RGBA")
            w, h = im.size
            nw, nh = max(1, round(w * razao)), max(1, round(h * razao))
            tela = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            tela.alpha_composite(im.resize((nw, nh), Image.LANCZOS), ((w - nw) // 2, h - nh))
            tela.save(f, optimize=True)


def animacoes(slug, altura, anims):
    # sem idle novo: usa a altura do idle que ja esta no jogo
    ref = None if anims[0][0] == "idle" else altura_mediana(slug)
    encolheu = False
    for anim, fonte, n in anims:
        args = [slug, anim, os.path.join(FONTE, fonte), "--frames", str(n)] + (BASE_MAGENTA if fonte in MAGENTA else BASE)
        # andar/correr: mediana dos quadros; ataque/morte: 1o quadro (em pe, antes do bote/da queda)
        modo = "median" if anim in ("walk", "run") else "first"
        args += ["--body-height", str(altura)] if anim == "idle" else ["--match-height", str(ref), "--match", modo]
        _out, enc = rodar(args)
        encolheu |= enc
        if anim == "idle":
            ref = altura_mediana(slug)
    return ref, encolheu


def main():
    pedidos = sys.argv[1:] or list(GRUPOS)
    for g in pedidos:
        slugs, altura, anims, tiras = GRUPOS[g]
        if anims and anims[0][0] != "idle":
            _ref, encolheu = animacoes(slugs[0], None, anims)
            if encolheu:
                diminuir_resto(slugs[0], anims[0][0], ULTIMA_RAZAO)
            print(g, "resto do mob diminuido %.3f para o ataque caber" % ULTIMA_RAZAO if encolheu else "na escala do idle")
        elif anims:
            while True:
                ref, encolheu = animacoes(slugs[0], altura, anims)
                if not encolheu or altura <= 60:
                    break
                altura -= 6
            for outro in slugs[1:]:
                animacoes(outro, altura, anims)
            print(g, "altura do idle", altura)
        ref = altura_mediana(slugs[0])
        for fonte, tira, *modo in tiras:
            # "first": 1o quadro = pose parada; "median" quando a tira comeca curvado/caido
            out, enc = rodar([slugs[0], "attack", os.path.join(FONTE, fonte), "--frames", "8", "--match-height", str(ref),
                              "--match", (modo or ["first"])[0], "--tira", os.path.join(VIS, tira)] + BASE)
            if tira in ROXEAR:
                roxear(os.path.join(VIS, tira))
            if tira in AZULAR:
                azular(os.path.join(VIS, tira))
            print(out, "(encolheu para caber)" if enc else "")
    print("ok")


if __name__ == "__main__":
    main()
