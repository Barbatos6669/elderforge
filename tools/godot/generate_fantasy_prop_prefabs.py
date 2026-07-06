"""Generate wrapper scene prefabs for Fantasy Props MegaKit runtime models."""

from __future__ import annotations

import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = PROJECT_ROOT / "assets" / "models" / "props" / "fantasy_props_megakit" / "models"
SCENE_DIR = PROJECT_ROOT / "scenes" / "props" / "fantasy_props_megakit"
STYLE_SCRIPT = "res://scripts/visuals/toon_texture_style_3d.gd"


def pascal_case(asset_id: str) -> str:
    return "".join(part.capitalize() for part in re.split(r"[_\s-]+", asset_id) if part)


def scene_text(asset_id: str) -> str:
    node_name = pascal_case(asset_id)
    model_path = f"res://assets/models/props/fantasy_props_megakit/models/{asset_id}.gltf"
    return f"""[gd_scene format=3]

[ext_resource type="PackedScene" path="{model_path}" id="1_model"]
[ext_resource type="Script" path="{STYLE_SCRIPT}" id="2_toon_style"]

[node name="{node_name}" type="Node3D"]
script = ExtResource("2_toon_style")

[node name="Visual" parent="." instance=ExtResource("1_model")]
"""


def main() -> None:
    if not MODEL_DIR.exists():
        raise RuntimeError(f"Missing model folder: {MODEL_DIR}")

    SCENE_DIR.mkdir(parents=True, exist_ok=True)

    generated = []
    for model_path in sorted(MODEL_DIR.glob("*.gltf")):
        scene_path = SCENE_DIR / f"{pascal_case(model_path.stem)}.tscn"
        scene_path.write_text(scene_text(model_path.stem), encoding="utf-8", newline="\n")
        generated.append(scene_path)

    readme_lines = [
        "# Fantasy Props MegaKit Prefabs",
        "",
        "Generated wrapper scenes for the imported Fantasy Props MegaKit models.",
        "",
        "Each prefab keeps the imported model under a `Visual` child and applies",
        "`ToonTextureStyle3D` on the root so the prop uses the same prototype",
        "toon/nearest-filter material style as the character while preserving the",
        "pack's texture atlases.",
        "",
        "Regenerate after adding or removing runtime models:",
        "",
        "```powershell",
        "python tools/godot/generate_fantasy_prop_prefabs.py",
        "```",
        "",
        "Prefabs:",
        "",
    ]
    readme_lines.extend(f"- `{path.name}`" for path in generated)
    (SCENE_DIR / "README.md").write_text("\n".join(readme_lines) + "\n", encoding="utf-8", newline="\n")

    print(f"Generated {len(generated)} fantasy prop prefabs in {SCENE_DIR.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
