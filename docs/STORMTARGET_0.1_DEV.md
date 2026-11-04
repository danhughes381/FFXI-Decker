# StormTarget v0.2-dev — two-key targeting prototype

**Development only. Not yet tested in the Storm XI client.** Separate addon; does not modify Decker, Aegis, LuAshitacast, macros, updater manifests, or Stable.

## Design
- **Tab** (opt-in): distance-ranked monster cycle. Each tap chooses the next monster. Initial native Tab is blocked only if smart selection succeeds; no candidates/error means native Tab is left alone.
- **Grave/backtick** (opt-in, key left of 1 on many UK keyboards): select nearest apparently unclaimed monster, with optional name filter. Does **not** claim, attack or cast.
- Supports manual `/stormtarget nearest|next|prev|claim|back`.
- `/stormtarget focus` stores current target (no permanent hotkey); `/stormtarget focusback` restores it while entity ID is valid.
- `/stormtarget filter Fafnir` selects only matching monster names; `/stormtarget filter off` clears it. Filtering currently supports one word; use `/stormtarget exact Fafnir` for an exact case-insensitive name instead of a substring; no fuzzy matching, multiword target names or named priority sets yet.
- Server IDs and zone changes guard stale targets. Monstrous spawn flag 0x10 replaces unsafe NPC flag 0x02; see tirem/statuslib's monster classification.
- **No threat estimation, automatic Rescue, auto-Flash, target-of-target, or party-assist implemented.** These require further investigation and live validation.

## Installation on a test copy
Copy `addons/stormtarget/stormtarget.lua` into `Ashita/addons/stormtarget/stormtarget.lua` and load with `/addon load stormtarget`.

Initially both hotkeys are OFF. Test manually:
```
/stormtarget nearest
/stormtarget next
/stormtarget claim
/stormtarget focus
/stormtarget focusback
```

Then opt in, one key at a time:
```
/stormtarget tab on
/stormtarget context on
/stormtarget status
```
Disable instantly:
```
/stormtarget tab off
/stormtarget context off
```
Or `/addon unload stormtarget`. Settings are session-only, not persisted after reload.

## In-game safety gates
1. Test in a quiet zone before any HNM or multibox engagement.
2. Tab must cycle only actual monsters, not guards, doors, NPCs, pets or Trusts. Do not proceed if monster classification fails.
3. No eligible targets: original native Tab should remain functional.
4. Chat open or search/bazaar input: hotkeys must be inert.
5. `/ma "Cure IV" <stal>`, `<stpt>`, `<stnpc>`, Cover and other menus must retain Tab/Enter/Escape.
6. Verify repeated holds do not auto-cycle, and game input does not see an accidental second Tab.
7. Verify modifier shortcuts (Shift+Tab, Ctrl+Tab) remain native, and Decker's custom nav modifier does not interfere.
8. Confirm claim status against actual claimed/unclaimed enemies, zone transitions, despawns and changing identity.
9. Confirm focus target is correctly restored after switching, and source name filter is case-insensitive.
10. Verify unloaded addon and reloaded Decker/Aegis behave as before.

## Implementation and limits
Uses Ashita v4 `key_data` for initial key capture and `key_state` to prevent held-key repetition, `IChatManager:IsInputOpen()` to gate text entry, `ITarget` subtarget/menu checks and `IEntity` spawn flags, claim and position APIs. Never captures text input WNDPROC event, does not send packets, does not synthesize keys.

Distance = approximate Euclidean local XYZ within 30 yalms, **not actual movement path, target range, or line of sight**. Overlapping or overlapping-key addon conflicts remain possible and must be checked in-client. Current layout hardcodes Tab scan 15 and grave scan 41. The latter might differ on UK keyboards or user keybinds.

The targeting approach was informed by existing Ashita examples and monster flag 0x10 usage in statuslib. This addon remains unverified against Ashita v4.3.2.1 running inside Storm XI, and no GUI or Decker integration is shipped.

## Next steps
Verify keyboard capture and native fallback first; then add high-confidence focus/assist, additional candidate prioritization and user-facing key preferences. Keep manual selection separate from actions until rescue target detection is reliable.

## Upstream reuse audit
See [STORMTARGET_REUSE_AUDIT.md](STORMTARGET_REUSE_AUDIT.md) for a source-level comparison with Targeter, ATA, HitPoints and Focus Target. No upstream code was copied. The experiment now includes an explicit exact-name filter; broader features are deferred until the native and addon selection paths pass live tests.
