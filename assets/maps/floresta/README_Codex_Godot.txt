# Floresta 5x4 — Arcadia / Paradise RPG

Pacote pronto para implantação no Godot 4.

Arquivos:
- floresta_full_map.png — mapa mestre completo
- floresta_chunk_00_00.png até floresta_chunk_04_03.png — 20 partes recortadas do mapa mestre
- floresta_manifest.json — dados da grade e posições

Dimensão do mapa completo:
- 1400x1120px

Grade:
- 5 colunas x 4 linhas
- cada chunk: 280x280px

Posicionamento no Godot:
- chunk_00_00: posição (0, 0)
- chunk_01_00: posição (280, 0)
- chunk_02_00: posição (560, 0)
- ...
- fórmula: Vector2(grid_x * 280, grid_y * 280)

Configuração recomendada de importação:
- Filter: OFF
- Mipmaps: OFF
- Repeat: OFF
- Texture Filter: Nearest
- Não esticar a imagem.
- Usar escala 1:1 ou escala inteira para manter pixel art nítida.

Observação:
As 20 partes foram recortadas diretamente do mesmo mapa mestre, então encaixam perfeitamente nas bordas.
