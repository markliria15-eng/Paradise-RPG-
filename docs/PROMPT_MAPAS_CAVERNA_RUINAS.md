# Prompts dos mapas Caverna e Ruínas (Paradise RPG)

Progressão: **Eldoria → Floresta → Caverna → Ruínas → Valdoria**.

Padrão técnico (igual à Floresta atual): uma **imagem mestre 5:4** (ex.: 1400x1120
ou 2800x2240), vista **top-down 3/4**, que depois é cortada em chunks e ampliada no
jogo (a Floresta usa 1400x1120 → 5600x4480, chunks 7x7). Gere **duas imagens por
mapa**: (1) o mapa visual limpo e (2) o mapa de colisão em cores chapadas, com o
mesmo enquadramento.

> Não reative os dois mapas de uma vez: monte e teste a Caverna primeiro.

---

## 1. Caverna Profunda (`bat_cave`) — bem sombria

### Prompt do mapa visual

```
Mapa de fundo para RPG 2D top-down em pixel art 16-bit detalhado, vista de cima em
3/4 (mesma perspectiva de um RPG clássico de mapa aberto), proporção 5:4, imagem única
e contínua, sem bordas, sem moldura.

TEMA: Caverna Profunda — uma caverna subterrânea MUITO SOMBRIA e opressiva, terceiro
mapa de um RPG, depois de uma floresta. Clima de medo e perigo constante.

ATMOSFERA E LUZ:
- Paleta muito escura: preto-azulado, cinza-ardósia, roxo profundo, verde doentio.
- A luz vem SÓ de fontes locais: cristais roxos e azul-esverdeados nas paredes,
  fungos bioluminescentes, poças de água escura refletindo brilho fraco, algumas
  tochas velhas quase apagadas perto da entrada.
- Vinheta natural: cantos e fundos de galeria quase pretos; o caminho principal
  levemente mais visível que o resto.
- Névoa baixa e fria em fendas e abismos.

LAYOUT (de cima para baixo, da esquerda para a direita):
1. CANTO SUPERIOR ESQUERDO — Entrada vinda da Floresta: boca da caverna com raízes
   entrando pelo teto, um pouco de luz fria de fora, chão de terra batida, área
   pequena e segura (sem perigo) ao redor de um portal de pedra rúnico apagado.
2. GALERIA DOS MORCEGOS (parte de cima/centro) — salão alto com estalactites, guano,
   ossos pequenos espalhados, rachaduras no chão; corredores largos e livres.
3. TÚNEIS DAS ARANHAS (lado direito e centro) — corredores estreitos e sinuosos
   cobertos de teias grossas nas paredes e nos cantos, casulos pendurados, ovos de
   aranha brilhando verde, restos de aventureiros enrolados em teia (sem sangue
   explícito).
4. LAGO SUBTERRÂNEO (parte de baixo à esquerda) — água negra parada com reflexos de
   cristal, margens de pedra lisa, uma ponte natural de rocha atravessando.
5. ABISMOS — 2 ou 3 fendas profundas e pretas cortando o mapa, com caminhos de pedra
   passando entre elas (não podem bloquear a rota principal).
6. NINHO DA MATRIARCA (canto inferior direito) — câmara circular grande, chão coberto
   de teia, pilares de rocha envoltos em seda, ossos maiores, um brilho verde tóxico
   no centro. Arena aberta e plana para luta de chefe.
7. Saída para as Ruínas: logo depois do ninho, um arco de pedra antigo com runas
   azuis fracas — o primeiro sinal das Ruínas Arcanas.

REGRAS DE JOGABILIDADE (obrigatórias):
- Um caminho principal contínuo e legível ligando entrada → galerias → ninho → saída,
  com largura de pelo menos 3 personagens.
- Chão caminhável claramente diferente das paredes (paredes de rocha com topo mais
  escuro e borda definida).
- Áreas abertas suficientes para combate contra grupos de mobs.
- Nada de objetos grandes no meio dos corredores.

PROIBIDO: personagens, monstros, NPCs, player, interface/HUD, texto, números, setas,
legendas, grade, marca d'água, moldura, bússola, título.
```

### Prompt do mapa de colisão (mesmo enquadramento)

Anexe o mapa visual aprovado e peça:

```
Use EXATAMENTE este mapa como base e gere uma versão de COLISÃO com o mesmo tamanho e
enquadramento, pintada só com cores chapadas, sem textura, sem sombra, sem antialiasing:
- verde #00FF00 = chão caminhável
- vermelho #FF0000 = parede/rocha/pilar bloqueado
- azul #0000FF = água e abismo (bloqueado)
- ciano #00FFFF = portais e área segura ao redor
- amarelo #FFFF00 = área de mobs fracos (morcegos)
- laranja #FF8800 = área de mobs médios (aranhas)
- laranja escuro #CC4400 = área de mobs fortes (aranhas rainhas)
- roxo #8800FF = arena do chefe (ninho da Matriarca)
As zonas de mobs ficam por cima do verde (são caminháveis). Nenhum texto.
```

