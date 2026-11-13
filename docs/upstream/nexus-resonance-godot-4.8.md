# Nexus Resonance in Godot 4.8 beta: what breaks and the workarounds

*2026-11-13, from `add-rack-audio-engine` spike task 1.9. Nexus Resonance v1.1.0
(undomick/godot-nexus-resonance, MIT) with Steam Audio 4.8.1 (Apache-2.0), on our
custom Godot 4.8 beta. It's not reported upstream yet; this note is the material for
that report.*

## Symptom

A `ResonancePlayer` with a `ResonancePlayerConfig` is silent, and it never pulls its
stream (our `RackStemStream`'s `_mix` is never called). Godot prints at load:

```
ERROR: Object 'ResonancePlayer' already has member 'set_stream'.
ERROR: Object 'ResonancePlayer' already has member 'get_stream'.
ERROR: Object 'ResonancePlayer' already has member 'play'.
ERROR: Object 'ResonancePlayer' already has member 'stop'.
ERROR: Object 'ResonancePlayer' already has member 'ATTENUATION_DISABLED'.
   at: bind_method (core/object/gdtype.cpp:174)
```

## Causes

1. **Godot 4.8 rejects an extension class re-binding a method its parent class already
   binds.** `ResonancePlayer` (extends `AudioStreamPlayer3D`) binds its own
   `set_stream`, `get_stream`, `play` and `stop`. In 4.8 those are rejected, so a
   script's `play()` runs `AudioStreamPlayer3D::play`. That skips Nexus's setup:
   rebinding the wrapper to the stream, registering the Steam source, and pushing the
   first spatial parameters. This happens with the 4.6 release binary *and* with a
   build against the 4.8 API.
2. **The spatial-output gate stays closed with no geometry.**
   `ResonanceServer::is_spatial_audio_output_ready()` waits for registered triangles.
   A scene with no `ResonanceGeometry` never opens it, so every player stays silent.

## Workarounds (no Nexus changes)

- Start players with **`play_stream(from_position)`**. It's the same method, bound
  under a name the parent doesn't have.
- Have **at least one `ResonanceGeometry`** in the scene (the opening's ground will do).

With both, the v1.1.0 release binary works in our 4.8 beta:
- **16 stems:** every stem read once per Godot mix step, 0 skips, Steam ready.
- **Cost:** about 0.42 ms of audio-thread CPU per 512-frame step, against 0.14 ms
  with plain `AudioStreamPlayer3D`.
- **Binaural:** one emitter on the right gives +10.9 dB right over left, against
  +6.0 dB from Godot's panning.

## Building it against the 4.8 API

Nexus builds against godot-cpp 10.0.0 and our dumped `extension_api.json`
(`scons platform=linux target=template_debug custom_api_file=...`), with three patches:

1. `ResonanceAudioEffectInstance::_process` takes `const AudioFrame *src_buffer`
   (it was `const void *`) to match the 4.8 `AudioEffectInstance` API.
2. `ResonanceDirectivityDrawer::immediate_mesh_` becomes a `Ref<ImmediateMesh>`:
   in godot-cpp 10, `memnew` of a `RefCounted` returns a `Ref`.
3. The same file: `immediate_mesh_ = nullptr` becomes `.unref()`, and
   `!immediate_mesh_` becomes `.is_null()`.

The rebuild doesn't fix cause 1; that needs Nexus to stop re-binding parent names
(for example, overriding through notifications, or only binding the `play_stream`
style names).
