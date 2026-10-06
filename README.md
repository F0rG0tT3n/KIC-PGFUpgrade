# KIC PGF Upgrade

KIC PGF Upgrade adds a `KIC +1` toggle to the Retail World of Warcraft Premade Group Finder dungeon search.

When enabled, it:

- shows only Mythic+ listings exactly one level above the character's seasonal best for that dungeon;
- uses +2 for dungeons without a completed seasonal key;
- excludes groups that already contain the logged-in character's class.

Premade Groups Filter is supported as an optional dependency. When both addons are installed, KIC PGF Upgrade applies its rules after the active Premade Groups Filter rules.

## Usage

Open **Group Finder > Premade Groups > Dungeons** and click **KIC +1**.

The filter can also be controlled with:

```text
/kicupgrade
/kicupgrade on
/kicupgrade off
```

## Installation

Copy the `KIC-PGFUpgrade` folder into the World of Warcraft Retail `Interface/AddOns` directory.
