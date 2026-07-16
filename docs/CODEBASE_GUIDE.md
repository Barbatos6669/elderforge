# Codebase Guide

This guide is a learning map for Elderforge's current Godot prototype. Read it
when you want to understand where things live, how the player prefab works, and
where to make the next small change.

The codebase is intentionally modular. The main idea is to keep each system in
its own script or scene so the MMO can grow without turning the player
controller into one giant file.

## First Read Order

Start here if you are new to the project:

1. `project.godot` - tells Godot which scene runs first.
2. `docs/START_HERE.md` - the short orientation page.
3. `scenes/bootstrap/SignInGateway.tscn` - the normal account-flow entry scene.
4. `scenes/world/starting_city/StartingCity.tscn` - the current test world.
5. `scenes/levels/PlayableLevelShell.tscn` - the shared playable level setup.
6. `scenes/player/Player.tscn` - the reusable player prefab.
7. `scripts/player/controllers/player_controller.gd` - coordinates the player
   sub-systems.
8. `scripts/README.md` - GDScript syntax notes and the script folder map.
9. The smaller scripts under `scripts/player/` - movement, input, animation,
   audio, stats, visuals, and feedback.

## Project Entry Point

`project.godot` points the game at:

```text
res://scenes/bootstrap/SignInGateway.tscn
```

Pressing Play loads sign-in first. A successful account login routes to
character creation when the account has no character, or character selection
when it does. Entering the world then loads:

```text
res://scenes/world/starting_city/StartingCity.tscn
```

Dedicated server runs skip the account UI and enter the game scene directly.

`StartingCity.tscn` inherits from `scenes/levels/PlayableLevelShell.tscn`. The
shell contains the common playable setup:

- `WorldEnvironment` for basic lighting/background color.
- `World`, a parent node for world objects.
- `DebugGrid`, the isometric reference grid.
- `Ground`, a flat walkable plane with collision.
- `Player`, an instance of the reusable player prefab.
- `PlayerInventory`, local prototype item and currency storage.
- `InventoryPanel`, the toggleable prototype inventory UI.
- HUD, death message, refining, loot, and lighting setup.

`StartingCity.tscn` should contain map-specific objects: placed resources,
enemies, props, water, buildings, and city layout work.

This is still a prototype scene. It is useful for testing movement, camera,
click feedback, audio, and stats, but it is not the future world streaming or
zone system.

## Folder Layout

```text
assets/
  animations/       Third-party animation packs and notes.
  audio/footsteps/  Footstep sounds, source notes, and surface set resources.
  characters/base/  Current placeholder character model and texture files.
  ui/cursors/       Mouse cursor icons for resource and interaction states.

docs/
  START_HERE.md         Short navigation and current run path.
  PROJECT_STATE.md      Current playable systems, risks, and verification.
  NEXT_TASK.md          Active handoff and acceptance checks.
  CODEBASE_INDEX.md     Fast lookup index for scenes, scripts, and systems.
  CODEBASE_GUIDE.md     This file.
  COMBAT_ARCHITECTURE.md Shared combat and authority contract.
  DESIGN_BOUNDARIES.md  What we can and cannot copy from other games.
  LICENSING.md          Asset and license rules.
  ROADMAP.md            Milestones.

scenes/
  bootstrap/  Normal client entry and account-flow scenes.
  camera/    Reusable camera rig scene.
  debug/     Debug-only helper scenes.
  entities/  Prototype gameplay entities such as target dummies.
  effects/   Visual effects such as click indicators.
  gathering/ Prototype resource nodes such as trees.
  ui/        Reusable UI scenes such as inventory and nameplates.
  levels/    Shared playable level shell and level helpers.
  world/     Current demo maps, such as Starting City.
  main/      Older prototype sandbox scene kept for reference/testing.
  player/    Reusable player prefab.

scripts/
  README.md    GDScript primer and script folder map.
  audio/     Shared audio data/resources.
  camera/    Camera behavior.
  combat/    Shared timing, health, abilities, and typed damage resolution.
  debug/     Debug helper behavior.
  effects/   Effect behavior.
  gathering/ Prototype gatherable resource metadata.
  interaction/ Shared interaction helpers such as hover detection.
  inventory/ Prototype item definitions, stacks, and inventory storage.
  network/   Direct-connect playtest replication and authority boundaries.
  persistence/ Prototype account, character, inventory, and stat storage.
  player/    Player-specific systems.
  stats/     Shared entity stat and Forged Trait components.
  ui/        UI and world-space display helpers.
  visuals/   Reserved for shared visual helpers.

tools/
  tests/       Focused headless Godot regression checks.
  playtest_client/ Windows updater source.
```

