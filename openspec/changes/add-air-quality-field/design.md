## Context

stubby-music's spec:
- a value in [0, 1] per 10 m cubic cell, sparse, eased over at least 3 s;
- targets from the density of plants and animals;
- global lights blend by the camera's cell;
- ground tint and flora accents use each cell's own value;
- no visible step at cell borders.

It was never built there. The user confirmed on 2026-11-13 that the game opens in
polluted air, cleaned as plants regrow, and asked whether 10 m cubes are
computationally feasible.

## Goals / Non-Goals

**Goals:**
- the field, with targets from plants;
- the camera-local 3D texture;
- the storm and ground/flora reading it;
- the mood blend with N moods;
- measured cost.

**Non-Goals:**
- authoring the `clearing` keys (art, upstream);
- new plants;
- animals;
- saving the field (it's a Resource-friendly dictionary, saved with the save change).

## Decisions

**D1. Sparse cells keyed by `Vector3i`.** Each cell is `{value, target}`. A cell
exists only once something sets a target, or it's still easing. A cell at value 0
with target 0 is removed.
- Easing: `value = move_toward(value, target, rate × delta)`, with a rate of about
  0.25/s (more than 3 s for a full step, per the spec).
- It runs on simulation time (Calendar), not audio. Clean air isn't musical timing.

**D2. Targets.**
- Each living thing registers a weight at a position: a reed clump is 1, a future
  tree more.
- target = clamp(Σ weights in the cell / capacity, 0, 1). The capacity (for
  example 6, about one reed bed) lives in a local `scenes/air_quality/` preset, not
  in `assets/`, which rsync overwrites.
- Cutting a reed clump removes its weight until it regrows.
- Vertically, life counts in its own cell and in the cell above it, so air clears
  overhead too. More layers can be added later.

**D3. The camera window texture.**
- An `ImageTexture3D`, `FORMAT_R8`, 64 × 8 × 64 by default. Its origin snaps to
  whole cells around the camera.
- It's rewritten only when a cell inside the window changed this frame, or the
  window moved.
- It's set as a global shader uniform `air_quality` (sampler3D, filter_linear),
  with `air_quality_origin` and `air_quality_size` (vec3, metres).
- Trilinear filtering blends across borders, with no step at a cell edge.
- Outside the window, samples clamp to the edge, which is usually polluted
  desert anyway.

Cost: 32 KB per upload at most once a frame, and a dictionary walk over changed
cells only.

Rejected:
- **A FogVolume per cell:** thousands of volumes, each with its own cost.
- **Per-object uniforms:** they can't cover ground and fog continuously.
- **A full-world texture:** wasteful on large maps.

**D4. Consumers.**
- **Storm fog** (`add-weather-and-dust-storm` D6): density × (1 − q).
- **Ground:** albedo blends toward the bloomed `ground_tint` by q.
- **Flora:** accent emission scales by q.
- **Global lights:** mood blend by q sampled at the camera (on the CPU from the
  sparse field, so there's no GPU readback).
- **Far haze beyond the volumetric fog length:** the Environment's depth fog,
  from the camera's q.

**D5. Moods are a list.** The reader takes every mood in `lighting_keys.json`
`moods` in stop order (`light_quality` gives each mood's stop) and blends the two
stops either side of q. With today's file that's bleak at 0 and bloomed at 1.
`clearing` drops in when art adds it (stubby-music `add-clearing-air-stage` 3.1–3.2).

## Risks / Trade-offs

- [Volumetric fog length (default 64 m) is too short to show a clean grove 150 m
  away as a clear pocket] → raise `volumetric_fog_length` (at some cost to depth
  precision), and lean on per-cell ground and flora colour for far groves. The
  spike measures this.
- [Uploads every frame while many cells ease] → the 32 KB is negligible. Throttle
  to 15 Hz if profiling disagrees.
- [Plant density is the only driver] → upstream left "what drives the stage" open
  (`add-clearing-air-stage` 2.1). The registration API takes any weight source, so
  the storm ending or a recipe can contribute later.

## Open Questions

- The capacity per cell (how much life fully cleans 10 m), tuned in play.
- Whether animals count as well as plants (yes when they exist), and what weight
  each carries.
