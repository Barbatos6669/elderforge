# Player Combat Scripts

This folder owns combat behavior that belongs specifically to the player.
Shared combat components live in `scripts/combat/`.

Files:

- `player_auto_attack.gd`: validates hostile targets, moves into range, tracks
  the shared wind-up/impact/recovery timeline, prevents click-spam swing resets,
  and creates typed physical damage requests at valid impact.
- `player_weapon_abilities.gd`: resolves equipment-supplied abilities, targeting
  modes, energy costs, cooldowns, channels, movement effects, self effects, and
  typed damage requests at authored impact timing.

Related scripts:

- `scripts/combat/combat_health.gd`
- `scripts/combat/damage_request.gd`
- `scripts/combat/damage_resolver.gd`
- `scripts/combat/damage_result.gd`
- `scripts/combat/abilities/weapon_ability_definition.gd`
- `scripts/player/targeting/player_targeting.gd`
- `scripts/player/controllers/player_controller.gd`

GDScript notes:

- `has_method("is_hostile")` lets this script work with any selectable target
  that exposes the expected method.
- Signals such as `attack_landed` let the controller trigger animation without
  the attack script knowing about animation nodes.
- Player combat scripts own local intent, target checks, range, and timing.
  Final damage application goes through the shared resolver.

Keep equipment ability behavior separate from auto-attack so both can share
damage and timing contracts without combining their input state.
