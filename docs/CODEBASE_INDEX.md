# Codebase Index

This is the fast lookup map for Elderforge. Use `CODEBASE_GUIDE.md` when you
want the learning walkthrough; use this file when you already know what system
you want to open.

## Entry Points

| Path | Purpose |
| --- | --- |
| `project.godot` | Godot project settings and main scene pointer. |
| `docs/START_HERE.md` | Shortest orientation page for the current prototype. |
| `scenes/world/starting_city/StartingCity.tscn` | Current playable prototype entry scene. |
| `scenes/levels/PlayableLevelShell.tscn` | Shared level shell inherited by playable scenes. |
| `scenes/player/Player.tscn` | Reusable player prefab. Drop this into a scene to play from it. |
| `scripts/README.md` | GDScript primer and guide to every script folder README. |
| `docs/CODEBASE_GUIDE.md` | Longer learning guide for how the current systems fit together. |
| `docs/ROADMAP.md` | Phase plan and milestone direction. |

## Playable Scenes

| Path | Purpose |
| --- | --- |
| `scenes/world/starting_city/StartingCity.tscn` | Current demo map. Keep map-specific placement here. |
| `scenes/levels/PlayableLevelShell.tscn` | Reusable player/UI/ground/grid/lighting setup for playable maps. |
| `scenes/main/Main.tscn` | Older prototype sandbox scene kept for reference/testing. |
| `scenes/debug/IsometricGrid.tscn` | Debug grid scene used as isometric visual reference. |
| `scripts/debug/isometric_grid.gd` | Draws and configures the debug grid. |
| `scenes/entities/TargetDummy.tscn` | Friendly and hostile prototype target scene. |
| `scenes/gathering/Tier1Tree.tscn` | T1 tree gameplay wrapper with Blender-authored trunk/leaves/stump visuals, 3 gather ticks, 30-second tick replenishment, and a resource collider. |
| `scenes/gathering/Tier1Rock.tscn` | T1 stone gameplay wrapper with Blender-authored full/depleted rock visuals, 3 gather ticks, 30-second tick replenishment, and a resource collider. |

## Art Assets

| Path | Purpose |
| --- | --- |
| `assets/models/resources/trees/t1_tree.blend` | Editable Blender source for the T1 tree. |
| `assets/models/resources/trees/t1_tree_trunk.glb` | Runtime trunk export instanced by `Tier1Tree.tscn`. |
| `assets/models/resources/trees/t1_tree_leaves.glb` | Runtime leaves/canopy export instanced by `Tier1Tree.tscn`, split out for future seasonal swaps and canopy hiding/fading. |
| `assets/models/resources/trees/t1_tree_stump.glb` | Runtime depleted-stump export instanced by `Tier1Tree.tscn`. |
| `assets/models/resources/rocks/t1_rock.blend` | Editable Blender source for the T1 rock. |
| `assets/models/resources/rocks/t1_rock_full.glb` | Runtime full-rock export instanced by `Tier1Rock.tscn`. |
| `assets/models/resources/rocks/t1_rock_depleted.glb` | Runtime depleted-rubble export instanced by `Tier1Rock.tscn`. |
| `assets/equipment/tools/axes/t#/source/t#_axe.blend` | Editable Blender source for each tiered axe gathering tool. |
| `assets/equipment/tools/axes/t#/models/t#_axe.glb` | Runtime axe tool exports instanced by tier-specific axe scenes. |
| `assets/models/equipment/attachments/axe_main_hand.tres` | Current main-hand attachment profile for axe visuals. |
| `scenes/equipment/tools/axes/Tier#Axe.tscn` | Tier-specific axe tool prefabs with grip and hit markers for hand attachment. |
| `tools/blender/export_t1_tree_asset.py` | Export-only Blender script for pushing hand edits from the `.blend` into the `.glb` runtime files. |
| `tools/blender/export_t1_rock_asset.py` | Export-only Blender script for pushing hand edits from the rock `.blend` into the `.glb` runtime files. |
| `tools/blender/export_t1_axe_asset.py` | Export-only Blender script for pushing hand edits from the axe `.blend` into the `.glb` runtime file. |

## Player Prefab

