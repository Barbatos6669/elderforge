# Decisions

Last updated: 2026-07-16

Use this as the short architecture and product decision log. Add entries when a
choice changes how future work should be done.

## Active Decisions

- Project memory lives in docs. Keep `docs/PROJECT_STATE.md`,
  `docs/DECISIONS.md`, and `docs/NEXT_TASK.md` updated so future sessions do
  not rely only on chat history.
- The full-screen master menu is the main UI hub. New gameplay panels should be
  routed through it unless there is a strong in-world reason not to.
- Old direct inventory/menu buttons and the old `I` inventory toggle are being
  retired in favor of the master menu.
- Use data catalogs or resources for expandable game content. UI should read
  recipes, creature entries, item definitions, and lore from data-shaped APIs
  rather than hardcoding every entry inside scene scripts.
- Crafting recipes currently live in
  `scripts/crafting/crafting_recipe_catalog.gd`. This is acceptable for the
  prototype, but the catalog should stay easy to migrate to `.tres`, JSON, or a
  database-backed format later.
- Silverneedle Pine is the intended tier 1 magical starter tree. It should be
  common enough for new players, but lore-rich enough to teach that basic
  resources matter.
- Moonchalk Rock is the intended tier 1 rock identity.
- Account login should require a real username and password plus the playtest
  code. Guest login was removed so every playtester can have a persistent
  profile.
- Player order should be tracked for nostalgia and possible future rewards.
- SQLite is acceptable for the current playtest database. Design table access
  and migrations so the project can move to Postgres or a service-backed
  database later if the player count grows.
- Azure is the current remote playtest hosting direction. Do not commit secrets,
  private keys, server passwords, or playtest codes to the public repo.
- Character equipment visuals should be item-driven and slot-driven. Equipping a
  different tier or item should instantiate that item's configured visual model.
- Character outfits currently keep the base head visible by clipping full-body
  base meshes with a material. This preserves user customization while avoiding
  visible body overlap under clothes.
- Preserve Blender source files for models that are likely to be redesigned.
  Runtime `.glb` files should be exports, not the only source of truth.
- Prefer custom low-poly, toon-styled assets over large imported asset packs for
  the core game identity.
- Keep imported packages organized and remove unused imports when they make the
  project harder to navigate.
- Gameplay systems should be multiplayer-ready by default. New combat,
  gathering, loot, appearance, and animation changes should consider what other
  clients need to see.
- Combat damage should flow through typed `DamageRequest`, `DamageResolver`, and
  `DamageResult` objects. Defense mitigation belongs in the shared resolver, not
  in UI scripts or one-off ability code, and public/PvP/reward-sensitive combat
  must validate attack intent, range, timing, and stats on the server.

## Open Decisions

- Final data format for long-term content catalogs: Godot resources, JSON,
  SQLite tables, or a mixed approach.
- Final character body strategy for outfits: shader clipping, separated body
  parts, skeleton-attached clothing, or a hybrid.
- Final scope of the first public demo: gathering/crafting loop only, or
  gathering plus combat, loot, and character customization.
- Final lore names for every tier of raw and refined resources.
- Final release/update cadence for the launcher and playtest server.
