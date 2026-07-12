# Crafting Scripts

This folder holds shared crafting data helpers.

- `crafting_recipe_catalog.gd` builds a read-only list of prototype recipes for UI pages such as the master menu.
- World stations still perform the actual craft/refine action. Keep station logic and catalog data in sync until recipes move into data resources.

GDScript note: `static func` means the function can be called on the script/class itself, so UI code can ask `CraftingRecipeCatalog.create_recipes()` without placing a node in the scene.
