# Loot UI

`loot_panel.gd` is the first-pass reward window. It opens for a `LootContainer3D`, draws currency and item rows, moves rewards into the node in group `player_inventory`, and asks `InventoryPanel` to sit beside it while looting.

`loot_item_row.gd` is the drag source for one loot row. It builds the drag payload through `LootPanel`, then the inventory slot accepts that payload and pulls the item from the loot container.

GDScript notes:

- `Button.pressed.connect(_on_take_item_pressed.bind(index))` connects a click and stores which row the button belongs to.
- `as Dictionary` is a cast. If the value is not the expected type, Godot returns `null` for object types or errors for incompatible value casts, so we normalize input data before drawing it.
- UI panels join `blocking_world_input` so world click-to-move pauses while a window is open.
