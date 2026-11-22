#!/usr/bin/env python3
"""Issue #25 audit: a transparent physical reference model of straight-line performance,
compared with what the game's drive model actually does (tests/car_performance_audit.gd).

NOT a simulator and NOT the proposed game physics: it answers "is a number credible?"
with a handful of stated assumptions, so the owner can see which inputs matter.

  godot --headless --path game --script res://tests/car_performance_audit.gd | grep AUDIT_JSON | sed 's/^AUDIT_JSON //' > audit.json
  python3 tools/perf/reference_model.py audit.json [--chart docs/dev/handoffs/evidence/issue-25-accel-curves.png]

Reference model (per car): wheel power P_w = eta * P_engine, traction limit a_tr, quadratic
drag + rolling resistance:
    a(v) = min(a_tr, P_w / (m v)) - rho * CdA * v^2 / (2 m) - Crr * g
Gears, shift time, torque curve and boost are NOT modelled (power is taken as available at
every speed): the result is an optimistic envelope, good for 0-100 / mid-range pull and a
power / drag limited top speed; the real top speed is often gearing- or limiter-limited.
"""
import argparse
import json
import math

RHO = 1.2          # air density kg/m3
CRR = 0.012        # rolling resistance coefficient
ETA = 0.85         # drivetrain efficiency (manual RWD, propshaft + diff)
G = 9.81
A_TRACTION = 5.5   # m/s2 launch limit of a RWD street-tyre car (rear load share x mu ~ 0.56 g)

# status: C = confirmed (published), E = estimate (named), M = missing build data.
CARS = {
    "red": {"label": "LADA 2106 RED - 13B rotary", "ps": 231, "mass": 1150, "cda": 0.85,
            "status": {"power": "C series 231 PS of the donor engine; build gain M", "mass": "E 1,035 kg shell + engine / box / cage",
                       "cda": "E Cd ~0.45-0.50 x 1.8-1.9 m2"}},
    "white": {"label": "LADA 2106 WHITE - N20B20 turbo (approved)", "ps": 245, "mass": 1100, "cda": 0.85,
              "status": {"power": "C stock 245 PS / 350 Nm (BMW 328i); tune M", "mass": "M (placeholder 1,100 kg)",
                         "cda": "E as the red body"}},
    "e30": {"label": "E30 BLESSED - M52B28", "ps": 193, "mass": 1250, "cda": 0.70,
            "status": {"power": "C factory reference 193 PS / 280 Nm (not dyno)", "mass": "E research tuning start 1,250 kg",
                       "cda": "E Cd ~0.36-0.38 x 1.9 m2"}},
    "blue": {"label": "RYU-32 - 4.0 V8 ITB", "ps": 355, "mass": 1300, "cda": 0.70,
             "status": {"power": "C owner reference 350 HP", "mass": "E 1,300 kg for a V8-swapped coupe, M",
                        "cda": "E Cd ~0.36-0.40 x 1.85 m2"}},
}


def accel(v, car):
    pw = ETA * car["ps"] * 735.5
    a_drive = min(A_TRACTION, pw / (car["mass"] * max(v, 0.5)))
    return a_drive - RHO * car["cda"] * v * v / (2.0 * car["mass"]) - CRR * G


def run(car, dt=0.002, t_max=90.0):
    v = 0.0
    t = 0.0
    times = {}
    marks = [60, 100, 120, 150, 200]
    top = 0.0
    while t < t_max:
        a = accel(v, car)
        if a <= 0.02:
            break
        v += a * dt
        t += dt
        kmh = v * 3.6
        for m in marks:
            if m not in times and kmh >= m:
                times[m] = round(t, 2)
    # power / drag limited top speed: a(v) = 0
    lo, hi = 1.0, 120.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if accel(mid, car) > 0:
            lo = mid
        else:
            hi = mid
    return times, round(lo * 3.6, 1)


