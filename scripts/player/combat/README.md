# Player Combat Scripts

This folder owns combat behavior that belongs specifically to the player.
Shared combat components live in `scripts/combat/`.

Files:

- `player_auto_attack.gd`: validates hostile targets, moves into range, tracks
  attack cooldown, prevents click-spam swing resets, and applies prototype
  damage.

Related scripts:

- `scripts/combat/combat_health.gd`
- `scripts/player/targeting/player_targeting.gd`
- `scripts/player/controllers/player_controller.gd`

GDScript notes:

- `has_method("is_hostile")` lets this script work with any selectable target
  that exposes the expected method.
- Signals such as `attack_landed` let the controller trigger animation without
  the attack script knowing about animation nodes.

Keep spell abilities separate later. Auto-attack is the simple baseline loop.
