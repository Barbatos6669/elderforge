# Codebase Guide

This guide is a learning map for Elderforge's current Godot prototype. Read it
when you want to understand where things live, how the player prefab works, and
where to make the next small change.

The codebase is intentionally small right now. The main idea is to keep each
system in its own script or scene so the MMO can grow without turning the player
controller into one giant file.

## First Read Order

Start here if you are new to the project:

1. `project.godot` - tells Godot which scene runs first.
2. `scenes/main/Main.tscn` - the current test world.
3. `scenes/player/Player.tscn` - the reusable player prefab.
4. `scripts/player/controllers/player_controller.gd` - coordinates the player
   sub-systems.
5. `scripts/README.md` - GDScript syntax notes and the script folder map.
6. The smaller scripts under `scripts/player/` - movement, input, animation,
   audio, stats, visuals, and feedback.

## Project Entry Point

`project.godot` points the game at:

```text
res://scenes/main/Main.tscn
```

That means pressing Play in Godot loads `Main.tscn`.

`Main.tscn` currently contains:

- `WorldEnvironment` for basic lighting/background color.
- `World`, a parent node for world objects.
- `DebugGrid`, the isometric reference grid.
- `Ground`, a flat walkable plane with collision.
- `Player`, an instance of the reusable player prefab.
- `FriendlyTarget` and `HostileTarget`, selectable prototype targets for testing
  relationship-colored hover/selection.
- `Tier1Tree`, a gathering tree with T1-colored leaf clusters.
- `Tier1Rock`, a gathering stone node with full and depleted rock visuals.
- `PlayerInventory`, local prototype item and currency storage.
- `InventoryPanel`, the toggleable prototype inventory UI.
- `Sun`, a directional light.

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
  CODEBASE_INDEX.md     Fast lookup index for scenes, scripts, and systems.
  CODEBASE_GUIDE.md     This file.
  DESIGN_BOUNDARIES.md  What we can and cannot copy from other games.
  LICENSING.md          Asset and license rules.
  ROADMAP.md            Milestones.

scenes/
  camera/    Reusable camera rig scene.
  debug/     Debug-only helper scenes.
  entities/  Prototype gameplay entities such as target dummies.
  effects/   Visual effects such as click indicators.
  gathering/ Prototype resource nodes such as trees.
  ui/        Reusable UI scenes such as inventory and nameplates.
  main/      Current playable test scene.
  player/    Reusable player prefab.

scripts/
  README.md    GDScript primer and script folder map.
  audio/     Shared audio data/resources.
  camera/    Camera behavior.
  combat/    Shared combat components.
  debug/     Debug helper behavior.
  effects/   Effect behavior.
  gathering/ Prototype gatherable resource metadata.
  interaction/ Shared interaction helpers such as hover detection.
  inventory/ Prototype item definitions, stacks, and inventory storage.
  player/    Player-specific systems.
  ui/        UI and world-space display helpers.
  visuals/   Reserved for shared visual helpers.
