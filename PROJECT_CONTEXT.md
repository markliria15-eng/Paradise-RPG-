# PROJECT_CONTEXT.md

Memoria tecnica do projeto Paradise RPG.

Criado em: 2026-09-12. Auditoria de transferencia atualizada em: 2026-10-23.

Regra principal: o codigo existente e a fonte principal da verdade. Este arquivo serve como mapa de continuidade e deve ser atualizado apenas nas partes relevantes quando mudancas importantes forem concluidas.

Convencao de evidencia usada nesta memoria:

- **Confirmado no codigo**: existe implementacao, configuracao ou dado diretamente inspecionado no working tree.
- **Confirmado no Git**: consta em branch, commit, tag, diff ou status local.
- **Somente documentado**: aparece em README, docs ou historico conversacional, mas nao foi validado ponta a ponta.
- **Nao confirmado**: depende de servico externo, dispositivo, banco ou teste manual que nao estava disponivel nesta auditoria.

## Snapshot verificavel da transferencia (2026-10-23)

- Repositorio: `git@github.com:markliria15-eng/Paradise-RPG-.git`.
- Branch: `main`; HEAD: `275ca459f9390c41b5c081738170e0444e3869e8` (`275ca45`, `Publica Paradise RPG v0.1.16`).
- Upstream: `origin/main`, sem divergencia no commit de referencia (`0` ahead / `0` behind).
- Antes de criar os arquivos desta transferencia havia `0` arquivos staged, `124` modificados, `9` deletados e `795` nao rastreados. Esse working tree, e nao apenas o HEAD, representa o estado atual do projeto.
- `PROJECT_CONTEXT.md` ja existia localmente, mas ainda nao era rastreado pelo Git. `CLAUDE.md` e `HANDOFF_TO_CLAUDE.md` foram criados nesta transferencia.
- Nenhum `AGENTS.md` foi encontrado no repositorio; a pasta `.agents/` esta vazia. Se um `AGENTS.md` for adicionado depois, suas regras passam a ter precedencia no escopo correspondente.
- Ha 9 IDs de mapa em `data/maps.json`, mas somente Eldoria e Floresta possuem conteudo ativo. Os demais IDs sao bases vazias de compatibilidade/reconstrucao.
- Conteudo JSON atual: 3 classes, 23 inimigos, 165 itens, 9 mapas, 2 quests, 88 receitas locais, 4 skills, 21 slots de equipamento, 6 conquistas MMO, 63 receitas MMO, 10 pets, 5 montarias, 1 definicao de profissoes e 1 temporada.
- Nao existe suite automatizada de testes (`test`, `tests`, `spec` ou equivalente) nem script `npm test`.

## Objetivo do projeto

Paradise RPG e um RPG 2D top-down em Godot 4, inspirado em Tibia/Arcadia, com MVP singleplayer jogavel e estrutura em evolucao para MMO online. O jogo combina escolha de classe, combate em tempo real, mapas de caca, drops, inventario, equipamentos, loja, progresso de atributos/skills, save local e sincronizacao online parcial.

O projeto tambem inclui backend Node.js para contas/MMO, banco PostgreSQL, sistema de patches de dados, site publico de download, workflows de publicacao e builds Android locais.

## Regras de continuidade

- Nao recriar sistemas existentes sem primeiro verificar o codigo e suas referencias.
- Nao substituir arquivos inteiros quando uma mudanca localizada for suficiente.
- Nao alterar nomes, caminhos, APIs, cenas, componentes, schemas ou dados persistentes sem mapear consumidores.
- Antes de remover codigo ou arquivos aparentemente legados, pesquisar referencias no projeto inteiro.
- Antes de mexer em banco, modelos, schemas, APIs ou save, verificar compatibilidade com dados existentes.
- Preferir mudancas incrementais, reversiveis e alinhadas ao estilo atual.
- Diferenciar funcionalidade pronta, parcial, legado, possivelmente nao usado, TODO e bug conhecido.

## Arquitetura geral

- Engine principal: o projeto declara recurso Godot 4.2 em `project.godot`; existem binarios locais 4.2.2 e 4.6.3 em `.tools/`, enquanto o workflow Android usa 4.6.3. Tratar a diferenca de versao como risco de compatibilidade.
- Cena inicial atual: `res://client/scenes/mmo_launcher.tscn`, nao `scenes/main.tscn` diretamente.
- Autoloads Godot: `MMOClient`, `PatchClient`, `ThemeManager`, `AudioManager`.
- Jogo principal: `scenes/main.tscn` carrega `scripts/main.gd` e sistemas de dados/save.
- Backend: Node.js 20+, Express, WebSocket, PostgreSQL, JWT e bcrypt.
- Deploy/site: `website/` via GitHub Pages; backend separado via Render usando `render.yaml`.
- Dados de gameplay: JSON em `data/`; patches publicados em `server/public/patches/data/`.

## Estrutura de pastas

