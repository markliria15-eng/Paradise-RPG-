# HANDOFF_TO_CLAUDE.md

Transferencia tecnica do Paradise RPG para Claude Code.

Data da auditoria: 2026-10-23.

## Referencia Git

- Repositorio: `git@github.com:markliria15-eng/Paradise-RPG-.git`.
- Branch: `main`.
- Commit base: `275ca459f9390c41b5c081738170e0444e3869e8` (`275ca45`).
- Assunto: `Publica Paradise RPG v0.1.16`.
- Primeiro commit da documentacao de transferencia: `6cbac2c` (`docs: add Claude Code technical handoff`).
- Upstream: `origin/main`.
- Divergencia no momento da auditoria: `0` ahead / `0` behind.
- Staging area: vazia.
- Estado do trabalho do aplicativo apos versionar os documentos: 124 arquivos modificados, 9 deletados e 794 nao rastreados.

**Atencao:** o commit base nao representa o jogo atual. Eldoria, Floresta, assets, scripts, dados e correcoes recentes estao no working tree local. Nao resetar, limpar ou trocar de branch sem preservar esse estado.

## Documentos de entrada

- `CLAUDE.md`: regras permanentes e comandos seguros.
- `PROJECT_CONTEXT.md`: memoria tecnica completa, arquitetura, contratos, mapas, riscos e historico.
- `HANDOFF_TO_CLAUDE.md`: snapshot operacional desta data.
- Nao havia `AGENTS.md` no repositorio durante a auditoria.

## Objetivo atual do produto

RPG 2D top-down em Godot 4 com modo offline jogavel e estrutura MMO parcial. O boot passa por launcher online/offline; o gameplay principal continua no cliente Godot, enquanto o backend Node/PostgreSQL cobre autenticacao, sessoes, movimento, chat, save parcial e modulos MMO.

## Estado funcional confirmado no codigo

### Cliente Godot

- Cena inicial: `client/scenes/mmo_launcher.tscn`.
- Cena principal: `scenes/main.tscn`.
- Autoloads: `MMOClient`, `PatchClient`, `ThemeManager`, `AudioManager`.
- Launcher oferece registro, login e abertura offline.
- Gameplay local possui player, inimigos, combate, habilidades, drops, inventario, equipamento, quests, loja, save, HUD, minimapa, chat e companions.
- Save local: `user://arcadia_realms_save.json`.
- Patch client baixa JSONs para `user://patches/data/`, que tem precedencia sobre `res://data/`.

### Mapas

- `city_eldoria`: ativo, seguro, 7200x5760, 9x9 chunks, 81 chunks, rio externo, muros, deck inferior, portal para Floresta, 14 casas separadas e 211 retangulos de colisao do kit.
- `forest_boars`: ativo, 5600x4480, 7x7 chunks, Guarda Doran, seis tipos de mob, coletaveis e portal para Eldoria.
- `world_reset`: alias/base de compatibilidade da Floresta.
- `arcane_ruins`, `bat_cave`, `city_valdoria`, `highland_pass`, `crystal_mines`, `ember_fortress`: IDs preservados com bases vazias; nao reimplantar em lote.
- `pantano`: assets existem, mas nao ha ID ativo em `data/maps.json`.

### Dados ativos

- 3 classes, 23 inimigos, 165 itens, 9 mapas, 2 quests, 88 receitas locais, 4 skills e 21 slots de equipamento.
- MMO: 6 conquistas, 63 receitas, 10 pets, 5 montarias, 1 definicao de profissoes e 1 temporada.
- Quests ativas no JSON: `furia_javalis` e `tutorial_forest`.
- `tutorial_forest` parece inacessivel para novos saves: nao esta em `BEGINNER_QUESTS` e nenhum NPC ativo referencia essa quest.

### Backend e banco

- Node.js 20+, Express, WebSocket e PostgreSQL.
- HTTP: health, download, patches, world status, registro e login.
- WebSocket: auth, movimento, save parcial, chat, PvP, boss, trade, guild, party, profissoes, crafting, pets, mounts, dungeons, ranks, mercado, VIP, conquistas e seasons.
- Schema com 30 tabelas em `database/schema.sql`.
- Persistencia online comprovada no contrato: level, XP, HP, mana, ouro, diamantes, mapa, posicao e quatro skills.
- Inventario, equipamento, quests e exploracao online nao estao comprovados ponta a ponta.

