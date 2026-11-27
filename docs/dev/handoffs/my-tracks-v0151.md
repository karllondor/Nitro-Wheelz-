# My Tracks v0.1.51

Issue [#61](https://github.com/karllondor/Nitro-Wheelz-/issues/61). Draft review is based on PR #58 at `73a03ca6c17c36f76186fd8d1c9468adbf6a5316`.

## Player workflow

- DRIVE → MY TRACKS offers DRIVE, EDIT, RENAME and DELETE per saved track. DELETE confirms the exact name. TRACK TRASH restores to the original slot.
- Both editors offer OPEN, SAVE, SAVE AS and RENAME. SAVE confirms replacement of the active file. For a new layout it asks for a name. SAVE AS always allocates an independent slot, including when the same name is entered repeatedly.
- OPEN in the Terrain Builder lists terrain tracks. Node-shaped terrain circuits go to the Node Editor, while open terrain routes from the Node Editor go to the Terrain Builder. Node editing of open routes remains tracked in #56.
- Built-in circuits open as copies. Scratch drive slots and editor drafts stay outside the saved track list and Track Trash.

## Storage and records

`PlayerTrackStore` keeps the existing `user://nitro_track_*.json` format. It checks ownership, validates the geometry before publishing and rechecks the confirmed file hash before replacement. Rename edits the display name in-place. The original layout ID stays attached to unchanged geometry, including legacy terrain opened and saved without edits. Layout edits keep the existing fingerprinting policy. PB and stars remain associated with the original layout ID. Trash and restore move the file with its records association intact. Trashed tracks still contribute their stars to the profile. Deleting the current selection falls back to Shin-Kawa and clears stale editor references. Trash is local and has no automatic expiry.

## Owner Android QA

1. Install from the draft PR over the signed v0.1.50 Review 45 app. Keep the existing installation and its data. Open your saved Touge.
2. Make three copies with the same name. Rename one, confirm its PB and stars, and delete another. First cancel deletion to verify nothing disappears, then confirm and use Track Trash to restore it.
3. In the 3D Terrain Builder, OPEN a saved Touge. Edit it, confirm SAVE, and check the list still contains the same number of tracks. SAVE AS should add one. Verify the route loads in a race.
4. In the Node Editor, OPEN a saved closed circuit, test SAVE, then SAVE AS. Open one built-in circuit and check that an editable copy can be made.
5. Delete the last selected custom track. Verify the next race falls back to Shin-Kawa. Check that the My Tracks list scrolls and the confirmation buttons remain reachable in portrait.

The draft PR carries CI results and the Android artifact. The automated Android smoke exercises the workflow on an API 35 emulator. Physical Android acceptance is an owner playtest.
