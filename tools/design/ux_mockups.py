#!/usr/bin/env python3
"""Issue #28 (DESIGN REVIEW ONLY): annotated screenshot of the current HUD + two mock-up directions,
drawn over REAL frames captured by game/tests/capture_ux_review.gd (portrait 720 x 1600).

  OUT_DIR=<dir> xvfb-run ... godot --path game --script res://tests/capture_ux_review.gd
  python3 tools/design/ux_mockups.py <dir with the captures> <output dir>

Nothing here changes game code. Millimetres assume a 1080 x 2400 phone of about 69.7 mm panel width
(15.5 px/mm; typical 6.5-6.7 inch phone): the owner's exact phone is not known, ratios hold for any phone.
"""
import json
import sys
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
W, H = 720, 1600
S = 2                                   # supersampling for smooth shapes
MM = 720 / 69.7                         # px per mm on the 720 px canvas
FONT = "/home/user/Nitro-Wheelz-/game/assets/fonts/Exo2-ItalicVF.ttf"
PINK, VIOLET, CYAN, GOLD = (255, 45, 140), (140, 82, 230), (60, 220, 255), (255, 214, 64)
BG = (8, 6, 14)
GLASS = (14, 10, 24)


def font(size, weight=800):
    f = ImageFont.truetype(FONT, int(size * S))
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


class Canvas:
    def __init__(self, base=None):
        self.im = (base.convert("RGBA").resize((W * S, H * S), Image.LANCZOS) if base is not None
                   else Image.new("RGBA", (W * S, H * S), BG + (255,)))

    def layer(self):
        return Image.new("RGBA", self.im.size, (0, 0, 0, 0))

    def rr(self, box, r, fill=None, outline=None, width=2, alpha=255):
        lay = self.layer()
        d = ImageDraw.Draw(lay)
        b = [v * S for v in box]
        d.rounded_rectangle(b, r * S, fill=(fill + (alpha,)) if fill else None,
                            outline=(outline + (255,)) if outline else None, width=int(width * S))
        self.im.alpha_composite(lay)

    def circle(self, c, r, fill=None, outline=None, width=2, alpha=255):
        lay = self.layer()
        d = ImageDraw.Draw(lay)
        d.ellipse([(c[0] - r) * S, (c[1] - r) * S, (c[0] + r) * S, (c[1] + r) * S],
                  fill=(fill + (alpha,)) if fill else None, outline=(outline + (255,)) if outline else None,
                  width=int(width * S))
        self.im.alpha_composite(lay)

    def arc(self, c, r, a0, a1, color, width=6):
        lay = self.layer()
        d = ImageDraw.Draw(lay)
        d.arc([(c[0] - r) * S, (c[1] - r) * S, (c[0] + r) * S, (c[1] + r) * S], a0, a1, fill=color + (255,), width=int(width * S))
        self.im.alpha_composite(lay)

    def text(self, xy, s, size, color=(255, 255, 255), weight=800, anchor="la", alpha=255, stroke=0):
        lay = self.layer()
        d = ImageDraw.Draw(lay)
        d.text((xy[0] * S, xy[1] * S), s, font=font(size, weight), fill=color + (alpha,), anchor=anchor,
               stroke_width=int(stroke * S), stroke_fill=(0, 0, 0, 255))
        self.im.alpha_composite(lay)

    def line(self, p, q, color, width=2):
        lay = self.layer()
        ImageDraw.Draw(lay).line([p[0] * S, p[1] * S, q[0] * S, q[1] * S], fill=color + (255,), width=int(width * S))
        self.im.alpha_composite(lay)

    def out(self):
        return self.im.resize((W, H), Image.LANCZOS).convert("RGB")


def glass(c, box, r=14, rim=PINK, alpha=215):
    c.rr(box, r, fill=GLASS, alpha=alpha)
    c.rr(box, r, outline=rim, width=2)


def badge(c, xy, n):
    c.circle(xy, 15, fill=GOLD)
    c.text(xy, str(n), 20, color=(10, 6, 20), anchor="mm")


