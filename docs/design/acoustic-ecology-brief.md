> **Source:** working brief from `~/Downloads/acoustic_game_design_context.md`, added 2026-11-13 and kept verbatim below.
> It predates the Godot port, so read "Bevy/Rust" as the original project (stubby-music).
> How this repo applies it to assets: `openspec/changes/add-acoustic-asset-profiles/`.
> Ideas here are not settled requirements.

# Acoustic Ecology Game — Agent Ideation Context

**Status:** Working design brief, not a finalized specification  
**Purpose:** Give design, audio, gameplay, physics, and engineering agents a common starting point for iterative experiments.

## 1. Core premise

Players explore a world and **collect sounds, samples, acoustic filters, and audio modulators**. They combine these resources into signal-processing chains and sound-producing systems. Physical environments and found objects are part of the instrument: rooms, pipes, cavities, walls, membranes, and resonators can shape sound.

**Existing project context:** The game is being developed in **Bevy/Rust**, draws inspiration from **Eurorack/modular synthesis** and **Factorio-style systems and recipes**, and explores using sound to influence moods and bring spaces back to life. Treat these as design context, not commitments to particular mechanics.

### Design hypothesis

> Make listening, discovery, acoustic experimentation, and modular composition the primary verbs. Let players discover a world through its sound and change that world by designing sound.

## 2. Acoustic physics: objects as filters

An acoustic filter is a structure whose **frequency-dependent transmission, reflection, or absorption** changes the sound reaching a listener. The result depends on geometry, material, source/receiver placement, coupling, and whether sound travels through a solid, a duct, or open air.

| Behavior | Physical examples | Potential player affordance | Caveat |
|---|---|---|---|
| Low-pass | Thick barriers, soft absorbers, long lossy passages | Muffle, conceal, warm, remove harshness | Walls also transmit bass poorly in some regimes; not ideal low-pass filters |
| High-pass | Engineered acoustic networks with compliant shunts and series inertance; certain duct/side-branch arrangements | Thin, brighten, remove rumble | A small hole or ordinary open pipe is **not automatically** a high-pass filter |
| Band-pass | Coupled resonant chambers, tuned membrane transmission, engineered duct resonators | Extract a note or formant from noise | Depends strongly on coupling and losses |
| Band-stop/notch | Side-branch Helmholtz resonator, quarter-wave side branch | Remove a hum or resonant frequency | A standalone bottle often **absorbs** near resonance; side-coupling determines transmission notch |
| Comb filtering | Two paths of different lengths, reflections | Hollow/metallic timbres, spatial puzzles | Strongly depends on path length and phase |
| Reverb/diffusion | Rooms, caverns, irregular surfaces | Spatialize, sustain, create atmosphere | Not simply an EQ curve |
| Nonlinear modulation | Rattling panels, vibrating reeds, loose objects | Distortion, buzz, harmonics | Often amplitude-dependent |

### Helmholtz resonance

A cavity connected by a neck has an approximate resonance

$$
f_0 \approx \frac{c}{2\pi}\sqrt{\frac{A}{V L_{\mathrm{eff}}}}
$$

where `c` is sound speed, `A` neck area, `V` cavity volume, and `L_eff` effective neck length. This is a useful tunable mechanic: changing cavity volume or neck geometry changes the resonant frequency. The equation is an approximation, especially for unusual geometry or strong coupling.

### Quarter-wave resonance

A tube closed at one end has a fundamental resonance approximately

$$f_0 \approx \frac{c}{4L_{\mathrm{eff}}}$$

A **side branch** tuned this way can create a transmission notch in a main duct. A tube's behavior depends on its boundary conditions; avoid assigning a universal filter type to a shape alone.

### Key physical distinction

- **Transmission:** what sound passes through a structure?
- **Reflection:** what sound is returned toward the source?
- **Absorption:** what acoustic energy is dissipated?
- **Resonance:** what frequencies are reinforced locally or coupled into/out of a path?
- **Perception:** what does a listener hear at a particular position?

Agents should model or label these separately. An object can absorb a frequency while simultaneously producing a notch in a transmitted signal, depending on how it is connected.

## 3. Collectible taxonomy

