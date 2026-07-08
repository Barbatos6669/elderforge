# Playtest Builds

The project is testable as a small Windows playtest build. This is not a public
demo yet: the login is local-only, multiplayer is direct-connect presence sync,
and gameplay authority is not server-owned.

## Build A Windows Zip

Install export templates once from Godot:

1. Open Godot.
2. Go to `Editor > Manage Export Templates`.
3. Download and install templates for the current Godot version.

Then run this from the project root:

```powershell
.\tools\build_windows_playtest.ps1
```

If PowerShell script execution is blocked, use the wrapper instead:

```bat
tools\build_windows_playtest.bat
```

The output is:

```text
builds/packages/Elderforge_Windows_Playtest.zip
```

Send that zip to your tester. They should extract the folder and run
`Start_Elderforge_Playtest.bat`. The launcher passes the playtest server address
into the game, then the tester signs in or uses Guest.

To package a build for a specific LAN or VPN host:

```powershell
.\tools\build_windows_playtest.ps1 -ServerAddress 192.168.1.50 -ServerPort 24566
```

To package a build that asks for a playtest code, mark the package as code-gated.
The client package does not store the raw code or accepted hash; it only knows
to ask the tester for a code:

```powershell
.\tools\build_windows_playtest.ps1 -ServerAddress thursday-scottish.gl.at.ply.gg -ServerPort 54355 -RequirePlaytestCode
```

## Multiplayer Friend Test

Run the test server on the host PC:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --server --port=24566
```

To require the same playtest code on the server, launch it with either the raw
code or its hash. Prefer keeping this in a private note or local environment
variable, not in the public repo:

```powershell
& 'C:\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path . --server --port=24566 --playtest-code="your-private-code"
```

The tester signs in and the client auto-joins the configured playtest server.
`F9` still opens the manual multiplayer panel for debugging. The client also
accepts `--connect=address:port`, `--playtest-server=address:port`,
`--connect-port=port`, `--playtest-port=port`, `--playtest-code=code`, and
`--playtest-code-hash=sha256`.

For LAN, use the host computer's local IP. For internet tests, use a VPN-style
tool such as Tailscale/ZeroTier/Radmin, or forward UDP on the chosen port.

## Current Test Scope

Good things for testers to try:

- Sign in or use Guest.
- Move, zoom, and click around the starting city.
- Confirm the client auto-connects after sign-in.
- Hover/select the player and resources.
- Gather starter resources.
- Open inventory and inspect stats.
- Join a local/direct-connect multiplayer session and confirm both players see
  each other move.

Known prototype limits:

- No real account backend.
- No authoritative MMO server yet.
- The playtest code is a lightweight gate, not production security. Traffic is
  still prototype direct-connect networking, so treat the code like a temporary
  playtest password.
- Combat, gathering, inventory, crafting, and loot are still local prototype
  systems.
