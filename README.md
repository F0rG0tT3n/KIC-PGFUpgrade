# KIC PGF Upgrade

KIC PGF Upgrade adds a `KIC +1` toggle to the Retail World of Warcraft Premade Group Finder dungeon search.

When enabled, it:

- reads a key range such as `20-21` from the native search box;
- keeps dungeons whose next upgrade level falls inside that range;
- sorts the remaining listings by their target level and dungeon;
- shows the character's next upgrade level beside every remaining listing;
- uses +2 for dungeons without a completed seasonal key;
- excludes groups that already contain the logged-in character's class.

Enter the level range you are currently browsing, for example `20-21`, then enable `KIC +1`. The game restricts the results to that range, while the addon keeps and sorts the dungeons with an upgrade target in it. A `CÉL +21` badge shows the required level. With an exact range such as `20-20`, every returned listing has a known level, so an actual upgrade is marked with a green row and an `UPGRADE +20` badge.

World of Warcraft does not expose each listing's exact key level to addons as a readable result field. In a multi-level range, compare the `CÉL +N` badge with the key level visible in the listing title; the addon cannot distinguish a `+20` row from a `+21` row inside the same `20-21` search.

Premade Groups Filter is supported as an optional dependency. When both addons are installed, KIC PGF Upgrade applies its rules after the active Premade Groups Filter rules.

## Usage

Open **Group Finder > Premade Groups > Dungeons**, enter a range such as `20-21`, and click **KIC +1**.

The filter can also be controlled with:

```text
/kicupgrade
/kicupgrade on
/kicupgrade off
```

## Installation

Copy the `KIC-PGFUpgrade` folder into the World of Warcraft Retail `Interface/AddOns` directory.
