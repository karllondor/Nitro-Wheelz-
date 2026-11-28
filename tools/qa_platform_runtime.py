"""Shared pixel and input checks for the exported Linux and Web games."""
import csv
import io
import json
import re
import subprocess
import time
from statistics import median

from PIL import Image, ImageChops, ImageStat


def text_points(image, target, area=None):
    x, y = area[:2] if area else (0, 0)
    crop = image.crop(area) if area else image
    stream = io.BytesIO()
    gray = crop.convert("L").point(lambda value: 255 if value > 150 else 0)
    gray.resize((crop.width * 2, crop.height * 2)).save(stream, "PNG")
    data = subprocess.run(
        ["tesseract", "stdin", "stdout", "--psm", "11", "tsv"],
        input=stream.getvalue(), capture_output=True, check=True, timeout=30,
    ).stdout.decode()
    lines = {}
    for word in csv.DictReader(io.StringIO(data), delimiter="\t"):
        clean = re.sub("[^A-Z0-9.]", "", (word.get("text") or "").upper())
        if clean:
            key = tuple(word[k] for k in ("block_num", "par_num", "line_num"))
            lines.setdefault(key, []).append((clean, *(int(word[k]) for k in ("left", "top", "width", "height"))))
    target = target.upper().split()
    for words in lines.values():
        for i in range(len(words) - len(target) + 1):
            selected = words[i:i + len(target)]
            if [w[0] for w in selected] == target:
                first, last = selected[0], selected[-1]
                yield x + round((first[1] + last[1] + last[3]) / 4), y + round((first[2] + first[4] / 2) / 2)


def image_delta(a, b, box):
    return ImageStat.Stat(ImageChops.difference(a.crop(box), b.crop(box)).convert("L")).mean[0]


def foreground(image):
    w, h = image.size
    return w // 4, h // 5, 3 * w // 4, 4 * h // 5


def lamp_gain(enabled, disabled):
    w, h = enabled.size
    # Central forward asphalt, away from HUD and car/dashboard.
    box = (int(w * .38), int(h * .27), int(w * .62), int(h * .54))
    gain = ImageChops.subtract(enabled.crop(box).convert("L"), disabled.crop(box).convert("L"))
    return sum(gain.histogram()[5:])


def red_pixels(image):
    w, h = image.size
    car_region = image.crop((int(w * .43), int(h * .46), int(w * .57), int(h * .79)))
    return sum(1 for r, g, b in car_region.getdata() if r > 225 and r > 1.7 * max(g, b, 1))


