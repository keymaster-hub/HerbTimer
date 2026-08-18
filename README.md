# HerbTimer

**HerbTimer** is a lightweight World of Warcraft: The Burning Crusade Classic addon for tracking gathering locations and the last time a tracked resource was looted.

Although it was originally created for herbs, HerbTimer can track **any lootable resource or item** by its Item ID.

## Features

- Automatically records the location and last loot time of tracked items.
- Displays saved points on both the **World Map** and **Minimap**.
- Shows the last loot time on map pins.
- Two time display modes:
  - **Clock** — `14:32` (default)
  - **Elapsed** — `5m ago` / `1h 12m ago`
- Automatically updates elapsed time while the World Map is open.
- Optional item icons on the World Map and Minimap.
- Optional display of out-of-range points on the Minimap border.
- Smart Minimap edge handling: at most one out-of-range point is shown on each visible side.
- Works correctly with **Rotate Minimap** enabled.
- Automatically refreshes map and Minimap points when the zone changes or saved data changes.
- Uses **HereBeDragons** and **HereBeDragons-Pins** for map and Minimap positioning.
- No external libraries need to be installed separately.

## Settings Window

HerbTimer has its own dedicated settings window instead of relying on the game's native interface options.

The window features:

- A Blizzard-style `UI-DialogBox` frame.
- A movable window that can be dragged by the frame.
- A close button (`×`).
- Closing with the **Esc** key.
- The same checkboxes, tracked-item list and controls available in the previous settings interface.
- No dependency on unavailable or broken native options APIs on the TBC Classic client.

Open the settings window with:

```text
/ht
```

or:

```text
/ht config
```

Both commands simply open or close the HerbTimer settings window.

## Tracked Resources

HerbTimer was originally designed for herbs, but it can track any lootable resource or item.

The default tracked resource is:

- **Nightmare Vine** — Item ID `22792`

**Mana Thistle** — Item ID `22793` can also be added to the tracked list.

Additional resources can be added by entering their Item ID in the settings window or using:

```text
/ht add <itemID>
```

Example:

```text
/ht add 22793
```

## Commands

### Open settings

```text
/ht
```

or:

```text
/ht config
```

Opens or closes the custom HerbTimer settings window.

### Show commands

```text
/ht help
```

Displays the available HerbTimer commands.

### Show saved locations

```text
/ht list
```

Displays saved points including map, coordinates, item and last loot time.

### Add an item

```text
/ht add <itemID>
```

Adds an Item ID to the tracked-item list.

### Remove an item

```text
/ht remove <itemID>
```

Stops tracking the item and removes its saved points.

### Show tracked items

```text
/ht items
```

Displays the currently tracked items.

### Toggle item icons

```text
/ht icons
```

Toggles HerbTimer item icons on the World Map and Minimap.

### Change time display

```text
/ht time
```

Switches between:

- **Clock** — `14:32`
- **Elapsed** — `5m ago` / `1h 12m ago`

The selected mode is saved and persists through reloads and relogging.

### Toggle Minimap icons

```text
/ht minimap
```

Completely enables or disables all HerbTimer icons on the Minimap.

When Minimap icons are disabled, HerbTimer does not register the icons at all.

### Toggle Minimap border markers

```text
/ht border
```

Controls whether points outside the visible Minimap radius are moved to the Minimap border.

When enabled, out-of-range points can be displayed along the Minimap edge.

When disabled, points outside the Minimap radius are simply hidden and are not moved to the edge.

### Clear saved locations

```text
/ht clear
```

Removes all saved gathering points.

### Show help

```text
/ht help
```

Displays the command list.

## Minimap

HerbTimer uses **HereBeDragons** and **HereBeDragons-Pins** to position Minimap points.

Points within the visible Minimap range are displayed at their actual positions.

When `/ht border` is enabled, points outside the visible range can be moved to the edge of the Minimap.

To reduce clutter, out-of-range points are grouped by their visible screen side:

- Top
- Bottom
- Left
- Right

Only the nearest point on each side is displayed.

Points that are physically inside the Minimap range are displayed normally and are not affected by this limitation.

The edge calculation works correctly with **Rotate Minimap** enabled.

## Time Display

The same time formatting is used on the World Map, Minimap and `/ht list`.

In **Clock** mode:

```text
14:32
```

In **Elapsed** mode:

```text
5m ago
1h 12m ago
```

Elapsed-time displays are refreshed automatically while the World Map is open.

## How It Works

When you loot a tracked item, HerbTimer reads the item ID from the loot message and records:

- Map ID
- X/Y coordinates
- Item ID
- Item name
- Last loot time

If the same tracked item is collected again at approximately the same location, HerbTimer updates the existing point instead of creating an unnecessary duplicate.

The saved information is then displayed on the World Map and Minimap.

## Requirements

- World of Warcraft **The Burning Crusade Classic**
- No additional libraries are required.

## Installation

1. Download the latest release.
2. Extract the `HerbTimer` folder.
3. Copy it to:

```text
World of Warcraft\_classic_\Interface\AddOns\
```

The final structure should look like:

```text
Interface
└── AddOns
    └── HerbTimer
        ├── HerbTimer.toc
        ├── HerbTimer.lua
        ├── HerbTimer.xml
        └── Libs
            ├── LibStub
            ├── CallbackHandler-1.0
            └── HereBeDragons
```

4. Start the game and make sure **HerbTimer** is enabled in the AddOns menu.

> **Note:** GitHub's **Code → Download ZIP** downloads the source repository. For installation, use the ZIP attached to a GitHub Release when available.

## Status

**Beta**

HerbTimer is intentionally lightweight and focused on tracking gathering locations and loot times.

It was originally designed for rare herbs such as Nightmare Vine and Mana Thistle, but any lootable resource can be tracked by adding its Item ID.

More functionality may be added in future releases.

## Author

**Keymaster**
