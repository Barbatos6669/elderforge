# Godot Tools

These scripts generate Godot-side scenes or resources. Python scripts run from
the project root with `python`. GDScript tools run through Godot with
`--headless --script`.

Common scripts:

- `generate_barbatos_prop_prefabs.py`: creates wrapper scenes for custom props
  under `assets/models/props/barbatos_props/`.
- `generate_fantasy_prop_prefabs.py`: creates wrapper scenes for Fantasy Props
  MegaKit runtime models.
- `generate_modular_prototyping_prefabs.py`: creates wrapper scenes for the CC0
  modular prototyping pack.
- `generate_resource_tier_scenes.py`: regenerates tiered gathering scene data
  from the current prototype pattern.
