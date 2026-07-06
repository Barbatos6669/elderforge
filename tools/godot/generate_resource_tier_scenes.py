"""Generate T2-T8 gatherable resource scenes from the current T1 scene pattern."""

from __future__ import annotations

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCENE_DIR = PROJECT_ROOT / "scenes" / "gathering"

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

SHARED_ROCK_MODEL_PATH = "res://assets/models/environment/stylized_nature_megakit/models/rock_medium_1.gltf"
SHARED_ROCK_MODEL_UID = "uid://c0t31rv1mnrne"
TIER_TINT_SCRIPT_PATH = "res://scripts/visuals/tier_tinted_model_3d.gd"
ROCK_VISUAL_TRANSFORM = (
    "Transform3D(0.55108804, 0, 0, 0, 0.48344278, 0, "
    "0, 0, 0.61184204, 0, -0.2695726, -0.17404577)"
)

TREE_NAMES = {
    1: "Crude Tree",
    2: "Rough Tree",
    3: "Sturdy Tree",
    4: "Seasoned Tree",
    5: "Hardened Tree",
    6: "Emberwood Tree",
    7: "Sunheart Tree",
    8: "Kingswood Tree",
}

ROCK_NAMES = {
    1: "Crude Stone",
    2: "Rough Stone",
    3: "Sturdy Stone",
    4: "Dense Stone",
    5: "Hardened Stone",
    6: "Runed Stone",
    7: "Sunstone",
    8: "Kingsstone",
}

ORE_NAMES = {
    1: "Crude Ore",
    2: "Rough Ore",
    3: "Sturdy Ore",
    4: "Dense Ore",
    5: "Hardened Ore",
    6: "Runed Ore",
    7: "Star Ore",
    8: "Kingsmetal Ore",
}

FIBER_NAMES = {
    1: "Crude Cotton",
    2: "Rough Cotton",
    3: "Coarse Cotton",
    4: "Soft Cotton",
    5: "Fine Cotton",
    6: "Lustrous Cotton",
    7: "Sunspun Cotton",
    8: "Kingsweave Cotton",
}


def main() -> None:
    SCENE_DIR.mkdir(parents=True, exist_ok=True)
    for tier in range(2, 9):
        _write_scene(f"Tier{tier}Tree.tscn", _tree_scene(tier))
        _write_scene(f"Tier{tier}Rock.tscn", _rock_scene(tier))
        _write_scene(f"Tier{tier}Ore.tscn", _ore_scene(tier))
        _write_scene(f"Tier{tier}Fiber.tscn", _fiber_scene(tier))


def _write_scene(filename: str, content: str) -> None:
    (SCENE_DIR / filename).write_text(content, encoding="utf-8", newline="\n")


def _color(tier: int, alpha: float | None = None) -> str:
    red, green, blue, default_alpha = TIER_COLORS[tier]
    return "Color(%s, %s, %s, %s)" % (
        _fmt(red),
        _fmt(green),
        _fmt(blue),
        _fmt(default_alpha if alpha is None else alpha),
    )


def _fmt(value: float) -> str:
    return ("%0.3f" % value).rstrip("0").rstrip(".")


def _common_ext_resources() -> str:
    return """[ext_resource type="Script" uid="uid://c7onhc7t0w5tj" path="res://scripts/gathering/gatherable_resource_3d.gd" id="1_gatherable"]
[ext_resource type="Script" uid="uid://br3ubcjkrdw57" path="res://scripts/interaction/selection/selectable_3d.gd" id="2_selectable"]
[ext_resource type="Script" uid="uid://cbxs8002i2pvm" path="res://scripts/interaction/hover/hover_feedback_3d.gd" id="3_hover_feedback"]
[ext_resource type="Script" uid="uid://i4o11j0hk5eg" path="res://scripts/interaction/selection/selection_feedback_3d.gd" id="4_selection_feedback"]
[ext_resource type="Material" path="res://assets/materials/hover/hover_outline_green.tres" id="5_hover_material"]
[ext_resource type="Texture2D" path="res://assets/ui/cursors/gather_tool_cursor.png" id="6_gather_cursor"]
[ext_resource type="Texture2D" uid="uid://cili1xiu4osa1" path="res://assets/ui/cursors/depleted_resource_cursor.png" id="7_depleted_cursor"]"""


