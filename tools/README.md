# Tools

Project automation lives here.

- `art/`: lightweight image/texture generation helpers.
- `blender/`: optional Blender-side material, shader, and mesh-generation
  helpers for asset work.
- `build_windows_playtest.ps1`: exports the Windows playtest build, writes the
  server config, creates the version manifest, and packages the auto-updating
  playtest client.
- `playtest_client/`: source files for the tiny Windows updater that testers can
  download once and use for future playtest updates.
- `tests/`: focused headless Godot regression checks. Combat authority work
  should at minimum run `combat_damage_resolver_test.gd`,
  `weapon_ability_test.gd`, and `mob_damage_resolver_test.gd`.

The old Blender/GLB and prefab-generation folders were removed with the
imported-mesh cleanup. Add new tool folders only when the workflow is active
again.
