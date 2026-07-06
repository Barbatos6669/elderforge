# Equipment Source Contract

Equipment that we expect to redesign later should have editable Blender source
beside its runtime export. Do not leave redesignable gear as Godot-only mesh
nodes unless it is a throwaway UI/debug shape.

Tier folder contract:

- `source/`: editable `.blend` files.
- `models/`: exported runtime `.glb` files referenced by Godot scenes.
- `textures/`: baked or hand-painted textures.
- `materials/`: tier-specific material resources or notes.
- `vfx/`: particles, trails, glows, and impact visuals.
- `icons/`: tier-specific inventory art when needed.

Godot item definitions should point at stable scene paths under `scenes/`, and
those scenes should point at exported GLBs. Artists can then edit a `.blend`,
export over the matching `.glb`, and keep gameplay references intact.
