# StormTarget v0.4-dev — Tab cycle, optional Enter engage, Focus recall and temporary return

**Draft code. Never installed or tested in a live Storm XI client.** Decker and Aegis working sources are unchanged.

## The intended two-key flow
- Hotkey 1: select next nearby eligible monster by distance. No attack.
- Hotkey 2: choose exactly one configured action: `engage`, `focusback`, `return`, `claim`, or `resume`.
- No third mandatory binding. Focus can also be assigned to an existing Decker macro, if preferred.
- **Enter binding is optional**, not active by default. FFXI and Decker both use Enter for confirmations, so use it only after testing with Decker macro navigation INACTIVE and no native menu/subtarget.
- No action tracking of arbitrary Cure, Flash, Sleep, Dispel or third-party macros. Returning automatically on queued spell cast would risk wrong target selection.

## Setup and test
Load the standalone development addon at `Ashita/addons/stormtarget/stormtarget.lua`:
```text
/addon load stormtarget
/stormtarget bind cycle TAB
/stormtarget bind context ENTER
/stormtarget mode engage
/stormtarget status
```
Binding is **NOT enabling**. To explicitly opt into key interception:
```text
/stormtarget tab on
/stormtarget context on
```
Switch off instantly:
```text
/stormtarget context off
/stormtarget tab off
```

## Focus Target
```text
/stormtarget focus
```
Stores current target identity. Later:
```text
/stormtarget focusback
```
Reselects it without attacking. To make the *second* hotkey return to Focus:
```text
/stormtarget mode focusback
```
Focus is an entity index + server ID that clears on zone change and is valid only while that exact entity remains loaded. This is not a focus display panel and does not detect player actions outside StormTarget.

## Temporary target return
1. Target Tiamat first.
2. Tab to an add.
3. Run a standard Flash/Sleep/Dispel macro on the selected add.
4. **After confirming your action has happened**, run:
```text
/stormtarget return
```
This reselects the original target without auto-attack. It stores the initial target at the beginning of a StormTarget selection excursion rather than replacing it on every subsequent Tab.
To have the second hotkey perform Return instead of Engage:
```text
/stormtarget mode return
```
This prototype does not do automatic post-cast return. The source lacks a trustworthy spell-completion and action-target correlation system, and restoring prematurely would risk casts going to the wrong monster.

## Engagement
```text
/stormtarget engage
```
Queues native `/attack on` for current selected living monster; this is an **attack request**, not proof of actual engagement. If already meleeing a different monster, FFXI native Switch Target may be required. Confirm with Peppa in-client before relying on it.
```text
/stormtarget resume
```
Recalls the last monster on which StormTarget explicitly requested engagement and requests attack again. If that identity is gone, the command can fall back to selecting the last StormTarget-selected monster without auto-attacking it.

## Enter collision: critical
Decker main branch source handles Enter scan codes 28 and 156 inside its active custom macro-navigation mode, where Enter executes the highlighted Decker macro. StormTarget currently intercepts scan code 28 only and does NOT have a shared lock with Decker. Although its input code checks preexisting `e.blocked` and subtarget/chat/menu state, **callback order cannot be assumed**, and Decker's sticky navigation may still conflict.
**Do not enable Enter override during Decker macro-navigation until an explicit shared focus/ownership guard has been implemented and verified.** For initial tests prefer F11/F12 or GRAVE instead of Enter, and keep Decker's Enter untouched. The feature is an opt-in experiment, not a safe production binding.

## Tests that must pass before merging
- Tab cycles actual living monsters; native Tab works with interception off and with no eligible target.
- Key bindings: duplicate keys rejected; physical hold and keyup do not repeat.
- Enter off: normal targeting confirmation, macro HUD, chat and Decker enter behaviour unchanged.
- Enter on: check native chat, menu, subtargets (`<stal>`, `<stpt>`, `<stnpc>`), Cover, and Decker hold/sticky navigation.
- Attack issued only from explicit `engage`/context engage/`resume`; not Tab, `return`, `focusback`, `claim`.
- Flash/Sleep and later Return: no attack, correctly chooses initial target and does not restore before the spell is cast.
- Focus restore verifies identity; test depops and zoning.
- At engaged-switch, observe whether `/attack on` truly changes melee target; do not treat queue success as proof.
- Verify no regression on six-account Ashita setup, and FPS impact acceptable.
- No automatic promotion, installation, stable merge, or updater modification.

## Source & status
- Draft PR https://github.com/danhughes381/FFXI-Decker/pull/19
- Original targeting audit: `STORMTARGET_REUSE_AUDIT.md`
- StormTarget source: `addons/stormtarget/stormtarget.lua`
