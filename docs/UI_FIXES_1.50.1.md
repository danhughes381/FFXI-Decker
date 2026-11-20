# Decker 1.50.1-dev — feedback fixes

Baseline: exact Library v1.50.0-dev ZIP source equals development branch source at 9436e1c (PR #4). Dan reported fonts close to the intended appearance; width/compact-label controls and movement locks failed, and StateBar source versus hotkey was unclear. Preserve the font implementation and existing native execution.

## Changes

The row renderer now uses the configured width rather than replacing it with available window width. Width/scale changes request window resizing. Short key labels show F1/1; full labels show CTRL 1 | F1 or ALT 1 | 1. Macro fonts and their defaults are retained.

HUD and StateBar independently retain unlocked coordinates and apply them every locked frame in addition to NoMove. The collapsed HUD also observes the main lock. Coordinates accept array, named-vector and numeric-pair host forms; anchors are cleared across character profiles. This runtime anchor is not a new saved-position format.

Settings uses a 7px scrollbar where the host exposes that style constant. Labels identify display scale, button width and last-used highlight colour. StateBar highlight colour names now match the actual colours.

Both direct and StateBar key selectors include letters, F1-F12, number-pad, punctuation and editing keys. These are single keys; Ctrl/Alt combinations remain native game controls. Macro key assignments have their own expandable section under Quick Setup. Main and StateBar assignments reject conflicts in the editor.

StateBar captures physical key-state edges as well as key-data presses. A press is executed once, held state is suppressed and releases clear capture. Native modifiers and navigation reservations retain their gates. StateBar shows its assigned key rather than its State/Utility type or macro source. Status and the last action result appear in its Settings section.

## Set up a StateBar button

1. Connect macros. Under Quick Setup, tick Allow Decker to reserve my assigned keys, then Enable Decker keyboard shortcuts. Reserved keys take over their usual game actions; switch shortcuts off before typing or editing macros.
2. Under StateBar, enable the bar and its hotkeys.
3. Choose State for a lasting mode (PDT/MDT): it stays highlighted after a successful request. Choose Utility for a one-off action (food/mount): it leaves the State highlight unchanged. Neither choice creates an action automatically or verifies equipped gear.
4. Choose Macro and its source (for example CTRL 1 in the current book/set), or Command and a supported command. Set a label if useful.
5. Assign a separate Hotkey, such as F11 or Num 1, that is unused by the main bar/navigation. CTRL 1 in Macro source is not a Ctrl+1 hotkey assignment. Mouse clicks use the same action.

## Verification

26 host-mocked regression groups pass under Lua 5.4 with existing 5.1 shims. Includes original execution, profiles, updater and glass tests; new coverage for width/label rendering, independent lock anchors, resizing, scrollbar style balance, expanded-key persistence and StateBar press/key-state deduplication/native suppression. ZIP integrity, exact packaged source and checksum checked. No game/native FFI calls executed. LuaJIT and Ashita/Vanacor unavailable here.

Live check: install addons/decker/decker.lua over the existing file, preserve your cfg files, reload Decker and reconnect. Drag each window unlocked, lock it and try dragging its heading/background. Check narrow/wide, short/full labels, scale and thin scrollbar. Assign F11 or Num 1 to a known StateBar action; verify single execution, no game action leakage, State/Utility highlight behaviour and main shortcuts/navigation. Test numpad with Num Lock on/off because physical keyboards may report different editing-key codes.

Keep this development candidate separate from main and the updater channel until the live check passes.

## 1.50.2-dev follow-up

Includes every fix above and corrects the hover tooltip seen as literal `%s` in the user's 1.50.0 screenshot. Pass the name as a single literal-text argument to SetTooltip. A mocked regression checks Help, a name containing percent characters and empty slots. 27 total regression groups pass. Hover a populated slot in game to confirm it displays the full name.

## 1.50.3-dev follow-up

Remove the blue native title strip and its duplicate writing. Overlay Begin calls now use an explicit open-state table rather than nil, retaining the NoTitleBar flag and using hidden window IDs. Title colours are transparent as a fallback. The black content area keeps its single DECKER/Book heading. Settings retains its standard title bar. The nil overload is a suspected cause of ignored flags in the reported host; no target-host reproduction is available here. 28 mocked regression groups pass, including explicit Begin arguments/flags for main HUD, StateBar and collapsed tab. Live check: confirm no blue strip, no duplicated heading and unlocked/locked dragging still behaves correctly. This candidate includes every previous fix.