- `assets/`: sprites, mapas, tiles, UI, sets de armadura, mobs, pets, NPCs e imagens de site.
- `client/`: launcher MMO, configuracao online e cliente WebSocket/HTTP em GDScript.
- `data/`: bancos JSON de classes, itens, monstros, mapas, quests, skills, receitas e sistemas MMO.
- `database/`: schema PostgreSQL e docker-compose.
- `docs/`: documentacao de online, hospedagem, patches, publicacao e checklist.
- `scenes/`: cenas Godot do jogo, efeitos, UI e componentes.
- `scripts/`: logica Godot do jogo, player, enemy, inventario, equipamentos, quest, save, UI e tema.
- `server/`: backend MMO Node.js, rotas HTTP, gateway WebSocket, managers, repositorios e patches.
- `website/`: site publico oficial de download e placeholder web.
- `site/`: site antigo/local de download.
- `build/` e `releases/`: APKs, logs, screenshots e builds locais.
- `tools/`: scripts auxiliares de Android, publicacao, assets e ADB.

## Sistemas implementados ou presentes

- Launcher online/offline: `client/scenes/mmo_launcher.tscn` e `client/scripts/mmo_launcher.gd`.
- Cliente MMO Godot: login, registro, conexao WebSocket, envio de movimento, save, chat, PvP, profissoes, crafting, pets, montarias, dungeons, rank, mercado, VIP, conquistas e temporada em `client/scripts/mmo_client.gd`.
- Sistema de patch de dados: baixa manifesto e JSONs para `user://patches/data/` em `client/scripts/patch_client.gd`; `ItemDatabase.resolve_data_path()` prioriza dados patchados.
- Main loop do jogo: `scripts/main.gd` orquestra UI, mapa, player, inimigos, drops, quests, save, online, minimap, chat, pets/montarias e paineis MMO.
- Player: `scripts/player.gd` implementa stats, classe, ataque, habilidades, dano, XP, equipamentos, inventario, save e sprites direcionais.
- Enemy: `scripts/enemy.gd` implementa perseguicao, ataque, vida, boss flag, dano, veneno, stun, burn, animacoes e sombras.
- Combate: `scripts/combat_system.gd` fornece calculo de dano/critico; `main.gd` aplica alvos, area, efeitos e drops.
- Inventario/equipamentos: `scripts/inventory_system.gd` e `scripts/equipment_system.gd` gerenciam pilhas, slots, aliases e bonus.
- Skills/progressao: `scripts/skill_progression_system.gd` define fighting/distance/magic/protection; `player.gd` tambem mantem progresso legado de ataque/defesa/speed attack.
- Quest local: `scripts/quest_system.gd` existe e funciona sobre `data/quests.json`.
- Save local: `scripts/save_system.gd` salva player, quests, mapa, posicao, exploracao e cache MMO em `user://arcadia_realms_save.json`.
- UI in-game: HUD, inventario, equipamento, loja, quests, skills, login, loading, class selection, side menu e componentes em `scenes/ui/` e `scripts/ui/`.
- Sistemas MMO no backend: auth, world, anti-cheat, mapas, players, entidades, chat, PvP, bosses, trade, guild, party, save, profissoes, crafting, pets, mounts, dungeons, ranks, mercado, VIP, conquistas, seasons e eventos.
- Site/download: `website/index.html` e workflow GitHub Pages; builds Android existem em `build/android/` e `releases/`.

## Sistemas parciais ou em transicao

- Mapas: `data/maps.json` foi reconciliado para conter novamente os mapas conhecidos pelo codigo (`city_eldoria`, `forest_boars`, `arcane_ruins`, `bat_cave`, `city_valdoria`, `highland_pass`, `crystal_mines`, `ember_fortress`) e preservar o alias/compatibilidade `world_reset`.
- Quests: `scripts/quest_system.gd` esta ativo, mas `data/quests.json` contem atualmente somente `furia_javalis` e `tutorial_forest`. As outras quatro quests conhecidas foram removidas do JSON ativo junto com os mapas correspondentes.
- Cenas de mapas antigas: `scenes/city_eldoria.tscn`, `scenes/arcane_ruins.tscn`, `scenes/bat_cave.tscn` e scripts equivalentes aparecem deletados no working tree. O desenho de mapas parece ter migrado para runtime em `scripts/main.gd`.
- MMO: servidor tem muitas features e tabelas, mas o client salva online principalmente level, XP, HP, mana, ouro, diamantes, mapa, posicao e skills. Inventario, equipamentos e quests online ainda parecem planejados/parciais.
- Patch remoto: `server/public/patches/manifest.json` foi regenerado a partir dos JSONs atuais de `data/` e validado contra os arquivos copiados em `server/public/patches/data/`.
- Online remoto: a configuracao atual aponta para Render (`paradise-rpg-server.onrender.com`). Em 2026-09-12, os endpoints `/health`, `/patch/manifest`, `/world/status` e `/ws` retornaram 503 com mensagem de servico suspenso pelo dono. Esse estado externo nao foi reconfirmado em 2026-10-23.
- Website game web: `website/game/` e descrito como placeholder; o app web completo depende de export Godot futuro.

## Banco de dados e backend

Banco: PostgreSQL em `database/schema.sql`.

Tabelas principais:

- `accounts`: usuario, email, hash de senha, login, ban, vip/premium.
- `characters`: personagem, classe, level, XP, HP, mana, ouro, diamantes, mapa e posicao.
- `inventory`, `equipment`, `skills`, `quests`: base para persistencia de progressao e estado do personagem.
- `guilds`, `guild_members`, `friends`, `mail`, `market`, `market_listings`, `trade_logs`, `parties`, `party_members`, `online_sessions`.
- Sistemas avancados: `professions`, `crafting_recipes`, `pets`, `character_pets`, `mounts`, `character_mounts`, `dungeons`, `dungeon_runs`, `rank_cache`, `achievements`, `character_achievements`, `seasons`, `season_progress`, `premium_purchases`.

Backend:

- `server/src/index.js`: sobe Express, health, downloads, patch manifest/files, auth routes, WorldService e WebSocket.
- `server/src/services/authService.js`: validacao Zod, registro/login, bcrypt, JWT.
- `server/src/services/worldService.js`: agrega managers e processa tick, movimento, snapshots, chat, saves e sistemas MMO.
- `server/src/net/wsGateway.js`: roteia tipos de mensagem WebSocket para WorldService/managers.
- `server/src/repositories/*`: acesso ao PostgreSQL para contas, personagens, guild, trade e sistemas MMO.

## Contratos e fluxos principais

### Boot do cliente

1. `project.godot` inicia `client/scenes/mmo_launcher.tscn`.
2. `client/scripts/mmo_launcher.gd` oferece registro, login e abertura offline.
3. Registro/login chamam `POST /auth/register` ou `POST /auth/login` por `MMOClient`.
4. No online, o launcher abre WebSocket, autentica o personagem e troca para `scenes/main.tscn` apos `world_entered`.
5. No offline, `MMOClient.prepare_offline_start()` grava a intencao temporaria e o launcher troca diretamente para a cena principal pre-carregada.
6. `scripts/main.gd` consome o estado do launcher, carrega JSONs, instancia jogador/mundo/UI e escolhe entre save local e estado online.

### HTTP

- `GET /health`: retorna identificacao e `ok`; o servidor HTTP so comeca a escutar depois que o PostgreSQL responde, portanto o health check tambem fica indisponivel quando o banco nao sobe.
- `GET /download/android` e `GET /download/status`: redirecionamento/metadados do APK configurado.
- `GET /patch/manifest` e `/patch/files/*`: manifesto e arquivos JSON de patch.
- `GET /world/status`: jogadores online por mapa, tick e intervalo de save.
- `POST /auth/register`: recebe `username`, `email`, `password`, `characterName`, `className`; classes aceitas: `Guerreiro`, `Mago`, `Arqueiro`.
- `POST /auth/login`: recebe `login` e `password`; login aceita username ou e-mail. Respostas bem-sucedidas incluem conta, token/JTI e personagem(es).

### WebSocket

- Primeira mensagem online: `auth` com JWT e `characterId`.
- Entradas implementadas: `move`, `character_save`, `chat`, `pvp_attack`, `boss_attack`, `trade_request`, `trade_accept`, `trade_offer`, `trade_confirm`, `guild_create`, `guild_invite`, `guild_accept_invite`, `party_invite`, `party_accept`, `professions_get`, `crafting_list`, `crafting_craft`, `pets_get`, `pets_equip`, `mounts_get`, `mounts_equip`, `dungeons_get`, `dungeon_start`, `rank_get`, `market_get`, `market_list_item`, `market_buy`, `vip_get`, `achievements_get`, `season_get`.
- Saidas principais: `auth_ok`, `world_entered`, `world_snapshot`, `player_joined`, `player_left`, `character_saved`, `chat_message`, `chat_error`, `anti_cheat_violation`, `entity_hp_sync`, respostas `pvp_*`, `trade_*`, `guild_*`, `party_*`, `professions_state`, `crafting_*`, `pets_state`, `mounts_state`, `dungeons_state`, `dungeon_started`, `rank_state`, `market_*`, `vip_state`, `achievements_state`, `season_state`, `system_event`, `boss_defeated` e `error`.
- O servidor limita posicoes aos limites retangulares do mapa e aplica verificacao basica de velocidade. Colisoes, paredes, rios e legitimidade de portal nao sao validados no servidor.

### Persistencia

- Save local: `user://arcadia_realms_save.json`, com `player`, `quests`, `current_map`, `position`, `exploration` e `mmo_cache`.
- Estado local do player inclui classe, level/XP, moedas, HP/mana, atributos, progresso de ataque/defesa/velocidade, skills, inventario e equipamento embutido em `inventory.to_save()`.
- Save online aceito atualmente: level, XP, HP, mana, ouro, diamantes, mapa, posicao e skills `fighting`, `distance`, `magic`, `protection`.
- Inventario, equipamento, quests e exploracao nao entram em `character_save`; apesar das tabelas existentes, persistencia online ponta a ponta desses sistemas nao esta comprovada.

### Dados dirigidos por JSON

