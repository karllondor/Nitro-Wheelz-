#!/usr/bin/env python3
"""Real exported Linux executable Xvfb input/render smoke. Not physical gameplay acceptance."""
from pathlib import Path
import os, time, subprocess, signal, json
import mss
from PIL import Image, ImageStat, ImageChops
ROOT=Path.cwd()
EXE=ROOT/"builds/desktop/Nitro-Wheelz_v0.1.43_Linux.x86_64"
OUT=ROOT/"builds/qa-desktop"
OUT.mkdir(parents=True,exist_ok=True)
assert EXE.is_file() and EXE.stat().st_size > 1000000
env=os.environ.copy()
env["LIBGL_ALWAYS_SOFTWARE"]="1"
log=open(OUT/"linux_runtime.log","w",encoding="utf-8")
proc=subprocess.Popen([str(EXE),"--rendering-driver","opengl3"],stdout=log,stderr=subprocess.STDOUT,env=env)
def shot(name):
    p=OUT/name
    with mss.mss() as capture:
        capture.shot(mon=1,output=str(p))
    image=Image.open(p).convert("RGB")
    sd=ImageStat.Stat(image).stddev
    print("SCREEN:",name,"size",image.size,"RGB_STDDEV",tuple(round(s,2) for s in sd),flush=True)
    return image, max(sd)
def key(*cmd):
    subprocess.run(["xdotool",*cmd],timeout=10,check=False)
try:
    time.sleep(17)
    if proc.poll() is not None:
        raise RuntimeError("Exported Linux game exited before reaching main UI (code %s)"%proc.returncode)
    img,sd=shot("01_linux_startup.png")
    if sd<4: raise RuntimeError("Native game rendered blank/uniform screen")
    key("type","--delay","45","QA_DRIVER")
    key("key","Return")
    time.sleep(3)
    img2,sd2=shot("02_linux_after_welcome.png")
    changed=ImageChops.difference(img,img2).getbbox() is not None
    print("UI_CHANGED_AFTER_INPUT:",changed,flush=True)
    key("key","Return")
    time.sleep(2)
    key("key","Return")
    time.sleep(7)
    key("keydown","w")
    time.sleep(2)
    key("keyup","w")
    img3,sd3=shot("03_linux_after_drive_attempt.png")
    print("UI_CHANGED_AFTER_DRIVE_ATTEMPT:",ImageChops.difference(img,img3).getbbox() is not None,flush=True)
    if proc.poll() is not None:
        raise RuntimeError("Native game exited unexpectedly while navigating")
    assert sd3>=4,"Native executable turned blank after input"
finally:
    if proc.poll() is None:
        proc.terminate()
        try:proc.wait(timeout=8)
        except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=5)
    log.close()
errors=[x for x in (OUT/"linux_runtime.log").read_text(encoding="utf-8",errors="replace").splitlines() if "SCRIPT ERROR" in x or "ERROR:" in x]
(OUT/"qa_summary.json").write_text(json.dumps({"exited":proc.returncode,"start_stddev":sd,"end_stddev":sd3 if "sd3" in globals() else None,"input_changed_ui":changed if "changed" in globals() else None,"runtime_errors":errors[:20]},indent=2),encoding="utf-8")
if errors:
    raise RuntimeError("Native runtime logged errors: "+" | ".join(errors[:4]))
print("PASS: exported Linux x86_64 executable booted in Xvfb, rendered nonblank GUI, accepted keyboard injection and stayed alive. Screenshots are attached. Manual real-desktop drive still requires owner QA.")
