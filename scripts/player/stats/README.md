# Player Stats Scripts

This folder stores player stat values and metadata.

Files:

- `player_stats.gd`: current player stat ids, display labels, and numeric
  values. Most values intentionally start at zero, with explicit base stats
  such as Auto-Attack Damage, Max Health, Max Energy, and regeneration layered
  on top.

GDScript notes:

- Stats are stored in dictionaries so systems can query by id.
- `reset_to_base_values()` zeroes every tracked stat first, then applies
  `BASE_STAT_VALUES`. Use `reset_all_to_zero()` only when you truly need a blank
  sheet for tests or editor tooling.
- This is state storage, not yet final formula logic.
- Health regeneration is applied by the player's `CombatHealth` node. Energy
  regeneration is tracked here and mirrored by the player's `Mana` resource pool
  until we have final formulas.
- `persist_to_player_database` saves/restores signed-in account stat values
  through `/root/PlayerDatabase`. Keep formula work separate so persistence only
  stores the resulting values, not every temporary modifier.
- Later equipment, buffs, food, mounts, and server data should write modifiers
  into this system.

Use this folder when adding new tracked player stats or stat lookup helpers.
Keep combat, inventory, and UI-specific calculations in their own modules until
we have a real stat formula layer.
