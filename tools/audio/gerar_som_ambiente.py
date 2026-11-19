"""Gera os loops de som ambiente de cada mapa (sintetizados, sem arquivos de terceiros).

As camadas de cada mapa seguem a lista que o ChatGPT desenhou (data/game_rules.json,
"sons_ambiente"). Todo filtro e feito no dominio da frequencia sobre o loop inteiro e os
eventos (gaivotas, sinos, gotas) dao a volta no fim, entao o loop emenda sem corte.

uso: python tools/audio/gerar_som_ambiente.py [mapa ...]
Grava: assets/audio/ambiente/<mapa>.ogg (estereo, 22050 Hz, 40 s; precisa de ffmpeg)
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "ambiente"
SR = 22050
DUR = 40.0
N = int(SR * DUR)
T = np.arange(N) / SR
rng = np.random.default_rng(7)


# ---------- blocos ----------
def band(sig, lo, hi, tilt=0.0):
    """filtro passa-faixa suave (circular: o loop continua emendado)"""
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    spec = np.fft.rfft(sig)
    g = 1 / (1 + (lo / np.maximum(f, 1)) ** 4) / (1 + (f / hi) ** 4)
    if tilt:
        g = g * (np.maximum(f, 20) / 1000.0) ** tilt
    return np.fft.irfft(spec * g, len(sig))


def noise(lo, hi, tilt=0.0):
    return np.stack([norm(band(rng.standard_normal(N), lo, hi, tilt)) for _ in range(2)])


def norm(x):
    return x / (np.abs(x).max() + 1e-9)


def lfo(period_div, phase=0.0, depth=0.5):
    """oscilador lento com periodo DUR/period_div (fecha certinho no loop)"""
    return 1 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * period_div * T / DUR + phase))


def place(track, sound, t0, pan=0.0, gain=1.0):
    """soma um som estereo/mono no instante t0, dando a volta no fim do loop"""
    if sound.ndim == 1:
        left, right = np.sqrt(0.5 * (1 - pan)), np.sqrt(0.5 * (1 + pan))
        sound = np.stack([sound * left, sound * right])
    i0 = int(t0 * SR) % N
    idx = (np.arange(sound.shape[1]) + i0) % N
    np.add.at(track[0], idx, sound[0] * gain)
    np.add.at(track[1], idx, sound[1] * gain)


def reverb(track, secs=1.6, wet=0.35, lo=200, hi=5000):
    """reverberacao por convolucao circular com ruido decaindo"""
    out = np.empty_like(track)
    n = int(secs * SR)
    for c in range(2):
        ir = np.zeros(N)
        ir[:n] = rng.standard_normal(n) * np.exp(-6.9 * np.arange(n) / n)
        ir = band(ir, lo, hi)
        ir /= np.sqrt((ir ** 2).sum())
        rev = np.fft.irfft(np.fft.rfft(track[c]) * np.fft.rfft(ir), N)
        out[c] = track[c] * (1 - wet) + rev * wet
    return out


def tone(freqs, amps, dur, decay, attack=0.004):
    t = np.arange(int(dur * SR)) / SR
    s = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) for f, a in zip(freqs, amps))
    env = np.minimum(t / attack, 1) * np.exp(-t / decay)
    return s * env


def glide(f0, f1, dur, harm=(1, 0.5, 0.25), curve=1.0, vib=0.0):
    t = np.arange(int(dur * SR)) / SR
    x = (t / dur) ** curve
    f = f0 + (f1 - f0) * x + vib * np.sin(2 * np.pi * 28 * t) * f0 * 0.02
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm))
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.7
    return s * env


# ---------- sons ----------
def ondas(vol):
    bed = noise(60, 900, -0.3)
    hiss = noise(900, 5000)
    env = np.zeros(N)
    for t0 in np.arange(0, DUR, DUR / 6) + rng.uniform(0, 1.5, 6):
        i = (np.arange(int(6 * SR)) + int(t0 * SR)) % N
        t = np.arange(len(i)) / SR
        env[i] += np.minimum(t / 1.4, 1) ** 2 * np.exp(-np.maximum(t - 1.4, 0) / 1.6)
    env = 0.35 + env / env.max()
    foam = np.roll(env, int(0.5 * SR)) - 0.3
    return vol * (bed * env * 0.8 + hiss * np.clip(foam, 0, None) * 0.35)


def agua_cais(vol):
    s = noise(180, 1100)
    env = np.zeros(N)
    for t0 in np.cumsum(rng.uniform(0.6, 1.8, 60)):
        if t0 >= DUR:
            break
        i = (np.arange(int(0.7 * SR)) + int(t0 * SR)) % N
        t = np.arange(len(i)) / SR
        env[i] += np.sin(np.pi * t / 0.7) ** 2 * rng.uniform(0.4, 1)
    return vol * s * env * 0.8


def vento(vol, lo=150, hi=700):
    return vol * noise(lo, hi) * lfo(2, 0.3, 0.6) * lfo(3, 2.0, 0.4)


def gaivotas(vol):
    tr = np.zeros((2, N))
    for t0 in np.sort(rng.uniform(0, DUR, 7)):
        pan = rng.uniform(-0.8, 0.8)
        g = rng.uniform(0.5, 1)
        base = rng.uniform(1300, 1700)
        for k in range(rng.integers(1, 4)):
            call = glide(base * 1.25, base * 0.8, rng.uniform(0.28, 0.4), (1, 0.6, 0.35, 0.15), curve=0.7, vib=1)
            call += 0.08 * band(rng.standard_normal(len(call)), 1500, 4000) * np.abs(call)
            place(tr, call, t0 + k * 0.45, pan, g)
    return vol * reverb(tr, 1.0, 0.3)


def sino(vol, f=520, vezes=2, decay=3.5, lp=3000):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, vezes):
        s = tone([f, f * 2.0, f * 2.76, f * 5.4], [1, 0.5, 0.35, 0.12], decay * 1.6, decay)
        place(tr, band(s, 100, lp), t0, rng.uniform(-0.5, 0.5))
    return vol * reverb(tr, 2.2, 0.5)


def rangido(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 6):
        d = rng.uniform(0.5, 1.1)
        t = np.arange(int(d * SR)) / SR
        f = rng.uniform(70, 120) * (1 + 0.6 * t / d) * (1 + 0.05 * rng.standard_normal(len(t)).cumsum() / np.sqrt(len(t)))
        pulses = (np.sin(2 * np.pi * np.cumsum(f) / SR) > 0.97).astype(float)
        s = band(pulses, 300, 1800) * np.sin(np.pi * t / d)
        place(tr, s, t0, rng.uniform(-0.6, 0.6))
    return vol * norm(tr)


def conversas(vol, lo=250, hi=1400):
    tr = np.zeros((2, N))
    for _ in range(140):
        d = rng.uniform(0.12, 0.35)
        n = int(d * SR)
        f = rng.uniform(lo * 1.3, hi * 0.7)
        s = band(rng.standard_normal(n), f * 0.7, f * 1.4) * np.sin(np.pi * np.arange(n) / n)
        place(tr, s, rng.uniform(0, DUR), rng.uniform(-0.7, 0.7), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 1.2, 0.5)) * lfo(4, 1.0, 0.5)


def passaros(vol, alto=False):
    tr = np.zeros((2, N))
    for t0 in np.sort(rng.uniform(0, DUR, 16 if alto else 11)):
        pan = rng.uniform(-0.9, 0.9)
        f0 = rng.uniform(2800, 5200)
        kind = rng.integers(0, 3)
        for k in range(rng.integers(2, 7)):
            if kind == 0:
                s = glide(f0, f0 * 1.4, 0.07, (1, 0.15))
            elif kind == 1:
                s = glide(f0 * 1.3, f0 * 0.8, 0.11, (1, 0.2))
            else:
                s = glide(f0, f0 * 1.05, 0.05, (1,), vib=8)
            place(tr, s, t0 + k * rng.uniform(0.09, 0.16), pan, rng.uniform(0.5, 1))
    return vol * norm(reverb(tr, 0.8, 0.25, 500, 8000))


def fonte(vol):
    bed = noise(700, 6500) * lfo(8, 0, 0.12)
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 260):
        s = glide(rng.uniform(1200, 2600), rng.uniform(2600, 4200), 0.02, (1,))
        place(tr, s, t0, rng.uniform(-0.4, 0.4), rng.uniform(0.1, 0.4))
    return vol * (bed * 0.7 + tr * 0.6)


def martelo(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 4):
        for k in range(3):
            s = tone([1100, 2650, 4100], [1, 0.6, 0.3], 0.5, 0.12, 0.001)
            place(tr, band(s, 200, 2500), t0 + k * 0.7, -0.3)
    return vol * reverb(tr, 1.4, 0.5)


def insetos(vol):
    tr = np.zeros((2, N))
    gate = (np.sin(2 * np.pi * 30 * T) > 0.2).astype(float) * (np.sin(2 * np.pi * (DUR / 1.6) * T / DUR) > 0.3)
    car = np.sin(2 * np.pi * 4600 * T)
    tr[0] = car * gate
    tr[1] = np.roll(car * gate, int(0.31 * SR)) * 0.7
    return vol * tr * 0.4 * lfo(5, 0.2, 0.7)


def folhas(vol):
    return vol * noise(1500, 7000) * lfo(2, 1.2, 0.8) ** 2 * 0.6


def riacho(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 600):
        s = glide(rng.uniform(600, 1300), rng.uniform(1300, 2200), 0.03, (1,))
        place(tr, s, t0, rng.uniform(-1, -0.2), rng.uniform(0.1, 0.3))
    return vol * (noise(300, 3000) * 0.4 + tr * 0.6)


def grunhidos(vol, f=90):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 3):
        d = rng.uniform(0.4, 0.7)
        t = np.arange(int(d * SR)) / SR
        saw = ((t * f * (1 + 0.2 * np.sin(2 * np.pi * 6 * t))) % 1) * 2 - 1
        s = band(saw * (1 + 0.5 * rng.standard_normal(len(t))), 100, 900) * np.sin(np.pi * t / d)
        place(tr, s, t0, rng.uniform(-0.8, 0.8))
    return vol * norm(reverb(tr, 1.5, 0.6))


def uivo(vol):
    tr = np.zeros((2, N))
    t0 = rng.uniform(0, DUR)
    s = glide(420, 620, 2.6, (1, 0.3, 0.1), curve=0.5, vib=1)
    s = s * np.sin(np.pi * np.arange(len(s)) / len(s))
    place(tr, s, t0, 0.6)
    return vol * norm(reverb(tr, 2.5, 0.7))


def gotas(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 34):
        f = rng.uniform(900, 2400)
        s = glide(f, f * 1.8, 0.05, (1, 0.1))
        place(tr, s, t0, rng.uniform(-0.9, 0.9), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 2.8, 0.55, 300, 6000))


def drone(vol, freqs=(55, 82.5, 110)):
    tr = np.zeros((2, N))
    for c in range(2):
        tr[c] = sum(np.sin(2 * np.pi * (f + 0.15 * c) * T) / (k + 1) for k, f in enumerate(freqs))
    return vol * norm(tr) * lfo(3, 0.5, 0.4)


def morcegos(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 10):
        for k in range(rng.integers(2, 5)):
            s = glide(rng.uniform(5500, 7500), rng.uniform(3500, 4500), 0.03, (1,))
            place(tr, s, t0 + k * 0.06, rng.uniform(-1, 1), rng.uniform(0.3, 0.8))
    return vol * norm(reverb(tr, 1.8, 0.5))


def asas(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 5):
        flap = np.zeros(int(0.9 * SR))
        for k in range(8):
            i = int(k * 0.11 * SR)
            flap[i:i + 600] += rng.standard_normal(600) * np.hanning(600)
        place(tr, band(flap, 200, 1500), t0, rng.uniform(-1, 1))
    return vol * norm(reverb(tr, 1.5, 0.5))


def pedras(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 2):
        for k in range(rng.integers(4, 9)):
            n = int(0.04 * SR)
            s = band(rng.standard_normal(n), 300, 3000) * np.exp(-np.arange(n) / (0.01 * SR))
            place(tr, s, t0 + k * rng.uniform(0.05, 0.2), rng.uniform(-1, 1), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 2.5, 0.6))


def zumbido_magico(vol):
    tr = np.zeros((2, N))
    for c in range(2):
        tr[c] = sum(np.sin(2 * np.pi * f * (1 + 0.002 * c) * T) * a for f, a in ((110, 1), (164.8, 0.7), (220, 0.5), (277.2, 0.35), (329.6, 0.25)))
    return vol * norm(tr) * lfo(4, 0, 0.5) * lfo(5, 1, 0.3)


def cristais(vol):
    tr = np.zeros((2, N))
    notes = [880, 1046.5, 1318.5, 1568, 1760, 2093]
    for t0 in rng.uniform(0, DUR, 22):
        f = notes[rng.integers(len(notes))]
        place(tr, tone([f, f * 2.01, f * 3.03], [1, 0.3, 0.1], 2.5, 0.9, 0.02), t0, rng.uniform(-0.9, 0.9), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 3.0, 0.6, 400, 8000))


def sussurros(vol):
    tr = np.zeros((2, N))
    for _ in range(40):
        d = rng.uniform(0.3, 0.9)
        n = int(d * SR)
        f = rng.uniform(1500, 3500)
        s = band(rng.standard_normal(n), f * 0.8, f * 1.3) * np.sin(np.pi * np.arange(n) / n) ** 2
        place(tr, s, rng.uniform(0, DUR), rng.uniform(-1, 1), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 2.0, 0.6)) * lfo(3, 2, 0.6)


def descargas(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 4):
        n = int(0.35 * SR)
        crack = rng.standard_normal(n) * (rng.random(n) > 0.85) * np.exp(-np.arange(n) / (0.12 * SR))
        place(tr, band(crack, 1500, 8000), t0, rng.uniform(-0.8, 0.8))
    return vol * norm(reverb(tr, 1.5, 0.5))


def sapos(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 34):
        f = rng.uniform(170, 330)
        pulsos = rng.integers(2, 6)
        dur = 0.07
        coaxo = np.concatenate([np.concatenate([tone([f, f * 2, f * 3.1], [1, 0.6, 0.25], dur, dur * 0.6),
                                                np.zeros(int(0.035 * SR))]) for _ in range(pulsos)])
        place(tr, coaxo, t0, rng.uniform(-0.9, 0.9), rng.uniform(0.35, 1))
    return vol * norm(reverb(tr, 1.4, 0.35, 120, 2500))


def bolhas(vol):
    tr = np.zeros((2, N))
    for t0 in rng.uniform(0, DUR, 70):
        f0 = rng.uniform(140, 260)
        place(tr, glide(f0, f0 * rng.uniform(1.8, 2.6), rng.uniform(0.05, 0.12), (1, 0.3)), t0, rng.uniform(-0.8, 0.8), rng.uniform(0.3, 1))
    return vol * norm(reverb(tr, 0.8, 0.25, 100, 1800))


MAPAS = {
    "swamp_almas": lambda: [vento(0.18, 90, 450), insetos(0.22), sapos(0.40), bolhas(0.22), riacho(0.06), drone(0.08, (49, 73.5, 98)),
                            sussurros(0.06)],
    "city_valdoria": lambda: [ondas(0.55), agua_cais(0.35), gaivotas(0.42), vento(0.25, 200, 900),
                              rangido(0.14), sino(0.22, 610, 2), conversas(0.16), martelo(0.10), sino(0.10, 98, 1, 5, 600)],
    "city_eldoria": lambda: [fonte(0.42), passaros(0.38), vento(0.22), conversas(0.18), martelo(0.12), sino(0.25, 392, 1, 5)],
    "forest_boars": lambda: [vento(0.38, 180, 900), folhas(0.18), passaros(0.42, True), insetos(0.10), riacho(0.18),
                             grunhidos(0.14), uivo(0.12)],
    "bat_cave": lambda: [gotas(0.55), vento(0.22, 60, 300), drone(0.16), morcegos(0.22), asas(0.14), pedras(0.12), riacho(0.08)],
    "arcane_ruins": lambda: [vento(0.30, 120, 600), zumbido_magico(0.22), cristais(0.30), sussurros(0.14), descargas(0.12)],
}


def write(name, layers):
    mix = sum(layers)
    mix = mix / (np.abs(mix).max() + 1e-9) * 0.8
    pcm = (mix.T * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = Path(tmp) / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "3", str(out)], check=True)
    print(name, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name in sys.argv[1:] or list(MAPAS):
        rng = np.random.default_rng(sum(map(ord, name)))
        write(name, MAPAS[name]())
