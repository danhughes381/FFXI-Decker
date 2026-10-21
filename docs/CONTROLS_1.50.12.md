# Decker 1.50.12-dev — named books and macro sets

Includes all previous v1.50 development feedback fixes. Install addons/decker/decker.lua over the existing file, keep your cfg profiles, reload and Connect to in-game macros. Assigned keys default on after successful connection unless you saved an opt-out. Owner-selected main, Stable and Development baseline. Both channels use the exact same 1.50.12-dev source; channel selection does not imply full live verification.

## Main HUD

The heading shows DECKER | Book 1 - WHM (#1), or your selected book number/name and current tracked set. The name is taken from the same per-character book-label source used in Settings: Decker alias first, imported game title second. Without either, it displays Book N. Long names abbreviate in the header; hover for the full label. A fixed identity field preserves the status and active-row positions when book/status text changes. LOCKED/HELD is red; UNLOCKED white. Only Active row: Upper/Lower follows the lock status.

Below the two macro rows, Macro set 1/10 and its arrows select a set inside the current book. Immediately to the right, book arrows and a Book N/20 dropdown choose the book. Dropdown choices include names. Previous/next book buttons wrap between 1 and 20. These book controls call the same existing native book setter as the Settings selector. The user confirmed changing books 1-3 worked in the previous v1.50.11 candidate; the new footer/name rendering remains unverified in game.

## Books, macro sets and equipment sets

The target-client screenshot shows 20 macro books. This candidate matches that menu, with 20 books each containing 10 macro sets. The earlier 40-book bound came from the broader upstream Ashita macro API; it was not a count of equipment sets. Native/UI requests in this target build are now restricted to books 1-20.

Equipment sets are separate presets of equipped gear. They are not additional macro books and are not managed by these controls. A macro can request a gear set, but the preset and the macro book are distinct things.

Native book/set numbers are still locally tracked requests rather than independent memory getters. Choose a macro set after switching books if needed and verify the in-game selection. Existing signature/pointer checks and deferred name refresh are retained.

## Book names

More → General → Book and Set controls lets you switch books and set Decker name for this book. That alias updates the HUD immediately and never renames the game book. Clear it to use an imported title.

Import saved in-game book names reads mcr.ttl from the exact character macro folder you supply. This target build uses the first 20 titles only. It reads files without modifying game data, supports the bounded printable-ASCII title format, and leaves the existing cache intact after invalid imports. Refresh after a rename has been saved by the game. This is saved-file import, not live title synchronization.

## Retained controls

Both rows: 1-0 is the new-profile default; saved layouts persist. Customise keys for both rows activates explicit custom mode when edited. Use my assigned keys is one switch below Connect to in-game macros. Advanced keys includes mod key, switch row key, Hold key pressed down or Press key once (Toggle), and Enable hotkeys.

With Hold hotkeys enabled, macros show only while the physical mod key is held and disappear on release, with no timer/recovery window. Toggle uses Appearance inactivity choices; auto-hide defaults off. Appearance Display defaults open. Finish first-time setup before selecting Hide completely. /decker settings independently opens Settings; /decker show enables normal HUD visibility (Hold still requires holding the key); /decker help lists recovery commands. Scrollbars and StateBar controls remain independent.

The Settings X closes the Settings window. StateBar Settings appears only while main Settings is open. StateBar hotkeys have their own permission and readiness status, scaled text/hover help and State/Utility explanations. Toggle chat echo says Macros locked/unlocked with locked red. Windows Sticky/Filter Keys shortcuts are OS settings; the addon leaves them unchanged.

## Verification

52 mocked Lua 5.4 groups pass, including named header alias/import fallback, native footer book selection and wrapping arrows, strict 1-20 bounds, read-only 20-title import and prior execution/visibility/profile/updater regression checks. ZIP integrity, exact packaged source and SHA-256 checked. LuaJIT/Ashita/Vanacor unavailable; no native calls executed outside mocks.

Next live check: confirm Book 1 - WHM and Book 2 - Bard in the header, then change both macro sets and books through the adjacent footer controls. Confirm the game selection and refreshed macro names match. Check heading fit and fixed positions at your chosen scale.
