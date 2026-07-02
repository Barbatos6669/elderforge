# Player Equipment Scripts

This folder owns player-side equipment visuals. Inventory state still lives in
`scripts/inventory/`; these scripts only decide what should appear on the
character model.

Files:

- `equipment_attachment_profile.gd`: item-specific local transform data used
  when a tool, weapon, or armor piece needs its own socket offset.
- `equipment_socket_3d.gd`: named character socket, usually on a skeleton bone,
  that receives visible equipped prefabs.
- `player_equipment_visuals.gd`: listens to `PlayerInventory.equipped_slots_changed`
  and spawns equipped item prefabs into the matching `EquipmentSocket3D`.
- `tier_tinted_equipment.gd`: optional prefab helper that tints named mesh
  pieces, such as an axe blade, from the equipped item's tier color.

GDScript notes:

- `BoneAttachment3D` is a Godot node that follows a named skeleton bone.
- A socket's `slot_id` must match the item definition's `equip_slot`.
- `NodePath` exports let scenes point this module at an inventory or skeleton
  without hard-coding every scene layout.
- The equipped item scene path comes from `ItemDefinition.equipment_scene_path`.
- Attachment profile paths come from
  `ItemDefinition.equipment_attachment_profile_path`.
- Equipped prefabs can define `apply_equipment_display_data(slot_data)` when
  they need item-specific visuals. `TierTintedEquipment` uses this to recolor
  only named blade meshes while keeping handles and wraps unchanged.
- `MainHandAttachment/MainHandPreview` is visible under the character skeleton
  in `Player.tscn` for editor tuning, then hidden at runtime so it does not
  appear unless the item is actually equipped.

Tune the visible `MainHandPreview` transform in `Player.tscn` when an equipped
item needs grip alignment. It is a child of the same `MainHandAttachment` as the
runtime item, so `PlayerEquipmentVisuals` can copy its local transform exactly.
The numeric `main_hand_item_*` fields are fallback values for scenes that do not
provide a preview node.
