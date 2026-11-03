"""Geração de assets (sprites, chunks, UI) e voz com a API da OpenAI (ChatGPT).

Só usa a biblioteca padrão + Pillow. A chave vem de OPENAI_API_KEY (ambiente ou
tools/paradise_bot/.env) e nunca é gravada em log.
"""
from __future__ import annotations

import base64
import io
import json
import os
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from util import Cor, say

API = "https://api.openai.com/v1"


class ErroOpenAI(RuntimeError):
    pass


def _chave(nome_env: str) -> str:
    chave = os.environ.get(nome_env, "").strip()
    if not chave:
        raise ErroOpenAI(f"Defina {nome_env} (variável de ambiente ou tools/paradise_bot/.env).")
    return chave


def _post(caminho: str, chave: str, corpo: bytes, tipo: str, tentativas: int = 3, timeout: int = 300) -> bytes:
    for tentativa in range(1, tentativas + 1):
        req = urllib.request.Request(f"{API}{caminho}", data=corpo, method="POST",
                                     headers={"Authorization": f"Bearer {chave}", "Content-Type": tipo})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            msg = e.read().decode("utf-8", "replace")
            if e.code in (429, 500, 502, 503, 504) and tentativa < tentativas:
                time.sleep(5 * tentativa)
                continue
            raise ErroOpenAI(f"HTTP {e.code}: {msg[:600]}") from None
        except urllib.error.URLError as e:
            if tentativa < tentativas:
                time.sleep(5 * tentativa)
                continue
            raise ErroOpenAI(f"Falha de rede: {e}") from None
    raise ErroOpenAI("Falha após várias tentativas.")


def _multipart(campos: dict, arquivos: list[tuple[str, str, bytes]]) -> tuple[bytes, str]:
    fronteira = uuid.uuid4().hex
    partes = []
    for nome, valor in campos.items():
        partes.append(f"--{fronteira}\r\nContent-Disposition: form-data; name=\"{nome}\"\r\n\r\n{valor}\r\n".encode())
    for nome, arquivo, dados in arquivos:
        partes.append(
            f"--{fronteira}\r\nContent-Disposition: form-data; name=\"{nome}\"; filename=\"{arquivo}\"\r\n"
            f"Content-Type: image/png\r\n\r\n".encode() + dados + b"\r\n")
    partes.append(f"--{fronteira}--\r\n".encode())
    return b"".join(partes), f"multipart/form-data; boundary={fronteira}"


def _tamanho_api(largura: int, altura: int) -> str:
    proporcao = largura / max(1, altura)
    if proporcao >= 1.2:
        return "1536x1024"
    if proporcao <= 0.83:
        return "1024x1536"
    return "1024x1024"


