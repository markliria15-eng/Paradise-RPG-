"""Gera (ChatGPT) e processa os sprites de caminhada dos personagens jogaveis.

Uso:
  py tools/char_sprites/generate_player_sheets.py gerar guerreiro   # chama a API OpenAI (custa)
  py tools/char_sprites/generate_player_sheets.py processar guerreiro

"gerar" salva a folha bruta em tools/char_sprites/out/raw_<classe>.png.
"processar" recorta a folha 4x4 (linhas: frente, esquerda, direita, costas;
colunas: parado, passo 1, passo 2, passo 3), remove pixels soltos, alinha os pes
de todos os quadros na mesma base e grava em
assets/sprites/player_frames_caminhada_classes/<classe>/frames_192/.
"folhas" recorta as 5 folhas de fontes/ (parado, andar, ataque, dano, morte).
"""
from __future__ import annotations

import io
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BOT = ROOT / "tools/paradise_bot"
OUT = Path(__file__).resolve().parent / "out"
PACKS = ROOT / "assets/sprites/player_frames_caminhada_classes"
CELL = 192
FEET_Y = 184
TARGET_H = 168
ROWS = ["front", "left", "right", "back"]

DESCRICAO = {
    "guerreiro": "guerreiro de armadura de placas prateada com capa e tabardo azul, escudo azul com leao dourado, espada, cabelo castanho",
    "maga_de_fogo": "maga de fogo com vestido longo vermelho e dourado, cabelo castanho longo, cajado com orbe de fogo e chama na outra mao",
    "arqueiro": "arqueiro com capa verde-escura com capuz abaixado, armadura de couro marrom, arco longo e aljava nas costas, cabelo castanho",
}


def prompt_for(cls: str) -> str:
    return "\n".join([
        "Pixel art 2D de RPG de fantasia, visao top-down 3/4 (camera levemente de cima), no MESMO estilo, nivel de detalhe e paleta da imagem de referencia do javali.",
        f"Personagem: {DESCRICAO[cls]}. Mantenha as mesmas roupas e cores do personagem da outra imagem de referencia, mas redesenhado com mais detalhe e pixels limpos.",
        "Spritesheet em grade 4x4, quadros de tamanho identico, sem divisorias, sem texto, fundo transparente.",
        "Linha 1: virado para BAIXO (de frente para a camera). Linha 2: virado para a ESQUERDA (perfil). Linha 3: virado para a DIREITA (perfil). Linha 4: de COSTAS (virado para cima).",
        "Coluna 1: parado. Coluna 2: andando, pe esquerdo a frente. Coluna 3: andando, pes juntos (passagem). Coluna 4: andando, pe direito a frente.",
        "O MESMO personagem em todos os 16 quadros: mesma altura, mesma proporcao, mesmo tamanho na tela, centralizado no quadro, pes sempre na mesma linha de base perto da base do quadro.",
        "Corpo inteiro visivel, sem cortar a cabeca nem os pes, sem sombra no chao, sem efeitos soltos.",
    ])


