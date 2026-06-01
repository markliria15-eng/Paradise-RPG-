# Client MMO (Godot 4)

Arquivos principais:

- `client/scenes/mmo_launcher.tscn`: login/register/connect world.
- `client/scripts/mmo_client.gd`: cliente HTTP + WebSocket.
- `client/scripts/mmo_launcher.gd`: UI do launcher.

Integração com jogo:

- `scripts/main.gd` detecta `MMOClient` (autoload) e ativa modo online.
- No modo online, envia movimento ao servidor e renderiza jogadores remotos.

