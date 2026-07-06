# Loot Scripts

Loot scripts handle the first combat reward loop.

- `loot_dropper_3d.gd` is a small component that rolls loot and spawns world scenes. Enemy AI calls it after death. Items go into a loot bag, while silver/gold can use a separate ground-drop scene.
- `loot_container_3d.gd` lives on spawned loot scenes. It stores item ids, quantities, silver, and gold, then transfers those rewards into `PlayerInventory`.
- `currency_pickup_3d.gd` is for silver/gold ground drops. It auto-collects
  when a player enters pickup range and does not open the loot window.

GDScript notes:

- `@export var loot_bag_scene: PackedScene` exposes a scene slot in the Godot Inspector.
- `call("method_name", args...)` is dynamic dispatch. We use it here so loot can talk to inventory-like nodes without hard-coding one class.
- `Variant` means the value can be different runtime types. `_normalize_items()` checks the shape before trusting it.
