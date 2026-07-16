# Elderforge

Elderforge is an original open-source sandbox MMORPG built with Godot. The goal is to create a player-driven online world with gathering, crafting, trade, territory conflict, and classless character progression.

This project may take inspiration from the broad sandbox MMO genre, including games such as Albion Online, EVE Online, RuneScape, and Ultima Online. It must not copy protected code, assets, names, lore, UI, maps, icons, audio, characters, or proprietary game data from any commercial game.

## Current Status

The repository is an active playable prototype. The current build includes
account and character flow, click-to-move exploration, gathering, refining,
crafting, inventory and equipment, hostile creatures, loot, equipment abilities,
direct-connect friend playtests, and prototype JSON persistence.

Multiplayer replication exists, but several valuable gameplay outcomes still
trust client reports. The active architecture work is moving combat intent,
range/timing checks, stat-derived damage, rewards, and persistence toward
server authority. See [Project State](docs/PROJECT_STATE.md) for the current
feature snapshot and [Multiplayer Readiness](docs/MULTIPLAYER_READINESS.md) for
the authority gaps.

For friend testing, see [Playtest Builds](docs/playtest_builds.md).

## Design Pillars

- Player-driven economy: most equipment and consumables should come from player gathering and crafting.
- Classless progression: gear, skills, and player choices define combat roles.
- Meaningful risk: travel, gathering, and conflict should create interesting decisions.
- Server-authoritative multiplayer: gameplay outcomes must be validated by the server.
- Open development: design, issues, and implementation should happen in public whenever possible.

## Tech Direction

- Engine: Godot 4
- Language: GDScript first, with C# or native extensions only when there is a clear need.
- Networking: server-authoritative architecture, to be prototyped before real game systems depend on it.
- Repository style: small, reviewable changes with issues and design notes attached.

## Getting Started

1. Install Godot 4.7.
2. Clone this repository.
3. Open `project.godot` in Godot.
4. Run the project from the editor.

The normal run path starts at sign-in, continues through character selection or
creation, and then enters Starting City. The current loop is still a prototype;
see [docs/ROADMAP.md](docs/ROADMAP.md) for the remaining milestones.

## Learning the Codebase

If the project feels large, start with [docs/START_HERE.md](docs/START_HERE.md).
Then use [docs/CODEBASE_GUIDE.md](docs/CODEBASE_GUIDE.md) for the longer
walkthrough and [docs/CODEBASE_INDEX.md](docs/CODEBASE_INDEX.md) for fast file
lookup.

## Contributing

Contributions are welcome once the project direction is clear enough for shared work. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then pick an issue or propose a focused design note before building a large system.

## Licensing

Source code in this repository is licensed under the MIT License. Original non-code assets are intended to be open content, but each asset should include clear license metadata before it is merged. See [LICENSE](LICENSE) and [docs/LICENSING.md](docs/LICENSING.md).
