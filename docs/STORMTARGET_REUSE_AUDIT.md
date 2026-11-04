# StormTarget — reuse-before-rebuild source audit
Date: 2026-11-04
Status: review of accessible upstream source; not a Storm XI live validation.

## Decision
Do **not** build a broad new target framework. Keep the optional Ashita-facing adapter small, make FFXI native targeting the baseline, and selectively implement ONLY features unavailable natively:
- Explicit distance-ranked cycling (Tab, opt-in);
- Nearest truly hostile and unclaimed selection with name/priority filters (second hotkey, opt-in);
- Focus identity for restoring a boss target, only if Ashita native focus/target retrieval does not satisfy it;
- Threat/rescue **later**, and only from independently validated signals.

Leave ordinary combat actions to native macros and Aegis/LuAshitacast; Decker owns display/hotkey presentation only. No auto Flash, packet injection or automatic battle commands.

## Source review

### FFXI Targeter (xurion/ffxi-targeter, targeter.lua, README.md)
https://github.com/xurion/ffxi-targeter
- Windower 4 addon. target_nearest calls get_mob_array, requires valid_target and positive HP, exact case-normalised names from a list, chooses minimum distance.
- Commands add/remove/once, saved and loaded named target sets.
- Uses packets.inject incoming chunk 0x058 to set target: implementation is not portable to Ashita directly.
- README documents an outstanding targeting delay in busy Dynamis areas.
- No explicit repository licence seen in file listing; use general design concepts, **do not copy source**.
- Take: exact-name lists and nearest eligible matching target, not its Windower targeting transport.

### AutoTargetAssist (kabitokaii/FFXI-Addons/ATA/ATA.lua and README)
https://github.com/kabitokaii/FFXI-Addons/tree/master/ATA
- Windower 4 addon; observes party/enemy actions for a **pseudo** enmity list; prioritizes auto next target after death, configurable HP/distance and blacklist, raid-assist target and visual bars.
- Author explicitly warns it reads/injects packets, and switching latency can depend on incoming game traffic.
- ATA.lua includes permissive 3-clause BSD-like redistribution and nonendorsement terms. Preserve notices if ever copying code.
- Take: policy ideas (enemy shortlist, blacklist, assisted target) only after native manual targeting passes. Do not claim its estimated enmity identifies whom an enemy will attack.

### HitPoints (tirem/HitPoints)
https://github.com/tirem/HitPoints
- Ashita v4 addon. engaged.lua calls gStatusLib.GetRelevantEnemies(), draws a list and uses QueueCommand(-1, '/target ' .. decimalId) for a click; target.lua uses target status information.
- Repository MIT licensed. Some runtime dependencies use git submodules; assess required libraries before installing.
- Take: test existing addon standalone for observed enemies and target-of-target; investigate whether its relevant-enemies query provides reliable *data*, but do not create a forced runtime dependency on its HUD or copy modules unnecessarily.
- Its tracked/relevant enemy list is NOT a proven server hate table.

### Focus Target (xurion/ffxi-focus-target)
https://github.com/xurion/ffxi-focus-target
- Windower addon. Tracks entity ID, displays HP/status and optional autofocus; target-change handlers clear/refresh after target depops.
- Take: target identity lifecycle and user-visible focus behavior, NOT full UI.

## Reassessment of existing StormTarget v0.2
Current draft: https://github.com/danhughes381/FFXI-Decker/pull/19
- Already supports manual next/prev/nearest, nearest observed unclaimed, optional Tab and grave hotkeys, basic name substring filter and focus restore. None of this is yet in-game accepted.
- The default distance=30 is merely a candidate search radius, not a verified targeting, claiming or action range.
- Current unclaimed test uses claim-status mask (0xFFFF); this MUST be validated against actual server ownership before advertising a reliable claim selector.
- Current filter is **substring**, unlike Targeter's exact-name saved sets; don't claim it is equivalent.
- Current target change uses ITarget:SetTarget(index,false), NOT the native '/targetbnpc' command. This Ashita operation is source-declared but its in-game compatibility, pickup latency, native UI behaviour and access under subtargets are unverified.
- Tab interception is opt-in and guarded; **do not treat keyboard capture/fallback as tested**. Native chat, subtargets, Decker, and all relevant conflicting hotkeys must pass actual client testing.
- The target may not be interactable just because spawn flag 0x10 and positive HP were observed: verify monster and targetable flags and pet/trust cases.
- No UI/hotkey config persistence, no full-name saved set, no dedicated rescue targeting or raid assist. These are not release-ready.

## Next milestone — minimal, observable tests
1. Test native /targetbnpc and compare its selection behaviour/latency against /stormtarget nearest, with a friendly NPC, a pet/Trust and three monsters in range.
2. Test StormTarget commands WITHOUT intercepting Tab. Verify list ordering, closest vs exact names, target validity, and claim flags.
3. Enable Tab only in a quiet zone. Confirm chat typing, alliance cure <stal>, party cure <stpt>, Cover, <stnpc>, Enter/Escape, and Decker macro HUD unaffected. Holding Tab must not repeat.
4. Test Focus return after a target dies, despawns, or zoning.
5. Test HitPoints on Ashita v4 separately: whether engaged-list tracking helps select an add while tanking, with minimal performance cost.
6. Only after the above: add exact-name priority sets, optional second context hotkey, and a non-actioning threat-candidate *display*. For Rescue, require real evidence from spell/attack events or target-of-target, confidence plus manual confirmation.

## Hard constraints
- Two hotkeys at most (Tab + one configurable context key); no added required macro buttons.
- Never intercept Enter/Escape or subtarget menus.
- Do not silently equip, attack, Flash, Provoke, change jobs, or replace existing Aegis/Decker profiles.
- No licence-incompatible copying; retain upstream notices if reusing permitted code.
- Keep v0.2 in draft until syntax, mocked tests and actual Ashita-v4/Storm-XI in-game tests pass.
