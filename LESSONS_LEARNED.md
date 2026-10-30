# FFXI-Decker — verified lessons

Add reproducible observations, exact build/commit, environment and validation. Mark hypotheses explicitly; never promote untested assumptions to established facts.

| Date | Evidence | Lesson | Confidence |
|---|---|---|---|

### 25 October 2026 — layout isolation requires renderer persistence

Code inspection and mocked regressions show that per-character preference files alone do not isolate placement when renderer coordinates remain session-only. The renderer must read and write profile positions explicitly. The previous legacy hudPos serialization was disconnected from the active geometry cache. Actual host behaviour still requires live validation.

- 27 October 2026 (offline reproduced): saving disconnected runtime key flags overwrites a previously enabled assigned-key preference. Regression fails before the preference-serialization fix and passes afterward; cover pre-Connect saves and unload as well as normal connected operation.


- 30 October 2026 (source-only, **not** live): Decker StateBar supports independent keys and single-command whitelist; user-specific F5–F10 controls must remain opt-in because FFXI uses them for targeting. The current StateBar highlight is local and cannot prove equipped gear. A feature edit initially malformed the isolated branch source due to unsafe replacement-string interpolation; it was discarded and reconstructed from clean main source with exact-match checks and one D3D callback. Native Lua parsing, live client and regressions remain pending; do not use this draft as proof of operational safety.
