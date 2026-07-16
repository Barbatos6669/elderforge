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
- `armor/`: wearable equipment such as skeleton-bound leather chest pieces,
  hoods, and boots.

Common edits:

- Change tier display names in `tier_names`.
- Add real lore or gameplay identity with `tier_descriptions`.
- Change the inventory art lookup with `icon_id`.
- Change stack size with `max_stack`.
- For tools and weapons, change the hand model path with
  `equipment_scene_path_template`. Use `%d` wherever the tier number should be
  inserted.
- For tools and weapons, change the socket offset with
  `equipment_attachment_profile_path`.
- For tools and weapons, change gathering/attack animation choices with
  `equipment_animation_profile_path_template`.
- For fitted armor, set `equipment_visual_mode` to `skeleton`, provide
  male/female paths in `equipment_scene_path_templates_by_body`, and list any
  built-in outfit mesh fragments it replaces in
  `equipment_replaces_outfit_parts`.
- Equipment abilities live in `ability_path_templates`; weapons own Q/W/E,
  chest armor owns R, helmets own D, and boots own F. The starter chest maps R
  to `moonleaf_binding.tres`, the starter helmet maps D to
  `energizing_shield.tres`, and the starter boots map F to Dodge Roll.
