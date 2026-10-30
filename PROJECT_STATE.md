# Decker — project state

Updated 21 October 2026. Owner selected **v1.50.12-dev as the latest main, Stable and Development baseline**.

Source: `addons/decker/decker.lua`. Exact delivered artifact: `dist/Decker_v1.50.12_dev_Mutant_X_Floating_Glass.zip` and adjacent SHA-256. Install/control guide: `docs/CONTROLS_1.50.12.md`. Latest artifact/source metadata: `dist/release.json`.

Implemented through this baseline: glass/fonts; sizing/position lock fixes; compact labels and hover fixes; hidden title bars; shared/default/custom keys and simpler setup; native-style Hold visibility and Toggle timers; StateBar independent hotkeys/labels/fitting; Settings close/visibility fixes; red locked/held status and stationary header columns; named books and adjacent Macro set/Book controls, matching the target 20-book menu.

Verified offline: 52 host-mocked regression groups under Lua 5.4 with compatibility shims; diff checks; ZIP integrity, exact packaged source and checksum. Owner live evidence: shared number-key control works; book changes 1–3 worked in v1.50.11. Complete 1.50.12 live proof remains pending. LuaJIT/native execution and target host are unavailable here.

This promotion preserves the exact tested source and delivered ZIP, existing main history and coordination files. Older PRs/history remain available. Owner explicitly requested Stable and Development; both manifests now pin identical source. Main, stable, development and the legacy updater development branch are aligned. Version remains 1.50.12-dev; no GitHub Release/tag is created. Readiness issue #3 remains open.

Next action: confirm the named HUD heading and adjacent Macro set/Book controls in game, then work through the remaining live checks in the current guide. Record actual results before claiming stable acceptance.

Source pin: `0f5ebdc03d882b7cdb36451f9f6ba8281fb9efcb`. Source SHA-256: `f94c1e1a82d8a447ebfcc49545b718a65d7587de69e660ec1ba46a543a4f28b9`. Stable uses main/updates/stable.txt; existing Development clients use dev/decker-v1.49.5-integration/updates/development.txt. Both locations are maintained.

