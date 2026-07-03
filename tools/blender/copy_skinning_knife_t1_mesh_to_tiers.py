"""Copy the edited T1 skinning knife mesh to other tiers while preserving colors.

Run with Blender from the project root:

    blender --background --python tools/blender/copy_skinning_knife_t1_mesh_to_tiers.py

The script treats
`assets/equipment/tools/skinning_knives/t1/source/t1_skinning_knife.blend`
as the shape master. It saves tier-specific `.blend` files for T2-T8, recolors
the tier-colored blade material, and exports each runtime GLB.
"""

from __future__ import annotations

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SKINNING_KNIFE_ROOT = PROJECT_ROOT / "assets" / "equipment" / "tools" / "skinning_knives"
SOURCE_BLEND = SKINNING_KNIFE_ROOT / "t1" / "source" / "t1_skinning_knife.blend"

TIER_COLORS = {
    1: (0.72, 0.72, 0.72, 1.0),
    2: (0.72, 0.50, 0.30, 1.0),
    3: (0.20, 0.62, 0.25, 1.0),
    4: (0.20, 0.42, 0.82, 1.0),
    5: (0.78, 0.18, 0.16, 1.0),
    6: (0.92, 0.48, 0.14, 1.0),
    7: (0.95, 0.82, 0.18, 1.0),
    8: (0.94, 0.94, 0.90, 1.0),
}

TIER_NAMES = {
    1: "Crude",
    2: "Rough",
    3: "Sturdy",
    4: "Forged",
    5: "Hardened",
    6: "Runed",
    7: "Sunsteel",
    8: "Elder",
}

FIXED_MATERIAL_HINTS = (
    "wood",
    "leather",
    "wrap",
    "dark",
    "socket",
    "collar",
    "bright",
    "edge",
    "tip",
    "pommel",
    "cap",
    "base",
    "plate",
    "guard",
    "ring",
)


def main() -> None:
    if not SOURCE_BLEND.exists():
        raise RuntimeError(f"Missing source blend: {SOURCE_BLEND}")

    for tier in range(1, 9):
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))
        root = _find_t1_root()
        if root is None:
            raise RuntimeError("Could not find root object 'T1SkinningKnife' in the T1 skinning knife source.")

        root.name = f"T{tier}SkinningKnife"
        root["elderforge_note"] = (
            f"One-handed T{tier} skinning knife copied from the edited T1 shape. "
            f"Edit this blend and re-export t{tier}_skinning_knife.glb."
        )
        _rename_meshes(root, tier)
        _retier_materials(root, tier)

        blend_path = SKINNING_KNIFE_ROOT / f"t{tier}" / "source" / f"t{tier}_skinning_knife.blend"
        export_path = SKINNING_KNIFE_ROOT / f"t{tier}" / "models" / f"t{tier}_skinning_knife.glb"
        blend_path.parent.mkdir(parents=True, exist_ok=True)
        export_path.parent.mkdir(parents=True, exist_ok=True)

        if tier > 1:
            bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
        export_hierarchy(root, export_path)
        print(f"Exported T{tier} skinning knife to {export_path}")


def _find_t1_root() -> bpy.types.Object | None:
    root = bpy.data.objects.get("T1SkinningKnife")
    if root is not None:
        return root

    for obj in bpy.context.scene.objects:
        if obj.parent is None and "skinning" in obj.name.lower() and "knife" in obj.name.lower():
            return obj
    return None


def _rename_meshes(root: bpy.types.Object, tier: int) -> None:
    for obj in [root, *root.children_recursive]:
        obj.name = obj.name.replace("T1", f"T{tier}")
        if obj.type == "MESH" and obj.data is not None:
            obj.data.name = obj.data.name.replace("T1", f"T{tier}")


def _retier_materials(root: bpy.types.Object, tier: int) -> None:
    material_map: dict[bpy.types.Material, bpy.types.Material] = {}
    for obj in root.children_recursive:
        if obj.type != "MESH":
            continue

        for slot in obj.material_slots:
            source_material = slot.material
            if source_material is None:
                continue

            if source_material not in material_map:
                material_map[source_material] = _make_tier_material(source_material, tier)
            slot.material = material_map[source_material]


def _make_tier_material(source_material: bpy.types.Material, tier: int) -> bpy.types.Material:
    material = source_material.copy()
    material.name = _tier_material_name(source_material.name, tier)
    if _is_tier_colored_material(source_material):
        _set_material_color(material, TIER_COLORS[tier])
    return material


def _tier_material_name(name: str, tier: int) -> str:
    tier_name = TIER_NAMES[tier]
    new_name = name
    for existing_tier, existing_name in TIER_NAMES.items():
        new_name = new_name.replace(f"T{existing_tier}_", f"T{tier}_")
        new_name = new_name.replace(f"_{existing_name}_", f"_{tier_name}_")
    return new_name


def _is_tier_colored_material(material: bpy.types.Material) -> bool:
    name = material.name.lower()
    if any(hint in name for hint in FIXED_MATERIAL_HINTS):
        return False
    return "blade" in name or _is_close_to_t1_tier_color(material.diffuse_color)


def _is_close_to_t1_tier_color(color: bpy.types.bpy_prop_array) -> bool:
    target = TIER_COLORS[1]
    return sum(abs(float(color[index]) - target[index]) for index in range(3)) < 0.18


def _set_material_color(material: bpy.types.Material, color: tuple[float, float, float, float]) -> None:
    material.diffuse_color = color
    if not material.use_nodes:
        return

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def export_hierarchy(root: bpy.types.Object, path: Path) -> None:
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_cameras=False,
        export_lights=False,
    )


if __name__ == "__main__":
    main()
