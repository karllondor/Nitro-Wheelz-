"""Exercise real ENet between two independent games, with isolated garage saves."""
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def play(host_driver, directory, scenario="race"):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    peers = {}
    try:
        for driver in ("KARLL", "KEVIN"):
            role = "host" if driver == host_driver else "guest"
            profile = directory / driver
            profile.mkdir()
            script = {"park": "net_park_peer", "race": "net_round_peer"}.get(scenario, "net_damage_peer")
            command = [os.getenv("GODOT_BIN", "godot"), "--headless", "--path", str(ROOT / "game"),
                       "--script", f"res://tests/{script}.gd", "--", role, driver, port, str(directory), scenario]
            with (profile / "game.log").open("w") as log:
                peers[driver] = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                                 env={**os.environ, "XDG_DATA_HOME": str(profile)})
        deadline = time.monotonic() + 55
        while any(proc.poll() is None for proc in peers.values()):
            if any(proc.returncode not in (0, None) for proc in peers.values()) or time.monotonic() > deadline:
                break
            time.sleep(0.1)
    finally:
        for proc in peers.values():
            if proc.poll() is None:
                proc.kill()
            proc.wait()
    clocks = []
    for driver, proc in peers.items():
        log = (directory / driver / "game.log").read_text()
        print(log, flush=True)
        if proc.returncode or "PASS:" not in log or "ERROR:" in log:
            raise RuntimeError(f"{driver} failed with {proc.returncode}")
        clocks.append(dict(re.findall(r"GO_OBS (\d+) (\d+)", log)))
    if scenario != "race":
        return
    if any(set(clock) != {"1","2","3"} for clock in clocks):
        raise RuntimeError("Each game must observe three GO transitions")
    gaps = [abs(int(clocks[0][key])-int(clocks[1][key])) for key in ("1","2","3")]
    print(f"Host {host_driver}, observed GO differences on loopback (ms) {gaps}", flush=True)
    if max(gaps) > 150:
        raise RuntimeError("GO skew exceeded 150 ms on loopback")

if __name__ == "__main__":
    scenario = "park" if "--park" in sys.argv else "race"
    for mode in (("ghost", "damage") if "--damage" in sys.argv else (scenario,)):
        for host in ("KARLL", "KEVIN"):
            with tempfile.TemporaryDirectory() as temp:
                play(host, Path(temp), mode)
    print("PASS: two independent games, both host roles")
