# Version history

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
