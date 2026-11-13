## Context

Ports stubby-music's `add-field-recorder` (proposal, spec and tasks only; it had no
design.md). Upstream built the art (`tools/blender/create_field_recorder.py`, task 1.1)
and the hand (`crates/stubby_game/src/hand.rs`, task 2.1): one `Hand` resource holding
`Option<HandItem>`, a `HAND_ITEMS` table of key, model and pose, each item spawned
hidden on the player and shown while held, and `NotShadowCaster` on the
`FieldRecorder_FurShell*` meshes. Task 2.2 (record light and level bars during
collection) was never built.

In this repo the asset is already copied. The glTF carries the nodes the game needs:
`Grip` (extras `socket: hand`), `Capture` (`pattern: xy_stereo`), `Windguard`,
`Light_rec` (`rest_strength 0`, `peak_strength 8`, `pulse_while: capturing`, material
`FieldRecorder_RecLight`), `Screen` (`display: input_level`, `levels: 8`),
`Level_0`–`Level_7`, and fourteen `FieldRecorder_FurShell<n>` plus
`FieldRecorder_WindguardSock`. The player is `scenes/player/` with `Head` (camera
pivot) and `Head/Reach`; E calls `Interactable.interact()` every physics tick on a
`hold_repeats` pickup. Screens disable the player with `controls_enabled = false`.

Audio: stubby-rack (`add-rack-audio-engine`) will own all game audio and time it with
its sample counter (master clock 1 BPM, tempo clocks at whole multiples). Today the
only sound is the lightning bugs' pre-rendered click on `AudioStreamPlayer3D` on the
Master bus. There is no custom bus layout yet.

## Goals / Non-Goals

**Goals:**
- H toggles the recorder in the hand; the hand is ready for more items.
- The record light answers collection; the meter answers real sound.
- Everything here works before the audio engine exists, and needs no rework when it
  arrives beyond pointing the meter at the right bus.

**Non-Goals:**
- Recording or playing back captures, or any recorder sound (a later change; the
  spec only fixes how such sounds must be played).
