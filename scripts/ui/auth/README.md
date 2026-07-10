# Auth UI Scripts

The auth UI is the first screen players see before controlling the character.

- `auth_panel.gd`: builds the sign-in/create-account panel, blocks world input
  while visible, asks for the playtest code, and passes only the code hash into
  the prototype network session. It does not ask for a character name.
- `character_selection_screen.gd`: lets signed-in accounts choose one of their
  saved characters before entering the world. Accounts are capped at three
  characters for the current prototype.
- `character_customization_screen.gd`: creates a new character slot and stores
  that character's name and appearance on the account.

GDScript notes:

- `extends CanvasLayer` keeps the panel drawn over the world camera.
- `call("method_name", value)` is used for loose coupling between UI and
  gameplay scripts.
