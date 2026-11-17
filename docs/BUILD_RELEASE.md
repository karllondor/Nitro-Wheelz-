# Build, export and release

1. Pin Godot version; install matching export templates.
2. Run Python + engine checks; do not treat CI smoke as gameplay QA.
3. Configure target-specific export_presets.cfg in each game (including Android unique package, sdk, keystore from secure environment); never commit signing passwords.
4. Export Windows/Linux/Web/Android only for project targets. Name artifacts with game slug + vX.Y.Z + platform; never overwrite previous versions.
5. Run tools/stamp_build.py before export, then tools/package_release.py against actual exported output.
6. Test install/launch and record QA evidence, then release with owner approval.

Unsigned/local APKs are for development; signed production AAB/APK require secure keys. Unconfigured presets are not fabricated by the starter.

