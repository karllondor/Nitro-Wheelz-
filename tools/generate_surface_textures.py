#!/usr/bin/env python3
"""Generate Nitro Wheelz' original tileable night-park surface textures.

Everything is procedural (seeded numpy noise), so the files are original work
of this repository and can be regenerated bit-for-bit:

    python3 tools/generate_surface_textures.py

Outputs (game/assets/surfaces/):
  grass_night.webp   512x512  olive night grass with sparse pink blossoms
  dirt_verge.webp    256x256  packed earth / gravel verge outside the barrier
  flower_cluster.png  64x64   RGBA pink blossom cluster sprite (verge decals)
  blossom_leaf.png    64x64   RGBA cherry-blossom canopy speckle (tree tops)
Requires numpy + Pillow (developer tool only, not used by the game at runtime).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "surfaces"


def periodic_noise(size, beta, rng):
    """Tileable fractal noise in [0,1] by 1/f^beta filtering white noise."""
    white = rng.standard_normal((size, size))
    fx = np.fft.fftfreq(size)[:, None]
    fy = np.fft.fftfreq(size)[None, :]
    freq = np.sqrt(fx * fx + fy * fy)
    freq[0, 0] = 1.0
    spectrum = np.fft.fft2(white) / freq ** beta
    spectrum[0, 0] = 0.0
    field = np.real(np.fft.ifft2(spectrum))
    field -= field.min()
    field /= max(field.max(), 1e-9)
    return field


def stamp_disc(img, cx, cy, radius, colour, alpha=1.0):
    """Wrap-around soft disc stamp (keeps the texture tileable)."""
    size = img.shape[0]
    r = int(np.ceil(radius + 1))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = np.hypot(dx, dy)
            if d > radius + 0.5:
                continue
            a = alpha * float(np.clip(radius + 0.5 - d, 0.0, 1.0))
            x = (cx + dx) % size
            y = (cy + dy) % size
            img[y, x, :3] = img[y, x, :3] * (1 - a) + np.array(colour) * a


def grass(rng):
    size = 512
    broad = periodic_noise(size, 1.6, rng)
    mid = periodic_noise(size, 1.1, rng)
    fine = periodic_noise(size, 0.35, rng)
    dark = np.array([40, 66, 34], float)
    olive = np.array([104, 124, 50], float)
    warm = np.array([132, 126, 54], float)
    t = np.clip(broad * 0.65 + mid * 0.35, 0, 1)[..., None]
    base = dark * (1 - t) + olive * t
    warm_mix = np.clip((mid - 0.55) * 2.2, 0, 1)[..., None] * 0.45
    base = base * (1 - warm_mix) + warm * warm_mix
    base *= (0.80 + 0.40 * fine)[..., None]
    img = np.concatenate([base, np.full((size, size, 1), 255.0)], axis=2)
    # Grass tufts: short darker strokes.
    for _ in range(2600):
        x, y = rng.integers(0, size, 2)
        length = rng.integers(2, 6)
        shade = rng.uniform(0.55, 0.8)
        for k in range(length):
            px, py = (x + k // 2) % size, (y - k) % size
            img[py, px, :3] *= shade
    # Sparse blossoms (pink) and a few pale daisies.
    for _ in range(140):
        x, y = rng.integers(0, size, 2)
        pink = [rng.uniform(225, 255), rng.uniform(95, 140), rng.uniform(165, 205)]
        stamp_disc(img, x, y, rng.uniform(1.0, 2.1), pink, 0.92)
    for _ in range(40):
        x, y = rng.integers(0, size, 2)
        stamp_disc(img, x, y, 1.0, [235, 232, 220], 0.8)
    return Image.fromarray(np.clip(img[..., :3], 0, 255).astype(np.uint8), "RGB")


def dirt(rng):
    size = 256
    broad = periodic_noise(size, 1.4, rng)
    fine = periodic_noise(size, 0.5, rng)
    a = np.array([92, 64, 44], float)
    b = np.array([150, 108, 74], float)
    t = np.clip(broad * 0.7 + fine * 0.3, 0, 1)[..., None]
    img = a * (1 - t) + b * t
    img *= (0.85 + 0.3 * fine)[..., None]
    img = np.concatenate([img, np.full((size, size, 1), 255.0)], axis=2)
    for _ in range(900):
        x, y = rng.integers(0, size, 2)
        grey = rng.uniform(120, 185)
        stamp_disc(img, x, y, rng.uniform(0.6, 1.6),
                   [grey * 1.02, grey * 0.92, grey * 0.82], 0.85)
    for _ in range(500):
        x, y = rng.integers(0, size, 2)
        stamp_disc(img, x, y, rng.uniform(0.6, 1.3), [62, 44, 32], 0.7)
    return Image.fromarray(np.clip(img[..., :3], 0, 255).astype(np.uint8), "RGB")


def sprite_cluster(rng, colours, count, size=64, spread=0.36, petal=(2.2, 4.6)):
    img = np.zeros((size, size, 4), float)
    centre = size / 2
    for _ in range(count):
        ang = rng.uniform(0, np.pi * 2)
        rad = abs(rng.normal(0, spread)) * size * 0.5
        x = centre + np.cos(ang) * rad
        y = centre + np.sin(ang) * rad
        r = rng.uniform(*petal)
        col = colours[rng.integers(0, len(colours))]
        shade = rng.uniform(0.82, 1.08)
        yy, xx = np.mgrid[0:size, 0:size]
        d = np.hypot(xx - x, yy - y)
        a = np.clip(r + 0.6 - d, 0, 1)
        for c in range(3):
            img[..., c] = img[..., c] * (1 - a) + np.clip(col[c] * shade, 0, 255) * a
        img[..., 3] = np.maximum(img[..., 3], a * 255)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(20261119)
    grass(rng).save(OUT / "grass_night.webp", lossless=True, quality=100, method=6)
    dirt(rng).save(OUT / "dirt_verge.webp", lossless=True, quality=100, method=6)
    pinks = [(255, 120, 190), (245, 92, 170), (255, 165, 215), (230, 70, 150)]
    sprite_cluster(rng, pinks, 26).save(OUT / "flower_cluster.png", optimize=True)
    blossom = [(255, 150, 205), (248, 110, 182), (255, 196, 228), (214, 74, 148)]
    sprite_cluster(rng, blossom, 150, spread=0.40, petal=(2.6, 4.6)).save(
        OUT / "blossom_leaf.png", optimize=True)
    for name in ("grass_night.webp", "dirt_verge.webp", "flower_cluster.png", "blossom_leaf.png"):
        print("WROTE", (OUT / name).relative_to(ROOT), (OUT / name).stat().st_size, "bytes")


if __name__ == "__main__":
    main()
