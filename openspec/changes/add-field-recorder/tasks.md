## 1. Check the asset (before building on it)

- [x] 1.1 Headless check of `field_recorder.glb`: `Grip`, `Capture`, `Windguard`, `Light_rec`, `Screen`, `Level_0`–`Level_7`, 14 `FieldRecorder_FurShell<n>`, `FieldRecorder_WindguardSock`, the `FieldRecorder_RecLight` material, and the extras design.md lists; record whether `Level_n` are meshes or empties over meshes (they are `MeshInstance3D`s; checked in `tests/test_field_recorder.gd`)
- [x] 1.2 `assets/equipment/field_recorder/acoustics.json` declaring no acoustic role (design D7)

## 2. Hand and input (no engine needed)

- [x] 2.1 Input action `field_recorder` (H) in `project.godot`
- [x] 2.2 `scenes/hand/hand.tscn` + `hand.gd` under `Player/Head`: one-item hand, an action per item, starts holding the recorder, ignored while `controls_enabled` is false (design D1, D6)
- [x] 2.3 Recorder item at stubby-music's pose; fur shells `cast_shadow` off (design D2, D3)
- [x] 2.4 Headless test: H toggles the recorder via `Input.parse_input_event`; H does nothing with the rack screen open; a new game starts with the recorder in hand
- [x] 2.5 Sound gating: `Rules.yields_sound(resource_id)` (any yield item has a `waveform` or a `sample`); `ResourceNode` refuses a sound without the recorder in hand and the HUD shows the tip with H read from the input map; headless test for bug refused, reed allowed, bug collected with the recorder

## 3. Record light (no engine needed)

- [x] 3.1 `Player` exposes whether E collected a pickup this tick (pickups only, not machines)
- [x] 3.2 Record-light envelope on a per-instance `FieldRecorder_RecLight` (strengths from `Light_rec` extras; attack 0.05 s, decay 0.4 s) (design D4)
- [x] 3.3 Headless test: collecting a bug raises the light to peak and it returns to rest within 1 s; walking without collecting leaves it at rest

## 4. Level meter (works today on Master; moves to the engine's bus later)

- [x] 4.1 Meter from `AudioServer` bus peak (max of L/R), peak-hold with 24 dB/s fall, eight bars from −48 dBFS in 6 dB steps (design D5)
- [x] 4.2 Headless test: all bars dark in the silent opening; a bug click two metres away lights bars, which fall back after
- [ ] 4.4 After the engine reports per-emitter levels (`add-rack-audio-engine` 8.2): weight them by the `Capture` pickup pattern; test pointing at and away from a single bug
- [x] 4.3 After stubby-rack provides stems (`add-rack-audio-engine` 3.3, 5.3): point the meter at the world/music bus and check the UI stem does not move it

## 5. Wrap-up

- [x] 5.1 Update CLAUDE.md (H, `scenes/hand/`, the meter's bus)
- [x] 5.2 `openspec validate --strict add-field-recorder`