Every folder under `scripts/` has a local `README.md`. Those files are meant as
junior-friendly entry points: what the folder owns, which files to open first,
and which GDScript syntax is worth knowing before editing there.

## Player Prefab

`scenes/player/Player.tscn` is the main player prefab. The goal is that this
scene can be dropped into any playable scene and work immediately.

Key current child nodes:

- `Input` reads mouse/keyboard intent.
- `Targeting` handles local click target selection.
- `AutoAttack` runs the local-player melee timeline.
- `WeaponAbilities` runs equipment-supplied targeting, casts, cooldowns,
  channels, and movement or damage effects.
- `Channeling` tracks timed actions such as gathering.
- `Gathering` handles gather target approach, channel start, and rewards.
- `Stats` stores player stat values and metadata.
- `Mana`, `Health`, and `CombatState` own combat resources and state.
- `Respawn`, `DamageNumbers`, `BloodImpact`, and `DamageImmunityBubble` own
  defeat and confirmed-damage feedback.
- `Movement` moves the `CharacterBody3D` toward a destination.
- `Facing` rotates the visual model toward movement direction.
- `VisualStyle` applies the current toon-like placeholder material style.
- `EquipmentVisuals` attaches equipped models to the character rig.
- `HoverSelectionRing` detects hover and applies the mesh outline highlight.
- `Animation` loads idle, jog, attack, and gathering animations onto the
  character model.
- `FootstepAudio` plays surface footsteps in sync with animation timing.
- `ClickFeedback` spawns the yellow click marker.
- `Visuals/BaseCharacter` is the current placeholder character model.
- `ChannelBar` renders the current channel progress.
- `CollisionShape3D` defines the player collision capsule.
- `CameraTarget` is the point the camera follows.
- `CameraRig` is the perspective isometric camera instance.
- `Nameplate` renders a temporary player name above the character.

The root `Player` node uses `scripts/player/controllers/player_controller.gd`.
That controller should stay small. Its job is to coordinate the modules, not to
own every system.

## Player Controller Flow

Every physics frame, `PlayerController` coordinates this simplified flow:

1. Advance equipment-ability state, then honor respawn, control, and full-screen
   UI locks.
2. A stop request clears movement and cancels auto-attack, active equipment
   actions, gathering, and pending world interactions.
3. Directional movement abilities temporarily own velocity while ordinary
   input can keep a follow-up destination ready.
4. Equipment slot input requests Q/W/E/R/D/F/1/2 abilities. Directional
   targeting receives aim/confirm/cancel input before standard world clicks.
5. Standard world input selects targets and starts movement, auto-attack,
   gathering, station, or loot interactions.
6. Active systems publish approach destinations; the movement motor resolves
   one movement step.
7. Facing, animation, footsteps, combat audio, and feedback follow the resolved
   movement and active target.
8. Auto-attack and ability impacts revalidate their target and range, create a
   typed `DamageRequest`, and use `DamageResolver` for mitigation and final
   health application.
9. Shared channeling advances gathering and equipment channels.

This means movement, visuals, animation, audio, and feedback can change without
rewriting the whole player controller.

## Hover Feedback

`scripts/interaction/hover/hover_feedback_3d.gd`
`scripts/interaction/cursor/cursor_override.gd`
`assets/materials/hover/hover_outline_green.tres`
`assets/materials/hover/hover_outline.gdshader`
`assets/ui/cursors/gather_tool_cursor.png`

The player prefab has a `HoverHitbox` area on a hover-only physics layer and a
`HoverSelectionRing` node. That node uses `HoverFeedback3D`, which owns the
hover test and applies the mesh outline highlight.

If the hover target has a `get_relationship_color()` method, hover feedback uses
that color for the optional mesh outline. Current convention: friendly targets
are green, hostile targets are red, and neutral/unknown targets fall back to
gold.

