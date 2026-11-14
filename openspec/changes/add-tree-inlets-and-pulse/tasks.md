## 1. Model

- [ ] 1.1 `create_scrub_oak.py`: `Inlet_<n>` empties (three, at the root flare, facing the trunk, angles from the variant), extras `stream: inlet`, and `Inlet_<n>_Halo` rings with `start_scale: 0` (the burbler's outlet halo pattern); regenerate, reimport
- [ ] 1.2 Headless check of the regenerated glb: three inlets per variant, halos at scale 0 after import, positions differ between variants

## 2. Inlets and connection

- [ ] 2.1 `StreamPort` gains an inlet kind (accepts a stream's end; never starts one); the oak registers its inlets
- [ ] 2.2 Builder: a free inlet within 3 m of the aim takes the plan's end (exact end point and arrival direction; invalid past the bend limit); its halo shows
- [ ] 2.3 Laying onto an inlet connects: inlet taken, the stream's end consumed; dismantling the connected segment frees both
- [ ] 2.4 `GrowthLevels.water_at`: trees with inlets are watered by connected flowing streams only (the clearest); others keep the reach rule
- [ ] 2.5 Update `add-stream-building`'s plant-growth requirement text to defer to inlets
- [ ] 2.6 Headless test: snap and connect, can't extend past, dismantle frees, near-but-unconnected doesn't water, connected-and-flowing waters (generic: any oak in a test scene, no goal content)

## 3. Pulse and knock

- [ ] 3.1 `knock.json` (c, envelope, gain, hearing radius) and the pitch from the instance's trunk height (D6)
- [ ] 3.2 The oak's rack: `tempo_clock` at the source's multiple → `envelope` → `vca` ← `vco_sine`, a `RackEmitter` at the trunk on the World bus, paused unless watered by a sounding source; the multiple follows the source's BPM
- [ ] 3.3 Pulse on the source's heard ticks (D4): envelope on canopy scale and bark/bud emission (per-instance materials)
- [ ] 3.4 Headless test: knock ticks on the same samples as the source's clock; pulse count follows ticks while watered and stops when the source stops; silent with no connection; pitch from trunk height
- [ ] 3.5 `assets/flora/scrub_oak/acoustics.json` (D7)

## 4. Wrap-up

- [ ] 4.1 Screenshot or short capture: halo on an inlet while planning, the pulse on a watered oak
- [ ] 4.2 CLAUDE.md: inlets, watering by connection, the pulse and knock
- [ ] 4.3 `openspec validate --strict add-tree-inlets-and-pulse`
