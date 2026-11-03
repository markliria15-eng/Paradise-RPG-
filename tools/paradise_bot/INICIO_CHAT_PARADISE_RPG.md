# Início do chat "Paradise RPG"

Cole a mensagem abaixo como PRIMEIRA mensagem da conversa nova, com a pasta do jogo
adicionada ao chat ("+" → "Adicionar pasta" →
`C:\Users\markl\Documents\Codex\2026-05-27\1-ideia-central-do-jogo-o`).

---

Este chat é dedicado ao **Paradise RPG**, meu RPG 2D top-down em Godot 4 com backend Node/PostgreSQL,
que estou criando só com IA e mostrando numa série de vídeos ("estou criando um jogo só com IA").

**Onde está tudo**
- Pasta do jogo (fonte da verdade, tem centenas de arquivos que não estão no GitHub):
  `C:\Users\markl\Documents\Codex\2026-05-27\1-ideia-central-do-jogo-o`
- GitHub: `markliria15-eng/Paradise-RPG-` (ramo `main` = v0.1.16 antigo; ramo `paradise-bot` = o bot).

**Antes de qualquer coisa**, leia na pasta do jogo, nesta ordem: `CLAUDE.md`, `HANDOFF_TO_CLAUDE.md`,
`PROJECT_CONTEXT.md` e `tools/paradise_bot/README.md`. Siga as regras do CLAUDE.md
(mudanças pequenas e reversíveis, nada de commit/push/reset/clean sem eu pedir, não exibir segredos,
mapas ativos só Eldoria e Floresta, reconstrução mapa por mapa).

**Paradise Bot** (`tools/paradise_bot/`, abre com `iniciar_bot.bat`)
- Eu digito CONTINUAR → o Claude Code propõe 3 melhorias de jogabilidade → eu escolho o número.
- O ChatGPT (API OpenAI, chave em `tools/paradise_bot/.env`) desenha sprites/chunks/UI;
  o Claude Code implementa; o bot valida (JSON, JS, Godot 4.6.3 headless em modo offline) e
  manda corrigir; eu aceito (A), testo (T), desfaço (D) ou peço ajuste.
- Cada atualização aceita vira um episódio: grava ANTES/DEPOIS do jogo em modo offline
  (`--offline-test`, `PARADISE_MMO_ENV=local`), roteiro, voz OpenAI TTS, legendas, vídeo 1080×1920,
  capa e legenda do post em `.paradise_bot/videos/episodio-NN/`.
- Snapshots de segurança em `refs/paradise-bot/*`; tudo do bot fica em `.paradise_bot/` (ignorado no Git).

**Estado atual (2026-10-26)**
- Jogo testado no Godot 4.6.3 pelo `TESTAR_JOGO_OFFLINE.bat` (entra direto no gameplay, sem login).
- Render/backend online com HTTP 503 — fase atual é só offline.
- Pendências conhecidas: quest `tutorial_forest` inacessível; loja inacessível (Eldoria sem NPCs);
  boss automático em `arcane_ruins` (mapa vazio); `/health` depende do banco; keystore Android
  rastreado no Git (tratar como exposto antes de publicar).

**O que eu quero deste chat**
1. Me ajudar a rodar o Paradise Bot e evoluir a jogabilidade, uma atualização por vez.
2. Montar e revisar os episódios de vídeo (pode usar a skill `episodio-jogo-ia`; publicar no
   Instagram só com a minha aprovação explícita).
3. Ajustar o próprio bot quando algo não funcionar.

Comece confirmando que leu os documentos e me diga, em poucas linhas, o estado do jogo e a
primeira melhoria que você recomenda.
