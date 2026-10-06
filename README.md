# KIC PGF Upgrade

KIC PGF Upgrade adds a `KIC +1` toggle to the Retail World of Warcraft Premade Group Finder dungeon search.

When enabled, it:

- shows only Mythic+ dungeons whose next upgrade matches an exact key-range search such as `20-20`;
- uses +2 for dungeons without a completed seasonal key;
- excludes groups that already contain the logged-in character's class.

World of Warcraft does not expose a listing's key level to addons as a readable result field. Enter an exact range such as `20-20` in the native search box; the game filters the listing level, then KIC PGF Upgrade keeps only the dungeons for which +20 is your next upgrade. With no exact range, the addon still applies the Mythic+ and class filters.

Premade Groups Filter is supported as an optional dependency. When both addons are installed, KIC PGF Upgrade applies its rules after the active Premade Groups Filter rules.

## Usage

Open **Group Finder > Premade Groups > Dungeons**, enter an exact range such as `20-20`, then click **KIC +1**.

The filter can also be controlled with:

```text
/kicupgrade
/kicupgrade on
/kicupgrade off
```

## Installation

Copy the `KIC-PGFUpgrade` folder into the World of Warcraft Retail `Interface/AddOns` directory.
