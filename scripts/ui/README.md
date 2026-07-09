# UI Scripts

UI scripts live here. These are usually attached to `Control` or `CanvasLayer`
nodes and should focus on displaying state, not owning gameplay state.

Folders:

- `hud/`: in-game HUD widgets, such as the channel bar.
- `inventory/`: inventory and equipment UI.
- `nameplates/`: world-space nameplates above characters and targets.
- `auth/`: first-pass sign-in and account creation screens.
- `chat/`: in-game chat display and text entry.

GDScript notes:

- `Control` nodes use anchors, offsets, containers, and theme overrides.
- `CanvasLayer` draws UI independently of the 3D world camera.
- UI should listen to gameplay signals or call narrow commands, not duplicate
  inventory, combat, or gathering rules.

If a UI script starts owning gameplay data, move that data into a gameplay
module and let the UI mirror it.
