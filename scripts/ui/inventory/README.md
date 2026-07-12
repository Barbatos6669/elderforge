# Inventory UI Scripts

This folder contains the prototype inventory and equipment UI. Most player
inventory browsing is moving into the fullscreen master menu, but the old
`InventoryPanel` still acts as the temporary drag/drop companion for loot
windows.

Files:

- `inventory_panel.gd`: companion inventory window. Its old `I` key toggle has
  been removed, but playable levels still instance it hidden so loot windows can
  open it beside themselves for drag/drop transfers.
- `equipment_panel.gd`: equipped gear slot layout, selection state, and gear
  drop routing.
- `equipment_slot_button.gd`: Godot drag/drop hooks for one equipped gear slot.
- `equipment_slot_icon.gd`: code-drawn placeholder icons for empty gear slots.
- `inventory_item_icon.gd`: code-drawn item card frame, tier background,
  bitmap item art lookup, and quantity text. Item family data controls the
  `icon_id`; this renderer maps that id to a texture in `assets/ui/inventory/`.
- `inventory_slot_button.gd`: Godot drag/drop hooks for one bag slot button.

GDScript notes:

- UI nodes are built with `Control`, `PanelContainer`, `GridContainer`,
  `VBoxContainer`, and similar Godot UI classes.
- Drag/drop methods return and accept `Dictionary` payloads. Loot rows send an
  `elderforge_loot_item` payload that inventory slots use to pull from the
  source loot container.
- The companion `InventoryPanel` calls `PlayerInventory.move_or_swap_slots(...)`,
  `equip_from_slot(...)`, and `unequip_to_slot(...)`; it does not own the
  authoritative slot data.
- The Stats tab reads from `PlayerStats`. `stats_path` can point at a specific
  node, and the panel falls back to the `player_stats` group for dropped-in
  player prefabs.

Use this folder as reference while building the new fullscreen inventory.
Change `scripts/inventory/` when item ownership rules change.
