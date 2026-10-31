#!/usr/bin/env python3
"""Génère les textures d'effets (fumée, feu, éclairs de bouche, impacts) et les sons d'armes.

Tout est fabriqué ici (bruit procédural et synthèse audio) : aucun fichier extérieur, aucune licence.
Usage : python3 tools/gen_fx.py   (écrit assets/fx/*.png et assets/sfx/*.wav)
"""
import math
import os
import wave

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FX = os.path.join(ROOT, "assets", "fx")
SFX = os.path.join(ROOT, "assets", "sfx")
rng = np.random.default_rng(2189)


# ---------------------------------------------------------------- bruit
def _up(a, size):
    im = Image.fromarray((a * 255).astype(np.uint8))
    return np.asarray(im.resize((size, size), Image.BICUBIC), dtype=np.float32) / 255.0


def fbm(size, octaves=5, base=4, seed_off=None):
    out = np.zeros((size, size), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = base * (2 ** o)
        out += _up(rng.random((n, n)).astype(np.float32), size) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def radial(size, cx=0.5, cy=0.5):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    return np.sqrt((x - cx) ** 2 + (y - cy) ** 2), np.arctan2(y - cy, x - cx)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save_rgba(path, rgb, a):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(path)
    print("écrit", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------- textures
def smoke_sheet(frames=8, cell=128):
    """Bouffée de fumée qui gonfle et se dissipe : 8x8 images, alpha + léger relief (haut plus clair)."""
    sheet_rgb = np.zeros((cell * frames, cell * frames, 3), np.float32)
    sheet_a = np.zeros((cell * frames, cell * frames), np.float32)
    big = fbm(cell * 2, 6, 3)
    big2 = fbm(cell * 2, 5, 5)
    d, _ = radial(cell)
    yy = np.mgrid[0:cell, 0:cell][0].astype(np.float32) / cell
    for i in range(frames * frames):
        t = i / (frames * frames - 1)
        ox = int(t * cell * 0.6)
        n = big[ox:ox + cell, ox // 2:ox // 2 + cell] * 0.65 + big2[cell - ox // 2:2 * cell - ox // 2, ox:ox + cell] * 0.35
        r = 0.3 + 0.14 * math.sqrt(t)
        shape = smooth(r + 0.06, r - 0.22, d + (n - 0.5) * 0.7) * smooth(0.5, 0.36, d)
        dens = shape * smooth(0.25, 0.6, n + 0.25 - t * 0.35) * (1.0 - t ** 1.6)
        a = np.clip(dens * 1.5, 0, 1)
        light = 0.62 + 0.38 * (1.0 - yy) * 0.8 + (n - 0.5) * 0.35
        rgb = np.dstack([light, light, light * 1.02])
        gy, gx = divmod(i, frames)
        sheet_rgb[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = rgb
        sheet_a[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = a
    save_rgba(os.path.join(FX, "smoke_sheet.png"), sheet_rgb, sheet_a)


def fire_sheet(frames=8, cell=128):
    """Boule de feu : cœur blanc-jaune, bords orange puis rouge sombre, finit en fumée noire (pour mélange additif)."""
    sheet = np.zeros((cell * frames, cell * frames, 4), np.float32)
    big = fbm(cell * 2, 6, 4)
    d, _ = radial(cell)
    for i in range(frames * frames):
        t = i / (frames * frames - 1)
        ox = int(t * cell * 0.9)
        n = big[ox:ox + cell, cell // 2 - ox // 3 + 20:cell // 2 - ox // 3 + 20 + cell] if ox < cell else big[:cell, :cell]
        r = 0.3 + 0.14 * math.sqrt(t)
        shape = smooth(r + 0.05, r - 0.22, d + (n - 0.5) * 0.85) * smooth(0.5, 0.34, d)
        n2 = big[cell - ox // 2:2 * cell - ox // 2, ox // 3:ox // 3 + cell]
        heat = np.clip(shape * (1.3 - t * 1.35) * (0.45 + 1.0 * n2) + (n - 0.5) * 0.3, 0, 1)
        col = np.zeros((cell, cell, 3), np.float32)
        col[..., 0] = 0.25 + 0.75 * smooth(0.0, 0.3, heat)
        col[..., 1] = smooth(0.15, 0.7, heat) * 0.88
        col[..., 2] = smooth(0.55, 1.0, heat) * 0.65
        # Les bords froids deviennent fumée : on les rend transparents plutôt que rouge sombre
        a = shape * (smooth(0.12, 0.5, heat) * (1 - t) + smooth(0.0, 0.25, heat) * t * 0.6) * (1 - t ** 2.5)
        smoke_k = smooth(0.25, 0.0, heat) * t
        col = col * (1 - smoke_k[..., None]) + 0.12 * smoke_k[..., None]
        gy, gx = divmod(i, frames)
        sheet[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell, :3] = col * a[..., None]
        sheet[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell, 3] = a
    save_rgba(os.path.join(FX, "fire_sheet.png"), sheet[..., :3], sheet[..., 3])


def muzzle_front(cell=256):
    """Éclair de bouche vu de face : 4 variantes (2x2), étoile à branches irrégulières."""
    out = np.zeros((cell * 2, cell * 2, 4), np.float32)
    d, ang = radial(cell)
    for v in range(4):
        branches = [4, 5, 6, 5][v]
        phase = rng.random() * math.tau
        lobes = np.abs(np.cos((ang + phase) * branches / 2.0)) ** 6
        jag = rng.random(64)
        k = ((ang + math.pi) / math.tau * 63).astype(int)
        lobes = lobes * (0.55 + 0.45 * jag[k])
        reach = 0.12 + 0.36 * lobes
        star = smooth(reach, reach * 0.3, d)
        core = smooth(0.16, 0.0, d)
        hot = np.clip(star * 0.8 + core, 0, 1)
        col = np.dstack([np.ones_like(hot), 0.55 + 0.45 * smooth(0.3, 1.0, hot), 0.15 + 0.85 * smooth(0.7, 1.0, hot)])
        gy, gx = divmod(v, 2)
        out[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell, :3] = col * hot[..., None]
        out[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell, 3] = hot
    save_rgba(os.path.join(FX, "muzzle_front.png"), out[..., :3], out[..., 3])


def muzzle_side(w=256, h=128):
    """Flamme de bouche vue de côté : le canon à gauche, la flamme s'évase vers la droite. 2 variantes (empilées)."""
    out = np.zeros((h * 2, w, 4), np.float32)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    x /= w
    y = (y / h - 0.5) * 2
    for v in range(2):
        n = fbm(w, 4, 6)[:h, :]
        width = 0.18 + 0.6 * np.sin(np.clip(x, 0, 1) * math.pi * 0.85) * (1 - x) ** 0.6
        body = smooth(width, width * 0.25, np.abs(y) + (n - 0.5) * 0.4) * smooth(1.0, 0.55, x + (n - 0.5) * 0.3)
        body *= smooth(0.0, 0.05, x)
        hot = np.clip(body * (1.3 - x), 0, 1)
        col = np.dstack([np.ones_like(hot), 0.5 + 0.5 * smooth(0.3, 1.0, hot), 0.1 + 0.9 * smooth(0.75, 1.0, hot)])
        out[v * h:(v + 1) * h, :, :3] = col * body[..., None]
        out[v * h:(v + 1) * h, :, 3] = body
    save_rgba(os.path.join(FX, "muzzle_side.png"), out[..., :3], out[..., 3])


def streak(w=16, h=128):
    """Étincelle étirée / balle traçante : fine, brillante au centre, s'efface vers les bouts (axe vertical)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    x = (x / (w - 1) - 0.5) * 2
    y = y / (h - 1)
    a = smooth(1.0, 0.0, np.abs(x)) ** 2 * smooth(0.0, 0.25, y) * smooth(1.0, 0.6, y)
    rgb = np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a)])
    save_rgba(os.path.join(FX, "streak.png"), rgb, a)


def bullet_hole(cell=128):
    """Trou de balle : centre noir, collerette brûlée irrégulière, petites fissures."""
    d, ang = radial(cell)
    n = fbm(cell, 4, 8)
    cracks = np.zeros_like(d)
    for _ in range(7):
        a0 = rng.random() * math.tau
        da = np.abs(np.angle(np.exp(1j * (ang - a0))))
        cracks = np.maximum(cracks, smooth(0.05, 0.0, da * d * 4) * smooth(0.42, 0.1, d))
    hole = smooth(0.12, 0.06, d + (n - 0.5) * 0.06)
    burn = smooth(0.38, 0.1, d + (n - 0.5) * 0.25) * 0.75
    a = np.clip(np.maximum(np.maximum(hole, burn), cracks * 0.8), 0, 1)
    shade = 0.06 + 0.18 * (1 - hole) * n
    rgb = np.dstack([shade, shade * 0.95, shade * 0.9])
    save_rgba(os.path.join(FX, "bullet_hole.png"), rgb, a)


def scorch(cell=256):
    """Trace de brûlure au sol après une explosion."""
    d, ang = radial(cell)
    n = fbm(cell, 5, 4)
    rays = (np.cos(ang * 9 + n * 6) * 0.5 + 0.5) * 0.05
    a = smooth(0.5, 0.12, d + (n - 0.5) * 0.3 - rays) * (0.75 + 0.25 * n)
    shade = 0.03 + 0.1 * n
    rgb = np.dstack([shade * 1.1, shade, shade * 0.9])
    save_rgba(os.path.join(FX, "scorch.png"), rgb, a)


def shock(cell=256):
    """Onde de choc : anneau fin et doux."""
    d, _ = radial(cell)
    a = smooth(0.06, 0.0, np.abs(d - 0.42)) * 0.9 + smooth(0.2, 0.0, np.abs(d - 0.38)) * 0.25
    rgb = np.ones((cell, cell, 3), np.float32)
    save_rgba(os.path.join(FX, "shock.png"), rgb, np.clip(a, 0, 1))


# ---------------------------------------------------------------- sons
SR = 44100


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def lowpass(x, cutoff):
    """Passe-bas un pôle (appliqué deux fois pour une pente plus douce)."""
    if np.isscalar(cutoff):
        cutoff = np.full(len(x), cutoff, np.float32)
    k = 1.0 - np.exp(-2 * math.pi * cutoff / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i in range(len(x)):
            acc += k[i] * (x[i] - acc)
            y[i] = acc
        x = y
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(n):
    return rng.standard_normal(n).astype(np.float32)


def brown(n):
    b = np.cumsum(noise(n))
    b -= lowpass(b, 8.0)
    return b / (np.abs(b).max() + 1e-6)


def tail(x, seconds=0.6, mix=0.25, cutoff=1800):
    """Écho d'espace ouvert : bruit filtré qui suit l'enveloppe du son."""
    n = len(x) + int(seconds * SR)
    out = np.zeros(n, np.float32)
    out[:len(x)] = x
    e = np.abs(np.pad(x, (0, n - len(x))))
    e = lowpass(e, 6.0)
    rv = lowpass(noise(n), cutoff) * e * mix * 6
    soft = np.pad(lowpass(x, cutoff * 0.7), (0, n - len(x)))
    for delay, g in ((0.09, 0.35), (0.21, 0.22), (0.37, 0.12)):
        d = int(delay * SR)
        if d < n:
            out[d:] += soft[: n - d] * g
    return out + rv


def norm(x, peak=0.9):
    return (x / (np.abs(x).max() + 1e-6) * peak).astype(np.float32)


def write_wav(name, x):
    x = norm(x)
    fade = min(len(x), int(0.02 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(SFX, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("écrit", os.path.relpath(path, ROOT), "%.2f s" % (len(x) / SR))


def gunshot(length=0.35, crack_decay=0.012, body_decay=0.06, thump_hz=70, bright=5200, tail_s=0.7):
    n = int(length * SR)
    crack = highpass(noise(n), 1500) * env(n, 0.0003, crack_decay) * 1.4
    body = lowpass(noise(n), bright) * env(n, 0.001, body_decay)
    t = np.arange(n) / SR
    thump = np.sin(2 * math.pi * (thump_hz * t + 30 * t * np.exp(-t * 30))) * env(n, 0.001, 0.07) * 0.9
    return tail(crack + body + thump, tail_s, 0.18)


def explosion(length=2.2, size=1.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    rumble = brown(n) * env(n, 0.004, 0.55 * size) * 1.4
    roar = lowpass(noise(n), 900 * np.exp(-t * 1.5) + 120) * env(n, 0.002, 0.35 * size)
    crack = highpass(noise(n), 900) * env(n, 0.0002, 0.03) * 0.9
    boom = np.sin(2 * math.pi * (38 * t + 25 * t * np.exp(-t * 6))) * env(n, 0.003, 0.4 * size) * 1.2
    debris = np.zeros(n, np.float32)
    for _ in range(int(14 * size)):
        p = int(rng.uniform(0.15, length * 0.8) * SR)
        m = min(n - p, int(0.04 * SR))
        debris[p:p + m] += highpass(noise(m), 2500) * env(m, 0.0005, 0.008) * rng.uniform(0.05, 0.18)
    return tail(rumble + roar + crack + boom + debris, 1.2, 0.15, 600)


def whoosh(length=0.7, f0=400, f1=2600):
    n = int(length * SR)
    t = np.arange(n) / SR
    cut = f0 + (f1 - f0) * np.clip(t / length, 0, 1) ** 0.5
    x = lowpass(noise(n), cut) - lowpass(noise(n), cut * 0.25)
    e = np.clip(t / 0.03, 0, 1) * np.exp(-t / (length * 0.45))
    pop = highpass(noise(n), 800) * env(n, 0.0005, 0.02) * 0.8
    return x * e * 1.4 + pop


def ricochet(length=0.35):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = 3200 * np.exp(-t * 3) + 900
    ping = np.sin(2 * math.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.08) * 0.5
    tick = highpass(noise(n), 3000) * env(n, 0.0002, 0.006)
    return ping + tick


def hit_dirt(length=0.25):
    n = int(length * SR)
    return lowpass(noise(n), 1400) * env(n, 0.0005, 0.03) + highpass(noise(n), 4000) * env(n, 0.0002, 0.004) * 0.6


def hit_metal(length=0.3):
    n = int(length * SR)
    t = np.arange(n) / SR
    clang = sum(np.sin(2 * math.pi * f * t) * a for f, a in ((1830, 0.5), (2710, 0.35), (4120, 0.25), (5900, 0.15)))
    return clang * env(n, 0.0003, 0.05) + highpass(noise(n), 3500) * env(n, 0.0002, 0.006) * 0.9


def casing(length=0.3):
    n = int(length * SR)
    t = np.arange(n) / SR
    x = np.zeros(n, np.float32)
    for k, (dt, g) in enumerate(((0.0, 1.0), (0.09, 0.5), (0.15, 0.25))):
        p = int(dt * SR)
        m = n - p
        tt = t[:m]
        x[p:] += (np.sin(2 * math.pi * 6200 * tt) + 0.6 * np.sin(2 * math.pi * 8900 * tt)) * np.exp(-tt / 0.025) * g
    return x * 0.5


def beam(length=0.9):
    n = int(length * SR)
    t = np.arange(n) / SR
    buzz = np.sign(np.sin(2 * math.pi * (110 + 40 * np.sin(t * 30)) * t)) * 0.3
    hiss = highpass(noise(n), 2500) * 0.6
    crackle = (rng.random(n) > 0.997).astype(np.float32) * noise(n) * 3
    zap = np.sin(2 * math.pi * np.cumsum(2400 * np.exp(-t * 6) + 300) / SR) * env(n, 0.001, 0.12)
    return (lowpass(buzz + hiss + crackle, 6000) * env(n, 0.005, 0.35)) + zap


def main():
    os.makedirs(FX, exist_ok=True)
    os.makedirs(SFX, exist_ok=True)
    smoke_sheet()
    fire_sheet()
    muzzle_front()
    muzzle_side()
    streak()
    bullet_hole()
    scorch()
    shock()
    for i in range(3):
        write_wav("rifle_%d" % i, gunshot(0.32, 0.010 + i * 0.002, 0.05 + i * 0.008, 65 + i * 8, 5200 - i * 500))
    for i in range(2):
        write_wav("sniper_%d" % i, gunshot(0.6, 0.02, 0.12, 52 + i * 6, 3800, 1.4))
    for i in range(3):
        write_wav("explosion_%d" % i, explosion(2.4, 1.0 + i * 0.12))
    for i in range(2):
        write_wav("blast_small_%d" % i, explosion(1.3, 0.55 + i * 0.1))
    write_wav("missile_launch", whoosh(0.8, 300, 2400))
    write_wav("missile_small", whoosh(0.45, 600, 3600))
    for i in range(2):
        write_wav("ricochet_%d" % i, ricochet(0.3 + i * 0.1))
    for i in range(2):
        write_wav("hit_dirt_%d" % i, hit_dirt())
    for i in range(2):
        write_wav("hit_metal_%d" % i, hit_metal())
    write_wav("casing", casing())
    write_wav("beam", beam())
    write_wav("grenade_throw", whoosh(0.35, 500, 1500) * 0.6)


if __name__ == "__main__":
    main()
