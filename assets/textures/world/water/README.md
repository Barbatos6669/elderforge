# Water Textures

Tileable support textures for the world water material.

- `water_normal_a.png`: broad scrolling wave normal.
- `water_normal_b.png`: tighter scrolling ripple normal.
- `water_foam_noise.png`: foam breakup mask.

Regenerate them with:

```powershell
python tools/art/create_water_textures.py
```

These are generated placeholder maps. They are intentionally stable so the
shader and prefab can be tuned now, then repainted later.
