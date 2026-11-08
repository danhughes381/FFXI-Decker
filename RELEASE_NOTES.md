# Decker v1.50.13-dev

Enhanced in-game macro interface for Final Fantasy XI — by **Mutant X**. Development build dated 21 October 2026.

## Included improvements
- Floating-glass interface with configurable fonts, opacity, sizing, position locks and compact macro labels.
- Both macro rows visible together; shared or custom keys, arrow navigation, row switching, native-style Hold visibility and Toggle/auto-hide controls.
- Named books using per-character Decker aliases or read-only saved-title import. Adjacent Book and Macro set controls support 20 books with 10 sets each; equipment sets remain separate.
- StateBar improvements: independent hotkeys and permission/readiness status, scaled labels, hover help and Settings visibility fixes.
- Updater fixes: explicit installed/channel versions, maintained Stable and Development channels, same-version Up to date results, immutable source download, SHA-256 checking, backup and reload.

## Install
Download **Decker_v1.50.13_dev_Mutant_X_Floating_Glass.zip** below. Extract and copy only addons/decker/decker.lua into your Ashita addons/decker folder, preserving existing character .cfg files. Reload Decker and select Connect to in-game macros. See docs/CONTROLS_1.50.13.md for setup and known limits.

## Verification and status
The owner confirms in-game testing using VanaCore/Ashita. This records owner testing; it does not claim every feature or the full update/install/reload flow has been independently verified in-game. All 54 mocked-host offline regression groups passed. ZIP integrity, packaged-source equality and recorded SHA-256 passed; live HTTPS manifests and pinned updater-source hashes were verified.

Both owner-selected updater channels remain on **1.50.13-dev**. The development suffix is retained; this is not final production acceptance. Native book/set requests remain locally tracked, and title import is saved-file import rather than live title synchronization.

Source commit: e095b847876ee89badfda00027ccda6e4c474bdb

ZIP SHA-256: cffc03ed2ecf8269465045dc156424bf56ade663af4c5094c50c9bc64cba848a
