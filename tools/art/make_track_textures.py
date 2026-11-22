#!/usr/bin/env python3
"""Generates the v0.1.36 track-side textures (deterministic, no external art):

  game/assets/surfaces/barrier_ads.png    advertising band for the barrier walls
                                          (2048 x 128 = four 4:1 panels, repeats every 9.6 m)
  game/assets/surfaces/concrete_slabs.png tileable concrete shoulder with slab joints
  game/assets/brand/road_logo.png         NITRO WHEELZ road inscription (crown + wordmark)

Inputs: the brand wordmark rendered from nitro_wheelz_logo.svg (render_logo_svg.gd) and the
project font converted to TTF (python -m fontTools.ttx / TTFont(...).flavor = None). Only
fictional names that belong to this game are printed on the panels (no real sponsors).

  python3 tools/art/make_track_textures.py --logo logo_render.png --font Exo2-ExtraBoldItalic.ttf
"""
import argparse
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

PURPLE = (149, 81, 249)
PINK = (225, 63, 147)
DEEP = (20, 8, 40)
WHITE = (253, 252, 255)
YELLOW = (255, 218, 73)


def crop_alpha(im):
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(box)


def fit(im, w, h):
    s = min(w / im.size[0], h / im.size[1])
    return im.resize((max(1, round(im.size[0] * s)), max(1, round(im.size[1] * s))), Image.LANCZOS)


def gradient(w, h, top, bottom):
    g = Image.new("RGBA", (w, h))
    px = g.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return g


def road_logo(logo, out):
    top = logo.crop((0, 0, logo.size[0], int(logo.size[1] * 0.765)))
    top = crop_alpha(top)
    W = 1024
    H = round(top.size[1] * W / top.size[0])
    top = top.resize((W, H), Image.LANCZOS)
    pad = Image.new("RGBA", (W + 16, H + 16), (0, 0, 0, 0))
    pad.paste(top, (8, 8))
    pad.save(out, optimize=True)


def barrier_ads(logo, font_path, out):
    PW, PH = 512, 128
    strip = Image.new("RGBA", (PW * 4, PH), (0, 0, 0, 255))
    font = ImageFont.truetype(font_path, 78)
    small = ImageFont.truetype(font_path, 40)
    wordmark = crop_alpha(logo.crop((0, 0, logo.size[0], int(logo.size[1] * 0.765))))
    jp = logo.crop((0, int(logo.size[1] * 0.74), logo.size[0], logo.size[1]))
    # keep only the white strap (drop the tail of the purple WHEELZ letters)
    jp_px = jp.load()
    for y in range(jp.size[1]):
        for x in range(jp.size[0]):
            r, g, b, a = jp_px[x, y]
            if not (r > 215 and g > 215 and b > 215):
                jp_px[x, y] = (0, 0, 0, 0)
    jp = crop_alpha(jp)
    # 1: wordmark on deep purple
    p = gradient(PW, PH, (38, 14, 76), DEEP)
    wm = fit(wordmark, PW - 30, PH - 12)
    p.alpha_composite(wm, ((PW - wm.size[0]) // 2, (PH - wm.size[1]) // 2))
    strip.paste(p, (0, 0))
    # 2: white panel, NITRO in deep purple, a pink stripe
    p = Image.new("RGBA", (PW, PH), (236, 234, 244, 255))
    d = ImageDraw.Draw(p)
    d.rectangle((0, PH - 14, PW, PH), fill=PINK)
    d.text((PW // 2, 42), "NITRO", font=font, fill=(40, 16, 90, 255), anchor="mm")
    d.text((PW // 2, 92), "DRIFT PARK", font=ImageFont.truetype(font_path, 32), fill=(40, 16, 90, 255), anchor="mm")
    strip.paste(p, (PW, 0))
    # 3: pink panel with the Japanese strap
    p = gradient(PW, PH, (236, 84, 160), (176, 36, 112))
    j = fit(jp, PW - 60, 52)
    p.alpha_composite(j, ((PW - j.size[0]) // 2, 12))
    d = ImageDraw.Draw(p)
    d.text((PW // 2, 92), "WHEELZ", font=ImageFont.truetype(font_path, 52), fill=WHITE, anchor="mm")
    strip.paste(p, (PW * 2, 0))
    # 4: black / white check with a purple plate
    p = Image.new("RGBA", (PW, PH), (18, 18, 24, 255))
    d = ImageDraw.Draw(p)
    cell = 16
    for y in range(0, PH, cell):
        for x in range(0, PW, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(228, 228, 236, 255))
    d.rounded_rectangle((90, 22, PW - 90, PH - 22), radius=14, fill=(52, 20, 104, 255))
    d.text((PW // 2, PH // 2 + 2), "NW", font=ImageFont.truetype(font_path, 74), fill=WHITE, anchor="mm")
    strip.paste(p, (PW * 3, 0))
    # a thin dark frame top and bottom so the band reads as a printed board
    d = ImageDraw.Draw(strip)
    d.rectangle((0, 0, PW * 4, 3), fill=(12, 12, 18, 255))
    d.rectangle((0, PH - 4, PW * 4, PH), fill=(12, 12, 18, 255))
    strip.convert("RGB").save(out, optimize=True)


def concrete_slabs(out):
    rng = random.Random(1136)
    S = 512
    im = Image.new("RGB", (S, S))
    px = im.load()
    base = 112
    slab = S // 2
    tone = [rng.uniform(-5, 5) for _ in range(4)]
    for y in range(S):
        for x in range(S):
            k = (y // slab) * 2 + (x // slab)
            n = rng.uniform(-3.5, 3.5)
            v = int(base + tone[k] + n)
            px[x, y] = (v, v, v + 2)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    d = ImageDraw.Draw(im)
    for k in range(2):
        c = k * slab
        d.rectangle((c - 2, 0, c + 2, S), fill=(54, 54, 60))
        d.rectangle((0, c - 2, S, c + 2), fill=(54, 54, 60))
    d.rectangle((0, 0, 2, S), fill=(54, 54, 60))
    d.rectangle((0, 0, S, 2), fill=(54, 54, 60))
    d.rectangle((S - 3, 0, S, S), fill=(54, 54, 60))
    d.rectangle((0, S - 3, S, S), fill=(54, 54, 60))
    im.save(out, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logo", required=True, help="PNG render of nitro_wheelz_logo.svg (RGBA)")
    ap.add_argument("--font", required=True, help="Exo2-ExtraBoldItalic.ttf")
    ap.add_argument("--root", default="game")
    a = ap.parse_args()
    logo = Image.open(a.logo).convert("RGBA")
    road_logo(logo, f"{a.root}/assets/brand/road_logo.png")
    barrier_ads(logo, a.font, f"{a.root}/assets/surfaces/barrier_ads.png")
    concrete_slabs(f"{a.root}/assets/surfaces/concrete_slabs.png")
    print("wrote road_logo.png, barrier_ads.png, concrete_slabs.png")


if __name__ == "__main__":
    main()