- Gating collection on holding the recorder (open question below).
- A hand/arm model, viewmodel FOV, or weapon-style sway.
- Directional capture (using `Capture`'s X/Y pattern to weight what the meter hears).

## Decisions

**D1 — The hand is a scene, its items are posed children.** `scenes/hand/hand.tscn`
is a `Node3D` under `Player/Head`. Each hand item is a child `Node3D` posed in the
editor (the recorder at stubby-music's transform: `(0.17, −0.165, −0.42)`, rotation
Y 0.35, X −0.7, Z 0.12 rad, applied in Bevy's Y·X·Z order), holding the instanced glb
and exporting the input action that toggles it. `hand.gd` keeps `held: StringName`
(empty = nothing) and shows only the held child. Ports `hand.rs`'s one-item hand and
key-per-item list.
- Rejected: a hard-coded item table in GDScript (upstream's `HAND_ITEMS`): the pose
  can't be tuned in the editor.
- Rejected: the pose in `asset.json`: that file is overwritten by re-syncs from
  stubby-music.
- Rejected: an `Inventory`-owned hand: the hand is presentation and input, not item
  counts; it can read the inventory later if items must be owned to be held.

**D2 — The held model is a plain child of the camera pivot.** It renders in the world
pass with the world's lighting.
- Rejected: a separate `SubViewport` viewmodel camera (no wall clipping, but a second
  render, and the recorder would lose the moon and sun lighting that shows the fur).
- Rejected: a depth-hack shader on the recorder's materials (edits imported
  materials, which re-imports would discard).
- Accepted risk: the recorder can poke into walls; at 0.42 m forward this is rare on
  an open mudflat (see Risks).

**D3 — Fur shadows off by name.** After the glb is instanced, every
`GeometryInstance3D` whose name, or whose parent's name, starts with
`FieldRecorder_FurShell` gets `cast_shadow = SHADOW_CASTING_SETTING_OFF`, mirroring
upstream's `fur_casts_no_shadow`. The rule comes from the profile
(`windguard.shells_cast_shadows: false`).
- Rejected: an import script or scene inheritance editing the glb import: more moving
  parts for a one-line runtime rule.

**D4 — The record light is an envelope, not a blink.** The player sets a
`collected_this_tick` flag when `interact()` acts on a pickup (an `Interactable` with
`hold_repeats`); machine interactions don't count. The recorder runs an attack/decay
envelope toward peak while the flag is set and back to rest otherwise, and writes it to
the emission energy of a per-instance copy of `FieldRecorder_RecLight` (and the
`FieldRecorder_GlowHalo` shells under `Light_rec`). Strengths come from `Light_rec`'s
extras; attack 0.05 s and decay 0.4 s are constants in the script until the profile
carries them.
- Rejected: a periodic pulse on frame time (upstream's "pulse"): an un-clocked
  rhythm next to clocked music, which the master-clock spec forbids for anything
  musical and which reads as one.
- Rejected: pulsing on master or burbler ticks: the master is 1 BPM (one pulse a
  minute), and following "the nearest clock" needs a rule this change doesn't need.

**D5 — The meter reads Godot's bus peak, not the engine.** Each frame the recorder
takes `max(AudioServer.get_bus_peak_volume_left_db, ..._right_db)` of the bus that
carries world and music audio, applies peak-hold with a fixed fall rate (24 dB/s), and
lights `Level_n` when the level is at or above `−48 + 6·n` dBFS (n = 0…7), by toggling
the visibility (or emission) of each `Level_n`'s meshes. Today that bus is Master,
where the bug clicks play. When stubby-rack adds its stems, the meter moves to their
world/music bus so the UI stem is excluded.
- Rejected: an engine meter from stubby-rack (`rack-control` "Lights, meters and
  scopes"): those are per module, and the mix the listener hears is only formed after
  Godot spatialises the stems, so Godot's bus meter is the right point, and it exists
  today.
- Rejected: `AudioEffectSpectrumAnalyzer` or `AudioEffectCapture` on the bus: more
  than a peak meter needs, and capture adds a ring buffer the main thread must drain.
- Rejected: a fake animation during collection (upstream task 2.2): it would light
  in the silent opening, contradicting "sound is what the player discovers".
- Not a timing source: the meter only reads levels for display, so it doesn't break
  the rule that audio is never timed from frame time.

**D6 — Input.** A `field_recorder` action bound to H in `project.godot`, handled in
`hand.gd`'s `_unhandled_input`, ignored while the player's `controls_enabled` is
false. Satisfactory-style keys stay as in CLAUDE.md.

**D7 — Acoustic profile.** `assets/equipment/field_recorder/acoustics.json` declares
no acoustic role. It is written to the `add-acoustic-asset-profiles` schema when that
lands; until then it is a minimal file with `"role": "none"` and a note, and the
schema task upgrades it.

## Risks / Trade-offs

- [The recorder clips into nearby geometry] → acceptable on the mudflat; if it shows
  up near machines, move the pose closer or revisit D2's viewmodel option.
- [Godot bus peak is per mix block (512 frames ≈ 10.7 ms) and read at frame rate] →
  fine for a display; peak-hold hides missed blocks.
- [Until stubby-rack splits buses, any future UI sound on Master would move the
  meter] → no UI sounds exist today; the engine's UI stem gets its own bus.
- [The `Level_n` nodes may be empties over bar meshes rather than meshes] → the task
  checks the glb and lights all mesh descendants of each `Level_n`.

## Migration Plan

Additive: a new scene under the player, one input action, one profile file. Rollback
is removing the `Hand` node. When stubby-rack lands, change the meter's bus name.

## Open Questions

- ~~Must the recorder be held to collect?~~ Decided 2026-11-13: yes, for sounds (any
  pickup yielding an item with a `waveform`); reeds and other materials need no
  recorder. The game starts with it in hand, and a tip names H when E is pressed on a
  sound without it.
- ~~Recording and playback~~: decided 2026-11-13. The recorder is a prop for
  collecting predefined or manufactured sound items; it never records live audio.
  "Recording the wind" collects a `wind` sample item that already exists in the
  rules, with its sound file and provenance. Playing such samples in a rack is the
  engine's sampler (`add-rack-audio-engine` 5.5) plus a sampler module, a later
  change; no capture pipeline is needed.
- ~~Directional listening~~: decided 2026-11-13, yes. The meter weights per-emitter
  levels by the `Capture` X/Y pattern once the engine reports them (needs
  `add-rack-audio-engine` 8.2 meters per emitter).
