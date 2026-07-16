# Next Task

Last updated: 2026-07-16

This file is the handoff note for the next work session. Replace it when the
active task changes.

## Current Focus

Continue the combat authority lane by replacing trusted client-reported mob
damage with server-validated attack intent, range, timing, and stat-derived
damage.

## Immediate Follow-Up

1. Replace the current mob-damage report payload with an attack-intent request
   that identifies attacker, target, ability or attack id, and client timing.
2. Validate attacker state, hostility, distance, cooldown/recovery timing, and
   line of sight on the server before creating the `DamageRequest`.
3. Derive final damage from server-owned stats, equipment, and ability data,
   then replicate a compact result for hit feedback, death, XP, and loot hooks.

## Useful Files

- `docs/PROJECT_STATE.md`
- `docs/DECISIONS.md`
- `docs/COMBAT_ARCHITECTURE.md`
- `docs/MULTIPLAYER_READINESS.md`
- `scripts/combat/damage_request.gd`
- `scripts/combat/damage_resolver.gd`
- `scripts/combat/damage_result.gd`
- `scripts/network/multiplayer_test_manager.gd`
- `scripts/player/combat/player_auto_attack.gd`
- `scripts/entities/enemy_mob_ai.gd`
- `tools/tests/combat_damage_resolver_test.gd`
- `tools/tests/mob_damage_resolver_test.gd`
- `tools/tests/weapon_ability_test.gd`

## Acceptance Checks

- `git diff --check` passes.
- `combat_damage_resolver_test.gd` passes.
- `weapon_ability_test.gd` passes.
- `mob_damage_resolver_test.gd` passes.
- A two-client smoke test still shows mob hit numbers, health changes, death,
  and respawn on both clients.

## Working Rules

- Do not revert user-created scene, model, or asset changes unless explicitly
  asked.
- Keep game data moving toward catalogs/resources instead of one-off UI code.
- Update `PROJECT_STATE.md` and this file when a major feature lands.
- Append to `DECISIONS.md` when we make a choice that future contributors need
  to respect.
