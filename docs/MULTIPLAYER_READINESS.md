# Multiplayer Readiness

This file is the current truth map for Elderforge multiplayer. It separates
"ready for friend playtests" from "ready for a real MMO economy/combat server."

## Current Playtest Contract

The exported client connects to one headless Godot server over ENet UDP. The
server checks the build gate and playtest code, then relays shared world state.
This is enough for small closed tests where players can move around, gather,
fight mobs, and see each other.

The current server is not yet a production MMO authority. Clients still report
some gameplay actions. That is acceptable for the private playtest, but not for
a public economy or PvP environment.

## Shared Today

| System | Multiplayer State |
| --- | --- |
| Sign in and join | Client reads `playtest_server.cfg`, signs in, submits access code, and auto-joins. |
| Dedicated server boot | The playable level shell removes client-only UI before headless server panels initialize. |
| Player presence | Remote players spawn with nameplates. |
| Player motion | Position, facing, movement animation, and gathering animation are replicated. |
| Player vitals | Health, mana, and death animation state are replicated to remote player copies. |
| Resource nodes | Remaining ticks, depletion, and replenishment are synced by scene path. |
| Hostile mobs | Health, hit feedback, death, respawn, motion/facing, and attack animations are synced. |
| Inventory snapshots | The local bag, equipped slots, silver, and gold have a bounded network snapshot that the server can store. |
| Build updates | GitHub release assets and the launcher manifest point testers to the current build. |

## Prototype-Local Today

| System | Why It Is Not Final Yet |
| --- | --- |
| Inventory rewards | Gathering, looting, crafting, and refining still mutate local `PlayerInventory` first. |
| Loot ownership | Enemy drops are currently personal/prototype drops, not server-owned shared containers. |
| Crafting costs | Refining/crafting validates cost locally. The server does not authoritatively spend resources yet. |
| Equipment stats | Equipment visuals and inventory slots exist, but stat changes are not server-authoritative. |
| Mob AI ownership | The peer fighting a mob can temporarily drive mob motion/attack animation sync. |
| Anti-cheat | The server clamps obvious bad values, but it still trusts several client action reports. |
| Persistence | Accounts, characters, inventory, and world state are not saved to a database yet. |

## Code Rules From Here On

- New gameplay rewards should go through `PlayerInventory` commands or a future
  server service, not directly through UI scripts.
- Any world object that must sync should have a stable scene path or future
  network id. Do not spawn important shared state with random unnamed nodes.
- Any new player-visible action should expose a compact network state or event:
  start, update if needed, complete, cancel.
- UI should never be the authority. UI can ask for an action, but gameplay code
  should validate and apply it.
- Server-only secrets, playtest code hashes, private keys, and tunnel details do
  not belong in the public repo.

## Next Server-Authority Pass

1. Add a server-owned inventory/economy service.
2. Move gathering rewards, loot pickup, refining, and crafting through server
   requests with success/failure replies.
3. Give world-spawned loot containers stable network ids and server ownership.
4. Move hostile mob AI and damage application to the server.
5. Save character inventory, equipment, position, and stats to a database.
6. Replace the playtest code gate with real account/session authentication.

## Quick Test Checklist

- Start the headless server and two clients.
- Sign in on both clients and confirm both can see each other.
- Move, stop, gather, and verify the other client sees the gathering animation.
- Damage a hostile mob and verify both clients see hit numbers, health changes,
  attack animation, death, and respawn.
- Let one player die and verify the other client sees the death animation and
  health bar state.
- Gather a resource and verify depletion/replenishment is visible to both.
