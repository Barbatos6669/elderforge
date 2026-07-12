# Auction UI

The auction UI displays market data and forwards player actions to
`/root/AuctionMarket`.

Files:

- `auction_house_panel.gd`: fullscreen-blocking market window with four prototype
  modes: buy listings, create sell order, create buy order, and quick sale.

Flow:

1. Player clicks the `AuctionHouseNpc` in the world.
2. The shared NPC service dialogue opens.
3. Choosing the service opens `AuctionHousePanel`.
4. The panel reads player inventory and silver, then calls `AuctionMarket`.

GDScript notes:

- `CanvasLayer` keeps the auction window independent from the 3D camera.
- The panel joins `blocking_world_input` so click-to-move does not fire while the
  market window is open.
- The UI should not own item prices permanently. It can display and submit
  numbers, but market rules belong in `scripts/economy/`.
