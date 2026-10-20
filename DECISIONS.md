# Development decisions

## Floating glass, 21 October 2026

Keep the single-file addon and updater protocol 1 intact. Display helpers stay in decker.lua so manual installation and rollback do not acquire a module dependency. Use native ImGui buttons for hit testing; add display-only text and an independent outline. No macro/state routing changes.

Apply alpha to background colours, never global ImGui Alpha: labels must remain readable over the game. Retain legacy opacity data for older builds without applying it to new text.

Load a bounded set of installed Windows fonts at load time rather than mutate the atlas during a frame. Do not redistribute proprietary font files. Reference GPL source informed API research only; copy no code/assets.

No full-build live baseline is evidenced. Keep this candidate on a dedicated branch and manual ZIP pending the live checklist; leave existing updater pins untouched.
