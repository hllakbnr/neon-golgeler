#!/usr/bin/env python3
"""Radyo istasyonları için prosedürel müzik bestecisi (telifsiz, oyuna özel).
Her istasyon için 3 şarkı bestelenir (akor yürüyüşü, bas, davul, melodi tohumla rastgele),
art arda eklenir ve tek bir döngü dosyası olarak yazılır: assets/music/<istasyon>.ogg
Gereken: numpy, scipy; ogg için ffmpeg (yoksa wav yazılır).
"""
import os, subprocess, sys
import numpy as np
from scipy.signal import lfilter

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'music')


# ------------------------------------------------------------------ temel sesler
def t_(d):
    return np.arange(int(d * SR)) / SR


def env(n, a=0.005, d=0.3, s=0.0, r=0.05, hold=None):
    """ADSR zarfı (n örnek)."""
    t = np.arange(n) / SR
    e = np.ones(n)
    a = max(a, 1e-4)
    e = np.minimum(1.0, t / a)
    dec = s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4))
    e = np.where(t > a, dec, e)
    if r > 0:
        rel = np.clip((t[-1] - t) / r, 0, 1)
        e *= rel
    return e


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def lowpass(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x, fc):
    return x - lowpass(x, fc)


def saw(f, d, det=0.0):
    t = t_(d)
    out = 2 * ((t * f) % 1.0) - 1
    if det:
        out = 0.5 * out + 0.5 * (2 * ((t * f * (1 + det)) % 1.0) - 1)
    return out


def square(f, d, pw=0.5):
    t = t_(d)
    return np.where((t * f) % 1.0 < pw, 1.0, -1.0)


def sine(f, d):
    return np.sin(2 * np.pi * f * t_(d))


def noise(d, rng):
    return rng.uniform(-1, 1, int(d * SR))


def pluck(f, d, rng, bright=0.5, decay=0.996):
    """Karplus-Strong telli çalgı (koto / saz / gitar)."""
    n = int(d * SR)
    N = max(2, int(SR / f))
    x = np.zeros(n)
    burst = rng.uniform(-1, 1, N)
    burst = lowpass(burst, 1500 + 6000 * bright)
    x[:N] = burst
    b = [1.0]
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -decay * 0.5
    a[N + 1] = -decay * 0.5
    y = lfilter(b, a, x)
    return y * env(n, 0.001, d * 0.6, 0.0, 0.05)


def kick(rng, d=0.4):
    t = t_(d)
    f = 45 + 80 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * 1.1 + noise(d, rng) * np.exp(-t * 120) * 0.15


def snare(rng, d=0.25, tone=190, gated=False):
    t = t_(d)
    nz = highpass(noise(d, rng), 900)
    body = np.sin(2 * np.pi * tone * t) * np.exp(-t * 25)
    dec = 9 if gated else 22
    e = np.exp(-t * dec)
    if gated:
        e = np.where(t < d * 0.75, np.maximum(e, 0.35), e * 0.2)
    return (nz * 0.7 + body * 0.5) * e


def hat(rng, d=0.06, open_=False):
    t = t_(0.3 if open_ else d)
    return highpass(noise(len(t) / SR, rng), 6000) * np.exp(-t * (12 if open_ else 70)) * 0.5


def clap(rng):
    t = t_(0.2)
    nz = highpass(noise(0.2, rng), 1200)
    e = np.zeros_like(t)
    for o in (0, 0.012, 0.024):
        e += np.where(t >= o, np.exp(-(t - o) * 60), 0)
    return nz * e * 0.6


def taiko(rng):
    t = t_(0.8)
    f = 70 + 40 * np.exp(-t * 15)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5) + lowpass(noise(0.8, rng), 400) * np.exp(-t * 20) * 0.5


def darbuka(rng, kind):
    t = t_(0.35)
    if kind == 'D':
        f = 95 + 30 * np.exp(-t * 25)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.9
    return (np.sin(2 * np.pi * 620 * t) * 0.4 + highpass(noise(0.35, rng), 2500) * 0.6) * np.exp(-t * 45) * 0.7


def pad(freqs, d, bright=1200, det=0.006):
    out = np.zeros(int(d * SR))
    for f in freqs:
        out += saw(f, d, det)
    out = lowpass(out / max(1, len(freqs)), bright)
    return out * env(len(out), d * 0.25, d, 1.0, d * 0.3)


