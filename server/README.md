# Arcadia MMO Server

Servidor autoritativo para Arcadia Realms, com:

- API HTTP de autenticação (`/auth/register`, `/auth/login`)
- JWT + bcrypt
- WebSocket para mundo online
- Tick de mundo, anti-cheat básico e auto-save
- Managers modulares: player/entity/combat/map/event/chat/trade/guild/pvp/boss/party
- Persistência em PostgreSQL

## Subir local

1. Copie `.env.example` para `.env`.
2. Suba o banco:
   - `docker compose -f ../database/docker-compose.yml up -d`
3. Instale dependências:
   - `npm install`
4. Inicie:
   - `npm run dev`

HTTP:
- `http://127.0.0.1:8080`

WebSocket:
- `ws://127.0.0.1:8081`

## Pacotes WebSocket esperados

Entrada:
- `auth`
- `move`
- `chat`
- `pvp_attack`
- `boss_attack`
- `trade_request`, `trade_accept`, `trade_offer`, `trade_confirm`
- `guild_create`, `guild_invite`, `guild_accept_invite`
- `party_invite`, `party_accept`

Saída:
- `auth_ok`
- `world_entered`
- `world_snapshot`
- `chat_message`
- `system_event`
- `player_joined`, `player_left`
- `entity_hp_sync`
- `pvp_attack_result`, `pvp_damage_taken`
- `trade_*`, `guild_*`, `party_*`

