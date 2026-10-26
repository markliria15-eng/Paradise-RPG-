# 🌴 Paradise Bot — melhorias contínuas do Paradise RPG

Você só digita **CONTINUAR**. O bot:

1. **Claude Code** lê o jogo (código, dados, assets, CLAUDE.md/HANDOFF/PROJECT_CONTEXT) e traz 3 ideias de jogabilidade.
2. Você escolhe **1, 2 ou 3** (ou **N** para outras ideias).
3. O **bot de vídeos** já abre o episódio e grava o clipe **ANTES**.
4. O **ChatGPT** (API OpenAI) desenha os sprites, chunks, ícones e UI que a ideia precisa.
5. O **Claude Code** implementa, o bot valida (JSON, JS, Godot headless) e manda corrigir se quebrou.
6. Você revisa: **A** aceita · **T** testa no Godot · **D** desfaz · ou escreve um ajuste (“deixa o dano mais forte”).
7. Ao aceitar: grava o clipe **DEPOIS** e monta o episódio em segundo plano (roteiro, voz, legendas, capa e post) enquanto você já pede a próxima com **CONTINUAR**.

## Instalação (uma vez, no Windows)

1. Copie a pasta `tools/paradise_bot/` para dentro da pasta do jogo (a mesma do `project.godot`).
2. Tenha instalados: **Python 3.10+** com Pillow (`py -m pip install pillow`), **Claude Code** (`npm install -g @anthropic-ai/claude-code`, depois rode `claude` uma vez para entrar na conta), **Git** e **ffmpeg** (`winget install Gyan.FFmpeg`).
3. Crie `tools/paradise_bot/.env` com a sua chave da OpenAI (o `.gitignore` do projeto já ignora `.env`):
   ```
   OPENAI_API_KEY=sk-...
   ```
4. (Opcional) Copie `config.example.json` para `config.json` e ajuste: caminho do Godot, foco das ideias, voz, modelo de imagem, tempo de gravação.
5. Dê dois cliques em `tools/paradise_bot/iniciar_bot.bat` e digite `CONTINUAR`.

## Comandos

| Comando | O que faz |
|---|---|
| `CONTINUAR` | Busca ideias novas ou mostra as pendentes |
| `1`, `2`, `3` | Aceita a ideia e começa a atualização |
| `N` | Descarta a rodada e pede outras ideias |
| `IDEIA <texto>` | Implementa uma ideia sua |
| `FOCO <texto>` | Direciona as próximas ideias (ex.: `FOCO chefões e drops raros`) |
| `DESFAZER` | Reverte a última atualização |
| `VIDEOS` / `VIDEO <n>` | Status dos episódios / remonta o episódio n |
| `STATUS` | Histórico de ideias e custo do Claude |
| `SAIR` | Encerra (espera os vídeos terminarem) |

## Segurança (segue o CLAUDE.md do projeto)

- Antes de cada atualização o bot tira um **snapshot completo** do working tree (inclusive arquivos não rastreados) num índice Git temporário, guardado em `refs/paradise-bot/…`. Ele não mexe no seu índice, HEAD nem nos arquivos. `D`/`DESFAZER` restaura **só** os arquivos que a atualização mudou.
- O Claude Code roda com ferramentas limitadas: pode ler, editar e rodar validações, mas **commit, push, reset, clean, checkout, stash, restore, npm install e build-patch são bloqueados**.
- O ChatGPT **nunca sobrescreve** um asset existente: se o caminho já existe, a versão nova vai para `.paradise_bot/assets/` e o Claude decide.
- Commit só acontece se você responder **s** na pergunta, e só com os arquivos daquela atualização. Push nunca.
- Tudo do bot (estado, logs, vídeos, prompts das artes) fica em `.paradise_bot/`, que se ignora sozinho no Git.

## Vídeos

Ficam em `.paradise_bot/videos/episodio-NN/`: `episodio-NN.mp4` (1080×1920), `capa.jpg`, `post.txt` (legenda + hashtags), `roteiro.json`, clipes `antes.mp4`/`depois.mp4`.

- `gravacao: "manual"` (padrão): o bot abre o jogo, diz o que mostrar, você aperta ENTER e joga por `segundos_gravacao`.
- `gravacao: "auto"`: grava sem esperar (mostra só o que estiver na tela). `"desligada"`: sem clipes.
- Voz: OpenAI TTS (`openai_tts_voice`). Sem chave, o vídeo sai só com legendas.
- Para publicar no Instagram com a sua conta conectada, use a skill **episodio-jogo-ia** no Claude: ela pega o vídeo e a legenda e só publica com a sua aprovação.

## Custos

Cada rodada de ideias e cada implementação gastam uso do Claude Code (o `STATUS` mostra o custo da sessão). Cada asset é uma geração de imagem da OpenAI e cada episódio uma narração TTS.