| Class | Examples | Controllable attributes |
|---|---|---|
| Sources | Wind, rain, footsteps, insects, machinery, voices, struck metal | Pitch, intensity, periodicity, position |
| Samples | One-shots, loops, ambient beds, granular fragments | Start/end, speed, pitch, envelope |
| Resonators | Bottles, pipes, bowls, strings, membranes | Length, volume, tension, damping |
| Filters | Low/high/band-pass, notch, comb | Cutoff/center frequency, bandwidth/Q, gain |
| Modulators | LFO, envelope follower, sequencer, oscillator, random CV | Rate, depth, shape, phase |
| Effects | Delay, reverb, distortion, chorus, granular processing | Time, feedback, mix, drive |
| Routing | Splitters, mixers, feedback paths, spatial emitters | Gain, connections, delay, position |
| Environmental modifiers | Doors, movable partitions, vents, cavities | Opening, orientation, placement, material |

Distinguish **collected audio assets**, **physical objects**, and **abstract processing modules**. They can share a patching interface without having identical acquisition or physics rules.

## 4. Gameplay loops to prototype

### A. Discover → capture → classify → patch

Explore a place, hear a sound, record a sample, identify its properties, combine it with a filter/modulator, and audition the result. Consider rewarding attentive listening rather than only collecting more items.

### B. Physical acoustic crafting

Find a pipe and change its length; add a cavity; position a microphone or listener; route the resulting output into a patch. Physical layout becomes a recipe for signal processing.

### C. Restore a space through sound

An environment has an acoustic or emotional target. The player builds a soundscape that changes its state. Avoid making emotion a simplistic one-frequency equation: consider rhythm, timbre, dynamics, harmonicity, spatial qualities, and contextual associations.

### D. Factory-like sound ecosystems

Chain sound sources and processors into repeatable production networks. Resource constraints might include power, acoustic energy, placement, CPU budget, noise leakage, and physical space. Feedback networks create emergent behavior, with stability limits.

## 5. Candidate puzzles and experiments

1. **The humming corridor:** Identify a persistent tone and tune a side-branch resonator to suppress it.
2. **The bottle choir:** Gather differently shaped cavities, tune resonances, and build a playable instrument.
3. **The divided room:** Move barriers and openings to alter the sound perceived at different positions.
4. **The echo garden:** Use reflecting surfaces and path lengths to construct rhythmic delays and comb-filter effects.
5. **The living workshop:** Combine captured mechanical samples, sequencers, and filters into a soundscape that changes the room's response.
6. **The whisper channel:** Design a frequency-selective path so one part of a sound is heard elsewhere while another is suppressed.

For each prototype, record: physical phenomenon, player action, audio result, visual feedback, discoverability, computational cost, and whether the mechanic is fun without a tutorial.

## 6. Signal-graph architecture (Bevy/Rust)

Conceptual patch:

```text
[Captured Sample] --> [Envelope] --> [Resonator] --> [Mixer] --> [Spatial Output]
                         ^                  ^
                         |                  |
                     [Sequencer]        [LFO / CV]

[Physical Object] --> [Measured/Approximated Transfer Function] --> [Audio Node]
```

### Suggested subsystem boundaries

- **World/ECS:** Bevy entities for objects, placement, discovery, interactions, and room state.
- **Audio graph:** Typed nodes and edges for audio-rate signals, control-rate signals, and event triggers.
- **DSP runtime:** Real-time-safe processing, preallocated buffers, deterministic node scheduling, and explicit feedback handling.
- **Acoustics model:** Lightweight approximations first (filters, delay taps, impulse responses); optional advanced wave simulation later.
- **Asset system:** Samples, impulse responses, presets, object acoustic profiles, metadata, and provenance/licenses.
- **Visualization:** Frequency response, spectrogram, waveform, signal-flow graph, and optional acoustic field overlays.
- **Game rules:** Discovery, crafting, recipes, objectives, world reactions, and progression independent of the DSP implementation.

### Important engineering constraints

- Do not assume Bevy itself provides a full modular, low-latency DSP graph or room acoustics solver.
- Separate real-time audio processing from gameplay frame rate; avoid allocations and blocking operations in the audio callback.
- Define sample-rate conversion, buffer sizes, channel layouts, latency, and feedback stability policies early.
- For browser/WASM, test actual audio permissions, autoplay constraints, and platform latency before committing to a runtime.
- Prefer reusable permissively licensed Rust components where practical; audit **code and asset licenses separately** for MIT compatibility.
- Physical geometry should initially map to plausible simplified DSP parameters, not imply full computational acoustics.

