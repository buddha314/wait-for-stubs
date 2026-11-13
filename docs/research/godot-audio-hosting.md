# Research: hosting the modular synth in Godot 4.8

*2026-11-13. Godot facts are from the engine source at commit `e8fe0a1b5`, the same
commit as the installed `4.8.beta.custom_build`. Follows stubby-music's
`docs/research/audio-engine.md` and `rack-and-spatial-audio.md`, whose
conclusions still hold: the synth generates the sound, game audio places and
mixes it, and the rack is per-sample with 1-sample cables.*

## How Godot mixes (what constrains a host)

- **Fixed 512-frame block.** `buffer_size = 512` is hardcoded, with a TODO to make
  it a setting (`servers/audio/audio_server.cpp:1337`). That's 10.7 ms at 48 kHz.
  The mix rate is the project setting `audio/driver/mix_rate` (default 44100). Output
  latency is the setting `audio/driver/output_latency` (default 15 ms).
- **One audio thread, playbacks mixed in turn.** `_mix_step()` (line 131) first runs
  C++-only mix callbacks, then calls `mix(buf, pitch_scale, 512)` on every active
  playback (line 199), all for the same block. So one shared engine can render once
  per step and fan stems out to many players with no added latency or drift. Don't
  rely on the list order: render when the first stem asks for a block the engine
  hasn't produced yet (compare a block cursor). Paused playbacks are skipped (line
  178), so keep one always-playing *driver* player that keeps the engine (and its
  clocks) running when nothing is audible.
- **No mix hook for extensions.** `add_mix_callback` and `get_mix_count` aren't bound.
  Bound for timing: `get_time_since_last_mix`, `get_time_to_next_mix`,
  `get_output_latency`, `get_mix_rate`. So the **engine's own sample counter must be
  the clock**, published lock-free with a `(sample, instant)` sync point, the same
  scheme as stubby-music's D6.
- **Resampling and doppler break lockstep.** `AudioStreamPlaybackResampled` reads at
  `stream_rate * rate_scale / mix_rate`, and doppler arrives as `pitch_scale`. Stems
  must be plain `AudioStreamPlayback`, ignore pitch, and run with doppler off.
- **Spatial parameters update per physics tick.** AudioStreamPlayer3D recomputes
  volume, filter and Area3D reverb sends on the physics tick
  (`scene/3d/audio_stream_player_3d.cpp:283`). The server smooths them across each
  block. A player beyond `max_distance` is silent but still mixed, so stems stay
  continuous.
- **Realtime rules:** `_mix` runs on the audio thread. No allocation, no Godot object
  calls, never `AudioServer.lock()`.

## GDScript DSP is not viable

A typed GDScript rack (phase accumulator plus one-pole filter per module, 1-sample
cables), measured headless on the installed build: **110 ns per module-sample**.
16 modules use 8.5% of real time, and 200 modules would need about 106%. That is
about 12× the Rust spike's 8.8 ns, for trivial modules. `AudioStreamGenerator` is
also fed from the main thread, so frame hitches become underruns.

## Hosting options

Scores 1 (poor) to 5 (good).

| Option | VCV semantics | Reuse | Module authoring | License | Godot-version risk | Spatial |
| --- | --- | --- | --- | --- | --- | --- |
| GDScript + AudioStreamGenerator | 1 | 1 | 3 | 5 | 5 | 4 |
| **godot-rust (gdext) hosting `stubby_audio`; stems → AudioStreamPlayer3D** | **5** | **5** | **4** | 5 | 3 | 4 |
| godot-cpp + DaisySP/MI (engine rewritten in C++) | 5 | 1 | 3 | 5 | 4 | 4 |
| libpd GDExtension | 2 | 1 | 3 | 5 | 2 | 3 |
| Faust as the host | 3 | 2 | 4 | 4 | 2 | 3 |
| `stubby_audio` on its own cpal device (Godot sends transforms only) | 5 | 5 | 4 | 5 | 5 | 3 |

About the options:

- **libpd:** Pd feedback costs at least one 64-sample block unless the patch uses
  `block~ 1`, which is expensive. Unverified.
- **Faust:** the Godot bridge is only a GSoC 2026 proposal.
- **Own cpal device:** gives two audio clocks, and Godot's buses and Area3D reverb
  can't be used.

