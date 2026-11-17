# Nitro Wheelz v0.1.2 grip/reverse handoff

Model: GPT-6
Branch: agent/nitro-v0.1.2-grip-reverse
Date: 2026-11-17
Status: Godot, Foundation, Android APK and Web export PASS; hardware playtest NOT RUN

Source videos: owner-provided Nitro Wheelz (1000075990.mp4) and DRIFTIT (1000075991.mp4). Owner reported excess drift/sliding and absence of BRAKE-to-REVERSE.

Updated: original deterministic two-axle driving model rear traction under power (velocity dependent), yaw response and neutral steering recovery, back-to-forward transition, BRAKE reverse drive. Maintained camera, Lada, track, mobile touches, Xbox mapping.
Source-validated mechanic references:
https://driftit.app/guides/drifting-explained
https://driftit.app/guides/drifting-with-a-controller
https://driftit.app/blog/building-a-drift-game-in-threejs

CI passes on code commit e975440ce2e3d24ab37bb89587a94ad489645ad7:\n- Foundation: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44182330072\n- Godot import/smoke/physics: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44182330061\n- Web preview: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44182330026\n- Android APK: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44182330052\n- APK SHA-256: 0e74478babd1915629710a11574fa64c8353e5cf7d9bc84905bcb8d025cb7a04 Real Android playtest must confirm feel and that reverse starts after braking to a stop. Can't assert exact feel match to proprietary DRIFTIT physics from articles alone.

Signing: CI generates a fresh debug signing key each run; old test build may need uninstall before new test APK. Stable Android signing is a separate pending improvement.
