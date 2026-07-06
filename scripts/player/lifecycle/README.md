# Player Lifecycle Scripts

This folder owns player lifetime state: death, respawn, and future checkpoint or
bind-point behavior.

Files:

- `player_respawn.gd`: listens for `CombatHealth.defeated`, plays the death
  animation, waits for the respawn timer, restores health/resources, and moves
  the player back to a spawn transform.

Related scene:

- `scenes/player/Player.tscn`

GDScript notes:

- `await get_tree().create_timer(seconds).timeout` pauses that function until the
  timer finishes. Other gameplay keeps running.
- `NodePath("../Health")` means "look for a sibling node named Health."
- Signals such as `death_started` let the controller disable input without this
  module needing to know how movement, gathering, or UI work.

Keep this folder focused on lifecycle rules. Combat math belongs in
`scripts/combat/`, and input/movement still belongs in their player folders.