Promotion review: [PR #5](https://github.com/danhughes381/FFXI-Decker/pull/5), merged as [797f8f2](https://github.com/danhughes381/FFXI-Decker/commit/797f8f226a83ad8250c151e456188f9791ec6190). Exact source pin: [0f5ebdc](https://github.com/danhughes381/FFXI-Decker/commit/0f5ebdc03d882b7cdb36451f9f6ba8281fb9efcb). Both updater manifests, stable/development branches and legacy Development location use the same version/source. This final metadata follow-up records the completed promotion.

## Updater verification — 1.50.13-dev

[PR #6](https://github.com/danhughes381/FFXI-Decker/pull/6) updates the addon status/version, regression tests/results, packaging script, guide, README/changelog, both manifests and release metadata. Source pin: [e095b84](https://github.com/danhughes381/FFXI-Decker/commit/e095b847876ee89badfda00027ccda6e4c474bdb); SHA-256: e4866175eab0a909d44321c80f932716686ca15e68a858e9f0f7d33c112d6543. Latest current build is 1.50.13-dev for both owner-selected channels, superseding the historical .12 baseline above.

54 mocked-host regression groups pass. Both channels cover check, offer, installation, exact backup and reload; equal versions do not offer installation. Actual HTTPS channel manifests and pinned-source downloads pass hash checks. ZIP integrity and packaged-source equality pass. Windows PowerShell transport and live Ashita install/reload remain unverified here. Issue #3 stays open.

Next action: on a 1.50.12-dev installation, select either channel, Check for updates, install 1.50.13-dev and reconnect macros. Confirm the in-game reload and subsequent Up to date result; record evidence before claiming complete live validation.

## Published GitHub release — 21 October 2026

[v1.50.13-dev](https://github.com/danhughes381/FFXI-Decker/releases/tag/v1.50.13-dev) is now the latest public GitHub release, titled **Decker v1.50.13-dev**, published as a regular release at the owner's explicit request. Tag/source commit: `e095b847876ee89badfda00027ccda6e4c474bdb`. Previous v1.47 release is preserved. GitHub displays the Latest badge. The -dev tag/version, existing verification limits and updater source pins are retained.

Attached unchanged installation ZIP: `Decker_v1.50.13_dev_Mutant_X_Floating_Glass.zip` (114760 bytes). Downloaded release asset SHA-256 matches `cffc03ed2ecf8269465045dc156424bf56ade663af4c5094c50c9bc64cba848a`. Archive integrity and exact packaged-source equality passed. All 54 mocked-host offline regression groups passed again. Live HTTPS Stable, Development and legacy Development manifests and immutable source hash passed verification. Both channels remain 1.50.13-dev; publishing does not change the updater protocol or source pins.

Owner confirms in-game testing using VanaCore/Ashita. This supersedes earlier statements that no latest-build live testing had been reported; it does not independently establish every feature or the complete Windows updater install/reload flow. Issue #3 remains open for detailed acceptance evidence.

Publication changes only release metadata and documentation (PROJECT_STATE.md, RELEASE_NOTES.md, README.md). Addon code, packaged ZIP, updater manifests and character settings are unchanged. No Actions workflow was dispatched or modified; the existing import workflow does not trigger on release publication or documentation changes. Next action: record specific live updater and feature results in issue #3 before final production acceptance.

## Development updater test candidate — 22 October 2026

The owner expected today's experimental v1.50.14-dev and v1.50.15-dev changes to be available via **Development** for in-game evaluation. Updated `updates/development.txt` in `main`, `development`, and the updater's actual legacy read path `dev/decker-v1.49.5-integration` to **v1.50.15-dev**. The immutable source pin is `511240f99e3a4ae24d77cdf6b1d61ac898279290` with independently recalculated source SHA-256 `6789da96690d1a685d1e7fa10fd054988c075bf385c79a41a77c8ec1c4162b28`.

v1.50.15 includes v1.50.14 font/preload, key-release and viewport hardening, plus optional HUD micro-motion and simulated interactive guide. GitHub Actions reported **61/61** mocked test groups passing in Lua 5.4 and LuaJIT. No in-game acceptance or live Windows updater install was verified by this promotion; the channel is **experimental for testing only**. Stable, the v1.50.13 GitHub Release, addon source in `main`, and draft PRs #9/#10 remain unchanged. No merge, tag or new release. Live follow-up: on existing v1.50.13, select Development → Check for updates → Install and reload; check `/decker guide`, both macro rows, keyboard/StateBar suppression while the guide is open, recovery afterward, reduced motion, and position/font behaviour. Record evidence in PR #10 / issue #3.

## Development v1.50.16-dev immediate auto-hide test — 22 October 2026

Owner requested "hide after activity — immediately (0s)" in the macro HUD Appearance settings. Created `dev/decker-v1.50.16-immediate-hide` on top of v1.50.15 and draft [PR #11](https://github.com/danhughes381/FFXI-Decker/pull/11) targeting its experimental base. Implemented **Immediately (0s)** as event-driven hide on the next UI frame after a successfully requested macro/StateBar action or end of Toggle navigation; avoids instant disappearance on startup. Hold remains physical-key-driven and 2–30-second timings remain unchanged. Per-character saved 0s preference supported. [Live checklist](https://github.com/danhughes381/FFXI-Decker/blob/dev/decker-v1.50.16-immediate-hide/docs/IMMEDIATE_HIDE_1.50.16.md).

GitHub Actions [run 39755640087](https://github.com/danhughes381/FFXI-Decker/actions/runs/39755640087) passed **65/65 mocked regression groups in Lua 5.4 and LuaJIT**, syntax and ZIP integrity. Pinned immutable candidate commit `67001453ed8869df076d6831305bcb3ef81cca48`; GitHub Actions source SHA-256 `94dde51ffc250dd3d4aea39d08aca67a134b3bdd69f0ca58561bf05759f6fc7e`. Updated all three served Development manifest locations (`dev/decker-v1.49.5-integration`, `development`, `main`) to v1.50.16-dev. **Stable remains v1.50.13-dev**, source on `main` and public release unchanged. No new public release, tag or merged UI PR. Real VanaCore/Ashita updater and macro execution remain unverified; test in game before Stable promotion.


## Development v1.50.17 character-layout fix — 25 October 2026

[PR #12](https://github.com/danhughes381/FFXI-Decker/pull/12) fixes session-only window positions on top of v1.50.16. Per-character HUD, StateBar and collapsed coordinates now save and restore explicitly, including unlocked restoration, viewport clamping and debounced drag saves with unload/profile-change flush. Existing per-character scale/size preferences remain separate. Source: `f178392675fb062875b2f9cac15de69eb789c253`; source SHA-256: `b9bb26bf42cfdf41052a6a27631cb876bedf87c4b4a3d35102a8f1a65c2c878a`.

GitHub [branch validation](https://github.com/danhughes381/FFXI-Decker/actions/runs/40206964685) and [PR validation](https://github.com/danhughes381/FFXI-Decker/actions/runs/40206967550) both succeeded: syntax, 67 mocked regression groups under Lua 5.4 and LuaJIT, test ZIP integrity and artifact upload. Code/tests match the locally reviewed source. All three served Development manifests (main, development, legacy dev/decker-v1.49.5-integration) now offer this immutable source. Stable and the public GitHub Release remain v1.50.13-dev. No source merge or public release was performed.

Next: select Development, Check for updates, install v1.50.17-dev; give the two characters distinct HUD/StateBar placement and sizing, switch back and forth, reload the addon and restart the game. Live VanaCore vector APIs and different-resolution behaviour remain unverified. Guide: [character layout test](https://github.com/danhughes381/FFXI-Decker/blob/fix/character-layout/docs/CHARACTER_LAYOUT_1.50.17.md). Readiness issue #3 stays open.

## Stable and Development 1.50.18-dev — 27 October 2026

Owner explicitly requested publication of the assigned-key persistence fix to both channels. Source pin `30e91f63e42d71683f520d408c7cf5403adabe7b`; SHA-256 `b8ae058040e25475b393da5e240dac3c4676d8700c1f5b09292c4e80eb2c5dc9`. Carries current Development features through 1.50.17, including per-character position persistence, plus PR #13. Persist savedKeybinds/savedAck instead of temporary disconnected runtime flags. Existing overwritten preferences require ticking Use my assigned keys once after installation.

PR #13 validation run 40515934316 passed Lua 5.4/LuaJIT regression, syntax and ZIP integrity. After version-only change, all 68 Lua 5.4 mocked groups and diff checks pass locally. Real Windows/VanaCore updater reload and live persistence remain unverified. Stable and Development manifests and both named channel branches are aligned; legacy Development URL remains served. No new public GitHub Release or tag. Next: update in game, Connect, enable assigned keys, reload, make an appearance edit before Connect, reconnect and verify the checkbox; test both characters. Readiness issue #3 remains open.


## 30 October 2026 — draft Aegis F5–F10 StateBar bridge

Branch: `feature/decker-optin-aegis-gear-keys-20261030`, based on current `main` Decker 1.50.18-dev source (the existing README baseline is partly historical). Issue #14. Adds a confirmed, opt-in Aegis StateBar preset: F5 PDT, F6 MDT, F7 Accuracy, F8 Idle, F9 Auto, F10 unassigned. Current user profiles are not touched by this branch or by startup; preset confirmation overwrites only the current character's selected StateBar slots. The preset uses `utility` highlight type because Decker cannot acknowledge real gear states. Hotkey interception is **OFF** after applying the preset; existing FFXI F-key targeting remains until deliberate activation. Only exact `/aegis gear <action>` requests are newly allowlisted. Aegis gear model exists on an isolated Aegis branch and has standalone Texlua test evidence, but **cross-addon operation, existing Decker regression suite and live VanaCore key focus/target conflicts are not tested**. No stable/development updater manifest, tag or release changed. Required: source syntax check, mocked regression, manual profile backup/restore, installed Aegis command delivery, FFXI targeting conflict testing, and acknowledged LAC gear-state transport before treating these as real locks.