def _tree_scene(tier: int) -> str:
    name = TREE_NAMES[tier]
    color = _color(tier)
    fill = _color(tier, 0.16)
    return f"""[gd_scene format=3]

{_common_ext_resources()}
[ext_resource type="PackedScene" path="res://assets/models/resources/trees/t{tier}_tree_trunk.glb" id="8_tree_trunk"]
[ext_resource type="PackedScene" path="res://assets/models/resources/trees/t{tier}_tree_stump.glb" id="9_tree_stump"]
[ext_resource type="PackedScene" path="res://assets/models/resources/trees/t{tier}_tree_leaves.glb" id="10_tree_leaves"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_selectable"]
radius = 0.92
height = 3.0

[sub_resource type="CylinderShape3D" id="CylinderShape3D_resource_body"]
height = 1.35
radius = 0.42

[node name="Tier{tier}Tree" type="Node3D"]
script = ExtResource("1_gatherable")
display_name = "{name}"
resource_family_id = "logs"
yield_item_id = "timber_t{tier}"
tier = {tier}

[node name="Selectable" type="Area3D" parent="."]
collision_layer = 8
collision_mask = 0
script = ExtResource("2_selectable")
display_name = "{name}"
relationship = 2
neutral_color = {color}

[node name="CollisionShape3D" type="CollisionShape3D" parent="Selectable"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.45, 0)
shape = SubResource("CapsuleShape3D_selectable")

[node name="ResourceBody" type="StaticBody3D" parent="."]
collision_layer = 2
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="ResourceBody"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.675, 0)
shape = SubResource("CylinderShape3D_resource_body")

[node name="HoverSelectionRing" type="MeshInstance3D" parent="."]
script = ExtResource("3_hover_feedback")
hover_collision_mask = 8
ring_radius = 0.78
ring_color = {color}
highlight_material = ExtResource("5_hover_material")
hover_cursor_texture = ExtResource("6_gather_cursor")
unavailable_hover_cursor_texture = ExtResource("7_depleted_cursor")

[node name="SelectedRing" type="MeshInstance3D" parent="."]
script = ExtResource("4_selection_feedback")
ring_radius = 0.86
ring_color = {color}
fill_color = {fill}

[node name="Visuals" type="Node3D" parent="."]

[node name="Active" type="Node3D" parent="Visuals"]

[node name="Trunk" type="Node3D" parent="Visuals/Active"]

[node name="T{tier}TreeTrunkModel" parent="Visuals/Active/Trunk" instance=ExtResource("8_tree_trunk")]

[node name="Leaves" type="Node3D" parent="Visuals/Active"]

[node name="T{tier}TreeLeavesModel" parent="Visuals/Active/Leaves" instance=ExtResource("10_tree_leaves")]

[node name="Depleted" type="Node3D" parent="Visuals"]
visible = false

[node name="T{tier}TreeStumpModel" parent="Visuals/Depleted" instance=ExtResource("9_tree_stump")]
"""


def _rock_scene(tier: int) -> str:
    return _compact_resource_scene(
        tier=tier,
        scene_name=f"Tier{tier}Rock",
        display_name=ROCK_NAMES[tier],
        family_id="stone",
        yield_item_id=f"stone_t{tier}",
        model_root="rocks",
        model_prefix="rock",
        active_path=SHARED_ROCK_MODEL_PATH,
        depleted_path=f"res://assets/models/resources/rocks/t{tier}_rock_depleted.glb",
        active_node=f"T{tier}RockFullModel",
        depleted_node=f"T{tier}RockDepletedModel",
        active_resource_uid=SHARED_ROCK_MODEL_UID,
        visual_script_path=TIER_TINT_SCRIPT_PATH,
        active_transform=ROCK_VISUAL_TRANSFORM,
        active_tint_color=_color(tier),
        selectable_shape="SphereShape3D",
        selectable_radius=0.95,
        selectable_height=0.0,
        selectable_y=0.58,
        body_radius=0.58,
        body_height=0.7,
        body_y=0.35,
        ring_radius=0.78,
        selected_ring_radius=0.86,
    )


def _ore_scene(tier: int) -> str:
    return _compact_resource_scene(
        tier=tier,
        scene_name=f"Tier{tier}Ore",
        display_name=ORE_NAMES[tier],
        family_id="ore",
        yield_item_id=f"ore_t{tier}",
        model_root="ores",
        model_prefix="ore",
        active_path=f"res://assets/models/resources/ores/t{tier}_ore_full.glb",
        depleted_path=f"res://assets/models/resources/ores/t{tier}_ore_depleted.glb",
        active_node=f"T{tier}OreFullModel",
        depleted_node=f"T{tier}OreDepletedModel",
        selectable_shape="SphereShape3D",
        selectable_radius=0.95,
        selectable_height=0.0,
        selectable_y=0.58,
        body_radius=0.58,
        body_height=0.7,
        body_y=0.35,
        ring_radius=0.78,
        selected_ring_radius=0.86,
    )


