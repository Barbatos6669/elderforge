"""Generate Godot wrapper scenes for custom Barbatos prop models.

The custom art folder keeps the artist-facing files under
`assets/models/props/barbatos_props/`. This script turns each runtime GLB found
there into a reusable scene under `scenes/props/barbatos_props/`.
"""

from __future__ import annotations

import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "assets" / "models" / "props" / "barbatos_props"
PREFAB_ROOT = PROJECT_ROOT / "scenes" / "props" / "barbatos_props"
TOON_STYLE_SCRIPT = "res://scripts/visuals/toon_texture_style_3d.gd"
RUNTIME_MODEL_EXTENSIONS = {".glb", ".gltf"}


def pascal_case(value: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    return "".join(word[:1].upper() + word[1:] for word in words) or "Prop"


def res_path(path: Path) -> str:
    return "res://" + path.relative_to(PROJECT_ROOT).as_posix()


def scene_name_for_model(model_path: Path) -> str:
    relative_parts = model_path.relative_to(SOURCE_ROOT).parts
    prop_folder = relative_parts[0] if relative_parts else model_path.stem

    # The usual workflow is one exported GLB per top-level custom prop folder.
    # If that changes, use the model file name to keep generated scene names
    # stable and unique.
    sibling_models = [
        path
        for path in (SOURCE_ROOT / prop_folder).rglob("*")
        if path.suffix.lower() in RUNTIME_MODEL_EXTENSIONS
    ]
    if len(sibling_models) <= 1:
        return pascal_case(prop_folder)

    return pascal_case(f"{prop_folder}_{model_path.stem}")


def scene_text(scene_name: str, model_path: Path) -> str:
    return f"""[gd_scene format=3]

[ext_resource type="PackedScene" path="{res_path(model_path)}" id="1_model"]
[ext_resource type="Script" path="{TOON_STYLE_SCRIPT}" id="2_toon_style"]

[sub_resource type="BoxShape3D" id="BoxShape3D_collision"]
size = Vector3(2, 2, 2)

[node name="{scene_name}" type="StaticBody3D"]
script = ExtResource("2_toon_style")

[node name="Visual" parent="." instance=ExtResource("1_model")]

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("BoxShape3D_collision")
"""


def main() -> None:
    if not SOURCE_ROOT.exists():
        raise SystemExit(f"Missing source folder: {SOURCE_ROOT}")

    PREFAB_ROOT.mkdir(parents=True, exist_ok=True)

    generated = 0
    model_paths = [
        path
        for path in SOURCE_ROOT.rglob("*")
        if path.suffix.lower() in RUNTIME_MODEL_EXTENSIONS
    ]

    for model_path in sorted(model_paths):
        scene_name = scene_name_for_model(model_path)
        scene_path = PREFAB_ROOT / f"{scene_name}.tscn"
        scene_path.write_text(scene_text(scene_name, model_path), encoding="utf-8")
        generated += 1
        print(f"Generated {scene_path.relative_to(PROJECT_ROOT)}")

    print(f"Generated {generated} Barbatos prop prefab(s).")


if __name__ == "__main__":
    main()
