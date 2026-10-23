# CLAUDE.md

Regras permanentes para continuar o Paradise RPG com Claude Code.

## Ordem de leitura obrigatoria

1. Leia este arquivo.
2. Leia `HANDOFF_TO_CLAUDE.md` para o snapshot Git e as pendencias atuais.
3. Leia `PROJECT_CONTEXT.md` para arquitetura, contratos, mapas e historico.
4. Consulte `README.md`, `server/README.md` e `docs/` somente como apoio; alguns trechos estao desatualizados.
5. Antes de alterar qualquer arquivo, procure `AGENTS.md` no caminho e diretorios pais. Na auditoria de 2026-10-23 nao havia nenhum.

## Fonte da verdade

- O working tree local e a fonte principal da verdade. O HEAD `275ca45` nao contem centenas de alteracoes e assets atuais.
- Codigo/configuracao/dados executados prevalecem sobre README, conversas e nomes historicos.
- Marque informacao externa ou nao testada como **nao confirmada**.
- Nao presuma que uma classe, manager, tabela ou painel esta funcional apenas porque existe.

## Regras de continuidade

- Nunca recrie um sistema antes de pesquisar a implementacao e os consumidores existentes.
- Nunca substitua arquivos inteiros se uma alteracao localizada for suficiente.
- Nao renomeie caminhos, IDs de mapa, IDs de item/quest, eventos WebSocket, campos JSON, nodes de cena, autoloads ou colunas sem mapear todas as referencias.
- Preserve compatibilidade com saves locais, PostgreSQL, patches em `user://patches/data/`, APIs, assets e APKs.
- Nao apague arquivos “legados” sem executar `rg` no repositorio e verificar Git/history.
- Nao limpe, restaure, resete ou reformate em massa o working tree sujo.
- Nao rode geradores de mapa/assets sem revisar o script e prever todos os arquivos sobrescritos.
- Prefira mudancas pequenas, testaveis e reversiveis.
- Nao instale dependencias, faça upgrade de engine ou refatore arquitetura sem pedido explicito.

## Seguranca

- Nunca escreva valores de `.env`, tokens, senhas, chaves ou credenciais em documentos, commits, logs ou respostas.
- Existe material de assinatura Android rastreado/configurado no repositorio. Nao exiba seu conteudo nem seus valores.
- Antes de publicar, tratar a chave Android como potencialmente exposta: remover do Git, rotacionar quando aplicavel e migrar a CI para secrets.
- Producao deve fornecer `DATABASE_URL`, `JWT_SECRET` e demais variaveis; nao confiar em defaults locais de `server/src/config.js`.

## Arquitetura resumida

- Godot: `project.godot` -> `client/scenes/mmo_launcher.tscn` -> `scenes/main.tscn`.
- Autoloads: `MMOClient`, `PatchClient`, `ThemeManager`, `AudioManager`.
- Orquestrador principal: `scripts/main.gd` (aprox. 7 mil linhas; alto risco de regressao).
- Gameplay: `scripts/player.gd`, `scripts/enemy.gd`, `scripts/npc.gd`, `scripts/item_drop.gd`, sistemas em `scripts/` e cenas em `scenes/`.
- Dados: JSONs em `data/`; alguns podem ser substituidos em runtime por patches em `user://patches/data/`.
- Backend: Node/Express/WebSocket em `server/src/`; PostgreSQL em `database/schema.sql`.
- Deploy: Render por `render.yaml`, Pages por `website/`, Android por `.github/workflows/release-android.yml`.

## Estado de mapas que deve ser preservado

- Conteudo ativo: `city_eldoria` e `forest_boars`.
- `world_reset` e alias/base de compatibilidade da floresta.
- Bases vazias reservadas: `arcane_ruins`, `bat_cave`, `city_valdoria`, `highland_pass`, `crystal_mines`, `ember_fortress`.
- Nao reative todos os mapas de uma vez. O usuario definiu reconstrucao mapa por mapa.
- Eldoria: 9x9 chunks, 7200x5760, 81 chunks, 32 chunks de agua com 4 frames, muros/agua com colisao, deck inferior, 14 casas e 211 formas de colisao.
- Floresta: 7x7 chunks, 5600x4480, mapa de caca ativo e portal para Eldoria.
- Casas de Eldoria sao sprites separados sobre a base limpa. Nao cole pisos/remendos sob as casas e nao reintroduza descricoes visuais.