The hover hitbox is intentionally wider than the movement collision capsule so
the fallback raycast can hit the visible character area. `HoverFeedback3D` also
checks the projected mesh bounds of `Visuals/BaseCharacter`, and then falls
back to a projected feet-to-head body line. This keeps hover detection tied to
what the player sees on screen instead of depending only on exact physics hits.

The generated hover ring is disabled by default; selected targets use
`SelectionFeedback3D` for their persistent ground ring. Tune screen hover
padding and ray fallback on the `HoverSelectionRing` node. If feedback does not
appear, enable `force_hover` on that node to confirm hover detection and outline
behavior before tuning detection.

Gatherable resources can also set `hover_cursor_texture` on their
`HoverSelectionRing` node. The T1 Oak Tree prefab uses the gather cursor asset
so hovering a gatherable tree replaces the normal mouse pointer. Tune
`hover_cursor_hotspot` if the click point feels offset from the icon. It also
uses `unavailable_hover_cursor_texture` for the red X cursor shown when the tree
is depleted and cannot currently be gathered.

Attackable hostile targets use `hostile_hover_cursor_texture` on their
`HoverSelectionRing` node. The prototype `TargetDummy` scene assigns the red
spear cursor, and `HoverFeedback3D` only shows it when the hovered selectable
returns true from `is_hostile()`.

## Target Selection

`scripts/interaction/selection/selectable_3d.gd`
`scripts/interaction/selection/selection_feedback_3d.gd`
`scripts/player/targeting/player_targeting.gd`
`scenes/entities/TargetDummy.tscn`

Target selection is split into reusable object-side and player-side pieces:

- `Selectable3D` lives on a selectable `Area3D` hitbox, owns selected state, and
  exposes the target relationship.
- `SelectionFeedback3D` listens to a selectable and shows the
  relationship-colored selected ring with a light translucent center fill.
- `PlayerTargeting` raycasts from the active camera on left-click and selects
  the first selectable hitbox on the selection physics layer.

The player's left-click selection check runs before click-to-move. If a click
selects a target, `PlayerInput` blocks movement until the mouse button is
released so the same click does not also become a move command. Selected target
rings stay visible while that target remains selected; clicking the ground does
not clear selection, but clicking another selectable swaps the selected target.

`TargetDummy.tscn` is the older friendly/hostile test entity used by prototype
sandbox scenes so hover/selection can be checked against both relationship
colors. Its nameplate is hidden until selected, and then only shows a
relationship-colored health bar: green for friendly and red for hostile.
The visual is the same base character model used by the player, with the shared
toon material pass tinted light green for friendly and light red for hostile.
This gives us a small combat foundation before adding attacks or spells.

Change a target's friendly/hostile behavior by selecting its `Selectable3D`
node and editing `relationship` in the Inspector. The default colors are also
exported there if we need to tune the exact green, red, or neutral gold later.
Tune the selected ring fill on the `SelectedRing` node with `fill_color` and
`fill_selection_color_mix`.

## Prototype Combat

`scripts/combat/combat_health.gd`
`scripts/combat/damage_request.gd`
`scripts/combat/damage_resolver.gd`
`scripts/combat/damage_result.gd`
`scripts/player/combat/player_auto_attack.gd`
`scripts/player/combat/player_weapon_abilities.gd`
`scripts/entities/enemy_mob_ai.gd`

Combat is playable for local and trusted friend tests, with shared timing,
equipment abilities, hostile mob AI, damage feedback, death, respawn, and loot.
It is not secure server-authoritative combat yet.

- `CombatHealth` owns health, immunity, finite absorb shields, regeneration,
  damage confirmation, and defeat.
- `PlayerAutoAttack` validates that the target is hostile, exposes a melee
  approach destination, uses wind-up/impact/recovery timing, rechecks range at
  impact, and stops when the target is defeated.
- `PlayerWeaponAbilities` reads equipment-authored abilities and owns targeting,
  energy spending, cooldowns, cast timing, channels, and movement effects.
- `EnemyMobAI` owns mob aggro, chase, basic attacks, equipment abilities,
  defeat cleanup, and respawn.
- Current player and mob impacts create `DamageRequest` objects. The shared
  resolver checks armor for physical damage, magical resistance for magical
  damage, and bypasses defense for true damage before calling `CombatHealth`.
- `DamageResult.applied_damage` is the actual health lost after defense,
  immunity, absorb shields, and remaining-health limits.
- Directly clicking a hostile selectable starts auto-attack.
- Pressing Space starts auto-attack against the currently selected hostile
  target.