def sheet(panels, titles, path, head):
    gap, pad = 14, 14
    n = len(panels)
    top = 96
    sh = Image.new("RGB", (pad + n * (W + gap), top + H + pad), (22, 20, 28))
    d = ImageDraw.Draw(sh)
    f = ImageFont.truetype(FONT, 30)
    try:
        f.set_variation_by_axes([800])
    except Exception:
        pass
    d.text((pad, 20), head, font=f, fill=(255, 255, 255))
    f2 = ImageFont.truetype(FONT, 20)
    for i, (p, t) in enumerate(zip(panels, titles)):
        x = pad + i * (W + gap)
        sh.paste(p, (x, top))
        d.text((x, top - 28), t, font=f2, fill=(200, 200, 210))
    sh.save(path, optimize=True)


# ---------------------------------------------------------------- current HUD, annotated
def current():
    geo = json.load(open(f"{SRC}/geometry.json"))
    k = W / 1080.0
    base = Image.open(f"{SRC}/race_hud_chase.png")
    c = Canvas(base)
    names = {"pause": "PAUSE", "camera": "CAM", "brake": "BRAKE", "gas": "GAS", "drift": "HANDBRAKE"}
    for key, label in names.items():
        x, y, w, h = [v * k for v in geo[key]]
        col = PINK if key in ("pause", "camera") else CYAN
        c.rr([x, y, x + w, y + h], 6, outline=col, width=3)
        if key in ("pause", "camera"):
            continue
        label_text = "%s %.1f x %.1f mm" % (label, geo[key][2] / 15.5, geo[key][3] / 15.5)
        if key == "drift":
            c.text((W - 8, y - 6), label_text, 17, color=col, anchor="rs", stroke=3)
        else:
            c.text((x + w / 2, y - 6), label_text, 17, color=col, anchor="ms", stroke=3)
    px, py, pw, ph = [v * k for v in geo["pause"]]
    c.text((W - 8, py + ph + 24), "PAUSE %.1f x %.1f mm  |  CAM %.1f x %.1f mm" % (
        geo["pause"][2] / 15.5, geo["pause"][3] / 15.5, geo["camera"][2] / 15.5, geo["camera"][3] / 15.5),
        17, color=PINK, anchor="rs", stroke=3)
    cx, cy = geo["joystick_center"][0] * k, geo["joystick_center"][1] * k
    c.circle((cx, cy), geo["joystick_radius"] * k, outline=CYAN, width=3)
    c.text((cx, cy - geo["joystick_radius"] * k - 8), "STEER ring %.0f mm" % (2 * geo["joystick_radius"] / 15.5), 17, color=CYAN, anchor="ms", stroke=3)
    # numbered findings
    badge(c, (30, 400), 1)
    badge(c, (712, 262), 2)
    badge(c, (30, 640), 3)
    badge(c, (640, 760), 4)
    badge(c, (120, 920), 5)
    badge(c, (22, 1260), 6)
    badge(c, (470, 1540), 7)
    return c.out()