### Distribuicao

- Render: `render.yaml`, web service Node + PostgreSQL.
- GitHub Pages: publica `website/`.
- Android: preset em `export_presets.cfg`; CI de release por tag em `.github/workflows/release-android.yml`.
- `website/game/` e placeholder.

## Alteracoes locais relevantes ainda nao commitadas

- Reconstrucao de Eldoria e Floresta por chunks, minimapas, agua animada, casas, colisoes e geradores.
- Mudancas grandes em `scripts/main.gd` e `scripts/player.gd`.
- Correcao do fluxo offline e tratamento de erros HTTP em `client/scripts/mmo_client.gd` e `client/scripts/mmo_launcher.gd`.
- Dados atuais em `data/maps.json`, `data/quests.json`, `data/items.json` e copias de patch.
- Remocao local das cenas/scripts antigos `city_eldoria`, `arcane_ruins` e `bat_cave`; nenhuma referencia executavel restante foi encontrada.
- Assets novos de NPCs, players, mobs, harvest, mapas, casas e agua.
- Versao Android local alterada para `0.1.21`, ainda sem release/commit correspondente.

Use `git diff --numstat`, `git status --short` e revisao por pasta antes de decidir commits. Nao use `git add .`.

## Validacoes desta auditoria

| Verificacao | Resultado |
| --- | --- |
| Parse de JSONs | Aprovado: 39 arquivos |
| Sintaxe Node `server/src` | Aprovado: 40 arquivos com `node --check` |
| Manifesto de patch | Aprovado: 16 arquivos, tamanho e SHA-256 conferem |
| Referencias a cenas deletadas | Nenhuma referencia executavel encontrada |
| Suite automatizada | Ausente |
| Godot 4.6.3 headless | Aprovado apos scan de classes globais: boot curto do launcher sem erros de script |
| Godot 4.2.2 headless | Inconclusivo: editor iniciou, mas o scan foi abortado durante quit |
| PostgreSQL/backend local | Nao executado nesta auditoria |
| Render/login/WebSocket remoto | Nao reconfirmado nesta auditoria |
| APK Android/dispositivo | Nao executado nesta auditoria |

Historico verificavel anterior: em 2026-09-12, cenas principais carregaram em Godot 4.2.2 e o fluxo offline abriu `scenes/main.tscn`; em 2026-10-05, a validacao registrada confirmou 14 casas, 211 colisoes, 81 chunks, 32 chunks de agua animada e vias/deck livres. Esses resultados sao historicos e devem ser repetidos antes de release.

## Riscos bloqueadores antes de publicar

1. **Segredo Android rastreado:** existe keystore de release versionado e configuracao sensivel no preset. Nao exibir valores. Remover do Git, rotacionar quando aplicavel e migrar a CI para secrets antes de nova publicacao.
2. **Estado nao reproduzivel:** 930 arquivos modificados/deletados/nao rastreados nao estao em `origin/main`. Publicar apenas os documentos nao transfere o projeto atual.
3. **Versao divergente:** HEAD/tag `v0.1.16`, preset local `0.1.21` e default manual antigo no workflow.
4. **Engine divergente:** projeto declara Godot 4.2; CI usa 4.6.3.
5. **Online nao confirmado:** ultimo teste registrado do Render retornou servico suspenso em 2026-09-12; estado atual desconhecido.
6. **Health acoplado ao DB:** Express so escuta depois de conectar ao PostgreSQL.
7. **Autoridade parcial:** servidor nao valida colisoes/portais e PvE continua majoritariamente no cliente.
8. **Boss em mapa vazio:** evento automatico cria boss em `arcane_ruins`, atualmente base vazia.
9. **Quest inacessivel:** `tutorial_forest` nao tem gatilho/NPC ativo.
10. **Sem testes:** features MMO avancadas existem no codigo, mas nao tem cobertura/end-to-end comprovado.

## Decisoes anteriores que nao devem ser revertidas por acidente