- Equipment owns the active Q/W/E/R/D/F/1/2 action-bar contract.
- The current playtest server clamps and resolves reported mob damage, but the
  attacking client still supplies the amount. Server validation of attack
  intent, range, timing, cooldowns, and authoritative stats is the next combat
  architecture step.

Auto-attack timing and fallback tuning lives on `Player/AutoAttack`. Equipment
ability tuning lives in resources under `assets/combat/abilities/`; do not copy
ability values into UI or network scripts.

- `attack_damage`
- `attack_interval`
- `attack_range`
- `approach_distance`

## Input

`scripts/player/input/player_input.gd`

Responsibilities:

- Reads left mouse and right mouse.
- Allows holding either mouse button to keep updating the move destination.
- Reads `S` as stop.
- Reads Space as the one-shot auto-attack request.
- Can suppress click-to-move after targeting consumes the current click.
- Uses the active camera to raycast from mouse position into the 3D world.
- Falls back to intersecting the player's floor plane if no physics hit exists.

Later refactor:

- Move hard-coded keys/buttons into Godot `InputMap` actions so controls can be
  rebound.

## Movement

`scripts/player/movement/player_movement_motor.gd`

Responsibilities:

- Stores the current movement destination.
- Accelerates toward that destination.
- Decelerates when there is no destination.
- Snaps sharp direction changes so quick click-turns feel responsive.
- Stops when close enough to the destination.

Important exported values on the `Movement` node:

- `movement_speed`
- `acceleration`
- `deceleration`
- `arrival_distance`
- `direction_change_snap_angle`

Note: the tracked player stat `Move Speed` is currently zeroed out in
`PlayerStats`. Gameplay movement still uses `movement_speed` on the `Movement`
node until we wire stats into movement formulas.

## Camera

`scenes/camera/IsometricCameraRig.tscn`
`scripts/camera/isometric_camera_rig.gd`

The camera rig is a reusable `Node3D` with a child `Camera3D`.

Responsibilities:

- Follow a target node, currently `Player/CameraTarget`.
- Use a perspective isometric-style angle.
- Keep the camera centered around the player's feet.
- Support mouse wheel zoom between the max distance and a closer distance.

Important exported values:

- `camera_offset` controls the angle and max distance.
- `min_zoom_ratio` controls how close the scroll wheel can zoom.
- `follow_speed` controls how tightly the camera follows.
- `field_of_view` controls perspective width.

## Animation

`scripts/player/animation/player_animation_controller.gd`

The character model and animation library come from different imported files, so
the animation controller creates a runtime `AnimationPlayer` and copies the
needed animations into it.

Current animations:

- `Idle`
- `Jog_Fwd`
- `Punch_Jab` for the first auto-attack prototype.
- `Shield_OneShot` for the first hand-gathering wood prototype.

Responsibilities:

- Find the animation source scene's `AnimationPlayer`.
- Copy selected animations into a runtime library. Idle, jog, and punch
  currently come from Universal Animation Library 1, while `Shield_OneShot` comes
  from Universal Animation Library 2.
- Loop idle, jog, and gathering animations.
- Slow the jog with `move_speed_scale`.
- Play the gathering loop while a gathering channel is active.
- Expose the current move animation progress so footstep audio can sync to foot
  contact points.

## Footsteps

Player-specific behavior:

```text
scripts/player/audio/player_footstep_audio.gd
```

Shared data:

```text
scripts/audio/footsteps/footstep_surface_set.gd
assets/audio/footsteps/sets/grass_footsteps.tres
assets/audio/footsteps/sets/hard_footsteps.tres
```

`FootstepSurfaceSet` is a reusable resource that stores:

- The sound streams for one surface type.
- Volume.
- Pitch variation.
- Fallback timing.

The player currently uses `grass_footsteps.tres` by default. The hard set is
kept for later terrain variety.

Footstep timing is synced to the jog animation with:

```gdscript
foot_contact_points = PackedFloat32Array([0.12, 0.62])
```

Those numbers mean "play a footstep at 12% and 62% through the looping jog
animation." If footsteps sound early or late, tune those two values.

Later refactor:

- Add terrain surface detection.
- Call `FootstepAudio.set_surface_set(...)` when the player walks from grass to
  stone, wood, mud, snow, etc.

