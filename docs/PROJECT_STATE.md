# Project State

Last updated: 2026-07-16

This file is the current high-level memory for Elderforge. Keep it short enough
to scan before making changes, and update it whenever a feature, architecture
choice, or playtest flow changes.

## Current Playtest Shape

- Godot starts from `scenes/bootstrap/SignInGateway.tscn`, then routes signed-in
  accounts through character selection or creation before entering
  `scenes/world/starting_city/StartingCity.tscn`. Dedicated servers skip the UI
  and enter the game scene directly.
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
  selection, auto attack, equipment abilities, death, respawn, nameplate, stats,
  traits, equipment visuals, outfit visuals, and gathering.
- UI: the full-screen master menu is the long-term hub. Press Enter to open it.
  Old direct top-right inventory/menu buttons and the old `I` inventory flow are
  being phased out. Persistent gameplay HUD uses a shared nine-zone grid so
  status, clock, notices, chat, channeling, abilities, and map cannot overlap.
  The gameplay HUD reserves eight responsive circular bottom-center spell slots
  (`Q`, `W`, `E`, `R`, `D`, `F`, `1`, `2`). Weapons own Q/W/E, chest armor owns
  R, helmets own D, boots own F, and weapon passives do not consume a cast key.
- Master menu: top status strip, main category buttons, hover-selected submenus,
  recent-entry timeline, and detail pages for category content. The Inventory
  detail page now reads `PlayerInventory` directly for bag slots, equipped gear,
  carried weight, currency, and selected item details.
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
- Combat and creatures: player and mob basic attacks share a wind-up, impact,
  and recovery contract. The one-handed sword now supplies a targeted Q spell
  with approach, authored impact, a five-second cooldown, HUD feedback, and
  remote animation playback. Leather helmet supplies an instant D absorb shield
  with missing-energy restoration, and leather boots supply a directional F
  dodge with cursor aiming, collision-aware movement, and the imported Roll
  animation. Typed damage requests/results now flow through a shared
  `DamageResolver` for armor, magical resistance, and true-damage handling.
  Player auto-attacks, player equipment abilities, mob basic attacks, mob
  abilities, and server-routed mob damage all use that path. Hostile equipment
  abilities show red ground telegraphs during wind-up or movement, and the
  battle arena can show orange aggro plus blue de-aggro/leash debug rings.
  The player prefab has positional sword swing,
  confirmed-hit, and non-voiced hurt sounds supplied by a swappable combat
  sound set. Confirmed local and replicated damage also drives a reusable
  low-poly blood burst. Hostile mobs, rats, health, damage text, death,
  respawn, loot, and skinning exist in prototype form.
- Equipment: the first one-handed sword item now has a Godot-native placeholder
  visual, a separate right-hand attachment profile, and a data-driven animation
  profile. The combat arena equips T1 automatically for isolated testing.
- Visual style: custom low-poly assets, toon materials, black outline option,
  simplified lighting, and atmosphere particles are the preferred direction.
- Blender workflow: keep editable `.blend` sources near exported runtime files
  when possible. User-authored custom meshes should be preserved and treated as
  source assets.

## Recent Important Changes

- Matched the battle-arena mob baseline to player base stats, added reusable
  hostile ability telegraphs, and exposed live aggro and de-aggro/leash rings
  for combat tuning. Focused tests cover mob stats, telegraphs, and arena
  equipment loadouts.
- Added the first shared damage resolver pass. Damage requests now carry
  physical, magical, or true damage type metadata; results report requested,
  mitigated, and applied damage plus the defense used. Armor and magical
  resistance reduce incoming damage, all current player and mob impact paths
  use the shared pipeline, and the playtest server wraps reported mob damage
  through the same resolver while trusted client reports are being replaced.
- Added the shared three-by-three gameplay HUD contract. Persistent widgets now
  declare a stable zone, clip to its bounds, and reflow at compact resolutions
  to reduce overlap.
- Moved the fullscreen master menu Inventory page beyond placeholder text. It
  now renders a real bag-slot grid, equipment-slot grid, currency/weight
  readouts, and spell loadouts from `PlayerInventory`. Gear can be dragged
  between the bag and its compatible equipment slot to equip, unequip, or swap
  it. The right panel presents the selected item's tier-gated spell choices,
  grouped by action key, persisted by item id, and rebound into combat
  immediately when changed. Weapons always expose independent Q, W, and E
  categories as horizontal circular icon rows, including dim sockets for locked
  or currently empty categories.
