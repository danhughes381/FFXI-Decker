# StormTarget v0.3-dev — configurable two-key selection and explicit engagement

Status: CODE COMMITTED TO DRAFT PR #19. No in-game acceptance, full Lua execution test, Decker conflict test, or successful melee-switch proof. Do not install over a production/stable addon.

## Two configurable keys
Initially both interceptions are OFF on every addon load. Default DIK keys: TAB (cycle), GRAVE (context; on many UK layouts the key left of 1). Any key in the allowlist can be assigned, subject to conflicts with Decker, macro bindings, game controls or Windows keyboard shortcuts.

```text
/addon load stormtarget
/stormtarget bind cycle F11
/stormtarget bind context F12
/stormtarget tab on
/stormtarget context on
/stormtarget status
```

Supported key names: TAB GRAVE F11 F12 HOME ENDKEY INSERT DELETE PAGEUP PAGEDOWN Q E R T G V B N M. These are DirectInput scan-code names, not necessarily the visible characters on a UK keyboard. Two bindings cannot share a key. Bindings are session-only in this prototype, and there is NO GUI.

## Context key modes (choose ONE)
```text
/stormtarget mode claim
```
The context hotkey selects the nearest candidate whose observed claim status appears unclaimed. **No attack is issued.**

```text
/stormtarget mode engage
```
The context hotkey requests `/attack on` for your **currently selected living monster** and remembers that monster as the last explicit engagement request. This may start auto-attack. It does not select a new enemy automatically.

```text
/stormtarget mode resume
```
The context hotkey returns to the most recently **StormTarget-requested** engaged enemy and requests `/attack on` again. If no live remembered engagement is available, it only reselects the last StormTarget-selected monster.

**Important:** The addon does not observe every action performed by standard macros, external addons, manually selecting enemies, or casts such as Sleep/Cure/Flash. Therefore 'last action' currently means only its OWN explicit engagement requests and selections. It cannot claim to read the last action performed on every mob or guarantee engagement actually happened. A server-verified attack/action event observer could be added later.

## Commands usable without changing key mode
```text
/stormtarget nearest
/stormtarget next
/stormtarget prev
/stormtarget engage
/stormtarget resume
/stormtarget back
/stormtarget focus
/stormtarget focusback
/stormtarget claim
/stormtarget exact Fafnir
/stormtarget filter off
```

### Example: Paladin melee + utility
1. Select Goblin A, then `/stormtarget engage`. This queues native `/attack on` and remembers Goblin A.
2. Select Goblin B using cycle hotkey. Cast Sleep or Flash using your normal macro. Selection MUST NOT issue attack.
3. Put context in `resume` mode. Press context key: return to Goblin A, issue explicit `/attack on` request.

If you attacked Goblin A using only a normal FFXI menu or another addon, StormTarget **does not know that**. Use `/stormtarget engage` at least once if you want it to remember your engagement request.

## Safety and compatibility
- No attack from cycle, claim, nearest, back, focus or focusback.
- No automatic threat/Rescue system, target-of-target inference, auto-Flash, Provoke, packet injection, or gear changes.
- No Tab interception by default; bindings off until `/stormtarget tab on` / `context on`.
- Chat, native menus, action subtargets and modifier-held shortcuts should be protected, but still require in-game testing.
- `/attack on` is native, but **switching an already engaged melee target without disengaging requires live test**. FFXI has a separate native Switch Target command. If targeting and queued attack do not result in the intended melee switch, do not assume success.
- Target identity checked with server ID and index; zoning clears memory. A despawn invalidates prior memory.
- Recording command queue success does not mean the attack connected, nor that the server accepted engagement.

## Must-pass manual tests before enabling on main characters
1. Load with both hotkeys OFF; existing Tab and Decker control work.
2. Bind to different keys; verify duplicate assignment rejected.
3. Enable only cycle; verify sorted selection with 3 monsters, and no auto-attack.
4. With an enemy slept, cycle to it and confirm no attack command is emitted.
5. Engage with explicit command out of combat; confirm weapon drawn and server/client target.
6. Cycle to a different add, use an ordinary spell, then resume the last engaged target. Verify FFXI switches actual melee target or report exact mismatch.
7. Test normal game engagement (not StormTarget): verify it is NOT automatically remembered.
8. Verify <stal> alliance cure, <stpt>, <stnpc>, Cover, Enter/Escape, chat input and Decker overlay are unaffected.
9. Check claimed/other-player mobs, Trusts, pets, NPCs, zoning and despawns.
10. Test both hotkeys OFF, addon unload, repeated key holds, keyup, and accessibility keys.
11. Test with Ashita v4.3.2.1 and Storm XI client (not merely mock APIs).
12. Only after passing add per-character hotkey persistence and an optional Decker settings panel.

## Reference
- StormTarget PR #19: https://github.com/danhughes381/FFXI-Decker/pull/19
- Native `/attack on`: https://ffxiclopedia.fandom.com/wiki/Command/attack
- Native Switch Target: https://ffxiclopedia.fandom.com/wiki/Command_Menu
- Reuse audit: STORMTARGET_REUSE_AUDIT.md
