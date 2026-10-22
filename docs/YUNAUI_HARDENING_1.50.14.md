# Decker v1.50.14-dev — YunaUI-informed HUD hardening

**Experimental branch only. Not published to Stable or Development updaters.**
Source baseline: 1.50.13-dev on `development` at `77e0e0701b7fb925c3161e9fdcde7594e09afa71`.
User-visible HUD layout, two ten-slot rows, native execution, book/set routing, config fields, updater protocol and published v1.50.13-dev release remain unchanged.

## What changed
1. **Font sizes** — Existing font families (Arial Bold, Segoe UI Bold, Times New Roman Bold) preload 16/20/28px atlas variants during addon `load` (instead of only 20px). The renderer chooses the smallest loaded font at or above the requested drawn text size, preserving the existing 20px default and scaling when required. Missing fonts/APIs still fall back to host/default.
2. **Lost direct-key releases** — The physical `key_state` recovery path clears `suppressed`/`held` for any captured key that is no longer physically down, including direct macro keys. This extends existing StateBar release recovery and avoids relying only on `key_data` release events.
3. **Locked positions** — When GetIO/DisplaySize is supported, pinned (locked) windows clamp saved coordinates to the current screen bounds. Unlocked windows are not repositioned; saved character configurations are unchanged.

## Verification
- Three new **mock regression groups** were added to `tests/regression.lua` (57 total):
  - font-selection default 20px / requested large 28px
  - direct-key release missed by `key_data`, recovered by `key_state`, followed by exactly one new execution
  - locked window offscreen clamp and no interference with unlocked windows
- **Status: tests have been written but not executed** in this session; Lua 5.4 / LuaJIT host and VanaCore client validation remain outstanding.
- Run `python3 tests/run_lua54.py` from the repository root when available, then `luajit tests/regression.lua .` where supported.
- These tests use mocked native calls and cannot prove actual input interception or font-atlas compatibility in the client.

## In-game acceptance
1. Back up `addons/decker/decker.lua` and character cfg files. Install the **source from this branch only in a test installation**, not via Stable or Development updaters.
2. Check default 18px Arial Bold at 100% HUD scale. Increase font to 23–28px and compare text sharpness/fit on both rows and on StateBar, then revert.
3. Test 1–0, F1–F10, mouse click, arrow navigation, Hold/Toggle and StateBar; confirm each macro executes once, no stuck-key suppression, and native Ctrl/Alt macros remain unaffected.
4. Lock HUD and StateBar near the bottom/right, reduce game resolution, reload/show and confirm controls remain reachable. Confirm unlocked dragging still works and no jitter.
5. Test empty/missing fonts and missing optional drawing APIs. Check all custom and default font paths, especially on VanaCore.
6. Confirm book names, 20-book selectors, settings, per-character isolation, updater status and previous control behaviours have not regressed.

## Research/source attribution
Engineering ideas were independently implemented after reviewing [YunaUI 1.0.29](https://github.com/YunasXI/yunaui/releases/tag/1.0.29), particularly font sizes, safe window positioning and physical key-release state.
No YunaUI GPL code, textures or fonts were copied. Existing Decker license remains unchanged. YunaUI source and assets have their own obligations.

## Release discipline
No ZIP, release, merge, tag, updater manifest changes, CI dispatch or new external installation were made. Treat this as an unverified prototype until the offline tests and target-client acceptance pass.
