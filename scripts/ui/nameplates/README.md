# Nameplate UI Scripts

Nameplate scripts render labels and status bars above characters or selected
targets in the 3D world.

Files:

- `player_nameplate.gd`: name, first-letter box, guild/alliance line, health,
  mana, relationship health colors, and zoom-stable sizing.
- `nameplate_glyph_atlas.gd`: support resource for atlas-based glyph rendering.

Related scene:

- `scenes/ui/nameplates/PlayerNameplate.tscn`

GDScript notes:

- Nameplates are world-space UI, so they must track camera scale and position.
- Exports on `player_nameplate.gd` are intentionally tuneable in the Inspector.
- The current first-letter style is simple text in a square; gold glyph atlas
  experiments are kept separate.

Use this folder for player/target display above units, not for inventory or HUD.
