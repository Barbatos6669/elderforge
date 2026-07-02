# Player Stats Scripts

This folder stores player stat values and metadata.

Files:

- `player_stats.gd`: current player stat ids, display labels, and numeric
  values. Most values intentionally start at zero.

GDScript notes:

- Stats are stored in dictionaries so systems can query by id.
- This is state storage, not yet final formula logic.
- Later equipment, buffs, food, mounts, and server data should write modifiers
  into this system.

Use this folder when adding new tracked player stats or stat lookup helpers.
Keep combat, inventory, and UI-specific calculations in their own modules until
we have a real stat formula layer.
