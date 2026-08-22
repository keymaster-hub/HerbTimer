# HerbTimer

A lightweight World of Warcraft (TBC Classic) addon that tracks respawn points for gathering nodes. When you loot a tracked item (herb, ore, etc.), HerbTimer remembers the exact spot and time, then shows a marker on the world map **and** the minimap — so you know where and when to go back.

## Features

- **Automatic tracking** — no manual marking. Loot a tracked item and HerbTimer silently records the location and time.
- **World map + minimap display**, powered by [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons) (the same positioning library used by GatherMate2).
- **Off-range minimap markers** — nodes outside the minimap's radius slide onto its border instead of disappearing, capped at one marker per screen side (top/bottom/left/right) so the edge doesn't get cluttered.
- **Two time display modes** — clock time (`14:32`) or elapsed time (`5m`, `1h 12m`).
- **Configurable item icons** — show the item's actual icon, or just a plain time-only marker.
- **Per-item display limit** — only show the N most recent points per tracked item (default: 2), so old, likely-already-picked nodes don't clutter the map. Applies to the map/minimap display only; nothing is deleted from the saved data.
- **Customizable item list** — track any item by ID, not just herbs.
- **Standalone settings window** (`/ht options`), plus a shortcut entry in the in-game **Options → AddOns** list.

## Installation
[CurseForge](https://www.curseforge.com/wow/addons/herbtimer)

or

1. Download or clone this repository.
2. Copy the `HerbTimer` folder into your WoW `Interface/AddOns/` directory.
3. Make sure the folder structure looks like:
   ```
   Interface/AddOns/HerbTimer/
   ├── HerbTimer.toc
   ├── HerbTimer.lua
   ├── HerbTimer.xml
   └── Libs/
       ├── LibStub/
       ├── CallbackHandler-1.0/
       └── HereBeDragons/
   ```
4. Restart WoW or `/reload`.

**Supported client:** TBC Classic (Interface `20506`).

## Usage

By default, HerbTimer tracks **Nightmare Vine** (item ID `22792`). Just loot it and a marker will appear on the map and minimap.

### Settings window

```
/ht
```
Opens the settings window, where you can:
- Toggle item icons on/off
- Toggle minimap display on/off
- Toggle off-range border markers on/off
- Switch between clock time and elapsed time
- Set the max points shown per item
- Add or remove tracked item IDs
- Clear all saved points

The addon is also listed under **Options → AddOns → HerbTimer** in-game, with a button to open the same window.

### Slash commands

| Command | Description |
|---|---|
| `/ht` | Open the settings window |
| `/ht help` | Print the list of commands to chat |
| `/ht list` | List all saved points |
| `/ht add <itemID>` | Start tracking an item |
| `/ht remove <itemID>` | Stop tracking an item and remove its saved points |
| `/ht items` | List currently tracked item IDs |
| `/ht icons` | Toggle item icons on the map/minimap |
| `/ht minimap` | Toggle all HerbTimer icons on the minimap |
| `/ht border` | Toggle off-range points floating on the minimap border |
| `/ht time` | Toggle between clock time and elapsed time |
| `/ht clear` | Clear all saved points |
| `/ht options` / `/ht config` | Open/close the settings window |

## How it works

HerbTimer hooks the `CHAT_MSG_LOOT` event and, for tracked item IDs, records the player's current map position (`mapID`, `x`, `y`) and timestamp. If a saved point for that item already exists nearby, it's updated in place (refreshing the respawn timer) instead of creating a duplicate.

Map/minimap rendering uses [HereBeDragons-2.0](https://github.com/Nevcairiel/HereBeDragons) for coordinate math and [HereBeDragons-Pins-2.0](https://github.com/Nevcairiel/HereBeDragons) for pin placement — the same library GatherMate2 is built on.

## Credits

- [HereBeDragons](https://github.com/Nevcairiel/HereBeDragons) by Nevcairiel — map/minimap positioning library.
- [LibStub](https://www.wowace.com/projects/libstub) and [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler) — shared library infrastructure.

## License

This project bundles third-party libraries (LibStub, CallbackHandler-1.0, HereBeDragons) under their own respective licenses. See each library's source header for details.