```

Every folder under `scripts/` has a local `README.md`. Those files are meant as
junior-friendly entry points: what the folder owns, which files to open first,
and which GDScript syntax is worth knowing before editing there.

## Player Prefab

`scenes/player/Player.tscn` is the main player prefab. The goal is that this
scene can be dropped into any playable scene and work immediately.

Current child nodes:

- `Input` reads mouse/keyboard intent.
- `Targeting` handles local click target selection.
- `AutoAttack` runs the local-player prototype auto-attack loop.
- `Channeling` tracks timed actions such as gathering.
- `Gathering` handles gather target approach, channel start, and rewards.
- `Stats` stores player stat values and metadata.
- `Movement` moves the `CharacterBody3D` toward a destination.
- `Facing` rotates the visual model toward movement direction.
- `VisualStyle` applies the current toon-like placeholder material style.
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

Every physics frame, `PlayerController` does this:

1. If input is disabled, stop movement, animation, footsteps, attacks, and
   gathering channels.
2. If `S` is held, stop movement and cancel gathering channels.
3. Otherwise, ask `PlayerTargeting` whether the current left-click selected a
   target.
4. If a gatherable target was clicked, ask `PlayerGathering` to approach it.
5. If a hostile target was clicked, ask `PlayerAutoAttack` to start attacking.
6. If Space was pressed while a hostile target is selected, ask `PlayerAutoAttack`
   to start attacking.
7. If targeting did not consume the click, ask `PlayerInput` whether the mouse
   is pointing at a movement target.
8. If a new click-move started, ask `PlayerClickFeedback` to spawn the click marker.
9. If auto-attack is active, chase the hostile target until melee range.
10. If gathering is active, approach the resource and start the channel in range.
11. Ask `PlayerMovementMotor` to move toward the destination.
12. Ask `PlayerFacing` to rotate the visual model.
13. Tell animation and footstep audio whether the player is currently moving.
14. Face the combat or gathering target once in range.
15. Advance the auto-attack cooldown, play the attack animation, and apply
    damage when a swing is ready.
16. Advance `PlayerChanneling` and let gathering add resources when its channel
    completes.

This means movement, visuals, animation, audio, and feedback can change without
rewriting the whole player controller.

## Hover Feedback

`scripts/interaction/hover/hover_feedback_3d.gd`
`scripts/interaction/cursor/cursor_override.gd`
`assets/materials/hover/hover_outline_green.tres`
`assets/materials/hover/hover_outline.gdshader`
`assets/ui/cursors/gather_pickaxe_cursor.png`

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
`HoverSelectionRing` node. `Tier1Tree` uses the pickaxe cursor asset so hovering
a gatherable tree replaces the normal mouse pointer. Tune
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

`TargetDummy.tscn` is the current test entity. `Main.tscn` instances it as a
friendly target and a hostile target so hover/selection can be checked against
both relationship colors. Its nameplate is hidden until selected, and then only
shows a relationship-colored health bar: green for friendly and red for hostile.
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
`scripts/player/combat/player_auto_attack.gd`

This is the first local-only combat prototype. It is not server authoritative
yet and does not include ability formulas, attack animations, or pathfinding.

- `CombatHealth` stores max/current health, applies damage, and emits health
  ratio updates for UI.
- `PlayerAutoAttack` validates that the target is hostile, exposes a melee
  approach destination, checks attack range, applies damage on an interval, and
  stops when the target is defeated.
- Directly clicking a hostile selectable starts auto-attack.
- Pressing Space starts auto-attack against the currently selected hostile
  target.
- Friendly and neutral targets cannot be auto-attacked by this module.
- The player moves into melee range before the first hit, faces the target, and
  plays the `Punch_Jab` one-shot animation when a hit lands.

Current tuning lives on `Player/AutoAttack`:

- `attack_damage`
- `attack_interval`
- `attack_range`
- `approach_distance`

`TargetDummy.tscn` has a `Health` child using `CombatHealth`. Its selected-only
health bar reads that health source, so auto-attacks visibly lower the bar.

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

`Main.tscn` has a `PlayerInventory` node and a standalone `InventoryPanel` scene
instanced at the root. Press `I` to toggle the panel during play.
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
formatting so larger currency totals stay readable. These values are still local
prototype data until an economy, wallet, persistence, or server module exists.

`PrototypeItemCatalog` defines eight timber resources. Turning on
`seed_prototype_resources` in a debug/demo scene can seed these stacks into the
bag, but the playable prototype now leaves the bag empty by default:

- `Crude Logs I`
- `Rough Logs II`
- `Sturdy Logs III`
- `Seasoned Logs IV`
- `Hardened Logs V`
- `Emberwood Logs VI`
- `Sunheart Logs VII`
- `Kingswood Logs VIII`

It also defines eight stone resources:

- `Crude Stone I`
- `Rough Stone II`
- `Sturdy Stone III`
- `Dense Stone IV`
- `Hardened Stone V`
- `Runed Stone VI`
- `Sunstone VII`
- `Kingsstone VIII`

And eight ore resources:

- `Crude Ore I`
- `Rough Ore II`
- `Sturdy Ore III`
- `Dense Ore IV`
- `Hardened Ore V`
- `Runed Ore VI`
- `Star Ore VII`
- `Kingsmetal Ore VIII`

And eight cotton resources:

- `Crude Cotton I`
- `Rough Cotton II`
- `Coarse Cotton III`
- `Soft Cotton IV`
- `Fine Cotton V`
- `Lustrous Cotton VI`
- `Sunspun Cotton VII`
- `Kingsweave Cotton VIII`

And eight hide resources:

- `Crude Hide I`
- `Rough Hide II`
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

Axes declare `equip_slot = "main_hand"`, so dragging one from the bag onto the
Main Hand gear slot equips it. Dragging the equipped axe back onto a bag slot
unequips it; dropping another axe onto Main Hand swaps the old one back into the
bag. They also set `equipment_scene_path` to tier-specific scenes like
`Tier1Axe.tscn` through `Tier8Axe.tscn`, plus
`equipment_attachment_profile_path` to the current axe main-hand offset profile.

Each tier scene under `scenes/equipment/tools/axes/` instances its matching GLB
from `assets/equipment/tools/axes/t#/models/`, which is exported from the
editable Blender source in `assets/equipment/tools/axes/t#/source/`. The prefab
includes a `GripPoint` marker at the root and a `HitPoint` near the blade so
future gathering, VFX, or hand-socket systems have stable attachment references.

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

