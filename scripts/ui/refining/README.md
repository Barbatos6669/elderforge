# Refining UI Scripts

This folder renders station menus for station actions, starting with refining
raw resources into processed materials and crafting tools at the tool maker.

Files:

- `refining_panel.gd`: modal menu that reads recipes from a clicked station,
  lets the player select a recipe from a dropdown, counts required inventory
  items, channels the selected action, consumes inputs, and grants outputs.

Related scripts:

- `scripts/refining/refining_station_3d.gd`
- `scripts/inventory/player_inventory.gd`

GDScript notes:

- `open_for_station(station)` is the public entry point used by the player
  controller. It asks the station for `get_refining_recipes()`, falling back to
  `get_refining_recipe()` for older single-recipe stations.
- Recipes can provide `recipe_label` and `action_text` when the dropdown or
  primary button needs station-specific wording, such as tool crafting.
- Recipes can provide `seconds_per_action` to control channel time. The panel
  multiplies that value by the selected quantity, so crafting 3 tools at 1s
  each takes a 3s channel.
- `Dictionary` values are key/value bags. This panel expects keys like
  `input_item_id`, `input_quantity`, `output_item_id`, and `output_quantity`.
- Signals such as `slots_changed` let the UI refresh when inventory changes,
  without polling every frame.

Keep item ownership rules in `scripts/inventory/`. This folder should only
handle what the player sees and clicks.
