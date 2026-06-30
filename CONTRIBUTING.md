# Contributing to Elderforge

Thanks for helping build Elderforge. This is an early-stage open-source MMORPG, so small, well-explained contributions are much easier to review than sweeping rewrites.

## Ground Rules

- Keep the project original. Do not submit copied assets, code, data, UI layouts, names, lore, or icons from Albion Online or any other commercial game.
- Prefer public design notes for major systems before implementation.
- Keep pull requests focused on one behavior, system, or document.
- Add tests or reproduction steps when changing gameplay, networking, persistence, or tooling.
- Document third-party assets and dependencies before adding them.

## Local Development

1. Install Godot 4.
2. Open `project.godot`.
3. Make changes in a feature branch.
4. Run the project and describe what you tested in your pull request.

## Commit Style

Use short, direct commit messages:

```text
Add inventory slot prototype
Document server authority model
Fix camera zoom limits
```

## Design Proposals

Use a design proposal for large systems such as combat, territory ownership, economy simulation, networking, account services, or persistence. A good proposal names:

- The player problem being solved.
- The server and client responsibilities.
- The data that must be persisted.
- Failure cases and abuse cases.
- The smallest useful prototype.