- Expanded the equipment ability HUD to eight stable circular slots. Equipped
  items bind through one canonical ownership contract: weapon Q/W/E, chest R,
  helmet D, boots F, plus two future utility placeholders. The sword supplies Q,
  leather chest supplies R, leather helmet supplies D, and leather boots supply
  F today.
- Added the first helmet equipment spell. Energizing Shield is an instant D
  self-cast that grants an 834-point absorb shield for three seconds, restores
  25% of missing energy, starts a 21.14-second cooldown, and reuses the shield
  bubble visual while the finite absorb pool is active.
- Added the first directional equipment spell. Dodge Roll previews a gold
  ground arrow without rooting locomotion, confirms with left-click, keeps
  right-click movement available, cancels with Escape, plays the UAL1 `Roll`
  clip, and continuously refreshes held movement so locomotion resumes on the
  first frame after its collision-aware forced motion. Activating it also
  grants `0.8` seconds of damage immunity with a synchronized shield bubble.
- Added the first CC0 combat sound set. Swing cues follow attack starts, weapon
  impacts follow landed signals, and body impacts follow actual health loss so
  repeated clicks cannot produce false hit audio.
- Added reusable blood-impact feedback to players, humanoid mobs, training
  targets, and rats. It shares the confirmed `damage_taken` path with floating
  damage numbers, including replicated mob damage.
- Added the first data-driven weapon spell. `Sword Slash` is supplied by the
  equipped one-handed sword, chains UAL2 `Sword_Regular_A` into `Sword_Regular_A_Rec`,
  lands at its authored contact point, and appears in a bottom-center Q slot
  with a radial five-second cooldown.
- Added `Whirling Slash` on the sword's W slot. Its downloaded Mixamo motion is
  retargeted to the Elderforge skeleton, converted to an in-place 1.8-second
  spin, and lands late for 80 base physical damage plus 150% attack damage.
  Sword-equipped mobs bind and use the same W spell when Q is unavailable.
- Added stable ability-id multiplayer events so remote players see weapon spell
  animations while the existing playtest combat-state path synchronizes mob
  damage.
- Added equipment-aware idle, movement, and attack animation selection. The
  first sword now uses `Sword_Idle`, the UAL1 `Sword_Attack` diagonal slash,
  and a sword-safe jog that blends its right-arm pose over the normal leg
  locomotion. Its profile synchronizes blade contact, damage, and floating hit
  text at `0.49` of the attack cycle, matching the downward blade contact.
- Connected the existing one-handed sword item family to a visible placeholder
  weapon and seeded it only in the battle test arena.
- Added `scenes/debug/combat/BattleTestArena.tscn` as a direct-run combat
  sandbox with stationary training targets and standard, fast, and heavy
  hostile variants.
- Re-enabled the shell-owned gameplay map and UTC clock in the battle arena,
  and fitted the map bounds to the complete rotated arena. HUD layers remain
  level-shell owned so multiplayer player prefabs cannot create duplicate UI.
- Reworked basic melee timing around `scripts/combat/attack_timeline.gd`.
  Damage now lands at the impact frame, range is revalidated, recovery survives
  stop/re-click orders, and remote clients receive attack-start visuals.
- Hardened repeated auto-attack playback against same-frame animation completion
  races, so a previous sword swing can no longer cancel the next visual cycle.
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
- Mob damage still starts from an attacking-client report in the playtest
  build, although the server now clamps and resolves it through the shared
  damage pipeline. Move attack intent, range/timing validation, stat-derived
  damage, and final reward authority fully to the server before adding PvP or
  treating combat rewards as secure.
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
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/combat_damage_resolver_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/weapon_ability_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/mob_damage_resolver_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/mob_equipment_ability_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/mob_base_stats_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/mob_ability_telegraph_test.gd
C:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/tests/battle_arena_mob_loadout_test.gd
```

The battle-arena loadout test currently emits dummy-renderer material warnings
in headless mode, but it should still print its pass message and exit with code
zero.

Only update the remote server, launcher manifest, or GitHub release when the
user explicitly asks for a live playtest update.