def piano(f, d):
    t = t_(d)
    out = np.zeros_like(t)
    for h, amp in ((1, 1.0), (2, 0.45), (3, 0.25), (4, 0.12), (5, 0.06)):
        out += amp * np.sin(2 * np.pi * f * h * t) * np.exp(-t * (2.2 + h * 0.9))
    return out * np.minimum(1, t / 0.004) * 0.5


def rhodes(f, d):
    t = t_(d)
    m = np.sin(2 * np.pi * f * 1.0 * t) * 1.2 * np.exp(-t * 3)
    return np.sin(2 * np.pi * f * t + m) * np.exp(-t * 1.6) * np.minimum(1, t / 0.006) * 0.45


def flute(f, d, rng, vib=5.0):
    t = t_(d)
    fm = f * (1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.minimum(1, t / 0.4))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    tone = np.sin(ph) + 0.15 * np.sin(2 * ph)
    breath = lowpass(highpass(noise(d, rng), 1500), 5000) * 0.12
    return (tone + breath) * env(len(t), 0.08, d, 0.85, 0.12) * 0.4


def dist_guitar(freqs, d, rng):
    out = np.zeros(int(d * SR))
    for f in freqs:
        out += saw(f, d, 0.004) + 0.5 * square(f * 0.5, d, 0.4)
    out = np.tanh(lowpass(out, 3200) * 4.0) * 0.45
    return out * env(len(out), 0.003, d, 0.8, 0.04)


def lead(f, d, kind='saw'):
    t = t_(d)
    fm = f * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25))
    ph = np.cumsum(fm) / SR
    w = (2 * (ph % 1.0) - 1) if kind == 'saw' else np.where(ph % 1.0 < 0.5, 1.0, -1.0)
    return lowpass(w, 2600) * env(len(t), 0.01, d, 0.7, 0.06) * 0.35


# ------------------------------------------------------------------ yardımcılar
class Track:
    def __init__(self, seconds):
        self.buf = np.zeros(int(seconds * SR) + SR * 4)

    def add(self, at, sig, gain=1.0):
        i = int(at * SR)
        if i >= len(self.buf):
            return
        j = min(len(self.buf), i + len(sig))
        self.buf[i:j] += sig[: j - i] * gain


def chord(root, quality):
    iv = {'m': [0, 3, 7], 'M': [0, 4, 7], 'm7': [0, 3, 7, 10], 'M7': [0, 4, 7, 11], '7': [0, 4, 7, 10], '5': [0, 7, 12], 'sus': [0, 5, 7]}[quality]
    return [root + i for i in iv]