- `data/maps.json`: cada mapa usa `name`, `safe`, `size`, `color`, `spawn`, `npcs`, `portals` e, quando aplicavel, `safe_zones`, `spawns`, `collectibles`.
- `data/quests.json`: dicionario por ID com `title`, `npc`, `map`, `objectives[]` (`type`, `target`, `amount`) e `rewards`.
- `data/items.json`, `data/enemies.json`, `data/classes.json`, `data/skills.json` e `data/recipes.json` alimentam o gameplay local.
- `ItemDatabase.resolve_data_path()` prioriza `user://patches/data/<arquivo>` sobre `res://data/<arquivo>`. Um patch antigo no dispositivo pode esconder mudancas empacotadas e deve ser considerado em depuracao.
- O manifesto atual publica 16 JSONs, versao `2026.09.13`, com hashes e tamanhos validos. `eldoria_house_kit.json`, colisoes especiais e assets de mapa nao fazem parte do patch e exigem novo build do cliente.

## Dependencias, build e deploy

- Cliente: Godot 4.x, sem addons de terceiros encontrados. Renderizacao mobile usa `gl_compatibility`; viewport base 1280x720 em landscape.
- Backend: Node.js `>=20`; Express, `ws`, PostgreSQL (`pg`), JWT, bcrypt, Zod, Helmet, CORS, compression, Morgan e UUID. Versoes ficam travadas por `server/package-lock.json`.
- Geradores Python de assets usam Pillow; nao existe arquivo de requirements, portanto a versao usada nao esta fixada.
- Banco local: `docker compose -f database/docker-compose.yml up -d`; schema idempotente aplicado por `npm run migrate` ou por `npm run start:prod`.
- Backend local: `cd server`, instalar dependencias conforme lockfile e executar `npm run dev`/`npm run start`; requer PostgreSQL funcional.
- Render: `render.yaml` cria um web service Node e PostgreSQL, roda `npm ci`, depois `npm run start:prod`, usa `/health` e WebSocket compartilhado em `/ws`.
- Site oficial: workflow `.github/workflows/deploy-pages.yml` publica `website/` em GitHub Pages quando `main` altera essa pasta/workflow.
- Android: `export_presets.cfg` define o preset `Android`; `.github/workflows/release-android.yml` instala Godot 4.6.3, exporta APK por tag `v*`, verifica assinatura e publica APK/hash em GitHub Releases.
- `build-flutter-web.yml` e deliberadamente inoperante enquanto nao existir `pubspec.yaml`; Flutter e referencia futura, nao arquitetura atual.
- `website/game/` continua placeholder. Nao existe export Web do Godot comprovado.

## Verificacoes executadas em 2026-10-23

- Parse de 39 JSONs em `data/`, `client/config/` e `server/public/patches/`: aprovado.
- `node --check` em 40 arquivos de `server/src/`: aprovado com Node local `v24.15.0`.
- Hash SHA-256 e tamanho dos 16 arquivos do manifesto de patches: aprovados.
- Referencias a cenas/scripts de mapas deletados: nenhuma referencia executavel encontrada fora da documentacao.
- Godot 4.6.3 headless concluiu o scan de classes globais e o boot curto do launcher sem erros de script. Na primeira tentativa, antes do scan, houve erros em cascata de classes globais ausentes; desapareceram depois da importacao, confirmando problema de cache, nao de codigo.
- Godot 4.2.2 headless abriu o editor, mas encerrou com codigo 1 por `Scan thread aborted` durante quit, acompanhado apenas de avisos de cursor/build-tools/Blender. A compatibilidade 4.2.2 continua inconclusiva nesta maquina.
- Nao foram executados banco, migracao, servidor, export Android, dispositivo, login remoto ou testes end-to-end.

## Mapa de dependencias

- `project.godot` define cena inicial e autoloads.
- `client/scenes/mmo_launcher.tscn` -> `client/scripts/mmo_launcher.gd` -> `client/scripts/mmo_client.gd` -> `scenes/main.tscn`.
- `scenes/main.tscn` -> `scripts/main.gd` -> `scripts/player.gd`, `scripts/enemy.gd`, `scripts/npc.gd`, `scripts/item_drop.gd`, sistemas JSON e UI.
- `scripts/main.gd` carrega `data/maps.json`, `data/enemies.json`, `data/mmo_pets.json`, `data/mmo_mounts.json` e usa `quest_system.load_quests()`.
- `scripts/item_database.gd` carrega `data/items.json` e resolve patches em `user://patches/data/`.
- `scripts/class_database.gd` carrega `data/classes.json`.
- `scripts/drop_system.gd` usa `data/enemies.json`.
- `scripts/quest_system.gd` usa `data/quests.json`.
- `server/src/index.js` -> `WorldService` -> managers -> repositorios -> `database/schema.sql`.
- `server/src/managers/mapManager.js` tambem le `data/maps.json`, entao mudancas de mapa afetam client e servidor.
- `server/src/scripts/buildPatchManifest.js` publica JSONs de `data/` em `server/public/patches/`.
- `website/` depende dos arquivos de release/download e dos links em GitHub Releases/Render.

## Arquivos criticos