For visual tuning, `Player.tscn` also contains
`Visuals/BaseCharacter/Armature/Skeleton3D/MainHandAttachment/MainHandPreview`.
This is a visible editor-only axe preview with a yellow grip marker. Move,
rotate, or scale that preview node to line up the grip in the character's hand;
`EquipmentVisuals` copies the preview's local transform to the real equipped
axe and hides the preview at runtime. The profile resource is the reusable data
home for item-specific offsets once we add more item shapes.

`InventoryItemIcon` draws the item card frame, small tier marker, and
bottom-right quantity. Log, stone, ore, cotton, and hide items use transparent
bitmap art from `logs_icon.png`, `rocks_icon.png`, `ores_icon.png`,
`cotton_icon.png`, and `hide_icon.png`; axe previews use `axe_icon.png`. Tier
colors fill the icon background behind the art: light gray, light brown, green,
blue, red, orange, yellow, and white for tiers I through VIII.

## Gathering Prototypes

`scenes/gathering/Tier1Tree.tscn`
`scenes/gathering/Tier1Rock.tscn`
`scripts/gathering/gatherable_resource_3d.gd`

`Tier1Tree` is the first gatherable node. The scene owns the gameplay wrapper,
while the visuals come from Blender-authored exports in
`assets/models/resources/trees/`. Open `t1_tree.blend` to edit the model, then
export over the same `.glb` paths so Godot updates the resource scene without
touching gathering, selection, or collision wiring. The trunk, leaves, and
depleted stump are separate runtime exports, which gives future scripts clean
targets for canopy hiding, fading, seasonal swaps, or different tree crowns. The
leaves use the shared T1 light gray tier color, while the trunk uses simple
brown bark materials.

`Tier1Rock` follows the same resource-scene pattern for stone. Its visuals come
from `assets/models/resources/rocks/t1_rock.blend`, exported as
`t1_rock_full.glb` and `t1_rock_depleted.glb`. It uses
`resource_family_id = "stone"` and `yield_item_id = "stone_t1"`, so each
completed gather tick adds one T1 stone stack item.

The root has `GatherableResource3D`, which stores the resource family, tier,
yield item id, per-tick yield quantity, gather duration, and remaining gather
ticks. The current T1 tree and T1 rock both have 3 ticks and give 1 item per
completed tick. Missing ticks replenish one at a time every 30 seconds. The
scene also has a neutral `Selectable` area plus hover and selected rings, so it
can already be targeted like other world objects.

The tree also has a separate `ResourceBody` `StaticBody3D` collider on the
`ResourceObstacle` physics layer. This is the solid obstacle the player collides
with. It is intentionally smaller than the selectable capsule, because clicking
and hovering should be forgiving while physical collision should stay close to
the trunk.

Clicking the tree now starts the first gathering flow:

1. `PlayerTargeting` selects the tree's `Selectable`.
2. `PlayerGathering` recognizes the parent `GatherableResource3D`.
3. The player moves into gather range and faces the tree.
4. `PlayerChanneling` starts a timed gathering channel.
5. `ChannelBar` shows the channel progress.
6. `PlayerAnimationController` loops `Shield_OneShot` while the channel is active.
7. On completion, `PlayerInventory.add_item("timber_t1", quantity)` adds 1 log.
8. `GatherableResource3D.consume_gather_tick()` subtracts one available tick.
9. If ticks remain, `PlayerGathering` queues the next gathering channel.
10. When the final tick is consumed, the full tree hides and only the depleted
    stump visual appears in place.
11. Every 30 seconds, `GatherableResource3D` restores one missing tick. When
    the first tick returns, the full tree visual and selection come back.

Useful exported values on `Tier1Tree`:

- `yield_quantity`
- `max_gather_ticks`
- `gather_duration`
- `replenish_enabled`
- `replenish_interval_seconds`
- `active_visuals_path`
- `depleted_visuals_path`

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
- Inventory is local prototype data only; no persistence, trading, crafting,
  equipment rules, or server authority yet.
- Stats are tracked but not applied to movement/combat formulas yet.
- No combat abilities yet.
- No terrain surface detector yet.
- No save/load persistence yet.
- No character creation or account system yet.

The next systems should stay small and testable: equipment data, stat modifiers,
terrain surface detection, gathering nodes, or a first ability prototype.
