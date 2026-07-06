# Item Family Data

Each `.tres` file in this folder describes one tiered item family. The runtime
catalog reads these files and creates the actual `ItemDefinition` objects.

Folders:

- `raw/`: gathered resources such as logs, stone, ore, cotton, and hide.
- `refined/`: crafted/refined materials such as planks, blocks, ingots, cloth,
  and worked leather.
- `tools/`: equippable gathering tools such as axes, hammers, pickaxes,
  sickles, and skinning knives.
- `weapons/`: equippable combat weapons such as one-handed swords.

Common edits:

- Change tier display names in `tier_names`.
- Change the inventory art lookup with `icon_id`.
- Change stack size with `max_stack`.
- For tools and weapons, change the hand model path with
  `equipment_scene_path_template`. Use `%d` wherever the tier number should be
  inserted.
- For tools and weapons, change the socket offset with
  `equipment_attachment_profile_path`.
- For tools and weapons, change gathering/attack animation choices with
  `equipment_animation_profile_path_template`.
