# Floating glass candidate

- [x] Implement and offline-check v1.50.0-dev styling on a dedicated branch.
- [ ] Run docs/FLOATING_GLASS.md live checklist and attach actual screenshots.
- [ ] Run regressions under LuaJIT; current workspace verification used Lua 5.4 with host mocks.

# Development TODO

## Public-release blockers

- [ ] Run v1.49.6-dev in Ashita v4 and Vanacor: Connect, mouse/native macro calls, all layouts, navigation and opt-in keyboard capture.
- [ ] Validate StateBar persistent colours, readable PDT/MDT labels, theme changes and InputText controls in both hosts.
- [ ] Test commands against real game/addon handlers; confirm Utility preserves State and missing actions do not imply equipment success.
- [ ] Salts → Pepper → Salts; logout/login, addon restart and full game reload; inspect separate files and renewed Connect/consent.
- [ ] Check chat/menu interference and held-key release while toggling controls; verify no duplicate execution.
- [ ] Inspect 1440p UI scale, long labels, vertical/horizontal StateBar, scrolling Settings, auto-hide and drag locks.
- [ ] Time a new installation and confirm setup takes 30–60 seconds.
- [ ] Review live evidence, then decide whether a stable release is justified.

## Next development priorities

- [ ] v1.49.7-dev: fix only failures reproduced from the live checklist before further features.
- [ ] Verify native book/set getters before considering dedicated-book execution with reliable restoration.
- [ ] Verify physical modifier handling before exposing StateBar modifier shortcuts.
- [ ] Verify Vanacor ImGui position/vector APIs before restoring explicit position persistence.
- [ ] Reliable chat/menu focus detection; automatically suspend experimental overrides only once trustworthy.
- [ ] Atomic profile writes and actionable disk-write errors.
- [x] Manual in-game check/install/reload and backup rollback implemented in 1.49.6-dev.
- [ ] Validate Windows PowerShell launch, HTTPS/timeout failures, pinned downloads, installation and reload on Ashita/Vanacor.
- [ ] Test rollback across an updater-capable version and a pre-updater version.
- [ ] Publish a stable manifest only after stable acceptance; keep stable updates unavailable until then.

## Completed in 1.49.5-dev

- [x] Compare GitHub main/development and v1.49.4 ZIP; preserve existing branch history and approval notice.
- [x] Four-section Settings with Quick Setup first and confirmed scoped resets.
- [x] Isolate profile preferences and clear native/input runtime state on character changes.
- [x] State versus Utility slots, labels, command validation and persistent highlighting.
- [x] Focused LuaJIT mocked regression coverage; document live limitations.
