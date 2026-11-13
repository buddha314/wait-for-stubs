## Why

The opening's horizon is empty: a 216 m mudflat ends at the sky, and the moon is
pinned in place. stubby-music enclosed its basin with seeded mountain silhouettes,
three overlapping ridge rings, and the user wants them back. Their skyline read
like acoustic waves, so here they are designed as echoes of one waveform. The sky
should also travel: the sun and stars already move with the Calendar, the clouds
drift with Sky3D's wind, but the moon is fixed.

## What Changes

- **Distant mountains** (port of stubby-music `lib.rs` setup, `add-desert-opening`
  atmosphere spec):
  - three seeded ridge rings at 480, 590 and 700 m;
  - the nearest ring's skyline is a seeded waveform (a few harmonics plus gentle
    roughness), and each farther ring repeats it as an echo: shifted around the
    circle, lower in amplitude, a little higher in the view, and hazier in colour;
  - the same seed always gives the same skyline;
  - generated at load, never saved into scenes.
- **Outer ground**: stubby-music's dark 1600 m plane under the mudflat, so there is
  no void between the mudflat and the mountains.
- **A travelling moon**:
  - it is fixed among the stars and turns with them as Calendar time passes;
  - it starts where it is pinned today (in view at spawn, NNW, 20° up);
  - the start position is data, so a physically plausible path is one edit away.
- **The sky's other motion** stays with Sky3D: the realistic sun, star rotation by
  sidereal time, and cloud drift by wind. This change only checks that they move.
- **Acoustics**: the rings are real reflectors, with echo delays of 2R/c (2.80 s,
  3.44 s and 4.08 s). Their acoustic profile is specified here and written when
  `add-acoustic-asset-profiles` defines the format.

## Capabilities

### New Capabilities
- `distant-mountains`: the echoed ridge rings, the outer ground, and their acoustic
  profile.
- `sky-motion`: the travelling moon, and the sun, stars and clouds moving with
  simulation time.

### Modified Capabilities
<!-- none -->

## Impact

- New `scenes/mountains/` (a `@tool` generator, like `reed_bed`) and
  `scenes/sky/moon_path.gd`.
- `main.tscn` instances both and gains the outer ground.
- **Reuse:** Sky3D (TimeOfDay, SkyDome, clouds), `WorldSeed`, Godot `SurfaceTool`.
- **Written from scratch:** the ridge generator (about 100 lines) and the moon path
  (about 60 lines). No add-on generates horizon silhouettes or drives Sky3D's moon
  along a custom path (see design).
- **Weather** (rain, dust, wind) is out of scope. It is researched in
  `docs/research/godot-weather.md` for a later change.
