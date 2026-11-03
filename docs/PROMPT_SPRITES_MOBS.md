# Prompt para gerar sprites de mobs (Paradise RPG)

Fluxo: gerar **uma imagem por animação** (tira horizontal) → importar com
`tools/mob_sprites/import_mob_strip.py` → abrir o Godot para gerar os `.import`.
O jogo passa a usar o mob novo sozinho quando a pasta existir
(`PACKED_MOB_ASSETS` em `scripts/enemy.gd`).

Animações por mob (mínimo): **idle 6**, **walk 8**, **attack 6**, **death 8** frames.
Morcego/voadores: use `fly` no lugar de `walk`.

---

## 1. Prompt base (copie e troque os campos `{...}`)

Gere as 4 animações **na mesma conversa**, uma de cada vez, sempre colando o
prompt base + o bloco da animação. Na 2ª imagem em diante, anexe o idle já
aprovado como referência e diga "mesmo personagem, mesmo tamanho, mesma paleta".

```
Sprite sheet de pixel art para RPG 2D top-down, estilo 16-bit detalhado
(mesmo estilo do javali e lobo já existentes do jogo: contorno escuro de 1px,
sombreamento suave, paleta natural e levemente dessaturada).

PERSONAGEM: {NOME} — {DESCRICAO_VISUAL}.
Tamanho na tela: {PORTE} (pequeno = cabe em 1 tile, médio = 1,5 tile, grande/chefe = 3 tiles).

REGRAS OBRIGATÓRIAS:
- UMA ÚNICA LINHA horizontal com exatamente {N} frames, lado a lado, todos com o mesmo
  espaçamento e o mesmo tamanho de célula.
- Vista LATERAL, personagem olhando para a ESQUERDA em todos os frames.
- Fundo 100% transparente (ou verde chroma #00FF00 liso, sem gradiente, sem xadrez).
- O MESMO personagem, mesma escala, mesma paleta e mesma posição em todos os frames;
  só a pose muda.
- Pés/base no MESMO nível em todos os frames (linha do chão invisível e fixa).
- Personagem inteiro dentro da célula, nada cortado, nada encostando no frame vizinho.
- SEM números, SEM texto, SEM títulos, SEM rótulos, SEM moldura, SEM grade, SEM chão,
  SEM sombra projetada, SEM efeitos soltos fora do corpo.

ANIMAÇÃO: {BLOCO_DA_ANIMACAO}
```

### Blocos de animação

**IDLE (parado) — N = 6**
```
IDLE em loop: respiração leve, corpo sobe e desce 1–2 pixels, pequeno movimento de
cabeça/cauda/antenas. O frame 6 deve emendar perfeitamente no frame 1. Sem andar.
```

**WALK (caminhada) — N = 8**
```
WALK em loop, ciclo completo de passada no lugar (sem sair do lugar): patas alternando
de forma clara, leve balanço do corpo. O frame 8 emenda no frame 1. Velocidade de
caminhada normal, não corrida.
```

**ATTACK (ataque) — N = 6**
```
ATTACK, golpe corpo a corpo para a ESQUERDA: 1–2 antecipação (recua/prepara),
3–4 golpe (avança, {GOLPE}), 5–6 recuperação voltando à pose parada.
Corpo continua na mesma linha de chão; sem rastro ou efeito separado do corpo.
```

**DEATH (morte) — N = 8**
```
DEATH: 1 recebe o golpe final (recuo), 2–4 perde o equilíbrio e cai de lado,
5–6 bate no chão, 7–8 deitado imóvel (últimos 2 frames quase iguais).
Sem sangue exagerado, sem partes separadas do corpo, sem poça.
```

**FLY (voadores, no lugar de walk) — N = 8**
```
FLY em loop: bater de asas completo (alto → baixo → alto), corpo flutuando 2–3 pixels.
O frame 8 emenda no frame 1.
```

---

## 2. Mobs para refazer (preencher o prompt base)

Ordem sugerida: primeiro o que já aparece na Floresta.

