# Decker — by Mutant X

**Enhanced In-Game Macro Interface for Final Fantasy XI**

**Keep your macros. Upgrade how you use them.**

*20 Macros. Two Rows. One Screen. Your Controls.*

Decker enhances FFXI's existing macro system. It displays all 10 Ctrl and 10 Alt macros together, while still using your original in-game macros. **No need to recreate your macro books or learn a separate macro language.**

### Navigate without holding Ctrl or Alt

In traditional FFXI, you hold **Ctrl** or **Alt** to open one macro row at a time. With Decker's **Toggle / Lock** navigation mode, press your chosen navigation key **once** to keep navigation active and see **both rows together**. Then use **Left / Right** to move between macro slots, **Up / Down** to move between macro sets, and your configurable **Switch Row Key** (default **End**) to switch between the Ctrl and Alt rows. Press the navigation key again to unlock.

You can move across slots, rows and sets without continuously holding Ctrl or Alt. **Ctrl and Alt remain available for FFXI's original controls.** Choose a comfortable navigation key that doesn't conflict with those bindings.

*Note: Macro books are separate from macro sets. Decker's book selector changes books; Up / Down navigates sets within the selected book.*

### Why Decker?

If you already have FFXI macros set up, Decker makes them easier to see and navigate without replacing the game's familiar Ctrl/Alt macro system. It's deliberately a lightweight alternative to building a fully custom hotbar. Keep your existing macros and change how you access them.

## Install

1. Download and extract the Decker ZIP.
2. Copy `addons/decker` into your Ashita `addons` folder.
3. Load Decker through Ashita while FFXI is running.

## First-time setup

1. **Refresh macros:** Open Decker Settings and select **Refresh macro names** to load your current Ctrl/Alt macro labels.
2. **Choose a navigation key:** In **Settings → Controls**, choose a **Navigation modifier** that's comfortable on your keyboard. **Right Shift is an example, not a requirement.** **Avoid Ctrl and Alt:** keep those for FFXI's traditional macro controls.
3. **Choose a mode:** Select **Hold to navigate** or **Toggle / Lock**, whichever suits you.
4. **Enable navigation:** Turn on **Enable custom navigation**, then close Settings.
5. **Navigate:** Hold or tap your chosen modifier. **Left / Right** selects slots; **End** switches Ctrl/Alt rows.
6. **Change sets and execute:** **Up / Down** changes sets; **Enter** runs the selected macro.
7. **Exit navigation:** Release the modifier in Hold mode, or tap it again in Toggle / Lock mode.
8. **Refresh when needed:** After changing macros in FFXI, use **Refresh macro names** again.

## Keyboard and peripheral bindings

Decker is designed for different keyboards, MMO mice and gaming keypads. **You don't have to use Ctrl or Alt to select macros.** Choose whichever supported keys suit your setup.

**Two optional binding approaches (design direction; not all behaviour is implemented or tested yet):**

- **Active Row Keys:** Enable a checkbox to let one configurable group of ten keys execute macros on the currently selected Ctrl or Alt row. For example, press **N** to switch rows, then **1–0** to run the corresponding macro. This must only intercept keys while Decker navigation is active.
- **Independent Row Bindings:** Assign ten keys to each row separately. For example, **1–0** for one row and **F1–F10** for the other, or keys emitted by an MMO mouse or Razer Orbweaver. These mappings should work without changing the active row.

The options should be independent so players can enable either or both. Detect and warn about duplicate bindings and native FFXI conflicts; do not silently take over gameplay keys. Peripheral support depends on the device sending keyboard inputs Ashita can recognise.

**Current release:** Decker includes configurable direct keybindings and a row-switch control. The proposed Active Row Keys checkbox and its number-key interception still need implementation and in-game verification. Do not treat this section as a claim that those features are shipped.

## Optional

Click macro buttons with the mouse, customise direct keybindings, or adjust opacity and auto-hide under Display. Avoid using Ctrl/Alt as Decker keybinds because they can interfere with native FFXI controls. Direct keyboard overrides are off by default.

Decker does not replace or rewrite your FFXI macro data.

**by Mutant X**

## Sharing, modifying & giving credit

Decker was created by **Mutant X** for the Final Fantasy XI community.

You're welcome to use it, share it, learn from it, and build your own improvements. If you share or release a modified version, please acknowledge **Decker by Mutant X** as the original project, link back to [this repository](https://github.com/danhughes381/FFXI-Decker), and make clear what you've changed.

Make it your own — just give credit where it started. Thanks for supporting the FFXI community!

**Licence:** [Apache License 2.0](LICENSE). See [NOTICE](NOTICE) for original-project attribution. The request to link back to GitHub is appreciated, but is not an additional licence condition.
