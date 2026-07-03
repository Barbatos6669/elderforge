"""Create T2-T8 placeholder variants for current gatherable resources.

Run with Blender from the project root:

    blender --background --python tools/blender/create_resource_tier_variants.py

The script keeps each T1 source as the shape master, writes tier-specific source
blends under ignored `source/` folders, recolors the tier-facing material, and
exports the GLBs referenced by the Godot tier scenes.
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
RESOURCE_ROOT = PROJECT_ROOT / "assets" / "models" / "resources"

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

T1_COLOR = TIER_COLORS[1]

ColorStrategy = Callable[[bpy.types.Material, int], tuple[float, float, float, float] | None]


def main() -> None:
    _build_tree_variants()
    _build_rock_variants()
    _build_ore_variants()
    _build_fiber_variants()


def _build_tree_variants() -> None:
    tree_dir = RESOURCE_ROOT / "trees"
    source_blend = tree_dir / "t1_tree.blend"
    for tier in range(2, 9):
        _open_source(source_blend)

        full_root = _require_object("T1TreeFull")
        trunk_root = _require_object("Trunk")
        leaves_root = _require_object("Leaves")
        stump_root = _require_object("T1TreeDepleted")

        _retier_hierarchy([full_root, stump_root], tier, _tree_color)
        trunk_root.name = f"T{tier}TreeTrunk"
        leaves_root.name = f"T{tier}TreeLeaves"

        source_path = tree_dir / "source" / f"t{tier}_tree.blend"
        exports = [
            (trunk_root, tree_dir / f"t{tier}_tree_trunk.glb"),
            (leaves_root, tree_dir / f"t{tier}_tree_leaves.glb"),
            (stump_root, tree_dir / f"t{tier}_tree_stump.glb"),
        ]
        _save_source_and_exports(source_path, exports)


def _build_rock_variants() -> None:
    rock_dir = RESOURCE_ROOT / "rocks"
    source_blend = rock_dir / "t1_rock.blend"
    for tier in range(2, 9):
        _open_source(source_blend)

        full_root = _require_object("T1RockFull")
        depleted_root = _require_object("T1RockDepleted")

        _retier_hierarchy([full_root, depleted_root], tier, _rock_color)

        source_path = rock_dir / "source" / f"t{tier}_rock.blend"
        exports = [
            (full_root, rock_dir / f"t{tier}_rock_full.glb"),
            (depleted_root, rock_dir / f"t{tier}_rock_depleted.glb"),
        ]
        _save_source_and_exports(source_path, exports)


def _build_ore_variants() -> None:
    ore_dir = RESOURCE_ROOT / "ores"
    source_blend = ore_dir / "source" / "t1_ore.blend"
    for tier in range(2, 9):
        _open_source(source_blend)

        full_root = _require_object("T1OreFull")
        depleted_root = _require_object("T1OreDepleted")

        _retier_hierarchy([full_root, depleted_root], tier, _ore_color)

        source_path = ore_dir / "source" / f"t{tier}_ore.blend"
        exports = [
            (full_root, ore_dir / f"t{tier}_ore_full.glb"),
            (depleted_root, ore_dir / f"t{tier}_ore_depleted.glb"),
        ]
        _save_source_and_exports(source_path, exports)


def _build_fiber_variants() -> None:
    fiber_dir = RESOURCE_ROOT / "fibers"
    source_blend = fiber_dir / "source" / "t1_fiber.blend"
    for tier in range(2, 9):
        _open_source(source_blend)

        full_root = _require_object("T1FiberFull")
        depleted_root = _require_object("T1FiberDepleted")

        _retier_hierarchy([full_root, depleted_root], tier, _fiber_color)

        source_path = fiber_dir / "source" / f"t{tier}_fiber.blend"
        exports = [
            (full_root, fiber_dir / f"t{tier}_fiber_full.glb"),
            (depleted_root, fiber_dir / f"t{tier}_fiber_depleted.glb"),
        ]
        _save_source_and_exports(source_path, exports)


def _open_source(source_blend: Path) -> None:
    if not source_blend.exists():
        raise RuntimeError(f"Missing source blend: {source_blend}")
    bpy.ops.wm.open_mainfile(filepath=str(source_blend))


def _require_object(name: str) -> bpy.types.Object:
    obj = bpy.data.objects.get(name)
    if obj is None:
        raise RuntimeError(f"Could not find Blender object '{name}'.")
    return obj


def _retier_hierarchy(roots: list[bpy.types.Object], tier: int, color_strategy: ColorStrategy) -> None:
    for obj in _iter_unique_objects(roots):
        _retier_object_name(obj, tier)
        if obj.type == "MESH" and obj.data is not None:
            _retier_mesh_name(obj.data, tier)

    for material in _iter_unique_materials(roots):
        material.name = material.name.replace("T1", f"T{tier}")
        color = color_strategy(material, tier)
        if color is not None:
            _set_material_color(material, color)


def _iter_unique_objects(roots: list[bpy.types.Object]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []
    seen: set[bpy.types.Object] = set()
    for root in roots:
        for obj in [root, *root.children_recursive]:
            if obj not in seen:
                seen.add(obj)
                objects.append(obj)
    return objects


def _iter_unique_materials(roots: list[bpy.types.Object]) -> list[bpy.types.Material]:
    materials: list[bpy.types.Material] = []
    seen: set[bpy.types.Material] = set()
    for obj in _iter_unique_objects(roots):
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            material = slot.material
            if material is not None and material not in seen:
                seen.add(material)
                materials.append(material)
    return materials


def _retier_object_name(obj: bpy.types.Object, tier: int) -> None:
    obj.name = obj.name.replace("T1", f"T{tier}")


def _retier_mesh_name(mesh: bpy.types.Mesh, tier: int) -> None:
    mesh.name = mesh.name.replace("T1", f"T{tier}")


def _tree_color(material: bpy.types.Material, tier: int) -> tuple[float, float, float, float] | None:
    name = material.name.lower()
    if "leaf" in name or "leaves" in name or _is_close_to_t1_color(material.diffuse_color):
        return TIER_COLORS[tier]
    return None


def _rock_color(material: bpy.types.Material, tier: int) -> tuple[float, float, float, float] | None:
    name = material.name.lower()
    if "stone" not in name and not _is_close_to_t1_color(material.diffuse_color):
        return None
    if "dark" in name or "shadow" in name:
        return _scale_rgb(TIER_COLORS[tier], 0.62)
    return TIER_COLORS[tier]


def _ore_color(material: bpy.types.Material, tier: int) -> tuple[float, float, float, float] | None:
    name = material.name.lower()
    if "hostrock" in name:
        return None
    if "ore" not in name and not _is_close_to_t1_color(material.diffuse_color):
        return None
    if "bright" in name or "facet" in name:
        return _mix_rgb(TIER_COLORS[tier], (1.0, 1.0, 1.0, 1.0), 0.35)
    return TIER_COLORS[tier]


def _fiber_color(material: bpy.types.Material, tier: int) -> tuple[float, float, float, float] | None:
    name = material.name.lower()
    if "cotton" in name or _is_close_to_t1_color(material.diffuse_color):
        return TIER_COLORS[tier]
    return None


def _is_close_to_t1_color(color: bpy.types.bpy_prop_array) -> bool:
    return sum(abs(float(color[index]) - T1_COLOR[index]) for index in range(3)) < 0.18


def _scale_rgb(color: tuple[float, float, float, float], scale: float) -> tuple[float, float, float, float]:
    return (color[0] * scale, color[1] * scale, color[2] * scale, color[3])


def _mix_rgb(
    color: tuple[float, float, float, float],
    target: tuple[float, float, float, float],
    amount: float,
) -> tuple[float, float, float, float]:
    return (
        color[0] * (1.0 - amount) + target[0] * amount,
        color[1] * (1.0 - amount) + target[1] * amount,
        color[2] * (1.0 - amount) + target[2] * amount,
        color[3],
    )


def _set_material_color(material: bpy.types.Material, color: tuple[float, float, float, float]) -> None:
    material.diffuse_color = color
    if not material.use_nodes:
        return

    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color


def _save_source_and_exports(source_path: Path, exports: list[tuple[bpy.types.Object, Path]]) -> None:
    source_path.parent.mkdir(parents=True, exist_ok=True)
    (source_path.parent / ".gdignore").write_text(
        "Godot uses the exported GLBs in ../; edit this source in Blender 5.1.\n",
        encoding="utf-8",
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))

    for root, export_path in exports:
        export_path.parent.mkdir(parents=True, exist_ok=True)
        _export_hierarchy(root, export_path)
        print(f"Exported {export_path}")


def _select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root


def _export_hierarchy(root: bpy.types.Object, path: Path) -> None:
    _select_hierarchy(root)
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
