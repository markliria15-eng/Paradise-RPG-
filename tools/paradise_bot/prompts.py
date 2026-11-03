"""Prompts enviados ao Claude Code."""
from __future__ import annotations

import json

REGRAS = """Você trabalha no Paradise RPG (Godot 4 + backend Node). Antes de tudo, leia CLAUDE.md,
HANDOFF_TO_CLAUDE.md e PROJECT_CONTEXT.md e siga TODAS as regras deles. Em especial:
- o working tree local é a fonte da verdade; não faça commit, push, reset, clean, checkout nem stash;
- mudanças pequenas, localizadas e reversíveis; nunca reescreva arquivos inteiros sem necessidade;
- não renomeie IDs, caminhos, eventos WebSocket, campos JSON, nodes ou autoloads;
- preserve saves locais, patches, banco e os mapas ativos (Eldoria e Floresta); não reative mapas em lote;
- nunca exiba ou grave segredos (.env, keystore, tokens).
Responda sempre em português do Brasil."""


def prompt_ideias(foco: str, historico: list[dict], qtd: int) -> str:
    aceitas = [h["titulo"] for h in historico if h.get("status") in ("aceita", "implementada")][-15:]
    recusadas = [h["titulo"] for h in historico if h.get("status") in ("recusada", "desfeita")][-15:]
    return f"""{REGRAS}

TAREFA: você é o diretor de jogabilidade do Paradise RPG. Analise o estado REAL do jogo
(código, dados, assets e git status/diff) e proponha {qtd} melhorias de JOGABILIDADE que
caibam em UMA atualização pequena cada (algumas horas de trabalho, testável).

Foco atual definido pelo dono do jogo: {foco}

Já aceitas/implementadas (não repita; construa em cima delas): {json.dumps(aceitas, ensure_ascii=False)}
Já recusadas (evite ideias parecidas): {json.dumps(recusadas, ensure_ascii=False)}

Critérios:
- O jogador precisa SENTIR a diferença (combate, controle, feedback visual/sonoro, progressão,
  recompensas, ritmo, clareza de objetivos, NPCs, quests, exploração dos mapas ativos).
- Considere as pendências do HANDOFF (ex.: quest tutorial_forest inacessível, boss em mapa vazio).
- Cada ideia deve dizer exatamente quais assets novos precisam ser desenhados pelo ChatGPT
  (sprites, chunks de mapa, ícones, UI, efeitos). Use caminhos que sigam as pastas existentes em assets/.
  Tamanhos reais em pixels do ARQUIVO (verifique os PNGs parecidos já existentes; por exemplo, os chunks
  da Floresta são arquivos pequenos ampliados no jogo — confira o tamanho real e a escala usada em
  scripts/main.gd antes de definir largura/altura). Em "referencias", liste 1 a 3 PNGs
  existentes que mostrem o estilo a seguir. Se a ideia não precisar de arte nova, deixe "assets": [].
- NÃO altere nada agora: só pesquise e proponha.

No final, responda com um bloco ```json exatamente neste formato:
{{"ideias": [{{
  "id": "slug-curto",
  "titulo": "título curto e chamativo",
  "resumo": "1-2 frases do que muda",
  "por_que_melhora": "por que deixa o jogo mais divertido",
  "como_jogador_percebe": "o que o jogador vê/sente",
  "mudancas": ["passo técnico 1", "passo técnico 2"],
  "arquivos_provaveis": ["scripts/player.gd"],
  "assets": [{{"caminho": "assets/...png", "tipo": "sprite|chunk|tile|ui|icone|efeito",
              "largura": 64, "altura": 64, "frames": 1, "transparente": true,
              "descricao": "descrição visual detalhada para o ChatGPT desenhar",
              "referencias": ["assets/...png"]}}],
  "risco": "baixo|medio|alto",
  "tamanho": "pequeno|medio|grande",
  "cena_video": "o que gravar no vídeo para mostrar a novidade (onde ir no jogo e o que fazer)",
  "gancho_video": "frase de gancho de até 10 palavras para o Reels/TikTok"
}}]}}"""


