# Prompts de tiles e objetos — Caverna e Ruínas (mesmo método da Floresta v2 / Eldoria v2)

Este documento substitui o método de "mapa pintado inteiro" de
`docs/PROMPT_MAPAS_CAVERNA_RUINAS.md`. Agora o fluxo é igual ao da Floresta e de Eldoria:

1. **ChatGPT gera as pranchas** (1024x1024, fundo transparente) com os prompts abaixo.
2. Você salva as pranchas nas pastas indicadas, **com os nomes exatos**.
3. **Eu monto o mapa**: recorto as pranchas, pinto o chão com os pisos, posiciono
   paredes e objetos como sprites separados, faço a colisão no pé de cada objeto, a
   máscara de área andável, o minimapa e os chunks. Os objetos grandes ficam com
   **y-sort**: o player passa **por trás** da copa/topo e colide só com a base.
4. A escuridão da caverna e o brilho dos cristais eu faço no Godot (luz e sombra).
   Por isso os tiles devem vir **escuros, mas com detalhe visível**, não pretos.

Pastas (crie se não existirem):
- Caverna: `assets/maps/caverna_v2/sheets/`
- Ruínas: `assets/maps/ruinas_v2/sheets/`

Já existem e serão reaproveitadas: `assets/maps/eldoria_v2/sheets/portal_caverna.png`,
`portal_ruina.png` e `eldoria_tochas.png` (portais e tochas animadas).

### Como pedir no ChatGPT

- Gere **uma prancha por mensagem**, sempre colando o **PROMPT BASE + o bloco da prancha**.
- Anexe como **referência de estilo** `assets/maps/eldoria_v2/sheets/eldoria_pisos.png`
  e `eldoria_objetos.png` (assim o tamanho e o pixel art batem com Eldoria e a Floresta).
- Na 2ª prancha em diante do mesmo mapa, anexe também a 1ª prancha aprovada e
  escreva: *"same palette, same scale, same lighting as the attached sheet"*.
- Se vier com fundo xadrez/branco, peça: *"regenerate with a truly transparent
  background (alpha channel), no checkerboard"*.

---

## CAVERNA PROFUNDA (`bat_cave`) — bem sombria

### Prompt base da Caverna (cole sempre antes do bloco)

```
Create a production sprite sheet for the "Deep Cave" map of a 2D top-down RPG called
Paradise RPG. Output exactly 1024x1024 pixels PNG with a truly transparent background
(alpha channel). Clean detailed 16-bit pixel art with crisp pixel clusters, dark 1px
outlines, same scale and pixel density as the attached reference sheets.

Mood: a VERY dark, oppressive and dangerous underground cave. Palette: blue-black,
slate grey, deep purple, sickly toxic green, cold teal. Light comes only from local
sources: purple and teal crystals, bioluminescent fungi, faint old torches. Keep
textures DARK but with readable detail (lighting will be added later in the engine),
never pure black.

Camera: classic orthogonal top-down 3/4 RPG camera. World X runs horizontally and Y
vertically. NO isometric diamond shapes, NO diagonal orientations, NO rotated ground.
Ground squares viewed straight overhead. Tall objects show their top and a little of
their front face, with their base/foot at the bottom of the sprite.

No text, no numbers, no labels, no grid lines, no frame, no characters, no monsters,
no loose cast shadows, no surrounding ground under objects. Every object fully inside
its cell with transparent gutter around it.
```

### 1) `caverna_pisos.png` — pisos (chão)