## Stats

`scripts/player/stats/player_stats.gd`

`PlayerStats` is attached to the `Stats` node in `Player.tscn`.

It currently registers every stat from the first character sheet pass and resets
all runtime values to `0.0`.

The stats module stores:

- A stable stat id, such as `max_health`.
- A display name, such as `Max Health`.
- A category, such as `resources`.
- A display format, such as `number`, `percent`, `per_second`, `kilogram`, or
  `per_day`.
- The current numeric value.

Useful methods:

```gdscript
stats.get_stat(PlayerStats.MAX_HEALTH)
stats.set_stat(PlayerStats.MAX_HEALTH, 1200.0)
stats.add_to_stat(PlayerStats.REPUTATION, 10.0)
stats.reset_all_to_zero()
stats.get_all_stats()
stats.get_stat_ids()
```

The values are intentionally zeroed for now. Later, equipment, buffs,
progression, food, mounts, and server data should write into this system.

## Nameplates

`scenes/ui/nameplates/PlayerNameplate.tscn`
`scripts/ui/nameplates/player_nameplate.gd`

The player prefab has a `Nameplate` child above the character. It currently
renders a prototype player nameplate with:

- A colored emblem behind the first letter.
- The first letter rendered as a centered UI label using a blackletter font.
- The rest of the player name in white UI text.
- A placeholder alliance tag before the guild name.
- A placeholder guild name.
- Five-segment health and mana bars.

Target entities can use the same `PlayerNameplate` script in a trimmed mob mode:
set `show_when_unselected` off, hide `show_name_row`, `show_guild_line`, and
`show_mana_bar`, then enable `use_relationship_health_color`. That makes the
plate appear only when the target is selected and show only a friendly/hostile
health bar.

Because the game camera is perspective, `PlayerNameplate` can compensate for
zoom by adjusting its generated `Sprite3D.pixel_size` every frame. Keep
`keep_screen_size_on_zoom` enabled when the nameplate should stay the same
apparent size as the camera scrolls in and out. `compensate_height_on_zoom`
also lowers the local nameplate position during zoom-in so the plate stays
visually attached to the character.

The health and mana bars use `status_bar_segments` and
`status_bar_segment_gap` so combat readability can be tuned without changing
the rest of the nameplate layout.

Nameplate rows are measured after text is generated and recentered inside the
viewport, so the name, guild line, and status bars stay anchored above the
character even when player names have different lengths. When
`auto_resize_viewport_width` is enabled, very long names expand the offscreen
viewport width instead of clipping.

The first-letter font currently comes from:

```text
assets/ui/nameplates/fonts/unifraktur_maguntia/
```

It uses the SIL Open Font License and is only assigned to
`first_letter_font`, so the rest of the player name stays legible. Tune the
badge letter with `first_letter_font_size`, `first_letter_outline_size`, and
`first_letter_label_size`; increase the label size if a larger letter clips.

The imported gold glyph atlas is parked for later art experiments, but the live
nameplate does not use it right now. The atlas files live in:

```text
assets/ui/nameplates/gold_atlas/
```

Important files:

- `nameplate_gold_source.png` keeps the original green-background image.
- `nameplate_gold_atlas.png` is the transparent runtime texture.
- `nameplate_gold_glyph_regions.json` maps `A-Z` and `0-9` to atlas regions.
- `nameplate_gold_glyph_atlas.tres` is the Godot resource for future atlas work.
- `scripts/ui/nameplates/nameplate_glyph_atlas.gd` loads the atlas metadata.

Later, a character identity or networking system can call:

```gdscript
nameplate.set_player_name("LARRY")
nameplate.set_guild_info("GUILD NAME", "TAG")
nameplate.set_vitals(0.85, 0.6)
```

## Inventory Data And UI

`scenes/ui/inventory/InventoryPanel.tscn`
`scenes/ui/inventory/EquipmentPanel.tscn`
`scripts/inventory/item_definition.gd`
`scripts/inventory/item_stack.gd`
`scripts/inventory/player_inventory.gd`
`scripts/inventory/prototype_item_catalog.gd`
`scripts/ui/inventory/inventory_panel.gd`
`scripts/ui/inventory/equipment_panel.gd`
`scripts/ui/inventory/equipment_slot_icon.gd`
`scripts/ui/inventory/inventory_item_icon.gd`
`scripts/ui/inventory/inventory_slot_button.gd`
`assets/ui/inventory/logs_icon.png`
`assets/ui/inventory/rocks_icon.png`
`assets/ui/inventory/ores_icon.png`
`assets/ui/inventory/cotton_icon.png`
`assets/ui/inventory/hide_icon.png`

