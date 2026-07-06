# Dead Tree Gathering Prefabs

These scenes wrap the Stylized Nature MegaKit `dead_tree_1` through
`dead_tree_5` models as Tier 1 gatherable trees.

Each prefab uses the same gameplay shape:

- `GatherableResource3D` on the scene root so player gathering can read yield,
  tier, replenish, and depletion data.
- `Selectable` and ring feedback so hovering/clicking behaves like other
  resources.
- `ResourceBody` with a simple cylinder collider for movement blocking.
- `WindSway3D` on the active visual model only, so the art sways but collision
  remains stable.

For now these all yield `timber_t1` and deplete into the shared Tier 1 stump.
