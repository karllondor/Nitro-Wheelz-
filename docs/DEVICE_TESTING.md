# Physical device QA

Each result: game version + git SHA + OS/build + hardware model + connection (USB/Bluetooth) + test date + evidence link/file + tester.
Android: adb devices; adb install -r <apk>; adb logcat -s godot; adb shell screenrecord /sdcard/test.mp4. Pull recording afterwards. Test hardware Back and both touch/gamepad. Do not mark APK tested because export completed.

Windows: verify keyboard and Xbox USB/Bluetooth; switch to controller while menu open; disconnect/reconnect; test focus and pause. Ubuntu: repeat and note Bluetooth adapter/driver. On Web verify activation after first button press. Record FPS/frame-time on real devices, not CI.

