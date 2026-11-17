# Nitro Wheelz — 0.1.1 Android visual + UI hotfix

Date: 2026-11-17
Model: GPT-6
Repository: https://github.com/karllondor/Nitro-Wheelz-
Branch: agent/nitro-v0.1.1-mobile-lada

## Delivered
Fixed inverse Godot Y-axis mesh yaw; added low-poly red four-door Lada-inspired procedural mesh based on the approved concept sheet; improved portrait mobile HUD/menu font scale and joystick / BRAKE / GAS / DRIFT control sizes; preserved top-down/chase; updated version, Android/Web export filenames and automated alignment/multitouch tests.

## Evidence
CI / APK / Web: NOT RUN at document write time. Update with exact GitHub workflow URLs after checks finish.
Real Android installation and appearance: NOT RUN. Controller USB/Bluetooth: NOT RUN.

## Build note
Previous v0.1.0 test APK used a random CI debug signing key. v0.1.1 build uses a newly generated debug key, so Android will probably require uninstalling v0.1.0 before installing v0.1.1. This can erase local app data. Production signing must eventually use stable secrets and release keystore management.

## Pending validation
Start straight on race line and matching car heading; check true multi-finger throttle/steering/drift; large legible portrait UI; front/rear chase; no regressions to drift model. Mobile graphics and performance require owner-provided screenshots/video.
