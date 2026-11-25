# Nitro Wheelz Park multiplayer handoff

This is the two-player LAN review lane. Kit for both phones must use **protocol 3**. Layout and environment inherit the provisional Park 2.0 design.

| Source | Exact commit |
| --- | --- |
| Canonical integration parent | `9d3aab09e329bb342529c0ade8743f23339fa678` |
| Park 2.0, PR #40 | `6c7e8d10068a7f8e83e6f9e9e0d6a0db79b17e36` |
| Multiplayer Reliability, PR #39 | `60f684e710bed453b219296f58eb62248381f768` |
| Isolated combined baseline | `c2dad9674919f5583100b0c7397ef3032698adf1` |
| Feature branch | `feat/park-multiplayer` |

The combined baseline has the two feature heads as its parents and the unchanged canonical integration head as their shared ancestor. Both dependency PRs were still open when this feature started. Installation and owner QA use a separate PR review package.

## Playing and reconnecting

- Host chooses **LOCAL MULTIPLAYER → HOST PARK** and shares the local IP. Guest chooses **JOIN GAME**. Both press **READY**, then host presses **OPEN PARK**. Both load into their own plaza slots, 10 m apart, and can drive as soon as the scenes load.
- Drive and practise anywhere. **PAUSE → DONUT & FIGURE-EIGHT GUIDE** starts that driver's local guide. Both can practise together on the same layout. Lessons keep only session-local progress, and any tutorial card affects only the driver who opened it.
- **RECOVER VEHICLE** returns just your car to your side of the plaza. Out-of-bounds recovery does the same. A return or rejoin uses an alternate spot 15 m south if the nominal location is occupied by the other driver.
- Only the host sees **RESET TRAINING OBJECTS**. This resets cones on both screens and leaves both cars free to drive.
- A guest can leave with **RETURN TO LOBBY** and reconnect to that same host address while the host keeps driving. The guest rejoins the active Park and receives the current cone state. Host **RETURN TO LOBBY** brings both players back to the ready room and clears their ready flags. A lost host ends the shared room. The guest can keep driving and return to the LAN menu.
- The Park has no race clock, countdown, score results or stars. Existing competitive LAN races retain the 3–2–1–GO sequence, ranking and synchronized rematches. Solo Park keeps its tutorial tracking.

## Network contracts

`NitroNetSession` owns peer identity and transport. A whitelisted Park path selects `State.PARK` after the scene-load acknowledgement. The fingerprint includes the Park track file, layout revision, loop, access paths, zone geometry, ramps, service bay and cone homes. Bump `park_site.gd:LAN_LAYOUT_REVISION` if changing a relevant placement outside the fingerprint inputs, such as an environment collision fixture. Each new start or reconnect advances the round epoch. Packets from previous rounds cannot change the current room.

| Contract | Producer and receiver | Data and behaviour |
| --- | --- | --- |
| `PARK_OPEN` | Host → guest, reliable | Round, current training revision and host position for spawn clearance. Following reliable cone snapshot establishes the shared state. |
| Car snapshot | Driver → partner, 44 bytes at 20 Hz | Existing buffered remote view, no player collision. Park always carries zero points. The first three samples after local recovery are reliable reset samples. |
| `KIND_PARK_CONES` | Host → guest | Complete sparse cone state. Header is 11 bytes for kind, round, revision and sequence, plus 11 bytes per displaced cone for index, x/z, tilt and tilt direction. Host sends up to 10 Hz while moving and uses reliable delivery at rest and on join. 80-cone maximum is 891 bytes. |
| `host_park_event(kind, payload)` and `park_event_received(kind, revision, payload)` | Host commits; both peers consume, reliable | Versioned envelope for a session-only world event. Round fences sessions, revision orders authoritative updates, and receivers validate type and payload. `RESET_TRAINING` is enabled with an empty payload. |
| `PARK_LOBBY` | Host → guest, reliable | Both retain the room and reset ready flags. The next start gets a new round epoch. |

`net_park_training.gd` owns cone replication. It uses normal cone contact locally on the host and checks bounded swept segments of accepted guest poses. Guest poses are client-reported for visual driving and lightweight practice props. They never change another player's handling or create persistent rewards.

Future event IDs are reserved in `NetProtocol.ParkEvent`. They are rejected by the current validator until a handler and payload validation ship. The same envelope can carry:

