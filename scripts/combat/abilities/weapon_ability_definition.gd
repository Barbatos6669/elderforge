## Data for one equipment-provided combat ability.
##
## Item definitions reference these resources. Runtime combat code reads the
## values without hard-coding sword-specific behavior into the player prefab.
class_name WeaponAbilityDefinition
extends Resource

@export var ability_id := ""
@export var display_name := "Weapon Ability"
@export_multiline var description := ""
## Short semantic labels rendered as colored badges in the hover tooltip.
@export var tooltip_tags: PackedStringArray = PackedStringArray()
## Structured, designer-authored effect rows rendered below the description.
@export var tooltip_effects: Array[Resource] = []
@export var input_slot: StringName = &"q"
@export var icon_id := ""
## `selected_target` uses the current hostile target, `direction` enters a
## cursor-driven ground-aim mode, and `self` commits immediately on the wearer.
@export_enum("selected_target", "direction", "self") var targeting_mode := "selected_target"
## Execution behavior stays data-driven so future movement skills can reuse the
## same targeting flow without inheriting damage-only assumptions.
@export_enum("damage", "dodge", "regeneration", "shield") var execution_type := "damage"
@export_range(0.0, 10000.0, 0.1) var energy_cost := 0.0
@export_range(0.0, 120.0, 0.1) var cooldown_seconds := 5.0
@export_range(0.0, 10.0, 0.01) var cast_duration_seconds := 1.0
## Channeled abilities can require a peaceful state before they begin.
@export var requires_out_of_combat := false
## When enabled, confirmed damage interrupts an active channel.
@export var cancel_on_damage := false
## Seconds between healing/resource pulses during a regeneration channel.
@export_range(0.05, 10.0, 0.05) var channel_tick_interval_seconds := 1.0
## Percent of the wearer's maximum health restored by each channel pulse.
@export_range(0.0, 100.0, 0.1) var health_restore_percent_per_tick := 0.0
## Percent of the wearer's maximum energy restored by each channel pulse.
@export_range(0.0, 100.0, 0.1) var energy_restore_percent_per_tick := 0.0
## Multiplier applied to ordinary movement while the channel remains active.
@export_range(0.0, 3.0, 0.05) var movement_speed_multiplier := 1.0
## Damage immunity granted when the cast begins. Zero leaves health unchanged.
@export_range(0.0, 10.0, 0.01) var damage_immunity_seconds := 0.0
## Finite damage shield granted when the cast begins. Zero leaves health unchanged.
@export_range(0.0, 100000.0, 0.1) var absorb_shield_amount := 0.0
## Seconds the finite damage shield remains active.
@export_range(0.0, 30.0, 0.01) var absorb_shield_duration_seconds := 0.0
## Percent of missing energy restored when the cast begins.
@export_range(0.0, 100.0, 0.1) var missing_energy_restore_percent := 0.0
@export_range(0.0, 1.0, 0.01) var impact_fraction := 0.5
@export_range(0.0, 20.0, 0.05) var attack_range := 2.0
@export_range(0.0, 20.0, 0.05) var approach_distance := 1.35
@export_range(0.0, 5.0, 0.05) var impact_range_leeway := 0.35
## Horizontal travel authored for directional movement abilities.
@export_range(0.0, 30.0, 0.05) var movement_distance := 0.0
## Width shown by the directional ground preview.
@export_range(0.1, 10.0, 0.05) var indicator_width := 1.0
## Flat damage applied before physical ability bonuses.
@export_range(0.0, 100000.0, 0.1) var base_damage := 0.0
## Fraction of the attacker's auto-attack damage added to `base_damage`.
@export_range(0.0, 20.0, 0.05) var damage_multiplier := 1.0
@export_file("*.glb", "*.gltf", "*.tscn") var animation_scene_path := ""
@export var animation_name: StringName = &""
## Optional follow-through played immediately after the strike animation.
@export var recovery_animation_name: StringName = &""
