# Pantano v2 (kit, igual Valdoria v2)

Pedido do Mark (2026-11-17): refazer o pantano no formato de kit. O ChatGPT faz o projeto e a arte;
o Claude monta (gerador em Python como tools/valdoria_v2/generate_valdoria_v2.py + data/<mapa>_kit.json).

## Passos
1. ChatGPT: projeto do mapa em JSON (zonas, terrenos, agua, caminhos, objetos com "porte" de colisao
   e "pe_px", inimigos, NPCs, portais, folhas de arte). Pedido pronto: pedido_projeto.txt.
2. ChatGPT: folhas de arte (tiles do chao, objetos separados, fundo #00FF00), uma por pedido.
3. Claude: recorta as folhas (fonte/ com .gdignore), gera chunks 400x320 (escala 2, 6400x5760),
   mascara andavel/agua, minimapa e o kit JSON; colisao pela regra de porte
   (PROJECT_CONTEXT.md -> "Regra de colisao para objetos de mapa").
4. Inimigos novos: sprites pelo fluxo de mobs (tools/mob_sprites/import_mob_strip.py --seams).
5. Liga no jogo (maps.json, portais), teste automatico + tests/conferir_casas e medir_tamanhos.