# ---------------------------------------------------------------- Direction A: COCKPIT (one hardware language)
def hud_a():
    c = Canvas(Image.open(f"{SRC}/race_world_clean.png"))
    # header strip with the two keys inside its right end (96 px = 9.3 mm each)
    glass(c, [16, 18, 704, 126], 18)
    c.circle((70, 72), 36, outline=(255, 255, 255), width=3)
    c.text((130, 44), "LAP 1/3", 18, color=(190, 190, 205), weight=600)
    c.text((130, 66), "SHIN-KAWA", 24)
    c.text((130, 94), "NEXT 1 STAR  6,600", 17, color=GOLD, weight=700)
    c.text((470, 92), "0", 50, anchor="rs")
    c.text((470, 40), "BANKED SCORE", 13, color=(190, 190, 205), anchor="rs", weight=600)
    c.text((470, 110), "00:05.67", 15, color=(190, 190, 205), anchor="rs", weight=600)
    for i, lab in enumerate(["II", "CAM"]):
        x0 = 506 + i * 96
        glass(c, [x0, 24, x0 + 92, 120], 14, rim=VIOLET, alpha=240)
        c.text((x0 + 46, 72), lab, 24, anchor="mm")
    # callout feed: compact, top-left under the header, never over the road ahead
    glass(c, [16, 138, 330, 190], 12, rim=PINK, alpha=200)
    c.text((32, 164), "KERB CLIP ×1.5", 24, color=PINK, anchor="lm")
    glass(c, [16, 198, 360, 250], 12, rim=(255, 90, 90), alpha=200)
    c.text((32, 224), "WALL!  CHAIN LOST", 24, color=(255, 120, 120), anchor="lm")
    # cluster: gauge with the drift angle inside it
    c.circle((112, 1010), 92, fill=GLASS, alpha=225)
    c.arc((112, 1010), 90, 135, 400, PINK, 8)
    c.text((112, 1008), "77", 54, anchor="mm")
    c.text((112, 1046), "KM/H", 15, color=(190, 190, 205), anchor="mm", weight=600)
    glass(c, [60, 1086, 164, 1128], 10, rim=VIOLET)
    c.text((112, 1108), "ANGLE 5°", 17, anchor="mm")
    # steering stick: bigger ring + dead-zone mark (radius 17 mm)
    c.circle((178, 1410), 160, outline=(255, 255, 255), width=3, alpha=255)
    c.circle((178, 1410), 160, fill=GLASS, alpha=70)
    c.circle((178, 1410), 52, fill=(200, 205, 215))
    c.circle((178, 1410), 82, outline=(255, 255, 255), width=2)
    c.text((178, 1410 + 194), "STEER (dead zone ring)", 15, color=(190, 190, 205), anchor="mm", weight=600)
    # handbrake lever (hit zone 0.52-0.76 h), pedals larger and aligned to one baseline
    glass(c, [556, 840, 690, 1190], 18, rim=PINK)
    c.rr([600, 880, 646, 1090], 10, fill=(40, 36, 52))
    c.rr([596, 872, 650, 906], 10, fill=PINK)
    c.text((623, 1150), "HANDBRAKE", 17, anchor="mm")
    c.rr([352, 1390, 470, 1560], 16, fill=(205, 208, 216))
    c.text((411, 1475), "BRAKE", 22, color=(30, 30, 40), anchor="mm")
    c.rr([490, 1260, 702, 1560], 20, fill=(205, 208, 216))
    c.text((596, 1410), "GAS", 30, color=(30, 30, 40), anchor="mm")
    return c.out()


def home_a():
    c = Canvas()
    c.text((360, 120), "NITRO", 62, anchor="mm")
    c.text((360, 175), "WHEELZ", 62, color=VIOLET, anchor="mm")
    glass(c, [24, 230, 696, 310], 16, rim=VIOLET)
    c.circle((74, 270), 26, outline=PINK, width=3)
    c.text((118, 262), "KARLL", 26, anchor="lm")
    c.text((118, 292), "14 STARS TOTAL  •  NEXT UNLOCK AT 20", 15, color=GOLD, anchor="lm", weight=700)
    glass(c, [24, 336, 696, 700], 22, rim=PINK)
    c.text((52, 372), "CONTINUE", 17, color=(190, 190, 205), weight=600)
    c.text((52, 404), "SHIN-KAWA  •  RYU-32", 32)
    c.rr([52, 450, 668, 600], 14, fill=(30, 24, 46))
    c.text((360, 525), "(track + car preview)", 18, color=(130, 130, 150), anchor="mm", weight=500)
    c.rr([52, 618, 668, 684], 16, fill=PINK)
    c.text((360, 651), "START", 30, anchor="mm")
    glass(c, [24, 722, 350, 880], 18)
    c.text((187, 800), "PARK", 30, anchor="mm")
    c.text((187, 840), "LEARN • FREE DRIVE", 14, color=(190, 190, 205), anchor="mm", weight=600)
    glass(c, [370, 722, 696, 880], 18)
    c.text((533, 800), "TRACK BUILDER", 26, anchor="mm")
    # thumb-zone bottom navigation
    glass(c, [0, 1480, 720, 1600], 0, alpha=245)
    for i, lab in enumerate(["HOME", "GARAGE", "PARK", "PROFILE", "SETTINGS"]):
        x = 72 + i * 144
        c.circle((x, 1530), 22, outline=PINK if i == 0 else (130, 130, 150), width=3)
        c.text((x, 1578), lab, 15, color=PINK if i == 0 else (190, 190, 205), anchor="mm", weight=700)
    c.text((360, 1450), "v0.1.38   •   DEVELOPER: tap the version 7 times", 13, color=(110, 110, 130), anchor="mm", weight=500)
    return c.out()


