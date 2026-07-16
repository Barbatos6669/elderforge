# Effects Scripts

Small visual effects live here. These scripts should be reusable and should
usually free themselves when the effect is over.

Files:

- `blood_impact_emitter_3d.gd`: reusable low-poly blood burst that listens to
  confirmed `CombatHealth.damage_taken` events without allocating per hit.
- `click_move_indicator.gd`: double-ring click marker that grows and fades on
  the ground.
- `directional_ability_indicator.gd`: reusable gold ground disc and arrow used
  to preview a directional ability's heading and travel distance.
- `damage_immunity_bubble_3d.gd`: listens to `CombatHealth` and displays a
  lightweight shield sphere while timed damage immunity or a finite absorb
  shield is active.
- `channel_aura_3d.gd`: mirrors one ability-specific `PlayerChanneling`
  context with a soft ground glow and lightweight upward motes.

Related scene:

- `scenes/effects/BloodImpactEmitter3D.tscn`
- `scenes/effects/ClickMoveIndicator.tscn`
- `scenes/effects/DirectionalAbilityIndicator.tscn`
- `scenes/effects/DamageImmunityBubble3D.tscn`
- `scenes/effects/MoonleafChannelAura3D.tscn`

GDScript notes:

- Tweens animate values over time without writing manual frame logic.
- `queue_free()` removes the effect node after it finishes.

Use this folder for one-off visual effects, not for long-lived UI or character
logic.
