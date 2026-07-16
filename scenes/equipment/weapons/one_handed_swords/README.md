# One-Handed Sword Scenes

`OneHandedSwordPlaceholder.tscn` is the first visible combat weapon. It is made
from lightweight Godot primitive meshes so combat can be tested before final
weapon art exists.

The prefab's local origin sits inside the grip. Keep that origin stable when
replacing the placeholder with a project-owned GLB; the attachment profile can
then handle small item-specific adjustments without moving the player's hand
socket.

Important pieces:

- `GripPoint` documents the intended hand origin.
- `HitPoint` marks the approximate end of the blade for future trails and VFX.
- `Blade` and `BladeTip` receive the item's tier color through
  `TierTintedEquipment`.
- `assets/models/equipment/attachments/one_handed_sword_main_hand.tres` owns
  the local hand offset and rotation.
- `assets/animations/equipment/one_handed_sword_animation_profile.tres` owns
  the sword stance, sword-safe jog pose, and basic attack clip.

All sword tiers currently share this placeholder scene. Only the T1 sword is
seeded in the battle arena; final tier models can later use a `%d` scene path
template in `assets/items/families/weapons/one_handed_sword.tres`.
