# Combat Architecture

This document records the combat contract that player abilities, equipment,
mobs, traits, and multiplayer validation should share.

## Current melee contract

1. Clicking a hostile or pressing Space with one selected engages it.
2. The attacker automatically approaches until it reaches `attack_range`.
3. A swing starts and roots the attacker for its wind-up.
4. Impact validates that both actors are alive, still hostile, and within range.
5. Valid impact applies damage; invalid impact interrupts without damage.
6. Recovery must finish before another swing can start.
7. A movement or stop order clears auto-attack. It does not clear recovery.

At the base player speed of one attack per second, the default cycle is:

- Wind-up: `0.32s`
- Impact: end of wind-up
- Recovery: `0.68s`

The exact wind-up can be tuned per player or mob in the Inspector. Equipped
weapons may instead supply a normalized contact point through their
`EquipmentAnimationProfile`; the one-handed sword currently impacts at `0.49`
of its cycle. Its complete animation is fitted to the same stat-driven cycle,
so attack-speed changes preserve the visual contact point. A small
`impact_range_leeway` prevents normal network/movement jitter from cancelling
a swing after it has already committed.

## Equipment ability contract

1. An equipped item supplies an effective `ability_paths` dictionary keyed by
   action-bar slot. Main-hand weapons own Q/W/E, chest armor owns R, helmets own
   D, and boots own F. Items can also expose tier-gated `ability_choices`;
   `PlayerInventory` validates and persists the player's selected path before
   publishing it through `ability_paths`. Weapon passives are always-on and do
   not consume a cast key.
2. Pressing a bound key or clicking its HUD slot requests the same ability path.
3. `selected_target` abilities approach and validate their hostile target.
4. `direction` abilities preview a ground indicator while ordinary locomotion
   continues. Left-click confirms, right-click steers movement, and Escape
   cancels.
5. `self` channels can use `PlayerChanneling`, including its shared progress
   bar, while item data controls movement speed and interruption rules.
6. A committed cast spends energy, starts its cooldown by stable ability id,
   and plays its authored animation.
7. Damage resolves at each authored impact point; movement abilities ask the
   movement motor for collision-aware forced movement.
8. Every bound HUD slot observes the component and renders remaining cooldown.

The first implementation is `Sword Slash`: a five-second cooldown using the
UAL2 `Sword_Regular_A` strike followed by `Sword_Regular_A_Rec`. Ability data lives in
`assets/combat/abilities/one_handed_sword_q.tres`; adding another weapon Q is a
data hookup unless it needs behavior beyond the common targeted-melee contract.

The same one-handed sword supplies `Whirling Slash` on W. Its user-provided
Mixamo motion is retargeted onto the Elderforge humanoid skeleton, stripped of
horizontal root travel, and fitted to a 1.8-second directional cast. The player
aims a three-meter forward semicircle, then the horizontal and descending
swipes resolve at 36% and 72% of the motion. Each pulse rechecks who remains in
the area and deals half of the total 80 base physical damage plus 150%
auto-attack scaling. Equipped mobs telegraph the same area and prefer W over Q
when it can catch at least two players. Its trusted network id and data live in
`assets/combat/abilities/one_handed_sword_w.tres`.

The first directional implementation is `Dodge Roll`: a five-second-cooldown F
ability supplied by leather boots. It uses the UAL1 `Roll` clip and travels up
to four meters. A collision can shorten the movement. Input cannot replace the
committed roll's velocity. Held right-click still refreshes the queued cursor
destination, so normal locomotion resumes on the first frame after the roll.
At cast start, the ability grants a data-authored `0.8`-second damage-immunity
window. `CombatHealth` enforces that window, and `DamageImmunityBubble3D`
listens to the same state so the visible shield cannot outlive its protection.
Remote casts apply to the server-side player representation before being
relayed, allowing the authority and observing clients to share the same state.

The first self-channel implementation is `Moonleaf Binding`, supplied by
leather chest armor on R. It can start only outside combat, lasts seven seconds,
slows ordinary movement by 50%, and restores 9% max health plus 7.5% max energy
on each one-second pulse. Damage or combat entry interrupts it. The generic
channel timer owns only elapsed time; `PlayerWeaponAbilities` owns the pulses,
cooldown, and equipment-channel context, while `PlayerController` owns the
temporary movement multiplier and combat interruption hooks.

