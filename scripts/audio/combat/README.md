# Combat Audio

`combat_sound_set.gd` defines reusable sound data for one combat style. The
player-owned playback component lives in `scripts/player/audio/` because it
binds those shared clips to player combat signals.

The three sound moments are intentionally separate:

- `swing_streams`: attack wind-up begins.
- `impact_streams`: damage is confirmed by the attacker.
- `hurt_streams`: this character's health actually decreases.

Keeping impact and hurt separate allows a later material system to combine a
weapon sound with target-specific flesh, armor, stone, or wood feedback.
