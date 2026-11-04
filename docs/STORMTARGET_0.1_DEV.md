# StormTarget v0.1-dev — isolated targeting prototype

This addon is optional, manual-only and **not verified in the running Storm XI game**. No existing Decker or Aegis file is changed. No releases or updater manifests are changed. No global Tab/Enter hooks, automated spell casts or packet injection.

## Install for supervised testing
Copy `addons/stormtarget/stormtarget.lua` to `Ashita/addons/stormtarget/stormtarget.lua`, run `/addon load stormtarget`, then `/stormtarget help`. Use temporary game macros:

- `/stormtarget nearest`: nearest loaded living NPC/monster-class entity.
- `/stormtarget claim`: nearest such entity with no observed claim ID; **selects but does not claim**.
- `/stormtarget next` / `prev`: cycle by Euclidean distance, tie-breaking on entity index.
- `/stormtarget back`: return to prior entity if its server ID still matches.

Selection radius is 30 yalms, **not guaranteed spell/JA range**. No guaranteed line-of-sight, hostile-only classification, or complete aggro information. A friendly NPC can still meet the NPC/monster flag; test this before using in combat. Zone-change history reset is not implemented; server-ID verification reduces but does not remove stale-target risk. The addon refuses selection while native subtarget/menu is active to avoid stealing alliance cures, Cover or confirmation keys. Use `/addon unload stormtarget` to turn it off.

## Mandatory acceptance
1. Verify the addon loads on Ashita v4.3.2.1 without errors.
2. Check nearest and forward/backward cycle with multiple monsters.
3. Check a friendly NPC within range; stop if selected.
4. Check claimed vs unclaimed mob without attacking.
5. Try `/ma "Cure IV" <stal>` while Decker is both open and closed; Enter must confirm independently.
6. Check `back` after despawn, and after zoning.
7. Check that selection never implicitly casts or claims.
8. Do not deploy to Stable or assign Tab/Enter until these checks pass.

## Architecture
Only supported high-level Ashita v4 memory getters and target `SetTarget(index,false)` are used. This prototype is a separate addon; later we can move a verified targeting service under Aegis and bind it from Decker. Rescue should first **display** candidate threats based on combat observations; entity targeting alone cannot establish a trustworthy hate table.

Official interface reference: https://github.com/AshitaXI/Ashita-v4beta/blob/main/plugins/sdk/Ashita.h
