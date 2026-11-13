## 1. Spike and checks (before building on them)

- [x] 1.1 Asset-contract test `tests/test_rack_assets.gd` (headless `-s`): every node named in `assets/modules/*/asset.json`, `rack_frame`, `slot_labels` and `patch_plug` exists in its glb (design D10)
- [x] 1.2 Spike: an own-world `SubViewport` with an orthographic camera showing `rack_frame` + `burbler_clock`; confirm in Godot 4.8 beta that `unproject_position` picking and drag-and-drop onto the container work, and that the emissive halos and lamp read; screenshot next to `stubby-music/docs/art/hud_mock.png`
- [x] 1.3 Measure the screen-texture blur's frame cost at 1080p and 4K; pick the mip level

## 2. Burbler data

- [x] 2.1 Burbler `instance_id` export and a value in `main.tscn`; seeded `bpm_multiple` from the ×56–×64 window in `assets/machines/mudpit_burbler/tempo.json` via `WorldSeed.rng` (design D7)
- [x] 2.2 `RackState` resource (`common/rack_state.gd`): mounted, knobs, cables, `changed` / `configured` signals, completion check against `configure.cables` by jacks, not colours (design D5)
- [x] 2.3 Machine owns its `RackState`, initialised from `configure` (fixed modules mounted, knobs at defaults, BPM at the seeded multiple); the burbler exposes a `sounding` property and `sounding_changed` signal (true while configured), which `add-stream-building` 5.2 consumes

## 3. Window

- [x] 3.1 Rewrite `scenes/rack_screen/`: framed window (title bar and header, left strip, centre rack, right 4 × 4 grid, key prompts) from `rack_frame` `screen.panel` / `text`
- [x] 3.2 Backdrop dim and blur shader (design D8)
- [x] 3.3 Open and close: keep `open_rack(point)` and the group; E or Esc closes; cursor and controls as now; no pickups while open

## 4. The 3D rack

- [x] 4.1 Rack world: SubViewport, `Environment`, key light, orthographic camera framing width + posts + comb (design D1)
- [x] 4.2 Build the rack from `RackState`: stretch rails, place posts, mount modules at HP offsets, outlines + `Label_<kind>` for empty places
- [x] 4.3 Picking helper: projected jacks, knobs, comb plugs and slot rectangles (design D2)

## 5. Mounting

- [x] 5.1 Relevant strip (icons, counts, numbers 1–0) and inventory grid from `Inventory` + `Rules`
- [x] 5.2 Mount by number, click, or drag onto a slot; kind check via `accepts`; take one item
- [x] 5.3 Remove a non-fixed module (unplug its cables first, return the item); INVENTORY FULL notice

## 6. Cables

- [x] 6.1 `common/patch_cable.gd` tube builder on a quadratic Bézier with the VCV slump formula; plug seated at `Port_*` via `Cable_attach`; colour tint (design D3)
- [x] 6.2 Comb: hang `configure.cables` on `Comb_<n>` along the stored-cable curve; take, unplug and hang back
- [x] 6.3 Drag patching: from a jack or comb plug, 40 px snap, refuse an occupied input, output fan-out allowed; player `patch_cable` items used and returned
- [x] 6.4 Cable in hand on a damped spring (design D4)
- [x] 6.5 Snap click stand-in, cycling `patch_snap`; provenance record for the three clips (shared with `add-acoustic-asset-profiles` 2.2) (design D9)

## 7. Guidance and knobs

- [x] 7.1 Ghost cables for unmade suggested patches, shown only when both modules are mounted
- [x] 7.2 Halo pulses (0 → 2, 1.2 s, cable colour); rest once patched
- [x] 7.3 Knobs: vertical drag (240 px full range, taper) and scroll; rotation over `rotation_degrees`; machine range overrides module range (design D6)
- [x] 7.4 BPM knob in whole steps; display segments and header follow it; lamp placeholder tick (design D9)

## 8. Verify and document

- [x] 8.1 Headless test: open the burbler rack, mount a square wave, patch both cables by simulated input; assert `RackState` and a single `configured`
- [x] 8.2 Run the game and screenshot the empty, ready and patched states against the stubby-music mocks
- [x] 8.3 Update CLAUDE.md (rack screen layout, stand-ins, `RackState`) and `openspec validate --strict add-burbler-rack-screen`

## 9. Stand-in voice (added after play-test)

- [x] 9.1 `BurblerVoice`: one looped pre-rendered beat at the outlet; re-render on tempo, freq or gain; silent unless patched and normalled; lamp follows its heard phase (design D9b); tests in `test_rack_screen.gd`, plus a master-bus recording check (2200 Hz, half-beat gate, 60/58 s period)

## 10. Unplugging (added after play-test)

- [x] 10.1 Right-click a plugged jack unplugs its cable (comb cable home, own cable to the inventory); right-click a module still removes it; a hint beside the pointer for plugs, jacks, knobs, comb cables and modules; prompts list it. Tested headless (`test_rack_screen.gd`) and through the GUI (`test_rack_drag.gd`, which now warps the real pointer because Godot's drag-and-drop reads it)
