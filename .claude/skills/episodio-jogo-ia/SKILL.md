---
name: episodio-jogo-ia
description: Monta, valida e prepara episódios verticais do Paradise RPG com clipes do jogo, voz local, legendas, capa e texto de publicação.
---

# Episódios do Paradise RPG

Trabalhe no repositório atual e preserve os sistemas, clipes e edições existentes. Não recrie episódios ou assets que já estejam prontos sem verificar seus consumidores e arquivos de origem.

## Montagem

- Use `tools/paradise_bot/video.py` para episódios novos. A voz padrão é o Piper local `pt_BR-faber-medium`; a OpenAI é apenas fallback opcional.
- Use `py tools/paradise_bot/remontar_episodio.py <números>` para adicionar voz local a episódios existentes que tenham `episodio-NN-sem-voz.mp4`, `legendas.ass` e `capa.jpg`.
- Mantenha as saídas em `.paradise_bot/videos/episodio-NN/`: vídeo final, `capa.jpg`, `post.txt`, narração e metadados.
- Preserve a sincronização com pausas reais. Para episódios antigos, ajuste frases às janelas do arquivo ASS; para episódios novos, use os tempos retornados por `local_tts.py`.

## Verificação

- Confirme vídeo vertical 1080×1920, codec H.264, áudio AAC, capa legível e texto de publicação presente.
- Verifique se a duração da narração cobre as legendas sem cortar o final.
- Não exponha nem copie chaves de `.env`. A voz local não depende de chave.

## Publicação

Prepare o vídeo, a capa e o texto, mas só publique ou envie a redes sociais depois de uma aprovação explícita do usuário para aquele episódio.
