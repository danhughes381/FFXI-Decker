# Decker v1.50.17-dev character layout test

Based on Development v1.50.16-dev, preserving immediate auto-hide and UI experiments.

Each character now saves HUD, StateBar and collapsed-button positions in its own existing cfg. Existing character-specific width, height and scale settings are preserved. Positions save after dragging settles, on character change and on addon unload. Restoration checks the current viewport. Keep existing character cfg files when installing.

Live checks still required:

1. Give two characters different HUD positions, widths/scales and StateBar placements.
2. Switch between them and confirm each layout returns, both unlocked and locked.
3. Reload Decker, then restart the game and confirm the layouts remain separate.
4. Check both different game resolutions and a reduced window size; restored controls should remain reachable.
5. Test dragging, locking, collapsed auto-hide and 0s auto-hide.

Offline: 67 mocked regression groups pass in Lua 5.4. GitHub runs Lua 5.4 and LuaJIT, syntax checks and a test-only ZIP integrity check. Offline checks do not establish live host acceptance.
