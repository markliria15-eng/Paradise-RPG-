# Portais de chão — Eldoria

Três temas: floresta (verde), caverna (ciano) e ruína (dourado).
São sprites de objetos/camadas completos; não são tiles de terreno repetíveis.

## Montagem

Cada PNG separado mede 512 × 512, com transparência real. Sobrepor os arquivos com a mesma origem. Os pés do personagem ficam em (256,320), medidos do canto superior esquerdo. Para colocar os pés em uma posição de mundo (X,Y), desenhar todas as camadas na origem (X−256,Y−320). Aplicar a mesma escala a todas as camadas e ao deslocamento da âncora.

Ordem de desenho, de baixo para cima:
1. base.png — estrutura imóvel, embaixo do personagem.
2. magia.png — círculo mágico dentro da estrutura.
3. aura_tras.png — energia atrás do personagem.
4. Personagem do próprio jogo; não incluído neste pacote.
5. aura_frente.png — energia à frente do personagem.

O arquivo portal_montado.png é uma referência de composição sem personagem; para permitir que o personagem fique entre as auras, usar as camadas separadas.

## Atlas

atlas_3x4.png mede 1536 × 2048. Células exatas de 512 × 512. Colunas: floresta, caverna, ruína. Linhas: base, magia, aura_tras, aura_frente. Recorte: x=coluna*512, y=linha*512. Os PNGs separados já estão prontos e são a opção mais simples.

## Animação sugerida no motor

Este pacote contém imagens estáticas, não uma spritesheet com quadros animados. Criar o movimento no motor com opacidade, luz e partículas. Manter base.png totalmente imóvel. Na magia, modular alpha entre 0.70 e 1.0 em um ciclo suave de 1.5 segundos. Na ativação, aumentar a opacidade das duas auras de 0 a 1 em 0.35 segundos e emitir partículas da mesma cor subindo ao redor do personagem. Não girar a imagem elíptica em 2D: isso mudaria a perspectiva do chão. Para fluxo interno real, usar shader com máscara ou produzir quadros adicionais.

Ordenar as camadas em relação ao personagem; a aura frontal não deve encobrir a interface. A base visual não define colisão automaticamente. Configurar um gatilho circular/elíptico na área interna, sem bloquear o acesso do personagem.

## Origem e limites

Arte gerada com ImageGen a partir da prévia aprovada dos portais no chão. As camadas foram recortadas e padronizadas para montagem. Conferir a escala final no jogo e ajustar o conjunto inteiro. prancha_original.png preserva a saída original; previa_montagem.png mostra o encaixe das camadas.
