# Decker — v1.49.6-dev

Enhanced in-game macro interface for Final Fantasy XI, by **Mutant X**.
Ashita v4 / Vanacor / CatsEyeXI. Apache 2.0; retain LICENSE and NOTICE.

**CatsEyeXI: T1 Sanctioned — approved 19 October 2026.** This records the existing staff approval; this development build has not been verified in game.

## Install and start

1. Back up your existing `addons/decker` folder and character `.cfg` files.
2. Extract the ZIP into your Ashita/Vanacor root. The result must be `addons/decker/decker.lua`, not a nested second decker folder.
3. Load with `/addon load decker` (unload the old version first when updating).
4. Open `/decker settings`. In **Quick Setup**, Connect macros, select a layout and enable the controls you need. Keyboard overrides require acknowledging the warning.

Target setup time: under one minute; not yet measured in game. Mouse execution is available after Connect. Native connection uses client signatures and FFI; incompatible clients can crash. Do not enable keyboard overrides while typing or editing menus: reliable chat/menu focus detection is unavailable.

## Four Settings sections

| Section | Controls |
| --- | --- |
| Quick Setup | Connect, split/shared keyboard layouts, permission and keyboard status; advanced navigation and assignments expand below |
| Appearance | Scale, themes, dimensions, opacity, auto-hide and dragging lock |
| StateBar | Optional independent bar, slot labels, State/Utility type, action source, hotkeys and appearance |
| More | Profiles, Book & Set controls, update information, help and diagnostics |

Each section has **Restore section defaults → Confirm restore**. More resets its Book/Set display and cooldown preferences only. Unrelated sections and other characters are preserved.

## Main macro HUD

- Split layout: F1–F10 top (Ctrl), 1–0 bottom (Alt).
- Shared layout: 1–0 or F1–F10 operates the selected Ctrl/Alt row.
- Mouse execution; selected and pressed highlighting; optional cooldown text.
- Opt-in navigation: default Right Shift, toggle or hold. Left/right select slots; up/down change sets; End or configured key switches row; Enter executes. Escape retains normal game behaviour.
- Custom direct keys and row/navigation controls; Ctrl/Alt remain native game modifiers.
- Auto-hide defaults off. Optional auto-hide collapses to a recoverable tab. `/decker show` reveals the HUD; `/decker keysoff` disables direct overrides.
- Dragging and lock work through ImGui. Explicit position save/restore remains disabled pending Vanacor vector API validation; ImGui's own position retention is host-dependent.

## StateBar

StateBar is part of Decker and has independent visibility and selection. Labels stay readable; the last requested **State** remains highlighted. **Utility** actions do not clear it, and normal HUD macros do not change it. This is a request indicator, never equipment confirmation. Add an optional label such as PDT, MDT or Food per slot.

Action sources:

- **macro**: executes the chosen Ctrl/Alt slot in the **currently active native book/set**. It never silently switches to a dedicated book. Labels without a custom override follow the current macro names.
- **command**: dispatches one allowlisted command through Ashita's command queue. Supported forms: `/equipset 1` (1–100), `/lac set PDT` (one alphanumeric/underscore/hyphen set name), `/item "Food" <me>`, `/ma "Spell" <me>`, `/ja "Ability" <me>`, `/mount "Name"`. Commands require Connect; macros and commands are requests only. Lua evaluation, script execution, chat commands and command chaining are rejected. The named item, spell, mount or integration must exist in your installation.

Single-key hotkeys are optional and require keyboard consent and enablement. Main-macro and navigation collisions are rejected at execution; duplicate StateBar shortcuts from edited profiles are also blocked. Modifier combinations remain unavailable until input handling is validated. Dedicated-book execution remains unavailable because restoring the original native book/set cannot be verified.

## Character profiles

After login, settings use `decker_profile_<server>_<character>.cfg`. Salts and Pepper get separate files. Unknown server IDs use the literal `server` prefix; identical names across unknown servers cannot be distinguished. No profile is written without a detected character. Character changes reset preferences before loading the next file, clear queued input and disconnect native macros. Reconnect and consent after each character change or addon restart. Legacy global `decker_display.cfg` is not overwritten or automatically imported.

## Development status

See [CHANGELOG.md](CHANGELOG.md), [TODO.md](TODO.md), and [docs/VERIFICATION.md](docs/VERIFICATION.md). LuaJIT host-mocked tests are provided in `tests/regression.lua`:

```sh
luajit tests/regression.lua .
```

## In-game updates (development feature)

Install v1.49.6-dev manually once to introduce the updater. Then use **More → Updates → development → Check for updates → Install update and reload Decker**. Only Decker reloads; the game stays open. Reconnect macros and renew keyboard consent after reload.

- Windows PowerShell is launched without a console window. HTTPS downloads run outside the game thread with a timeout, so rendering is not blocked by network requests.
- The channel manifest pins the source to a specific Git commit and SHA-256. Decker checks the downloaded source version and compiles it with the running LuaJIT before replacement; it never executes downloaded installer scripts.
- Only `decker.lua` is replaced. Character `.cfg` files are untouched. The previous source is saved as `decker.lua.bak`; **Roll back previous version → Confirm rollback** restores it and reloads Decker. If you roll back to a version predating the updater, reinstall an updater-capable ZIP manually for subsequent updates.
- Stable channel is reserved for verified releases; no stable updater manifest is published yet. Development channel follows the reviewed candidate manifest on `dev/decker-v1.49.5-integration`, not every unreviewed source commit.
- Windows PowerShell, access to raw.githubusercontent.com and a writable addon folder are required. Download errors leave installed source unchanged. A failed final rename attempts to restore the original source. No admin elevation is requested.
- The Windows process/HTTPS transport and reload still require live Ashita/Vanacor testing. There are no automatic background update checks or unattended installations. Protocol 1 supports single-file Decker builds only; a future multi-file migration needs a new protocol/manual bootstrap.

This build is a development candidate, **not a stable release**.