```
A 4x4 atlas of 16 EXACT square 256x256 ground textures, edge-to-edge cells with no
gutters. All pixels of every cell filled with its ground texture. Completely FLAT
overhead view, no sides, no walls, no raised edges, no relief. Each texture must
repeat seamlessly in both directions, opposite edges matching.
Row 1 left to right: dark slate cave floor; cracked dark stone floor; packed dark
earth with small gravel; damp rock floor with tiny puddle glints.
Row 2: cave floor with scattered small bones and pebbles; floor covered in thin
spider web strands; dark floor with faint glowing teal moss patches; floor with fine
purple crystal dust.
Row 3: thick white-grey spider silk carpet (nest floor); ancient dark stone slabs with
faint blue rune cracks (transition to ruins); rough black rock (abyss rim texture,
very dark); old wooden mine planks running horizontally.
Row 4: FOUR ANIMATION FRAMES OF THE SAME deep black-teal underground water texture.
Exact same hue and structure, only faint crystal reflection glints shift slightly per
frame, seamless across all four edges and looping. No shore, no rocks.
The full sheet is square, no margin, square texture cells, no diamonds.
```

### 2) `caverna_paredes.png` — paredes modulares (colisão)

```
Orthogonal cave rock wall modular atlas. Arrange 12 separated objects in a 4-column x
3-row layout, each inside its invisible 256x341 cell with ample transparent gutter.
Row 1: horizontal straight cave rock wall front-facing (jagged dark rock face with a
darker top); horizontal wall variation with purple crystals growing from it; vertical
rock wall running straight up-down viewed from above; second vertical wall variation
with hanging roots.
Row 2: four L corners upper-left, upper-right, lower-left, lower-right, arms STRICTLY
horizontal and vertical in screen space.
Row 3: massive round rock pillar (stalagmite column); cave entrance arch of rock with
a dark OPEN transparent passage and roots hanging from the top; straight horizontal
natural rock bridge running left-right; straight vertical natural rock bridge running
up-down. No water or void under bridges.
All wall segments same thickness, same scale and same connection widths. ABSOLUTELY NO
diagonal walls. The vertical wall is not a rotated horizontal wall: depict its top
surface properly for a wall running north-south.
```

### 3) `caverna_objetos.png` — objetos grandes e médios (passar por trás)

```
20 individual cave prop sprites, arranged in a spacious invisible 5-column x 4-row
layout. Each object complete with its base at the bottom, no ground patch under it,
no loose shadow.
Row 1: tall stalagmite; cluster of three small stalagmites; large purple crystal
cluster (glowing); large teal crystal cluster (glowing); small crystal shard group.
Row 2: tall bioluminescent mushroom (teal cap); cluster of small glowing mushrooms;
pile of old bones with a skull; large animal ribcage skeleton; broken wooden mine cart.
Row 3: wooden mine support beam frame (two posts and a top beam, front-facing);
old iron torch stand (unlit); rotten wooden barrels pair; large dark boulder; small
boulders group.
Row 4: big spider web stretched between two rocks; hanging silk cocoon on a rock;
cluster of green glowing spider eggs; adventurer skeleton wrapped in web lying on a
rock (no blood); hanging root curtain from a rock ledge.
Consistent orthogonal top-down 3/4 camera, no diagonals, same scale (a human-sized
character would be about as tall as the tall mushroom).
```

### 4) `caverna_ninho.png` — arena do chefe (Matriarca Venenosa)

```
12 individual boss-lair prop sprites in a spacious invisible 4-column x 3-row layout,
all for the giant spider queen nest at the deepest part of the cave.
Row 1: huge rock pillar fully wrapped in thick spider silk; large web canopy hanging
between two pillars (front-facing); giant egg sac mound glowing toxic green; pile of
large bones and broken armor (no blood).
Row 2: silk-wrapped cocoons hanging cluster; broken shield and sword stuck in web;
toxic green glowing puddle (flat, top-down); cracked boulder covered in webs.
Row 3: ancient stone arch with faint blue runes and an OPEN transparent passage (exit
to the ruins, front-facing); two short broken rune pillars; small web patches (flat,
for floor decoration); empty cell.
Same dark palette, same scale and camera as the attached cave sheet.
```

### 5) `caverna_cristal_animado.png` — brilho animado (opcional)