| Path | Purpose |
| --- | --- |
| `scripts/player/controllers/player_controller.gd` | Coordinates player sub-systems. This should stay thin. |
| `scripts/player/input/player_input.gd` | Reads click-to-move, hold-to-move, stop, space attack, and mouse intent. |
| `scripts/player/movement/player_movement_motor.gd` | Moves the `CharacterBody3D` toward the current destination. |
| `scripts/player/visuals/player_facing.gd` | Rotates the character toward movement and combat targets. |
| `scripts/player/visuals/player_visual_style.gd` | Applies the current toon-like placeholder material style. |
| `scripts/player/equipment/player_equipment_visuals.gd` | Mirrors equipped inventory items into visible player hand attachments. |
| `scripts/player/equipment/equipment_socket_3d.gd` | Named bone socket used by equipped visual prefabs. |
| `scripts/player/equipment/equipment_attachment_profile.gd` | Item-specific local offset data for socketed equipment visuals. |
| `scripts/player/animation/player_animation_controller.gd` | Owns movement, combat, and gathering animation playback. |
| `scripts/player/audio/player_footstep_audio.gd` | Plays footstep audio tied to movement cadence. |
| `scripts/player/feedback/player_click_feedback.gd` | Spawns click-move ground indicators. |
| `scripts/player/stats/player_stats.gd` | Stores player stat ids and current numeric values. |
| `scripts/player/targeting/player_targeting.gd` | Handles local selection and targeting rules. |
| `scripts/player/combat/player_auto_attack.gd` | Prototype auto-attack flow for hostile targets. |
| `scripts/player/channeling/player_channeling.gd` | Generic timed-action state for gathering and future spell casts. |
| `scripts/player/gathering/player_gathering.gd` | Player-side gathering approach, channel start, and reward handoff. |

## Camera

| Path | Purpose |
| --- | --- |
| `scenes/camera/IsometricCameraRig.tscn` | Camera rig attached to or following the player. |
| `scripts/camera/isometric_camera_rig.gd` | Perspective-isometric follow camera with scroll zoom. |

## Interaction

| Path | Purpose |
| --- | --- |
| `scripts/interaction/hover/hover_feedback_3d.gd` | Hover detection and hover visual feedback hook. |
| `scripts/interaction/cursor/cursor_override.gd` | Shared helper for temporary custom mouse cursors. |
| `scripts/interaction/selection/selectable_3d.gd` | Shared selectable target data such as friendly or hostile relationship. |
| `scripts/interaction/selection/selection_feedback_3d.gd` | Selected-target ring and relationship color feedback. |

## Combat And Health

| Path | Purpose |
| --- | --- |
| `scripts/combat/combat_health.gd` | Shared prototype health component for damageable things. |
| `scripts/player/combat/player_auto_attack.gd` | Player-side auto-attack behavior and range/face/start logic. |

## Inventory Data

| Path | Purpose |
| --- | --- |
| `scripts/inventory/item_definition.gd` | Static data for one item type: id, name, tier, icon, stack size, weight, color, equip slot, equipment scene path, and attachment profile path. |
| `scripts/inventory/item_stack.gd` | Runtime quantity of a specific item definition. |
| `scripts/inventory/prototype_item_catalog.gd` | Temporary in-code catalog for logs, stone, ore, cotton, and hide tiers. |
| `scripts/inventory/player_inventory.gd` | Local prototype owner for bag slots, currency, and equipped-slot state. |

Open `player_inventory.gd` when adding inventory behavior. Open
`prototype_item_catalog.gd` when changing the temporary resource item list.
Later, the catalog should become authored resources, loaded data, or
server-provided definitions.

## Inventory UI

| Path | Purpose |
| --- | --- |
| `scenes/ui/inventory/InventoryPanel.tscn` | Toggleable inventory window. |
| `scenes/ui/inventory/EquipmentPanel.tscn` | Equipped gear slot panel. |
| `scenes/ui/hud/ChannelBar.tscn` | HUD channel progress bar for gathering and future casts. |
| `scripts/ui/inventory/inventory_panel.gd` | UI-only panel: renders inventory state and forwards bag/equipment drag/drop moves. |
| `scripts/ui/inventory/equipment_panel.gd` | Gear slot layout, selection UI, and gear drop routing. |
| `scripts/ui/inventory/equipment_slot_button.gd` | Godot drag/drop hooks for one equipped gear slot button. |
| `scripts/ui/inventory/equipment_slot_icon.gd` | Code-drawn default gear slot icons. |
| `scripts/ui/inventory/inventory_item_icon.gd` | Code-drawn item cards with tier background, icon art, and quantity. |
| `scripts/ui/inventory/inventory_slot_button.gd` | Godot drag/drop hooks for one inventory slot button. |
| `scripts/ui/hud/channel_bar.gd` | Signal-driven UI for the current PlayerChanneling action. |

## Gathering

