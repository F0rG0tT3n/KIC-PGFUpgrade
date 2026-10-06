# KIC PGF Upgrade

KIC PGF Upgrade adds a `KIC +1` toggle to the Retail World of Warcraft Premade Group Finder dungeon search.

When enabled, it:

- reads a key range such as `20-21` from the native search box;
- keeps dungeons whose next upgrade level falls inside that range;
- sorts the remaining listings by the group leader's Mythic+ score, highest first;
- marks guaranteed upgrades in exact, single-level searches;
- uses +2 for dungeons without a completed seasonal key;
- excludes groups that already contain the logged-in character's class.

Enter the level range you are currently browsing, for example `20-21`, then enable `KIC +1`. The game restricts the results to that range, while the addon keeps the dungeons with an upgrade target in it and puts the groups with the highest leader Mythic+ score first. With an exact range such as `20-20`, every returned listing has a known level, so an actual upgrade is marked with a green `[UPGRADE +20]` badge.

World of Warcraft does not expose each listing's exact key level to addons as a readable result field. The addon can filter and sort upgrade dungeons in a multi-level range, but it only displays the `[UPGRADE +N]` badge for a single-level search where the result level is guaranteed.

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