`PlayableLevelShell.tscn` has a `PlayerInventory` node and a standalone
`InventoryPanel` scene instanced at the root. Press `I` to toggle the panel
during play.
`PlayerInventory` owns local prototype item stacks, currency, and equipped-slot
state. `InventoryPanel` observes that node through signals and stays focused on
rendering slots, selected item details, equipped gear placeholders, and carry
weight. The default bag grid is 42 slots arranged as 6 columns by 7 rows.
The player starts with an empty bag and empty equipped gear; gathered resources
enter the bag through the gathering flow.

Bag slots can be dragged onto other bag slots. Dropping onto an empty slot moves
the stack there; dropping onto a filled slot swaps the two stacks. The
`InventorySlotButton` script owns only the Godot drag/drop event hooks, while
`InventoryPanel` forwards the move request to `PlayerInventory`.

Useful exported values on `PlayerInventory`:

- `slot_count`
- `seed_prototype_resources`
- `debug_seed_item_ids`
- `debug_main_hand_item_id`
- `starting_silver`
- `starting_gold`

Useful exported values on `InventoryPanel`:

- `inventory_path`
- `toggle_key`
- `slot_count`
- `columns`
- `start_visible`
- `starting_silver`
- `starting_gold`

The prototype data layer is split into small pieces:

- `ItemDefinition` describes a kind of item: id, display name, tier, icon,
  stack limit, unit weight, color, optional `equip_slot`, optional
  `equipment_scene_path`, optional `equipment_attachment_profile_path`, and
  description.
- `ItemStack` stores a runtime quantity for one item definition.
- `PrototypeItemCatalog` builds the temporary gathering resource definitions.
- `PlayerInventory` owns slots and exposes commands such as
  `move_or_swap_slots()`, `equip_from_slot()`, `unequip_to_slot()`,
  `add_stack()`, and `set_currency()`.

The current UI still reads display dictionaries from
`PlayerInventory.get_display_slots()`. Each filled display slot contains fields
such as `name`, `quantity`, `max_stack`, `category`, `unit_weight`, `color`, and
`description`. Empty bag slots are empty dictionaries. Equipped gear is a
`Dictionary` keyed by slot id, such as `bag`, `head`, `cape`, `main_hand`,
`chest`, `off_hand`, `potion`, `shoes`, or `food`. The visual gear panel is a
3x3 layout: Bag, Helmet, Cape / Main Hand, Chest, Off Hand / Potion, Shoes,
Food.

Empty gear slots use code-drawn placeholder icons from
`equipment_slot_icon.gd`. Equipped items use the same item-card renderer as bag
slots, so an equipped axe still shows its axe art and tier background. The
prototype starts with no equipped gear so the full placeholder icon set is
visible until the player drags a valid item into a gear slot.

Silver and gold are owned by `PlayerInventory`, centered in the inventory
header, and start at `0`. Their labels use fixed-width space and comma
formatting so larger currency totals stay readable. Signed-in playtest accounts
now save bag, equipped-slot, silver, and gold snapshots through
`PlayerDatabase`; the economy is still not server-authoritative yet.

`PrototypeItemCatalog` defines eight timber resources. Turning on
`seed_prototype_resources` in a debug/demo scene can seed these stacks into the
bag, but the playable prototype now leaves the bag empty by default:

- `Oak Wood I`
- `Ironwood II`
- `Silverneedle Pine III`
- `Blackroot Wood IV`
- `Emberwood V`
- `Sunheart Wood VI`
- `Kingswood VII`
- `Elderwood VIII`

It also defines eight stone resources:

- `Clay I`
- `Rough Stone II`
- `Sturdy Stone III`
- `Dense Stone IV`
- `Hardened Stone V`
- `Runed Stone VI`
- `Sunstone VII`
- `Kingsstone VIII`

And eight ore resources:

- `Iron Ore I`
- `Copper Ore II`
- `Silver Ore III`
- `Dense Ore IV`
- `Hardened Ore V`
- `Runed Ore VI`
- `Star Ore VII`
- `Kingsmetal Ore VIII`

