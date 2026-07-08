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
@export var equipment_scene_path_template: String = ""
@export_file("*.tres") var equipment_attachment_profile_path: String = ""
@export var equipment_animation_profile_path_template: String = ""
