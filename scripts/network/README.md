# Network Scripts

Early multiplayer lives here.

- `multiplayer_test_manager.gd`: direct-connect test harness for small playtests.
  The server process hosts, and signed-in clients auto-join the configured
  playtest address. Auto-join retries briefly after the world loads so the
  sign-in-to-world handoff does not miss the connection window.

This is still a prototype harness, but it now shares the most visible world
state for friend playtests:

- player presence, movement, facing, and gathering animation state
- remote player health, mana, and death animation state
- gatherable resource tick counts, including depletion and replenishment
- hostile mob health, movement/facing animation, attack-start events, death, hit
  feedback, respawn visibility, and server-routed shared damage resolution
- bounded inventory/equipment/currency snapshots sent to the server for the
  next inventory-authority pass
- local chat messages relayed through the server after playtest-code approval

Inventory rewards, loot ownership, crafting costs, and anti-cheat validation are
still local/prototype systems until we move to server-authoritative gameplay.
For now the server relays and lightly clamps client action reports so everyone
sees the same world during playtests. Hostile mob animation is still client
reported: the peer currently fighting a mob drives the temporary movement and
attack animation sync until we replace this with server-owned AI.

Mob damage is also still initiated by a client-reported amount. The server
clamps it and applies it through `DamageRequest`/`DamageResolver`, but it does
not yet validate attack intent, range, timing, cooldowns, or authoritative
attacker stats. Do not treat current combat, PvP, XP, or loot ownership as
secure until that report is replaced with a server-validated attack request.

See `docs/MULTIPLAYER_READINESS.md` for the current readiness matrix and the
order we should convert systems to server authority.

Press `F9` during play to show or hide the multiplayer test panel. It is hidden
by default now, because normal client flow is sign in -> auto-join.

## Playtest Code

The direct-connect server can require a playtest access code before accepting
client state. This is a lightweight gate for early friend tests, not production
authentication.

Start the server with a private code:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --server --port=24566 --playtest-code="your-private-code"
```

Clients enter that code on the sign-in screen. Exported builds may include
`playtest_server.cfg` with `playtest.require_code=true`, but the accepted hash
belongs on the server launch command or in private server config. Do not commit
or ship the raw code.

## Testing

For two copies on one machine, host in one game window and join `127.0.0.1` from
the other.

## Local Dedicated Test Server

You can run a server process on the development PC while another game/editor
window joins it. This gives us the same workflow we will later use on a Pi or a
hosted Linux box, but without waiting for hardware.

From the project folder:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --server
```

Then press play in Godot, sign in, and the client auto-joins:

- IP: `127.0.0.1`
- Port: `24565`

If that port is already busy, run the server on another port:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --server --port=24566
```

The sign-in scene targets `127.0.0.1:24566` by default in-editor. Exported
playtest zips can include `playtest_server.cfg` beside the exe to point players
at the active tunnel without making them type an IP.

For LAN, the joining player uses the host computer's local IP address.

For internet testing, the host needs UDP port `24565` reachable. The simplest
developer-friendly path is usually a VPN/tunnel such as Tailscale, ZeroTier, or
Radmin VPN; otherwise the host must port-forward UDP `24565` on their router and
allow the game through Windows Firewall.