Mobs previstos: Morcego Pequeno, Morcego Sombrio, Aranha Venenosa, Aranha Rainha e
chefe **Matriarca Venenosa** (bloqueia a saída para as Ruínas).

---

## 2. Ruínas Arcanas (`arcane_ruins`)

### Prompt do mapa visual

```
Mapa de fundo para RPG 2D top-down em pixel art 16-bit detalhado, vista de cima em
3/4, proporção 5:4, imagem única e contínua, sem bordas, sem moldura.

TEMA: Ruínas Arcanas — restos de uma antiga cidade de magos destruída por um feitiço
que saiu do controle, quarto mapa do RPG, logo depois de uma caverna escura. Belo,
melancólico e perigoso: magia ainda viva no meio das pedras.

ATMOSFERA E LUZ:
- Céu de crepúsculo eterno refletido no chão: tons azul-noite, violeta, pedra
  cinza-azulada, musgo verde-escuro, detalhes dourados gastos.
- Luz mágica: runas azul-ciano brilhando em pisos e pilares, cristais flutuando
  sobre pedestais, partículas de luz paradas no ar, rachaduras com brilho violeta.
- Contraste maior que a caverna, mas ainda noturno.

LAYOUT:
1. ENTRADA SUL (parte de baixo, centro) — arco de pedra vindo da Caverna, escadaria
   quebrada subindo, área segura com um pequeno acampamento de exploradores (fogueira
   apagada, tenda rasgada) onde ficará a NPC Maga Selene; chão livre ao redor.
2. AVENIDA DOS PILARES (eixo central, sul → norte) — rua larga de lajes rachadas
   ladeada por colunas tombadas e estátuas de magos sem cabeça; é o caminho principal.
3. BIBLIOTECA EM RUÍNAS (lado esquerdo) — paredes sem teto, estantes quebradas, livros
   e pergaminhos espalhados, círculo mágico desenhado no chão.
4. JARDIM CORROMPIDO (lado direito) — fontes secas, árvores mortas retorcidas, canais
   de água com brilho violeta, vegetação invadindo as pedras.
5. OBSERVATÓRIO (canto superior direito) — torre caída, anel de pedra com astrolábio
   gigante partido, cristais flutuando.
6. SANTUÁRIO DO ARQUIMAGO (topo, centro) — grande praça circular elevada, piso com um
   selo arcano enorme rachado emitindo luz roxa, quatro obeliscos nos cantos. Arena
   aberta e plana para luta de chefe.
7. Saída para Valdoria: portal de pedra no canto superior esquerdo, depois do
   santuário, com runas douradas.

REGRAS DE JOGABILIDADE (obrigatórias):
- Ruas e praças largas e contínuas; a avenida central liga entrada → santuário.
- Paredes, colunas inteiras e muros com base bem definida; escombros pequenos podem
  ficar no chão sem bloquear a passagem.
- Rota livre até o acampamento da Maga Selene e até os dois portais.

PROIBIDO: personagens, monstros, NPCs, player, interface/HUD, texto legível, números,
setas, legendas, grade, marca d'água, moldura, título.
```

### Prompt do mapa de colisão

Use o mesmo prompt de colisão da Caverna, trocando as zonas:

- amarelo = mobs fracos (Espírito Fraco) perto da entrada;
- laranja = mobs médios (Aprendiz Corrompido, Espectro Arcano) na biblioteca e no jardim;
- laranja escuro = mobs fortes (Sentinela Arcano) no observatório e na avenida norte;
- roxo = Santuário do Arquimago (chefe **Arquimago Corrompido**);
- branco #FFFFFF = posição da NPC Maga Selene no acampamento.

---

## 3. Dicas para a geração sair usável

- Se a IA desenhar personagens ou texto, repita: "imagem SEM nenhum personagem e
  SEM texto, só o cenário".
- Se a perspectiva sair lateral (estilo plataforma), reforce: "vista de cima em 3/4,
  câmera alta olhando para baixo, como mapa de RPG top-down".
- Peça variações do mesmo mapa ("mantenha o layout, mude só a iluminação") em vez de
  gerar do zero — assim a colisão continua batendo.
- Antes de implantar: validar spawn, portais, corredores, colisões, minimapa e chunks
  (regras do `CLAUDE.md`). A Caverna já tem pacote antigo em `assets/maps/caverna/`;
  o novo deve substituir só depois de revisado.
