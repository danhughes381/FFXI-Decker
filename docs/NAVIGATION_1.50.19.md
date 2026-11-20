# Decker 1.50.19-dev — manual test candidate

Copy `addons/decker/decker.lua` over your existing addon file after backing it up; retain all character cfg files. Reload Decker and Connect to in-game macros. Updater channels still offer 1.50.18-dev, so do not install that older channel over this manual candidate.

Under Controls → Advanced keys, choose Macro visibility mod key and Switch row key. Both offer 28 choices. To exchange the defaults, select END as the mod: the existing END row key moves to RSHIFT. Choosing the other control's key swaps them. Re-enable navigation hotkeys after changing the mod. Both Hold and Toggle are supported.

Hold Left/Right to move between slots; hold Up/Down to request successive sets. Repeat starts after 350 ms at an 80 ms cadence, subject to native set-request completion and frame rate. Release stops repeated requests. Enter, Space and the row-switch key do not repeat.

Book titles are read from saved `mcr.ttl` (20 books, ten sets each). If the host exposes the supported filesystem and party APIs, Decker tries exact current-character hexadecimal USER folders under registered FFXI installs. It chooses only one unambiguous valid file. General → Book and Set controls → Import saved in-game book names retains the explicit character folder and refresh button. Titles refresh every five seconds after saving changes in game. Existing Decker labels take precedence; clear one to use the imported title. Missing/unsupported files leave existing titles intact. No inference from job or macros is used.

Lock/held status has a red badge, unlocked has a green badge; text size and neighbouring header positions stay fixed.

## Required live checks

- Tap, hold and release every arrow in Hold and Toggle; check wrap and immediate repeat cancellation, including modifier release and guide opening.
- Confirm Up/Down reaches the expected native set at normal and low frame rates.
- Select END mod/RSHIFT row key; switch rows, reload and verify both choices persist. Test chat/key conflicts for other keys before adopting them.
- Confirm the new character gets its own saved Book 1/3 titles; save a book rename and wait five seconds. If auto-discovery fails, choose the exact USER character folder once. Check another character retains its own names/aliases.
- Compare locked/unlocked/held header layout; adjacent text must remain stationary.

75 mocked-host Lua 5.4 regression groups pass. This is not live Ashita/VanaCore verification; LuaJIT is covered by the repository's PR CI, whose result must be checked separately. No public release or updater promotion.