| Future event | Suggested event fields and host validation |
| --- | --- |
| Object impulse | Stable object ID, actor slot, bounded point and impulse. Confirm object exists, contact is plausible and impulse is in bounds. |
| Player contact | Two different roster slots, contact point and normal. Resolve contact from host-approved pose history. |
| Bumper damage | Actor slot, fixed part ID and bounded cosmetic state, derived from an accepted collision event. |
| Detached component | Fixed component ID, instance ID and bounded pose/velocity. Dedupe object creation by ID. |
| Service repair | Actor slot and bay ID. Validate the stopped visit, then clear the authorized cosmetic state. The current local `NitroParkController.repair_requested` signal remains the integration point. |

For any future guest-authored proposal, derive the actor from the sender's roster slot. Validate on the host, then call `host_park_event`. Keep current-world state in join snapshots for durable objects and use events for discrete changes. Simulation and storage authority for player collision or damage are outside this implementation.

## Automated verification

Godot 4.7.2. Run `bash tools/run_godot_checks.sh`. After editor import, `python3 tools/test_net_rounds.py --park` runs both host roles in separate Linux processes, each with its own profile and real ENet loopback sockets. Each driver completes a vehicle-model tour through the plaza, paddock, industrial yard, service station, stunt access and run-ups, and the technical circuit and its exit. The test checks both cameras' shared remote marker node, live pose flow, no clock or standings, local recovery, guide changes, guest contribution to shared cones, host-only reset, existing cone state on rejoin, spawn clearance and a switch back to the competitive countdown.

The competitive paired harness separately verifies three races per host with restarts, opponent liveries and result sorting. The existing solo Park tests exercise progression, menus, detectors, recovery and full-site driving.

## Owner playtest on two phones

| Test | What to do | Expected |
| --- | --- | --- |
| Host / join | Install the same review APK on both phones. Play on home Wi-Fi, then swap host and guest. Repeat on a hotspot with mobile data off. | Both reach the Park with no 3–2–1 or race clock. Each sees the other's original livery, name and cyan ring. |
| Full tour | Drive together from the plaza through the west circuit entrance, linked corners and east exit, then through parking and the container yard. Follow the east access road to the stunt slab. | Both cars stay visible and can reach all zones. Ramp deck closures stay visible. |
| Training and tandem | Use Chase and Top-down, follow the large and small figure-eight, hit a cone with the guest car, then open and close the local guide. | Both see displaced cones. Opening the guide affects just that driver. Host can reset cones. Neither profile gains stars or records. |
| Recovery | One driver uses **RECOVER VEHICLE**, then drives past the outer park bounds. Keep the other driver moving. | Only the recovering car returns to its slot. The other driver keeps control. |
| Reconnect and lobby | Displace a cone. Guest returns to the LAN menu and rejoins while host stays in the Park. Host later chooses **RETURN TO LOBBY**. | Host keeps driving. Guest rejoins with the latest cone state. Host's lobby action brings both to the ready room. |
| Host loss | Close the hosting app while the other car is driving. | The guest sees that the host left, can still drive locally and can return to the LAN menu. |
| Competitive and solo | From the ready room choose Oval and run a competitive start and host restart. Then leave and open solo Park. | Competitive countdown and standings work. Solo Park keeps the saved tutorial history. |

Physical handset FPS, live Wi-Fi/hotspot round-trip latency and perceived cone-motion smoothness await this playtest.

## Network performance evidence

Two Godot 4.7.2 Linux processes per run, same machine over ENet loopback. Each observer sampled 62 accepted car packets during ordinary real-time driving. Gaps are receiver inter-arrival times. RTT is the guest's smoothed clock-ping sample.

| Host | Guest RTT | Host median / p95 packet gap | Guest median / p95 packet gap |
| --- | ---: | ---: | ---: |
| KARLL | 6.90 ms | 48 / 56 ms | 48 / 55 ms |
| KEVIN | 7.99 ms | 48 / 56 ms | 48 / 55 ms |

The car payload is 880 bytes/s per direction at 20 Hz before transport overhead. Each host sent 15 cone-state packets totalling 451 payload bytes in the tested contact, settling and reconnect sequence. Idle settled cones require no periodic state traffic. A fully displaced 80-cone set at the 10 Hz cap has an 8,910 bytes/s payload ceiling while in motion.

The paired test instances printed Godot ObjectDB shutdown warnings after passing. The loopback results describe this local test and provide no physical Wi-Fi latency or handset frame pacing measurements.
