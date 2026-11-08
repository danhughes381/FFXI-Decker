# Decker v1.50.16-dev — Immediate (0s) auto-hide

This experimental candidate builds on v1.50.15-dev and is available for in-game testing on the Development channel only once the channel is pinned to this source. Do not merge to Stable until in-game acceptance.

## Behaviour

- Appearance → Display → Auto-hide macro display (Toggle mode) → **Immediately (0s)**.
- With 0s selected, the macro HUD remains available until a successful macro request or StateBar action, then hides on the next UI frame. It also hides when active Toggle navigation ends.
- With no action yet, the HUD stays usable; choosing 0s cannot immediately hide a new HUD at startup.
- Explicit `/decker show` or opening via the modifier wakes it again, allowing another action.
- A running Toggle navigation session and open Settings keep the HUD visible; Hold mode still appears while the modifier is physically held and disappears on release, independent of this setting.
- Existing 2, 5, 10, 15 and 30-second inactivity timings are unchanged.
- Choose **Hide completely** to remove the bar entirely, or **Keep small Decker button** for a recovery control. Keyboard shortcuts remain supported when the HUD is hidden.
- `0s` is saved per-character. Defaults stay as before (auto-hide disabled, 10 seconds if enabled).

## Offline tests

Four additional host-mocked regression groups cover selecting and saving 0s, remaining visible until action, immediate hide after macro/StateBar activity, Toggle navigation exit, explicit Show recovery, Hold independence, and older timed choices.

## Live checklist (Ashita v4 / VanaCore)

1. Connect macros, set Toggle mode and enable Auto-hide. Select Immediately (0s).
2. Confirm the macro bar remains visible before any action. Click a native macro and verify it executes exactly once and the main bar disappears; check the small Decker recovery button if configured.
3. Use `/decker show` and ensure the bar reappears and stays up until another action.
4. Test keyboard macro shortcuts, StateBar, and unlocking Toggle navigation. Confirm hide and no lost/repeated key presses.
5. Switch to Hold mode: while modifier is down the bar stays visible; releasing hides it immediately.
6. Switch to 2s and 5s and confirm timers are unchanged. Switch back to 0s, reload and confirm per-character persistence.
7. Verify Settings, interactive guide, and independent StateBar remain usable even when the HUD hides.

Tests only prove the modelled behaviours, not real game execution. Record live pass/fail before Stable promotion.
