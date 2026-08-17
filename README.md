# HerbTimer

**HerbTimer** is a lightweight World of Warcraft TBC Classic addon for tracking gathering locations and the last time an item was looted.

The addon saves gathering locations and displays the last loot time on both the **World Map** and **Minimap**.

## Features

- Track gathering locations automatically from your own loot messages.
- Save the **last loot time** for each location.
- Display gathering locations on the **World Map and Minimap**.
- Choose how loot times are displayed:
  - **Clock** — `14:32` (default)
  - **Elapsed** — `5m ago` / `1h 12m ago`
- Live elapsed-time updates while the World Map is open.
- Optional gathering icons on both the World Map and Minimap.
- Minimap points outside the visible area can optionally **float to the edge of the Minimap**.
- Smart Minimap edge handling — no more than one edge icon is shown on each visible side of the Minimap.
- Works correctly with **Rotate Minimap** enabled.
- Automatically synchronizes World Map and Minimap when changing zones, looting, removing items, or clearing saved locations.
- Lightweight and designed for a small personal database of gathering spots.

## Libraries

HerbTimer uses:

- **HereBeDragons**
- **HereBeDragons-Pins**

These are the same libraries used by GatherMate2 for map and Minimap positioning.

The libraries are included in the `Libs/` folder and loaded before the main addon file.

## Default tracked item

The addon is currently configured to track:

- **Nightmare Vine** — `22792`

Additional items can be added manually using their item ID.

## Commands

### Show saved locations

```text
/ht list
```

### Add an item

```text
/ht add <itemID>
```

### Remove an item

```text
/ht remove <itemID>
```

### Show tracked items

```text
/ht items
```

### Toggle map icons

```text
/ht icons
```

Toggles HerbTimer gathering icons on both the World Map and Minimap.

### Change time display mode

```text
/ht time
```

Switches between:

- **Clock** — `14:32` (default)
- **Elapsed** — `5m ago` / `1h 12m ago`

The selected mode is saved and persists through `/reload` and relogging.

The same time formatting is used on the World Map, Minimap, and `/ht list`.

When **Elapsed** mode is active, the displayed times are updated every 30 seconds while the World Map is open.

### Toggle Minimap icons

```text
/ht minimap
```

Completely enables or disables HerbTimer icons on the Minimap.

### Toggle Minimap edge display

```text
/ht border
```

Controls whether gathering points outside the visible Minimap area are displayed on its edge.

When enabled, out-of-range points float to the Minimap edge. Only the nearest point on each visible side is displayed. Points physically inside the Minimap radius are displayed normally.

When disabled, points outside the Minimap radius are hidden.

The edge calculation works correctly with **Rotate Minimap** enabled.

### Clear saved locations

```text
/ht clear
```

Removes all saved gathering locations from the database.

## Minimap behavior

HerbTimer uses HereBeDragons-Pins to position gathering points on the Minimap.

Points within the visible Minimap radius are displayed at their actual positions.

When edge display is enabled, points outside the visible radius are moved to the Minimap edge instead of disappearing.

To prevent clutter, edge points are grouped by their visible screen side:

- Top
- Bottom
- Left
- Right

Only the nearest point on each side is displayed.

Points inside the Minimap radius are not affected by this limitation.

## How it works

When you loot a tracked item, HerbTimer reads the loot message and records:

- Map ID
- X/Y coordinates
- Item ID
- Item name
- Last loot time

The saved information is used to display the gathering location and its last known loot time on the World Map and Minimap.

## Requirements

- World of Warcraft **The Burning Crusade Classic**
- No external libraries need to be installed separately.

## Installation

1. Download the latest release.
2. Extract the `HerbTimer` folder.
3. Copy it to:

```text
World of Warcraft\_classic_\Interface\AddOns\
```

The final folder structure should look like:

```text
Interface
└── AddOns
    └── HerbTimer
        ├── HerbTimer.toc
        ├── HerbTimer.lua
        ├── HerbTimer.xml
        └── Libs
            ├── HereBeDragons
            └── HereBeDragons-Pins
```

4. Start the game and make sure **HerbTimer** is enabled in the AddOns menu.

> **Note:** GitHub's **Code → Download ZIP** downloads the source repository, not a ready-to-install addon package. For installation, use a release ZIP when one is available.

## Status

**Beta**

HerbTimer is currently focused on tracking gathering locations and displaying the last loot time on the World Map and Minimap.

More functionality may be added in the future.

## Author

**Keymaster**
