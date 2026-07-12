# Economy Scripts

Economy scripts own market-facing rules that are bigger than one UI panel or one
NPC.

Files:

- `auction_market.gd`: prototype auction-house service. It stores sell listings
  and buy orders in memory, validates inventory and silver, and exposes narrow
  methods for buy, sell order, buy order, and quick sale flows.
- `auction_house_npc_3d.gd`: world-space service NPC wrapper. The player clicks
  the auctioneer, walks into interaction range, sees the shared NPC dialogue, and
  then opens the auction panel.

GDScript notes:

- `project.godot` autoloads this script as `/root/AuctionMarket`. Keep that
  singleton name stable because UI panels look it up by path.
- `signal market_changed` lets UI refresh when orders change without polling.
- Dictionaries are used for early prototype order records. If the schema grows,
  move these into a typed resource or server database row.

Multiplayer/server note:

The current auction market is client-side prototype logic. Before the auction
house is trusted with player-to-player trading, order creation, quick sale,
inventory changes, and currency changes must be validated on the authoritative
server and persisted in the player database.
