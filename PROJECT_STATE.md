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
