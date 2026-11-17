# Storm XI — macro quality and pressure-test standard (proposal)

Status: **audit framework only**. No character macro has been read or edited by this change. Do not claim live verification from mocked-host tests.

## Scope and boundaries
- Applies to Peppa PLD/NIN, Salts BRD and eventually all six clients/jobs. Inspect the actual six-line native macro bodies and saved book/set positions before suggesting replacements. Decker currently sees macro names, not a trustworthy six-line command export.
- Preserve native FFXI macros and user layouts, Right Shift mapping, targeting, Aegis gear management, Nexus, StormTarget, multibox and launcher.
- Every change must be reversible: back up the corresponding USER macro files before any write and retain book/set/slot mappings. No bulk writes without a verified parser and explicit acceptance.

## Quality gates: every combat macro
1. **Single primary action** unless a multi-action sequence is explicitly deliberate; one button should do one clearly predictable thing under pressure.
2. **Action availability:** resolve actual spell/ability ID and in-game recast; distinguish cooldown from casting lockout. A button's indicator must not imply readiness when the character is unable to execute.
3. **Target safety:** specify intended target selector for self, enemy, party or subtarget. Keep <stpc>/<stal>/<stpt> input with native FFXI and do not retarget the engaged enemy unexpectedly.
4. **Reliable execution:** validate full command sequence and any /wait; avoid long waits that can be interrupted by a new macro; do not queue multiple high-priority actions on one button.
5. **Aegis compatibility:** no competing gear swaps while Aegis owns precast/midcast/aftercast; preserve PLD/NIN shadow handling, cure timing, BRD song duration/gear and all custom settings.
6. **Combat ergonomics:** critical actions within immediate reach and consistently placed across sets. Provoke and Flash separate but adjacent for PLD/WAR; cures, Utsusemi, Sentinel/Shield Bash and emergency tools readily accessible. Never silently remap other job books.
7. **Failure clarity:** invalid target, cooldown, insufficient MP/TP, silence, stun, out-of-range and interrupted selection must not result in a second accidental action or sticky Decker keyboard capture.
8. **Server/era correctness:** verify 75-cap rules, job/subjob, learned spell availability, server changes and actual recasts; do not assume retail-modern behaviour.
9. **One source of truth:** the native recast manager for spell/ability timing; Decker overlays are display-only and never fabricate timers from button presses. Recast ID mapping may be manually confirmed when a macro has multiple actions.
10. **Multibox independence:** buttons and recasts must track the actual character and relevant job; no accidental IPC broadcast to other clients.

## Pressure-test matrix — per critical slot
- Idle: action executes once; pressing again within cooldown does not trigger duplicate side effects.
- Engaged in combat: target remains correctly selected.
- Friendly-target macro: enter selection, arrows, Enter and Escape all work; return cleanly to Decker navigation. Run in Hold and Toggle.
- Chat input open: Right Shift, row switch, arrows, Enter and configured direct/StateBar shortcuts do not execute Decker actions. Confirm both new chat and pre-existing held keys.
- Cast interrupted / target dead / untargetable / out of range: UI recovers, no stale suppression or incorrect ready indicator.
- Under rapid input: repeated keydowns, missed keyup, delayed target prompt and quick swapping across books/sets.
- Aegis midcast/aftercast state and recast overlays remain correct, including rapid cures and Utsusemi.
- Multiple clients: Peppa, Salts and others have isolated mappings and correct recasts; party control unaffected.
- Persist through reload, zoning, job change and restarting launcher. Verify backup and rollback.

## PLD/NIN initial control priorities
- Provoke is available only if subjob/job grants it; do not place an unusable button on a PLD/NIN primary combat row.
- Flash remains separate from Provoke because its targeting, MP requirement and recast differ.
- Preserve precise self/party Cure IV selection and existing target; test in combat and with chat focus open.
- Utsusemi: Ichi/Ni must respect existing Aegis and shadow-overwrite handling, and must not chain mindlessly.
- Shield Bash, Sentinel, Rampart, emergency abilities, enmity and mitigation swaps remain independently reachable.
- Group by reaction priority, not alphabetically; avoid speculative reassignments without original macro book/slot inventory.

## Acceptance and reporting
Record character, job/subjob, book/set/row/slot, original six lines, revised six lines, expected target, recast ID, Aegis integration, test result and rollback path. Only call a macro *pressure-tested* after both offline regression and a live target-host confirmation. Track untested items explicitly.

## Next engineering tasks
1. Implement **read-only** acquisition of native macro bodies or safe export of saved macro files; test parsing with fixtures, never guess from names. Avoid invasive FFI for editing.
2. Create a macro linter with deterministic checks (duplicate abilities, conflicting targeting, long waits, unknown action IDs, unreachable actions, crossing Aegis ownership).
3. Build job/subjob and character-specific recommendations, with before/after diff and backup.
4. Extend current Decker cooldown binding into an accurate clock/5-second countdown overlay, using Ashita's real recast values, with tests.
5. Test Peppa PLD/NIN and Salts BRD end-to-end before rolling out to other accounts or jobs.
