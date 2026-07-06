# Level Lighting

`BasicLevelLighting.tscn` is the default lighting rig for playable levels.

## Contents

- `KeySun`: warm directional light with shadows. This is the main sunlight.
- `SkyFill`: cool low-energy directional light without shadows. This keeps
  characters from going too dark on the shaded side.
- `SpawnWarmth`: small warm omni light at the spawn point. This gives the first
  playtest area a little readability before a real city lighting pass exists.

## Tuning

For a quick visual pass, start with `KeySun.light_energy`, `KeySun.light_color`,
and the `KeySun` rotation. For night, caves, interiors, or city props, add more
specific lights under the level's `World/LevelContent/Lighting` folder or make a
new lighting prefab.
