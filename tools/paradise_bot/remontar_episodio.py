"""Remonta episódios existentes com a voz Piper local sincronizada ao ASS."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from local_tts import narrar_sincronizado_com_ass
from util import achar_executavel, carregar_json, rodar, salvar_json


BOT_DIR = Path(__file__).resolve().parent
REPO = BOT_DIR.parents[1]


def remontar(numero: int, cfg: dict) -> Path:
    pasta = REPO / ".paradise_bot" / "videos" / f"episodio-{numero:02d}"
    video_sem_voz = pasta / f"episodio-{numero:02d}-sem-voz.mp4"
    legenda = pasta / "legendas.ass"
    capa = pasta / "capa.jpg"
    if not video_sem_voz.exists():
        raise RuntimeError(f"Vídeo sem voz não encontrado: {video_sem_voz}")
    if not legenda.exists():
        raise RuntimeError(f"Legenda não encontrada: {legenda}")
    if not capa.exists():
        raise RuntimeError(f"Capa não encontrada: {capa}")

    ffmpeg = achar_executavel(cfg.get("ffmpeg", "ffmpeg"), REPO)
    if not ffmpeg:
        raise RuntimeError("ffmpeg não encontrado.")

    narracao = pasta / "narracao.wav"
    resultado = narrar_sincronizado_com_ass(cfg, REPO, legenda, narracao, ffmpeg)
    final = pasta / f"episodio-{numero:02d}.mp4"
    processo = rodar([
        ffmpeg, "-y", "-i", str(video_sem_voz), "-i", str(narracao),
        "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart", str(final),
    ], timeout=1200)
    if processo.returncode != 0:
        raise RuntimeError(f"ffmpeg falhou ao montar o episódio {numero}: {processo.stderr[-1200:]}")
    salvar_json(pasta / "narracao-local.json", {
        "provider": "piper",
        "voice": cfg.get("piper_voice", "pt_BR-faber-medium"),
        "duration_seconds": round(resultado.duracao, 3),
        "synced_to": legenda.name,
        "video": final.name,
        "cover": capa.name,
    })
    return final


def main() -> int:
    parser = argparse.ArgumentParser(description="Remonta episódios existentes com voz Piper local.")
    parser.add_argument("episodios", nargs="+", type=int, help="Números dos episódios, por exemplo: 1 2")
    args = parser.parse_args()
    cfg = carregar_json(BOT_DIR / "config.json", carregar_json(BOT_DIR / "config.example.json", {}))
    for numero in args.episodios:
        print(f"Remontando episódio {numero:02d} com voz local...", flush=True)
        final = remontar(numero, cfg)
        print(f"Pronto: {final}", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as erro:
        print(f"Erro: {erro}", file=sys.stderr)
        raise SystemExit(1)
