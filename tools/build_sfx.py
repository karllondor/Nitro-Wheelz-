#!/usr/bin/env python3
"""Build the game's processed SFX from the owner's WAV masters.

Reads game/assets/audio/sfx_spec.json and audio_masters/<name>.wav, cuts the
event region, applies fades, makes loops seamless with an equal-power
crossfade, peak-normalises to -3 dBFS (Vorbis overshoot headroom) and encodes OGG Vorbis into
game/assets/audio/processed/. Needs numpy and ffmpeg (libvorbis).
Re-run after editing the spec. The original OGG files are never touched.
"""
import json, pathlib, subprocess, tempfile, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = ROOT/"game/assets/audio/sfx_spec.json"
MASTERS = ROOT/"audio_masters"
OUT = ROOT/"game/assets/audio/processed"
PEAK_DBFS = -3.0

def read_wav(path):
    with wave.open(str(path), "rb") as w:
        sr = w.getframerate(); n = w.getnframes(); ch = w.getnchannels()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64)/32768.0
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    return data, sr

def write_ogg(x, sr, path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp)/"x.wav"
        pcm = np.clip(x, -1.0, 1.0)
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
            w.writeframes((pcm*32767.0).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis",
                        "-q:a", "5", "-map_metadata", "-1", str(path)], check=True)

def build(name, spec):
    x, sr = read_wav(MASTERS/f"{name}.wav")
    a = int(round(spec["start"]*sr))
    n = int(round(spec["length"]*sr))
    need = a+n+(int(round(spec.get("crossfade", 0.2)*sr)) if spec.get("loop") else 0)
    if need > len(x):
        raise SystemExit(f"{name}: cut ends at {need/sr:.2f}s but the master is {len(x)/sr:.2f}s")
    if spec.get("loop"):
        xf = int(round(spec.get("crossfade", 0.2)*sr))
        seg = x[a:a+n+xf].copy()
        body = seg[:n].copy()
        t = np.linspace(0.0, np.pi/2, xf)
        # Equal-power blend of the segment's tail into its head -> seamless.
        body[:xf] = seg[:xf]*np.sin(t) + seg[n:n+xf]*np.cos(t)
        y = body
    else:
        y = x[a:a+n].copy()
        fi = int(round(spec.get("fade_in", 0.0)*sr)); fo = int(round(spec.get("fade_out", 0.0)*sr))
        if fi > 0:
            y[:fi] *= np.linspace(0.0, 1.0, fi)
        if fo > 0:
            y[-fo:] *= np.linspace(1.0, 0.0, fo)**2
    peak = np.max(np.abs(y))
    if peak > 0:
        y *= (10**(PEAK_DBFS/20.0))/peak
    write_ogg(y, sr, OUT/f"{name}.ogg")
    return len(y)/sr

def main():
    spec = json.loads(SPEC.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    for name, s in spec["clips"].items():
        d = build(name, s)
        print(f"{name:22s} {d:5.2f}s {'loop' if s.get('loop') else 'one-shot'}")

if __name__ == "__main__":
    main()
