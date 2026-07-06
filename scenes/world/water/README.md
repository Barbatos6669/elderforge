# Water Prefabs

Reusable water scenes live here.

- `WaterPlane.tscn`: visual-only stylized water plane using the shared
  production-style water material. Drop it under a level's
  `World/LevelContent/GroundDress` or a future `Water` folder, then scale the
  root or edit the `PlaneMesh` size.

The water plane does not include collision. Keep gameplay blockers, shore
collision, swimming, and navigation rules separate so level layout stays easy to
iterate.

The material uses the common real-time water stack: subdivided plane, Gerstner
vertex waves, two scrolling normal maps, depth color fade, shoreline foam, and
Fresnel highlights.