## Arquivos e acoplamentos criticos

- `scripts/main.gd`: mapa, UI, combate, save, online, NPCs, portais, minimapa e companions.
- `data/maps.json`: consumido pelo cliente e por `server/src/managers/mapManager.js`.
- `data/items.json`, `data/quests.json` e demais JSONs: podem exigir regenerar `server/public/patches/manifest.json`.
- `data/eldoria_house_kit.json`: nao esta no manifesto de patches; alteracoes exigem build do cliente.
- `client/scripts/mmo_client.gd` <-> `server/src/net/wsGateway.js` <-> `server/src/services/worldService.js`: contrato WebSocket.
- `server/src/services/authService.js` <-> `server/src/http/authRoutes.js`: contrato HTTP de conta.
- `scripts/save_system.gd` e `scripts/player.gd`: compatibilidade de save local.
- `database/schema.sql` e `server/src/repositories/`: persistencia online.
- `scenes/ui/side_menu.tscn` usa `scripts/ui_side_menu.gd`; existem duplicatas em `scripts/ui/`, portanto nao remover por nome.

## Fluxo seguro para alteracoes

1. Rode `git status --short` e confirme que arquivos-alvo nao contem trabalho alheio.
2. Use `rg` para encontrar consumidores, IDs, caminhos e formatos.
3. Leia o diff local contra `HEAD` antes de editar.
4. Faça o menor patch possivel.
5. Valide JSON/sintaxe/cena especifica antes de testes amplos.
6. Se alterar `data/`, determine se o arquivo esta na lista de `server/src/scripts/buildPatchManifest.js`.
7. Se alterar mapa, valide spawn, portais, ruas/deck, colisoes, minimapa, chunks e save/online.
8. Atualize `PROJECT_CONTEXT.md` e `HANDOFF_TO_CLAUDE.md` apenas quando o estado tecnico realmente mudar.

## Comandos de consulta e validacao

Execute na raiz do repositorio em PowerShell.

```powershell
git status --short
git diff -- <arquivo>
rg -n "TERMO" scripts client server data scenes
```

Parse dos JSONs principais:

```powershell
Get-ChildItem data -Filter *.json | ForEach-Object {
  $null = Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100
}
```

Sintaxe do backend, sem iniciar banco/servidor:

```powershell
Get-ChildItem server/src -Recurse -Filter *.js | ForEach-Object {
  node --check $_.FullName
}
```

Godot local:

```powershell
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --path .
```

O projeto declara Godot 4.2, mas a CI Android usa 4.6.3. Teste compatibilidade antes de release.

Banco e backend, somente quando o ambiente estiver preparado:

```powershell
docker compose -f database/docker-compose.yml up -d
Set-Location server
npm ci
npm run migrate
npm run dev
```

Regenerar patches altera arquivos; faça apenas quando intencional:

```powershell
Set-Location server
npm run build-patch
```

## Geradores de Eldoria

- Agua: `tools/generate_eldoria_water_frames.py`.
- Casas/chunks/minimapa/colisoes: `tools/eldoria_house_kit/generate_eldoria_house_kit.py`.
- Ambos dependem de Pillow e podem sobrescrever muitos PNGs/JSONs.
- Antes de executar, revisar inputs, fazer inventario do diff e garantir que ruas/deck/base limpa serao preservados.

## Testes e limites atuais

- Nao ha suite automatizada nem `npm test`.
- Validacoes estaticas nao substituem teste manual no Godot, Android e ambiente online.
- O servidor depende do PostgreSQL antes de começar a escutar HTTP.
- O backend nao valida colisoes/portais do mapa; apenas limites e velocidade basica.
- Inventario/equipamento/quests online nao estao comprovados ponta a ponta.

## Git e publicacao

- Nao fazer `git add .`, `git reset --hard`, `git clean`, commit, push, tag ou release sem autorizacao explicita.
- Para documentacao, adicionar somente `PROJECT_CONTEXT.md`, `CLAUDE.md` e `HANDOFF_TO_CLAUDE.md`.
- Publicar apenas esses documentos nao transfere o estado local do jogo. Antes do push, revisar e versionar separadamente as alteracoes de codigo/assets que devem sobreviver em outro clone.
