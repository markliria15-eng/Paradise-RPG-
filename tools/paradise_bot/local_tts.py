"""Narração local em português com Piper e tempos de legenda."""
from __future__ import annotations

import re
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

from util import rodar


@dataclass
class ResultadoNarracao:
    caminho: Path
    duracao: float
    legendas: list[dict]


def _modelo(cfg: dict, repo: Path) -> tuple[Path, Path]:
    voz = cfg.get("piper_voice", "pt_BR-faber-medium")
    pasta = Path(cfg.get("piper_model_dir", ".paradise_bot/voices"))
    if not pasta.is_absolute():
        pasta = repo / pasta
    modelo = pasta / f"{voz}.onnx"
    configuracao = pasta / f"{voz}.onnx.json"
    if not modelo.exists() or not configuracao.exists():
        raise RuntimeError(
            f"Voz Piper ausente em {pasta}. Rode: py -m piper.download_voices "
            f"--download-dir \"{pasta}\" {voz}"
        )
    return modelo, configuracao


def _voz(cfg: dict, repo: Path):
    try:
        from piper.config import SynthesisConfig
        from piper.voice import PiperVoice
    except ImportError as erro:
        raise RuntimeError("Piper não instalado. Rode: py -m pip install piper-tts==1.8.0") from erro

    modelo, configuracao = _modelo(cfg, repo)
    voz = PiperVoice.load(modelo, config_path=configuracao)
    sintese = SynthesisConfig(
        length_scale=float(cfg.get("piper_length_scale", 0.92)),
        noise_scale=float(cfg.get("piper_noise_scale", 0.667)),
        noise_w_scale=float(cfg.get("piper_noise_w_scale", 0.8)),
        volume=float(cfg.get("piper_volume", 1.0)),
    )
    return voz, sintese


def _frases(texto: str) -> list[str]:
    texto = re.sub(r"\s+", " ", texto).strip()
    if not texto:
        return []
    frases = re.findall(r".+?(?:[.!?…:;]+(?:[\"'”’]+)?(?=\s|$)|$)", texto)
    return [frase.strip() for frase in frases if frase.strip()]


def _blocos(texto: str, tamanho: int) -> list[str]:
    palavras = texto.split()
    return [" ".join(palavras[i:i + tamanho]) for i in range(0, len(palavras), tamanho)]


def _legendas_da_frase(texto: str, inicio: float, duracao: float, tamanho: int) -> list[dict]:
    blocos = _blocos(texto, tamanho)
    if not blocos:
        return []
    pesos = [sum(max(1, len(re.sub(r"\W", "", palavra))) for palavra in bloco.split()) for bloco in blocos]
    peso_total = max(1, sum(pesos))
    legendas = []
    cursor = inicio
    for indice, bloco in enumerate(blocos):
        fim = inicio + duracao if indice == len(blocos) - 1 else cursor + duracao * pesos[indice] / peso_total
        legendas.append({"inicio": cursor, "fim": fim, "texto": bloco})
        cursor = fim
    return legendas


def _pausa(frase: str, cfg: dict) -> float:
    if frase.rstrip().endswith(("?", "!", ".", "…")):
        return float(cfg.get("piper_sentence_pause", 0.24))
    return float(cfg.get("piper_clause_pause", 0.14))


def narrar_piper(cfg: dict, repo: Path, texto: str, saida: Path) -> ResultadoNarracao:
    voz, sintese = _voz(cfg, repo)
    frases = _frases(texto)
    if not frases:
        raise RuntimeError("A narração está vazia.")

    amostras = bytearray()
    taxa = voz.config.sample_rate
    canais = 1
    largura = 2
    inicial = float(cfg.get("piper_initial_silence", 0.25))
    final = float(cfg.get("piper_final_silence", 0.55))
    amostras.extend(b"\x00" * round(inicial * taxa * canais * largura))
    cursor = inicial
    legendas = []
    tamanho = max(1, int(cfg.get("piper_words_per_caption", 3)))

    for frase in frases:
        dados = bytearray()
        for trecho in voz.synthesize(frase, syn_config=sintese):
            dados.extend(trecho.audio_int16_bytes)
        duracao = len(dados) / (taxa * canais * largura)
        amostras.extend(dados)
        legendas.extend(_legendas_da_frase(frase, cursor, duracao, tamanho))
        cursor += duracao
        pausa = _pausa(frase, cfg)
        amostras.extend(b"\x00" * round(pausa * taxa * canais * largura))
        cursor += pausa

    amostras.extend(b"\x00" * round(final * taxa * canais * largura))
    cursor += final
    saida.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(saida), "wb") as arquivo:
        arquivo.setnchannels(canais)
        arquivo.setsampwidth(largura)
        arquivo.setframerate(taxa)
        arquivo.writeframes(amostras)
    return ResultadoNarracao(saida, cursor, legendas)


