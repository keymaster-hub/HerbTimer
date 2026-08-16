# HerbTimer

**HerbTimer** is a lightweight World of Warcraft TBC Classic addon for tracking gathering locations and the last time an item was looted.

The addon saves the location and loot time of gathered items and displays them directly on the World Map.

## Features

- Track gathering locations automatically from your own loot messages.
- Save the **last loot time** for each location.
- Display the last loot time directly on the World Map.
- Choose how loot times are displayed:
  - **Clock** — `14:32` (default)
  - **Elapsed** — `5m ago` / `1h 12m ago`
- Live elapsed-time updates while the World Map is open.
- Optional map icons.
- Duplicate protection — the same gathering point is not unnecessarily added multiple times.
- Works with any item ID added to the tracking list.
- Simple slash commands for managing tracked items and saved locations.
- Lightweight and designed for a small personal database of gathering spots.

## Default tracked item

The addon is currently configured to track:

- **Nightmare Vine** — `22792`

Additional items can be added manually using their item ID.

For example:

```text
/ht add 22792
```

## Commands

### Show saved locations

```text
/ht list
```

or

```text
/herbtimer list
```

Displays the locations currently stored in the database.

### Add an item

```text
/ht add <itemID>
```

Example:

```text
/ht add 22792
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

This toggles the display of gathering icons on the World Map.

### Change time display mode

```text
/ht time
```

Switches between two time display modes:

- **Clock** — `14:32` (default)
- **Elapsed** — `5m ago` / `1h 12m ago`

The selected mode is saved and persists through `/reload` and relogging.

The same time formatting is used in `/ht list` and on World Map pins.

When **Elapsed** mode is active, the displayed times are automatically updated every 30 seconds while the World Map is open.

### Clear saved locations

```text
/ht clear
```

Removes the saved gathering locations from the database.

## How it works

When you loot a tracked item, HerbTimer reads the loot message from the game and records:

- Map ID
- X/Y coordinates
- Item ID
- Item name
- Last loot time

The saved information is then used to display the gathering location and its last known loot time on the World Map.

The last loot time can be displayed either as a clock time or as elapsed time since the herb was collected.

The same formatting function is used both on the World Map and in `/ht list`, keeping the displayed time consistent.

## Example

After gathering an item, the location can appear on the map with its last collection time:

```text
       14:32
         ●
```

or in elapsed mode:

```text
       5m ago
         ●
```

The elapsed time is updated automatically while the World Map is open.

## Requirements

- World of Warcraft **The Burning Crusade Classic**
- No external libraries required.

## Installation

1. Download the latest release.
2. Extract the `HerbTimer` folder.
3. Copy it to:

```text
World of Warcraft\_classic_\Interface\AddOns\
```

Your final folder structure should look like:

```text
Interface
└── AddOns
    └── HerbTimer
        ├── HerbTimer.toc
        ├── HerbTimer.lua
        └── HerbTimer.xml
```

4. Start the game and make sure **HerbTimer** is enabled in the AddOns menu.

> **Note:** GitHub's **Code → Download ZIP** downloads the source repository, not a ready-to-install addon package. For installation, use a release ZIP when one is available.

## Status

**Beta**

The addon is intentionally small and currently focuses on tracking gathering locations and displaying the last loot time on the World Map.

More functionality may be added in the future.

## Author

**Keymaster**