| Mob (nome no jogo) | Pasta (`assets/sprites/mobs/…`) | Porte | `{DESCRICAO_VISUAL}` | `{GOLPE}` |
|---|---|---|---|---|
| Aranha Venenosa (Floresta) | `aranha_venenosa` | médio | aranha gigante de floresta, corpo preto-arroxeado com manchas verde-tóxico no abdômen, 8 patas peludas, presas verdes pingando veneno, olhos vermelhos | dá o bote e morde com as presas |
| Aranha Rainha | `aranha_rainha` | médio-grande | aranha maior e mais escura, carapaça roxa brilhante, coroa de espinhos no cefalotórax, marcas douradas | ergue as patas dianteiras e crava |
| Matriarca Venenosa (chefe) | `aranha_matriarca` | grande | aranha colossal, abdômen inchado verde luminoso, espinhos ósseos, teias presas ao corpo | golpe duplo com as patas dianteiras |
| Espírito Fraco | `espirito_fraco` | pequeno | espírito azul-claro translúcido em forma de chama, rosto simples, cauda de névoa (usar FLY) | avança e toca, brilho mais forte |
| Aprendiz Corrompido | `aprendiz_corrompido` | médio | jovem mago humanoide de manto roxo rasgado, capuz, mãos com energia sombria | lança um pulso de magia curto à frente |
| Espectro Arcano | `espectro_arcano` | médio | fantasma encapuzado azul-violeta com runas brilhantes, sem pernas (usar FLY) | garra espectral |
| Sentinela Arcano | `sentinela_arcano` | médio-grande | constructo de pedra com runas azuis e um núcleo de cristal no peito | soco pesado |
| Arquimago Corrompido (chefe) | `arquimago_corrompido` | grande | arquimago alto de manto preto e dourado, cajado com cristal roxo, aura sombria | golpe com o cajado |
| Bandido das Colinas | `bandido_colinas` | médio | humano com lenço no rosto, couro marrom, faca curta | estocada com a faca |
| Golem de Pedra | `golem_pedra` | grande | golem de rochas cinzentas com musgo, olhos laranja | pancada com os dois punhos |
| Senhor das Colinas (chefe) | `senhor_colinas` | grande | chefe bandido corpulento, armadura de couro e placas, machado grande | machadada de cima para baixo |
| Guardião Cristalino | `guardiao_cristalino` | médio-grande | cavaleiro de cristal azul-ciano translúcido, lança | estocada com a lança |
| Draco Jovem | `draco_jovem` | médio-grande | pequeno dragão vermelho-alaranjado de 4 patas, asas fechadas | mordida avançando o pescoço |
| Titã de Cristal (chefe) | `tita_cristal` | grande | gigante de cristal roxo e azul, punhos enormes | soco descendo no chão |
| Cavaleiro Sombrio | `cavaleiro_sombrio` | médio | cavaleiro de armadura negra com detalhes vermelhos, espada longa | corte horizontal |
| General Infernal (chefe) | `general_infernal` | grande | demônio de armadura vermelha e chifres, espada flamejante | corte em arco |

Mobs da Floresta que já têm frames (idle/walk ok após a limpeza) mas **precisam
de nova morte e ataque**: `javali_selvagem` (Javali Selvagem/Bruto), `javali_rei`
(Rei Javali), `lobo_selvagem` (Lobo Cinzento/Alfa; ataque atual tem só 3 frames).
Para eles, gere só `attack` e `death` anexando um frame do idle atual como referência.
Depois de importar a morte nova, remova o mob de `DEATH_ANIM_BLOCKLIST` em
`scripts/enemy.gd`.

---

## 3. Importar no jogo

Na raiz do repositório (PowerShell). Importe o **idle primeiro**; ele imprime a
escala usada — reutilize em `--scale` nas outras animações do mesmo mob.

```powershell
py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa idle   C:\caminho\aranha_idle.png   --frames 6
py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa walk   C:\caminho\aranha_walk.png   --frames 8 --scale 0.635
py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa attack C:\caminho\aranha_attack.png --frames 6 --scale 0.635
py -I tools/mob_sprites/import_mob_strip.py aranha_venenosa death  C:\caminho\aranha_death.png  --frames 8 --scale 0.635
.\.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe --headless --path . --import
.\TESTAR_JOGO_OFFLINE.bat
```

Opções úteis: `--flip` se a IA desenhou olhando para a direita; `--tolerance 90`
se sobrar borda do fundo; `--body-height 150` para mob maior (só no idle).

Para limpar frames antigos já existentes (números, rótulos, desalinhamento):
`py -I tools/mob_sprites/clean_mob_frames.py <pasta_do_mob>`.

### Checklist de aprovação
- [ ] Nenhum número/texto/pedaço de outro frame.
- [ ] Pés na mesma linha em todos os frames (não "pula" ao trocar de animação).
- [ ] Idle e walk emendam em loop sem salto.
- [ ] Mesmo tamanho entre idle, walk, attack e death.
- [ ] Testado no `TESTAR_JOGO_OFFLINE.bat` andando nas 4 direções e atacando.
