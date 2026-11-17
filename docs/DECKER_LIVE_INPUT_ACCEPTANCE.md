# Decker input diagnostics and live release acceptance

Status: **v1.50.38-dev candidate**. This is a diagnostic/testability release; it is **not** proof that FFXI combat or modifier-key bugs are resolved on a Windows client. The source uses Ashita v4 LuaJIT; GitHub Lua mock tests cannot prove Windows DirectInput or addon compatibility.

## Read-only capture (opt-in)

In-game commands (never enter these while your chat input is focused):

- `/decker inputtrace on`: clear prior trace and record bounded **in-memory** events.
- `/decker inputtrace status`: report enabled state and buffer count.
- `/decker inputtrace report 40`: print the latest 40 events (1–80 allowed).
- `/decker inputtrace off`: stop recording; existing history remains until cleared/unloaded.
- `/decker inputtrace clear`: erase trace history.

Settings > General > Show advanced diagnostics also has an Input diagnostics toggle.

The trace is **off** by default on every load; not persisted, not transmitted, not written to disk. It contains only input source, rejection/acceptance reason, numeric scan code, press/release/poll state, local monotonic time, booleans for chat/native prompt/modifier and repeat count. It intentionally does **not** capture macro command bodies, user text, player identities or packet payloads. Last 80 observations only; repeated identical observations are coalesced within 0.5 seconds. Copy only the relevant chat lines for a bug report; no automatic uploads.

**Trace interpretation:** `blocked=true` means the Decker handler captured that key. `blocked=false` generally means Decker yielded; this does not establish whether another addon or the game processed it. `invoke` means an attempted command request, not a successful cast or completed gear swap. An empty trace or unfamiliar event ordering is not a positive pass.

## Required live acceptance: Peppa PLD/NIN, Ashita v4 on Storm XI

Before testing: back up current Decker profile, verify installer selected **Development** and the exact version; run with usual Nexus, Aegis, Decker, StormTarget and multibox load order. If a bug recurs, enable trace briefly; stop it after reproducing.

| ID | Scene | Steps | Expected evidence |
| --- | --- | --- | --- |
| IN-01 | Unengaged hostile target | Target mob, use Flash, Reprisal (when available) and Cure IV | Each action request works; no unintended targeting or duplicate requests |
| IN-02 | **Engaged** hostile target | Engage, press Flash, Reprisal, Cure IV and an emergency defensive macro in succession | No unexplained Decker hotkey rejection; no extra key presses required |
| IN-03 | Action-target handoff | Use native friendly target Cure macro, arrows/Enter/Escape, then use another macro | Native target selection works without retriggering Decker or stealing movement |
| IN-04 | Toggle Right Shift | Toggle navigation on/off ten times, including immediately after IN-02 | Each tap changes state exactly once; no latch or missing unlock |
| IN-05 | Hold Right Shift | Hold modifier, use left/right/up/down and End row key, release | Only intended navigation, no stuck key |
| IN-06 | Chat | Open chat during and after modifier hold, type keys and close chat, press modifier again | Chat typing untouched; modifier clears and re-arms after close |
| IN-07 | StateBar | Activate PDT, MDT, accuracy, auto while engaged and unengaged | Command requests execute; **verified green only with Aegis readback**, amber is pending/unverified; mode changes correspond to Aegis |
| IN-08 | Recast display | Trigger Flash and one ability with correctly mapped recast | Circular clock + red text while cooling; **no numerical countdown overlay** |
| IN-09 | Six-client controls | Test Peppa with all normal clients, switch focus and use another controlled client | Key state, chat and hotkeys do not leak between accounts |
| IN-10 | Reload, zone, logout | Reload Decker, zone, re-engage, test a macro and chat | Same results; trace defaults off after reload |
| IN-11 | Stability / rollback | If failure occurs, record trace and restore previously working Stable/source | Profile remains backed up and recovery works; never overwrite Stable untested |

### Multi-addon differential test

If IN-02/03/04/07 fails, repeat the smallest failing sequence once with Decker alone, then with Aegis, Nexus, StormTarget and multibox re-enabled one at a time. Keep identical bound keys and target. Do **not** change native macros or Aegis gear setup merely to make a test pass. Record the addons and precise step that first reproduces the failure.

## Evidence to record in the PR / release

- Windows build; Ashita v4 build; Storm XI server build; character/job/subjob; exact Decker version and source commit.
- Host-specific observations: `IsInputOpen`, `GetIsSubTargetActive` and `GetActionTargetActive` availability and observed transitions (recorded through diagnostic categories where possible). State whether hostile target was only selected, **engaged**, or in native subtarget prompt.
- Table IN-01 to IN-11: PASS / FAIL / NOT TESTED, actual result, key scan code if relevant, and short filtered `inputtrace report`.
- StateBar source: the **real** Aegis saved-mode file/schema and whether readback succeeded; amber pending is not sufficient to declare mode state confirmed.
- Recovery procedure tested and any unresolved conflicts.

**Release gate**: Automated Lua5.4/LuaJIT tests and checksum are necessary but not sufficient. No release may be described as **live verified**, fixed in real combat, or promoted to Stable unless relevant IN-01–IN-11 checks are performed on the running Windows client. A Development build may be published explicitly as a **test candidate** to collect this evidence, with all caveats and rollback available. A PR without the live acceptance report must remain marked as 'Windows validation pending'. No fabricated test results.
