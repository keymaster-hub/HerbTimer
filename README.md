# HerbTimer

**HerbTimer** is a lightweight World of Warcraft TBC Classic addon for tracking gathering locations and the last time an item was looted.

The addon saves the location and loot time of gathered items and displays them directly on the World Map.

## Download

Download the latest version from the
[Releases](../../releases) page.

> **Do not use GitHub's "Download ZIP" button for installation.**
> It downloads the source repository rather than the addon package.

## Features

- Track gathering locations automatically from your own loot messages.
- Save the **last loot time** for each location.
- Display the last loot time directly on the World Map.
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

## Example

After gathering an item, the location can appear on the map with its last collection time:

```text
       19:13
         ●
```

The time is displayed continuously when a saved time is available.

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

## Status

**Beta**

The addon is intentionally small and currently focuses on tracking gathering locations and displaying the last loot time on the World Map.

More functionality may be added in the future.

## Author

**Keymaster**
