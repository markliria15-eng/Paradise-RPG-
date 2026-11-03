# Teste rapido no PC e validacao mobile

O fluxo principal de desenvolvimento usa o jogo nativo para Windows. Ele carrega as mesmas cenas, scripts, mapas e contratos online do APK, mas nao exige exportar nem instalar o aplicativo a cada alteracao.

## Atalhos

- `TESTAR_JOGO_OFFLINE.bat`: atalho principal na raiz. Abre diretamente o gameplay offline, sem login, patches ou servidor.
- `tools/run_pc_online.bat`: ambiente de teste online (`staging`). Preserve para uma etapa futura.
- `tools/run_pc_local.bat`: backend em `127.0.0.1:3000`. Use para desenvolver servidor/banco sem depender da hospedagem.
- `tools/run_pc_production.bat`: perfil usado pelo Android/producao. Use somente para conferir a configuracao final.

Os atalhos usam Godot 4.6.3, viewport 1280x720 e conversao de clique do mouse em toque. Isso permite testar joystick, botoes e HUD mobile diretamente no PC.

Enquanto o desenvolvimento estiver somente offline, use apenas `TESTAR_JOGO_OFFLINE.bat`. Os atalhos online ficam preservados para uma etapa futura.

## Controles no PC

- Movimento: `WASD` ou setas.
- Ataque basico: `1`.
- Habilidades: `2`, `3` e `4`.
- Pocoes: `F1`, `F2`, `F3` e `F4`.
- Conversar com NPCs e atravessar portais: `Enter`.

Os atalhos aparecem sobre os quadrados de ataque, habilidades e pocoes. Os botoes de toque continuam disponiveis para futuros testes mobile.

## Perfis de ambiente

| Perfil | Arquivo | Uso |
| --- | --- | --- |
| `local` | `client/config/mmo_client_config.local.json` | Backend local, patches desativados |
| `staging` | `client/config/mmo_client_config.staging.json` | Servidor online de testes |
| `production` | `client/config/mmo_client_config.production.json` | APK e validacao final |

No Windows, o cliente usa `staging` por padrao. No Android, usa `production`. O arquivo antigo `mmo_client_config.json` continua como fallback de compatibilidade.

Tambem e possivel escolher manualmente em PowerShell:

```powershell
.\tools\run_pc.ps1 -Environment local -MobilePreview -Offline
.\tools\run_pc.ps1 -Environment local -MobilePreview
.\tools\run_pc.ps1 -Environment staging -MobilePreview
.\tools\run_pc.ps1 -Environment production -MobilePreview
```

Ou definir `PARADISE_MMO_ENV` antes de abrir o Godot.

Smoke test rapido, sem abrir janela permanente:

```powershell
.\tools\run_pc.ps1 -Environment local -MobilePreview -Offline -SmokeTest
```

## Backend local

O perfil `local` espera HTTP e WebSocket compartilhado em `http://127.0.0.1:3000` e `/ws`.

```powershell
docker compose -f database/docker-compose.yml up -d
Copy-Item .env.example server/.env
Set-Location server
npm ci
npm run migrate
npm run dev
```

Revise `server/.env` localmente antes de iniciar. Nunca envie esse arquivo ao Git.

## Quando usar emulador ou celular

Use o preview no PC durante implementacao. Rode emulador Android ou celular real somente quando concluir um bloco funcional, especialmente para validar:

- gestos e multitouch;
- teclado virtual;
- permissao de internet;
- consumo de memoria e desempenho;
- instalacao, assinatura e atualizacao do APK;
- diferencas de GPU e resolucao.

O emulador ainda instala uma build Android. Por isso ele e mais lento que o preview nativo e nao deve ser o ciclo principal de desenvolvimento.

## Observacao sobre staging

No momento, `staging` e `production` apontam para a mesma hospedagem configurada anteriormente. Em 2026-10-26, `/health` e `/world/status` responderam HTTP 503; o servidor precisa ser reativado/republicado para login e multiplayer pela internet. Quando existir um servidor de homologacao separado, altere somente `mmo_client_config.staging.json`.
