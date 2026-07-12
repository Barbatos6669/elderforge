# NPC Scripts

This folder is for non-combat townsfolk and service NPC behavior.

Files:

- `service_npc_visual_3d.gd`: builds a humanoid NPC from the shared Universal
  Base Character parts. It owns body, hair, outfit, toon material setup, and
  idle/walk animation playback.
- `service_npc_ambient_wander_3d.gd`: moves a service NPC a short distance
  around its placed station. It moves the visual, collider, selectable area, and
  selected ring together so the NPC can stroll without breaking interaction.

GDScript notes:

- `NodePath("../Visuals")` means "from this script's node, go to the parent,
  then find `Visuals`." The service wander node lives beside `Visuals`, `Body`,
  `Selectable`, and `SelectedRing` inside a station scene.
- Exported variables show up in the Godot Inspector. Use them to tune wander
  radius, speed, idle wait time, and whether a selected NPC should pause.
- Service NPCs deliberately do not use full navigation yet. They only need
  small ambient motion until town pathing and job schedules become real systems.
