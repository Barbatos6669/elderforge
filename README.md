# Elderforge

Elderforge is an original open-source sandbox MMORPG built with Godot. The goal is to create a player-driven online world with gathering, crafting, trade, territory conflict, and classless character progression.

This project may take inspiration from the broad sandbox MMO genre, including games such as Albion Online, EVE Online, RuneScape, and Ultima Online. It must not copy protected code, assets, names, lore, UI, maps, icons, audio, characters, or proprietary game data from any commercial game.

## Current Status

The repository is at the foundation stage. We have a Godot project shell and contributor documentation, but the playable game, backend services, and content pipeline still need to be designed and implemented.

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

1. Install Godot 4.
2. Clone this repository.
3. Open `project.godot` in Godot.
4. Run the project from the editor.

There is not yet a full game loop. See [docs/ROADMAP.md](docs/ROADMAP.md) for the first milestones.

## Contributing

Contributions are welcome once the project direction is clear enough for shared work. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then pick an issue or propose a focused design note before building a large system.

## Licensing

Source code in this repository is licensed under the MIT License. Original non-code assets are intended to be open content, but each asset should include clear license metadata before it is merged. See [LICENSE](LICENSE) and [docs/LICENSING.md](docs/LICENSING.md).
