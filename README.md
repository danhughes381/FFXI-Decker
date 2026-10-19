# Decker — v1.49.5-dev

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

No automatic updater/rollback is implemented. Download releases from this repository and retain your previous ZIP. This build is a development candidate, **not a stable release**.
