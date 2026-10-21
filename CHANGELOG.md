# Version history

## 1.50.13-dev — clear updater status

- Show installed and published channel versions for update available, up-to-date and older-channel results.
- Remove obsolete text claiming Stable has no published updater release. Both channels are maintained.
- 54 host-mocked regression groups pass, including both-channel check, update offer, install, exact backup and reload. Actual HTTPS manifests and pinned-source hashes verified; Windows PowerShell and in-game installation remain pending live confirmation.

## 1.50.12-dev — named header and inline book controls

- Show the selected book name in the HUD heading, using the same alias/imported-title source as the Settings book selector. Keep fixed status/active-row columns and full-name hover. Long header titles abbreviate after 15 bytes.
- Rename Set to Macro set and add adjacent book previous/next buttons plus named book picker. Book selection still calls the native game function.
- Match the target client screenshot: book selectors/native request bounds use 1-20; each book has 10 macro sets. Explain that equipment sets are separate gear presets. Read titles only from mcr.ttl for these 20 books.
- User confirms book changes 1-3 worked in v1.50.11. New heading/footer layout still needs live confirmation. 52 mocked regression groups pass.

## 1.50.11-dev — minimal active-row header

- Remove key layout and mod-key text from HUD header. Keep only Active row: Upper/Lower beside identity/book/mod status, at the fixed column position.
- Keep layout/custom-key information in Settings and unverified-set detail in the book-heading tooltip. Execution and bindings unchanged.
- Includes all previous fixes; 50 mocked regression groups pass. Live confirmation pending.

## 1.50.10-dev — header key labels

- Header now says Active row: Upper/Lower and Mod key: followed by the actual configured mod key (for example RSHIFT), rather than labelling the row-switch key as a mod. Fixed header positions retained.
- Includes previous fixes; 50 host-mocked regression groups pass. Live confirmation pending.

## 1.50.9-dev — connection defaults, macro echoes and named books

- Rename connection buttons to Connect to in-game macros. Assigned keys default on after successful connection; preserve saved opt-out and keep execution off before/after failed connection.
- Toggle chat echo says Macros locked/unlocked; colour only locked red through the host chat API. Rename echo setting to Echo macro visibility on/off to chat.
- Add native book selector under Book and Set controls; support upstream 1-40 book indices with existing native signature/pointer gates. Set buttons remain available.
- Add read-only saved-title import from user-specified character macro folder (mcr.ttl and optional mcr_2.ttl). Strict 344-byte/20 fixed-record ASCII reader, atomic title-cache updates, no game-file writes. Add per-character Decker-only alias fallback and header tooltip. This is saved-file import, not live book-name synchronization.
- 50 host-mocked regression groups pass; live connection/input/chat/book/file confirmation pending.

## 1.50.8-dev — native-style Hold visibility

- With mod hotkeys enabled, Hold mode shows the macro HUD only while the physical mod key is held and hides it on release, regardless of Appearance timers/startup grace/force-reveal. No recovery tab appears on Hold release. Settings and StateBar retain independent visibility.
- Toggle mode retains Appearance inactivity timing; default auto-hide remains off so the full macro HUD is visible by default.
- Appearance Display section defaults expanded. Explain mode-specific timing and warn to finish first-time setup before Hide completely.
- 45 host-mocked regression groups pass; live physical input confirmation pending. Includes all earlier feedback fixes.

## 1.50.7-dev — stable header columns and mod status colours

- Give identity, mod status and key details fixed header columns. LOCKED/UNLOCKED/HELD length and book digits no longer shift key details.
- Render LOCKED and HELD in red and UNLOCKED in white; scope colour to status only. Status follows the actual selected hold/toggle mode.
- Rename mod choices to Hold key pressed down and Press key once (Toggle), preserving behaviour.
- 42 host-mocked regression groups pass; live confirmation pending. Includes all earlier feedback fixes.

## 1.50.6-dev — compact header and StateBar Settings visibility

- Rename StateBar Configure to Settings, shown only while the main Settings window is open. It selects the StateBar settings tab. Remove unused footer space when closed.
- Place HUD identity/book/mod status and shared/custom-key/active-row/row-switch details on one line with spacing between groups. Reduce default HUD height.
- Add collapsed Windows Shift shortcut help for Shift mod users. Keep current bindings and Windows accessibility settings unchanged.
- 40 mocked regression groups pass; live layout and Windows handling still need confirmation. Includes all preceding feedback fixes.

## 1.50.5-dev — simpler keyboard setup and Settings close

- New profiles default to both rows using 1-0; preserve saved layouts.
- Replace two keyboard permission switches with one Use my assigned keys switch immediately below Connect macros. Layout and slot editing is gated on connection and that switch.
- Simplify Advanced keys with Macro visibility mod key, Switch row key, Macro mod behaviour and Enable hotkeys. Keep short help beneath each control; cooldown options have their own section.
- Add Customise keys for both rows button and explicit Custom keys status. Slot edits activate and persist custom routing, superseding presets; selecting a preset resumes it. Migrate legacy edited split mappings without changing keys.
- Settings native title-bar X now updates the Settings visibility state, including collapsed windows.
- 38 host-mocked regression groups pass; live confirmation pending. Includes all prior feedback fixes; no updater/main promotion.

## 1.50.4-dev — visibility and StateBar usability

