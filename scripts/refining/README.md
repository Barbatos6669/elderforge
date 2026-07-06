ok now# Refining Scripts

World refining station logic lives here.

Files:

- `refining_station_3d.gd`: data attached to a clickable world station. It
  exposes recipe dictionaries and opens a refining UI panel. The sawmill
  prototype generates plank recipes from its item id prefixes.
- `refining_station_tier_visuals.gd`: placeholder visual upgrade generator used
  by tiered refining station prefabs. It creates simple trim, posts, canopies,
  and family-specific details until each tier gets authored art.
- `toolmaker_station_3d.gd`: multi-output crafting station for gathering tools.
  It builds one recipe per available tool family per tier while reusing the
  same station interaction and UI flow.
- `weapon_smith_station_3d.gd`: multi-output crafting station for weapon
  families. The first recipe line crafts one-handed swords from refined ingots
  and planks.

Related scenes:

- `scenes/refining/RefiningStationBase.tscn`: shared collision, selection,
  hover, interaction, and script base for new refining station families.
- `scenes/refining/SawmillPrototype.tscn`: shared sawmill base with station
  logic, collision, hover feedback, selection feedback, and the common
  placeholder model.
- `scenes/refining/StonecutterPrototype.tscn`: stone-to-block refining base.
- `scenes/refining/SmelterPrototype.tscn`: ore-to-ingot refining base.
- `scenes/refining/LoomPrototype.tscn`: cotton-to-cloth refining base.
- `scenes/refining/ToolmakerPrototype.tscn`: refined-material-to-tool crafting
  base.
- `scenes/refining/WeaponSmithPrototype.tscn`: refined-material-to-weapon
  crafting base.
- `scenes/refining/sawmills/Tier1Sawmill.tscn` through
  `scenes/refining/sawmills/Tier8Sawmill.tscn`: tier-specific sawmill prefabs.
  Each tier inherits the shared base, sets its own `max_recipe_tier`, and owns
  placeholder visual pieces that can be replaced by tier-specific Blender/GLB
  art later.
- `scenes/refining/stonecutters/Tier1Stonecutter.tscn` through
  `scenes/refining/stonecutters/Tier8Stonecutter.tscn`: tier-specific stone
  refining prefabs.
- `scenes/refining/smelters/Tier1Smelter.tscn` through
  `scenes/refining/smelters/Tier8Smelter.tscn`: tier-specific ore refining
  prefabs.
- `scenes/refining/looms/Tier1Loom.tscn` through
  `scenes/refining/looms/Tier8Loom.tscn`: tier-specific cotton refining
  prefabs.
- `scenes/refining/toolmakers/Tier1Toolmaker.tscn` through
  `scenes/refining/toolmakers/Tier8Toolmaker.tscn`: tier-specific gathering
  tool crafting prefabs.
- `scenes/refining/weapon_smiths/Tier1WeaponSmith.tscn` through
  `scenes/refining/weapon_smiths/Tier8WeaponSmith.tscn`: tier-specific weapon
  crafting prefabs.
- `scenes/ui/refining/RefiningPanel.tscn`

GDScript notes:

- `@export` variables show up in the Godot Inspector, so designers can change
  the station name, input item id, output item id, and recipe quantities without
  editing code.
- `min_recipe_tier` and `max_recipe_tier` control which recipe tiers appear in
  the menu. A tier 1 sawmill only exposes tier I recipes, while a tier 8
  sawmill, stonecutter, smelter, or loom exposes tiers I-VIII.
- `require_lower_tier_refined_input` models the refining ladder: tier 1 recipes
  only consume their raw material, while tier 2+ recipes also consume one
  refined item from the previous tier. For example, `planks_t2` adds
  `planks_t1` as an extra input.
- `input_item_id_prefix` and `output_item_id_prefix` let one script power
  multiple station families. Current mappings are `timber -> planks`,
  `stone -> blocks`, `ore -> ingots`, and `cotton -> cloth`.
- Tool makers craft `axe`, `hammer`, `pickaxe`, `sickle`, and
  `skinning_knife` item families. Their first prototype recipes consume
  refined resources of the same tier. The skinning knife currently asks for
  `worked_leather`, which will become craftable when a hide/tannery station is
  added.
- Weapon smiths craft `one_handed_sword` items. The first prototype recipe
  consumes same-tier `ingots` and `planks`.
- `interaction_radius` limits station use to actors near the building. It is
  measured from the footprint edge using `interaction_half_extents`, so a 4x4
  building can still require the player to stand about 1m from the outside.
- `get_interaction_destination(actor)` returns a point near the station
  footprint. The player controller uses this when the player clicks a station
  from too far away.
- `get_tree().get_first_node_in_group("refining_panel")` finds the shared UI
  panel when the station does not have a direct `NodePath` assigned.
- The station does not remove or add items itself. It gives recipe data to UI,
  and the UI calls `PlayerInventory`.

Use this folder for world-side crafting or refining station behavior. Put menu
layout and button logic in `scripts/ui/refining/`.
