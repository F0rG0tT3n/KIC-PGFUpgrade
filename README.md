# KIC PGF Upgrade

KIC PGF Upgrade adds a `KIC +1` toggle to the Retail World of Warcraft Premade Group Finder dungeon search.

When enabled, it:

- shows the character's next upgrade level beside every Mythic+ listing;
- uses +2 for dungeons without a completed seasonal key;
- excludes groups that already contain the logged-in character's class.

World of Warcraft does not expose a listing's key level to addons as a readable result field and prevents addons from filling the native search box. KIC PGF Upgrade therefore leaves the search box empty and places a `TARGET +21` style badge beside each listing. Compare that badge with the visible key level in the listing title; no key range needs to be entered.

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
