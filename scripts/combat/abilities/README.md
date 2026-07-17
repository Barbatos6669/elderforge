# Equipment Abilities

Equipment abilities are split into data and runtime behavior:

- `weapon_ability_definition.gd` describes one spell: energy cost, cooldown,
  range and arc, damage type, damage scaling, animation, one or more impact
  timings, optional damage immunity, finite absorb shields, missing-energy
  restoration, and tooltip presentation.
- `weapon_ability_catalog.gd` maps network-safe ids to trusted resources.
- Ability resources live under `assets/combat/abilities/`.
- `player_weapon_abilities.gd` owns targeting, casting, impact, and cooldowns
  for the local player.

An equipped item exposes its active `ability_paths` dictionary keyed by
action-bar slot. Tiered item families author defaults through
`ability_path_templates` and optional selectable lists through
`ability_choice_path_templates`. Choice entries can gate a spell with
`min_tier` and `max_tier`; `PlayerInventory` stores the player's valid choice
and publishes it back through the effective `ability_paths` dictionary. The
canonical active layout is Q/W/E for the weapon, R for chest armor, D for the
helmet, and F for boots. Weapon passives are always-on data and do not consume
an active key. Q, W, and E are independent weapon spell categories with one
selected spell per category. Adding another common equipment spell normally
means creating a `.tres` ability and pointing the item family at it instead of
editing player code.

Targeted cast requests accept an untrusted `Variant` at their public boundary,
then normalize it to a live `Node`. This matters because Godot Node references
do not keep a defeated or unloaded target alive; stale targets are rejected
before typed combat helpers or signals receive them.

Abilities support two targeting modes:

- `selected_target` approaches and attacks the selected hostile target.
- `direction` previews either a movement arrow or damage area toward the mouse
  before the player confirms or cancels the cast.
- `self` commits immediately against the wearer. It can either use the shared
  `PlayerChanneling` timer or apply an instant self effect.

The starter leather boots provide `Dodge Roll` on F. Press F or click its HUD
slot to aim, move the mouse to choose a direction, and left-click to roll.
Right-click continues issuing movement orders while aiming; Escape cancels.
The roll uses the UAL1 `Roll` animation, travels up to four meters with
collision, and has a five-second cooldown. Held right-click keeps refreshing
the queued destination, which resumes immediately when the roll finishes.
Its data resource also grants `0.8` seconds of damage immunity at cast start;
`CombatHealth` owns the exact timer while the player bubble mirrors that state.

The starter leather chest provides `Moonleaf Binding` on R. It is a
seven-second out-of-combat channel that permits movement at half speed. Every
second it restores `9%` maximum health and `7.5%` maximum energy. Damage,
entering combat, starting another action, death, or equipment reset interrupts
the channel; its 30-second cooldown starts when the binding begins. Tune those
values in `assets/combat/abilities/moonleaf_binding.tres` rather than in the
controller.

The starter leather helmet provides `Energizing Shield` on D. It is an instant
self-cast that grants an 834-point absorb shield for three seconds, restores
25% of missing energy, and starts a 21.14-second cooldown. Tune those values in
`assets/combat/abilities/energizing_shield.tres`.

Raw ability damage uses
`(base_damage + auto_attack_damage * damage_multiplier) * (1 + matching_bonus / 100)`.
Physical abilities use the physical ability percentage bonus, magical
abilities use the magical ability percentage bonus, and true damage currently
uses no type bonus. The shared `DamageResolver` then checks armor for physical
damage, magical resistance for magical damage, or bypasses defense for true
damage. Sword Slash on Q uses 100 base physical damage and zero auto-attack
scaling. Whirling Slash on W uses 80 base physical damage plus 150% auto-attack
damage across two equal hits at 36% and 72% of its retargeted animation. Each
hit rechecks hostiles inside the aimed three-meter forward semicircle. The
ability has an independent eight-second cooldown.

Leaping Strike on E is a ground-targeted mobility attack. Its landing circle
follows the cursor up to 3.65 meters away. It travels to that point with
collision, lands at 53% of its 1.8-second cast, and damages enemies in a
1.75-meter circle for 140 base physical damage plus 100% auto-attack damage.
Its player preview shows both the travel path and landing area. Equipped mobs
use the same spell as a gap closer or clustered-area attack and warn players
at the chosen landing circle before impact. Its cooldown is 12 seconds.

Mana is checked when an ability is requested and charged only when its cast
actually begins. Approaching a target or losing it before cast start is free;
an interrupted committed cast remains paid. `ResourcePool.try_spend()` prevents
partial payments when the player cannot afford the full cost.

GDScript notes:

- `&"q"` is a `StringName`, an efficient identifier used for stable slots.
- `equipment_ability_slots.gd` is the canonical list of active keys, HUD slots,
  and equipment ownership. Change that contract instead of copying new key
  lists into several scripts.
- `Dictionary` stores slot-to-ability relationships without adding one field
  for every future action-bar key.
- `signal name(arguments)` declares an event other scripts can observe.
- `as Resource` safely casts a loaded object; a failed cast returns `null`.
