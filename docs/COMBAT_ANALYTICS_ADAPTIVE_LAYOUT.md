# Storm XI — Decker Combat Analytics and Permissioned Layout Adaptation

Status: technical specification; **not implemented or enabled in the addon**. Version baseline: v1.50.31-dev. Preserve existing native macros, key mappings, Aegis, Nexus and other addons.

## Goals
Use actual Decker input to learn which controls are high-use, high-urgency, awkwardly placed or redundant during HNM, NM and EXP play. Produce per-character/job/subjob recommendations with no surprise changes.

## Capture and what is measurable
1. Instrument the central `execute_slot(row,slot)` function once (mouse, direct assigned keys and navigational Enter already funnel through it). Record *requested execution* after connection/validation and native invocation; record refused invocation separately. No assumption that a native invocation successfully cast an ability.
2. Instrument StateBar *utility command* requests separately, and expose navigation effort: page changes, row switches and distance from the prior action.
3. The actual macro body is **not currently available** from Decker's name-only reader. Do not silently infer the spell/ability from an eight-byte button label. Identity key: character ID, job/subjob, macro book/set, row, slot, name-page fingerprint; optionally verified primary spell/ability ID. Treat generic and multi-action macros explicitly.
4. Current combat success/interrupt data cannot be inferred just from Decker button activation. A future optional Ashita outgoing-action/incoming-packet or battle-message observer could correlate attempts to confirmed actions, failures and recast, but must be separately verified on Ashita v4/Storm XI.
5. Counts should distinguish **presses (including repeated taps)**, native executor requests, refused requests, known cooldown attempts, confirmed successful actions (only once verified), and player-selected cancellations. Source of input is useful: click, direct key, navigational Enter, StateBar.
6. Data should default local, with optional bounded session logging, per-character isolation, bounded memory/retention and no chat text, player coordinates or private server credentials.

## Session types
- HNM: user-started named encounter (e.g. /decker session start hnm Tiamat), optional future start/stop from authoritative combat signals only. Show duration, normalized presses/min and phase-specific activity. Ensure dying, zoning or relogging closes/suspends session cleanly.
- EXP camp: user-started camp window; summarize actions/min, rate per fight when kill signals actually available, stretches of inactivity and page navigation. No guessing mob/kill counts.
- Other: simple timed practice session.
- Never conflate a single HNM's 25-minute fight with hours of EXP; normalize within session type and sample size.

## Scoring and recommendations
- Preserve a **criticality score** independent of frequency: Flash, Cure IV, Utsusemi, Shield Bash, Sentinel etc. may be emergency/defensive, not low-priority because rarely clicked.
- Observed metrics: count, presses/min, multi-press bursts, late cooldown reattempts when grounded by real recast, row/page switch overhead, action sequences (Flash → Cure IV), key travel and context-specific mis-selection.
- Offer adjacent grouping where pairs are frequently sequenced; prioritize emergency access; flag unused or duplicate labels for review, never auto-delete.
- Minimum sample requirement: at least 3 comparable sessions and substantial input counts; show confidence, negative cases and whether action ID association is verified.
- Do not use raw popularity alone to move buttons; most-used should not displace a lifesaving emergency action.

## Permission levels
- **Observe** (default): logging and reports only, no UI/control movement.
- **Suggest**: preview old vs proposed overlay arrangement and explanations, never commit layout automatically.
- **Approve once**: user explicitly chooses proposed layout; backup exact per-character config and verify restore.
- **Adaptive between sessions** (future, explicit per-character opt-in): only change a Decker presentation/shortcut layer after the session and away from combat; show exact diff and offer undo. This is never enabled by default.
- **Never rearrange during combat**, inside friendly-target selection, while chat is open, or on zone/login/job transitions. Do not change native FFXI macro books, sets, contents or game keybindings without separate explicit consent. A preview must identify whether a proposed slot is display-only or changes the bound action.

## Main technical hazard: display order vs actions
Decker's two main rows currently map to native CTRL/ALT macro slots. Merely reordering their visual buttons would be misleading if click or keyboard activation still targets old slots. Either:
(a) implement a verified, reversible *virtual layout mapping* applied consistently to rendering, mouse clicks, keys, StateBar shortcuts and cooldown IDs; or
(b) limit rearrangement to recommendation previews until that mapping is tested.
Mapping must respect 20 books × 10 sets, per-character profile, non-matching fingerprint invalidation, duplicate slots, job changes and save/reload. Do not physically edit native macros.

## Acceptance and failure injection
- One physical key press => at most one request event; key repeat bursts counted accurately, not mistaken for successes.
- Mouse button, keyboard key, navigation Enter and StateBar pathways all counted; no double count.
- Refused disconnection, empty slot, invalid signature/pointer, guide preview, chat/target focus and cooldown events are classified without fake success.
- Profile and book/set switching never mix logs; HNM and EXP results separated; no cross-character leaks on multibox.
- Crash/abrupt exit and corrupt log cannot break gameplay, block a macro or corrupt a profile.
- Suggest/approve/revert lifecycle tested; no mid-combat, chat or native-target remap.
- Game integration: Peppa PLD/NIN HNM and EXP tests; Salts BRD including song swaps; multiple clients; verify exact input counts and latency overhead.
- Full Lua 5.4 and LuaJIT mock regression suite, benchmark draw/event overhead, and Windows/Ashita in-game acceptance required before enabling adaptive layout or marking pressure-tested.

## Proposed implementation slices
1. Central *local-only recording* module and explicit session start/stop, summaries. Keep no control changes. Dev build only after regression.
2. Job-aware analytics dashboard/report and export to Storm Companion; compare HNM vs EXP and account-by-account.
3. Recast overlays from grounded Ashita timers; correlate excessive presses during cooldown without assuming successful action.
4. Manual approval/reversible virtual layout engine with full keyboard/mouse/target mapping verification.
5. Optional between-session adaptive suggestions with explicit permission and reliable rollback.
