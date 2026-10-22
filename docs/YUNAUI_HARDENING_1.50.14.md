# Decker v1.50.14-dev — YunaUI-informed HUD hardening

**Experimental branch only. Not published to Stable or Development updaters.**
Source baseline: 1.50.13-dev on `development` at `77e0e0701b7fb925c3161e9fdcde7594e09afa71`.
User-visible HUD layout, two ten-slot rows, native execution, book/set routing, config fields, updater protocol and published v1.50.13-dev release remain unchanged.

## What changed
1. **Font sizes** — Existing font families (Arial Bold, Segoe UI Bold, Times New Roman Bold) preload 16/20/28px atlas variants during addon `load` (instead of only 20px). The renderer chooses the smallest loaded font at or above the requested drawn text size, preserving the existing 20px default and scaling when required. Missing fonts/APIs still fall back to host/default.
2. **Lost direct-key releases** — The physical `key_state` recovery path clears `suppressed`/`held` for any captured key that is no longer physically down, including direct macro keys. This extends existing StateBar release recovery and avoids relying only on `key_data` release events.
3. **Locked positions** — When GetIO/DisplaySize is supported, pinned (locked) windows clamp saved coordinates to the current screen bounds. Unlocked windows are not repositioned; saved character configurations are unchanged.

## Verification
- **22 October 2026: all 57 mocked regression groups PASS on both Lua 5.4 and LuaJIT**, along with source syntax checks. [GitHub Actions run 39739369038](https://github.com/danhughes381/FFXI-Decker/actions/runs/39739369038), commit `f93ffa9ddd36d6ed4074c0a899373991b7d707df`.
- Three new checks cover: default 20px/large 28px font selection, direct-key release recovery after missing a `key_data` release and one subsequent execution, and offscreen locked-window clamp with unaffected unlocked windows.
- The successful workflow created an **experimental test-only ZIP** inside the downloadable `Decker-v1.50.14-dev-TEST-ONLY` Actions artifact. This is not a GitHub Release or an updater channel publication.
- Source SHA-256: `52aafe5c8e0ecb3253bd2ca3c235edeb8c2ad70e4c35a8972e96f4e0ecb5fe7c`.
- Inner ZIP SHA-256: `b2ca18b01dbfbdba1385479e779a16f9a426b58feeed04083e2cca106310da1e`.
- ZIP integrity independently checked after downloading the GitHub Actions artifact.
- Re-run locally: `python3 tests/run_lua54.py` and `luajit tests/regression.lua .`.
- **In-game behaviour remains untested**; mocked native calls and draw functions cannot prove target-client input interception, installed fonts, positioning or Windows-specific compatibility.

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
A temporary **test-only ZIP** was packaged and uploaded by a single branch-scoped GitHub Actions check. No regular release, merge, tag, updater manifest change, main/stable/development promotion or external installation was made. Treat this as an unverified-in-game prototype until target-client acceptance passes.