And eight cotton resources. Cotton remains a prototype cloth-crafting lane until
the lore bible defines a dedicated fiber plant:

- `Crude Cotton I`
- `Rough Cotton II`
- `Coarse Cotton III`
- `Soft Cotton IV`
- `Fine Cotton V`
- `Lustrous Cotton VI`
- `Sunspun Cotton VII`
- `Kingsweave Cotton VIII`

And eight hide resources:

- `Wolf Hide I`
- `Deer Hide II`
- `Thick Hide III`
- `Cured Hide IV`
- `Hardened Hide V`
- `Pristine Hide VI`
- `Royal Hide VII`
- `Elder Hide VIII`

And eight axe gathering tool previews:

- `Crude Axe I`
- `Rough Axe II`
- `Sturdy Axe III`
- `Forged Axe IV`
- `Hardened Axe V`
- `Runed Axe VI`
- `Sunsteel Axe VII`
- `Elder Axe VIII`

Tools still declare `equip_slot = "main_hand"` in data so the inventory rules can
keep evolving. During the imported-mesh cleanup, the actual tool/weapon visual
prefabs and attachment profiles were removed, so these items currently equip as
data only.

`Player.tscn` has an `EquipmentVisuals` child that listens to
`PlayerInventory.equipped_slots_changed`. When the main hand slot contains an
item with `equipment_scene_path`, it finds the matching `EquipmentSocket3D`
whose `slot_id` equals the item's `equip_slot`, then instances that equipment
scene as a child of the socket.

This matches the usual production pattern:

- Character rigs expose named sockets, such as `main_hand`.
- Item definitions point at visual prefabs, such as `Tier1Axe.tscn`.
- Optional attachment profiles store item-specific local offsets, such as
  `axe_main_hand.tres`.
- Runtime equip logic only spawns or clears scenes; it does not hand-tune
  positions.

That production pattern is still the intended direction once project-owned item
visuals come back. `Player.tscn` keeps the `main_hand` bone socket, but the old
editor-only axe preview was removed with the imported mesh assets.

`InventoryItemIcon` draws the item card frame, small tier marker, and
bottom-right quantity. Log, stone, ore, cotton, and hide items use transparent
bitmap art from `logs_icon.png`, `rocks_icon.png`, `ores_icon.png`,
`cotton_icon.png`, and `hide_icon.png`; axe previews use `axe_icon.png`. Tier
colors fill the icon background behind the art: light gray, light brown, green,
blue, red, orange, yellow, and white for tiers I through VIII.

## Gathering Prototypes

`scripts/gathering/gatherable_resource_3d.gd`

`scenes/gathering/trees/OakTreeT1.tscn`

The first project-owned gatherable resource is currently the T1 Oak Tree. The
player-facing node and item names follow the lore bible: the tree yields
`Oak Wood I`. The scene wraps `assets/Nature Pack/CommonTree_1.gltf` and keeps
gameplay scale, colliders, selection, alpha-cut leaves, hover cursor, wind sway,
depleted stump visuals, and gather metadata in the prefab.

The root has `GatherableResource3D`, which stores the resource family, tier,
yield item id, per-tick yield quantity, gather duration, and remaining gather
ticks. The tree prefab pairs it with a neutral `Selectable` area, hover cursor
support, a selected ring, and a separate trunk collider.

Clicking the tree now starts the first gathering flow:

1. `PlayerTargeting` selects the tree's `Selectable`.
2. `PlayerGathering` recognizes the parent `GatherableResource3D`.
3. The player moves into gather range and faces the tree.
4. `PlayerChanneling` starts a timed gathering channel.
5. `ChannelBar` shows the channel progress.
6. `PlayerAnimationController` loops the active gathering animation while the
   channel is active.
7. On completion, `PlayerInventory.add_item("timber_t1", quantity)` adds 1 Oak Wood.
8. `GatherableResource3D.consume_gather_tick()` subtracts one available tick.
9. If ticks remain, `PlayerGathering` queues the next gathering channel.
10. When the final tick is consumed, the full tree hides and only the depleted
    stump visual appears in place.
11. Every 30 seconds, `GatherableResource3D` restores one missing tick. When
    the first tick returns, the full tree visual and selection come back.

Useful exported values on the T1 tree:

