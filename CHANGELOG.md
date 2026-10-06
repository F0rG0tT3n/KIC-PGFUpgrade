# Changelog

## 1.0.5

- Moved the upgrade badge to the lower-right corner of each result row so it no longer overlaps the leader's Mythic+ rating.

## 1.0.4

- Reads an exact key range such as `20-21` from the native search box.
- Keeps only dungeons whose next upgrade target falls inside the entered range.
- Sorts matching listings by target level and dungeon while retaining duplicate-class filtering.
- Marks guaranteed upgrades with a green row when a single-level range such as `20-20` is used.

## 1.0.3

- Removed the exact-range search requirement.
- Shows the calculated next upgrade level beside every Mythic+ result.
- Keeps automatic Mythic+ and duplicate-class filtering without requiring search-box input.

## 1.0.2

- Fixed the toggle position so it follows the rendered `Dungeons` title instead of the title frame's full width.
- Removed the invalid `GetKeystoneForActivity` result-level check that hid every listing.
- Uses the game's exact key-range search together with each dungeon's next upgrade target.
- Keeps Mythic+ and duplicate-class filtering active when no exact key range is entered.

## 1.0.1

- Moved the `KIC +1` toggle directly beside the native Dungeon search heading.
- Avoided overlap with Premade Groups Filter controls in the upper-right corner.

## 1.0.0

- Added a `KIC +1` toggle to the Premade Group Finder dungeon search.
- Shows only Mythic+ listings exactly one level above the character's seasonal best for each dungeon.
- Uses +2 as the target for dungeons without a completed seasonal key.
- Excludes groups that already contain the logged-in character's class.
- Supports Premade Groups Filter as an optional dependency.