```
An EXACT 2x2 animation sprite sheet: four invisible 512x512 cells, each contains the
SAME large purple-and-teal glowing crystal cluster growing from dark rock, orthogonal
top-down 3/4 camera. All four sprites pixel-identical in shape, size, position,
palette and alignment, centered with the same margins. ONLY the inner glow and small
sparkles change across four looping phases, order top-left, top-right, bottom-left,
bottom-right. No ground around the base, no shadow, truly transparent background.
```

**Layout que vou montar:** entrada no canto superior esquerdo (vinda da Floresta) →
galeria dos morcegos → túneis das aranhas (teias) → lago subterrâneo com ponte →
abismos com passagens → ninho da Matriarca (canto inferior direito) → arco para as
Ruínas. Mobs: Morcego Pequeno, Morcego Sombrio, Aranha Venenosa, Aranha Rainha e
chefe Matriarca Venenosa.

---

## RUÍNAS ARCANAS (`arcane_ruins`)

### Prompt base das Ruínas

```
Create a production sprite sheet for the "Arcane Ruins" map of a 2D top-down RPG called
Paradise RPG. Output exactly 1024x1024 pixels PNG with a truly transparent background
(alpha channel). Clean detailed 16-bit pixel art with crisp pixel clusters, dark 1px
outlines, same scale and pixel density as the attached reference sheets.

Mood: the ruins of an ancient city of mages destroyed by a spell gone wrong. Beautiful,
melancholic and dangerous, under an eternal twilight. Palette: night blue, violet,
blue-grey weathered stone, dark moss green, worn gold details. Magic still alive:
cyan glowing runes, floating crystals, violet glowing cracks.

Camera: classic orthogonal top-down 3/4 RPG camera. World X runs horizontally and Y
vertically. NO isometric diamond shapes, NO diagonal orientations, NO rotated ground.
Ground squares viewed straight overhead. Tall objects show their top and a little of
their front face, with their base/foot at the bottom of the sprite.

No text, no readable letters, no numbers, no labels, no grid lines, no frame, no
characters, no monsters, no loose cast shadows, no surrounding ground under objects.
Every object fully inside its cell with transparent gutter around it.
```

### 1) `ruinas_pisos.png`

```
A 4x4 atlas of 16 EXACT square 256x256 ground textures, edge-to-edge cells with no
gutters. All pixels filled. Completely FLAT overhead view, no sides, no relief. Each
texture repeats seamlessly in both directions, opposite edges matching.
Row 1 left to right: large blue-grey stone slabs; cracked stone slabs with moss in
the joints; broken paving with dirt showing through; dark twilight grass.
Row 2: stone slabs with faint glowing cyan rune lines; ornate mosaic floor (violet and
gold geometric pattern, no letters); scattered rubble and pebbles on dirt; dry cracked
earth with violet glowing cracks.
Row 3: overgrown grass with small blue night flowers; dead dry grass; dark wet stone
(fountain floor); old wooden floor planks (library floor).
Row 4: FOUR ANIMATION FRAMES OF THE SAME shallow violet-glowing magical water texture,
same hue and structure, only light glints shift slightly per frame, seamless and
looping. No shore, no rocks.
The full sheet is square, no margin, square texture cells, no diamonds.
```

### 2) `ruinas_muros.png` — muros quebrados modulares

```
Orthogonal ruined stone wall modular atlas. Arrange 12 separated objects in a 4-column
x 3-row layout, each inside its invisible 256x341 cell with ample transparent gutter.
Row 1: horizontal straight ruined wall front-facing (blue-grey stone, broken uneven
top, moss); horizontal ruined wall with a glowing cyan rune carving; vertical ruined
wall running straight up-down viewed from above; second vertical wall variation with
ivy.
Row 2: four L corners upper-left, upper-right, lower-left, lower-right, arms STRICTLY
horizontal and vertical in screen space.
Row 3: low collapsed wall rubble segment (horizontal); grand broken archway with an
OPEN transparent passage; wide stone staircase going up (front-facing, broken edges);
straight horizontal stone bridge running left-right.
All wall segments same thickness, scale and connection widths. ABSOLUTELY NO diagonal
walls. The vertical wall shows its top surface properly for a north-south wall.
```

