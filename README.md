# Decker — by Mutant X

**Stable: v1.50.13-dev · Development updater: v1.50.17-dev (experimental, awaiting live testing)** · Ashita v4 / Vanacor / CatsEyeXI

Enhanced in-game macro interface for Final Fantasy XI. Shows both native macro rows together, with floating glass, fitted labels, shared or custom keys, Hold/Toggle navigation and an independent StateBar.

[Download the latest release ZIP](https://github.com/danhughes381/FFXI-Decker/releases/download/v1.50.13-dev/Decker_v1.50.13_dev_Mutant_X_Floating_Glass.zip) · [Setup and controls](docs/CONTROLS_1.50.13.md) · [Project state](PROJECT_STATE.md) · [Changelog](CHANGELOG.md)

## Install

1. Extract the ZIP and copy `addons/decker/decker.lua` into your existing Ashita `addons/decker` folder. Keep your character `.cfg` files.
2. Load/reload Decker and select **Connect to in-game macros**. Assigned keys default on after successful connection; an existing saved opt-out is preserved.
3. New profiles use **Both rows: 1–0**. Under **Advanced keys**, enable the mod/arrow hotkeys. Choose **Hold key pressed down** or **Press key once (Toggle)**. Right Shift and End are the default mod and row-switch keys.
4. Use **Macro set** and the adjacent **Book** controls to select sets 1–10 and books 1–20. Book names use your Decker label or imported saved game title.

Hold shows macros while the mod is physically held and hides them on release. Toggle retains Appearance auto-hide settings. `/decker settings`, `/decker show` and `/decker help` provide recovery. Full details, StateBar setup and known limits are in the [current guide](docs/CONTROLS_1.50.13.md).

Development v1.50.16-dev adds an optional **Immediately (0s)** post-action auto-hide setting for Toggle mode on top of the v1.50.14/15 font, keyboard, animated HUD and interactive guide experiments. **65/65 mocked regression groups pass under Lua 5.4 and LuaJIT**; live Windows/VanaCore testing is still required. [0s testing instructions](https://github.com/danhughes381/FFXI-Decker/blob/dev/decker-v1.50.16-immediate-hide/docs/IMMEDIATE_HIDE_1.50.16.md). Stable and the latest public GitHub Release remain v1.50.13-dev. No Stable merge or public release has been created.

## Baseline status

This main-branch baseline was selected by the owner on 21 October 2026 and includes the feedback passes through 1.50.13-dev. **54 host-mocked regression groups pass** under Lua 5.4 with the existing compatibility shims. Archive integrity, exact source and SHA-256 are checked. The owner confirmed shared number-key control and native book changes in earlier candidates. The owner confirms in-game testing of this build using VanaCore/Ashita; individual features and the complete Windows updater install/reload flow have not all been independently verified. LuaJIT and native execution are unavailable in this workspace. See [release-readiness issue #3](https://github.com/danhughes381/FFXI-Decker/issues/3).

The owner selected this baseline for Stable and Development on 21 October 2026. Both updater manifests pin identical source and SHA-256; the version remains 1.50.13-dev. Channel promotion does not add live verification. The updater now shows installed and published versions explicitly. Stable and Development offer the same current build.

**CatsEyeXI: T1 Sanctioned — approved 19 October 2026.** This records the existing addon approval; it does not claim every subsequent development build was separately reviewed.

Decker uses existing FFXI macros and does not rewrite game macro data. Equipment sets are separate gear presets, not additional macro books. Saved title-file import is read-only and currently supports the documented ASCII format.

## Attribution

Created by **Mutant X**. Licensed under [Apache 2.0](LICENSE); retain [NOTICE](NOTICE). If sharing a modified version, acknowledge the original project and identify your changes.

Published 21 October 2026: [v1.50.13-dev GitHub release](https://github.com/danhughes381/FFXI-Decker/releases/tag/v1.50.13-dev), the latest public release, titled **Decker v1.50.13-dev**, published as a regular release at the owner's request. The existing ZIP is unchanged; preserve character .cfg files when installing. Previous releases remain available.

Development v1.50.17-dev adds explicit per-character HUD, StateBar and collapsed-button position saving/restoration. [PR #12](https://github.com/danhughes381/FFXI-Decker/pull/12): both GitHub validation runs passed Lua 5.4/LuaJIT regression and test ZIP checks (67 groups each). All served Development updater locations offer v1.50.17-dev; live character-switch/restart and different-resolution acceptance remain pending. Earlier Development notes above describe superseded candidates.

Both in-game channels now offer 1.50.18-dev, including character-position and assigned-key preference fixes. The linked public release ZIP above remains historical 1.50.13-dev. After updating, Connect and enable Use my assigned keys once if its old preference was already overwritten. Offline validation passes; live client verification remains pending.

## Optional Aegis layered-gear StateBar preset (draft)

The isolated development PR adds a **manually prepared** F5–F10 baseline in StateBar settings: F5 PDT, F6 MDT, F7 Accuracy, F8 Idle, F9 Auto, F10 unassigned. It asks for confirmation before replacing an existing character's StateBar slots and leaves shortcut interception **disabled** until separately enabled. Aegis `/aegis gear ...` commands modify policy intentions only: there is no equipment execution or acknowledgment and no persistent active highlight for these buttons. FFXI normally uses these F-keys for targeting; do not enable interception without accepting the conflict. This candidate is neither a published updater release nor validated in game. See issue #14 and [Aegis issue #43](https://github.com/danhughes381/Aegis/issues/43).
