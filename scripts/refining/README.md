# Refining Scripts

World refining station logic lives here.

Files:

- `refining_station_3d.gd`: data attached to a clickable world station. It
  exposes recipe dictionaries and opens a refining UI panel. The sawmill
  prototype generates plank recipes from its item id prefixes. Stations now
  represent service NPCs in the world, but this script still owns their recipe
  tier limits and interaction rules.
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

- `scenes/refining/stations/*.tscn` are clickable service NPC prefabs for
  refining and crafting. They reuse `ServiceNpcVisual3D` for the humanoid art
  and keep recipe generation on the station scripts in this folder.
- `scenes/ui/refining/RefiningPanel.tscn`
- `scenes/ui/npc/ServiceNpcDialogPanel.tscn`

GDScript notes:

- `@export` variables show up in the Godot Inspector, so designers can change
  the station name, input item id, output item id, and recipe quantities without
  editing code.
- `service_level` is the NPC's practical craft/refine skill. A level 1 NPC only
  offers tier I recipes, while a level 8 NPC can offer tiers I-VIII.
- `min_recipe_tier` and `max_recipe_tier` are designer bounds on top of service
  level. Use them when an NPC specializes in only part of the tier ladder.
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
- `interaction_radius` limits station use to actors near the NPC or station
  footprint. It is measured from the footprint edge using
  `interaction_half_extents`, so buildings can use broad footprints while service
  NPCs can use a compact body-sized footprint.
- `get_interaction_destination(actor)` returns a point near the station
  footprint. The player controller uses this when the player clicks a station
  from too far away.
- `get_tree().get_first_node_in_group("refining_panel")` finds the shared UI
  panel when the station does not have a direct `NodePath` assigned.
- `use_service_dialog` opens a small NPC dialogue before the real recipe panel.
  The dialogue is found through the `service_npc_dialog_panel` group unless a
  direct `service_dialog_panel_path` is assigned. Its service button calls
  `open_service_menu()`, which keeps the recipe UI reusable for NPCs and any
  future non-NPC station.
- The station does not remove or add items itself. It gives recipe data to UI,
  and the UI calls `PlayerInventory`.

Use this folder for world-side crafting or refining station behavior. Put menu
layout and button logic in `scripts/ui/refining/`.