- `project.godot`: define startup, autoloads, input e exportabilidade.
- `client/config/mmo_client_config.json`: aponta para Render em HTTP/WSS, patches e online enabled.
- `client/scripts/mmo_client.gd`: contrato client com HTTP/WebSocket.
- `client/scripts/patch_client.gd`: atualizacao remota de dados.
- `scripts/main.gd`: maior concentrador de gameplay, UI, mapas, online, chat, companion, minimap e save.
- `scripts/player.gd`: estado do jogador e regras de combate/progressao/equipamento.
- `scripts/enemy.gd`: comportamento dos inimigos e efeitos.
- `scripts/item_database.gd`: fonte de dados e mecanismo de fallback para patches.
- `data/maps.json`, `data/quests.json`, `data/items.json`, `data/enemies.json`, `data/classes.json`: conteudo que dirige o jogo.
- `server/public/patches/manifest.json`: contrato de atualizacao remota.
- `database/schema.sql`: compatibilidade persistente do online.
- `server/src/services/worldService.js` e `server/src/net/wsGateway.js`: protocolo MMO.
- `website/index.html` e `.github/workflows/deploy-pages.yml`: publicacao do site.
- `export_presets.cfg`: build/export Android.
- `CLAUDE.md`: regras permanentes para continuidade por Claude Code.
- `HANDOFF_TO_CLAUDE.md`: snapshot operacional, Git e pendencias na data da transferencia.

## Decisoes arquiteturais identificadas

- O projeto migrou de um MVP singleplayer Godot para uma estrutura hibrida com launcher online primeiro.
- A cena principal continua sendo `scenes/main.tscn`, mas o boot normal passa pelo launcher MMO.
- Os mapas deixaram de depender apenas de cenas `.tscn`; `scripts/main.gd` desenha mapas e colisoes em runtime a partir de imagens/chunks/JSON.
- Dados de balanceamento foram externalizados em JSON e podem ser atualizados por patch remoto.
- O backend e autoritativo apenas em parte: controla login, sessoes, snapshots, movimento sanitizado, chat e varias features MMO; combate PvE local ainda parece majoritariamente no client.
- A persistencia online foi iniciada de forma incremental; save local continua existindo para offline.
- Sistema de patches nao cobre scripts/cenas/assets grandes; essas mudancas exigem novo APK.

## Funcionalidades prontas, parciais e legado

Prontas ou bem presentes:

- Projeto Godot 4 abre com launcher, UI e cena principal.
- Escolha/inicio offline ainda existe por fluxo de launcher/metadados.
- Player, inimigos, ataques, habilidades, drops, inventario, equipamentos, loja/paineis, HUD, minimapa, chat local/online e save local existem no codigo.
- Backend sobe HTTP, WebSocket, auth, world status, patches e managers MMO.
- Website publico e pipeline GitHub Pages existem.
- Builds Android locais e releases existem.

## Plano de mapas preservado

Estado ativo atual:

- `city_eldoria`: `Base de Eldoria`, mapa seguro em reconstrucao; sem NPCs ativos, com base 9x9 em chunks, rio ao redor, muros com colisao, abertura inferior central, deck/ponte para o futuro portal, 14 casas medievais top-down, 4 casas principais reservadas para NPCs futuros, 10 casas de aldeao e portal para `forest_boars`.
- `forest_boars`: `Floresta dos Javalis`, mapa ativo com Guarda Doran, mobs `Javali Selvagem`, `Lobo Cinzento`, `Aranha Venenosa`, `Javali Bruto`, `Lobo Alfa`, `Rei Javali`, coletaveis e portal para `city_eldoria`.

Mapas deixados apenas como base vazia para implantar depois:

- `bat_cave`: `Caverna Profunda`; mobs planejados `Morcego Pequeno`, `Aranha Venenosa`, `Espirito Fraco`, `Morcego Sombrio`, `Espectro Arcano`, `Aranha Rainha`, `Guardiao Cristalino`, `Matriarca Venenosa`; NPC planejado `Mineiro Perdido`.
- `arcane_ruins`: `Ruinas Arcanas`; mobs planejados `Espirito Fraco`, `Aprendiz Corrompido`, `Espectro Arcano`, `Sentinela Arcano`, `Arquimago Corrompido`; NPC planejado `Maga Selene`.
- `city_valdoria`: `Valdoria Cidade`; sem mobs planejados; NPCs planejados `Mira, Vendedora de Pets`, `Torin, Mestre de Montarias`, `Durnan, Forja Rara`, `Liora, Curandeira`, `Varek, Mercador`.
- `highland_pass`: `Passagem Alta`; mobs planejados `Bandido das Colinas`, `Golem de Pedra`, `Senhor das Colinas`; sem NPC planejado.
- `crystal_mines`: `Minas de Cristal`; mobs planejados `Guardiao Cristalino`, `Draco Jovem`, `Tita de Cristal`; sem NPC planejado.
- `ember_fortress`: `Fortaleza de Cinzas`; mobs planejados `Cavaleiro Sombrio`, `Draco Jovem`, `General Infernal`; sem NPC planejado.
- `pantano`: asset visual existe em `assets/maps/pantano/`, mas ainda nao esta ativo em `data/maps.json`.

Quests ativas atuais:

- `furia_javalis` e `tutorial_forest` permanecem ativas por dependerem da floresta.
- Quests `cristal_quebrado`, `sombras_caverna`, `tutorial_ruins` e `tutorial_cave` foram retiradas do JSON ativo junto com os mapas correspondentes e devem ser reimplantadas quando esses mapas voltarem.

Parciais/em desenvolvimento:

