# Project State

Last updated: 2026-07-11

This file is the current high-level memory for Elderforge. Keep it short enough
to scan before making changes, and update it whenever a feature, architecture
choice, or playtest flow changes.

## Current Playtest Shape

- Godot starts from `scenes/world/starting_city/StartingCity.tscn`.
- `StartingCity.tscn` inherits from `scenes/levels/PlayableLevelShell.tscn`.
- The level shell owns common playtest setup: player, camera, UI, lighting,
  atmosphere, ground, debug grid, inventory hooks, refining/crafting windows,
  loot UI, and multiplayer helpers.
- Azure is the current remote playtest target. Playit was useful for local
  tunnel testing, but it is not the main hosting path.
- Public releases should be made through the launcher/update flow, not by asking
  testers to manually swap loose files.

## Active Systems

- Account flow: sign-in uses username, password, and playtest code. Guest login
  has been removed by design. Character selection/creation is the intended path
  after account login.
- Character creation: supports body type, skin color, hair style, and hair
  color. The preview should use gameplay-style lighting and idle pose.
- Player: click-to-move, hold-to-move, stop key, follow camera, zoom, target
  selection, auto attack, death, respawn, nameplate, stats, traits, equipment
  visuals, outfit visuals, and gathering.
- UI: the full-screen master menu is the long-term hub. Press Enter to open it.
  Old direct top-right inventory/menu buttons and the old `I` inventory flow are
  being phased out.
- Master menu: top status strip, main category buttons, hover-selected submenus,
  recent-entry timeline, and detail pages for category content.
- Crafting menu: reads from `scripts/crafting/crafting_recipe_catalog.gd` and
  shows craftable items, ingredients, and lore/details in the standard
  three-panel layout.
- Inventory and economy: stackable items, tool items, drag/drop slots, silver,
  gold, carried weight, and inventory capacity exist in prototype form.
- Gathering: tree, rock, ore, and fiber resource nodes use tier rules, tool
  requirements, channel bars, depletion, and replenishment. Tier 1 can be
  gathered without a tool at a slower rate.
- Refining/crafting stations: sawmill, stone refining, smelting, cloth, leather,
  toolmaking, and weapon crafting prototypes exist.
- Combat and creatures: hostile mobs, rats, health, damage text, death, respawn,
  loot, and skinning exist in prototype form.
- Visual style: custom low-poly assets, toon materials, black outline option,
  simplified lighting, and atmosphere particles are the preferred direction.
- Blender workflow: keep editable `.blend` sources near exported runtime files
  when possible. User-authored custom meshes should be preserved and treated as
  source assets.

## Recent Important Changes

- Added a crafting recipe catalog and connected it to the master menu crafting
  page.
- Added shader clipping support so full-body base meshes can keep the head
  visible while outfits cover the body. This is used by both gameplay visuals
  and the character creation preview.
- Added `scripts/crafting/README.md` to keep the new crafting folder explainable
  for junior contributors.

## Known Risks

- The worktree may contain user edits and generated imports. Do not broadly
  revert or clean files unless the user explicitly asks.
- Multiplayer still needs hardening. Resource depletion, creature combat,
  animation state, loot, and player appearance should be treated as networked
  systems when changed.
- The outfit/head masking path is a practical bridge. Long term, separated body
  sections or explicit body masks will be easier to tune than shader clipping.
- Some item/resource names may still need final lore alignment. Check
  `docs/lore/RESOURCE_NAME_ALIGNMENT.md` before renaming player-facing items.
- The master menu is still being migrated from placeholder panels to real data.
  Keep new UI work compatible with that direction.
- Performance can be affected quickly by lighting, outlines, particles, and
  imported meshes. Prefer simple materials and low-poly assets for playtests.

## Verification Habits

Run these before committing significant code changes:

```powershell
git diff --check
```

Load key scenes headless when touching player, UI, character creation, or shared
level setup:

```powershell
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://scenes/world/starting_city/StartingCity.tscn --quit-after 1
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://scenes/player/Player.tscn --quit-after 1
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://scenes/ui/auth/CharacterCustomizationScreen.tscn --quit-after 1
```

Only update the remote server, launcher manifest, or GitHub release when the
user explicitly asks for a live playtest update.