def gerar(cls: str) -> None:
    sys.path.insert(0, str(BOT))
    from util import carregar_env_local  # noqa: E402
    from openai_assets import GeradorAssets  # noqa: E402
    import json

    carregar_env_local()
    cfg = json.loads((BOT / "config.json").read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    ref_player = OUT / f"ref_{cls}.png"
    Image.open(PACKS / cls / "frames_192" / f"{cls}_idle_front.png").convert("RGBA").resize((256, 256), Image.NEAREST).save(ref_player)
    ref_mob = ROOT / "assets/sprites/mobs/javali_selvagem/walk_front/javali_selvagem_walk_front_01.png"
    gerador = GeradorAssets(cfg, ROOT, OUT)
    bruto, precisa_recorte = gerador._gerar_imagem(prompt_for(cls), "1024x1024", True, [ref_mob, ref_player])
    img = Image.open(io.BytesIO(bruto)).convert("RGBA")
    if precisa_recorte:
        from openai_assets import _remover_fundo_magenta
        img = _remover_fundo_magenta(img)
    img.save(OUT / f"raw_{cls}.png")
    print("ok", OUT / f"raw_{cls}.png", img.size)


def label_parts(mask: np.ndarray) -> tuple[np.ndarray, list[int]]:
    """Componentes conectados (8 vizinhos): matriz de rotulos e tamanho de cada um."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    sizes = [0]
    for y in range(h):
        for x in np.flatnonzero(mask[y] & (labels[y] == 0)):
            if labels[y, x]:
                continue
            lab = len(sizes)
            q = deque([(y, x)])
            labels[y, x] = lab
            n = 0
            while q:
                cy, cx = q.popleft()
                n += 1
                for ny in (cy - 1, cy, cy + 1):
                    for nx in (cx - 1, cx, cx + 1):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = lab
                            q.append((ny, nx))
            sizes.append(n)
    return labels, sizes


def largest_parts(alpha: np.ndarray, keep_ratio: float = 0.04) -> np.ndarray:
    """Mantem o maior componente e pedacos grandes (arma, cajado); remove pixels soltos."""
    h, w = alpha.shape
    mask = alpha > 40
    labels = np.zeros((h, w), dtype=np.int32)
    sizes = [0]
    for y in range(h):
        for x in np.flatnonzero(mask[y] & (labels[y] == 0)):
            if labels[y, x]:
                continue
            lab = len(sizes)
            q = deque([(y, x)])
            labels[y, x] = lab
            n = 0
            while q:
                cy, cx = q.popleft()
                n += 1
                for ny in (cy - 1, cy, cy + 1):
                    for nx in (cx - 1, cx, cx + 1):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = lab
                            q.append((ny, nx))
            sizes.append(n)
    if len(sizes) == 1:
        return mask
    biggest = max(sizes)
    keep = [i for i, n in enumerate(sizes) if i and n >= biggest * keep_ratio]
    return np.isin(labels, keep)


def processar(cls: str) -> None:
    raw = Image.open(OUT / f"raw_{cls}.png").convert("RGBA")
    cw, ch = raw.width // 4, raw.height // 4
    cells = []
    for r in range(4):
        for c in range(4):
            cell = np.array(raw.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)))
            keep = largest_parts(cell[:, :, 3])
            cell[~keep] = 0
            ys, xs = np.nonzero(cell[:, :, 3] > 40)
            cells.append((r, c, cell, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
    # Escala unica para a classe inteira: o quadro mais alto vira TARGET_H.
    tallest = max(b[3] - b[1] for *_, b in cells)
    scale = TARGET_H / tallest
    dest = PACKS / cls / "frames_192"
    dest.mkdir(parents=True, exist_ok=True)
    # Centro horizontal por linha (direcao) = mediana dos centros, para o corpo nao "pular".
    row_center = {}
    for r in range(4):
        centers = [((b[0] + b[2]) / 2) for rr, _, _, b in cells if rr == r]
        row_center[r] = float(np.median(centers))
    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for r, c, cell, b in cells:
        img = Image.fromarray(cell, "RGBA")
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
        arr = np.array(img)
        arr[:, :, 3] = np.where(arr[:, :, 3] > 110, 255, 0)
        img = Image.fromarray(arr, "RGBA")
        frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        # Alinha pelos pes (base do bbox) e pelo centro mediano da linha.
        ox = round(CELL / 2 - row_center[r] * scale)
        oy = round(FEET_Y - b[3] * scale)
        frame.paste(img, (ox, oy), img)
        name = f"{cls}_idle_{ROWS[r]}.png" if c == 0 else f"{cls}_walk_{ROWS[r]}_{c}.png"
        frame.save(dest / name)
        sheet.paste(frame, (c * CELL, r * CELL), frame)
    OUT.mkdir(parents=True, exist_ok=True)
    preview = Image.new("RGBA", sheet.size, (70, 110, 70, 255))
    preview.alpha_composite(sheet)
    preview.save(OUT / f"preview_{cls}.png")
    print("ok", dest, "escala", round(scale, 3))


def torso_center_x(alpha: np.ndarray) -> float:
    ys, xs = np.nonzero(alpha)
    top, h = ys.min(), ys.max() - ys.min()
    band = alpha[top:top + int(h * 0.6)]
    _, bx = np.nonzero(band)
    return float(bx.mean())


# Folhas feitas no ChatGPT (fontes/<classe>_<nome>.png, grade 4x4, linhas
# frente/esquerda/direita/costas) -> animacao no jogo e como alinhar cada quadro:
# "cabeca" = centro da cabeca, "pes" = centro dos pes, "corpo" = centro do
# corpo inteiro (na morte ele deita e precisa caber no quadro de 192).
FOLHAS = [
    ("parado", "idle", "cabeca"),
    ("andar", "walk", "cabeca"),
    ("ataque", "attack", "pes"),
    ("dano", "hurt", "pes"),
    ("morte", "death", "corpo"),
]


def _corte_minimo(proj: np.ndarray, partes: int = 4) -> list[int]:
    """Linhas de corte da grade onde ha menos tinta (a grade do ChatGPT nao e exata)."""
    n = len(proj)
    suave = np.convolve(proj, np.ones(5) / 5, mode="same")
    cortes = [0]
    for k in range(1, partes):
        alvo = n * k // partes
        ini, fim = alvo - n // 7, alvo + n // 7
        cortes.append(ini + int(np.argmin(suave[ini:fim])))
    cortes.append(n)
    return cortes


def _recortar_folha(path: Path) -> list[list[np.ndarray]]:
    """Separa os 16 quadros. Cada pedaco conectado (corpo, escudo, flecha) vai
    inteiro para o quadro onde fica o seu centro, para nada sair cortado na
    linha da grade; so pedacos que atravessam um quadro inteiro sao divididos."""
    arr = np.array(Image.open(path).convert("RGBA"))
    alpha = arr[:, :, 3] > 40
    h, w = alpha.shape
    linhas = _corte_minimo(alpha.sum(axis=1))
    colunas = [_corte_minimo(alpha[linhas[r]:linhas[r + 1]].sum(axis=0)) for r in range(4)]
    labels, sizes = label_parts(alpha)
    dono = np.zeros_like(labels)  # 1 + r*4 + c de cada pixel; 0 = descartado
    ys_all, xs_all = np.nonzero(labels)
    lab_all = labels[ys_all, xs_all]
    ordem = np.argsort(lab_all, kind="stable")
    ys_all, xs_all, lab_all = ys_all[ordem], xs_all[ordem], lab_all[ordem]
    inicio = np.searchsorted(lab_all, np.arange(len(sizes) + 1))
    for lab in range(1, len(sizes)):
        if sizes[lab] < 30:
            continue
        ys = ys_all[inicio[lab]:inicio[lab + 1]]
        xs = xs_all[inicio[lab]:inicio[lab + 1]]
        grande = (xs.max() - xs.min()) > 1.25 * w / 4 or (ys.max() - ys.min()) > 1.25 * h / 4
        if grande:
            rr = np.clip(np.searchsorted(linhas, ys, side="right") - 1, 0, 3)
            cc = np.array([np.clip(np.searchsorted(colunas[r], x, side="right") - 1, 0, 3) for r, x in zip(rr, xs)])
            dono[ys, xs] = 1 + rr * 4 + cc
        else:
            r = int(np.clip(np.searchsorted(linhas, ys.mean(), side="right") - 1, 0, 3))
            c = int(np.clip(np.searchsorted(colunas[r], xs.mean(), side="right") - 1, 0, 3))
            dono[ys, xs] = 1 + r * 4 + c
    grade = []
    for r in range(4):
        quadros = []
        for c in range(4):
            sel = dono == 1 + r * 4 + c
            ys, xs = np.nonzero(sel)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            cell = arr[y0:y1, x0:x1].copy()
            cell[~sel[y0:y1, x0:x1]] = 0
            keep = largest_parts(cell[:, :, 3], 0.06)
            cell[~keep] = 0
            quadros.append(cell)
        grade.append(quadros)
    return grade


def _ancora(alpha: np.ndarray, modo: str) -> tuple[float, int, int]:
    """(x da ancora, base dos pes, altura) de um quadro."""
    ys, xs = np.nonzero(alpha)
    top, bot = int(ys.min()), int(ys.max())
    altura = bot - top + 1
    if modo == "cabeca":
        band = alpha[top:top + max(4, int(altura * 0.14))]
    elif modo == "corpo":
        return (float(xs.min()) + float(xs.max()) + 1) / 2, bot, altura
    else:
        band = alpha[max(top, bot - max(4, int(altura * 0.08))):bot + 1]
    _, bx = np.nonzero(band)
    return float(bx.mean()), bot, altura


def folhas(cls: str) -> None:
    src = PACKS / cls / "fontes"
    dest = PACKS / cls / "frames_192"
    grades = {nome: _recortar_folha(src / f"{cls}_{nome}.png") for nome, _, _ in FOLHAS}
    # Escala unica da classe: altura mediana do "parado" vira TARGET_H.
    alturas = [_ancora(q[:, :, 3] > 40, "cabeca")[2] for linha in grades["parado"] for q in linha]
    scale = TARGET_H / float(np.median(alturas))
    dest.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    preview = Image.new("RGBA", (CELL * 4 * len(FOLHAS), CELL * 4), (70, 110, 70, 255))
    for f, (nome, anim, modo) in enumerate(FOLHAS):
        for r, direction in enumerate(ROWS):
            for c in range(4):
                cell = grades[nome][r][c]
                ax, bot, _ = _ancora(cell[:, :, 3] > 40, modo)
                img = Image.fromarray(cell, "RGBA")
                img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
                a = np.array(img)
                a[:, :, 3] = np.where(a[:, :, 3] > 110, 255, 0)
                img = Image.fromarray(a, "RGBA")
                frame = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                frame.paste(img, (round(CELL / 2 - ax * scale), round(FEET_Y - (bot + 1) * scale)), img)
                frame.save(dest / f"{cls}_{anim}_{direction}_{c + 1}.png")
                if anim == "idle" and c == 0:
                    frame.save(dest / f"{cls}_idle_{direction}.png")
                preview.alpha_composite(frame, ((f * 4 + c) * CELL, r * CELL))
    preview.save(OUT / f"preview_folhas_{cls}.png")
    print("ok", dest, "escala", round(scale, 3))


if __name__ == "__main__":
    acao, classe = sys.argv[1], sys.argv[2]
    {"gerar": gerar, "processar": processar, "folhas": folhas}[acao](classe)