def prompt_implementar(ideia: dict, assets_gerados: list[dict], falhas_assets: list[str]) -> str:
    return f"""{REGRAS}

TAREFA: implemente no Paradise RPG a melhoria aprovada pelo dono do jogo:
{json.dumps(ideia, ensure_ascii=False, indent=2)}

Assets já desenhados pelo ChatGPT para esta atualização:
{json.dumps(assets_gerados, ensure_ascii=False, indent=2)}
{"Falhas na geração de assets (use placeholder simples ou assets existentes): " + json.dumps(falhas_assets, ensure_ascii=False) if falhas_assets else ""}

Como trabalhar:
1. Rode `git status --short` e leia os arquivos que vai mudar; procure consumidores com rg/Grep.
2. Integre os assets: se algum estiver em `.paradise_bot/assets/...` (staging), significa que já existia
   um arquivo no caminho original — decida se substitui (copie por cima) ou se salva com outro nome.
   Não apague assets antigos. Godot cria os .import sozinho ao abrir o projeto.
3. Faça a menor mudança que entregue a ideia completa e jogável.
4. Se mudar algo em data/ que esteja no manifesto de patches, avise no resumo (não rode build-patch).
5. Valide: parse dos JSON alterados, `node --check` em JS alterado, e revise a sintaxe GDScript.
6. Se o estado técnico mudou de verdade, atualize PROJECT_CONTEXT.md/HANDOFF_TO_CLAUDE.md de forma localizada.

Termine com um resumo curto em português: o que mudou, arquivos tocados, como testar no jogo
(passo a passo para o jogador) e riscos/pendências."""


def prompt_corrigir(problemas: list[str]) -> str:
    return ("A validação automática encontrou problemas na atualização que você acabou de fazer. "
            "Corrija com mudanças mínimas, sem desfazer a melhoria:\n\n" + "\n\n".join(problemas) +
            "\n\nTermine com um resumo curto do que corrigiu.")


def prompt_ajuste(pedido: str) -> str:
    return (f"O dono do jogo testou e pediu este ajuste na mesma atualização: \"{pedido}\". "
            "Faça a mudança mínima necessária, valide e termine com um resumo curto.")


def prompt_roteiro(ideia: dict, resumo_impl: str, numero_episodio: int, tem_antes: bool) -> str:
    return f"""Você escreve roteiros de vídeos curtos (Reels/TikTok, 30-45 s) da série
"estou criando um RPG só com IA" sobre o jogo Paradise RPG. Tudo em português do Brasil.

Episódio {numero_episodio}. Novidade desta atualização:
{json.dumps(ideia, ensure_ascii=False, indent=2)}

O que foi realmente implementado:
{resumo_impl[:3000]}

Vídeo disponível: {"clipe ANTES da mudança e clipe DEPOIS" if tem_antes else "apenas clipe DEPOIS da mudança"}.

Regras: gancho forte em até 2 s (nada de "olá pessoal"); frases curtas e faladas; narração de
90 a 120 palavras; 1 detalhe curioso de como a IA fez (ChatGPT desenhou a arte, Claude programou);
final com gancho para o próximo episódio + "segue pra ver o jogo ficar pronto". Não invente
recursos que não estão no resumo. Não use ferramentas, só responda.

Responda só com um bloco ```json:
{{"titulo": "título curto do episódio",
  "texto_capa": "até 5 palavras, impactante",
  "gancho_tela": "texto grande do topo nos 3 primeiros segundos (até 6 palavras)",
  "narracao": "texto completo da narração",
  "palavras_destaque": ["palavras-chave para pintar de amarelo nas legendas"],
  "legenda_post": "legenda do post com emojis",
  "hashtags": ["#gamedev", "#ia", "#indiegame", "#jogos", "#rpg"]}}"""
