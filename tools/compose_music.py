#!/usr/bin/env python3
"""Nitro Wheelz background track "Night Drift" — original composition in code.

Style brief from the owner (a melancholic chill-trap / future-bass reference):
120 BPM, A minor, deep 808, half-time drums, dark low-passed supersaw pads
pumping with the kick, airy formant "vocal" chops, soft vinyl texture, dark
top end. No samples, no copied melody. Deterministic (seeded). The whole
track loops seamlessly (reverb tails wrap to the start).

Needs numpy + ffmpeg (libvorbis). Writes game/assets/music/night_drift.ogg.
"""
import pathlib, subprocess, tempfile, wave
import numpy as np

SR = 44100
BPM = 120.0
BEAT = 60.0/BPM
BAR = 4*BEAT
RNG = np.random.default_rng(2106)
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT/"game/assets/music/night_drift.ogg"

def hz(note):
    names = {"C":0,"C#":1,"D":2,"D#":3,"E":4,"F":5,"F#":6,"G":7,"G#":8,"A":9,"A#":10,"B":11}
    n, octave = note[:-1], int(note[-1])
    return 440.0*2**((names[n]+12*(octave+1)-69)/12.0)

# Arrangement: 64 bars = 128 s. Sections: intro 8, A 16, B 16, A2 16, outro 8.
SECTIONS = [("intro",8),("A",16),("B",16),("A2",16),("outro",8)]
BARS = sum(n for _, n in SECTIONS)
N = int(BARS*BAR*SR)
# Two-bar chords. A: Am F C G   B: F G Em Am
PROG_A = [("A",["A3","C4","E4","G4"]),("F",["F3","A3","C4","E4"]),("C",["C3","G3","C4","E4"]),("G",["G3","B3","D4","E4"])]
PROG_B = [("F",["F3","A3","C4","E4"]),("G",["G3","B3","D4","F#4"]),("E",["E3","G3","B3","D4"]),("A",["A3","C4","E4","B4"])]
BASS = {"A":"A1","F":"F1","C":"C2","G":"G1","E":"E1"}

def section_of(bar):
    b = 0
    for name, n in SECTIONS:
        if bar < b+n:
            return name, bar-b
        b += n
    return "outro", 0

