# Decker 1.50.15-dev — UI Experience Lab

**Status (22 October 2026):** Experimental source on isolated branch; not live-validated in VanaCore. This is a stacked extension of the still-draft 1.50.14-dev hardening branch. At the owner's request, the **Development updater only** now offers v1.50.15-dev for in-game evaluation, pinned to immutable source commit `511240f99e3a4ae24d77cdf6b1d61ac898279290` (SHA-256 `6789da96690d1a685d1e7fa10fd054988c075bf385c79a41a77c8ec1c4162b28`). Stable remains v1.50.13-dev. Draft PRs remain unmerged; do not promote to Stable or a public release without acceptance.

## Purpose

Use Decker as a small learning laboratory for an original, reusable **experience layer** before considering UI improvements in Aegis or Nexus. Preserve Decker's exact native two-row macro layout, FFXI macro books, keyboard mappings, character-specific preferences, StateBar and execution gates.

## Changes
1. **Draw-only, opt-out micro-motion**: soft breathing outline on the already selected macro and a 300 ms confirmation strip after execution was *requested* through the existing guarded executor. No claim of game-side completion. No new texture loading, Windows dependencies, key hooks or background loops. A new per-character **Subtle animations** checkbox (Appearance) supports reduced motion and persists across reloads.
2. **Independent four-step interactive guide**: open with `/decker guide` or Settings → **Interactive guide**. It presents safe simulated CTRL/ALT sample buttons (“Flash,” “Provoke,” “Cure III,” “Protect”), then selection vs execution, Hold vs Toggle, and book/set/StateBar concepts. The guide stores only temporary presentation state; touching the sample buttons cannot invoke a macro, StateBar command or native page change. Real macro execution and navigation are guarded while it is open. It works with the native macro connection unavailable and with the HUD hidden.
3. **Separation of concerns**: preview state is not saved and cannot access the native macro executor. Drawing only reads existing selection, flash timestamp, font and theme data. The simulation intentionally does not impersonate in-game state.

## Test checklist

### Offline
- Run `python3 tests/run_lua54.py` and `luajit tests/regression.lua .` from repo root.
- Test groups include prior 57 and four new groups: profile-isolated reduced-motion persistence; guide blocking native macro, StateBar and page operations; command-driven guide / simulated click; animated glow/flash opt-out and balanced drawing stacks.

### In-game — REQUIRED before promotion
- Confirm the real macro HUD still displays **both full sets of ten native macro slots** with unchanged proportions and mouse/keyboard controls.
- In Appearance, switch **Subtle animations** off and on; verify ordinary selected/pressed feedback remains legible with motion off and no flicker with motion on.
- Run `/decker guide` with macros connected and disconnected, and with HUD shown/hidden. Tap Flash/Cure sample buttons and confirm **no macro execution, set changes, gear commands or unwanted keyboard effects**.
- Try Hold/Toggle demo; verify real mod preference and book/set remain unchanged. Check Back, Next, Finish, Close and window X.
- While the guide is open, test keys that would usually trigger Decker and StateBar. Confirm no game action triggered by Decker. When closed, confirm normal execution resumes exactly once and no keys stay captured.
- Evaluate CPU/frame budget against v1.50.13-dev on the same hardware in a busy zone. No measured performance claims until observed.
- Verify per-character reduced-motion save/load and Restore Appearance defaults. Validate text and font on actual Windows/VanaCore ImGui.
- Check no regressions from **1.50.14-dev**: font tiers, recovered key release, locked viewport positioning. That version is not yet confirmed live.

## Source/licensing decision
YunaUI is research inspiration only. No GPL YunaUI implementation, animation frames, fonts or textures were copied into Apache-2.0 Decker. The preview uses original Lua and host ImGui primitives. This is **not** a shared framework yet; extract reusable patterns only after in-game acceptance.

## Outcome
Document exact pass/fail, user screenshots and any VanaCore discrepancies in the branch PR. Only consider merge/release after live acceptance of both 1.50.14 and 1.50.15.