- `yield_quantity`
- `max_gather_ticks`
- `gather_duration`
- `replenish_enabled`
- `replenish_interval_seconds`
- `selectable_path`

Useful exported values on `VisualState`:

- `active_mesh_names`
- `occluded_mesh_names`
- `depleted_mesh_names`

## Channel Bar

`scenes/ui/hud/ChannelBar.tscn`
`scripts/ui/hud/channel_bar.gd`
`scripts/player/channeling/player_channeling.gd`

`PlayerChanneling` is the generic timed-action module. It emits start,
progress, complete, and cancel signals. `ChannelBar` listens to those signals
and renders a centered HUD progress bar with the action name and remaining time.
The first user of this system is tree gathering, but spells, recall, mounting,
crafting, and other interrupted actions should use the same channel module.

## Click Feedback

`scripts/player/feedback/player_click_feedback.gd`
`scenes/effects/ClickMoveIndicator.tscn`
`scripts/effects/click_move_indicator.gd`

When a new click-move starts, the player asks `PlayerClickFeedback` to spawn a
click indicator scene at the target world position.

The click indicator:

- Uses two yellow rings.
- Starts small.
- Scales outward.
- Fades quickly.
- Frees itself when the tween finishes.

## Debug Grid

`scenes/debug/IsometricGrid.tscn`
`scripts/debug/isometric_grid.gd`

The debug grid is an editor-friendly helper for reading the world from the
current camera angle. It rebuilds itself when exported values change.

It is not gameplay logic. It can be hidden, removed, or replaced without
touching player behavior.

## Visual Style

`scripts/player/visuals/player_visual_style.gd`

This script applies simple toon-like materials to the placeholder character at
runtime. It is currently reused by the prototype target characters too, so the
friendly and hostile test mobs use the same low-poly/toon material style as the
player with different body colors. It is a prototype styling pass, not the final
character customization system.

Later refactor:

- Move character appearance into data resources.
- Add equipment meshes/materials.
- Separate base body, hair, eyes, armor, weapons, and cosmetic overrides.

## Asset Notes

Current third-party assets are documented near the assets themselves:

- Character model/license: `assets/characters/base/`
- Animation packs/license/source: `assets/animations/`
- Footstep sources/license: `assets/audio/footsteps/README.md`

Before adding new assets, read `docs/LICENSING.md`.

## Common Changes

Change base movement speed:

- Open `Player.tscn`.
- Select `Player/Movement`.
- Edit `movement_speed`.

Change camera angle:

- Open `scenes/camera/IsometricCameraRig.tscn`.
- Adjust `camera_offset`.

Change max zoom-in:

- Open `IsometricCameraRig.tscn`.
- Adjust `min_zoom_ratio`.

Tune footstep timing:

- Open `Player.tscn`.
- Select `Player/FootstepAudio`.
- Adjust `foot_contact_points` on the script if exposed, or edit the default in
  `player_footstep_audio.gd`.

Add a new player stat:

- Add a new constant in `player_stats.gd`.
- Add one entry to `STAT_DEFINITIONS`.
- Keep the default runtime value at zero unless a real system owns that value.

Add a new footstep surface:

- Add sound files under `assets/audio/footsteps/`.
- Document source and license in `assets/audio/footsteps/README.md`.
- Create a new `.tres` resource using `FootstepSurfaceSet`.
- Later, surface detection can swap to it at runtime.

## What To Keep Modular

As the MMO grows, avoid putting unrelated logic into `PlayerController`.

Good module boundaries:

- Input reads intent.
- Movement changes velocity/position.
- Animation plays animations.
- Audio plays sounds.
- Stats store numeric character state.
- Combat applies abilities and damage.
- Inventory stores item stacks.
- Equipment modifies stats and visuals.
- Networking validates and replicates gameplay.

If a script starts doing three of those jobs at once, it is probably time to
split it.

## Current Gaps

These are expected gaps, not bugs:

- No server-authoritative networking yet.
- Inventory has prototype player-database persistence, but no trading or
  server-authoritative economy yet.
- Stats are tracked and can persist, but most are not applied to final
  movement/combat formulas yet.
- No combat abilities yet.
- No terrain surface detector yet.
- World resources, loot containers, and position are not saved yet.

The next systems should stay small and testable: equipment data, stat modifiers,
terrain surface detection, gathering nodes, or a first ability prototype.
