# Auth Scripts

Authentication starts here while the project is still local/direct-connect.

- `prototype_auth_session.gd`: stores throwaway local accounts in `user://` and
  emits the signed-in display name used by the nameplate, HUD, and multiplayer
  test panel. It now writes account, password hash, and appearance data through
  `/root/PlayerDatabase`, while still migrating older
  `user://prototype_accounts.json` saves. It also carries the playtest server
  address and playtest access code hash from the sign-in UI into the world
  scene.

GDScript notes:

- `signal signed_in(...)` lets UI react without hard-coding every consumer into
  the session object.
- `Dictionary` is Godot's key/value container. Here it mirrors simple JSON
  account data.
- `user://` is Godot's writable per-user app data folder, not the project repo.
- `get_node_or_null("/root/PlayerDatabase")` reads the persistence autoload.
  The null check keeps editor-only scenes from crashing if the autoload changes.

Do not treat this folder as production security. Real MMO auth should be
server-owned, token-based, and never trust client-side account files.
