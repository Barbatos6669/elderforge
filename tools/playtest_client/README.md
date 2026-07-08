# Playtest Client

This folder contains the tiny Windows launcher used by external playtesters.

The launcher is intentionally separate from the game export. It checks the
GitHub release manifest, downloads the newest playtest zip when the build id
changes, installs it into a local `Game/` folder, then starts
`Elderforge_Playtest.exe`.

Why this exists:

- A running game exe cannot safely overwrite itself.
- Testers should download one small client once instead of replacing the full
  game zip every time.
- The updater can fall back to the locally installed game if GitHub is briefly
  unreachable.

`build_windows_playtest.ps1` packages these files into
`Elderforge_Playtest_Client.zip` and writes `client_config.json` with the active
release URLs.
