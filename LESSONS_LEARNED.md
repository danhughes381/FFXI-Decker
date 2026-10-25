# FFXI-Decker — verified lessons

Add reproducible observations, exact build/commit, environment and validation. Mark hypotheses explicitly; never promote untested assumptions to established facts.

| Date | Evidence | Lesson | Confidence |
|---|---|---|---|

### 25 October 2026 — layout isolation requires renderer persistence

Code inspection and mocked regressions show that per-character preference files alone do not isolate placement when renderer coordinates remain session-only. The renderer must read and write profile positions explicitly. The previous legacy hudPos serialization was disconnected from the active geometry cache. Actual host behaviour still requires live validation.
