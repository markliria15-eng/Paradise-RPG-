# Contas e save online

Este projeto ja possui a base para conta online:

- API HTTP de login e registro em `server/src/http/authRoutes.js`.
- Autenticacao JWT em `server/src/services/authService.js`.
- Servidor WebSocket em `server/src/net/wsGateway.js`.
- Banco PostgreSQL em `database/schema.sql`.
- Cliente Godot em `client/scripts/mmo_client.gd`.

## Como funciona o fluxo

1. O jogador registra uma conta e cria um personagem.
2. O servidor criptografa a senha com bcrypt.
3. O personagem e salvo no PostgreSQL.
4. O login devolve um token JWT e os personagens da conta.
5. O jogo conecta no WebSocket com esse token.
6. O servidor valida o token e libera o personagem no mundo.
7. O client envia autosave periodico com mapa, posicao, level, XP, HP, mana, ouro e skills.
8. O servidor sanitiza os dados e grava no PostgreSQL.
9. Ao sair e entrar de novo, o login carrega o personagem salvo.

## Onde hospedar

GitHub Pages hospeda somente o site e arquivos estaticos. Ele nao roda o servidor MMO nem o PostgreSQL.

Para o online publico, hospede o servidor em uma destas opcoes:

- Render
- Railway
- Fly.io
- VPS
- Azure/AWS/GCP

Para o banco PostgreSQL:

- Supabase
- Neon
- Railway PostgreSQL
- Render PostgreSQL
- VPS com PostgreSQL

## Configuracao do servidor

Crie as variaveis de ambiente conforme `.env.example`:

```text
DATABASE_URL=postgres://usuario:senha@host:5432/banco
JWT_SECRET=troque_por_um_segredo_forte
HTTP_PORT=8080
WS_PORT=8081
```

Rode o schema:

```bash
psql "$DATABASE_URL" -f database/schema.sql
```

Suba o servidor:

```bash
cd server
npm install
npm run start
```

## Configuracao do client

Edite `client/config/mmo_client_config.json` para apontar para o servidor publico:

```json
{
  "online_enabled": true,
  "http_base_url": "https://seu-servidor.exemplo.com",
  "ws_url": "wss://seu-servidor.exemplo.com/ws"
}
```

Depois exporte um APK novo e publique no site.

## O que ja salva

- Level
- XP
- HP
- Mana
- Ouro
- Mapa atual
- Posicao
- Skills Lutando, Distancia, Magica e Protecao

Inventario completo, equipamentos e quests online devem ser persistidos nas proximas etapas usando as tabelas ja preparadas no banco.
