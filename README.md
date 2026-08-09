# EZ-Marker

A WoW addon for **TurtleWoW / OctoWoW (1.12 client)** that automatically assigns raid target markers to enemies in a configurable priority order. Marks are freed automatically when their target dies, so the raid always fights in the same order without you having to manually manage icons.

---

## Features

- **One hotkey to mark** - press it on each enemy and they get the next available mark in your configured order (Skull → Cross → Square → Moon → Triangle → Diamond → Circle → Star by default)
- **Automatic mark cleanup** - when a marked enemy dies its slot is freed and the next enemy will get that mark again, always starting from priority #1
- **Remove mark hotkey** - instantly removes the mark from your currently targeted enemy and frees the slot
- **Drag-to-reorder UI** - open the settings panel and drag the 8 marker icons to set your preferred kill priority
- **Minimap button** - draggable button for quick access; right-click resets tracking
- **Saved settings** - your custom mark order persists across sessions and reloads

---

## Installation

1. Copy the `EZ-Marker` folder into your addons directory:
   ```
   <WoW>\Interface\AddOns\EZ-Marker\
   ```
2. Remove "-master" from the folder name (if it has one);
3. Launch the game and make sure the addon is enabled in the character select screen.

---

## Setting Up Hotkeys

Go to **ESC → Key Bindings → scroll down to the EZ-Marker section** and bind:

| Binding | What it does |
|---|---|
| **Mark Target** | Applies the next free mark to your current hostile target |
| **Remove Mark (current target)** | Removes the mark from your current target and frees that slot |

---

## How It Works

### Marking enemies
1. Target an enemy.
2. Press your **Mark Target** key.
3. The enemy receives the highest-priority free marker (Skull by default).
4. Target the next enemy and press the key again → they get the next mark (Cross), and so on.
5. Each enemy gets a unique mark. If all 8 are in use, you'll see a chat message.

### Automatic cleanup
When a marked enemy dies, its marker slot is freed within ~1 second. The next enemy you mark will receive that freed slot, always restarting from the highest available priority. This keeps kill order consistent for your group without any manual management.

### Removing a single mark
Target a marked enemy and press your **Remove Mark** key. The icon is removed immediately and the slot becomes available.

---

## Settings Panel

Open via the **minimap button** (left-click) or type `/ezm`.

| Control | Action |
|---|---|
| **Drag icons** | Reorder mark priority (leftmost = first assigned) |
| **Reset Tracking** button | Clears the addon's internal memory - the addon forgets which marks are active and starts from #1 again. Visual icons on enemies remain until they die. |
| **Default Order** button | Restores the default Skull → Cross → Square → Moon → Triangle → Diamond → Circle → Star order |

---

## Minimap Button

| Action | Result |
|---|---|
| Left-click | Open / close settings panel |
| Left-drag | Reposition button around minimap edge |
| Right-click | Reset Tracking |

---

## Slash Commands

| Command | Action |
|---|---|
| `/ezm` | Toggle settings panel |
| `/ezmarker` | Same as `/ezm` |
| `/ezm reset` | Reset tracking |
| `/ezm help` | Print command list to chat |

---

## Notes & Limitations

- **Requires raid leader or assistant rank** to apply marks in a raid group.
- **Remove Mark** only works on your currently selected target.
- Settings (mark order and minimap position) are saved per-account in `EZMarkerDB`.

---
