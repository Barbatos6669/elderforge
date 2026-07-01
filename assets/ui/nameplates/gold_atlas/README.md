# Gold Nameplate Glyph Atlas

This folder contains a generated fantasy-style glyph sheet intended for player
nameplates.

Files:

- `nameplate_gold_source.png` preserves the original green-background source.
- `nameplate_gold_atlas.png` is the chroma-keyed transparent runtime atlas.
- `nameplate_gold_glyph_regions.json` stores generated crop rectangles for
  `A-Z` and `0-9`.
- `nameplate_gold_glyph_atlas.tres` wraps the texture and metadata for Godot.

Source: generated image provided by the project owner from
`C:\Users\Larry\Downloads\ChatGPT Image Jun 30, 2026, 07_23_04 PM.png`.

The current atlas only supports uppercase English letters and digits. Player
names should be validated or rendered with a fallback font before supporting
other characters.
