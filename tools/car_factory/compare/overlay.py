"""Photo | same-camera render | overlay sheet (cyan = model outline, red = picked
pixel, green = projected model keypoint). Usage (run in the folder that holds
cams.json, render_<photo>.png (magenta background) and grey_<photo>.png):
  python overlay.py /path/to/photos/
The sheets contain the reference photos: keep them out of the public repo."""
import json, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
P = sys.argv[1]
cams = json.load(open("cams.json"))
for c in cams:
    name = c["photo"]
    photo = Image.open(P + name + ".jpg").convert("RGB")
    W, H = photo.size
    rend = Image.open("render_" + name + ".png").convert("RGB").resize((W, H))
    a = np.asarray(rend).astype(int)
    mask = ~((a[..., 0] > 200) & (a[..., 1] < 60) & (a[..., 2] > 200))
    # outline of the model silhouette
    m = Image.fromarray((mask * 255).astype(np.uint8))
    edge = np.asarray(m.filter(ImageFilter.FIND_EDGES)) > 0
    edge = np.asarray(Image.fromarray((edge * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    ov = np.asarray(photo).copy()
    blend = (np.asarray(photo) * 0.45 + a * 0.55).astype(np.uint8)
    ov[mask] = blend[mask]
    ov[edge] = (0, 255, 255)
    over = Image.fromarray(ov)
    d = ImageDraw.Draw(over)
    for k, q in c["picked"].items():
        p = c["projected"][k]
        d.ellipse((q[0] - 7, q[1] - 7, q[0] + 7, q[1] + 7), outline=(255, 40, 40), width=3)
        d.line((q[0], q[1], p[0], p[1]), fill=(255, 255, 0), width=2)
        d.ellipse((p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4), fill=(40, 255, 80))
    clean = Image.open("grey_" + name + ".png").convert("RGB").resize((W, H))
    scale = 700 / H
    tiles = [photo, clean, over]
    tiles = [t.resize((int(W * scale), 700)) for t in tiles]
    out = Image.new("RGB", (sum(t.width for t in tiles) + 20, 740), (24, 24, 28))
    x = 0
    for t in tiles:
        out.paste(t, (x, 40)); x += t.width + 10
    d = ImageDraw.Draw(out)
    d.text((8, 10), "%s | photo | Godot render, same solved camera | overlay (cyan = model outline, red = picked point, green = model point) | RMS %.1f px = %.1f%% of keypoint span" % (name, c["rms_px"], c["rms_pct_of_keypoint_span"]), fill=(255, 255, 255))
    out.save("compare_" + name + ".png")
    print(name, out.size)
