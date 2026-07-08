# Network Scripts

Early multiplayer lives here.

- `multiplayer_test_manager.gd`: direct-connect test harness for small playtests.
  The server process hosts, and signed-in clients auto-join the configured
  playtest address.

This is presence sync only: it lets players see each other moving in the same
scene. Combat, gathering, inventory, loot, and crafting are still local
prototype systems until we move to server-authoritative gameplay.

Press `F9` during play to show or hide the multiplayer test panel. It is hidden
by default now, because normal client flow is sign in -> auto-join.

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

The sign-in scene currently targets `127.0.0.1:24566` by default. For a friend
build, set `AuthPanel.playtest_server_address` to the host LAN/VPN IP before
exporting.

For LAN, the joining player uses the host computer's local IP address.

For internet testing, the host needs UDP port `24565` reachable. The simplest
developer-friendly path is usually a VPN/tunnel such as Tailscale, ZeroTier, or
Radmin VPN; otherwise the host must port-forward UDP `24565` on their router and
allow the game through Windows Firewall.
