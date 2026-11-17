# Approved asset lock

Place reference files inside assets/references/approved and run python3 tools/lock_asset.py <relative-path> --id <stable-id>. A locked source is immutable: revisions use new names/IDs.

The single canonical registry is assets/approved_assets.json. The gate:
1. validates sha256 of every registered approved file,
2. rejects unregistered approved files,
3. rejects deletions/edits of entries present in the protected git base,
4. allows additive entries only when source is present and hashed,
5. forbids symlink escapes and duplicate IDs.

PR CI must use a trusted base (origin/main); branch protection is needed to keep checks from being bypassed by editing the gate itself. An owner-authorized process must review any deliberate replacement. Static checks alone do not establish consent.

