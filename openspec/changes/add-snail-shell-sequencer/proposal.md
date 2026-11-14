## Why

The rack can make a sound on every beat, but not a pattern: there is no sequencer.
The user wants the first one to come from the world (2026-11-13): a high-spired snail
shell, its whorls the steps, collected and mounted in a rack as a basic step sequencer
in the spirit of KORG's SQ-1, with a gate and a CV output. It lets the burbler play a
four-note line or a rhythm, and it's the first instance of a "natural sequencer" from
the wall of bad ideas (`docs/design/wall-of-bad-ideas.md`), which will later light the
campfire (a flint on 2 and 4).

## What Changes

- **Snail shells in the world.** Empty, high-spired land-snail shells (four whorls,
  glossy brown, after the user's reference photo) lie on the mud near the reed beds,
  placed by a seeded scatter. E collects one (no recorder needed: a shell is not a
  sound) into a `snail_shell` item.
- **A four-step sequencer module.** A `snail_shell` mounts in a rack place as the
  "Snail sequencer": four steps, each with a CV knob and a lit step button (as on
  Intellijel's Steppy and KORG's SQ-1: push a button to light the step, push again to
  clear it; the same light shows the playhead passing); jacks CLOCK in, RESET in, GATE
  out, CV out. A new sequencer starts with every step dark. Each
  rising edge at CLOCK moves to the next step (1→4, then 1). GATE out follows the clock's
  gate on steps whose button is on; CV out holds the step's knob voltage, so patched to
  a VCO's V/OCT it plays a four-note line.
- **The burbler's rack gets an optional place** for it, so the player can patch clock
  GATE → CLOCK, sequencer GATE → volume TRIG and CV → VCO V/OCT.
- **"Sounding" means a signal path, not exact cables.** A machine's suggested cable is
  satisfied when its `to` jack is fed from its `from` jack directly or through patched
  modules, so routing the clock through the sequencer still counts as configured
  (stream flow and goals follow). Optional places don't need filling.
- **Gate buttons in the rack screen:** a new control (click toggles, its light shows the
  state), beside knobs and jacks.
- **Engine:** a `step_sequencer` module kind in stubby-rack (clock and reset in, gate
  and CV out, per-step CV and gate parameters), reporting each step change through the
  engine's event path so the active-step light is lit at the heard instant.
- **Acoustic profile** for the shell (an empty cavity: Helmholtz resonance noted,
  excited by nothing yet).

### Existing tools this relies on

- The rack: `RackState` places and `accepts` (an item mounts as a module, as
  `square_wave` → `square_vco`), the rack screen, `RackLink` (state → engine),
  `RackModules` and module assets (`assets/modules/<id>/asset.json`, `engine.json`).
- `ResourceNode` pickups, `resources.json`/`items.json`, seeded scatters (`ReedBed`).
- Blender generators and `module_kit.py` for the shell model and the module panel.
- stubby-rack's module registry, its event path (`clock_ticked`), and
  `sample_to_ticks_usec`.
- Sequencer logic references from `docs/research/module-library.md` §7: Peaks
  `mini_sequencer` (MIT), ML_modules' sequencer (BSD-3).

Written from scratch: the four-step module (a few lines of edge logic; see design.md
D3 for why no library module is vendored), the gate-button control, the shell
generator and panel.

## Capabilities

### New Capabilities
- `snail-shell`: the shell in the world, its collection and item, and its acoustic
  profile.
- `step-sequencer`: the four-step sequencer's behaviour, its panel and controls, its
  place in the burbler's rack, and signal-path "sounding".

### Modified Capabilities
- `rack-screen`: gate buttons join knobs and jacks as controls.
- `mudpit-burbler`: an optional sequencer place; "configured" means the suggested
  signal paths are made, through any patched modules.

## Impact

- New `assets/creatures/snail_shell/` (master scene, model, profile, `acoustics.json`),
  `tools/blender/create_snail_shell.py`; scatter near the reed beds in `main.tscn`.
- New `assets/modules/snail_sequencer/` (panel model from a generator, `asset.json`,
  `engine.json`).
- `assets/recipes/items.json`, `resources.json`, `ids.lock`; the burbler's
  `configure` (`create_burbler.py` writes it).
- `common/rack_state.gd` (optional places, path-based completion), `scenes/rack_screen/`
  (gate buttons, active-step light), `common/rack_link.gd` (step events).
- stubby-rack: `step_sequencer` kind and its step events; resync with
  `tools/sync_stubby_rack.sh`.
