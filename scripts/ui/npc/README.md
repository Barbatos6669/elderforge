# NPC UI Scripts

Small NPC-facing UI panels live here. These scripts should describe services
and route player choices, while world scripts still own gameplay rules.

Files:

- `service_npc_dialog_panel.gd`: bottom-screen dialogue panel for service NPCs.
  It shows the NPC name, role, description, and actions. The Refine/Craft button
  calls back into the station's `open_service_menu()` method.

GDScript notes:

- `add_to_group("service_npc_dialog_panel")` lets stations find the shared
  panel without hard-coding scene paths.
- `blocking_world_input` tells player input code that world movement should
  pause while the dialogue is open.
- The panel does not own recipes, inventory, costs, or crafting results. Those
  stay in refining/crafting systems so NPC dialogue can be replaced later
  without rewriting production rules.
