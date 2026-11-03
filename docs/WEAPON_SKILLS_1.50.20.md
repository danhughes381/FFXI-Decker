# Weapon-aware WS slots — 1.50.20-dev

Manual test candidate built on held-arrow navigation PR #16 (source 4a35dd7). Not a channel promotion or a live-tested build.

## Install and configure

1. Back up your current `addons/decker/decker.lua` and character `.cfg` files. Close/reload the addon around installation. Extract this candidate's `addons/decker/decker.lua` into the Ashita folder, preserving existing cfg files.
2. In FFXI's macro editor, choose three slots in your usual book/set. Name them exactly `WS-ST`, `WS-AOE`, `WS-UTIL`. Leave their command lines empty. Replacing populated macros is your choice; back them up first.
3. Connect Decker to in-game macros and refresh names.
4. Open Decker Settings → More → Weapon skills. Enable weapon-aware WS slots.
5. Equip your sword. Enter exact English WS names for Primary single-target, AoE and Utility. Example choices are Atonement, Circle Blade and Spirits Within; this does not establish that your character/server has them unlocked.
6. Equip another weapon and save its three choices. Choices are specific to this exact main-hand item ID, main/subjob and existing server/character profile. No weapon-type defaults or automatic highest-damage ranking yet.
7. Stay in the same book/set. Decker should display the saved actual WS names in those positions. Click or use Decker assigned keys to request one WS. Native FFXI macro execution does not implement dynamic markers.

The game still validates weapon compatibility, unlocks, TP, distance and target. Decker does not claim a submitted command executed successfully. It never tries alternative WS commands. A missing choice does nothing. Spirits Within is an explicit utility choice; HP does not cause automatic switching. Existing LAC/other WS gear handling remains the equipment owner; no Aegis transport or new gear writer is added.

Only the main-hand weapon is considered. Weapon identity is read with the existing Aegis Ashita v4 getter pattern (`GetEquippedItem(0)`, packed bag/index, `GetContainerItem`). Labels are refreshed at most ten times per second; execution rereads context. A weapon/configuration change since the displayed selection blocks that press, refreshes labels and requires another press. Zoning or identity uncertainty blocks WS requests.

## Live acceptance still required

- Sword → dagger → staff, same book/set, all three labels and one-command requests.
- Exact WS spelling, ownership/unlocks and level-75 server availability; fixture names are not server evidence.
- Existing gear handler's actual WS gear changes and restoration.
- Weapon swaps during input, zoning, disconnect, job/subjob changes, character switches and reload.
- Mouse, navigation Enter and assigned keys; no repeats while holding an action key.
- Existing held arrows, End/Right Shift and book titles from PR #16.
- FPS/frame time on the owner's client. No performance improvement is claimed from mocked tests.

PDT/MDT and other persistent gear modes belong on owner-selected F6-upward bindings, outside the action macro rows. This feature does not rebuild macros or change any existing F-key assignment.

## Offline validation

82 Lua 5.4 mocked regression groups passed, including seven WS groups covering display/dispatch, stale-selection blocking, job/weapon/character isolation, persistence, missing choices, malformed commands, zoning/identity/API failures, connection/guide gates and settings rendering. ZIP source equality/integrity and diff checks pass. LuaJIT/native Windows/Ashita/VanaCore execution remains unverified.

Rollback: restore the backed-up Lua file. Disable/remove dynamic marker slots or restore the original game macros; older Decker builds treat them as ordinary macros. No updater manifests, release tags or Aegis code are changed.
