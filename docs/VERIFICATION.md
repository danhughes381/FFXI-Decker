# v1.49.6-dev verification

## Baseline and method

GitHub main: 2e1029c (v1.47). Development: e20ec5e (v1.48-dev), branch dev/decker-v1.48-controls-fonts. No open PRs at inspection. Candidate input: Decker_v1.49.4_dev_Mutant_X_usability.zip. Integrated onto development; stable main is unchanged.

Used LuaJIT 2.1 (Lua 5.1-compatible host runtime), not just Lua 5.4 parsing. Tests substitute explicit Ashita, FFI and ImGui mocks: **no Windows client/native pointer validation or in-game evidence**. No existing tests or CI workflow were present in the inspected repo.

Ten regression groups pass: first-install defaults; Salts/Pepper persistence/isolation; zero slots; State/Utility/normal HUD semantics and blocked requests; command allowlist and round trip; scoped resets; split/shared layouts and N persistence; collisions/permissions; repeat/release suppression; all Settings sections with style stack balance. Test harness initially lacked the existing NewLine mock; added it and reran. A syntax error during development was repaired before the passing run.

The upstream Ashita macro API executes the active macro selection and provides setters but no verified current-book/current-set getter in the consulted module. Dedicated-book execution therefore remains unavailable. Direct dispatch follows the documented Ashita command queue API; real command availability/effects remain a live test requirement.

Sources consulted:
- https://github.com/AshitaXI/Ashita-v4beta/blob/main/addons/libs/ffxi/macros.lua
- https://github.com/AshitaXI/Ashita-v4beta/blob/main/addons/autorespond/autorespond.lua
- https://thornyffxi.github.io/LuAshitacast/tutorial.html

## Required live acceptance run

1. Back up configs. Install and check v1.49.5-dev in HUD and Settings. Confirm disabled controls and first-install defaults.
2. Connect; click one known macro. Select each of the three layouts; acknowledge/enable and verify row-to-slot mapping. Exercise custom keys and N/End row switch, hold/toggle navigation, book/set controls, click highlights and auto-hide/reveal.
3. Enable StateBar, label State slots PDT/MDT and a Utility Food. Request PDT; run a normal HUD macro and Food; PDT stays highlighted and readable. Request MDT; highlight moves. Disable macro readiness; a blocked request must not change selection.
4. Test every command form you intend to use, first with harmless known actions. Queue acceptance does not prove the game accepted the action or equipment changed.
5. Test hotkey repeats and releases, change permissions while holding a key, main-key/navigation collisions, native Ctrl/Alt, chat and menus. Overrides may interfere with typing; opt-in warning remains necessary.
6. Change appearance, slots and shortcuts on Salts; switch to Pepper. Confirm independent defaults/configuration, disconnected native macros and fresh consent. Change Pepper, return to Salts and repeat after addon/game restart.
7. Inspect every Settings section at your actual UI scale, scroll advanced controls and long labels. Restore one section, cancel another reset; confirm unrelated values survive reload.
8. Record host version, character, screenshots and result for each step. No stable release until blockers in TODO are resolved.

## Updater verification

Additional LuaJIT tests exercise manifests, numeric/prerelease ordering, source promotion with exact backup, rollback/reload request, invalid-source rejection, pending/timeout/error process states, and unsupported hosts. Windows PowerShell and Windows process creation are unavailable in this Linux environment; the worker script, HTTPS and CreateProcessW ABI remain live-validation requirements. The updater is not claimed in-game verified.

First live test: install the bootstrap ZIP, choose development and Check (expect no newer version when current). Publish a newer test candidate before testing Install. Check stored source/backup versions and unchanged configs. Repeat with a disconnected network, folder write failure and rollback. Verify no game freeze during check/download and that only Decker reloads. The stable channel should currently report a fetch failure because no stable manifest is published.

Win32 process APIs: https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw
Addon reload: https://docs.ashitaxi.com/usage/commands/
