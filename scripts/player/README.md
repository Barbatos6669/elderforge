# Player Scripts

The player prefab is intentionally split into small modules. The controller
coordinates them, but each folder owns one job.

Related scene:

- `scenes/player/Player.tscn`

Folders:

- `animation/`: animation playback.
- `audio/`: player-owned sound playback.
- `channeling/`: timed actions such as gathering and future casts.
- `combat/`: player attack behavior.
- `controllers/`: high-level player coordination.
- `feedback/`: click markers and other player-triggered feedback.
- `gathering/`: player-side gathering flow.
- `input/`: local keyboard and mouse interpretation.
- `movement/`: click-to-move motor.
- `stats/`: player stat storage.
- `targeting/`: target selection.
- `visuals/`: facing and visual material styling.

GDScript notes:

- The player controller uses `@onready var module = $ChildName` to cache child
  module nodes from `Player.tscn`.
- Most modules expose public methods instead of reading each other directly.
- This makes it easier to replace a module later, or move authority to a server.

Rule of thumb: if a script starts owning input, movement, animation, inventory,
and UI at the same time, split it.