**godot-rust gdext 0.5.5** (MPL-2.0, file-level, fine in an MIT game):

- Features exist up to `api-4-7`. Use `api-custom` against this binary's
  `extension_api.json` for 4.8.
- `IAudioStreamPlayback::mix_rawptr` exists.
- Open issues #1130 and #1131: `mix` touching `self` is formally unsound, and gdext
  guards `self` with a mutex that a script call could hold. The fix is to keep the
  playback holding only an `Arc` to lock-free engine state, and to have scripts talk
  to a separate controller object.

## DSP libraries (license matters: the repo is MIT)

| Library | License | Language | Coverage | Maintained |
| --- | --- | --- | --- | --- |
| fundsp | MIT/Apache-2.0 | Rust | broad: oscillators, filters, envelopes, effects | yes |
| mi-plaits-dsp-rs | MIT | Rust | Mutable Instruments Plaits engines | yes |
| pichenettes/eurorack | MIT (STM32 modules); GPL-3 (AVR) | C++ | Plaits, Braids, Rings, Clouds… | yes |
| DaisySP | MIT core; avoid `DaisySP-LGPL` | C++ | Eurorack-oriented | yes |
| Faust | generated code is ours; libraries are per-file | DSL → C++/Rust | huge | yes |
| libpd | BSD | C | Pd vanilla | yes |
| Csound | LGPL-2.1 | C | huge | yes |
| VCV Rack, Cardinal, Surge | GPL-3 | C++ | everything | **can't be linked into an MIT game** |

No existing Godot Eurorack-style rack is worth adopting (`zuggamasta/modular_godot`
is small, C#, and has no license).

## Spatialization

- Custom streams work with AudioStreamPlayer3D, which gives panning, distance
  attenuation, a distance filter, Area3D reverb buses and polyphony.
- Godot has no HRTF.
- Steam Audio for Godot: `stechyo/godot-steam-audio` is archived; nurjeff's fork is
  active. Nexus Resonance (MIT, Godot 4.6+, HRTF and occlusion) may help, but whether
  it accepts custom streams is unverified.
- Fallback: binauralise the top emitters inside the engine (`firewheel-ircam-hrtf`,
  about 25 µs per emitter per block, measured in stubby-music) and output them
  through a non-positional player.

## What the first spike should measure

1. A test tone fanned to 48 AudioStreamPlayer3D stems for 10 minutes: zero drift, zero
   glitches.
2. Godot-side cost per AudioStreamPlayer3D at 16, 48 and 96 emitters.
3. A 200-module rack inside `mix`, compared with stubby-music's 8.5% of a block.
4. Clock-to-light jitter, using the sync point and `get_output_latency`.
5. Pause, scene reload and editor hot-reload of the extension.
6. Builds against `api-4-7` and against `api-custom`.

## Sources

Godot source (commit e8fe0a1b5): `servers/audio/audio_server.cpp`,
`servers/audio/audio_driver.cpp`, `scene/3d/audio_stream_player_3d.cpp`,
`scene/resources/audio/audio_stream.cpp`.
[AudioStreamPlayback](https://docs.godotengine.org/en/latest/classes/class_audiostreamplayback.html),
[AudioStreamGenerator](https://docs.godotengine.org/en/stable/classes/class_audiostreamgenerator.html),
[gdext compatibility](https://godot-rust.github.io/book/toolchain/compatibility.html),
[IAudioStreamPlayback](https://godot-rust.github.io/docs/gdext/master/godot/classes/trait.IAudioStreamPlayback.html),
gdext issues [#1130](https://github.com/godot-rust/gdext/issues/1130) and
[#1131](https://github.com/godot-rust/gdext/issues/1131),
[fundsp](https://github.com/SamiPerttu/fundsp),
[mi-plaits-dsp-rs](https://github.com/sourcebox/mi-plaits-dsp-rs),
[pichenettes/eurorack](https://github.com/pichenettes/eurorack),
[DaisySP](https://github.com/daisyaudio/DaisySP), [libpd](https://github.com/libpd/libpd),
[VCV Rack license](https://github.com/VCVRack/Rack/blob/v2/LICENSE.md),
[Nexus Resonance](https://store.godotengine.org/asset/movec/nexus-resonance/),
[godot-steam-audio](https://github.com/stechyo/godot-steam-audio).
