# Rat

This folder contains the first imported animal placeholder.

Files:

- `Rat.glb`: rat model copied from the local `godot packages/Animals` folder.
- `Rat.glb.import`: Godot import metadata.

Imported clips currently used by `scenes/entities/animals/Rat.tscn`:

- `RatArmature|Rat_Idle`
- `RatArmature|Rat_Walk`
- `RatArmature|Rat_Death`

The prefab is a T1 skinnable animal. While alive it is attackable; after death
the corpse yields `hide_t1`.

Before a public asset release, confirm and document the source asset license in
this folder.
