# Interactions: what a click, a right-click and a key do

Signpost behaves the way players expect an add-on to behave: a button on the minimap, an entry in the AddOn Compartment, a small menu on
a right-click, keys on the Key Bindings screen. The user asked for this on 2026-10-21 ("the common, what do you call it, app interactions
that apps have"). Their own example was Shift-clicking the button on the minimap border to hide or show the steps panel, left-click for the
big window and right-click for "a small little context window", with "Please don't take that as instruction": they asked to "go and look
extensively" for "the industry standard". This file records what the standard is and where it comes from, the map Signpost implements,
where Signpost differs from the first proposal and why, and what only the real client can confirm. The code is `UI/Launcher.lua`, the key
bindings are `Bindings.xml`, the specs are `tests/launcher_spec.lua` (with the fakes in `tests/mocks/launcher.lua`). The contract is in
`docs/ENGINE.md` ("UI/Launcher.lua").

## 1. What the convention is

**There is no official style guide for an add-on's button.** What exists is a contract (LibDataBroker) and practice. Everything below was
read at its source on 2026-10-21; where a page could not be read, that is said.

| Source | What it shows |
|---|---|
| [LibDataBroker-1.1 data specification](https://github.com/tekkub/libdatabroker-1-1/wiki/Data-Specifications) | A launcher is `type = "launcher"` with an `icon` and an `OnClick(self, button)` that the display attaches to its frame. A tooltip is `OnTooltipShow(tooltip)`: the display positions and shows it, the handler only fills it; the spec gives as its common use "to explain the mapping of click buttons to function (e.g. left click for hide window, right click for config window etc.)". "Quicklaunchers should never expect a secure frame to be used." The spec says **nothing about modifier keys**: a handler reads `IsShiftKeyDown()`, `IsControlKeyDown()`, `IsAltKeyDown()` itself. |
| [Bartender4 (source)](https://github.com/Nevcairiel/Bartender4/blob/master/Bartender4.lua), `createLDBLauncher` | Left-click toggles the bar lock, right-click opens or closes the options dialog; it looks at no modifier key. The tooltip is the name followed by one hint per click, the key in yellow and the rest in the default colour: `\|cffffff00Click\|r to toggle bar lock`, `\|cffffff00Right-click\|r to open the options menu` (the backslashes only keep the table intact; the text starts with the colour code `|cffffff00`). |
| [MinimapIconBar](https://www.curseforge.com/wow/addons/minimapiconbar) | "Click it to open or close the row, right-click for options, and drag it to move the whole bar"; **Shift-click** does the lock: "shift-click the M to freeze position + open state". |
| [Minimap Button Stash for TBC](https://www.curseforge.com/wow/addons/mbs-minimap-button-stash-for-tbc-2026) | Left-click opens or closes its window; **Shift + right-click** locks or unlocks its icon: another add-on, another meaning for Shift. |
| `Libs/LibDBIcon-1.0` (the bundled copy, minor 57) | The button is registered for the release of any mouse button and for left-drag, and hands `(button frame, mouse button)` to the object's `OnClick`. Its saved table holds `hide`, `lock`, `minimapPos`, `showInCompartment`. `Hide` and `Show` only act on the button: **the saved `hide` flag is the add-on's to keep**; `Lock` writes `db.lock = true`, `Unlock` clears it. If the object has `OnTooltipShow` the library anchors its own tooltip at the button, calls it and shows the tooltip. |
| [Blizzard's `AddonCompartment.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Minimap/Mainline/AddonCompartment.lua) | Each compartment entry is `rootDescription:CreateButton(text, func)` with `RegisterForClicks("AnyUp")`; the click reaches the TOC function as `CallAddonGlobalFunc(name, menuInputData.buttonName)`, so **both mouse buttons arrive as `(addonName, "LeftButton" or "RightButton")`**. The hover functions get `(addonName, buttonFrame)`; the compartment's own icon shows its tooltip with `GameTooltip:SetOwner(self, "ANCHOR_LEFT")`. The TOC fields are `AddonCompartmentFunc`, `AddonCompartmentFuncOnEnter`, `AddonCompartmentFuncOnLeave` ([Warcraft Wiki: Addon compartment](https://warcraft.wiki.gg/wiki/Addon_compartment); since 11.0 an automatic registration no longer receives the frame as a third click argument). |
| Blizzard's Menu system: [Menu implementation guide](https://warcraft.wiki.gg/wiki/Blizzard_Menu_implementation_guide), `Blizzard_Menu/MenuUtil.lua`, `MenuTemplates.lua`, `Menu.lua` | `MenuUtil.CreateContextMenu(owner, generator)` opens a menu **at the cursor** and calls `generator(owner, rootDescription)`; the menu closes by itself if the owner is hidden. `root:CreateTitle(text)`, `CreateButton(text, callback, data)`, `CreateCheckbox(text, isSelected, onSelect, data)`, `CreateDivider()`. A button has no response set, which the menu treats as "close all menus"; a check box sets `MenuResponse.Refresh`: it stays open and re-reads its state. `MenuUtil.ShowTooltip` does **not** exist in that source (the functions are `ShowTooltipEx` and `HideTooltipEx`). |
| [Warcraft Wiki: Bindings.xml](https://warcraft.wiki.gg/wiki/Bindings.xml) | `Bindings.xml` in the add-on's folder is loaded by the client by its name (it is **not** listed in the TOC). `<Binding name="TOKEN" header="HEADER">Lua code</Binding>`; the Key Bindings screen shows `BINDING_NAME_<name>` and `BINDING_HEADER_<header>` (the bare token when the global is missing). The code runs insecurely; `keystate` is `"down"` (or `"up"` with `runOnUp="true"`); a literal `<` must be escaped. |
| RestedXP | Its pages answer 403 to this tool: nothing is claimed about its button or its window. |

So the convention, as far as there is one:

1. **Left-click** opens (or toggles) the main window.
2. **Right-click** opens the options or a small menu.
3. A **modifier-click** (Shift most often) does a secondary toggle. Nothing agrees on *which*: one add-on locks with Shift-click, another with
   Shift + right-click. The meaning is the add-on's own, so the tooltip must say it.
4. **Dragging** moves the button; many add-ons also let it be locked.
5. The **tooltip** says what the button is for and lists the clicks (the key in yellow).
6. Players dislike clutter: a way to **hide the button** is expected, and something to bring it back.
7. Nothing was found for Ctrl, Alt, the middle button or the side buttons.

## 2. The map Signpost implements

| Where | Input | What it does |
|---|---|---|
| Minimap button | Left-click | Shows or hides the Journal |
| | Shift + left-click | Shows or hides the step card (the saved setting, as the Journal's box and `/signpost show`/`hide` do) |
| | Right-click (with or without Shift) | Opens the quick menu at the cursor |
| | Left-drag | Moves the button around the minimap (LibDBIcon); not when locked |
| | Hover | Tooltip: the name, where the player is (`<chapter> · step i/N` and the step's first line, or "No guide is loaded"), a blank line, then the three clicks above in the yellow-key style |
| | Ctrl or Alt held | Ignored: the click does what it does without the key |
| | Middle or side buttons | Nothing |
| AddOn Compartment entry | Left-click, Shift + left-click, right-click | The same as the minimap button (Shift is read from the keyboard: the compartment only passes the button's name) |
| | Hover | The same tooltip, anchored left of the menu entry |
| Step card | Right-click | The quick menu, owned by the card (the Journal is its first entry) |
| Key Bindings screen | Header "Signpost" | Show or hide the Journal; show or hide the step card; previous step; next step; skip this step; find my place |
| Slash | `/signpost`, `/signpost card [on\|off]`, `/signpost minimap [show\|hide\|lock\|unlock]` | The Journal; the card; the button |

Nothing here is protected: every action toggles a Journal or card frame or moves the guide's pointer, so all of it works in combat too (the
step card's secure item button is only ever changed out of combat, as before). A client without the Menu system gets what the right-click
did before: the Journal's Settings tab from the button and the compartment, the Journal on the current step from the card.

### The quick menu (`Launcher:BuildMenu(owner, root)`)

One function builds it for all three openers. A couple of quick options for the middle of play, not a settings panel:

```
Signpost                                  (title)
Open the Journal
-----------------------------------------
[x] Show the step card
[ ] Lock the step card
[x] Track only the current step's quests
-----------------------------------------
Find my place                             (only when the placement layer exists: ns.Progress.Place)
Previous step
Skip this step
-----------------------------------------
Settings...                               (the Journal's Settings tab)
Hide the minimap button                   (reads "Show the minimap button" while it is hidden)
```

The check boxes read and write the same settings as the Journal's Settings tab. Previous step, Skip this step and Find my place run the
player's own `/signpost back`, `skip` and `place`: the same checks and the same chat line about where the pointer landed.
"Hide the minimap button" says in chat how to bring it back (`/signpost minimap`, or the box in the Settings tab).

### Settings

`SignpostDB.minimapButton = { hide, lock, minimapPos }` is the table LibDBIcon is given. The Journal's Settings tab (first column) has
**Show the minimap button** and **Lock the minimap button's position**; both go through `Launcher:SetButtonHidden/SetButtonLocked`, which
write the flag and call LibDBIcon's `Hide`/`Show`/`Lock`/`Unlock`. `/signpost minimap` does the same from the keyboard.

### Key bindings

Each binding in `Bindings.xml` runs one line, `SlashCmdList.SIGNPOST("<command>")`, so no function of ours stands behind a key and a key
does exactly what the typed command does (a bare `/signpost`, which the Journal binding runs, shows or hides the Journal). The labels are
the only globals this adds: `BINDING_HEADER_SIGNPOST` and `BINDING_NAME_SIGNPOST_JOURNAL`, `_CARD`, `_BACK`, `_NEXT`, `_SKIP`, `_PLACE`
(set in `UI/Launcher.lua`, declared in `.luacheckrc`). `tools/check_repo.py` fails when a binding has no label, when the file is not
well-formed XML or when a TOC lists it. No key is bound by default: the player chooses.

## 3. Where Signpost differs from the first proposal (and from the convention)

The first proposal (the lead's, "build it as proposed") is the baseline. These are the places where the implementation differs, each with
its reason:

1. **The compartment's tooltip uses `GameTooltip`, not `MenuUtil.ShowTooltip`.** The proposal named that function; it does not exist in
   Blizzard's source (there are `ShowTooltipEx` and `HideTooltipEx`). The code does what the compartment's own icon does:
   `GameTooltip:SetOwner(frame, "ANCHOR_LEFT")`, fill, `Show`.
2. **The compartment's right-click opens the menu one frame later** (`C_Timer.After(0, ...)`). The compartment closes its own menu after
   the entry's function returns; a menu opened inside that call could be closed with it. Reading Blizzard's source does not settle
   whether it would be (`VERIFY(beta)`), and the delay costs nothing.
3. **The last menu entry flips** between "Hide the minimap button" and "Show the minimap button". With the button hidden the menu (reached
   from the card or the compartment) must still offer the way back.
4. **Menu actions run through the slash commands** (`back`, `skip`, `place`) instead of calling the engine, so they print the same chat
   line and obey the same rules as the typed command. Key bindings do the same.
5. **Ctrl and Alt are ignored** (a Ctrl-click opens the Journal like a plain click) and **the other mouse buttons do nothing**. No
   convention was found for them, and a player who holds Ctrl by accident still wants the Journal.
6. **The step card's right-click changed meaning.** It used to open the Journal on the current step; it now opens the menu, whose first
   entry opens the Journal at the tab last used (the Route tab's "Current step" button makes the old jump). A client without the Menu
   system keeps the old behaviour.
7. **Two slash commands were added** because bindings and menu entries can only run commands: `/signpost card [on|off]` (no word: toggle)
   and `/signpost minimap [show|hide|lock|unlock]` (no word: show or hide). Both report where they leave the setting where that is not
   obvious.
8. **The Settings tab's check boxes are drawn at 26 instead of 32** (`CHECK_SIZE` in `UI/Journal.lua`). The first column now holds eleven
   boxes, and at the template's size the card steppers and the profession line would have run over the buttons at the bottom. Eleven
   smaller rows take the room nine took. This was worked out from the code, not seen in the client (probe below). The pane is full, though:
   the next setting needs a scrolling or a second page (backlog: *the-journal-s-settings-tab-is-full*).
9. **Not done: a LibDataBroker data source with the current step as its text** (for Titan Panel, ChocolateBar and the like). The launcher
   object already appears in those bars with its icon, tooltip and clicks; a text-bearing second object is a small addition but nobody can
   confirm it without such a bar, so it is a backlog item rather than code (backlog: *a-libdatabroker-data-source-with-the-current-step*).
10. **`Launcher:Where()` builds the step card's `<chapter> · step i/N` text a second time** instead of calling the card's own function, so
    that `UI/StepFrame.lua` is touched only in `OnRightClick` while other work edits it (backlog: *launcher-where-copies-the-step-card-s-header*).

## 4. What only the real client can confirm

All of this is built on the mock; none of it has been seen in the game. The open probes are in `docs/FOREVER-API-NOTES.md`
("Launcher"). In short:

- the quick menu: it opens at the cursor with the title, buttons, check boxes and dividers; a check box keeps it open and shows the new
  state; a button closes it; hiding the owner closes it;
- the compartment: a right-click reaches `Signpost_OnAddonCompartmentClick` with `"RightButton"`, our menu opens and stays open, the
  hover tooltip shows and hides, `IsShiftKeyDown()` is true inside the click;
- the Key Bindings screen shows the header "Signpost" with six labelled actions (under AddOns, presumably), and a bound key works, in
  combat too;
- the minimap button: Shift-click, drag, lock, hide and show, the saved choices across `/reload`, the tooltip;
- the Settings tab's first column fits above the buttons at the bottom with eleven boxes.

## 5. Adding to it

- **A menu entry:** add it in `Launcher:BuildMenu` (an action through `safely(...)`, a check box through `reading(...)` for its state),
  add the label to the expected layout in `tests/launcher_spec.lua`, and keep the menu short: it is for the middle of play.
- **A binding:** add the `<Binding>` to `Bindings.xml` (name `SIGNPOST_<ACTION>`, header `SIGNPOST`, body one
  `SlashCmdList.SIGNPOST("<command>")`), the label global in `UI/Launcher.lua` and `.luacheckrc`, and the name to the list in the spec.
  `python tools/check_repo.py` tells you what is missing.
- **A click:** the map lives in `Launcher:Click`; the tooltip's hint lines in `hints()`. Change both together and say so here.
