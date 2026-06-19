# DIM Power Search Helper

The userscript adds a small panel to DIM with these searches:

- Trash unlocked equipment below the selected power while protecting Tier 4 and
  Tier 5 gear, Keep/Favorite tags, and locked items.
- Find unlocked infusion material at or above the selected power, plus currently
  equipped gear below that power that the player may want to level up.
- Find existing `infuse` tags below the selected power for removal while
  protecting Tier 4 and Tier 5 gear.
- Move unequipped gear outside the vault and postmaster back to the vault.
- Find duplicate weapons while excluding Favorite-tagged copies.
- Find non-Exotic armor below Tier 4 while protecting only Favorite-tagged gear.
- Find non-Exotic armor below Tier 5 while protecting only Favorite-tagged
  armor.
- Find non-Exotic Tier 3 armor with no duplicate copy so it can be reviewed for
  Archive tagging.
- Find duplicate armor while excluding Favorite-tagged and Archive-tagged copies.
- Find archived Tier 1-3 gear that has another copy for replacement review.
- Find weapons with missing catalysts.
- Find weapons with unfinished catalysts.
- Find crafted weapons below level 17.

All review searches exclude green/Uncommon gear with `-is:uncommon`. Weapon and
general equipment review searches also exclude Ergo Sum with
`-exactname:"Ergo Sum"`. The unequipped-gear movement search intentionally
includes both so they can still be returned to the vault.

The `archive` tag means the item is intentionally retained until a higher-tier
replacement drops. Trash, infusion-candidate, and duplicate-review searches
therefore exclude `tag:archive`. The infusion-tag cleanup search does not exclude
Archive gear, allowing an accidental `infuse` tag to be found and removed.

The archived-replacement search uses `is:dupe tag:archive tier:<=3`. DIM can
confirm that another copy exists, but its search language cannot confirm that the
other copy has a higher tier. Compare the copies before removing the Archive tag.

The script accepts power values from 1 to 9999 and attempts to detect a
maximum-power number displayed by DIM. If it
cannot find one, enter the threshold once in the panel. The number is remembered
for later visits.

Tampermonkey checks the published GitHub copy for updates. New releases are
installed when the userscript version number increases.

Automatic detection reads the number directly associated with DIM's `Account
Power` label. It intentionally ignores individual item power values, even when
one of those items has a higher number.

Only the three power-based searches require a valid power value. The movement,
duplicate, catalyst, and crafted-level searches remain available without one.

DIM's `tier:` filter refers to the newer Tier 1 through Tier 5 gear-quality
system. It is separate from item rarity filters such as `rarity:legendary` and
`rarity:exotic`. The cleanup searches use `-tier:>=4` to protect Tier 4 and
Tier 5 gear without excluding legacy items that do not have a gear tier.

The script only fills DIM's search box. It does not tag, move, lock, unlock, or
dismantle items automatically.

Use the full-width **Hide Helper** button to collapse the panel into a small
**Show DIM Helper** button. The hidden or visible state is remembered across DIM
reloads.