- Somente Eldoria e Floresta ficam como conteudo ativo de mapa neste momento; os demais IDs foram preservados como bases vazias para reconstrucao incremental.
- Eldoria esta em base 9x9: os chunks externos formam o rio navegavel visualmente, mas bloqueado por colisao; o deck inferior central fica livre para servir de ponte/passagem ate o portal da Floresta.
- Os 32 chunks que contem agua em Eldoria usam quatro quadros visuais animados, gerados a partir dos chunks atuais por `tools/generate_eldoria_water_frames.py` em `assets/maps/eldoria/water_frames/`. A animacao altera apenas as cores da agua; margens, muros, casas, deck, minimapa e colisoes continuam definidos pelos arquivos e codigo existentes. Se os chunks base forem redesenhados, executar novamente o gerador.
- Eldoria tem marcadores internos nao visiveis para futuros NPCs em `scripts/main.gd`: `Arion, Mestre de Classes`, `Bakka, Ferreiro`, `Sarah, Curandeira` e `Borin, Mercador`. Eles ainda nao aparecem como NPCs no mapa ativo.
- O kit ativo de Eldoria usa 14 casas separadas como `Sprite2D`: Mestre de Classes, Curandeira, Mercador, Ferreiro e dez casas de aldeao alternando os modelos A/B. Os PNGs ficam em `assets/maps/eldoria/houses/`; o posicionamento e as 211 formas de colisao ficam em `data/eldoria_house_kit.json`.
- As colisoes do kit foram derivadas somente das areas vermelhas dos guias originais em `tools/eldoria_house_kit/collision_guides/`. A metade superior preta nao bloqueia e o jogador pode passar visualmente por tras das casas; os guias nao aparecem no jogo. O gerador reproduz chunks, minimapa e dados pelo arquivo `tools/eldoria_house_kit/generate_eldoria_house_kit.py`.
- Todas as casas antigas desenhadas diretamente no chao foram removidas. O gerador parte da base limpa `assets/maps/eldoria/eldoria_7x7_minimap.png`, sem colar remendos de piso, preserva integralmente as ruas e remove as placas/descricoes visuais dos seis sprites de casa. Ruas principais, cruzamentos, portao inferior e deck continuam livres.
- Quests locais ativas foram limitadas a floresta; quests online seguem como persistencia parcial.
- Persistencia online de inventario/equipamento/quests ainda nao parece completa.
- Mercado/crafting/pets/montarias/dungeons/rank/VIP/conquistas/seasons tem UI/protocolo/backend, mas precisam teste ponta a ponta.
- Patches de dados foram reconciliados nesta etapa; antes de publicar, ainda validar boot e fluxo real do launcher.

Legado ou possivelmente nao usado:

- Referencias Flutter no README sao explicitamente futuras/legadas.
- `site/` parece site privado/local antigo; `website/` e o site publico oficial.
- Cenas antigas de mapa foram deletadas no working tree, mas ainda devem ser consideradas historico/legado ate confirmar que a geracao runtime substitui tudo.
- Scripts duplicados de UI existem em `scripts/ui/*.gd` e na raiz `scripts/ui_*.gd`; cenas usam ambos dependendo do caso, entao nao remover sem pesquisa.

## Problemas conhecidos e riscos

- `scripts/main.gd` tem 7.075 linhas fisicas e concentra muitas responsabilidades. E risco de regressao para qualquer ajuste em mapa, UI, online, combate, save ou mobile.
- Working tree esta sujo com muitas alteracoes nao commitadas, incluindo assets de floresta, dados, cenas deletadas, scripts e servidor. Tratar tudo como trabalho em andamento do projeto.
- O estado atual nao pode ser reproduzido a partir de `origin/main`: centenas de assets e alteracoes de codigo ainda nao estao em commit. Um clone novo recebe apenas v0.1.16, nao Eldoria/Floresta e correcoes locais descritas aqui.
- `ci/android/paradise-release.keystore` esta rastreado pelo Git apesar das regras atuais de `.gitignore`; `export_presets.cfg` tambem contem configuracao sensivel de assinatura. Nao copiar valores para documentacao/logs. Antes de nova publicacao, remover o segredo do versionamento, rotacionar a chave se ja exposta e migrar a CI para GitHub Secrets.
- `server/src/config.js` possui defaults de desenvolvimento para JWT e banco. Producao deve falhar sem segredos/credenciais reais, em vez de herdar defaults.
- O workflow Android usa Godot 4.6.3, enquanto `project.godot` declara 4.2; validar export e runtime nas duas versoes antes de release.
- A versao local de `export_presets.cfg` e `0.1.21`, mas o commit/tag de referencia e `v0.1.16`. Nao publicar sem decidir qual versao e a correta.
- Cenas/scripts antigos de mapas ainda aparecem deletados no working tree; os IDs dos mapas foram preservados como bases vazias para evitar quebra de saves/referencias, mas o conteudo antigo foi retirado do JSON ativo.
- `server/public/patches/manifest.json` foi atualizado, mas qualquer nova mudanca em `data/` exige rodar novamente o build de patch.
- O evento de boss do backend usa `arcane_ruins`; esse mapa agora esta como base vazia, entao o evento deve ficar desativado ou ser refeito quando Ruinas Arcanas for reimplantado.
- `tutorial_forest` esta no JSON, mas `BEGINNER_QUESTS` esta vazio e nenhum NPC ativo referencia essa quest. Ela parece inacessivel para novos saves, embora possa continuar em saves antigos.
- Mapas vazios continuam conhecidos pelo backend e, por terem `safe: false`, sao tratados como PvP se um cliente enviar esse ID. O servidor valida limite do mapa, mas nao portal/colisao.
- `project.godot` usa launcher online como cena inicial e `client/config/mmo_client_config.json` esta com `online_enabled: true`, entao problemas no backend/patch podem afetar boot normal.
- O ultimo teste documentado do Render, em 2026-09-12, retornou servico suspenso. O estado atual e nao confirmado.
- Backend local nao iniciou nesta maquina porque o PostgreSQL local em `127.0.0.1:5432` recusou conexao; Docker tambem nao esta disponivel no PATH para subir `database/docker-compose.yml` automaticamente.
- O HTTP so inicia depois da conexao com o PostgreSQL, portanto `/health` nao ajuda a diagnosticar banco indisponivel durante startup e pode falhar o health check da hospedagem.
- Nao existe suite automatizada. As features MMO avancadas sao presenca de codigo, nao garantia de funcionamento ponta a ponta.
- Ha muitos assets e APKs pesados versionados/locais; mudancas em assets podem gerar diffs grandes e lentos.
- Encoding aparente em alguns textos mostra caracteres quebrados em pelo menos um trecho de UI (`cosmÃ©ticos`), sugerindo risco de mistura de encoding.
- Avisos de Git indicam conversao LF/CRLF em muitos arquivos quando tocados.

