"""NPCs novos (folhas 512x128, 4 quadros de respiracao) alinhados a linha dos pes dos NPCs premium.

Fonte: tools/npc_sprites/fonte/npc_<nome>_idle.png (pacote npcs_sete_personagens.zip).
Saida: assets/characters/npcs/<destino>_idle_4f_128.png (o sufixo liga a animacao de respiracao
em Npc.setup). Cada folha e deslocada na vertical para os pes ficarem na linha 119, igual a
Sarah, Borin, Bakka e Arion.

uso: python tools/npc_sprites/fit_npc_sprites.py   (raiz do projeto; Pillow, numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).resolve().parent / "fonte"
OUT = ROOT / "assets/characters/npcs"
FEET_Y = 119
MAPA = {
    "npc_mineiro_perdido_idle": "npc_mineiro_perdido",
    "npc_maga_selene_idle": "npc_maga_selene",
    "npc_mira_idle": "npc_mira_pets",
    "npc_torin_idle": "npc_torin_montarias",
    "npc_durnan_idle": "npc_durnan_forja_rara",
    "npc_liora_idle": "npc_liora_curandeira",
    "npc_varek_idle": "npc_varek_mercador",
}


def main():
    for src, dst in MAPA.items():
        im = Image.open(SRC / f"{src}.png").convert("RGBA")
        assert im.size == (512, 128), (src, im.size)
        alpha = np.asarray(im)[..., 3] > 20
        feet = int(np.nonzero(alpha.any(1))[0].max())
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.alpha_composite(im, (0, FEET_Y - feet))
        out.save(OUT / f"{dst}_idle_4f_128.png", optimize=True)
        print(dst, "pes", feet, "->", FEET_Y)


if __name__ == "__main__":
    main()
