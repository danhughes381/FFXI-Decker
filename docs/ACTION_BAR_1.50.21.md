# Decker 1.50.21-dev — action-bar polish

Manual test candidate on PR #17 (`af49637`). Preserves held-arrow navigation, expanded keys, saved book titles and the three weapon-aware WS slots. No key assignments, macro lines, weapon rules or Aegis code are rewritten.

## Install

Back up the installed `addons/decker/decker.lua` and your Decker cfg files. Copy this ZIP's `addons/decker/decker.lua` into your Ashita folder, preserving cfg files. In game run `/addon reload decker`, then Connect to in-game macros.

## Try the features separately

1. **Appearance → Action button look → facet**: original slanted buttons and fine accent edges. Classic remains the default. If the host lacks the polygon drawing API, normal rectangular buttons remain. The clickable area stays the original button rectangle.
2. **Appearance → Emphasise active row**: the navigation row is brighter; the other is dimmer. This starts enabled and can be disabled. It follows Decker's selected row, not an independent native Ctrl/Alt-state detector. Both rows and 1–0 labels remain.
3. **Controls → Colour macro text when ability/spell is recasting** enables feedback. Under **More → General → Book and Set controls**, enable **Detect recasts from macro commands**. Existing manual cooldown bindings take priority. Supported quoted English spell and ability commands are resolved against client resources; up to three unique recasts per macro are checked. The text turns amber and hovering shows the longest remaining recast. The Facet theme adds a short green edge after an observed recast reaches zero; reduced motion removes that effect.
4. Separately, enable **Read native book and set (experimental)** in the same General section. This is off by default. It reads only after connection, matching object pointers, zoning/character checks, recognised setPage prologue/operand and two stable in-range field reads. The supported range stays 20 books and ten sets; no 40-book expansion is inferred. If validation fails, the last known/manual position remains, and a prior native-read status becomes unverified. Read the status text there.

Macro-line reads are staggered: at most one button's six lines per 30 ms sample, subject to frame rate. Initial population or an edited line can take about 0.6 seconds at sufficient frame rate, longer at low FPS. Book/set checks run at most twice per second. No scanning is repeated by these helpers. Cached recasts are advisory; they do not decide action execution.

Auto-translate, unquoted names, aliases, scripts and conditional commands are not inferred. WS readiness, TP, range, MP, unlocks and actual execution are not established by a cooldown indicator. Dynamic WS markers keep their own resolved labels and normal single-command route; existing gear handling remains responsible for swaps. Book/set numbers and saved book titles use separate readers.

## What this candidate does not include

No macro editor, skillchain/burst highlighting, VanaCore-native HUD hiding, custom macro playback, YunaUI files or art, channel promotion or release. Original implementation inspired by YunaUI's feature ideas; attribution is in README. Native macro execution and existing permissions are retained.

## Evidence and next checks

89 Lua 5.4 mocked regression groups pass, including all prior 82 groups, command parsing, timer deduplication/manual precedence, missing resources, invalid native fields/signatures, bounded read-only sampling, polygon geometry/fallback and profile persistence. ZIP integrity/source equality and diff checks pass. LuaJIT and live Windows/Ashita/VanaCore execution remain unverified.

Test each toggle independently, then together. Verify sword/dagger/staff WS labels, set/book changes including identical macro names, name refresh and book aliases, long labels at your resolution, actual recast durations, reload and two characters. Check FPS/frame-time before and after enabling helpers and Facet. No measured performance improvement is claimed. Native FFI/memory accesses require live client compatibility; Lua error handling cannot protect against every native crash. Disable the experimental reader or restore the backup if the client behaves incorrectly.
