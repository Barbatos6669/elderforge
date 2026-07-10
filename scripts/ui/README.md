# UI Scripts

UI scripts live here. These are usually attached to `Control` or `CanvasLayer`
nodes and should focus on displaying state, not owning gameplay state.

Folders:

- `elderforge_ui_style.gd`: shared color, layer, panel, button, tab, label, and
  progress-bar style helpers. New HUD/panel scripts should use this before
  creating local `StyleBoxFlat` helpers.
- `hud/`: in-game HUD widgets, such as the channel bar.
- `inventory/`: inventory and equipment UI.
- `menu/`: fullscreen master menu and submenu navigation.
- `nameplates/`: world-space nameplates above characters and targets.
- `auth/`: first-pass sign-in and account creation screens.
- `chat/`: in-game chat display and text entry.

GDScript notes:

- `Control` nodes use anchors, offsets, containers, and theme overrides.
- `CanvasLayer` draws UI independently of the 3D world camera.
- `preload("res://scripts/ui/elderforge_ui_style.gd")` gives a script access
  to the shared `ElderforgeUiStyle` constants and static helper functions.
- UI should listen to gameplay signals or call narrow commands, not duplicate
  inventory, combat, or gathering rules.

If a UI script starts owning gameplay data, move that data into a gameplay
module and let the UI mirror it.
