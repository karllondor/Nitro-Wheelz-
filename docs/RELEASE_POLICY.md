# Semantic versioning and preservation

First starter source version **0.1.0**. Every new game created from it starts its own version history; starter version and game version are different concepts.

Naming:
Game-Slug_vMAJOR.MINOR.PATCH_Source.zip
Game-Slug_vMAJOR.MINOR.PATCH_Windows.zip
Game-Slug_vMAJOR.MINOR.PATCH_Linux.zip
Game-Slug_vMAJOR.MINOR.PATCH_Web.zip
Game-Slug_vMAJOR.MINOR.PATCH_Android.apk

PATCH: bugfix; MINOR: functionality; MAJOR: first stable contract/breaking release. Pre-1.0 changes may be breaking; document them.

Do not change VERSION by hand when a release is in process. Run tools/bump_version.py with patch/minor/major and tools/package_release.py for immutable packaging. Source ZIP is not an installed-tested game. Each archive carries version, commit hash if available and file SHA256. Any existing destination filename causes failure; never overwrite or delete an earlier release.

Record platform status (BUILT / INSTALLED / TESTED) separately. Android requires signing and export templates; this template does not ship secrets or a signed APK. Git tag and GitHub Release follow owner approval and passing checks.

