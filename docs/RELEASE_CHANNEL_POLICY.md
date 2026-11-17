# Decker release channels — single-source governance

## Owner decision (17 November 2026)

Two user-facing channels exist, with exactly **one canonical Development line**:

- **Stable**: v1.50.34, based on the Work-authored chat-input build. Official source branch: `main`. The `stable` branch mirrors this code. No Combat Analytics or newer recast clocks in this Stable version.
- **Development**: v1.50.37-dev, consolidated chat input/target handoff, PLD tank-mode highlight fix, exact-name recast display hints and Combat Analytics. Official source branch: `development`. Do not treat old `dev/decker-v1.49.5-integration`, `fix/*`, `feature/*`, or Work branches as alternative release channels.

The in-game updater reads `updates/development.txt` or `updates/stable.txt`, depending on its selected channel. The manifest pins an **immutable source commit** plus SHA-256 and version; branch names themselves are not authoritative. Mirrors of these two manifests in `main`, `development`, `stable` and the legacy integration branch are strictly compatibility copies of the same pair, never separate channels.

## Required release process

1. Develop through a short-lived feature/Work branch and PR into `development`. Review *all* earlier Work branches and current Dev code for changes; never bump version on an old branch and promote it without a diff and merge.
2. Run Lua 5.4 and LuaJIT mocked-host regression suites, including chat input, held key transitions, friendly subtarget, Decker navigation, cooldown and analytics.
3. Verify the exact immutable source SHA-256 and source `addon.version`. For Development, versions must exceed both currently published Development and any higher-version locally installed Work build if the in-game updater is to offer an upgrade.
4. Only after CI passes, publish exactly one `updates/development.txt` manifest and mirror it identically to the established updater paths. Do not modify Stable during a Development-only release.
5. For a Stable promotion, independently validate the exact Stable source. Do not equate Stable with the newest development features; document intentional differences. Update all Stable manifest mirrors.
6. Confirm in-game update on Windows, backup/reload and rollback before calling the release *live verified*. Mocked-host CI does not substitute for live FFXI checks.
7. Keep the README channel versions current. Record any separate Work branch or local uncommitted install as **not yet released**, even if its version label is higher.

## Current pinned releases

- Development v1.50.37-dev: `a2dfc491a34cde37d5d6079698cedca34a5621bd`, SHA-256 `68417337a3b02af088d8711a4e9959aedf571883a23b9cb756b76e7cc7101162`. 110 mocked regression groups pass under Lua 5.4 and LuaJIT.
- Stable v1.50.34: `8f08412f391cebd00f7663f1eabd4e82b8c7514e`, SHA-256 `b4ee5d37a1fee84879a41e64b3f323955b1213cbf636952c4e34e480ac4d71e3`. 93 mocked regression groups pass under Lua 5.4 and LuaJIT.

Neither build has been directly installed or live tested on the user's Windows machine by this process.

## Mandatory Windows input acceptance (effective after v1.50.37)

See [Decker live input acceptance](DECKER_LIVE_INPUT_ACCEPTANCE.md). GitHub mocked suites cannot validate actual engaged-combat DirectInput, native subtarget, Windows keyboard focus, Aegis mode-file compatibility or the six-client addon set. Releases modifying input/hotkeys/StateBar must attach an IN-01 to IN-11 live report before they can be called "live verified" or promoted to Stable.

Source and tests must be merged together. Never update the canonical development source while leaving tests/regression.lua on a legacy branch. Diagnostics must remain off by default, bounded, private and removable without affecting game behaviour.

A Development test candidate may be published for Windows acceptance, provided it is explicitly labelled "not live verified" until supported by real game evidence. CI green alone is insufficient.
