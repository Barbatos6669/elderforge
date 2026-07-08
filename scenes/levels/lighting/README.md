# Level Lighting

`BasicLevelLighting.tscn` is the default lighting rig for playable levels.
Atmospheric fog and sky color are set on the shared `WorldEnvironment` inside
`scenes/levels/PlayableLevelShell.tscn`, while visible mist patches live in
`scenes/levels/atmosphere/AtmosphereField.tscn`.

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

For atmosphere, tune the `Environment_level` fog settings in
`PlayableLevelShell.tscn` and the mist patch positions/material strengths in
`AtmosphereField.tscn`.

`AtmosphereField` is hidden in `PlayableLevelShell.tscn` so the level is easier
to edit. Its `AtmosphericMist3D` script restores runtime visibility when the
game starts, controlled by the `show_in_game` export.

`WorldEnvironment` fog is also saved disabled for editor readability.
`RuntimeWorldEnvironment` restores fog during play with `fog_enabled_in_game`.
