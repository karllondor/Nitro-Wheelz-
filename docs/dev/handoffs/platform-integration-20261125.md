# Nitro Wheelz v0.1.48 platform integration

**Review branch** `integration/park-unified-rc`, [PR #44](https://github.com/karllondor/Nitro-Wheelz-/pull/44). Start `17a65634f55df4ffba6e71feaef138458f3faa7b` (0.1.47). Use the current PR head for the final SHA and the PR build metadata for exact artifacts. The review APK uses the existing isolated PR #44 Android application ID. The previous Park, multiplayer, stunts, damage, editor and event implementation remains in the integration history.

| Upstream | Treatment |
| --- | --- |
| #36 `1cfab07c617a01abc0a5b8e6d442f3fb77b0e98d` | Imported compact 61%-opacity HUD, profile, original minimap and desktop telemetry, shared action bounds, and geometry/lifecycle test. Wired around the current Park and lighting pause lifecycle and showed the current and last completed lap time beneath the lap counter. |
| #35 `6fa7f27febfe651b6c62b772f3d2f47781e8a885` | Reconciled the existing Linux/Windows and Web workflows, with names derived from VERSION, checksums and actual exported-runtime screenshots. Updated X11 and Chromium runners to follow the present menus and verify real clicks, throttle, lighting and view transitions. |
| #44 lighting | Existing production lighting files, road surface response, lamp calibration and protocol retained. Pause confirmation and resize callbacks now use weak references to avoid invoking a freed control after a rapid restart/exit. |

The approved racing input and mobile HUD metrics stay the same on Android. Mouse CAMERA and PAUSE are available in native non-touch desktop builds and the Web HUD. The current PR #36 and unified source have no functional nitro charge or agreed telemetry provider. The HUD shows its approved speed and drift telemetry. A nitro indicator requires a source value before integration.

## Runtime QA

```sh
bash tools/run_godot_checks.sh
python3 tools/check_project.py --base-ref origin/main
xvfb-run -a -s "-screen 0 1280x720x24" python3 tools/qa_linux_runtime.py BUILD_LINUX EVIDENCE_LINUX
python3 tools/qa_web_browser.py WEB_DIRECTORY EVIDENCE_WEB
```

The Linux runtime runner uses X11 keyboard and pointer input and captures the shipped executable. The Web runner uses the shipped game from a temporary localhost HTTP server in Chromium, exercises keyboard and pointer, and checks 1280×720 plus 800×600. The app ships with the existing Compatibility renderer and the single-threaded Web preset. WebGL 2 is required. Serve the extracted Web directory over HTTP and click the page to allow browser audio. ENet LAN uses raw UDP and remains a native-platform feature. Chromium software WebGL and X11 virtual-display measurements are software timing samples. They do not represent physical device FPS. Windows builds are export smoke only. Android runs the debug-only ADB integration check in the exported APK on CI's emulator. Preset buttons and resume are invoked inside the running game for screenshots, while CAM, PAUSE and handbrake input use actual Godot screen-touch events. Phone display brightness, real touch latency, frame pacing and two physical LAN devices still require owner review.

## Owner checklist

| Platform | Check |
| --- | --- |
| Linux and Web | Start an official race. Read the lap counter, times and progress. Try W, C and Esc, then click CAMERA and PAUSE. Resize the browser. Use pause to restart and resume. |
| Windows | If using the Windows export, run the same HUD checks with mouse and keyboard. |
| Park | Switch DAWN, DAY, GOLDEN HOUR and NIGHT from Pause without moving the car or resetting objects. Compare AUTO / OFF and DAY / ON. Drive through a figure eight, and jump a ramp. |
| Android | Verify the original controls with one or two fingers. Test separate and combined BRAKE and HAND BRAKE in NIGHT and DAY, including manual OFF. Compare Chase and Top-down beam brightness and frame pacing. |
| Two native devices | Both install the same version. Host selects the Park preset. Join, change time live, and check brake lights, props, contact settings, detached bumpers and repair. Repeat a competitive restart and compare results. |

See the [production-lighting handoff](production-lighting-20261125.md) for the original calibration and acceptance scenarios. Build links, checksums and the exact version under test are recorded in PR #44.