The first instant self-effect implementation is `Energizing Shield`, supplied
by leather helmets on D. It grants an 834-point finite absorb shield for three
seconds, restores 25% of missing energy, and starts a 21.14-second cooldown.
`CombatHealth` drains the absorb pool before health damage and emits shield
state changes that `DamageImmunityBubble3D` mirrors with the same bubble visual
used by short damage-immunity windows.

## Shared damage resolver

Current combat damage enters gameplay as a typed `DamageRequest` and leaves as
a `DamageResult`. Callers still own attack intent, hostility, timing, range, and
target validation. The resolver owns damage-type normalization, defense lookup,
mitigation, and final application through `CombatHealth`:

- `physical` damage checks armor.
- `magical` damage checks magical resistance.
- `true` damage bypasses defense mitigation.

Physical and magical mitigation use
`incoming_damage * 100 / (100 + defense)`. Defense values are clamped to zero,
so this pass does not support negative resistance or vulnerability.

`DamageResult` preserves source, target, health component, damage type,
requested damage, mitigated damage, mitigation amount, defense value, and
actual health damage applied. Player auto-attacks, player equipment abilities,
mob basic attacks, mob equipment abilities, and server-routed mob damage all
use this resolver. Future damage entry points should use the same request/result
contract.

## Damage feedback

`CombatHealth.damage_taken` is the shared confirmation point for floating
numbers and `BloodImpactEmitter3D`. Effects therefore appear only after damage
actually lowers health, at the authored weapon contact frame. Replicated mob
damage emits the same signal on remote clients.

## Ownership

- `scripts/combat/attack_timeline.gd` owns timing only.
- `scripts/player/combat/player_auto_attack.gd` owns player target/range checks
  and resolves player impacts.
- `scripts/player/combat/player_weapon_abilities.gd` owns equipped slot ability
  lookup, target/aim state, ability impacts or movement requests, and cooldowns.
- `scripts/combat/abilities/weapon_ability_definition.gd` owns authored spell
  values; `weapon_ability_catalog.gd` owns network-safe id lookup.
- `scripts/combat/damage_request.gd`, `damage_resolver.gd`, and
  `damage_result.gd` own typed damage inputs, mitigation, application, and
  result metadata.
- `scripts/entities/enemy_mob_ai.gd` owns mob aggro, chase, and mob impacts.
- `scripts/effects/ability_telegraph_3d.gd` owns hostile wind-up and movement
  path warnings; `scripts/debug/mob_aggro_zone_debug_3d.gd` visualizes aggro and
  de-aggro/leash tuning only.
- `scripts/combat/combat_health.gd` owns current/max health and defeat signals.
- `scripts/player/controllers/player_controller.gd` coordinates movement,
  facing, animation, combat state, and input cancellation.
- `scripts/player/animation/equipment_animation_profile.gd` optionally owns an
  equipped weapon's clip and normalized visual contact timing.
- `scripts/network/multiplayer_test_manager.gd` mirrors attack-start visuals,
  weapon-ability visuals, and current playtest mob health.

## Multiplayer boundary

The current playtest transport still accepts a client-reported mob damage
amount, but the server now clamps that value and routes it through the shared
damage resolver. That is adequate only for trusted prototype testing. Before
PvP or a public test, replace the reported damage amount with
server-authoritative attack intent:

1. Client sends attack intent and target id.
2. Server validates attacker state, hostility, range, line of sight, and timing.
3. Server computes damage from authoritative stats, ability data, and defenses.
4. Server applies health changes and broadcasts the result.
5. Clients predict animation/feedback but never decide final damage.

Do not build PvP, critical hits, valuable loot security, or reward ownership on
the current client-reported damage RPC.

## Next combat layers

Implement these in order so later systems use one resolver instead of inventing
their own damage rules:

1. Server-authoritative attack intent, range, timing, and cooldown validation.
2. Server-derived damage from authoritative stats, equipment, and ability data.
3. Replicated result metadata for consistent hit feedback and auditing.
4. Energy costs and cast/channel interruption rules for abilities.
5. Buff/debuff and crowd-control effects.
6. Threat tables, assists, kill credit, XP, and loot ownership.

## Validation

Run the focused combat checks from the repository root:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/combat_damage_resolver_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/weapon_ability_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/weapon_directional_aoe_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/sword_w_animation_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/mob_damage_resolver_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/mob_equipment_ability_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/helmet_shield_ability_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/mob_ability_telegraph_test.gd

& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' `
  --headless --path . `
  --script res://tools/tests/battle_arena_mob_loadout_test.gd
```
