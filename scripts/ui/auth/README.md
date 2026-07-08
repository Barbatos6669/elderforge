# Auth UI Scripts

The auth UI is the first screen players see before controlling the character.

- `auth_panel.gd`: builds the sign-in/create-account panel, blocks world input
  while visible, and pushes the signed-in character name into the player
  nameplate, HUD, and multiplayer test manager. It also asks for a playtest code
  and passes only the code hash into the prototype network session.

GDScript notes:

- `extends CanvasLayer` keeps the panel drawn over the world camera.
- `@export var player_path: NodePath` exposes node wiring in the Inspector.
- `call("method_name", value)` is used for loose coupling between UI and
  gameplay scripts.
