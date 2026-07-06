"""Generate wrapper scene prefabs for Free 3D Modular Game Assets models."""

from __future__ import annotations

import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
PACK_ID = "free_3d_modular_game_assets_for_prototyping"
MODEL_DIR = PROJECT_ROOT / "assets" / "models" / "props" / PACK_ID / "models"
SCENE_DIR = PROJECT_ROOT / "scenes" / "props" / PACK_ID
STYLE_SCRIPT = "res://scripts/visuals/toon_texture_style_3d.gd"
MESH_COLLISION_SCRIPT = "res://scripts/visuals/visual_mesh_collision_shape_3d.gd"
VISUAL_TRANSFORMS = {
    # The sample character imports with its skinned mesh below the wrapper root.
    # Keep the prefab bottom-centered like the rest of the static pieces.
    "character": "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.003, 1.953, 0.012)",
}


def pascal_case(asset_id: str) -> str:
    return "".join(part.capitalize() for part in re.split(r"[_\s-]+", asset_id) if part)


def scene_text(asset_id: str) -> str:
    node_name = pascal_case(asset_id)
    model_path = f"res://assets/models/props/{PACK_ID}/models/{asset_id}.gltf"
    visual_transform = VISUAL_TRANSFORMS.get(asset_id, "")
    visual_transform_line = f"\ntransform = {visual_transform}" if visual_transform else ""
    return f"""[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" path="{model_path}" id="1_model"]
[ext_resource type="Script" path="{STYLE_SCRIPT}" id="2_toon_style"]
[ext_resource type="Script" path="{MESH_COLLISION_SCRIPT}" id="3_mesh_collision"]

[node name="{node_name}" type="StaticBody3D"]
script = ExtResource("2_toon_style")

[node name="Visual" parent="." instance=ExtResource("1_model")]{visual_transform_line}

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
script = ExtResource("3_mesh_collision")
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
        "# Free 3D Modular Game Assets Prefabs",
        "",
        "Generated wrapper scenes for the imported modular prototyping models.",
        "",
        "Each prefab keeps the imported model under a `Visual` child and applies",
        "`ToonTextureStyle3D` on the root so the prop uses the same prototype",
        "toon/nearest-filter material style as the character.",
        "",
        "The root is a `StaticBody3D` on the World physics layer. Its",
        "`CollisionShape3D` uses `VisualMeshCollisionShape3D` to build a static",
        "mesh collider from the visible model at runtime.",
        "",
        "Regenerate after adding or removing runtime models:",
        "",
        "```powershell",
        "python tools/godot/generate_modular_prototyping_prefabs.py",
        "```",
        "",
        "Prefabs:",
        "",
    ]
    readme_lines.extend(f"- `{path.name}`" for path in generated)
    (SCENE_DIR / "README.md").write_text("\n".join(readme_lines) + "\n", encoding="utf-8", newline="\n")

    print(f"Generated {len(generated)} modular prototyping prefabs in {SCENE_DIR.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