def _tempo_ass(valor: str) -> float:
    horas, minutos, segundos = valor.strip().split(":")
    return int(horas) * 3600 + int(minutos) * 60 + float(segundos)


def _texto_ass(valor: str) -> str:
    return re.sub(r"\{[^}]*\}", "", valor).replace("\\N", " ").strip()


def _eventos_ass(caminho: Path) -> tuple[list[dict], float]:
    falas = []
    duracao_total = 0.0
    for linha in caminho.read_text(encoding="utf-8-sig").splitlines():
        if not linha.startswith("Dialogue:"):
            continue
        partes = linha.split(",", 9)
        if len(partes) != 10:
            continue
        camada = int(partes[0].split(":", 1)[1].strip())
        inicio, fim = _tempo_ass(partes[1]), _tempo_ass(partes[2])
        duracao_total = max(duracao_total, fim)
        if camada == 0:
            falas.append({"inicio": inicio, "fim": fim, "texto": _texto_ass(partes[9])})
    return falas, duracao_total


def _grupos_de_fala(falas: list[dict]) -> list[dict]:
    grupos = []
    atual = []
    for fala in falas:
        atual.append(fala)
        texto = fala["texto"].rstrip('"”’')
        if texto.endswith((".", "!", "?", "…", ":", ";")) or len(atual) >= 8:
            grupos.append(atual)
            atual = []
    if atual:
        grupos.append(atual)
    return [
        {
            "inicio": grupo[0]["inicio"],
            "fim": grupo[-1]["fim"],
            "texto": " ".join(item["texto"] for item in grupo),
        }
        for grupo in grupos
    ]


def _filtro_atempo(ritmo: float) -> str:
    fatores = []
    while ritmo > 2.0:
        fatores.append(2.0)
        ritmo /= 2.0
    while ritmo < 0.5:
        fatores.append(0.5)
        ritmo /= 0.5
    fatores.append(ritmo)
    return ",".join(f"atempo={fator:.8f}" for fator in fatores)


def narrar_sincronizado_com_ass(
    cfg: dict,
    repo: Path,
    legenda_ass: Path,
    saida: Path,
    ffmpeg: str,
) -> ResultadoNarracao:
    voz, sintese = _voz(cfg, repo)
    falas, duracao_total = _eventos_ass(legenda_ass)
    grupos = _grupos_de_fala(falas)
    if not grupos:
        raise RuntimeError(f"Nenhuma fala encontrada em {legenda_ass}.")

    taxa = voz.config.sample_rate
    largura = 2
    trilha = bytearray(round(duracao_total * taxa) * largura)
    with tempfile.TemporaryDirectory(prefix="paradise-tts-") as temporario:
        temporario = Path(temporario)
        for indice, grupo in enumerate(grupos):
            bruto = temporario / f"fala-{indice:03d}.wav"
            ajustado = temporario / f"fala-{indice:03d}-ajustada.wav"
            with wave.open(str(bruto), "wb") as arquivo:
                voz.synthesize_wav(grupo["texto"], arquivo, syn_config=sintese)
            with wave.open(str(bruto), "rb") as arquivo:
                duracao_bruta = arquivo.getnframes() / arquivo.getframerate()
            alvo = max(0.1, grupo["fim"] - grupo["inicio"])
            ritmo = max(0.01, duracao_bruta / alvo)
            filtro = f"{_filtro_atempo(ritmo)},apad,atrim=duration={alvo:.6f}"
            resultado = rodar([
                ffmpeg, "-y", "-i", str(bruto), "-af", filtro, "-ar", str(taxa), "-ac", "1",
                "-c:a", "pcm_s16le", str(ajustado),
            ], timeout=180)
            if resultado.returncode != 0:
                raise RuntimeError(f"ffmpeg não ajustou a fala {indice}: {resultado.stderr[-800:]}")
            with wave.open(str(ajustado), "rb") as arquivo:
                dados = arquivo.readframes(arquivo.getnframes())
            inicio = round(grupo["inicio"] * taxa) * largura
            limite = min(len(trilha), inicio + len(dados))
            trilha[inicio:limite] = dados[:limite - inicio]

    saida.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(saida), "wb") as arquivo:
        arquivo.setnchannels(1)
        arquivo.setsampwidth(largura)
        arquivo.setframerate(taxa)
        arquivo.writeframes(trilha)
    return ResultadoNarracao(saida, duracao_total, falas)
