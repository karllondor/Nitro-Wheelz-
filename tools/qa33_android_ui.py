"""Cold launch the unmodified #33 APK. Exercise ordinary Android input without QA hooks."""
import csv
import io
import os
import subprocess
import time
from pathlib import Path

pkg = os.environ['NITRO_PKG']
out = Path('builds/independent-ui')
out.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args])

def capture(label):
    path = out / (label + '.png')
    path.write_bytes(adb('exec-out', 'screencap', '-p'))
    return path

def word(label, target):
    for _ in range(12):
        path = capture(label)
        data = subprocess.check_output(['tesseract', str(path), 'stdout', '--psm', '11', 'tsv'],
                                       stderr=subprocess.DEVNULL, text=True)
        (out / (label + '.tsv')).write_text(data)
        for row in csv.DictReader(io.StringIO(data), delimiter='\t'):
            if row['text'].strip(' ,:•').upper() == target:
                return [str(int(row[k]) + int(row[size]) // 2)
                        for k, size in [('left', 'width'), ('top', 'height')]]
        time.sleep(2)
    raise ValueError(f'{target} absent from {label}')

def reopen():
    adb('shell', 'am', 'force-stop', pkg)
    adb('shell', 'monkey', '-p', pkg, '1')

apk = str(next(Path('builds/android').rglob('*.apk')))
adb('install', '-r', apk)
adb('shell','wm','size','720x1280')
adb('shell','wm','density','240')
adb('shell','settings','put','secure','immersive_mode_confirmations','confirmed')
adb('shell','input','keyevent','KEYCODE_WAKEUP')
adb('shell','wm','dismiss-keyguard')
reopen()
# Keep collecting the other evidence even when the external UI driver fails.
try:
    word('first-launch', 'WELCOME')
    adb('shell','input','text','AstraQA')
    adb('shell','input','keyevent','KEYCODE_ENTER')
    for label, entry, expected in [('garage','GARAGE','GARAGE'),('lobby','MULTIPLAYER','HOST'),
                                    ('park','PARK','TUTORIAL'),('setup','DRIVE','DRIVE')]:
        reopen()
        pos = word('main-menu', entry)
        adb('shell','input','tap',*pos)
        time.sleep(2)
        word(label, expected)
    adb('shell','input','tap',*word('setup','DRIVE'))
    time.sleep(10)
    capture('solo-race')
    (out/'ui-verdict.txt').write_text('PASS normal menu taps and persistence after restart; inspect screenshots for solo HUD.')
except Exception as exc:
    (out/'ui-verdict.txt').write_text('INCOMPLETE: '+str(exc))
    print(exc)
(out/'memory-normal-ui.txt').write_bytes(adb('shell','dumpsys','meminfo',pkg))
(out/'package.txt').write_bytes(adb('shell','dumpsys','package',pkg))
adb('shell','am','force-stop',pkg)
