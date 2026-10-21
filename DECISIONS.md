# FFXI-Decker — decision register

Record only decisions with material future impact. Keep earlier project history and existing decisions intact.

| Date | Decision | Rationale / evidence | Revisit when |
|---|---|---|---|
| 2026-10-20 | Use GitHub issues plus short versioned repository memory as the coordination source | Reduces repeated discovery and keeps history reviewable; proposed on an isolated branch | After first two development handovers |

# Development decisions

## Floating glass, 21 October 2026

Keep the single-file addon and updater protocol 1 intact. Display helpers stay in decker.lua so manual installation and rollback do not acquire a module dependency. Use native ImGui buttons for hit testing; add display-only text and an independent outline. No macro/state routing changes.

Apply alpha to background colours, never global ImGui Alpha: labels must remain readable over the game. Retain legacy opacity data for older builds without applying it to new text.

Load a bounded set of installed Windows fonts at load time rather than mutate the atlas during a frame. Do not redistribute proprietary font files. Reference GPL source informed API research only; copy no code/assets.

No full-build live baseline is evidenced. Keep this candidate on a dedicated branch and manual ZIP pending the live checklist; leave existing updater pins untouched.

## Feedback fixes, 21 October 2026

Configured button width must remain authoritative; a cosmetic renderer must read existing display preferences. Apply window size again only when configured dimensions change, preserving manual resizing otherwise. Lock with both NoMove and the last unlocked position because target-host dragging is reported broken; accept vector forms without assuming numeric indexing. Runtime anchors remain isolated per character.

State/Utility describes highlight persistence, while macro source chooses the action and Hotkey chooses the physical trigger. Show the hotkey on the bar and explain all three in Settings. Reserve single physical keys; keep native Ctrl/Alt combinations unchanged. Capture StateBar physical input as well as key-data events, sharing held-state guards to prevent double execution.

## Visibility and independent StateBar controls, 21 October 2026

Chat commands provide recovery without a permanent window. Full hide may leave no main HUD/recovery control visible; Settings must render independently of that visibility. Keep recovery optional as a single small Decker button. Keep StateBar visibility independent.

The StateBar hotkey checkbox is its own explicit permission to reserve assigned keys. It must not silently depend on the main direct-key/consent switch. Retain native connection and enabled-navigation gates; main mappings reserve keys only while main shortcuts are active. F11 input mocks do not establish that host/global shortcut ordering is fixed.

Dan confirms shared number-row routing works in game. Preserve that implementation and explain layout selection, actual configured row-switch/navigation keys and active row. Use the existing fitted-text renderer with a separate StateBar text scale so small boxes fit both labels; show full content and State/Utility semantics on hover.

## Keyboard setup and custom precedence, 21 October 2026

Use one explicit keyboard consent/enable switch directly after native connection, retaining the internal legacy fields for profile compatibility. Connection plus that switch gates main layout and slot editing. StateBar retains its independent permission. Default only new profiles to shared 1-0; never overwrite saved layouts.

Custom assignments need an explicit mode, not silent edits that a shared preset ignores. A slot edit selects custom routing for the saved twenty-slot map; shared presets remain available. Preserve legacy individual edits by identifying edited split profiles as custom on load. Keep the editor accessible from layout choices and clearly display current mode. The title-bar X must write its bool-table state back after End, including collapsed Begin paths.

## Book names and connection defaults, 21 October 2026

User explicitly requested assigned keys on by default after Connect. Keep actual execution off until connection succeeds; saved opt-out remains respected. Use the host chat colour API for only the locked word.

Use the existing native book setter, whose upstream bound is forty books, rather than fake UI-only switching. Book titles have no exposed getter in the inspected native macro library; import explicit character-local saved title files read-only, with bounded structural validation and per-profile cache/aliases. Do not guess memory offsets, scan other character folders or write the game files. First candidate supports printable ASCII titles; unsupported data leaves previous cache intact. The active book/set tracking still requires live verification; title-file import is not live state synchronization.

## Target macro books and named HUD, 21 October 2026

User screenshot establishes a 20-book menu in the target client and confirms native book switching. Match that visible range in selectors and native request bounds, rather than exposing the broader 40-book upstream bound. Equipment presets are a distinct system. Use the same per-profile alias/imported-title source in both HUD and selector. Fixed header columns reserve title space; abbreviated long names retain a full hover label. Add native book controls beside Macro set to make the hierarchy accessible directly in the HUD.

## GitHub baseline promotion, 21 October 2026

The user explicitly selected v1.50.12-dev as the latest GitHub base. Promote its exact source and delivered ZIP to main through an isolated PR while preserving existing coordination files/history. This is a development baseline, with partial user live evidence and 52 mocked groups; it does not constitute full stable acceptance or an updater-channel promotion. Keep prior development branches and issue #3 open.

## Stable and Development promotion, 21 October 2026

Owner explicitly requested both channels. Align branch trees/manifests to the same tested source, preserving its version and delivered ZIP. Maintain the old Development manifest branch for already installed clients. Channel designation records the owner's publication choice; it does not invent full in-game verification.
