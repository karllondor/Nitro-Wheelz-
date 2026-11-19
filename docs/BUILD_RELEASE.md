# Build, export and release

1. Pin Godot version; install matching export templates.
2. Run Python + engine checks; do not treat CI smoke as gameplay QA.
3. Configure target-specific export_presets.cfg in each game (including Android unique package, sdk, keystore from secure environment); never commit signing passwords.
4. Export Windows/Linux/Web/Android only for project targets. Name artifacts with game slug + vX.Y.Z + platform; never overwrite previous versions.
5. Run tools/stamp_build.py before export, then tools/package_release.py against actual exported output.
6. Test install/launch and record QA evidence, then release with owner approval.

Unsigned/local APKs are for development; signed production AAB/APK require secure keys. Unconfigured presets are not fabricated by the starter.


## Android debug APK updates (stable signing key)
Android installs a new APK as an UPDATE only when it is signed by the same certificate as the installed app. Until v0.1.13 the Android workflow generated a new random debug key on every run, so every new APK failed to install over the previous one ("App not installed" / package conflict).

The workflow now reads a persistent debug keystore from the repository secret `NITRO_DEBUG_KEYSTORE_B64` (base64 of a keystore with alias `androiddebugkey`, store/key password `android`). Without the secret it falls back to a throwaway key and prints a warning in the run summary.

One-time setup (owner): GitHub → repository Settings → Secrets and variables → Actions → New repository secret → name `NITRO_DEBUG_KEYSTORE_B64`, value = the base64 text of the keystore. Never commit the keystore or its base64 to the repository.

After the first build signed with the stable key, uninstall the old app ONCE (it was signed with a random key; uninstalling deletes local saves: tracks, run history, garage paint). From then on every new APK installs as an update and keeps the saves.
