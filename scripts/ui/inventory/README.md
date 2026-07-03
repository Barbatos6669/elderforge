# Inventory UI Scripts

This folder renders the inventory and equipment UI. Inventory state lives in
`scripts/inventory/`.

Files:

- `inventory_panel.gd`: toggleable inventory window, bag slot rendering,
  details panel, currency display, bag drag/drop, and gear drag/drop forwarding.
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
- Drag/drop methods return and accept `Dictionary` payloads.
- `InventoryPanel` calls `PlayerInventory.move_or_swap_slots(...)`,
  `equip_from_slot(...)`, and `unequip_to_slot(...)`; it does not own the
  authoritative slot data.

Change this folder when the inventory should look or behave differently on
screen. Change `scripts/inventory/` when item ownership rules change.