def chord_at(bar):
    name, local = section_of(bar)
    prog = PROG_B if name == "B" else PROG_A
    return prog[(local//2) % 4]

def env_adsr(n, a, d, s, r):
    e = np.ones(n)*s
    ai, di, ri = int(a*SR), int(d*SR), int(r*SR)
    ai = min(ai, n); e[:ai] = np.linspace(0, 1, ai)
    di = min(di, n-ai); e[ai:ai+di] = np.linspace(1, s, di)
    if ri > 0 and ri < n:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e

def fft_filter(x, lo=None, hi=None, slope=6.0):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1/SR); g = np.ones_like(f)
    if hi: g *= 1/np.sqrt(1+(f/hi)**slope)
    if lo: g *= 1/np.sqrt(1+(lo/np.maximum(f, 1e-3))**slope)
    return np.fft.irfft(X*g, n=len(x))

def saw(freq, t, phase=0.0):
    p = (freq*t+phase) % 1.0
    return 2*p-1

def kick_times():
    out = []
    for bar in range(BARS):
        name, local = section_of(bar)
        if name == "intro" and local < 2:
            continue
        if name == "outro" and local >= 6:
            continue
        base = bar*BAR
        out += [base, base+1.5*BEAT]          # half-time: 1 and the "and" of 2
        if local % 4 == 3:
            out.append(base+3.5*BEAT)         # pickup every 4th bar
    return out

def render():
    t = np.arange(N)/SR
    mix_l = np.zeros(N); mix_r = np.zeros(N)
    kicks = kick_times()
    # Sidechain envelope from the kick grid (pads pump).
    duck = np.ones(N)
    for k in kicks:
        i = int(k*SR); n = int(0.42*SR)
        seg = 1-0.65*np.exp(-np.linspace(0, 5, min(n, N-i)))
        duck[i:i+len(seg)] = np.minimum(duck[i:i+len(seg)], seg)

    # Pads: 6 detuned saws per note, dark low-pass with slow sweep.
    pad = np.zeros(N); pad_r = np.zeros(N)
    for bar in range(0, BARS, 2):
        root, notes = chord_at(bar)
        a, n = int(bar*BAR*SR), int(2*BAR*SR)
        tt = np.arange(n)/SR
        e = env_adsr(n, 0.35, 0.4, 0.85, 0.5)
        for note in notes:
            f = hz(note)
            for k, det in enumerate([-0.11, -0.06, -0.02, 0.02, 0.06, 0.11]):
                s = saw(f*2**(det/12), tt, RNG.random())*e
                if k % 2 == 0:
                    pad[a:a+n] += s
                else:
                    pad_r[a:a+n] += s
    lfo = 0.5+0.5*np.sin(2*np.pi*t/(8*BAR))
    pad = fft_filter(pad, lo=90, hi=2600, slope=4)*(0.9+0.2*lfo)
    pad_r = fft_filter(pad_r, lo=90, hi=2600, slope=4)*(0.9+0.2*lfo)
    sec_gain = np.ones(N)
    for bar in range(BARS):
        name, local = section_of(bar)
        g = {"intro":0.95,"A":0.85,"B":1.0,"A2":0.9,"outro":0.95}[name]
        sec_gain[int(bar*BAR*SR):int((bar+1)*BAR*SR)] = g
    pad *= duck*sec_gain; pad_r *= duck*sec_gain
    pad /= np.max(np.abs(pad))+1e-9; pad_r /= np.max(np.abs(pad_r))+1e-9
    mix_l += 0.40*pad; mix_r += 0.40*pad_r

    # 808: sine with pitch drop + saturation, on the kick grid, root notes.
    sub = np.zeros(N)
    for k in kicks:
        bar = int(k//BAR)
        root, _ = chord_at(bar)
        f0 = hz(BASS[root])
        i = int(k*SR); n = min(int(0.9*BEAT*SR*1.6), N-i)
        tt = np.arange(n)/SR
        f = f0*(1+1.2*np.exp(-tt/0.03))
        ph = 2*np.pi*np.cumsum(f)/SR
        e = np.exp(-tt/0.55)*np.minimum(1, tt/0.004)
        # Layered 808: sub fundamental + strong octave so it reads on phones.
        sub[i:i+n] += (0.75*np.sin(ph)+0.85*np.sin(2*ph))*e
    sub = np.tanh(sub*1.8)/np.tanh(1.8)
    mix_l += 0.30*sub; mix_r += 0.30*sub

    # Kick click (short body on top of the 808).
    kick = np.zeros(N)
    for k in kicks:
        i = int(k*SR); n = min(int(0.12*SR), N-i)
        tt = np.arange(n)/SR
        f = 55+180*np.exp(-tt/0.012)
        kick[i:i+n] += np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-tt/0.05)
    mix_l += 0.40*kick; mix_r += 0.40*kick

    # Snare / clap on beat 3 (half-time) with a long dark tail.
    snare = np.zeros(N)
    for bar in range(BARS):
        name, local = section_of(bar)
        if name == "intro" and local < 2:
            continue
        if name == "outro" and local >= 6:
            continue
        i = int((bar*BAR+2*BEAT)*SR); n = min(int(0.35*SR), N-i)
        tt = np.arange(n)/SR
        noise = RNG.standard_normal(n)
        clap = noise*np.exp(-tt/0.09)*(1+0.6*(np.sin(2*np.pi*tt/0.012) > 0))
        body = np.sin(2*np.pi*190*tt)*np.exp(-tt/0.05)
        snare[i:i+n] += 0.6*clap+0.5*body
    snare = fft_filter(snare, lo=180, hi=6000, slope=4)
    snare /= np.max(np.abs(snare))+1e-9

    # Hats: 8ths with soft 16th rolls at phrase ends, dark and quiet.
    hats = np.zeros(N)
    for bar in range(BARS):
        name, local = section_of(bar)
        if (name == "outro" and local >= 7):
            continue
        steps = [s*0.5 for s in range(8)]
        if local % 4 == 3:
            steps += [3.25, 3.75, 3.125, 3.375, 3.625, 3.875]
        for s in steps:
            i = int((bar*BAR+s*BEAT)*SR); n = min(int(0.05*SR), N-i)
            if n <= 0: continue
            v = 0.55+0.45*RNG.random()*(1.0 if s % 1 == 0 else 0.6)
            hats[i:i+n] += RNG.standard_normal(n)*np.exp(-np.arange(n)/SR/0.012)*v
    hats = fft_filter(hats, lo=5000, hi=11000, slope=4)
    hats /= np.max(np.abs(hats))+1e-9

    # Formant "vocal" chops: an original melancholic motif in A minor.
    motif_a = [("E5",0,1.0),("D5",1.0,0.5),("C5",1.5,1.0),("A4",2.5,1.5),
               ("C5",4.0,0.5),("D5",4.5,0.5),("E5",5.0,1.0),("G5",6.0,0.5),("E5",6.5,1.5)]
    motif_b = [("A5",0,1.5),("G5",1.5,0.5),("E5",2.0,1.0),("D5",3.0,1.0),
               ("E5",4.0,0.75),("C5",4.75,0.75),("B4",5.5,0.5),("A4",6.0,2.0)]
    vox = np.zeros(N)
    for bar in range(0, BARS, 2):
        name, local = section_of(bar)
        if name not in ("A","B","A2") or local % 4 != 0:
            continue
        motif = motif_b if name == "B" else motif_a
        for note, st, ln in motif:
            i = int((bar*BAR+st*BEAT)*SR); n = min(int(ln*BEAT*SR), N-i)
            tt = np.arange(n)/SR
            f = hz(note)*(1+0.006*np.sin(2*np.pi*5.2*tt))
            src = 2*((np.cumsum(f)/SR) % 1.0)-1
            e = env_adsr(n, 0.02, 0.1, 0.7, min(0.15, ln*BEAT*0.5))
            vox[i:i+n] += src*e
    ah = fft_filter(vox, lo=550, hi=900, slope=8)+0.6*fft_filter(vox, lo=1000, hi=1400, slope=8)+0.25*fft_filter(vox, lo=2400, hi=3200, slope=8)
    ah /= np.max(np.abs(ah))+1e-9

    # Reverb: decaying stereo noise IR, applied circularly (seamless loop).
    def reverb(x, seconds, seed):
        r = np.random.default_rng(seed)
        n = int(seconds*SR); tt = np.arange(n)/SR
        ir = r.standard_normal(n)*np.exp(-tt/(seconds/5.0))
        ir = fft_filter(ir, lo=200, hi=4500, slope=4)
        ir /= np.sqrt(np.sum(ir**2))+1e-9
        L = len(x)
        y = np.fft.irfft(np.fft.rfft(x, L)*np.fft.rfft(ir, L), n=L)   # circular
        return y
    vox_l = 0.55*ah+0.45*reverb(ah, 2.8, 1); vox_r = 0.55*ah+0.45*reverb(ah, 2.8, 2)
    sn_l = snare+0.8*reverb(snare, 1.8, 3); sn_r = snare+0.8*reverb(snare, 1.8, 4)
    mix_l += 0.46*sn_l+0.20*hats+0.24*vox_l
    mix_r += 0.46*sn_r+0.20*np.roll(hats, 40)+0.24*vox_r
    pad_space_l = reverb(0.30*pad, 3.5, 5); pad_space_r = reverb(0.30*pad_r, 3.5, 6)
    mix_l += 0.35*pad_space_l; mix_r += 0.35*pad_space_r

    # Vinyl texture: very quiet crackle + hiss band.
    crackle = np.zeros(N)
    idx = RNG.choice(N, size=int(BARS*BAR*6), replace=False)
    crackle[idx] = RNG.standard_normal(len(idx))*0.6
    crackle = fft_filter(crackle, lo=900, hi=5000, slope=2)
    mix_l += 0.02*crackle; mix_r += 0.02*np.roll(crackle, 371)

    # Master: dark top, glue, soft clip, loudness ~ -14 LUFS-ish by RMS.
    out = np.stack([mix_l, mix_r])
    out = np.stack([fft_filter(c, hi=11000, slope=4) for c in out])
    rms = np.sqrt(np.mean(out**2))
    out *= 0.15/rms
    out = np.tanh(out*1.3)/np.tanh(1.3)
    out *= 0.80/np.max(np.abs(out))
    return out

def write(out):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp)/"m.wav"
        pcm = (np.clip(out.T, -1, 1)*32767).astype(np.int16)
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg","-v","error","-y","-i",str(wav),"-c:a","libvorbis","-q:a","3",
                        "-map_metadata","-1",str(OUT)], check=True)

if __name__ == "__main__":
    write(render())
    print(f"wrote {OUT} ({BARS*BAR:.0f} s, {BPM:.0f} BPM)")
