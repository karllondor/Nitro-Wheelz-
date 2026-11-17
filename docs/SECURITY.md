# Repository and release security

Mandatory: protect main in GitHub Settings with pull requests and passing Foundation/Godot checks. Configure branch rules on the target repository; template files cannot activate GitHub protections by themselves.

Never store Android signing keystores, private certificates, access tokens, passwords, personal data or .env secrets in Git. Use protected CI secrets, short-lived tokens, least-privilege contents: read permissions for tests, and explicit owner authorization for publishing.

Check untrusted third-party addons against license, maintainer, revision, transitive dependencies and engine compatibility. Pin versions and verify downloads/checksums when feasible. REA examination of public game behavior never authorizes copying commercial source or assets.

Files larger than 25 MiB should be assessed for Git LFS or external artifact storage. Approved-art manifest checks must compare against a trusted base; do not grant agents bypass via updating CI scripts.

On incident: stop publishing, revoke compromised credentials, preserve logs, identify the first affected version, revert safely and document the fix. Redact secrets from HANDOFF and screenshots.
