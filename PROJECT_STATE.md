# Decker — project state

Updated 21 October 2026. Branch: `dev/decker-v1.50-floating-glass`.

Latest baseline: v1.49.6-dev, `3e50a94`, draft integration PR #1. No recorded live proof of that complete candidate; main remains separate. Existing live-readiness issue: #3.

Changed: v1.50.0-dev display helpers, four independent background alphas, installed font cache/choices, fitted labels and bottom-right shortcuts, execution fill plus selection outline, glass StateBar backgrounds. Input/native execution/state handlers preserved. See docs/FLOATING_GLASS.md.

Verified: 22 mocked regression groups under Lua 5.4 with documented 5.1 compatibility shims, plus archive/source/checksum checks. Simulation is explicitly not a game screenshot. LuaJIT, Ashita and Vanacor unavailable here.

Files: addons/decker/decker.lua, tests/regression.lua, tests/run_lua54.py, tools/package_glass.py, docs/FLOATING_GLASS*, README.md, CHANGELOG.md, TODO.md, DECISIONS.md, this state file, dist/v1.50 development ZIP/checksum.

Next action: install v1.50.0-dev ZIP manually and run the live checklist: draw/font ABI, both rows, execution/selection overlap, independent StateBar, dragging, auto-hide and per-character restart. Keep draft; no main merge, stable release or updater-channel promotion.

Review: draft [PR #4](https://github.com/danhughes381/FFXI-Decker/pull/4). Implemented code/package commit: [`a1d4bc2`](https://github.com/danhughes381/FFXI-Decker/commit/a1d4bc2ebb24dfb8cb9c12ca7fc9c33aab0e6eec). Test evidence: docs/FLOATING_GLASS.md and tests/regression.lua.
