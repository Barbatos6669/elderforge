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
5. The smaller scripts under `scripts/player/` - movement, input, animation,
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

docs/
  CODEBASE_GUIDE.md     This file.
  DESIGN_BOUNDARIES.md  What we can and cannot copy from other games.
  LICENSING.md          Asset and license rules.
  ROADMAP.md            Milestones.

scenes/
  camera/    Reusable camera rig scene.
  debug/     Debug-only helper scenes.
  effects/   Visual effects such as click indicators.
  main/      Current playable test scene.
  player/    Reusable player prefab.

scripts/
  audio/     Shared audio data/resources.
  camera/    Camera behavior.
  debug/     Debug helper behavior.
  effects/   Effect behavior.
  player/    Player-specific systems.
  ui/        UI and world-space display helpers.
```

## Player Prefab

`scenes/player/Player.tscn` is the main player prefab. The goal is that this
scene can be dropped into any playable scene and work immediately.

Current child nodes:

- `Input` reads mouse/keyboard intent.
- `Stats` stores player stat values and metadata.
- `Movement` moves the `CharacterBody3D` toward a destination.
- `Facing` rotates the visual model toward movement direction.
- `VisualStyle` applies the current toon-like placeholder material style.
- `Animation` loads idle/jog animations onto the character model.
- `FootstepAudio` plays surface footsteps in sync with animation timing.
- `ClickFeedback` spawns the yellow click marker.
- `Visuals/BaseCharacter` is the current placeholder character model.
- `CollisionShape3D` defines the player collision capsule.
- `CameraTarget` is the point the camera follows.
- `CameraRig` is the perspective isometric camera instance.
- `Nameplate` renders a temporary player name above the character.

The root `Player` node uses `scripts/player/controllers/player_controller.gd`.
That controller should stay small. Its job is to coordinate the modules, not to
own every system.

## Player Controller Flow

Every physics frame, `PlayerController` does this:

1. If input is disabled, stop movement, animation, and footsteps.
2. If `S` is held, stop movement.
3. Otherwise, ask `PlayerInput` whether the mouse is pointing at a movement
   target.
4. If a new click started, ask `PlayerClickFeedback` to spawn the click marker.
5. Ask `PlayerMovementMotor` to move toward the destination.
6. Ask `PlayerFacing` to rotate the visual model.
7. Tell animation and footstep audio whether the player is currently moving.

This means movement, visuals, animation, audio, and feedback can change without
rewriting the whole player controller.

## Input

`scripts/player/input/player_input.gd`

Responsibilities:

- Reads left mouse and right mouse.
- Allows holding either mouse button to keep updating the move destination.
- Reads `S` as stop.
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

Responsibilities:

- Find the animation source scene's `AnimationPlayer`.
- Copy selected animations into a runtime library.
- Loop idle and jog animations.
- Slow the jog with `move_speed_scale`.
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

Because the game camera is perspective, `PlayerNameplate` can compensate for
zoom by adjusting its generated `Sprite3D.pixel_size` every frame. Keep
`keep_screen_size_on_zoom` enabled when the nameplate should stay the same
apparent size as the camera scrolls in and out. `compensate_height_on_zoom`
also lowers the local nameplate position during zoom-in so the plate stays
visually attached to the character.

The health and mana bars use `status_bar_segments` and
`status_bar_segment_gap` so combat readability can be tuned without changing
the rest of the nameplate layout.

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
runtime. It is a prototype styling pass, not the final character customization
system.

Later refactor:

- Move character appearance into data resources.
- Add equipment meshes/materials.
- Separate base body, hair, eyes, armor, weapons, and cosmetic overrides.

## Asset Notes

Current third-party assets are documented near the assets themselves:

- Character model/license: `assets/characters/base/`
- Animation packs/license: `assets/animations/`
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
- No inventory/equipment system yet.
- Stats are tracked but not applied to movement/combat formulas yet.
- No combat abilities yet.
- No terrain surface detector yet.
- No save/load persistence yet.
- No character creation or account system yet.

The next systems should stay small and testable: inventory data, equipment data,
stat modifiers, terrain surface detection, or a first ability prototype.
