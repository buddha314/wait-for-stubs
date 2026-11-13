## 1. Spike (feasibility numbers first)

- [ ] 1.1 `AirQuality` prototype with 200 easing cells and a moving camera: CPU time per frame for easing and packing, and the 64 × 8 × 64 `ImageTexture3D` upload cost; record in design.md
- [ ] 1.2 FogVolume sampling the global sampler3D: a clean pocket visible at 30 m, 80 m and 150 m; tune `volumetric_fog_length` and record cost (shared with `add-weather-and-dust-storm` 1.1)

## 2. Field

- [ ] 2.1 Sparse cells (`Vector3i` → value, target), easing on Calendar time, removal of settled empty cells (design D1)
- [ ] 2.2 Registration API: weights at positions, own cell + cell above; capacity from the local `scenes/air_quality/` preset (D2)
- [ ] 2.3 Reed clumps register; cutting removes their weight until they regrow
- [ ] 2.4 Camera window packing into `ImageTexture3D`; global uniforms `air_quality`, `air_quality_origin`, `air_quality_size` in `project.godot` (D3)
- [ ] 2.5 Headless tests: untouched desert stores nothing; easing takes 3 s or more; locality (50 m unchanged); cutting lowers and regrowth raises; monotonic samples across a border; cost under 0.5 ms with 200 cells

## 3. Consumers

- [ ] 3.1 Mood reader for N moods by stop; blend by q at the camera into Sky3D and the Environment (D4, D5)
- [ ] 3.2 Ground material tint by q; flora accent emission by q (reeds first)
- [ ] 3.3 Storm fog density × (1 − q) (with `add-weather-and-dust-storm` 4.1); far depth fog from the camera's q
- [ ] 3.4 Screenshots: a cleared reed bed seen from inside and from 60 m outside, at night and by day

## 4. Docs

- [ ] 4.1 CLAUDE.md (field, globals, registration); `openspec validate --strict add-air-quality-field`