### 3) `ruinas_objetos.png` — objetos grandes (passar por trás)

```
20 individual ruins prop sprites in a spacious invisible 5-column x 4-row layout. Each
object complete with its base at the bottom, no ground patch under it, no shadow.
Row 1: tall intact stone column with gold capital; broken column (half height); fallen
column lying horizontally; headless mage statue in robes on a pedestal; large stone
obelisk with glowing cyan runes.
Row 2: broken bookshelf with old books (no readable text); pile of scattered books and
scrolls; reading lectern with an open book (no text); dry stone fountain (round,
cracked basin); twisted dead tree.
Row 3: dead tree variation (smaller); stone pedestal with a floating violet crystal;
large broken astrolabe ring on a stone base; small rubble pile; big cracked boulder
with moss.
Row 4: abandoned explorer tent (torn canvas, front-facing); burnt-out campfire with
stones; wooden supply crates pair; glowing blue night-flower bush; stone brazier with
violet magic flame.
Consistent orthogonal top-down 3/4 camera, no diagonals, same scale (a human-sized
character would be about as tall as the broken column).
```

### 4) `ruinas_santuario.png` — arena do chefe (Arquimago Corrompido)

```
12 individual sanctuary prop sprites in a spacious invisible 4-column x 3-row layout,
for the archmage boss arena at the top of the ruins.
Row 1: tall dark obelisk with violet glowing runes; tall dark obelisk variation; large
ornate broken throne of stone and gold (front-facing); tall stone brazier with a big
violet flame.
Row 2: floating cluster of three violet crystals over a small rune stone; ruined
archway with golden runes and an OPEN transparent passage (portal frame to the next
city, front-facing); broken mage statue kneeling; scattered gold-trimmed debris.
Row 3: circular raised platform edge piece, horizontal (flat top, short front wall);
same platform edge piece, vertical; small rune floor tile glowing (flat, top-down);
empty cell.
Same palette, scale and camera as the attached ruins sheet.
```

### 5) `ruinas_selo_animado.png` — selo arcano do chão (animado)

```
An EXACT 2x2 animation sprite sheet: four invisible 512x512 cells, each contains the
SAME large circular arcane seal drawn on the floor, viewed completely flat from
straight overhead (a perfect circle, not an ellipse). Cracked through the middle,
violet and cyan glowing lines, geometric symbols only, NO letters. All four frames
pixel-identical in shape, size and position; ONLY the glow intensity and small
sparkles change across four looping phases, order top-left, top-right, bottom-left,
bottom-right. Truly transparent background outside the circle.
```

**Layout que vou montar:** entrada sul vinda da Caverna, com o acampamento da Maga
Selene (área segura) → avenida central de colunas → biblioteca (esquerda) e jardim
corrompido (direita) → observatório (canto superior direito) → santuário do Arquimago
no topo → portal para Valdoria no canto superior esquerdo. Mobs: Espírito Fraco,
Aprendiz Corrompido, Espectro Arcano, Sentinela Arcano e chefe Arquimago Corrompido.

---

## Checklist antes de me mandar as pranchas

- [ ] 1024x1024, fundo **transparente de verdade** (sem xadrez).
- [ ] Pisos: 4x4 células cheias, sem bordas, e emendam quando repetidos.
- [ ] Objetos separados, sem chão embaixo e sem sombra solta; base visível embaixo.
- [ ] Nenhum texto, número, personagem ou monstro.
- [ ] Nada em diagonal ou isométrico.
- [ ] Mesma escala entre as pranchas do mesmo mapa.

Ordem sugerida: **Caverna primeiro** (pisos → paredes → objetos → ninho → cristal).
Quando as pranchas da Caverna estiverem na pasta, me avise que eu monto o mapa.
