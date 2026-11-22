# Player card and race setup flow (v0.1.35)

Owner request 2026-11-22 (issue #24). All local, on the device: no account, no network.

## Flow (one RACE SETUP hub joins the track list and the garage)
```
first launch -> WELCOME (name) -> main menu
main menu: [player chip -> PLAYER CARD] DRIVE | GARAGE | TRACK BUILDER | SETTINGS
DRIVE        -> RACE SETUP  (TRACK  ▸ name  |  CAR  ▸ name  |  DRIVE)
  TRACK      -> track list (pick = select, back to RACE SETUP; it never starts the race)
  CAR        -> garage (BACK = RACE SETUP)
GARAGE (from the menu or from RACE SETUP): cars, SIGNATURE / PAINT / WHEELS,
  TRACK ▸ name -> track list (pick -> back to the garage), BACK, DRIVE (selected track)
PLAYER CARD: avatar + name + total stars; SKIN / HAIR / STYLE / T-SHIRT;
  TRACKS DRIVEN (best time, best points, best stars): tap = select that track -> RACE SETUP
  (the car is chosen there through CAR ▸ garage)
```
Implementation: `scripts/boot.gd` pages `welcome`, `setup`, `profile`, `drive`; the scene changes remember where to land via
`nitro/boot_page` (first page after the scene loads, consumed once), `nitro/track_return` (`setup` | `garage`) and
`nitro/garage_return` (`main` | `setup`). The last chosen track is saved (`last_track`) for the next launch.

## Rules and limits
| what | rule |
|---|---|
| player name | 2 – 14 characters; letters (incl. Polish), digits, space and `- _ . '`; spaces collapsed; anything else is dropped; empty = `DRIVER` |
| car label (catalog `short`) | at most 14 characters (`tests/player_profile_test.gd` checks every car) |
| TOP RUNS table | `# | DRIVER | CAR | STARS | TIME | POINTS`; POINTS flush right, TIME right-aligned next to it, DRIVER (56 %) and CAR share all the rest; a longer text shrinks to fit instead of being cut |
| avatar | skin (6 tones), hair colour (8), hair style (4: SHORT, LONG, BUZZ, CAP), t-shirt colour (10); drawn with vectors (`scripts/ui/avatar.gd`), saved as palette indexes (out-of-range values are clamped) |
| total stars | the best stars of every driven track, summed; only tracks that can still be loaded are listed |
| records | each run stores the driver and the exact car (older runs stay UNKNOWN); ranking is by points as before |

Files: `scripts/player/driver_profile.gd` (name, avatar, last track; `user://nitro_driver.cfg`), `scripts/player/player_progress.gd`,
`scripts/ui/avatar.gd`, `scripts/ui/race_results.gd` (`top_run_columns`), `scripts/ui/garage.gd`, `scripts/boot.gd`.
