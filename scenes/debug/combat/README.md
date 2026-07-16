# Battle Test Arena

`BattleTestArena.tscn` is a focused sandbox for tuning combat without city
buildings, gathering nodes, crafting NPCs, or resource loot getting in the way.
Open the scene and press **F6** to run it directly. It is intentionally not the
project's main scene.

## Layout

- The player starts at the quiet southern end of the arena.
- The arena equips a T1 one-handed sword without reading or modifying the
  signed-in player's saved inventory.
- Three stationary training targets test approach distance, target switching,
  sustained attacks, damage numbers, and impact timing.
- The left hostile is slow, durable, and heavy-hitting.
- The center hostile represents the current baseline enemy.
- The right hostile moves and attacks quickly but has less health.
- The side `Ability Raider` equips the starter sword, chest, helmet, and boots
  so mob equipment abilities can be tested in a live fight.
- Hostiles have a short five-second respawn and produce no loot, keeping the
  arena reusable and uncluttered.

## Tuning

Combat timing belongs to scripts rather than this scene:

- `scripts/combat/attack_timeline.gd` owns wind-up and recovery timing.
- `scripts/player/combat/player_auto_attack.gd` exposes player range and timing.
- `scripts/entities/enemy_mob_ai.gd` exposes hostile movement, aggro, attack,
  death, and respawn values.

Per-enemy health, damage, speed, aggro, leash, and respawn overrides are stored
directly on the three hostile instances in `BattleTestArena.tscn`. This makes
the arena safe to tune without changing every enemy in the game.