## 7. Research lanes for parallel agents

### Agent A — Acoustic science

Catalog physical filters and resonators with reliable references, measurable frequency responses, parameter ranges, and limitations. Distinguish established physics from proposed gameplay abstractions. Deliver a table of 20 candidate objects with approximate transfer-function models.

### Agent B — Game mechanics

Develop three distinct playable loops: exploration/collection, physical acoustic puzzles, and factory-style audio production. Identify player feedback and progression; produce short test scenarios rather than an enormous design document.

### Agent C — Rust/Bevy audio

Investigate maintained, permissively licensed Rust audio/DSP graph libraries and Bevy integration. Compare real-time safety, cross-platform/WASM support, spatialization, sample playback, modulation, and graph mutation. Do not assume maintenance or licensing without checking.

### Agent D — Content and ecology

Build a taxonomy of discoverable sounds and physical objects across biomes and built environments. Propose sample provenance and licensing workflows, metadata schemas, and procedurally generated variations.

### Agent E — UX/visualization

Prototype a patching interface, frequency-response displays, waveform/spectrogram views, and spatial acoustic visualization. Make cause and effect visible and audible, while keeping exploration central.

### Agent F — Systems integration

Define a minimal shared data model for `SoundAsset`, `AcousticObject`, `Processor`, `ControlSignal`, `Patch`, `AcousticEnvironment`, and `WorldEffect`. Specify serialization and test fixtures, avoiding premature engine-wide abstractions.

## 8. Shared experiment format

Each agent should submit proposals in this format:

```yaml
id: acoustic-001
name: Tunable side-branch resonator
hypothesis: A player can learn notch filtering by changing tube length.
physical_basis: Quarter-wave side-branch resonance
player_action: Attach a branch and adjust its effective length
inputs: [broadband_noise, narrowband_hum]
outputs: [filtered_audio, frequency_response]
parameters: [tube_length_m, damping, coupling]
prototype: Simple digital notch approximation with audible A/B toggle
success_criteria:
  - Player can hear and identify a meaningful change
  - Visual response matches the simulated filter
  - Mechanic works in a short, repeatable gameplay test
risks: [weak perceptual contrast, unrealistic physical mapping]
confidence: established_physics_simplified_simulation
```

## 9. First vertical slice

**Goal:** One small playable room with a sound source, one collectible sample, two physical acoustic objects, a simple patch interface, and an audible environmental objective.

Suggested sequence:

1. Start with a looping hum plus broadband environmental audio.
2. Let the player capture and replay one sound.
3. Provide a tunable side-branch resonator represented by a notch filter.
4. Provide a second object with a contrasting resonant or low-pass response.
5. Show a live spectrum and an optional response curve.
6. Let the player route, compare, and bypass each object.
7. Define success in terms of a measurable audio property, then test whether players can solve it by listening.

**Exit criteria:** Stable audio, responsive controls, clear audible contrast, reproducible simulation, and at least one player-discovered solution.

## 10. Open design questions

- Are physical objects literal world geometry, portable inventory items, or both?
- Are patches freely programmable, recipe-based, or progressively unlocked?
- Should the audio physics be approximate but legible, or increasingly simulation-driven?
- Does the world respond to measurable sound properties, authored musical patterns, or a hybrid?
- How do mood and environmental restoration work without enforcing arbitrary musical tastes?
- How much of the game is real-time performance versus construction and automation?
- Can multiple players hear and manipulate the same acoustic environment coherently?
- How are user-created samples and patches saved, shared, attributed, and moderated?

## 11. Immediate agent prompt

> Use this brief as design context for a Bevy/Rust, MIT-licensed modular-audio exploration game. Propose **three materially different mechanics** centered on collectible sounds and physical acoustic filters. For each, distinguish the real acoustic principle from the simplified DSP implementation; specify the player interaction, progression value, minimum prototype, and a falsifiable playtest. Prefer existing maintained, permissively licensed libraries over bespoke infrastructure. Mark unverified claims and propose targeted research rather than inventing APIs or physical behavior. Do not treat the ideas in this document as settled requirements.