def setup_a():
    c = Canvas()
    c.text((360, 70), "RACE SETUP", 34, anchor="mm")
    c.text((24, 150), "TRACK", 16, color=(190, 190, 205), weight=600)
    for i, (x0, nm) in enumerate([(24, "OVAL"), (260, "SHIN-KAWA"), (496, "SWEEPERS")]):
        glass(c, [x0, 176, x0 + 200, 400], 18, rim=PINK if i == 1 else (90, 90, 110))
        c.text((x0 + 100, 330), nm, 20, anchor="mm")
        c.text((x0 + 100, 366), "2 / 5 STARS" if i == 1 else "NO RUN", 15, color=GOLD if i == 1 else (150, 150, 170), anchor="mm", weight=700)
    c.text((360, 440), "swipe for more  •  MY TRACKS >", 14, color=(150, 150, 170), anchor="mm", weight=500)
    c.text((24, 500), "CAR", 16, color=(190, 190, 205), weight=600)
    glass(c, [24, 526, 696, 880], 22, rim=VIOLET)
    c.text((360, 700), "(3D car preview)", 18, color=(130, 130, 150), anchor="mm", weight=500)
    c.text((360, 840), "RYU-32 • DEEP BLUE", 26, anchor="mm")
    c.text((60, 700), "<", 40, anchor="mm")
    c.text((660, 700), ">", 40, anchor="mm")
    c.text((24, 930), "ONE primary action, always at the bottom (thumb zone)", 15, color=(150, 150, 170), weight=500)
    c.rr([24, 1440, 696, 1530], 20, fill=PINK)
    c.text((360, 1485), "DRIVE", 36, anchor="mm")
    c.text((360, 1568), "< BACK", 18, color=(190, 190, 205), anchor="mm", weight=700)
    return c.out()


# ---------------------------------------------------------------- Direction B: ARCADE (game first, flat pads)
def hud_b():
    c = Canvas(Image.open(f"{SRC}/race_world_clean.png"))
    # slim pill header; the minimap only on demand
    glass(c, [150, 24, 570, 84], 30, rim=PINK, alpha=190)
    c.text((200, 54), "1/3", 22, anchor="lm", color=(190, 190, 205))
    c.text((360, 52), "0", 36, anchor="mm")
    c.text((520, 54), "00:05.67", 20, anchor="rm", color=(190, 190, 205))
    c.rr([160, 86, 560, 92], 3, fill=(60, 50, 80), alpha=200)
    c.rr([160, 86, 300, 92], 3, fill=GOLD)
    for x0, lab in [(20, "II"), (604, "CAM")]:
        c.circle((x0 + 48, 70), 48, fill=GLASS, alpha=190)
        c.circle((x0 + 48, 70), 48, outline=VIOLET, width=3)
        c.text((x0 + 48, 70), lab, 24, anchor="mm")
    # callouts: centred chips under the pill
    c.rr([200, 112, 520, 158], 22, fill=GLASS, alpha=190)
    c.text((360, 135), "KERB CLIP ×1.5", 22, color=PINK, anchor="mm")
    # speed: numerals only, angle as a thin arc; no dial
    c.text((26, 1020), "77", 110, anchor="ls", stroke=4)
    c.text((172, 1020), "KM/H", 20, anchor="ls", color=(220, 220, 230), stroke=3, weight=600)
    c.arc((82, 960), 150, 200, 250, PINK, 10)
    c.text((26, 1062), "5° ANGLE", 24, anchor="ls", color=PINK, stroke=3)
    # flat translucent pads in the thumb arcs, all >= 14 mm
    c.circle((150, 1420), 130, fill=(255, 255, 255), alpha=40)
    c.circle((150, 1420), 130, outline=(255, 255, 255), width=3)
    c.circle((150, 1420), 44, fill=(255, 255, 255), alpha=170)
    c.circle((590, 1440), 112, fill=PINK, alpha=190)
    c.circle((590, 1440), 112, outline=(255, 255, 255), width=4)
    c.text((590, 1440), "GAS", 34, anchor="mm", stroke=2)
    c.circle((392, 1500), 74, fill=(200, 205, 215), alpha=170)
    c.circle((392, 1500), 74, outline=(255, 255, 255), width=3)
    c.text((392, 1500), "BRAKE", 20, anchor="mm", color=(20, 20, 30))
    c.rr([470, 1232, 702, 1326], 47, fill=VIOLET, alpha=205)
    c.rr([470, 1232, 702, 1326], 47, outline=(255, 255, 255), width=3)
    c.text((586, 1279), "DRIFT", 30, anchor="mm", stroke=2)
    return c.out()