## TODOs e sinais de incompleto encontrados

- `README.md` declara que `website/game/` e placeholder.
- `README.md` mantem comandos Flutter apenas como referencia futura.
- `assets/README_visual_assets.md` marca alguns caminhos como reservados para sprites futuros.
- `scripts/audio_manager.gd` indica audio final ainda ausente/placeholder.
- `docs/online-contas-save.md` afirma que inventario, equipamentos e quests online ainda devem ser persistidos em proximas etapas.
- `assets/maps/caverna/PROMPT_CODEX_IMPLANTAR_CAVERNA.txt` contem planejamento para caverna e pontos futuros.
- `README.md` contem instrucoes antigas de criar repositorio/release v0.1.0, embora o remoto e tags ate v0.1.16 ja existam.
- `release-android.yml` ainda usa um valor default antigo no disparo manual; a tag real deve ser informada explicitamente.
- Os scripts geradores de assets dependem de Pillow sem lockfile/requirements.

## Proximos passos recomendados

1. Estabilizar o estado atual do working tree antes de novas features: revisar intencao das alteracoes nao commitadas e decidir o que deve entrar.
2. Recriar os mapas um por vez, comecando pela prioridade escolhida pelo usuario, usando o plano de nomes/mobs/NPCs preservado.
3. Ao reativar cada mapa, religar portais, spawns, NPCs, coletaveis, quests e patches somente daquele mapa.
4. Conferir no editor Godot se a base 9x9 de Eldoria, o deck inferior e a Floresta continuam navegaveis antes de iniciar o proximo mapa.
5. Reativar/republicar o backend Render ou apontar temporariamente o client para backend local funcional.
6. Subir PostgreSQL local, rodar migracao e testar `npm run start`, login/registro e `/world/status`.
7. Antes de publicar novo APK/site, confirmar URLs de download, manifest de patches, versionCode/versionName e arquivo final correto.
8. Corrigir o tratamento de segredos Android antes de qualquer push publico e decidir como preservar/rotacionar a chave de assinatura existente.
9. Tornar `tutorial_forest` acessivel novamente ou removê-la do conjunto ativo ate o NPC/fluxo voltar.
10. Criar testes minimos para contratos de JSON, schema, auth e WebSocket antes de ampliar os sistemas MMO.

## Historico tecnico recente

