# Selection Interaction Scripts

Selection scripts let world objects be selected and show a selected-target ring.

Files:

- `selectable_3d.gd`: reusable `Area3D` target with selected state,
  relationship, and relationship colors.
- `selection_feedback_3d.gd`: ground ring shown while a selectable is selected.

GDScript notes:

- `enum Relationship { FRIENDLY, HOSTILE, NEUTRAL }` creates named integer
  values.
- `signal selection_changed(is_selected: bool)` lets visuals update without the
  targeting system knowing about them.
- `match relationship:` is similar to a C++ `switch`.

Use this folder when an object needs target selection behavior that is not
specific to combat or gathering.
