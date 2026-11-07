# FFXI-Decker — verified lessons

Add reproducible observations, exact build/commit, environment and validation. Mark hypotheses explicitly; never promote untested assumptions to established facts.

| Date | Evidence | Lesson | Confidence |
|---|---|---|---|

### 25 October 2026 — layout isolation requires renderer persistence

Code inspection and mocked regressions show that per-character preference files alone do not isolate placement when renderer coordinates remain session-only. The renderer must read and write profile positions explicitly. The previous legacy hudPos serialization was disconnected from the active geometry cache. Actual host behaviour still requires live validation.

- 27 October 2026 (offline reproduced): saving disconnected runtime key flags overwrites a previously enabled assigned-key preference. Regression fails before the preference-serialization fix and passes afterward; cover pre-Connect saves and unload as well as normal connected operation.

- 3 November 2026 (offline): current 1.50.18 input queues only physical press edges; an unchanged held arrow cannot advance again. Deterministic mocked polling reproduces the gap. All 72 groups pass after adding delayed repeats and cancellation at both queue-consumption and deferred-set execution boundaries. Live timing and native set transitions remain unverified.

Offline regression reproduced End being rewritten to RSHIFT during cfg load; preserving the configured choice fixes persistence. Right Shift row switching also needs exclusion from unrelated-modifier gating. Current-character title detection and periodic refresh are offline tested only; real registered paths, client saves and private-server character-ID mapping still require in-game verification.

## Cooldown annotations follow the action

A CTRL or ALT position can represent different actions in every book and set. Key annotations to the tracked context, check the native label snapshot, and hide cooldown colour during an observed page transition. A matching label snapshot alone cannot distinguish identical pages.

- An open macro HUD does not itself consume alliance navigation. Armed Decker navigation captures the same arrows and Enter in both event and held-state paths. The native targeting guard must cover both, discard deferred page work and preserve the owner of keys already down until release.
