# Hospedagem online do Paradise RPG

O jogo ainda nao fica publico sozinho apenas com o APK. Para aparecerem varios jogadores na tela e salvar conta/personagem, voce precisa hospedar:

1. Servidor Node.js em uma URL publica.
2. Banco PostgreSQL online.
3. APK apontando para essa URL publica.

## Recomendacao principal

Use Render primeiro, porque ele hospeda o servidor Node.js, aceita WebSocket publico e tambem oferece PostgreSQL gerenciado.

Estrutura ja preparada:

- `server/`: servidor MMO, login, save, WebSocket e sistemas online.
- `database/schema.sql`: tabelas do PostgreSQL.
- `render.yaml`: blueprint para Render.
- `server/Dockerfile`: alternativa para Docker/Fly/Railway.

## URLs do jogo online

Quando o servidor estiver publicado, ele tera:

- HTTP/API: `https://SEU-SERVIDOR`
- WebSocket: `wss://SEU-SERVIDOR/ws`

No APK, edite:

`client/config/mmo_client_config.json`

Exemplo:

```json
{
  "http_base_url": "https://paradise-rpg-server.onrender.com",
  "ws_url": "wss://paradise-rpg-server.onrender.com/ws",
  "online_enabled": true,
  "remember_login": true
}
```

Depois gere e instale o APK novamente.

## Variaveis de ambiente do servidor

Obrigatorias em producao:

```env
NODE_ENV=production
PORT=8080
WS_MODE=shared
WS_PATH=/ws
DATABASE_URL=postgres://...
DB_SSL=true
JWT_SECRET=uma_chave_grande_e_secreta
CLIENT_ORIGIN=*
SAVE_INTERVAL_MS=20000
WORLD_TICK_MS=100
```

## Render

1. Envie o projeto para o GitHub.
2. No Render, crie um Blueprint apontando para o repo, ou crie manualmente:
   - Web Service Node.js.
   - Root directory: `server`.
   - Build command: `npm ci`.
   - Start command: `npm run start:prod`.
3. Crie um Render Postgres.
4. Copie a connection string do Postgres para `DATABASE_URL`.
5. Defina `DB_SSL=true`.
6. Abra `https://SEU-SERVIDOR/health`.
7. Abra `https://SEU-SERVIDOR/world/status`.

## Railway ou Fly.io

Tambem funcionam:

- Use o `server/Dockerfile`.
- Configure `DATABASE_URL`.
- Configure `DB_SSL=true` se o banco exigir SSL.
- Exponha apenas uma porta HTTP.
- Use WebSocket em `/ws`.

## Supabase

Supabase pode ser usado apenas como banco PostgreSQL.

- Crie projeto no Supabase.
- Copie a connection string PostgreSQL.
- Use em `DATABASE_URL`.
- Use `DB_SSL=true`.
- Ainda sera necessario hospedar o servidor Node.js em Render/Railway/Fly/VPS.

## Teste final

Depois do deploy:

1. Acesse `/health`.
2. Acesse `/world/status`.
3. Coloque a URL publica em `client/config/mmo_client_config.json`.
4. Gere APK novo.
5. Instale em dois celulares.
6. Crie duas contas.
7. Entre no mesmo mapa.
8. Os personagens devem aparecer um para o outro.
9. Ande com um personagem e veja o outro sincronizar.
10. Saia e entre novamente para confirmar o save.
