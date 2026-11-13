## Context

The brief is a working design document for parallel design agents, written before the
Godot port. This change takes the parts that govern **how assets are made**. It leaves
mechanics, puzzles and progression for their own changes, because the brief itself
says its ideas aren't settled requirements. Audio rendering belongs to
`add-rack-audio-engine`. This change only describes assets so that engine can render
them.

## Goals / Non-Goals

**Goals:**
- An acoustic description for every world asset, made with the asset rather than
  added afterwards.
- Physics that are approximate but legible, and honest about which is which.
- Clean provenance for every sound we ship.

**Non-Goals:**
- Wave or room-acoustics simulation.
- Puzzle and progression design (the brief's §4–5 loops become their own changes).
- Recording or sourcing sound libraries (this change defines how they're recorded
  and checked).

## Decisions

**D1 — A separate `acoustics.json` per asset.** `assets/` mirrors stubby-music and is
re-synced with `rsync`, so `asset.json` must stay untouched. A sibling file survives a
re-sync and keeps the acoustic contract reviewable on its own. *Alternative:* a
block inside `asset.json`. Rejected because the next sync would overwrite it.

**D2 — Behaviours, not filter types.** Following brief §2, a profile lists *emission,
transmission, reflection, absorption, resonance* separately. Each entry has:

- `physical_basis`, the real phenomenon;
- `approximation`, one DSP primitive from a small set: `lowpass`, `highpass`,
  `bandpass`, `notch`, `comb`, `resonator`, `impulse_response`, `noise_source`,
  `sample`, `nonlinear`;
- `parameters`, with ranges;
- `confidence`: `established_physics`, `simplified_simulation` or
  `gameplay_abstraction`.

An object can absorb near its resonance *and* notch a transmitted signal, depending on
how it's coupled, so coupling is part of the entry. A shape is never given a single
fixed filter type.

**D3 — Geometry drives parameters through a small formula library.** Formulas are
GDScript helpers in `common/acoustics.gd`, tested headless:

| Formula | Use | Basis |
| --- | --- | --- |
| Quarter-wave tube, f₀ ≈ c / 4L_eff, L_eff ≈ L + 0.6r | reeds, pipes | established; end correction approximate |
| Helmholtz, f₀ ≈ (c/2π)·√(A / (V·L_eff)), L_eff ≈ L + 1.7r | hollow stumps, bottles | established, approximate for odd geometry |
| Minnaert bubble, f ≈ (1/2πR)·√(3γp₀/ρ) ≈ 3.26/R Hz in water | burbler, streams | established for water; mud is denser and lossier, so treat as simplified |
| Two-path comb, notches at f = (2k+1)·c / 2Δd | ground reflection, echo garden | established |

c = 343 m/s at 20 °C (a setting, because a hot desert is faster). Blender builders
can export the measurements (tube length, cavity volume, neck area) into the
profile, so geometry and acoustics never drift apart.

**D4 — Legible first.** Every acoustic object maps to at most a few primitives from D2.
Anything heavier, such as measured impulse responses or modal synthesis, needs its
own change with a spike. This follows the brief's §6 constraint "physical geometry
should initially map to plausible simplified DSP parameters".

**D5 — Provenance is per file and audited.** Each sound file (sample or IR) has a
sidecar `<file>.provenance.json` with:

- `source` (URL or "recorded in-house"), `author`, `license` (SPDX), `date`;
- `modifications`;
- `mit_compatible`, derived from the licence by the check, never hand-set.

Code licences and asset licences are audited separately (brief §6). CC0 and CC-BY are
acceptable; CC-BY adds an attribution entry to `CREDITS.md`. NC, ND and SA licences,
and anything unknown, fail the check. The existing
`assets/audio/sfx/patch_snap/LICENSE.txt` is the first file to migrate.

**D6 — Response previews are generated.** A headless tool renders each acoustic
object's magnitude response (from its D2 primitives and D3 parameters) to
`response.png` beside the visual previews. Reviewers see and later hear what an asset
does. Once the rack exists, the tool also renders an audio preview through it.

**D7 — The silent opening wins over the brief's vertical slice.** The brief's first
slice starts from "a looping hum plus broadband environmental audio". This game opens
in silence: a silent windstorm, where sound is what you discover. Acoustic objects
therefore shape sound but don't make it until something discovered excites them.
Ambient sources (wind in brush, water in streams) are discoverable sources that obey
the same hearing radius and silence rule as the lightning bug.

**D8 — Physical acoustics in the engine; environment-scale acoustics in Godot.**
Objects in a patch (a tuned reed, a cavity) render as rack processors, sample-locked
with everything else. Environment-scale effects use Godot's spatial layer: Area3D
reverb buses for enclosed spaces, and the occlusion and distance cues from
`add-rack-audio-engine`. The ground-reflection comb is a per-emitter filter there,
added only if a spike shows it's audible and worth the cost.

## First-pass acoustic reading of existing assets

These are proposals, to be confirmed by experiments in `docs/experiments/`.

| Asset | Role | Behaviour → approximation | Confidence |
| --- | --- | --- | --- |
| Reed clump (`flora/reeds`) | acoustic object; its harvest (`reed`) is a tunable tube | resonance: hollow internode as a closed tube → `resonator` at c/4L_eff. A clump is a panpipe; stubble is short, high tubes | established physics, simplified |
| Hollow stump (`props/desert/desert_stump_*`) | acoustic object | resonance: cavity plus opening → Helmholtz `resonator`. Side-coupled to a stream it notches; alone it absorbs near f₀ | established physics, simplified |
| Mudpit burbler | source | emission: bursting bubbles → `resonator` bursts at a Minnaert pitch set by bubble radius, timed by its Clock | simplified (mud ≠ water) |
| Dead brush (`desert_brush_*`) | source when wind is discovered; diffuser | emission: twig rattle → `noise_source` plus `nonlinear` buzz; reflection: scattering | gameplay abstraction |
| Mud-plate debris (`desert_debris_*`) | struck object | emission when struck: curled plates → short `resonator` bank | simplified |
| Mudflat ground | environment | reflection: hard, flat, dry ground → two-path `comb` at the listener (ground effect); absorption is low while dry and higher when wet | established physics, simplified |
| Scrub oak | environment, later source | absorption: foliage attenuates highs (`lowpass` grows with bloom); emission: wind in leaves once grown | simplified |
| Lightning bug | source | emission: square click (`add-rack-audio-engine`) | n/a (synthetic) |
| Stream segment | source and channel | emission: flowing water → `noise_source` with bubble `resonator` grains; transmission: a channel carries sound along it | simplified |
| `patch_snap` SFX | sound asset | `sample`; first file to get provenance | n/a |

## Risks / Trade-offs

- [Physics that sounds plausible but is wrong] → confidence labels on every
  behaviour; anything `established_physics` cites a source in the profile.
- [Profiles drift from the meshes] → Blender builders export measurements (D3);
  formula tests catch values outside their ranges.
- [Weak audible contrast makes a mechanic fail] → the brief's experiment format
  demands audible A/B success criteria before a mechanic is built.
- [Licence mistakes in found sounds] → D5's check runs with the other asset checks
  and blocks merges.

## Open Questions

- The brief's §10: are acoustic objects world geometry, portable items, or both? The
  reed is already both (a clump in the world, `reed` in the inventory).
- Does the world respond to measured sound properties, authored patterns, or a
  hybrid? This touches the light-quality field that drives blooming.
- Speed of sound as a world setting: fixed at 343 m/s, or tied to the day/night
  temperature?
