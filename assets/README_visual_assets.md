# Paradise RPG - Visual Assets

Esta pasta mantém os PNGs antigos em `assets/sprites/` como aliases de compatibilidade
para não quebrar os caminhos usados pelo Godot.

## Organização nova

- `assets/tiles/`: variações de grama, terra, água, pedra, caverna e ruínas.
- `assets/environment/`: árvores, arbustos, flores, rochas e props leves.
- `assets/buildings/`: casas, forja e portal.
- `assets/mobs/`: reservado para sprites de monstros futuros.
- `assets/characters/`: reservado para sprites de players e NPCs futuros.

## Compatibilidade

O render ainda carrega caminhos como `res://assets/sprites/tile_grass.png`.
Esses arquivos continuam existindo, mas agora o mapa também usa variações como
`tile_grass_01.png` até `tile_grass_04.png` para reduzir repetição visual.
