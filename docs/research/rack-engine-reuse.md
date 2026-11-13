# Research: existing open-source packages for the rack engine

*2026-11-13. Asked before creating `stubby-rack`: "make sure there are no existing
open source packages we can use instead." Every licence was verified from the
repo's LICENSE file or README. The game is MIT, so copyleft is out.*

## Verdicts

| Part of the design | Verdict | Why |
| --- | --- | --- |
| Per-sample rack scheduler (VCV semantics) | **Write it** | Every permissive graph engine processes in blocks, so feedback costs a block: miniaudio `ma_node_graph` (pull-based, locks on attach and detach), Elementary (feedback taps one block long), LabSound (WebAudio 128-frame quanta). Engines with 1-sample cables are all GPL-3: VCV Rack, Cardinal, 4ms MetaModule, Bespoke. The small MIT engines (maec, sonic-forge-dsp) are experimental. |
| Master clock and transport | **Write it**, splitting blocks at event offsets with CHOC's `AudioMIDIBlockDispatcher` (ISC) | Godot keeps `get_mixed_frames`, `mix_count` and `add_mix_callback` in C++ only. `AudioStreamSynchronized` and `AudioStreamInteractive` lock streams together only inside one stream. `AudioStreamPolyphonic` can't start a sound at a sample offset. Rhythm "conductor" addons are GDScript that estimate time from wall clocks. |
| Stem fan-out to AudioStreamPlayer3D | **Write it** | No prior art. godot-blipkit (MIT) and oparisy/gdextension-custom-audiostream are references for subclassing `AudioStreamPlayback`. Don't copy blipkit's mutex in `_mix`. |
| Lock-free queues | **Adopt CHOC** `choc_SingleReaderSingleWriterFIFO.h` (ISC) | Fallbacks: rigtorp/SPSCQueue (MIT), moodycamel ReaderWriterQueue (BSD-2 + zlib). |
| Godot-facing classes | **Write them** on godot-cpp | GDSiON (MIT) is an FM/MML synth fed through `AudioStreamGenerator` from the main thread, not a rack. |
| DSP | **DaisySP (MIT core) + Mutable Instruments STM32 (MIT) + Signalsmith DSP (MIT)**; cycfi/q (MIT) optional | Avoid: Surge `sst-*` (GPL-3, except a few headers marked individually), Tracktion Engine and the Cmajor runtime (GPL or commercial), DaisySP's LGPL submodule, Mutable's AVR code (GPL). |

## Candidates checked

- **Engines:** miniaudio, Elementary, LabSound, CHOC, Tracktion Engine, Cmajor, SOUL.
- **DSP libraries:** Signalsmith DSP, cycfi/q, Gamma, STK, Maximilian, sndkit, Surge
  `sst-*`, Vult.
- **Modular projects:** 4ms MetaModule, VCV Rack, Cardinal, Bespoke, Pure Data /
  godot-pd, maec, madronalib, sonic-forge-dsp, HexoDSP, VOSIMSynth, YASE.
- **Godot projects:** GDSiON, godot-blipkit, RhythmNotifier, GodotConductor,
  modular_godot.
- **Godot's own streams:** `AudioStreamInteractive`, `AudioStreamSynchronized`,
  `AudioStreamPolyphonic`.

Pins and vendored paths are in `stubby-rack/THIRDPARTY.md`.

## Sources

[miniaudio](https://github.com/mackron/miniaudio), [Elementary](https://github.com/elemaudio/elementary),
[LabSound](https://github.com/LabSound/LabSound), [WebAudio DelayNode](https://www.w3.org/TR/webaudio/#DelayNode),
[CHOC](https://github.com/Tracktion/choc), [rigtorp/SPSCQueue](https://github.com/rigtorp/SPSCQueue),
[readerwriterqueue](https://github.com/cameron314/readerwriterqueue),
[Tracktion Engine](https://github.com/Tracktion/tracktion_engine), [Cmajor](https://github.com/cmajor-lang/cmajor),
[Signalsmith DSP](https://github.com/Signalsmith-Audio/dsp), [cycfi/q](https://github.com/cycfi/q),
[sst-filters](https://github.com/surge-synthesizer/sst-filters), [4ms MetaModule](https://github.com/4ms/metamodule),
[VCV Rack licence](https://github.com/VCVRack/Rack/blob/v2/LICENSE.md), [GDSiON](https://github.com/YuriSizov/gdsion),
[godot-blipkit](https://github.com/detomon/godot-blipkit),
[gdextension-custom-audiostream](https://github.com/oparisy/gdextension-custom-audiostream),
Godot [audio_server.cpp](https://github.com/godotengine/godot/blob/master/servers/audio/audio_server.cpp),
[audio_stream_synchronized.cpp](https://github.com/godotengine/godot/blob/master/modules/interactive_music/audio_stream_synchronized.cpp),
[audio_stream_interactive.cpp](https://github.com/godotengine/godot/blob/master/modules/interactive_music/audio_stream_interactive.cpp).
