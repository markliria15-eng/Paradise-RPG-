"""Gera os efeitos sonoros curtos do jogo (sintetizados, sem arquivos de terceiros).

uso: python tools/audio/gerar_efeitos.py
Grava: assets/audio/sfx/<nome>.wav (mono, 22050 Hz, 16 bits)
Nomes usados pelo AudioManager.play_sfx(): golpe, dano, moeda, item, nivel, missao_aceita,
missao_concluida, clique, abrir, casco, chefe_aviso, vitoria, erro.
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx"
SR = 22050
rng = np.random.default_rng(11)


def t(d):
    return np.arange(int(d * SR)) / SR


def env(n, a=0.005, d=0.2):
    x = np.arange(n) / SR
    return np.minimum(x / a, 1) * np.exp(-x / d)


def band(sig, lo, hi):
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    g = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(sig) * g, len(sig))


def tone(f, d, decay=0.2, harm=(1, 0.3, 0.1), a=0.004):
    x = t(d)
    s = sum(h * np.sin(2 * np.pi * f * (k + 1) * x) for k, h in enumerate(harm))
    return s * env(len(x), a, decay)


def glide(f0, f1, d, harm=(1, 0.3)):
    x = t(d)
    f = f0 + (f1 - f0) * x / d
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sum(h * np.sin(ph * (k + 1)) for k, h in enumerate(harm)) * np.sin(np.pi * x / d)


def cat(*parts, gap=0.0):
    out = []
    for p in parts:
        out += [p, np.zeros(int(gap * SR))]
    return np.concatenate(out)


def mix(a, b, at=0.0):
    i = int(at * SR)
    n = max(len(a), i + len(b))
    o = np.zeros(n)
    o[: len(a)] += a
    o[i: i + len(b)] += b
    return o


def norm(x, peak=0.85):
    return x / (np.abs(x).max() + 1e-9) * peak


SFX = {
    # espadada: chiado que desce + baque grave
    "golpe": lambda: mix(band(rng.standard_normal(int(0.16 * SR)), 900, 6000) * np.linspace(1, 0, int(0.16 * SR)) ** 2 * 0.7,
                         tone(110, 0.18, 0.06, (1, 0.5)) * 0.8, 0.05),
    "dano": lambda: mix(band(rng.standard_normal(int(0.2 * SR)), 150, 1800) * env(int(0.2 * SR), 0.002, 0.05),
                        glide(320, 140, 0.16, (1, 0.4)) * 0.6),
    "moeda": lambda: cat(tone(1568, 0.07, 0.05, (1, 0.4, 0.2)), tone(2093, 0.25, 0.12, (1, 0.4, 0.2))),
    "item": lambda: cat(tone(880, 0.07, 0.06), tone(1175, 0.18, 0.1)),
    "nivel": lambda: cat(*[tone(f, 0.11, 0.12, (1, 0.5, 0.25)) for f in (523, 659, 784)], tone(1047, 0.6, 0.35, (1, 0.5, 0.25))),
    "missao_aceita": lambda: cat(tone(659, 0.1, 0.1), tone(988, 0.3, 0.2)),
    "missao_concluida": lambda: cat(tone(784, 0.1, 0.1, (1, 0.5)), tone(988, 0.1, 0.1, (1, 0.5)),
                                    tone(1175, 0.1, 0.1, (1, 0.5)), tone(1568, 0.55, 0.3, (1, 0.5, 0.2))),
    "clique": lambda: tone(1400, 0.04, 0.012, (1,)) * 0.7,
    "abrir": lambda: glide(500, 900, 0.09, (1, 0.2)) * 0.6,
    # casco: dois toques secos de madeira
    "casco": lambda: cat(band(rng.standard_normal(int(0.05 * SR)), 300, 2200) * env(int(0.05 * SR), 0.001, 0.012),
                         band(rng.standard_normal(int(0.05 * SR)), 250, 1800) * env(int(0.05 * SR), 0.001, 0.012) * 0.7, gap=0.07),
    # aviso de golpe de chefe: rugido grave subindo
    "chefe_aviso": lambda: (glide(70, 120, 0.55, (1, 0.6, 0.4, 0.2)) + band(rng.standard_normal(int(0.55 * SR)), 80, 600) * 0.5)
                           * np.sin(np.pi * t(0.55) / 0.55),
    "vitoria": lambda: cat(*[tone(f, 0.14, 0.14, (1, 0.6, 0.3)) for f in (392, 523, 659)], tone(784, 0.9, 0.5, (1, 0.6, 0.3))),
    "erro": lambda: cat(tone(220, 0.09, 0.06, (1, 0.6)), tone(165, 0.16, 0.08, (1, 0.6))),
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SFX.items():
        x = norm(fn())
        x = np.concatenate([x, np.zeros(int(0.02 * SR))])
        with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype("<i2").tobytes())
        print(name, round(len(x) / SR, 2), "s")
