# Occlusion Materials

Materials here are used when world art blocks the player from the camera.

- `pixel_occlusion_fade.gdshader` keeps the source albedo texture/color and
  fades the texture alpha when it blocks the player. It can still do blocky
  world-space dither if `use_pixel_dither` is enabled on `OccludableVisual3D`.

`OccludableVisual3D` drives the shader at runtime. Artists should tag only the
mesh pieces that should get out of the way, such as tree leaves, roofs, or
canopies. Solid pieces like trunks and walls should usually stay untouched.

For tall trees, use `target_mesh_names` for leaves/canopy that should fade.
Use `hide_while_occluded_mesh_names` and `show_while_occluded_mesh_names` when
an artist-made de-render mesh should replace the normal mesh while the player is
behind the object.

When `drives_player_silhouette` is enabled, the same component reports that it
is hiding the local player so `PlayerOcclusionSilhouette` can show the readable
through-object character highlight even if the visual mesh has no physics
collider. Keep it disabled for early-fading canopy/leaves when the silhouette
should only appear for solid blockers such as trunks, walls, or buildings.