def game_accel(v_kmh, h):
    v = v_kmh / 3.6
    a = h["drive_accel"] - h["rolling_drag"] - h["drag_coeff"] * v * v
    cap = h["top_speed_mps"] - 5.0
    if v > cap:
        a *= max(0.0, 1.0 - (v - cap) / 5.0)
    return a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("audit")
    ap.add_argument("--chart")
    args = ap.parse_args()
    audit = json.load(open(args.audit))
    rows = []
    print("| car | game 0-100 | model 0-100 | game top | model top (power/drag) | game a(100) | model a(100) | game a(120) | model a(120) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for key, car in CARS.items():
        g = audit[key]
        times, top = run(car)
        ga100 = game_accel(100.0, g)
        ga120 = game_accel(120.0, g)
        ma100 = accel(100 / 3.6, car)
        ma120 = accel(120 / 3.6, car)
        print("| %s | %s s | %s s | %.1f km/h | %.1f km/h | %.1f m/s2 | %.1f m/s2 | %.1f m/s2 | %.1f m/s2 |" % (
            car["label"], g["times"].get("100"), times.get(100), g["top_kmh"], top, ga100, ma100, ga120, ma120))
        rows.append((key, car, g, times, top))
    if args.chart:
        chart(rows, audit, args.chart)


def chart(rows, audit, path):
    from PIL import Image, ImageDraw, ImageFont
    W, H = 1500, 820
    im = Image.new("RGB", (W, H), (18, 14, 28))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
        fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
    except OSError:
        f = fb = ImageFont.load_default()
    x0, y0, x1, y1 = 110, 90, W - 40, H - 120
    vmax, amax = 260.0, 12.0
    px = lambda v: x0 + (x1 - x0) * v / vmax
    py = lambda a: y1 - (y1 - y0) * a / amax
    d.text((x0, 24), "Acceleration vs speed: the game (solid) vs a reference physical model (dashed)", font=fb, fill=(240, 240, 250))
    for v in range(0, 261, 20):
        d.line([(px(v), y0), (px(v), y1)], fill=(50, 44, 70), width=1)
        d.text((px(v) - 14, y1 + 8), str(v), font=f, fill=(190, 190, 210))
    for a in range(0, 13, 2):
        d.line([(x0, py(a)), (x1, py(a))], fill=(50, 44, 70), width=1)
        d.text((x0 - 44, py(a) - 10), str(a), font=f, fill=(190, 190, 210))
    d.text((x1 - 190, y1 + 36), "speed km/h", font=f, fill=(190, 190, 210))
    d.text((12, y0 - 34), "accel m/s2", font=f, fill=(190, 190, 210))
    colours = {"red": (255, 90, 120), "white": (240, 240, 245), "e30": (255, 200, 70), "blue": (90, 170, 255)}
    shown = ["red", "e30", "blue"]
    ly = 28
    for key, car, g, times, top in rows:
        if key not in shown:
            continue
        col = colours[key]
        pts = []
        for v in range(0, 261, 2):
            pts.append((px(v), py(max(0.0, game_accel(float(v), g)))))
        d.line(pts, fill=col, width=4)
        # dashed model
        seg = []
        for v in range(1, 261):
            a = accel(v / 3.6, car)
            if a <= 0:
                break
            seg.append((px(v), py(a)))
        for i in range(0, len(seg) - 1, 6):
            d.line([seg[i], seg[min(i + 3, len(seg) - 1)]], fill=col, width=3)
        lx = x0 + shown.index(key) * 450
        d.rectangle([lx, H - 52, lx + 26, H - 38], fill=col)
        d.text((lx + 34, H - 58), car["label"].split(" - ")[0].replace("LADA 2106 ", "Lada ").replace(" BLESSED", "") + ": game top %.0f, model %.0f km/h" % (g["top_kmh"], rows[[r[0] for r in rows].index(key)][4]), font=f, fill=(225, 225, 240))
    d.text((x0, H - 28), "model: wheel power = 0.85 x engine, traction cap 5.5 m/s2, Cd*A and mass in tools/perf/reference_model.py (estimates, no gearbox)", font=f, fill=(170, 170, 190))
    im.save(path)
    print("chart ->", path)


if __name__ == "__main__":
    main()
