## Data-only description for a tiered item family.
##
## A family is one repeated item line across tiers, such as axes I-VIII,
## planks I-VIII, or ore I-VIII. PrototypeItemCatalog turns this resource into
## one ItemDefinition per tier so new families can be authored as data.
class_name ItemFamilyDefinition
extends Resource

@export var family_id: String = ""
@export var icon_id: String = ""
@export var item_id_prefix: String = ""
@export var category: String = "Resource"
@export var tier_names: PackedStringArray = PackedStringArray()
## Optional per-tier descriptions. When an entry is empty, the catalog falls
## back to the generated prototype description for that tier.
@export var tier_descriptions: PackedStringArray = PackedStringArray()
@export_range(0.0, 1000.0, 0.001) var base_weight: float = 0.0
@export_range(0.0, 1000.0, 0.001) var weight_per_tier: float = 0.0
@export_multiline var usage_text: String = ""
@export_range(1, 999, 1) var max_stack: int = 999
@export var equip_slot: String = ""
## How this family's visual is attached: rigid items use a named bone socket,
## while clothing meshes bind directly to the animated character skeleton.
@export_enum("socket", "skeleton") var equipment_visual_mode: String = "socket"
@export var equipment_scene_path_template: String = ""
## Optional body-specific scene templates for fitted clothing and armor.
## Keys currently use `male` and `female`; the generic scene template remains
## the fallback for equipment that does not vary by body type.
@export var equipment_scene_path_templates_by_body: Dictionary = {}
## Outfit mesh-name fragments hidden while this item is equipped. For example,
## boots replace the starter outfit mesh whose name contains `feet`.
@export var equipment_replaces_outfit_parts: PackedStringArray = PackedStringArray()
@export_file("*.tres") var equipment_attachment_profile_path: String = ""
@export var equipment_animation_profile_path_template: String = ""
## Legacy weapon ability equipped in the player's Q slot.
@export var q_ability_path_template: String = ""
## Optional abilities supplied to action-bar slots by this equipment family.
## Q/W/E belong to weapons, R to chest armor, D to helmets, and F to boots.
## Values are resource path templates and may include `%d` for tier-specific
## definitions. Always-on passives are separate data and do not consume a key.
@export var ability_path_templates: Dictionary = {}
## Optional selectable spell paths keyed by action-bar slot.
##
## Each value may be a path, an array of paths, or dictionaries with `path`,
## `min_tier`, and `max_tier`. The authored default in `ability_path_templates`
## is always included as the first available choice.
@export var ability_choice_path_templates: Dictionary = {}
## Additive player stat bonuses shared by every tier in this family.
@export var stat_modifiers: Dictionary = {}
