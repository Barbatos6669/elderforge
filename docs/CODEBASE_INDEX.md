# Codebase Index

This is the fast lookup map for Elderforge after the imported-mesh cleanup.
Use `CODEBASE_GUIDE.md` for the longer learning walkthrough.

## Entry Points

| Path | Purpose |
| --- | --- |
| `project.godot` | Godot project settings and main scene pointer. |
| `scenes/world/starting_city/StartingCity.tscn` | Current playable prototype entry scene. |
| `scenes/levels/PlayableLevelShell.tscn` | Shared level shell inherited by playable scenes. |
| `scenes/player/Player.tscn` | Reusable player prefab. |
| `scenes/entities/animals/Rat.tscn` | Killable/skinnable rat animal prefab. |
| `scripts/README.md` | GDScript primer and guide to script folder READMEs. |
| `docs/ROADMAP.md` | Phase plan and milestone direction. |
| `docs/MULTIPLAYER_READINESS.md` | Current multiplayer-safe systems, prototype-local systems, and next authority pass. |
| `docs/PERSISTENCE_ARCHITECTURE.md` | Player database backend plan from JSON to SQLite to larger live databases. |

## Current 3D Assets

| Path | Purpose |
| --- | --- |
| `assets/characters/base/` | Current base character mesh, textures, and license notes. |
| `assets/animals/rat/` | Imported rat animal placeholder and import metadata. |
| `assets/animations/universal_animation_library_1/` | Shared animation pack 1. |
| `assets/animations/universal_animation_library_2/` | Shared animation pack 2. |
| `assets/animations/source/` | Editable Blender source files for the animation packs. |
| `assets/Nature Pack/CommonTree_1.gltf` | Current T1 Oak/Common Tree visual used by the gatherable starter tree prefab. |

Broad imported model/source packs were removed. Future world props, resources,
equipment, and buildings should be rebuilt as project-owned assets or
Godot-native prototypes.

## Lore And Design

| Path | Purpose |
| --- | --- |
| `docs/lore/resources/` | Resource lore, names, drop ideas, and quest hooks. |
| `docs/lore/resources/silverneedle_pine.md` | T1 magical wood identity and gameplay hooks. |

## Player

| Path | Purpose |
| --- | --- |
| `scripts/player/controllers/player_controller.gd` | Coordinates player sub-systems. This should stay thin. |
| `scripts/player/input/player_input.gd` | Reads click-to-move, hold-to-move, stop, space attack, and mouse intent. |
| `scripts/player/movement/player_movement_motor.gd` | Moves the `CharacterBody3D` toward the current destination. |
| `scripts/player/visuals/player_facing.gd` | Rotates the character toward movement and combat targets. |
| `scripts/player/visuals/player_visual_style.gd` | Applies the current toon-like placeholder material style. |
| `scripts/player/animation/player_animation_controller.gd` | Owns movement, combat, death, and gathering animation playback. |
| `scripts/player/audio/player_footstep_audio.gd` | Plays footstep audio tied to movement cadence. |
| `scripts/player/stats/player_stats.gd` | Stores player stat ids and current numeric values. |
| `scripts/player/targeting/player_targeting.gd` | Handles local selection and targeting rules. |
| `scripts/player/combat/player_auto_attack.gd` | Prototype auto-attack flow for hostile targets. |
| `scripts/player/channeling/player_channeling.gd` | Generic timed-action state for gathering and future spell casts. |
| `scripts/player/gathering/player_gathering.gd` | Player-side gathering approach, channel start, and reward handoff. |
| `scenes/gathering/trees/OakTreeT1.tscn` | First gatherable T1 Oak Tree prefab. |

## Core Systems

| Path | Purpose |
| --- | --- |
| `scripts/inventory/` | Inventory data, item families, item stacks, and the prototype catalog. |
| `scripts/persistence/` | File-backed player database for prototype accounts, appearance, inventory snapshots, and stat snapshots. |
| `scripts/gathering/` | World resource metadata and visual state helpers. |
| `scripts/levels/` | Shared playable-level shell startup behavior, including dedicated server cleanup. |
| `scripts/entities/animals/` | Reusable animal animation and skinnable corpse behavior. |
| `scripts/ui/inventory/` | Inventory and equipment UI behavior. |
| `scripts/ui/chat/` | In-game chat panel and text-entry behavior. |
| `scripts/combat/` | Shared health, combat state, resource pools, and damage numbers. |
| `scripts/interaction/` | Hover, cursor, selection, and target feedback helpers. |
| `scripts/camera/isometric_camera_rig.gd` | Perspective-isometric follow camera with scroll zoom. |
| `scenes/levels/lighting/BasicLevelLighting.tscn` | Shared directional/fill/spawn lighting rig. |
| `scenes/levels/atmosphere/AtmosphereField.tscn` | Reusable ground mist atmosphere pass. |
| `scenes/ui/hud/ChannelBar.tscn` | HUD channel progress bar for gathering and future casts. |
| `scenes/ui/chat/ChatPanel.tscn` | Bottom-left multiplayer chat panel. |
| `scenes/ui/nameplates/PlayerNameplate.tscn` | World-space player or target nameplate. |

## UI And 2D Assets

| Path | Purpose |
| --- | --- |
| `assets/ui/inventory/` | Current inventory item icons. |
| `assets/ui/cursors/` | Current cursor icons. |
| `assets/ui/nameplates/` | Nameplate fonts and glyph experiments. |
| `assets/audio/footsteps/` | Current footstep sound sets. |
| `assets/materials/hover/` | Hover outline shader/material assets. |
| `assets/materials/world/` | Godot-native world materials such as water and mist. |

## Good Search Commands

```powershell
rg --files
rg "class_name PlayerInventory" scripts
rg "move_or_swap_slots|add_stack" scripts
rg "auto_attack|target" scripts/player scripts/interaction
rg "source_animation_scene|gathering_animation_scene" scenes/player scripts/player
```