- 2026-09-12: criada memoria tecnica `PROJECT_CONTEXT.md` apos analise do repositorio local do task Codex anterior `jogo rpg`.
- Estado analisado: branch `main`, HEAD `275ca45` (`v0.1.16`, `origin/main`), com working tree sujo e alteracoes locais relevantes.
- Alteracoes recentes no historico Git: releases v0.1.1 a v0.1.16, ajustes de Android, HUD, mapas online, sincronizacao entre mapas, pets/mobs e site.
- Estado local recente nao commitado: edicoes em floresta 7x7, launcher/MMO client, `data/items.json`, `data/maps.json`, `data/quests.json`, `project.godot`, `export_presets.cfg`, scripts centrais, patches e `server/src/managers/mapManager.js`; delecoes de cenas/scripts de mapas antigos; novos sprites de NPCs, harvest, frames de caminhada e dados de colisao.
- Decisao tomada nesta etapa: documentar contexto e riscos sem fazer grandes alteracoes de codigo.
- 2026-09-12: reconciliados `data/maps.json` e `data/quests.json` com o conjunto funcional conhecido do HEAD, preservando `world_reset`; sincronizados `server/public/patches/data/maps.json` e `server/public/patches/data/quests.json`; regenerado `server/public/patches/manifest.json`.
- Validacao leve concluida: JSONs principais parseiam, mapas = 9, quests = 6, arquivos de patch = 16, fontes `data/` e copias de patch estao alinhadas, hashes/tamanhos do manifesto conferem e nao foram encontrados portais/spawns/recompensas quebrados na checagem estatica.
- 2026-09-12: validacao Godot 4.2.2 sem janela confirmou que `mmo_launcher.tscn`, `main.tscn`, `player.tscn`, `enemy.tscn` e `npc.tscn` carregam e instanciam; fluxo do launcher offline troca para `res://scenes/main.tscn`.
- 2026-09-12: endpoints remotos configurados retornaram 503 `Service Suspended`; backend local falhou por ausencia de PostgreSQL ativo e Docker indisponivel. Ajustado `client/scripts/mmo_client.gd` para parse seguro de respostas HTTP, preservando mensagens JSON validas do servidor e evitando erro quando o servidor retorna HTML.
- 2026-09-12: Eldoria entrou em modo reconstrucao. O runtime nao usa mais imagem/minimapa antigos de Eldoria quando `ELDORIA_REBUILD_BASE_ONLY` esta ativo; `city_eldoria` foi renomeado para `Base de Eldoria`, NPCs antigos foram removidos do JSON, e ficaram apenas base limpa, caminhos, spawn e portal para a floresta. Assets antigos de Eldoria foram preservados no disco como referencia.
- 2026-09-12: mapas fora de Eldoria/Floresta foram convertidos para base vazia: sem NPCs, portais, spawns, coletaveis e safe zones. Floresta manteve apenas portal para Eldoria. Quests ativas foram reduzidas para `furia_javalis` e `tutorial_forest`. Plano de nomes, mobs e NPCs dos mapas removidos ficou registrado em `Plano de mapas preservado`.
- 2026-09-12: criada nova base visual de Eldoria em 7x7 chunks (`assets/maps/eldoria/chunks_7x7/`) com piso em bloquetos no mapa inteiro e caminhos em bloquetos bege. Runtime passou a carregar `EldoriaChunks7x7`, com tamanho mundial `5600x4480`, minimapa novo `assets/maps/eldoria/eldoria_7x7_minimap.png`, sem casas, NPCs ou decoracoes antigas.
- 2026-09-12: adicionados muros em volta da base 7x7 de Eldoria, com colisao registrada no runtime e abertura central inferior livre para acessar o portal da Floresta.
- 2026-09-12: Eldoria foi expandida para 9x9 chunks (`assets/maps/eldoria/chunks_9x9/`), com o 7x7 central preservado como cidade/base, rio visual nos chunks externos, colisao de agua ao redor, deck/ponte inferior central livre sobre a agua e portal da Floresta reposicionado para o deck. Runtime agora carrega `EldoriaChunks9x9`, minimapa `assets/maps/eldoria/eldoria_9x9_minimap.png`, tamanho mundial `7200x5760`, e validacao Godot confirmou 81 chunks, muros bloqueando, agua bloqueando e passagem/deck livres.
- 2026-09-13: adicionadas casas medievais europeias em Eldoria: 4 casas principais coerentes com os futuros NPCs/profissoes (`Mestre de Classes`, `Ferreiro`, `Curandeira`, `Mercador`) e casas residenciais extras distribuídas pela cidade. Foram adicionados marcadores internos invisiveis via `ELDORIA_FUTURE_NPC_LOCATIONS`, colisao de construcoes via `ELDORIA_BUILDING_COLLISION_RECTS`, e validacao Godot confirmou 81 chunks, 4 marcadores e ruas/deck principais livres.
- 2026-09-19: criado movimento no rio de Eldoria com quatro quadros por chunk de agua (32 chunks, 128 imagens), animados no runtime por `AnimatedSprite2D` a 5 quadros/segundo. O gerador reaproveita os chunks 9x9 atuais, preserva pixels fora da paleta da agua e usa coordenadas globais para manter a ondulacao continua entre bordas de chunks.
- 2026-10-05: aplicado e refinado `Eldoria_Houses_and_Collisions_Kit.zip`. As 4 casas principais e 10 casas de aldeao passaram a ser sprites separados com profundidade por Y; somente as areas vermelhas dos seis guias viraram colisao, totalizando 211 `CollisionShape2D`. Todas as casas antigas foram retiradas dos chunks, a base limpa original voltou a ser a unica camada de chao, as placas de descricao foram removidas das imagens e o minimapa foi recomposto. A validacao Godot confirmou 14 casas, 81 chunks, 32 chunks de agua animada, passagem livre atras das metades superiores, bases bloqueadas e todas as ruas/deck livres.
- 2026-10-23: realizada auditoria de transferencia para Claude Code. Confirmados branch/HEAD/upstream, dirty tree, contratos HTTP/WebSocket/save, 30 tabelas PostgreSQL, dados ativos, deploys e riscos de seguranca. Parse de JSON, sintaxe Node, hashes de patch e boot curto no Godot 4.6.3 passaram; Godot 4.2.2 ficou inconclusivo por aborto do scan do editor. Criados `CLAUDE.md` e `HANDOFF_TO_CLAUDE.md`; nenhuma logica do aplicativo foi alterada.