class RuntimeChecks:
    def __init__(self, driver, output, profile):
        self.driver = driver
        self.output = output
        self.profile = profile
        self.verdict = {}
        output.mkdir(parents=True, exist_ok=True)

    def capture(self, label=None):
        image = self.driver.image().convert("RGB")
        if label:
            image.save(self.output / (label + ".png"))
        return image

    def expect(self, label, area=None, timeout=40):
        stop = time.monotonic() + timeout
        while time.monotonic() < stop:
            image = self.capture()
            hits = list(text_points(image, label, area))
            if hits:
                return hits[0]
            time.sleep(.25)
        self.capture("failure")
        raise AssertionError(f"Could not find {label!r} in the running {self.profile} game")

    def select(self, label, area=None):
        self.driver.click(*self.expect(label, area))
        time.sleep(.5)

    def confirm(self, button):
        x, y = self.expect(button)
        self.driver.click(x, y)
        time.sleep(.28)
        self.driver.click(x, y)
        time.sleep(.65)

    def key(self, name, hold=.13):
        self.driver.key(name, True)
        time.sleep(hold)
        self.driver.key(name, False)
        time.sleep(.4)

    def action(self, camera):
        # PR #36 actions are positioned in Godot's 1280x720 stretch/expand space.
        w, h = self.capture().size
        scale = min(w / 1280, h / 720)
        vw, vh = w / scale, h / scale
        edge = min(19, max(14 if self.profile == "web" else 9, min(vw, vh) * .018))
        gap = min(14, max(7, vw * .009))
        button = min(86, max(61, vw * .059))
        height = min(43, max(35, vh * .062))
        distance = button * 1.5 + gap if camera else button / 2
        self.driver.click(round((vw - edge - distance) * scale), round((edge + height / 2) * scale))
        time.sleep(.72)

    def pause(self):
        self.action(camera=False)
        self.expect("PAUSED")

    def resume(self):
        self.select("RESUME")
        if self.capture().width >= 1280:
            self.expect("CAMERA")
            return
        # The small Web canvas can render CAMERA below reliable OCR size.
        # PAUSED is a large, unambiguous indicator that the modal is still open.
        stop = time.monotonic() + 12
        while time.monotonic() < stop:
            if not list(text_points(self.capture(), "PAUSED")):
                return
            time.sleep(.25)
        self.capture("failure")
        raise AssertionError("RESUME did not close the pause menu in the narrow canvas")

    def pause_option(self, label, options, vertical):
        self.pause()
        self.expect("RESUME")
        w, h = self.capture().size
        assert (w, h) == (1280, 720), "lighting interaction uses the 1280x720 reference viewport"
        # The small stylised buttons can defeat OCR, especially inactive heads.
        # Use the real pointer on the equal-width rows of this reference view.
        panel = min(w * .84, h * 1.1)
        start = (w - panel) / 2 + 19
        end = (w + panel) / 2 - 31
        slot = options.index(label) + .5
        x = round(start + (end - start) * slot / len(options))
        for attempt in range(2):
            self.driver.click(x, round(h * vertical))
            time.sleep(.55)
            # On virtual X11 a queued resume can be rendered after the next
            # click was submitted. Re-open once if the current frame is already driving.
            frame = self.capture()
            if list(text_points(frame, "RESUME")):
                self.resume()
                return
            self.expect("CAMERA")
            if attempt == 0:
                self.pause()
                self.expect("RESUME")
        self.capture("failure")
        raise AssertionError(f"No stable pause menu while selecting {label}")

    def switch_time(self, label):
        self.pause_option(label, ("DAWN", "DAY", "GOLDEN HOUR", "NIGHT"), .855)

    def switch_lamps(self, label):
        self.pause_option(label, ("AUTO", "ON", "OFF"), .73)

    def official(self):
        self.expect("WELCOME")
        self.capture("01-welcome")
        self.driver.type("PLATFORM QA")
        self.key("Enter")
        self.select("DRIVE")
        self.expect("YOUR RACE")
        self.capture("02-race-setup")
        self.expect("GOLDEN HOUR")
        self.select("DRIVE")
        self.expect("LAP")
        start = self.capture("03-circuit-top-down")
        self.key("w", 1.65)
        moved = self.capture("04-keyboard-throttle")
        delta = image_delta(start, moved, foreground(start))
        assert delta > 3, f"Throttle did not alter the circuit view: {delta}"
        self.key("r")
        self.pause()
        self.confirm("RESTART")
        self.expect("LAP")
        self.pause()
        self.confirm("GARAGE MENU")
        self.expect("NITRO WHEELZ PARK")
        self.verdict["official_throttle_delta"] = round(delta, 2)

    def park(self):
        self.select("NITRO WHEELZ PARK")
        self.select("FREE DRIVE")
        self.expect("CAMERA")
        before = self.capture("05-park-top-down")
        self.action(camera=True)
        chase = self.capture("06-park-chase")
        delta = image_delta(before, chase, foreground(before))
        assert delta > 8, f"Camera click did not switch the Park view: {delta}"
        self.key("c")
        down = self.capture()
        assert image_delta(down, chase, foreground(down)) > 8, "Keyboard C did not return to Top-down"
        self.key("Escape")
        self.expect("PAUSED")
        self.resume()
        presets = []
        for label in ("DAWN", "DAY", "GOLDEN HOUR", "NIGHT"):
            self.switch_time(label)
            presets.append(self.capture(f"07-{label.lower().replace(' ', '-')}"))
        preset_change = [image_delta(a, b, foreground(a)) for a, b in zip(presets, presets[1:])]
        assert all(delta > 2 for delta in preset_change), f"Some Park presets did not visibly change the view: {preset_change}"
        self.verdict["preset_transition_deltas"] = [round(delta, 2) for delta in preset_change]
        on = self.capture("08-night-headlights-auto")
        self.switch_lamps("OFF")
        off = self.capture("09-night-headlights-off")
        gain = lamp_gain(on, off)
        assert gain > 80, f"No measurable headlight gain on rendered asphalt: {gain} pixels"
        self.switch_lamps("ON")
        manual = self.capture("10-night-headlights-on")
        assert lamp_gain(manual, off) > 80, "Manual ON did not relight asphalt"
        self.switch_lamps("AUTO")
        self.action(camera=True)
        self.capture("11-night-chase-position")
        self.switch_time("DAY")
        self.switch_lamps("OFF")
        released = self.capture("12-day-released-off")
        self.driver.key("Space", True)
        time.sleep(.32)
        handbrake = self.capture("13-day-handbrake-off")
        self.driver.key("s", True)
        time.sleep(.22)
        combined = self.capture("14-day-combined-brakes-off")
        self.driver.key("Space", False)
        time.sleep(.21)
        brake = self.capture("15-day-brake-off")
        self.driver.key("s", False)
        counts = [red_pixels(frame) for frame in (released, handbrake, combined, brake)]
        assert min(counts[1:]) > counts[0] + 3, f"Brake lamps did not stand out: {counts}"
        self.verdict.update(park_camera_delta=round(delta, 2), night_beam_pixels_gain=gain,
                            red_pixels_released_handbrake_combined_brake=counts)

    def run(self):
        self.official()
        self.park()

    def save(self):
        (self.output / "qa_summary.json").write_text(json.dumps(self.verdict, indent=2) + "\n")


def frame_metrics(samples_ms):
    ordered = sorted(samples_ms)
    middle = median(ordered)
    return {"median_ms": round(middle, 2), "p95_ms": round(ordered[int((len(ordered)-1) * .95)], 2),
            "fps_from_median": round(1000 / middle, 1), "samples": len(ordered)}
