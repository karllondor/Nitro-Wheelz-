#!/usr/bin/env python3
"""Run the shipped Linux game using OS pointer/keyboard events inside X11."""
import argparse
import ctypes as c
import os
from pathlib import Path
import re
import subprocess
import tempfile

from PIL import ImageGrab

from qa_platform_runtime import RuntimeChecks, frame_metrics


class X11Input:
    def __init__(self):
        self.x = c.CDLL("libX11.so.6")
        self.xt = c.CDLL("libXtst.so.6")
        self.x.XOpenDisplay.restype = c.c_void_p
        self.x.XStringToKeysym.restype = c.c_ulong
        self.x.XKeysymToKeycode.argtypes = [c.c_void_p, c.c_ulong]
        self.x.XFlush.argtypes = [c.c_void_p]
        self.x.XCloseDisplay.argtypes = [c.c_void_p]
        handle = self.x.XOpenDisplay(None)
        assert handle, "X11 display unavailable"
        self.display = c.c_void_p(handle)

    def image(self):
        return ImageGrab.grab(xdisplay=os.environ["DISPLAY"])

    def click(self, x, y):
        self.xt.XTestFakeMotionEvent(self.display, -1, x, y, 0)
        for down in (1, 0):
            self.xt.XTestFakeButtonEvent(self.display, 1, down, 0)
        self.x.XFlush(self.display)

    def key(self, name, down):
        name = {"Enter": "Return", "Space": "space", " ": "space"}.get(name, name.lower() if len(name) == 1 else name)
        code = self.x.XKeysymToKeycode(self.display, self.x.XStringToKeysym(name.encode()))
        assert code, name
        self.xt.XTestFakeKeyEvent(self.display, code, int(down), 0)
        self.x.XFlush(self.display)

    def type(self, value):
        for char in value:
            self.key(char, True)
            self.key(char, False)

    def close(self):
        self.x.XCloseDisplay(self.display)


def run(executable, output):
    assert executable.stat().st_size > 1000000 and os.access(executable, os.X_OK)
    pointer = X11Input()
    qa = RuntimeChecks(pointer, output, "linux")
    fps_log = output / "linux_runtime.log"
    with tempfile.TemporaryDirectory() as profile, fps_log.open("w") as log:
        proc = subprocess.Popen([
            str(executable.resolve()), "--audio-driver", "Dummy", "--disable-vsync",
            "--resolution", "1280x720", "--position", "0,0", "--print-fps",
        ], env={**os.environ, "LIBGL_ALWAYS_SOFTWARE":"1", "XDG_DATA_HOME":profile}, stdout=log, stderr=subprocess.STDOUT)
        try:
            qa.run()
            assert proc.poll() is None, "Native binary stopped during the tests"
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
            pointer.close()
    runtime_log = fps_log.read_text(errors="replace")
    errors = [line for line in runtime_log.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    assert not errors, errors
    fps = [float(f) for f in re.findall(r"Project FPS: (\d+(?:\.\d+)?)", runtime_log) if float(f) > 0]
    if fps:
        qa.verdict["mixed_runtime_engine_samples"] = frame_metrics([1000/f for f in fps[-25:]])
    qa.save()
    print("PASS: shipped Linux binary, X11 keyboard/mouse, Park presets and lights", qa.verdict)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    run(args.binary, args.output.resolve())