def melody(rng, scale, bars, beats_per_bar, base, density=0.55, step_max=2, rest=0.25):
    """ölçek dereceleri üzerinde rastgele yürüyüş → [(vuruş, süre, midi)]"""
    notes = []
    deg = int(rng.integers(0, len(scale)))
    b = 0.0
    total = bars * beats_per_bar
    while b < total:
        dur = float(rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0] if density < 0.6 else [0.25, 0.5, 0.5, 1.0]))
        if rng.random() > rest:
            deg = int(np.clip(deg + rng.integers(-step_max, step_max + 1), 0, len(scale) * 2 - 1))
            m = base + scale[deg % len(scale)] + 12 * (deg // len(scale))
            notes.append((b, dur, m))
        b += dur
    return notes


def reverb(x, amt=0.25):
    """basit çoklu geri besleme yankısı"""
    y = x.copy()
    for dl, g in ((0.029, 0.5), (0.037, 0.45), (0.051, 0.4), (0.071, 0.35), (0.113, 0.3)):
        n = int(dl * SR)
        b = np.zeros(n + 1)
        b[0] = 1
        a = np.zeros(n + 1)
        a[0] = 1
        a[n] = -g
        y += lfilter(b, a, x) * amt * 0.25
    return y


# ------------------------------------------------------------------ türler
def synthwave(rng, key):
    bpm = 100 + int(rng.integers(-6, 8))
    beat = 60.0 / bpm
    progs = [[(0, 'm'), (8, 'M'), (3, 'M'), (10, 'M')], [(0, 'm'), (5, 'm'), (8, 'M'), (7, 'M')], [(8, 'M'), (10, 'M'), (0, 'm'), (0, 'm')]]
    prog = progs[int(rng.integers(0, len(progs)))]
    bars = 28
    tr = Track(bars * 4 * beat)
    scale = [0, 2, 3, 5, 7, 8, 10]
    mel = melody(rng, scale, 8, 4, key + 69, 0.5)
    for bar in range(bars):
        t0 = bar * 4 * beat
        r, q = prog[bar % 4]
        ch = chord(key + 57 + r, q)
        intro = bar < 4
        if not intro:
            for k in range(4):
                tr.add(t0 + k * beat, kick(rng), 0.9 if k % 2 == 0 else 0.0)
                if k % 2 == 1:
                    tr.add(t0 + k * beat, snare(rng, 0.45, gated=True), 0.55)
            for k in range(8):
                tr.add(t0 + k * beat * 0.5, hat(rng), 0.25 if k % 2 else 0.15)
        for k in range(8):
            f = midi(key + 33 + r + (12 if k % 2 else 0))
            b = lowpass(saw(f, beat * 0.45), 900) * env(int(beat * 0.45 * SR), 0.002, 0.15, 0.3, 0.03)
            tr.add(t0 + k * beat * 0.5, b, 0.5)
        tr.add(t0, pad([midi(n) for n in ch], 4 * beat, 1800), 0.22)
        for k in range(16):
            n = ch[k % len(ch)] + 12 * ((k // len(ch)) % 2)
            tr.add(t0 + k * beat * 0.25, lowpass(saw(midi(n + 12), beat * 0.22), 2500) * env(int(beat * 0.22 * SR), 0.002, 0.08, 0.0, 0.02), 0.12 if bar >= 4 else 0.08)
        if 12 <= bar < 20 or bar >= 24:
            for (b, d, m) in mel:
                if (bar % 8) * 4 <= b < (bar % 8 + 1) * 4:
                    tr.add(t0 + (b - (bar % 8) * 4) * beat, lead(midi(m), d * beat), 0.35)
    return reverb(tr.buf, 0.35)


def lofi(rng, key):
    bpm = 84 + int(rng.integers(-4, 6))
    beat = 60.0 / bpm
    swing = 0.12
    prog = [(2, 'm7'), (7, '7'), (0, 'M7'), (9, 'm7')]
    bars = 26
    tr = Track(bars * 4 * beat)
    scale = [0, 2, 4, 7, 9]
    mel = melody(rng, scale, 4, 4, key + 72, 0.4, rest=0.45)
    for bar in range(bars):
        t0 = bar * 4 * beat
        r, q = prog[bar % 4]
        ch = chord(key + 60 + r, q)
        tr.add(t0, sum(rhodes(midi(n), 3.9 * beat) for n in ch), 0.4)
        tr.add(t0 + 2.5 * beat, sum(rhodes(midi(n + 12), 1.2 * beat) for n in ch[1:3]), 0.18)
        bass = sine(midi(key + 36 + r), 1.8 * beat) * env(int(1.8 * beat * SR), 0.01, 0.6, 0.5, 0.1)
        tr.add(t0, bass, 0.55)
        tr.add(t0 + 2.5 * beat, sine(midi(key + 36 + r + 7), 1.2 * beat) * env(int(1.2 * beat * SR), 0.01, 0.4, 0.4, 0.1), 0.4)
        if bar >= 2:
            for b in (0.0, 1.75, 2.5):
                tr.add(t0 + b * beat, kick(rng), 0.8)
            for b in (1.0, 3.0):
                tr.add(t0 + b * beat, lowpass(snare(rng, 0.3), 5000), 0.5)
            for k in range(8):
                off = swing * beat if k % 2 else 0.0
                tr.add(t0 + k * 0.5 * beat + off, lowpass(hat(rng), 8000), 0.18)
        if bar % 8 >= 4:
            for (b, d, m) in mel:
                if (bar % 4) * 4 <= b < (bar % 4 + 1) * 4:
                    tr.add(t0 + (b - (bar % 4) * 4) * beat, piano(midi(m), d * beat + 0.4), 0.35)
    out = tr.buf
    crackle = (rng.random(len(out)) > 0.9993) * rng.uniform(-0.6, 0.6, len(out))
    out = lowpass(out, 6500) + lowpass(crackle, 3000) * 0.4 + lowpass(rng.uniform(-1, 1, len(out)), 800) * 0.01
    return reverb(out, 0.2)


def rock(rng, key):
    bpm = 126 + int(rng.integers(-6, 10))
    beat = 60.0 / bpm
    progs = [[0, 3, 5, 3], [0, 10, 8, 10], [0, 5, 3, 10]]
    prog = progs[int(rng.integers(0, len(progs)))]
    bars = 34
    tr = Track(bars * 4 * beat)
    scale = [0, 3, 5, 7, 10]
    mel = melody(rng, scale, 8, 4, key + 64, 0.7, step_max=2, rest=0.15)
    for bar in range(bars):
        t0 = bar * 4 * beat
        r = prog[bar % 4]
        pc = [midi(n) for n in chord(key + 40 + r, '5')]
        for k in range(8):
            tr.add(t0 + k * beat * 0.5, dist_guitar(pc, beat * 0.45, rng), 0.42 if bar >= 2 else 0.25)
        tr.add(t0, lowpass(saw(midi(key + 28 + r), 4 * beat), 500) * env(int(4 * beat * SR), 0.005, 2, 0.6, 0.05), 0.45)
        if bar >= 2:
            for k in range(4):
                tr.add(t0 + k * beat, kick(rng), 0.85 if k in (0, 2) else 0.0)
                if k in (1, 3):
                    tr.add(t0 + k * beat, snare(rng, 0.3, 210), 0.65)
            tr.add(t0 + 2.5 * beat, kick(rng), 0.6)
            for k in range(8):
                tr.add(t0 + k * beat * 0.5, hat(rng), 0.22)
            if bar % 8 == 2:
                tr.add(t0, hat(rng, open_=True), 0.7)
        if 10 <= bar < 18 or 26 <= bar < 32:
            for (b, d, m) in mel:
                if (bar % 8) * 4 <= b < (bar % 8 + 1) * 4:
                    tr.add(t0 + (b - (bar % 8) * 4) * beat, np.tanh(lead(midi(m), d * beat) * 3) * 0.5, 0.35)
    return reverb(tr.buf, 0.2)


def koto(rng, key):
    bpm = 82 + int(rng.integers(-6, 6))
    beat = 60.0 / bpm
    scale = [0, 1, 5, 7, 8]          # miyako-bushi
    bars = 24
    tr = Track(bars * 4 * beat)
    mel = melody(rng, scale, 8, 4, key + 69, 0.45, rest=0.3)
    for bar in range(bars):
        t0 = bar * 4 * beat
        arp = [0, 2, 4, 3, 1, 3, 2, 4]
        for k in range(8):
            deg = arp[(k + bar) % 8]
            m = key + 57 + scale[deg % 5] + (12 if deg >= 5 else 0)
            tr.add(t0 + k * beat * 0.5, pluck(midi(m), 1.6, rng, 0.7, 0.997), 0.4)
        tr.add(t0, pad([midi(key + 45), midi(key + 52)], 4 * beat, 700), 0.15)
        if bar >= 4:
            tr.add(t0, taiko(rng), 0.6)
            if bar % 2 == 1:
                tr.add(t0 + 2.5 * beat, taiko(rng), 0.4)
                tr.add(t0 + 3 * beat, taiko(rng), 0.35)
        if 8 <= bar < 16 or bar >= 20:
            for (b, d, m) in mel:
                if (bar % 8) * 4 <= b < (bar % 8 + 1) * 4:
                    tr.add(t0 + (b - (bar % 8) * 4) * beat, flute(midi(m), d * beat + 0.15, rng), 0.45)
    return reverb(tr.buf, 0.45)


def saz(rng, key):
    bpm = 96 + int(rng.integers(-6, 8))
    beat = 60.0 / bpm
    scale = [0, 1, 4, 5, 7, 8, 10]   # hicaz
    bars = 26
    tr = Track(bars * 4 * beat)
    mel = melody(rng, scale, 8, 4, key + 62, 0.62, rest=0.15)
    pat = [('D', 0.0), ('T', 1.0), ('T', 1.5), ('D', 2.0), ('T', 3.0)]
    for bar in range(bars):
        t0 = bar * 4 * beat
        tr.add(t0, pad([midi(key + 38), midi(key + 45)], 4 * beat, 500), 0.2)
        if bar >= 2:
            for kd, b in pat:
                tr.add(t0 + b * beat, darbuka(rng, kd), 0.7)
            tr.add(t0 + 3.5 * beat, darbuka(rng, 'T'), 0.35)
        for (b, d, m) in mel:
            if (bar % 8) * 4 <= b < (bar % 8 + 1) * 4:
                at = t0 + (b - (bar % 8) * 4) * beat
                if d >= 1.0:
                    # uzun notada saz tremolosu
                    for k in range(int(d * 4)):
                        tr.add(at + k * beat * 0.25, pluck(midi(m), 0.5, rng, 0.9, 0.995), 0.28)
                else:
                    tr.add(at, pluck(midi(m), 1.0, rng, 0.9, 0.996), 0.4)
        if 10 <= bar < 18:
            for (b, d, m) in mel[::2]:
                if (bar % 8) * 4 <= b < (bar % 8 + 1) * 4:
                    tr.add(t0 + (b - (bar % 8) * 4) * beat, flute(midi(m + 12), d * beat + 0.2, rng, 4.5), 0.22)
    return reverb(tr.buf, 0.3)


def ambient(rng, key):
    bpm = 70
    beat = 60.0 / bpm
    prog = [(0, 'M7'), (9, 'm7'), (5, 'M7'), (7, 'sus')]
    bars = 22
    tr = Track(bars * 4 * beat)
    scale = [0, 2, 4, 7, 9]
    for bar in range(bars):
        t0 = bar * 4 * beat
        r, q = prog[(bar // 2) % 4]
        ch = chord(key + 60 + r, q)
        if bar % 2 == 0:
            tr.add(t0, pad([midi(n) for n in ch], 8 * beat, 1100, 0.01), 0.3)
            tr.add(t0, sine(midi(key + 36 + r), 8 * beat) * env(int(8 * beat * SR), 1.0, 8, 1.0, 1.0), 0.35)
        for k in range(4):
            if rng.random() < 0.55:
                m = key + 72 + scale[int(rng.integers(0, 5))] + (12 if rng.random() < 0.3 else 0)
                tr.add(t0 + k * beat + rng.uniform(0, 0.2), piano(midi(m), 3.0), 0.3)
        if bar >= 4:
            for k in range(8):
                tr.add(t0 + k * beat * 0.5, lowpass(hat(rng), 7000), 0.08)
    return reverb(tr.buf, 0.6)


STATIONS = {
    'neonfm': (synthwave, [9, 2, 4]),
    'ritim': (lofi, [5, 0, 7]),
    'kanyon': (rock, [4, 9, 2]),
    'sakura': (koto, [4, 9, 11]),
    'cay': (saz, [2, 7, 9]),
    'dalga': (ambient, [0, 5, 7]),
}


def master(x):
    """ses düzeyi eşitleme (RMS) + yumuşak sınırlayıcı: istasyonlar arası geçişte ses zıplamaz"""
    x = x - np.mean(x)
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    x = x * (0.2 / rms)
    return np.tanh(x * 1.1) * 0.9


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    for name, (fn, keys) in STATIONS.items():
        if only and name not in only:
            continue
        parts = []
        for i, k in enumerate(keys):
            rng = np.random.default_rng(sum(ord(c) * 31 ** j for j, c in enumerate(name)) % (2 ** 31) + i * 101)
            song = master(fn(rng, k))
            # şarkı sonu yumuşak kapanış + kısa sessizlik
            fade = int(SR * 2.0)
            song[-fade:] *= np.linspace(1, 0, fade)
            parts.append(song)
            parts.append(np.zeros(int(SR * 0.8)))
        audio = np.concatenate(parts)
        pcm = (np.clip(audio, -1, 1) * 32000).astype(np.int16)
        wav = os.path.join('/tmp', name + '_music.wav')
        import wave
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT, name + '.ogg')
        try:
            r = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', '-fflags', '+bitexact', '-flags:a', '+bitexact', out])
            ok = r.returncode == 0
        except FileNotFoundError:
            ok = False
        if not ok:
            import shutil
            shutil.copy(wav, os.path.join(OUT, name + '.wav'))
        print('♪', name, '%.0f sn' % (len(audio) / SR), 'ogg' if ok else 'wav')


if __name__ == '__main__':
    main()