def _remover_fundo_magenta(img):
    """Fallback quando o modelo não aceita fundo transparente: remove o magenta #FF00FF."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if r > 200 and b > 200 and g < 90:
                px[x, y] = (0, 0, 0, 0)
    return img


class GeradorAssets:
    def __init__(self, cfg: dict, repo: Path, pasta_staging: Path):
        self.cfg = cfg
        self.repo = repo
        self.staging = pasta_staging
        self.chave_env = cfg.get("openai_api_key_env", "OPENAI_API_KEY")

    # ---------- imagens ----------
    def _gerar_imagem(self, prompt: str, tamanho: str, transparente: bool, referencias: list[Path]) -> tuple[bytes, bool]:
        chave = _chave(self.chave_env)
        modelos = [self.cfg.get("openai_image_model", "gpt-image-2")]
        fallback = self.cfg.get("openai_image_model_fallback")
        if fallback and fallback not in modelos:
            modelos.append(fallback)
        ultimo_erro = None
        for modelo in modelos:
            for usar_transparencia in ([True, False] if transparente else [False]):
                p = prompt
                if transparente and not usar_transparencia:
                    p = p.replace("com fundo transparente", "com fundo de cor sólida magenta pura #FF00FF")
                    p += "\nFundo: cor sólida magenta pura #FF00FF, sem sombras no fundo (será recortado depois)."
                try:
                    if referencias:
                        campos = {"model": modelo, "prompt": p, "size": tamanho, "n": "1"}
                        if usar_transparencia:
                            campos["background"] = "transparent"
                        if self.cfg.get("openai_image_quality"):
                            campos["quality"] = self.cfg["openai_image_quality"]
                        arquivos = [("image[]", ref.name, ref.read_bytes()) for ref in referencias[:4]]
                        corpo, tipo = _multipart(campos, arquivos)
                        bruto = _post("/images/edits", chave, corpo, tipo)
                    else:
                        payload = {"model": modelo, "prompt": p, "size": tamanho, "n": 1}
                        if usar_transparencia:
                            payload["background"] = "transparent"
                        if self.cfg.get("openai_image_quality"):
                            payload["quality"] = self.cfg["openai_image_quality"]
                        bruto = _post("/images/generations", chave, json.dumps(payload).encode(), "application/json")
                    dados = json.loads(bruto)["data"][0]
                    if dados.get("b64_json"):
                        return base64.b64decode(dados["b64_json"]), (transparente and not usar_transparencia)
                    if dados.get("url"):
                        with urllib.request.urlopen(dados["url"], timeout=120) as r:
                            return r.read(), (transparente and not usar_transparencia)
                except ErroOpenAI as e:
                    ultimo_erro = e
                    texto = str(e).lower()
                    if "background" in texto or "transparen" in texto:
                        continue  # tenta sem transparência nativa
                    if "model" in texto and ("not found" in texto or "does not exist" in texto or "invalid" in texto):
                        break  # tenta o modelo reserva
                    raise
        raise ErroOpenAI(f"Não foi possível gerar a imagem: {ultimo_erro}")

    def gerar(self, asset: dict, numero: int) -> dict:
        from PIL import Image  # Pillow já é usado pelos geradores do projeto

        caminho = asset["caminho"].replace("\\", "/").lstrip("/")
        largura, altura = int(asset.get("largura", 64)), int(asset.get("altura", 64))
        frames = max(1, int(asset.get("frames", 1)))
        tipo = asset.get("tipo", "sprite")
        transparente = bool(asset.get("transparente", tipo not in ("chunk", "tile", "fundo")))
        largura_total = largura * frames

        estilo = self.cfg.get("estilo_arte", "")
        partes = [estilo, f"Asset para o jogo Paradise RPG ({tipo}): {asset.get('descricao', '')}"]
        if frames > 1:
            partes.append(f"Spritesheet horizontal com {frames} quadros de animação do MESMO personagem/objeto, "
                          f"lado a lado, mesmo tamanho e mesma posição em cada quadro, sem divisórias.")
        if tipo in ("chunk", "tile", "fundo"):
            partes.append("Vista de cima (top-down), preenchendo o quadro inteiro, sem moldura, sem bordas escuras, "
                          "bordas que possam continuar nos chunks vizinhos, sem texto, sem personagens.")
        elif transparente:
            partes.append("Objeto isolado e centralizado, com fundo transparente, sem chão, sem cenário, sem texto.")
        refs = []
        for r in asset.get("referencias", []) or []:
            p = (self.repo / r).resolve()
            if p.exists() and p.suffix.lower() == ".png" and self.repo.resolve() in p.parents:
                refs.append(p)
        if refs:
            partes.append("Use as imagens enviadas apenas como referência de estilo, paleta, escala e perspectiva; "
                          "crie um asset novo e coerente com elas.")
        prompt = "\n".join(x for x in partes if x)

        say(f"   🎨 ChatGPT gerando {caminho} ({largura_total}x{altura})…", Cor.AZUL)
        bruto, precisa_recorte = self._gerar_imagem(prompt, _tamanho_api(largura_total, altura), transparente, refs)
        img = Image.open(io.BytesIO(bruto))
        img = img.convert("RGBA") if transparente else img.convert("RGB")
        if precisa_recorte:
            img = _remover_fundo_magenta(img)
        img = img.resize((largura_total, altura), Image.LANCZOS)
        cores = int(self.cfg.get("reduzir_cores", 0) or 0)
        if cores and transparente:
            alfa = img.getchannel("A")
            img = img.convert("RGB").quantize(colors=cores, method=Image.Quantize.MEDIANCUT).convert("RGBA")
            img.putalpha(alfa.point(lambda a: 255 if a > 127 else 0))

        destino = self.repo / caminho
        if destino.exists():
            # Nunca sobrescreve um asset existente: deixa a versão nova no staging para o Claude decidir.
            destino = self.staging / f"{numero:03d}" / caminho
            situacao = "staging (já existia um arquivo no caminho original)"
        else:
            situacao = "criado no caminho final"
        destino.parent.mkdir(parents=True, exist_ok=True)
        img.save(destino)
        registro = self.staging / f"{numero:03d}" / "prompts" / (caminho.replace("/", "__") + ".txt")
        registro.parent.mkdir(parents=True, exist_ok=True)
        registro.write_text(prompt, encoding="utf-8")
        return {"caminho_pedido": caminho, "salvo_em": str(destino.relative_to(self.repo)).replace("\\", "/"),
                "situacao": situacao, "tamanho": f"{largura_total}x{altura}", "frames": frames}

    # ---------- voz ----------
    def narrar(self, texto: str, saida: Path) -> Path:
        chave = _chave(self.chave_env)
        payload = {
            "model": self.cfg.get("openai_tts_model", "gpt-4o-mini-tts"),
            "voice": self.cfg.get("openai_tts_voice", "onyx"),
            "input": texto,
            "response_format": "mp3",
            "instructions": self.cfg.get("openai_tts_instrucoes",
                                         "Fale em português do Brasil, tom animado de criador de conteúdo, ritmo rápido."),
        }
        try:
            bruto = _post("/audio/speech", chave, json.dumps(payload).encode(), "application/json")
        except ErroOpenAI as e:
            if "instructions" in str(e).lower():
                payload.pop("instructions")
                bruto = _post("/audio/speech", chave, json.dumps(payload).encode(), "application/json")
            else:
                raise
        saida.parent.mkdir(parents=True, exist_ok=True)
        saida.write_bytes(bruto)
        return saida
