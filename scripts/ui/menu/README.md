# Menu UI

The master menu is the fullscreen hub for player-facing submenus.

- `master_menu.gd`: opens with Enter, blocks world input while visible, and
  routes submenu buttons to their real UI panels as those panels are built.
  The first hub buttons are Glossary, Alchemy, Inventory, World Map, Quests,
  and Character. Hovering Glossary reveals the first second-level row:
  Creatures, Tutorial, Characters, Books, and Crafting. The second-level row
  stays open until another main hub button is hovered.
- The category news area below the second-level row updates when a main hub
  button is hover-selected. It is placeholder-driven today, except Inventory
  reads visible bag items and silver from `PlayerInventory` when available.
- The Inventory detail page renders the bound `PlayerInventory` bag slots,
  equipped gear slots, carried weight, and currency. Selecting a bag or gear
  slot updates the right-side item inspector. Drag/drop ownership still lives in
  the retired companion inventory window until the fullscreen menu gets command
  controls.
- Clicking a second-level button, or a main hub button without second-level
  buttons, opens detail mode. Detail mode hides the hub tiles/news, shows the
  section page, and uses the top rotary selector to cycle through Creatures,
  Tutorial, Characters, Books, Crafting, Alchemy, Inventory, World Map, Quests,
  and Character. Escape returns from detail mode to the hub before closing the
  menu.
- The top-left header reads inventory slot usage, carried weight, and silver
  from `PlayerInventory` through `inventory_path` or the `player_inventory`
  group. Max weight comes from `PlayerStats.max_load` when available and falls
  back to 50 kg for the prototype.
- `master_menu_stat_icon.gd`: small code-drawn placeholder icons for menu
  header stats until final icon art is imported.
- `master_menu_tile_icon.gd`: code-drawn placeholder icons inside the six
  square submenu buttons. Replace this with final icon textures when the art is
  ready.

Keep gameplay state in the feature modules. The master menu should only decide
which UI surface to open.