def _fiber_scene(tier: int) -> str:
    return _compact_resource_scene(
        tier=tier,
        scene_name=f"Tier{tier}Fiber",
        display_name=FIBER_NAMES[tier],
        family_id="cotton",
        yield_item_id=f"cotton_t{tier}",
        model_root="fibers",
        model_prefix="fiber",
        active_path=f"res://assets/models/resources/fibers/t{tier}_fiber_full.glb",
        depleted_path=f"res://assets/models/resources/fibers/t{tier}_fiber_depleted.glb",
        active_node=f"T{tier}FiberFullModel",
        depleted_node=f"T{tier}FiberDepletedModel",
        selectable_shape="CapsuleShape3D",
        selectable_radius=0.68,
        selectable_height=1.55,
        selectable_y=0.78,
        body_radius=0.42,
        body_height=0.72,
        body_y=0.36,
        ring_radius=0.66,
        selected_ring_radius=0.72,
    )


def _compact_resource_scene(
    *,
    tier: int,
    scene_name: str,
    display_name: str,
    family_id: str,
    yield_item_id: str,
    model_root: str,
    model_prefix: str,
    active_path: str,
    depleted_path: str,
    active_node: str,
    depleted_node: str,
    selectable_shape: str,
    selectable_radius: float,
    selectable_height: float,
    selectable_y: float,
    body_radius: float,
    body_height: float,
    body_y: float,
    ring_radius: float,
    selected_ring_radius: float,
    active_resource_uid: str = "",
    visual_script_path: str = "",
    active_transform: str = "",
    active_tint_color: str = "",
) -> str:
    color = _color(tier)
    fill = _color(tier, 0.16)
    active_uid_text = f' uid="{active_resource_uid}"' if active_resource_uid else ""
    visual_script_resource = (
        f'[ext_resource type="Script" path="{visual_script_path}" id="10_tier_tint"]\n'
        if visual_script_path
        else ""
    )
    active_transform_property = f"transform = {active_transform}\n" if active_transform else ""
    active_script_property = 'script = ExtResource("10_tier_tint")\n' if visual_script_path else ""
    active_tint_property = f"tint_color = {active_tint_color}\n" if active_tint_color else ""
    shape_definition = f"""[sub_resource type="{selectable_shape}" id="{selectable_shape}_selectable"]
radius = {_fmt(selectable_radius)}
"""
    if selectable_shape == "CapsuleShape3D":
        shape_definition += f"height = {_fmt(selectable_height)}\n"

    return f"""[gd_scene format=3]

{_common_ext_resources()}
[ext_resource type="PackedScene"{active_uid_text} path="{active_path}" id="8_{model_root}_{model_prefix}_full"]
[ext_resource type="PackedScene" path="{depleted_path}" id="9_{model_root}_{model_prefix}_depleted"]
{visual_script_resource}

{shape_definition}
[sub_resource type="CylinderShape3D" id="CylinderShape3D_resource_body"]
height = {_fmt(body_height)}
radius = {_fmt(body_radius)}

[node name="{scene_name}" type="Node3D"]
script = ExtResource("1_gatherable")
display_name = "{display_name}"
resource_family_id = "{family_id}"
yield_item_id = "{yield_item_id}"
tier = {tier}

[node name="Selectable" type="Area3D" parent="."]
collision_layer = 8
collision_mask = 0
script = ExtResource("2_selectable")
display_name = "{display_name}"
relationship = 2
neutral_color = {color}

[node name="CollisionShape3D" type="CollisionShape3D" parent="Selectable"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {_fmt(selectable_y)}, 0)
shape = SubResource("{selectable_shape}_selectable")

[node name="ResourceBody" type="StaticBody3D" parent="."]
collision_layer = 2
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="ResourceBody"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {_fmt(body_y)}, 0)
shape = SubResource("CylinderShape3D_resource_body")

[node name="HoverSelectionRing" type="MeshInstance3D" parent="."]
script = ExtResource("3_hover_feedback")
hover_collision_mask = 8
ring_radius = {_fmt(ring_radius)}
ring_color = {color}
highlight_material = ExtResource("5_hover_material")
hover_cursor_texture = ExtResource("6_gather_cursor")
unavailable_hover_cursor_texture = ExtResource("7_depleted_cursor")

[node name="SelectedRing" type="MeshInstance3D" parent="."]
script = ExtResource("4_selection_feedback")
ring_radius = {_fmt(selected_ring_radius)}
ring_color = {color}
fill_color = {fill}

[node name="Visuals" type="Node3D" parent="."]

[node name="Active" type="Node3D" parent="Visuals"]

[node name="{active_node}" parent="Visuals/Active" instance=ExtResource("8_{model_root}_{model_prefix}_full")]
{active_transform_property}{active_script_property}{active_tint_property}

[node name="Depleted" type="Node3D" parent="Visuals"]
visible = false

[node name="{depleted_node}" parent="Visuals/Depleted" instance=ExtResource("9_{model_root}_{model_prefix}_depleted")]
"""


if __name__ == "__main__":
    main()
