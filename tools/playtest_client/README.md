# Playtest Launcher

This folder contains the Windows launcher used by external playtesters.

The launcher is intentionally separate from the game export. It opens a small
launcher window, checks the GitHub release manifest, downloads the newest
playtest zip when the build id changes, installs it into a local `Game/`
folder, shows the Azure server status, checks the server's required build id,
then starts `Elderforge_Playtest.exe`.

Why this exists:

- A running game exe cannot safely overwrite itself.
- Testers should download one small client once instead of replacing the full
  game zip every time.
- The updater can fall back to the locally installed game if GitHub is briefly
  unreachable.
- Server status comes from a tiny HTTP endpoint on the playtest server. It does
  not expose the playtest code or any private credentials.
- If the server is in maintenance or requires a newer build, the launcher blocks
  Play until the tester updates.

`build_windows_playtest.ps1` packages these files into
`Elderforge_Playtest_Client.zip` and writes `client_config.json` with the active
release URLs and server status URL.

Tester entry point:

- `Elderforge_Playtest_Launcher.exe` is the normal no-console launcher.
- `Elderforge_Playtest_Client.bat` is a fallback for debugging.

Launcher UI/updater changes are shipped by replacing `Elderforge_Playtest_Client.zip`.
Game builds still update automatically through the launcher after the client is installed.
