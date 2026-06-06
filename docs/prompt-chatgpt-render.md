# Prompt para o ChatGPT guiar hospedagem no Render

Copie e cole este texto no ChatGPT quando estiver abrindo o Render pelo celular ou computador.

```text
Quero que voce me guie passo a passo para hospedar meu jogo Paradise RPG no Render.

Contexto do projeto:
- Repositorio GitHub: https://github.com/markliria15-eng/Paradise-RPG-.git
- O jogo e feito em Godot 4.
- O backend MMO esta na pasta server/.
- O banco esta em PostgreSQL.
- Existe um arquivo render.yaml na raiz do projeto.
- O servidor usa Node.js.
- O servidor tem login, JWT, bcrypt, save online, WebSocket e multiplayer.
- O client Godot usa:
  - HTTP para login/registro.
  - WebSocket para players aparecerem no mesmo mapa.
- O WebSocket publico deve ficar em /ws.
- O arquivo do client que vou editar depois e:
  client/config/mmo_client_config.json

Objetivo:
Me orientar para deixar o Paradise RPG online no Render, com:
1. servidor Node.js publico;
2. banco PostgreSQL online;
3. WebSocket funcionando;
4. contas salvando;
5. jogadores aparecendo para todos no mesmo mapa;
6. URLs corretas para colocar no APK.

Arquivos importantes ja existentes:
- render.yaml
- server/package.json
- server/src/index.js
- server/src/scripts/migrate.js
- database/schema.sql
- client/config/mmo_client_config.json
- client/config/mmo_client_config.production.example.json

Configuracao esperada no Render:
- Criar via Blueprint usando render.yaml, se possivel.
- Web Service:
  - nome: paradise-rpg-server
  - runtime: Node
  - root directory: server
  - build command: npm ci
  - start command: npm run start:prod
- PostgreSQL:
  - nome: paradise-rpg-db
  - database: paradise_rpg
  - user: paradise_rpg

Variaveis de ambiente esperadas:
NODE_ENV=production
WS_MODE=shared
WS_PATH=/ws
DB_SSL=true
CLIENT_ORIGIN=*
DATABASE_URL=connection string do PostgreSQL
JWT_SECRET=uma chave secreta grande

Depois do deploy, preciso testar:
1. Abrir https://URL-DO-SERVIDOR/health
2. Abrir https://URL-DO-SERVIDOR/world/status
3. Confirmar que o servidor nao esta dando erro nos logs.
4. Confirmar que o banco foi conectado.
5. Confirmar que database/schema.sql foi aplicado pelo comando npm run start:prod.

Quando o servidor estiver online, me diga exatamente o que colocar neste arquivo:

client/config/mmo_client_config.json

Exemplo:
{
  "http_base_url": "https://URL-DO-SERVIDOR",
  "ws_url": "wss://URL-DO-SERVIDOR/ws",
  "online_enabled": true,
  "remember_login": true
}

Regras para voce me guiar:
- Va uma etapa por vez.
- Nao pule passos.
- Me diga onde clicar no painel do Render.
- Quando aparecer uma tela, me pergunte o que estou vendo antes de continuar.
- Se aparecer erro no deploy, me ajude a interpretar o log.
- Se aparecer erro de banco, confira DATABASE_URL e DB_SSL.
- Se aparecer erro de WebSocket, confira se estou usando wss:// e /ws.
- Se o Render pedir plano, me explique a opcao mais barata que funcione para teste.
- No final, me entregue as URLs finais HTTP e WebSocket para eu colocar no APK.

Comece me perguntando se eu ja conectei o Render ao GitHub e se consigo ver o repositorio Paradise-RPG- no Render.
```

## Checklist rapido para voce marcar

```text
[ ] Render conectado ao GitHub
[ ] Repositorio Paradise-RPG- selecionado
[ ] Blueprint render.yaml encontrado
[ ] Web Service paradise-rpg-server criado
[ ] PostgreSQL paradise-rpg-db criado
[ ] DATABASE_URL configurado
[ ] DB_SSL=true configurado
[ ] JWT_SECRET configurado
[ ] Deploy terminou sem erro
[ ] /health abriu
[ ] /world/status abriu
[ ] URL HTTP copiada
[ ] URL WSS copiada
[ ] client/config/mmo_client_config.json atualizado
[ ] APK novo gerado e instalado
[ ] Duas contas testadas
[ ] Dois players aparecem no mesmo mapa
```

## Links oficiais uteis

- Render Web Services: https://render.com/docs/web-services
- Render PostgreSQL: https://render.com/docs/postgresql-creating-connecting
- Render Blueprint YAML: https://render.com/docs/blueprint-spec