- Boot pelo launcher, mantendo `scenes/main.tscn` como gameplay.
- Mapas gerados/carregados em runtime; cenas antigas de mapa foram substituidas localmente.
- Somente Eldoria e Floresta ficam ativas enquanto os demais mapas sao refeitos um por um.
- IDs antigos de mapa permanecem para compatibilidade com saves/backend.
- Casas de Eldoria ficam como sprites separados sobre base limpa, sem piso colado por cima das ruas e sem placas descritivas.
- Colisao das casas usa somente areas vermelhas dos guias; a parte superior permite passagem visual por tras.
- Dados patchados em `user://` prevalecem sobre dados empacotados.
- Save offline continua coexistindo com save online parcial.

## Tentativas/problemas anteriores registrados

- Uma iteracao de Eldoria colou piso ao redor das casas sobre ruas/base. Foi corrigida usando a base limpa e casas separadas; nao repetir essa composicao.
- Os mapas antigos foram esvaziados/deletados para evitar manter conteudo que o usuario quer reconstruir. Nomes, mobs e NPCs planejados foram preservados em `PROJECT_CONTEXT.md`.
- Em 2026-09-12, backend local nao subiu por falta de PostgreSQL e Docker nao estava no PATH; o Render retornava 503.
- Nesta auditoria, a primeira execucao 4.6.3 ocorreu antes do scan das classes globais e mostrou erros em cascata de tipos ausentes. O scan do editor corrigiu o cache e o boot seguinte passou. Em 4.2.2, o scan ainda encerra abortado; nao tratar esse resultado como erro confirmado de GDScript nem como teste aprovado.

## Proximos passos prioritarios

### P0 - Preservar e tornar reproduzivel

1. Fazer backup/snapshot do working tree inteiro antes de qualquer limpeza.
2. Revisar os 124 modificados, 9 deletados e 797 nao rastreados por grupos logicos.
3. Resolver o segredo Android antes de push publico.
4. Criar commits pequenos e tematicos para codigo/dados, mapas/assets, tooling e documentacao.
5. Atualizar este arquivo com os novos SHAs depois dos commits.

### P1 - Validar o estado atual

1. Concluir import do Godot e testar launcher offline.
2. Entrar em Floresta e Eldoria; testar spawn, portal, deck, rios, muros, casas, colisoes, minimapa e save/load.
3. Testar em Godot 4.2.2 e 4.6.3 para decidir a versao suportada.
4. Subir PostgreSQL, rodar migracao e testar health, register/login, WebSocket, movimento e save.
5. Reconfirmar Render apenas depois de revisar configuracao/segredos.

### P2 - Corrigir inconsistencias conhecidas

1. Tornar `tutorial_forest` acessivel ou remove-la temporariamente.
2. Desativar/mover o boss automatico de `arcane_ruins` enquanto o mapa estiver vazio.
3. Decidir versao Android e alinhar preset, workflow, tag e site.
4. Separar health/liveness da disponibilidade imediata do banco.
5. Adicionar validadores/testes minimos para JSON, auth, WebSocket e schema.

### P3 - Continuar conteudo

1. Escolher um unico mapa vazio.
2. Implantar base, colisao, portal, NPCs, mobs e quests somente desse mapa.
3. Validar fluxo completo antes de iniciar o mapa seguinte.

## Publicacao dos documentos

Os tres documentos foram adicionados, commitados e enviados para `origin/main` apos autorizacao explicita. Nenhum arquivo de codigo, dados ou assets do working tree foi incluido nesse commit; nenhuma tag ou release foi criada.

Para revisar e preparar futuras atualizacoes somente da documentacao:

```powershell
git diff --no-index -- NUL PROJECT_CONTEXT.md
git diff --no-index -- NUL CLAUDE.md
git diff --no-index -- NUL HANDOFF_TO_CLAUDE.md
git add -- PROJECT_CONTEXT.md CLAUDE.md HANDOFF_TO_CLAUDE.md
git diff --cached --check
git diff --cached --stat
```

Commit sugerido para futuras atualizacoes, somente apos nova autorizacao:

```powershell
git commit -m "docs: add Claude Code technical handoff"
```

Push sugerido para futuras atualizacoes, somente apos nova autorizacao e depois de decidir como transferir o working tree real:

```powershell
git push origin main
```

Recomendacao: nao publicar os documentos isoladamente como se fossem um snapshot reproduzivel. Primeiro preservar/versionar as mudancas intencionais do jogo ou declarar claramente que Claude Code continuara na mesma maquina e no mesmo working tree.
