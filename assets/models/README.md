# Model Source Index

Gameplay models that we expect to redesign should have editable source art and a
stable runtime export.

Current source-backed model groups:

- `assets/equipment/tools/`: tiered gathering tool `.blend` sources, GLBs,
  animation source files, and attachment profiles.
- `assets/equipment/weapons/one_handed_swords/`: tiered one-handed sword
  `.blend` sources and GLBs.
- `assets/models/resources/`: tiered resource node `.blend` sources and GLBs.
- `assets/models/refining_stations/`: tiered refining/crafting station
  `.blend` sources and GLBs.
- `assets/models/props/`: source-backed world props such as city ruins,
  landmarks, and reusable set dressing.
- `assets/models/environment/`: environment art libraries and reusable
  world-building packs. This can include third-party CC0 assets; when practical,
  convert them into the same editable source plus stable runtime export workflow
  used by our original models.

The normal art workflow is:

1. Open the tier's `.blend` file from `source/`.
2. Edit the model.
3. Export over the matching `.glb` in `models/`.
4. Keep gameplay scenes and item definitions pointing at stable scene/resource
   paths so art can change without breaking code.

Source folders that contain Blender files can include `.gdignore`; that is
intentional. Godot should import runtime GLBs, not the editable source files.