- Add persistent Show scrollbars toggle for HUD, StateBar and Settings.
- Allow full auto-hide with no recovery window; optional recovery is one small Decker button opening Settings. Settings works when HUD is manually hidden. Add visible command help and Show macros in Settings.
- Preserve shared number/F-key routing confirmed working by the user; clarify layout selection, configured navigation/row-switch keys and active row.
- Make StateBar keyboard switch independent of main direct shortcuts, retaining connection gates, collision checks and input suppression. Display OFF/READY/WAITING status.
- Fit StateBar name and key text to its scaled box; add full action/key/behaviour tooltips. Separate macro action from physical shortcut in Settings and explain State/Utility inline.
- 34 host-mocked regression groups pass. Live Ashita/Vanacor F11 interception, rendering and controls still require confirmation.

## 1.50.3-dev — hide overlay title bars

- Use an explicit open-state table for overlay Begin calls so the host receives the window flags without a nil argument.
- Apply NoTitleBar to HUD, StateBar and collapsed tab; use hidden window IDs so only the content heading contains writing.
- Make overlay title colours transparent as a visual fallback. Settings retains its title bar.
- Includes all 1.50.1/1.50.2 fixes; 28 mocked regression groups pass. Live title-bar confirmation pending.

## 1.50.2-dev — hover tooltip

- Pass the macro name directly to the host tooltip API; remove the literal %s placeholder seen in the v1.50.0 game screenshot.
- Retain all v1.50.1 feedback fixes. Add a regression covering plain names, percent characters and empty slots.
- 27 mocked regression groups pass; live tooltip verification pending.

## 1.50.1-dev — feedback fixes

- Respect button width and compact key labels in glass and fallback renderers. Resize windows when display preferences change.
- Anchor locked HUD, collapsed tab and StateBar positions; retain independent locks.
- Use a 7px Settings scrollbar; clarify size, highlight colour, keyboard permission and macro source labels.
- Expand direct key choices with number pad, punctuation and editing keys. Expose macro assignments separately from navigation.
- Capture StateBar physical key edges and held state, with duplicate prevention and native modifier exclusion. Show assigned hotkey on the bar, omit State/Utility captions, and explain both behaviours in Settings.
- 26 mocked regression groups pass; live dragging/input and LuaJIT verification pending. Manual dev candidate; updater pins unchanged.

## 1.50.0-dev — floating glass first pass

- Preserve two rows, button sizing, input/execution and independent StateBar logic.
- Add borderless black glass with separate outer/panel/button/StateBar background opacity; keep text opaque.
- Add installed Arial Bold and alternative font choices, font size, centred fitted names and bottom-right keys; cache fonts outside rendering.
- Distinguish persistent execution fill from gold navigation outline; retain active StateBar colours.
- Add compatibility fallback, 7 regression groups and an explicitly labelled offline renderer simulation.
- 22 mocked groups pass under Lua 5.4; LuaJIT and live Ashita/Vanacor verification pending. Manual development ZIP; no stable release or updater promotion.


## 1.49.6-dev — in-game updater

- More → Updates now checks the development/stable channel and offers Install update and reload Decker.
- HTTPS runs in a background Windows PowerShell process, polled once per second with a 45-second process timeout. No blocking network calls on the game thread.
- Download pinned commit source; verify SHA-256 in the worker, validate version and LuaJIT syntax locally, back up source and restore on a failed final rename.
- Confirmed rollback restores the prior source and requests addon-only reload. Character settings are preserved; native macros need reconnecting afterward.
- Stable channel deliberately has no published manifest until a release is verified. Windows transport/reload remain unverified in game.
- Added updater regression coverage for manifest/version checks, exact backup/rollback, syntax rejection, process lifecycle and unsupported hosts.

## 1.49.5-dev — integration candidate

- Integrated Library v1.49.4 usability source onto the existing v1.48 development branch; main was v1.47. No open PRs existed at inspection.
- Quick Setup opens first; Connect and accurate keyboard readiness appear together. Retained four top-level Settings sections and advanced disclosure; removed a dead duplicate Book/Set block.
- Fixed cross-character appearance, StateBar hotkey/selection and permission leakage. Clear native connection, labels and deferred navigation when identity changes; fresh keyboard consent is required after reload/change.
- Added State/Utility slot types, optional labels and supported single direct commands. State highlights update only on a successful local dispatch request, never on blocked execution; Utility and main HUD actions preserve the selected State.
- Persist slot count (including an empty bar), types, labels, commands and sources. Commands/labels are hex encoded in the existing text config, not executed as Lua.
- Added confirmation-based section defaults and StateBar theme rendering. Retained N row switching and the CatsEyeXI T1 approval notice from GitHub development.
- Reject duplicate StateBar hotkeys and navigation collisions in shared layouts; finish captured key releases after disablement. Guard raw navigation input against short buffers.
- Added LuaJIT host-mocked regression tests and release verification checklist.

## Imported candidate history (not independently verified in game)

- 1.49.4-dev: four Settings sections; Lua 5.4 syntax/ZIP checks reported by handover.
- 1.49.3-dev: independent StateBar single-key shortcuts.
- 1.49.2b-dev: persistent StateBar colour without replacing labels.
- 1.49.2a-dev: syntax repair.
- 1.49.2-dev and earlier 1.49 development: character profiles, three mapping layouts, independent StateBar, visibility and appearance work. Position persistence intentionally disabled after Vanacor vector errors.
- 1.48-dev: development keyboard/navigation work including N row switching and active-row numbers. The integrated candidate uses the newer shared-layout implementation rather than the old separate Active Row Keys toggle.
- 1.47: GitHub main source baseline at inspection.

Older release descriptions are retained in RELEASE_NOTES.md below the current candidate entry; they describe historical builds, not current validation.
