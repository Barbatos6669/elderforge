# Next Task

Last updated: 2026-07-11

This file is the handoff note for the next work session. Replace it when the
active task changes.

## Current Focus

Keep migrating real gameplay data into the new full-screen master menu while
protecting the current playable loop.

## Immediate Follow-Up

1. Visually verify the character outfit fix in gameplay and character creation.
   Outfits should hide the base torso/limbs, but the customized head should
   remain visible.
2. Tune the head clip values only if the neck or face is visibly cut off.
3. Continue plugging real data into master menu pages. Crafting is connected;
   likely next pages are Character stats/traits, Inventory, or Creatures.

## Useful Files

- `docs/PROJECT_STATE.md`
- `docs/DECISIONS.md`
- `docs/lore/RESOURCE_NAME_ALIGNMENT.md`
- `scripts/ui/menu/master_menu.gd`
- `scripts/crafting/crafting_recipe_catalog.gd`
- `scripts/player/visuals/player_visual_style.gd`
- `scripts/ui/auth/character_appearance_preview.gd`
- `scripts/visuals/character_appearance_assets.gd`
- `assets/materials/characters/experimental_toon.gdshader`
- `assets/materials/characters/toon_black_outline.gdshader`

## Acceptance Checks

- `git diff --check` passes.
- Starting city scene loads headless.
- Player scene loads headless after player visual changes.
- Character customization scene loads headless after appearance changes.
- The master menu can open with Enter and close without breaking gameplay input.

## Working Rules

- Do not revert user-created scene, model, or asset changes unless explicitly
  asked.
- Keep game data moving toward catalogs/resources instead of one-off UI code.
- Update `PROJECT_STATE.md` and this file when a major feature lands.
- Append to `DECISIONS.md` when we make a choice that future contributors need
  to respect.
