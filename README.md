# Paradise RPG

Paradise RPG e um RPG 2D estilo Tibia/Arcadia feito em Godot 4, com estrutura preparada para MMO online.

O projeto esta organizado para desenvolvimento local, publicacao em GitHub, download publico por GitHub Releases e site oficial por GitHub Pages.

## Estrutura do projeto

```text
client/      Estrutura do client/launcher e arquivos relacionados ao jogo
server/      Backend MMO, WebSocket, API, autenticacao e logica online
database/    Scripts SQL e estrutura PostgreSQL
assets/      Sprites, mapas, tilesets, icones, sons e imagens
scenes/      Cenas Godot 4
scripts/     Scripts GDScript do client
website/     Site publico oficial de download e versao web estatica
site/        Site privado antigo/local para download direto do APK
docs/        Documentacao tecnica e guias de publicacao
releases/    Builds locais antes de enviar para GitHub Releases
tools/       Scripts auxiliares de build, Android e publicacao local
```

## Estado atual

- Client em Godot 4.
- APK Android release gerado localmente.
- Site oficial criado em `website/`.
- Workflow de GitHub Pages criado em `.github/workflows/deploy-pages.yml`.
- Documentacao de publicacao criada em `docs/`.
- Backend Node.js e banco PostgreSQL preparados em `server/` e `database/`.

Importante: GitHub Pages hospeda somente arquivos estaticos. Ele pode hospedar o site e uma versao web estatica do client, mas nao deve hospedar o servidor MMO nem o banco de dados.

O backend do MMO precisa ficar em um servico separado, como Render, Railway, Fly.io, VPS, Firebase, Supabase ou outro servidor.

## Site publico

O site oficial fica em:

```text
website/index.html
```

Ele contem:

- Hero principal com download Android.
- Botao para jogar no navegador.
- Botao de download Windows.
- Secoes de classes, recursos, progressao, mapas e download.
- Comentarios no HTML mostrando onde trocar os links pelos arquivos do GitHub Releases.

Depois de publicar no GitHub Pages, o endereco sera:

```text
https://markliria15-eng.github.io/Paradise-RPG-/
```

## Como subir o projeto para o GitHub

Repositorio configurado:

```text
https://github.com/markliria15-eng/Paradise-RPG-.git
```

Para subir do zero em outra maquina, rode:

```bash
git init
git add .
git commit -m "Publicacao inicial do Paradise RPG"
git branch -M main
git remote add origin https://github.com/markliria15-eng/Paradise-RPG-.git
git push -u origin main
```

Depois ative GitHub Pages:

1. Abra o repositorio no GitHub.
2. Va em `Settings > Pages`.
3. Em `Build and deployment`, selecione `GitHub Actions`.
4. Faca push na branch `main`.

## Como atualizar o site

```bash
git add .
git commit -m "Atualiza site de download"
git push
```

O workflow `.github/workflows/deploy-pages.yml` publica automaticamente a pasta `website/`.

## Como trocar os links de download

1. Crie uma Release no GitHub.
2. Envie os arquivos:

```text
paradise-rpg-android-v0.1.0.apk
paradise-rpg-windows-v0.1.0.zip
```

3. Copie o link de cada arquivo na Release.
4. Abra `website/index.html`.
5. Procure por:

```html
<!-- Trocar este link pelo link real do APK no GitHub Releases. -->
<!-- Trocar este link pelo link real do ZIP Windows no GitHub Releases. -->
```

6. Troque os `href` dos botoes pelos links reais.
7. Faca commit e push.

## Publicar downloads no GitHub Releases

Guia completo:

```text
docs/publicar-downloads.md
```

Checklist:

```text
docs/checklist-publicacao.md
```

## Comandos uteis

### Criar build Flutter Web

Este projeto atual e Godot, nao Flutter. Estes comandos ficam como referencia se um client Flutter for adicionado no futuro:

```bash
flutter clean
flutter pub get
flutter build web --release
```

### Criar APK Android com Flutter

Referencia para projeto Flutter futuro:

```bash
flutter build apk --release
```

### Criar AppBundle para Play Store com Flutter

Referencia para projeto Flutter futuro:

```bash
flutter build appbundle --release
```

### Exportar APK Android no Godot

O projeto ja possui preset Android em `export_presets.cfg`. O APK release local atual fica em:

```text
build/android/ArcadiaRealms2D-release.apk
```

Tambem existe copia local para publicacao em:

```text
releases/paradise-rpg-android-v0.1.0.apk
```

## Rodar local

### Banco

```powershell
cd database
docker compose up -d
```

### Servidor

```powershell
cd server
npm install
npm run start
```

### Cliente Godot

1. Abra `project.godot` no Godot 4.
2. Use a cena inicial configurada no projeto.
3. Rode o jogo pelo editor ou exporte pelos presets.

## Conta e save online

O client agora envia autosave quando esta conectado no modo online. O servidor salva level, XP, HP, mana, ouro, mapa, posicao e skills no PostgreSQL, e o login carrega esses dados quando o jogador entra novamente.

Guia completo:

```text
docs/online-contas-save.md
docs/hospedagem-online.md
```

Resumo:

1. Hospede o backend Node.js em Render, Railway, Fly.io, VPS ou similar.
2. Hospede o PostgreSQL em Render Postgres, Supabase, Neon, Railway ou VPS.
3. Use `render.yaml` para publicar servidor + banco no Render, ou rode `npm run migrate` no servidor para aplicar `database/schema.sql`.
4. Configure `client/config/mmo_client_config.json` com as URLs publicas HTTP/WSS.
5. Exporte um APK novo e publique no site.

Exemplo de URLs publicas no client:

```json
{
  "http_base_url": "https://paradise-rpg-server.onrender.com",
  "ws_url": "wss://paradise-rpg-server.onrender.com/ws",
  "online_enabled": true,
  "remember_login": true
}
```

## Versao web do jogo

A pasta `website/game/` contem um placeholder.

Se o jogo for exportado para web no futuro:

1. Exporte a versao web do client.
2. Copie os arquivos gerados para `website/game/`.
3. Teste `website/game/index.html`.
4. Faca commit e push.

O botao `Jogar no navegador` ja aponta para:

```text
./game/index.html
```

## O que ainda falta para ficar online para todos

- Criar repositorio GitHub publico ou privado.
- Fazer push do projeto.
- Ativar GitHub Pages com GitHub Actions.
- Criar a Release `v0.1.0`.
- Enviar APK e ZIP Windows para a Release.
- Trocar os links no `website/index.html`.
- Hospedar o servidor MMO fora do GitHub Pages.
- Hospedar o PostgreSQL em servico online.
- Configurar `.env` real no servidor online.
- Testar login, multiplayer, chat, trade, PvP, bosses e eventos em ambiente publico.

## Segurança

Nao envie para o GitHub:

- `.env` real.
- Tokens.
- Senhas.
- Arquivos de keystore.
- Chaves privadas.
- Builds pesados fora do GitHub Releases.

Use `.env.example` apenas como modelo.