| Path | Purpose |
| --- | --- |
| `scenes/gathering/Tier1Tree.tscn` | First gatherable tree scene with selectable hitbox and solid resource collider. |
| `scenes/gathering/Tier1Rock.tscn` | First gatherable stone scene with selectable hitbox and solid resource collider. |
| `scripts/gathering/gatherable_resource_3d.gd` | Resource data, per-tick yield, remaining gather ticks, and depleted visual state. |
| `scripts/player/gathering/player_gathering.gd` | Approaches resources, starts gathering channels, consumes ticks, and adds rewards to inventory. |

## Nameplates

| Path | Purpose |
| --- | --- |
| `scenes/ui/nameplates/PlayerNameplate.tscn` | World-space player or target nameplate. |
| `scripts/ui/nameplates/player_nameplate.gd` | Name, guild, alliance, health, mana, and scale behavior. |
| `scripts/ui/nameplates/nameplate_glyph_atlas.gd` | Support for atlas-based glyph rendering. |
| `assets/ui/nameplates/fonts/unifraktur_maguntia/` | Current old-style font files and license. |
| `assets/ui/nameplates/gold_atlas/` | Experimental gold glyph atlas assets. |

## Effects

| Path | Purpose |
| --- | --- |
| `scenes/effects/ClickMoveIndicator.tscn` | Ground click indicator scene. |
| `scripts/effects/click_move_indicator.gd` | Double-ring click indicator growth and fade behavior. |

## Audio

| Path | Purpose |
| --- | --- |
| `scripts/audio/footsteps/footstep_surface_set.gd` | Resource describing footstep clips for a surface. |
| `assets/audio/footsteps/sets/grass_footsteps.tres` | Current default grass/dirt footstep surface set. |
| `assets/audio/footsteps/sets/hard_footsteps.tres` | Hard-surface footstep set kept for later variety. |
| `assets/audio/footsteps/README.md` | Footstep asset notes and source tracking. |

## Visual Assets

| Path | Purpose |
| --- | --- |
| `assets/characters/base/` | Current base character mesh, textures, and license notes. |
| `assets/animations/universal_animation_library_1/` | Imported animation pack 1. |
| `assets/animations/universal_animation_library_2/` | Imported animation pack 2. |
| `assets/animations/source/` | Editable Blender source files for the imported animation packs. |
| `assets/ui/inventory/logs_icon.png` | Log resource item art. |
| `assets/ui/inventory/rocks_icon.png` | Stone resource item art. |
| `assets/ui/inventory/ores_icon.png` | Ore resource item art. |
| `assets/ui/inventory/cotton_icon.png` | Cotton resource item art. |
| `assets/ui/inventory/hide_icon.png` | Hide resource item art. |
| `assets/ui/inventory/axe_icon.png` | Axe equipment preview item art. |
| `assets/ui/cursors/gather_pickaxe_cursor.png` | Custom cursor shown while hovering gatherable resources. |
| `assets/ui/cursors/depleted_resource_cursor.png` | Custom cursor shown while hovering depleted gatherable resources. |
| `assets/ui/cursors/attack_cursor.png` | Custom cursor shown while hovering hostile attackable targets. |
| `assets/materials/hover/` | Hover outline shader/material assets. |

## Documentation

| Path | Purpose |
| --- | --- |
| `README.md` | Project overview. |
| `CONTRIBUTING.md` | Contributor workflow and expectations. |
| `CODE_OF_CONDUCT.md` | Community behavior rules. |
| `SECURITY.md` | Security reporting guidance. |
| `docs/START_HERE.md` | Short orientation page for the active prototype. |
| `docs/PROJECT_STRUCTURE.md` | Folder layout and naming rules. |
| `docs/CODEBASE_GUIDE.md` | Detailed learning guide. |
| `docs/CODEBASE_INDEX.md` | This fast lookup index. |
| `docs/DESIGN_BOUNDARIES.md` | Design/legal boundaries for inspiration from existing games. |
| `docs/LICENSING.md` | Asset and licensing rules. |
| `docs/ROADMAP.md` | Current phase roadmap. |
| `scripts/**/README.md` | Local junior-friendly notes for each script folder. |

## Good Search Commands

```powershell
rg --files
rg "class_name PlayerInventory" scripts
rg "move_or_swap_slots|add_stack" scripts
rg "inventory_path" scenes scripts
rg "auto_attack|target" scripts/player scripts/interaction
```

## Current Growth Direction

The safest next systems to grow from here are:

- Gathering nodes that call `PlayerInventory.add_item()` or `add_stack()`.
- Equipment data that feeds `PlayerInventory.set_equipped_slots()`.
- Stat modifiers that connect equipment and buffs to `PlayerStats`.
- Terrain surface detection that chooses between footstep surface sets.
- A first ability prototype that builds on targeting and auto-attack.
