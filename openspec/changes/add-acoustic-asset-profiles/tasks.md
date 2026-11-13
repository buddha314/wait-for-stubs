## 1. Profile format and checks

- [ ] 1.1 JSON Schema for `acoustics.json` (kind, behaviours, primitives, parameters, coupling, confidence, citations) in `assets/acoustics/schema/`
- [ ] 1.2 Headless asset check: every world asset has a profile; profiles validate; established-physics entries cite sources
- [ ] 1.3 Formula library `common/acoustics.gd` (quarter-wave, Helmholtz, Minnaert, two-path comb; c as a setting) with headless tests for the spec's scenarios

## 2. Provenance

- [ ] 2.1 `<file>.provenance.json` format and the licence audit (SPDX → MIT-compatible), separate from code licences
- [ ] 2.2 Migrate `assets/audio/sfx/patch_snap/LICENSE.txt` to provenance records; generate `CREDITS.md`

## 3. Profiles for existing assets (from design.md's first-pass table)

- [ ] 3.1 Reeds: export internode tube lengths from `create_reeds.py` measurements (via stubby-music's Blender builder, or measured from the glTF); quarter-wave resonance
- [ ] 3.2 Desert stumps: cavity volume and opening from the mesh; Helmholtz resonance; standalone vs side-coupled entries
- [ ] 3.3 Burbler: bubble radius range → Minnaert pitch; mark simplified for mud
- [ ] 3.4 Brush, debris, scrub oak, mudflat ground, stream segment, lightning bug: profiles per the table
- [ ] 3.5 Machines and modules: `kind: processor` profiles that point at their rack definitions

## 4. Previews and experiments

- [ ] 4.1 Response-preview tool (headless, renders `response.png` from a profile); preview staleness check
- [ ] 4.2 `docs/experiments/` with the shared YAML template and a format check
- [ ] 4.3 First three experiments, adapted from the brief to this world: tune a reed side-branch to notch the burbler's hum; a stump-cavity "bottle choir"; ground-reflection comb vs listener height on the mudflat
- [ ] 4.4 `openspec validate --strict add-acoustic-asset-profiles`
