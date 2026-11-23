"""Cold launch the unmodified #33 APK. Exercise ordinary Android input without QA hooks."""
import csv
import io
import os
import subprocess
import time
from pathlib import Path
from PIL import Image

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
    for _ in range(20):
        path = capture(label)
        bw = out / 'ocr.png'
        Image.open(path).convert('L').point(lambda x: 0 if x>165 else 255).save(bw)
        data = subprocess.check_output(['tesseract', str(bw), 'stdout', '--psm', '11', 'tsv'],
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
old = 'com.karllondor.nitrowheelz'
legacy = str(next(Path('builds/legacy').rglob('*.apk')))
installed = subprocess.run(['adb','install','-r',legacy],capture_output=True,text=True)
(out/'legacy-install.txt').write_text(installed.stdout+installed.stderr)
old_ok = installed.returncode == 0
if old_ok:
    # Write inside the actual legacy package's sandbox before installing DEV.
    adb('shell','run-as',old,'mkdir','-p','files')
    adb('shell','run-as',old,'sh','-c',"'echo OLD-QA-SAVE > files/nitro_local_runs.json'")
adb('install', '-r', apk)
adb('shell','wm','size','720x1280')
adb('shell','wm','density','240')
adb('shell','settings','put','secure','immersive_mode_confirmations','confirmed')
adb('shell','input','keyevent','KEYCODE_WAKEUP')
adb('shell','wm','dismiss-keyguard')
reopen()
checks = []
failures = []

def verify(label, fn):
    try:
        fn()
        checks.append(label)
    except Exception as exc:
        failures.append(label+': '+str(exc))
        capture(label+'-failed')

def first_launch():
    word('first-launch', 'WELCOME')
    adb('shell','input','text','AstraQA')
    adb('shell','input','keyevent','KEYCODE_ENTER')
    word('main-menu','DEVELOPER')

def page(entry, target, label):
    reopen()
    word('main-menu','DEVELOPER')
    pos = word('main-menu',entry)
    adb('shell','input','tap',*pos)
    word(label,target)

def tutorial():
    page('PARK','TUTORIAL','park-menu')
    adb('shell','input','tap',*word('park-menu','START'))
    time.sleep(14)
    capture('park-lesson')

def solo():
    page('DRIVE','RACE','race-setup')
    adb('shell','input','tap',*word('race-setup','DRIVE'))
    time.sleep(16)
    capture('solo-before-gas')
    # Hold the accelerator in the portrait touch controls.
    adb('shell','input','swipe','646','1116','646','1116','2400')
    capture('solo-after-gas')

def saves():
    adb('shell','run-as',pkg,'sh','-c',"'echo DEV-QA-SAVE > files/qa33-sentinel'")
    adb('install','-r',apk)
    assert adb('shell','run-as',pkg,'cat','files/qa33-sentinel').strip()==b'DEV-QA-SAVE'
    reopen()
    word('restored-profile','ASTRAQA')
    if old_ok:
        assert adb('shell','run-as',old,'cat','files/nitro_local_runs.json').strip()==b'OLD-QA-SAVE'
        (out/'production-package.txt').write_bytes(adb('shell','dumpsys','package',old))
        print('Legacy sandbox survived DEV install and reinstall')
    else:
        print('Actual legacy installation unavailable; inspect legacy-install.txt')
verify('onboarding',first_launch)
verify('garage',lambda:page('GARAGE','WHEELBASE','garage'))
verify('lobby',lambda:page('MULTIPLAYER','HOST','lobby'))
verify('builder',lambda:page('BUILDER','TERRAIN','builder-menu'))
verify('tutorial',tutorial)
verify('solo-touch',solo)
(out/'memory-normal-ui.txt').write_bytes(adb('shell','dumpsys','meminfo',pkg))
verify('reinstall',saves)
(out/'package.txt').write_bytes(adb('shell','dumpsys','package',pkg))
(out/'ui-verdict.txt').write_text(('PASS' if not failures else 'INCOMPLETE')+' | '+str(checks)+' | '+str(failures)+' | legacy installed: '+str(old_ok))
print((out/'ui-verdict.txt').read_text())
