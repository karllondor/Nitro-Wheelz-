#!/usr/bin/env python3
"""Run the shipped Godot Web export in Chromium with real mouse and keys."""
import argparse
from functools import partial
import http.server
import io
import os
from pathlib import Path
import threading

from PIL import Image
from playwright.sync_api import sync_playwright

from qa_platform_runtime import RuntimeChecks, frame_metrics, image_delta


class BrowserInput:
    def __init__(self, page):
        self.page = page

    def image(self):
        return Image.open(io.BytesIO(self.page.screenshot(timeout=20000)))

    def click(self, x, y):
        self.page.mouse.click(x, y)

    def key(self, name, down):
        (self.page.keyboard.down if down else self.page.keyboard.up)(name)

    def type(self, text):
        self.page.keyboard.type(text, delay=28)


def run(directory, output):
    directory = directory.resolve()
    assert all((directory / file).stat().st_size for file in ("index.html", "index.wasm", "index.pck"))
    handler = partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server, sync_playwright() as playwright:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            browser = playwright.chromium.launch(headless=True, executable_path=os.getenv("CHROMIUM") or None, args=[
                "--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl", "--ignore-gpu-blocklist",
                "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            ])
            page = browser.new_page(viewport={"width":1280,"height":720})
            errors, console = [], []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda entry: console.append(f"{entry.type}: {entry.text}"))
            qa = RuntimeChecks(BrowserInput(page), output, "web")
            try:
                assert page.evaluate("!!document.createElement('canvas').getContext('webgl2')"), "WebGL2 unavailable"
                url = f"http://127.0.0.1:{server.server_port}/"
                assert page.goto(url, wait_until="domcontentloaded", timeout=90000).status == 200
                page.wait_for_function("document.querySelector('canvas')?.width >= 200", timeout=90000)
                qa.run()
                qa.verdict["browser"] = browser.version
                qa.verdict["webgl2"] = True
                samples = page.evaluate("""() => new Promise(resolve => {
                    let previous = 0, samples = [];
                    function frame(now) {
                        if (previous) samples.push(now - previous);
                        previous = now;
                        if (samples.length === 64) resolve(samples);
                        else requestAnimationFrame(frame);
                    }
                    requestAnimationFrame(frame);
                })""")
                qa.verdict["browser_raf_frame_cadence"] = frame_metrics(samples)
                page.set_viewport_size({"width":800,"height":600})
                page.wait_for_timeout(750)
                prior = qa.capture("16-web-800x600")
                qa.action(camera=True)
                later = qa.capture("17-web-800x600-camera")
                # Include the horizon that disappears on the switch to Top-down.
                # The middle of the dark Park alone changes little in small canvases.
                camera_delta = image_delta(prior, later, (160,36,640,300))
                assert camera_delta > 6, f"800x600 CAMERA target did not change the view: {camera_delta}"
                qa.verdict["narrow_camera_delta"] = round(camera_delta, 2)
                qa.pause()
                qa.capture("18-web-800x600-pause")
                qa.resume()
                assert not errors, errors
                fatal = [line for line in console if any(word in line.lower() for word in (
                    "script error", "failed to compile", "webgl context lost", "runtimeerror", "out of memory",
                ))]
                assert not fatal, fatal
                qa.save()
                print("PASS: shipped Web game, WebGL2, keyboard/mouse, Park presets and lights", qa.verdict)
            finally:
                (output / "browser_console.txt").write_text("\n".join(console + errors) + "\n")
                browser.close()
        finally:
            server.shutdown()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    run(args.build, args.output.resolve())