def home_b():
    c = Canvas()
    c.text((360, 90), "NITRO WHEELZ", 40, anchor="mm")
    glass(c, [24, 150, 696, 226], 16, rim=VIOLET)
    c.circle((70, 188), 24, outline=PINK, width=3)
    c.text((112, 188), "KARLL  •  14 STARS", 24, anchor="lm")
    # the rest of the screen is the thumb zone: ONE primary, then equal secondaries
    for i, (lab, sub) in enumerate([("TRACK BUILDER", ""), ("SETTINGS", ""), ("GARAGE", "RYU-32 • DEEP BLUE"), ("PARK", "TUTORIAL 1/10")]):
        y = 560 + i * 110
        glass(c, [24, y, 696, y + 90], 16, rim=(90, 90, 110))
        c.text((360, y + (36 if sub else 45)), lab, 28, anchor="mm")
        if sub:
            c.text((360, y + 68), sub, 15, color=(170, 170, 190), anchor="mm", weight=600)
    c.rr([24, 1020, 696, 1150], 24, fill=PINK)
    c.text((360, 1070), "RACE", 48, anchor="mm")
    c.text((360, 1118), "SHIN-KAWA  •  RYU-32", 20, anchor="mm", weight=600)
    c.text((360, 1560), "v0.1.38", 14, color=(110, 110, 130), anchor="mm", weight=500)
    c.text((24, 1210), "Same flow as today, but: one glowing primary at the bottom,", 15, color=(150, 150, 170), weight=500)
    c.text((24, 1234), "the logo only on this page, DEVELOPER hidden (version tapped 7x).", 15, color=(150, 150, 170), weight=500)
    return c.out()


def setup_b():
    c = Canvas()
    c.text((360, 70), "RACE", 34, anchor="mm")
    glass(c, [24, 130, 696, 400], 22, rim=PINK)
    c.text((52, 160), "TRACK", 16, color=(190, 190, 205), weight=600)
    c.text((52, 200), "SHIN-KAWA", 38)
    c.text((52, 252), "2 / 5 STARS   •   BEST 28,400", 20, color=GOLD, weight=700)
    c.text((52, 340), "CHANGE >", 20, color=PINK)
    glass(c, [24, 430, 696, 760], 22, rim=VIOLET)
    c.text((52, 460), "CAR", 16, color=(190, 190, 205), weight=600)
    c.text((52, 500), "RYU-32  •  DEEP BLUE", 30)
    c.text((52, 700), "CHANGE >", 20, color=VIOLET)
    c.rr([24, 1380, 696, 1500], 24, fill=PINK)
    c.text((360, 1440), "DRIVE", 44, anchor="mm")
    c.text((360, 1560), "< BACK", 18, color=(190, 190, 205), anchor="mm", weight=700)
    return c.out()


WHITE = (255, 255, 255)
import os
os.makedirs(OUT, exist_ok=True)
cur = current()
sheet([cur, Image.open(f"{SRC}/menu_main.png").convert("RGB"), Image.open(f"{SRC}/menu_setup.png").convert("RGB")],
      ["RACE HUD v0.1.38 (real frame) with the touch hit areas", "HOME (real)", "RACE SETUP (real)"],
      f"{OUT}/issue-28-current-annotated.png", "#28 CURRENT UI: touch areas in mm and numbered findings (1-7)")
sheet([hud_a(), home_a(), setup_a()], ["A  COCKPIT: race HUD (mock-up over a real frame)", "A  HOME hub + bottom navigation", "A  RACE SETUP: carousels, one DRIVE"],
      f"{OUT}/issue-28-direction-A-cockpit.png", "#28 DIRECTION A: NITRO COCKPIT (one hardware language, familiar layout)")
sheet([hud_b(), home_b(), setup_b()], ["B  ARCADE: race HUD (mock-up over a real frame)", "B  HOME: one primary action", "B  RACE: one summary screen"],
      f"{OUT}/issue-28-direction-B-arcade.png", "#28 DIRECTION B: NITRO ARCADE (game first, flat pads in the thumb arcs)")
print("ok")
