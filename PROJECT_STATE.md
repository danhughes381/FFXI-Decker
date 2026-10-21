# Decker — project state

Updated 21 October 2026. Owner selected **v1.50.12-dev as the latest main, Stable and Development baseline**.

Source: `addons/decker/decker.lua`. Exact delivered artifact: `dist/Decker_v1.50.12_dev_Mutant_X_Floating_Glass.zip` and adjacent SHA-256. Install/control guide: `docs/CONTROLS_1.50.12.md`. Latest artifact/source metadata: `dist/release.json`.

Implemented through this baseline: glass/fonts; sizing/position lock fixes; compact labels and hover fixes; hidden title bars; shared/default/custom keys and simpler setup; native-style Hold visibility and Toggle timers; StateBar independent hotkeys/labels/fitting; Settings close/visibility fixes; red locked/held status and stationary header columns; named books and adjacent Macro set/Book controls, matching the target 20-book menu.

Verified offline: 52 host-mocked regression groups under Lua 5.4 with compatibility shims; diff checks; ZIP integrity, exact packaged source and checksum. Owner live evidence: shared number-key control works; book changes 1–3 worked in v1.50.11. Complete 1.50.12 live proof remains pending. LuaJIT/native execution and target host are unavailable here.

This promotion preserves the exact tested source and delivered ZIP, existing main history and coordination files. Older PRs/history remain available. Owner explicitly requested Stable and Development; both manifests now pin identical source. Main, stable, development and the legacy updater development branch are aligned. Version remains 1.50.12-dev; no GitHub Release/tag is created. Readiness issue #3 remains open.

Next action: confirm the named HUD heading and adjacent Macro set/Book controls in game, then work through the remaining live checks in the current guide. Record actual results before claiming stable acceptance.

Source pin: `0f5ebdc03d882b7cdb36451f9f6ba8281fb9efcb`. Source SHA-256: `f94c1e1a82d8a447ebfcc49545b718a65d7587de69e660ec1ba46a543a4f28b9`. Stable uses main/updates/stable.txt; existing Development clients use dev/decker-v1.49.5-integration/updates/development.txt. Both locations are maintained.

Promotion review: [PR #5](https://github.com/danhughes381/FFXI-Decker/pull/5), merged as [797f8f2](https://github.com/danhughes381/FFXI-Decker/commit/797f8f226a83ad8250c151e456188f9791ec6190). Exact source pin: [0f5ebdc](https://github.com/danhughes381/FFXI-Decker/commit/0f5ebdc03d882b7cdb36451f9f6ba8281fb9efcb). Both updater manifests, stable/development branches and legacy Development location use the same version/source. This final metadata follow-up records the completed promotion.
