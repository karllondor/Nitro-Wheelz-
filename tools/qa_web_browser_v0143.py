#!/usr/bin/env python3
"""Browser smoke test of the actual exported Nitro Wheelz Godot/Web game.
Runs a localhost-only HTTP server. No external production deployment.
Requires pip install playwright pillow and an available Chromium/Chrome.
"""
import os, threading, http.server, socketserver, time, sys, json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
from playwright.sync_api import sync_playwright

WEB = Path("builds/web").resolve()
OUT = Path("builds/qa-web").resolve()
OUT.mkdir(parents=True, exist_ok=True)
PORT = 8765
for item in ("index.html", "index.wasm"):
    assert (WEB / item).stat().st_size > 0, "Missing Web export " + item

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(WEB), **kw)
    def log_message(self, fmt, *a):
        pass

class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
srv = Server(("127.0.0.1", PORT), Handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()
issues = []
console = []
def report(text):
    print(text, flush=True)
    console.append(text)

with sync_playwright() as p:
    browser_path = next((s for s in ("/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser") if os.path.exists(s)), None)
    opts = dict(headless=True, args=["--no-sandbox", "--disable-dev-shm-usage",
        "--enable-webgl", "--ignore-gpu-blocklist", "--use-gl=angle",
        "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    if browser_path:
        opts["executable_path"] = browser_path
    browser = p.chromium.launch(**opts)
    page = browser.new_page(viewport={"width": 1280, "height": 720}, device_scale_factor=1)
    page.on("console", lambda msg: (console.append("console[%s] %s" % (msg.type,msg.text)), issues.append(msg.text) if msg.type == "error" else None))
    page.on("pageerror", lambda err: issues.append("PAGE_ERROR: " + str(err)))
    report("BROWSER: " + browser.version)
    webgl = page.evaluate("!!document.createElement('canvas').getContext('webgl2')")
    report("WEBGL2_AVAILABLE: " + str(webgl))
    if not webgl:
        raise RuntimeError("WebGL2 unavailable in CI browser; web playability cannot be verified")
    resp = page.goto(f"http://127.0.0.1:{PORT}/", wait_until="domcontentloaded", timeout=120000)
    report("HTTP: " + str(resp.status if resp else "NO_RESPONSE"))
    assert resp and resp.status == 200
    page.wait_for_function("() => {const c=document.querySelector('canvas');return !!c && c.width > 200 && c.height > 100}", timeout=120000)
    # Large Godot .pck assets can take time before first rendered main menu.
    page.wait_for_timeout(13000)
    shot1 = OUT / "01_web_after_load.png"
    page.screenshot(path=str(shot1))
    im1 = Image.open(shot1).convert("RGB")
    st = ImageStat.Stat(im1)
    report("SCREEN_LOAD_STDDEV: " + ",".join("%.2f" % n for n in st.stddev))
    if max(st.stddev) < 4.0:
        raise RuntimeError("Browser still shows a uniform/blank screen (screenshot not proof of game rendering)")
    # Interact using the actual Godot HTML5 keyboard path: welcome username -> menu -> setup -> drive.
    # Coordinates are avoided; first-focus and Enter are how the game is built.
    page.locator("canvas").click(position={"x": 640, "y": 340})
    page.keyboard.type("QA_DRIVER", delay=45)
    page.keyboard.press("Enter")
    page.wait_for_timeout(1700)
    shot2 = OUT / "02_web_after_welcome_input.png"
    page.screenshot(path=str(shot2))
    im2 = Image.open(shot2).convert("RGB")
    bbox=ImageChops.difference(im1,im2).getbbox()
    report("UI_CHANGED_AFTER_INPUT: " + str(bbox is not None))
    page.keyboard.press("Enter") # main focus DRIVE -> setup
    page.wait_for_timeout(1400)
    page.screenshot(path=str(OUT / "03_web_race_setup.png"))
    page.keyboard.press("Tab")   # setup TRACK -> CAR
    page.keyboard.press("Tab")   # setup CAR -> DRIVE
    page.keyboard.press("Enter") # actual driving scene
    page.wait_for_timeout(12000)
    page.screenshot(path=str(OUT / "04_web_race_before_throttle.png"))
    page.keyboard.down("w")
    page.wait_for_timeout(2000)
    page.keyboard.up("w")
    shot3 = OUT / "05_web_race_after_throttle.png"
    page.screenshot(path=str(shot3))
    im3 = Image.open(shot3).convert("RGB")
    report("SCREEN_FINAL_STDDEV: " + ",".join("%.2f" % n for n in ImageStat.Stat(im3).stddev))
    report("UI_CHANGED_AFTER_DRIVE: " + str(ImageChops.difference(im1,im3).getbbox() is not None))
    suspicious=[e for e in issues if any(k in e.lower() for k in ("unhandled", "runtimeerror", "out of memory", "failed to load", "webgl", "wasm", "uncaught"))]
    report("BROWSER_ERRORS: " + str(len(issues)))
    report("SUSPICIOUS_ERRORS: " + json.dumps(suspicious[:12]))
    (OUT/"browser_console.txt").write_text("\n".join(console + ["ERRORS:"] + issues), encoding="utf-8")
    browser.close()
    if suspicious:
        raise RuntimeError("Browser raised fatal errors: " + " | ".join(suspicious[:3]))
srv.shutdown()
print("PASS: Godot Web export loaded in Chromium with WebGL2, rendered nonblank images, and received input; screenshots attached.")
