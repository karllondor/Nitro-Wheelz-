# LOCAL MULTIPLAYER (offline, two Android phones) — v0.1.41 prototype

Issue #31 (owner dispatch 2026-11-22), coordination #26. Branch `agent/claude/issue-31-local-multiplayer` = v0.1.39 (the active Android line) + this.
Handoff: `docs/dev/handoffs/issue-31-local-multiplayer-20261123-claude.md`.

**Status: CODE_READY + automated tests on one desktop (loopback). NOT tested on two real phones (OWNER_QA_PENDING).**

## What it is

Two Android phones on the **same local network** (the same Wi-Fi, or one phone's hotspot) play the **same track at the same time**.
One phone HOSTS, the other JOINS by typing the host's local address. No Internet, no account, no server, no cloud, no mobile data,
no paid infrastructure. Each phone drives its **own** car with the normal controls and the normal physics; it draws the other player's
car from small position snapshots.

It is **not** Internet multiplayer: the join field refuses any address that is not a private LAN address (10.x, 172.16–31.x, 192.168.x).

## Two-phone test (owner)

1. Install the same APK `Nitro-Wheelz_v0.1.41_Android-debug.apk` on both phones (same version is required; the game says so otherwise).
2. Network, pick one:
   * both phones on the same Wi-Fi router (internet not needed), or
   * **hotspot test (the real offline case):** phone A: turn mobile data OFF, then turn the Wi-Fi hotspot ON. Phone B: mobile data OFF, join A's hotspot.
3. Phone A: **LOCAL MULTIPLAYER → HOST GAME**. It shows its address, e.g. `192.168.43.1`.
4. Phone B: **LOCAL MULTIPLAYER → JOIN GAME**, type that address, **CONNECT**. (The field is pre-filled with the first three numbers of phone B's own address.)
5. Both phones: **READY**. Phone A: **START**. 3 – 2 – 1 – GO!, both cars drive. Drift together.
6. Leave with PAUSE → GARAGE / MENU (or the phone's back button in the lobby). Then play a normal single-player lap: nothing must have changed.

Please report: did the join work on Wi-Fi and on the hotspot, does the other car look smooth, did GO feel simultaneous, what happens when you
lock one screen / switch app / walk out of range, do the scores and stars of single-player stay as before.

## Architecture

| Piece | File | Role |
|---|---|---|
| Protocol | `game/scripts/net/net_protocol.gd` | constants, message kinds, 40-byte snapshot encode/validate, track whitelist + SHA-256 fingerprint, address helpers |
| Session | `game/scripts/net/net_session.gd` | one ENet connection: handshake, roster, READY/START, load barrier, countdown, snapshots, pings, timeouts, leave |
| Lobby | `game/scripts/net/multiplayer_lobby.gd` + `game/scenes/multiplayer_lobby.tscn` | isolated UI entry: HOST GAME / JOIN GAME / READY / START / LEAVE |
| Race side | `game/scripts/net/net_race.gd` | attached to the race scene only during a multiplayer race: start slots, countdown freeze + overlay, snapshots out, remote car + interpolation |

Transport: Godot `ENetMultiplayerPeer` (UDP, default port **47821**) inside a **private `SceneMultiplayer` per session** that uses only
`send_bytes` / `peer_packet` (no RPC, no spawner, no scene replication, no global `multiplayer` state), so a session can be created and destroyed
cleanly, and tests can run a host and a joiner in one process.

### Messages
* **Control** (reliable, `var_to_bytes` dictionaries, ≤ 1 KB, header-validated before decoding so no engine error can be provoked by garbage):
  HELLO / WELCOME / REJECT (FULL, PROTOCOL, VERSION, TRACK) / INFO (name, car, ready, track fingerprint) / TRACK / START / LOADED / COUNTDOWN / PING / PONG / LEAVE.
* **Snapshot** (unreliable-ordered, **40 bytes, 20 Hz** ≈ 0.8 kB/s each way): kind, flags (drifting, paused, reset, handbrake), 16-bit sequence,
  sender time (ms), x, z, heading, vx, vz, yaw rate, steering angle, drift score. Never the 120 Hz physics state.

### Flow
`IDLE → HOSTING / CONNECTING → LOBBY → STARTING → COUNTDOWN → RACING` (+ `LOST`, `FAILED`, `CLOSED`).
1. Joiner connects; HELLO carries protocol number, game version, name, car. The host answers WELCOME or REJECT with a readable text.
2. Both sides exchange INFO; the host chooses the track from a built-in whitelist (oval, sweepers, both Shin-Kawa circuits). The track is identified by **path in the
   whitelist + SHA-256 of the track file**; a different file on the other phone ends in `TRACK MISMATCH`. No remote path is ever opened (only whitelisted `res://` files).
3. READY on both, host START → both load the race scene → each reports LOADED → host announces a 3 s countdown once both are loaded;
   the joiner subtracts half its measured round trip so GO is simultaneous (loopback measurement: 0.0 ms apart; **not** a Wi-Fi measurement).
4. Start slots: side by side on the start line, 2.6 m left (host) / right (joiner) of the centre line; checked to be on the road of all four circuits.

### Remote car
A **visual only** (no collision body, no drive model, no sound). Pose = Hermite interpolation between the two buffered snapshots that bracket
*render time = now − clock offset − 120 ms*; after the newest snapshot it extrapolates with the sent velocity for at most 250 ms and then stands;
a RESET flag (restart) snaps instead of gliding; an impossible jump (> 160 m/s) is dropped; heading interpolates through ±π. The car node
reuses the existing car models and wheel steering (`set_motion`). The other player's drift score is shown as a small label
(`NAME  1234 PTS`), informational only.

### The local car
Runs **exactly as in single-player** (`race.gd` is not refactored; its physics, steering, camera and scoring are untouched). Local touch
input can only reach the local car because the remote car has no input path at all.

## What multiplayer never does
* It never writes a record, star, score or top-run (`NitroRaceResults.record_allowed()` is false while a multiplayer race scene exists; the result screen says so).
* It never contacts the Internet; a public address is refused.
* It leaves no state behind: leaving the race scene (menu, back, restart of the app) closes the session and frees the socket.
* Remote data is **client-reported and untrusted** (prototype): positions and scores are for display only, there is no anti-cheat and no ranking.

## Failure handling (all end in a readable message, never a crash)
Port busy, malformed address, public address, host unreachable (8 s), no answer to HELLO (5 s), session full, different protocol / game version / track,
the other phone left, 6 s of silence (host or guest), the other phone never finished loading (30 s), malformed / NaN / huge / stale / out-of-order /
oversized / object-carrying packets (dropped and counted). If the other phone disappears **during a race** the race continues for the local player
with a message ("YOU CAN KEEP DRIVING").

## `race.gd` and shared files touched (feature-gated, minimal)
* `scripts/race/race.gd`: `const NET_RACE`, `var net`, creation right after the Park block **only if a multiplayer session is starting**, one `if net != null and net.freezes(): return` in `_physics_process`, `net.on_restart()` in `_restart()`.
* `scripts/ui/race_results.gd`: `record_allowed()` also false in multiplayer; footer text.
* `scripts/boot.gd`: one menu line `LOCAL MULTIPLAYER`.
* `game/export_presets.cfg`: `permissions/internet=true` (Android needs it for any socket, even a LAN one) and version; `.github/workflows/android-debug.yml`: version + a step that **fails the build if the APK manifest lacks `android.permission.INTERNET`**.
* `tools/run_godot_checks.sh`: three tests appended.

## Tests (container, headless, Godot 4.7.2)
| Test | Proves |
|---|---|
| `net_session_test` | protocol round trips, malformed/NaN/huge/stale/oversized/object packets rejected; host + join + roster + READY + START + LOADED + countdown on a real ENet loopback; snapshots in order; leave / lost host / lost joiner / silence timeout; room stays open after a leave; third player refused; wrong version / track / unreachable host / malformed IP end in messages |
| `net_race_test` | interpolation maths; start slots on the road of every shareable circuit; car frozen until GO and driving after; solo race has no multiplayer object; remote car has no collider and moves without jumps; impossible jump dropped; reset snaps; paused flag + score arrive; a multiplayer result is never saved; lost peer reported while the local car keeps driving; leaving cleans up (`SESSION.current == null`, records allowed again) |
| `multiplayer_lobby_test` | menu entry; HOST GAME / JOIN GAME / READY / START / LEAVE through two lobby screens; malformed and public addresses refused; START only when both READY; track choice reaches the guest; START opens the race scene with the agreed track and keeps the session; lost host explained |
| `main_menu_test` | updated menu list |

**NOT proven by any of them (owner QA, OWNER_QA_PENDING):** two real phones on Wi-Fi / hotspot with mobile data off, Android multicast / client-isolation
behaviour of routers, phone sleep / app in background / lock screen, thumb controls while playing, real network jitter and loss, battery / heat.

## Known limitations of this prototype
* 2 players, manual address entry (no automatic discovery yet), one session at a time, port 47821 (UDP) must be free.
* Some routers and "guest" Wi-Fi networks isolate clients (they cannot reach each other): use one phone's hotspot instead.
* Positions are client-reported (untrusted); no collisions between cars; no shared finish or standings; each player's own 3-lap finish ends their own run.
* Restart (pause → restart) puts the car back in its own start slot without a new countdown.
* The Android app lifecycle (phone sleep, background) is untested; a backgrounded phone is reported to the other phone as lost after 6 s of silence.
* The remote car uses the car model the other player selected, but no engine sound for it.

## For the future (NOT implemented)
The session / snapshot layer does not know about scoring: lead–chase **tandem** drifting, Club / Pro **events** (#29), a shared **finish** and standings,
more than two players, ghost cars and automatic room discovery can be added on top by (a) extra control messages, (b) per-event state that the
host broadcasts (e.g. which zone is active), (c) a second snapshot field set. The 16-bit sequence and the message kind byte leave room for that.
Nothing of #29 (procedural zones, Club / Pro scoring, Road / Touge surface, Track Builder) was changed or imitated here.
