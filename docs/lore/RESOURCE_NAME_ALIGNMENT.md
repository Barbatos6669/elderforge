# Resource Name Alignment

This file maps prototype gameplay IDs to the lore bible names players should see.
Keep IDs stable unless a migration is planned; inventory, refining, and multiplayer
state use those IDs internally.

## Hearthvale Starter Resources

| Gameplay ID | Player-facing name | Lore source |
| --- | --- | --- |
| `timber_t1` | Oak Wood I | Common strong Hearthvale wood |
| `planks_t1` | Oak Beams I | Refined Oak Wood for building and crafting |
| `stone_t1` | Clay I | Hearthvale starter construction material |
| `blocks_t1` | Clay Blocks I | Refined Clay for construction |
| `ore_t1` | Iron Ore I | Common Hearthvale mine metal |
| `ingots_t1` | Iron Ingots I | Refined Iron Ore |
| `hide_t1` | Wolf Hide I | Hearthvale starter hide resource |
| `worked_leather_t1` | Wolf Worked Leather I | Refined Wolf Hide |

## Nearby Or Later Resource Names

| Gameplay ID | Player-facing name | Notes |
| --- | --- | --- |
| `timber_t2` | Ironwood II | Blackroot Forest wood |
| `timber_t3` | Silverneedle Pine III | Frostspine mountain wood, not a Hearthvale starter |
| `ore_t2` | Copper Ore II | Hearthvale hills and shallow mines |
| `ore_t3` | Silver Ore III | Frostspine metal for undead and corrupted monsters |
| `hide_t2` | Deer Hide II | Hearthvale starter-region animal hide |

## Placeholder Systems Still Waiting On Lore Content

- The current cotton/fiber loop stays in place for cloth crafting until the lore
  bible gets a dedicated fiber plant line.
- Moonleaf, Basic Herbs, and Grave Moss are lore-correct Hearthvale alchemy
  resources, but they do not have gatherable node prefabs yet.
- The T1 tree prefab now uses the nature pack CommonTree art while keeping the
  lore-facing Oak Tree / Oak Wood I naming.
